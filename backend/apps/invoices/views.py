from rest_framework import generics, permissions, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.http import HttpResponse
from django.db import models
from apps.accounts.permissions import IsStoreUser, CanAccessStore
from .models import Customer, Invoice, InvoiceItem
from .serializers import (
    CustomerSerializer, InvoiceSerializer, InvoiceListSerializer, InvoiceDetailSerializer,
    InvoiceCreateSerializer, InvoiceItemSerializer
)
from .utils import generate_invoice_pdf


class InvoicePagination(PageNumberPagination):
    """Custom pagination class for invoice list - 100 invoices per page for better UX"""
    page_size = 100
    page_size_query_param = 'page_size'
    max_page_size = 200


class CustomerListCreateView(generics.ListCreateAPIView):
    serializer_class = CustomerSerializer
    permission_classes = [IsStoreUser]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['company', 'state']
    search_fields = ['name', 'email', 'phone', 'gstin']
    ordering_fields = ['name', 'created_at']
    ordering = ['-created_at']

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return Customer.objects.filter(
                company__owner=user
            ).select_related('company')
        else:
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            user_companies = models.Q()
            for store_id in user_stores:
                user_companies |= models.Q(company__stores__id=store_id)
            return Customer.objects.filter(
                user_companies
            ).select_related('company').distinct()


class CustomerDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CustomerSerializer
    permission_classes = [IsStoreUser]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return Customer.objects.filter(
                company__owner=user
            ).select_related('company')
        else:
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            user_companies = models.Q()
            for store_id in user_stores:
                user_companies |= models.Q(company__stores__id=store_id)
            return Customer.objects.filter(
                user_companies
            ).select_related('company').distinct()


class InvoiceListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsStoreUser]
    pagination_class = InvoicePagination  # Use custom pagination with page_size=20
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['status', 'company', 'store', 'invoice_date']
    search_fields = ['invoice_number', 'customer__name', 'customer__phone']
    ordering_fields = ['invoice_date', 'total_amount', 'created_at']
    ordering = ['-created_at']

    def get_serializer_class(self):
        """
        Use appropriate serializer based on request method:
        - POST: InvoiceCreateSerializer (for creating invoices)
        - GET: InvoiceListSerializer (lightweight, for list performance)
        """
        if self.request.method == 'POST':
            return InvoiceCreateSerializer
        return InvoiceListSerializer  # Use lightweight serializer for list view

    def get_queryset(self):
        from django.db.models import Exists, OuterRef
        user = self.request.user

        # Base queryset with optimizations
        # Include 'company' and 'store' to avoid N+1 queries
        queryset = Invoice.objects.select_related('customer', 'company', 'store')

        # For detail/create, include full relations
        if self.request.method != 'GET':
            # Full queryset for detail/create - all relations
            queryset = queryset.select_related(
                'created_by'
            ).prefetch_related('items', 'items__item')

        # Apply user-based filtering
        if user.role == 'admin':
            return queryset.filter(company__owner=user)
        else:
            # PERFORMANCE OPTIMIZATION: Use EXISTS subquery instead of IN clause
            # This avoids materializing the store list and is faster for databases
            from apps.stores.models import StoreUser
            store_subquery = StoreUser.objects.filter(
                user=user,
                is_active=True,
                store=OuterRef('store_id')
            )
            return queryset.filter(Exists(store_subquery))

    def perform_create(self, serializer):
        user = self.request.user

        # For non-admin users (store users), automatically assign their store
        if user.role != 'admin':
            # Remove store from validated_data if provided by client
            if 'store' in serializer.validated_data:
                serializer.validated_data.pop('store')

            # Get user's first available store assignment
            user_store_assignment = user.store_assignments.filter(is_active=True).first()
            if not user_store_assignment:
                raise PermissionDenied("No active store found for user")

            store = user_store_assignment.store
            serializer.validated_data['store'] = store

            # Automatically set company from user's store
            serializer.validated_data['company'] = store.company

        else:
            # For admin users, handle store selection as before
            if 'store' not in serializer.validated_data or not serializer.validated_data['store']:
                raise PermissionDenied("Admin users must specify a store")

            store = serializer.validated_data['store']

            # Handle store as integer ID
            if isinstance(store, int):
                from apps.stores.models import Store
                store = Store.objects.get(pk=store)
                serializer.validated_data['store'] = store

            # Set company from store if not provided
            if 'company' not in serializer.validated_data or not serializer.validated_data['company']:
                serializer.validated_data['company'] = store.company

        serializer.save()


class InvoiceDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = InvoiceDetailSerializer
    permission_classes = [IsStoreUser, CanAccessStore]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return Invoice.objects.filter(
                company__owner=user
            ).select_related('customer', 'company', 'store', 'created_by').prefetch_related('items', 'items__item')
        else:
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            return Invoice.objects.filter(
                store__id__in=user_stores
            ).select_related('customer', 'company', 'store', 'created_by').prefetch_related('items', 'items__item')


@api_view(['GET'])
@permission_classes([IsStoreUser])
def generate_pdf_view(request, invoice_id):
    user = request.user
    
    try:
        if user.role == 'admin':
            # Use the same logic as the invoice list view
            invoice = Invoice.objects.select_related('company', 'customer', 'store', 'created_by').get(id=invoice_id)
        else:
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            invoice = Invoice.objects.select_related('company', 'customer', 'store', 'created_by').get(id=invoice_id, store__id__in=user_stores)

        # Safely determine layout preference (admin's preference for all their users)
        if invoice.created_by:
            creator = invoice.created_by
            if creator.role == 'store_user' and creator.created_by:
                # Store user - use their admin's preference
                layout = getattr(creator.created_by, 'invoice_layout_preference', 'classic')
            else:
                # Admin or orphan user - use their own preference
                layout = getattr(creator, 'invoice_layout_preference', 'classic')
        else:
            # Fallback (should never happen due to CASCADE)
            layout = 'classic'
        pdf_buffer = generate_invoice_pdf(invoice, layout=layout)
        
        response = HttpResponse(pdf_buffer.getvalue(), content_type='application/pdf')
        response['Content-Disposition'] = f'attachment; filename="invoice_{invoice.invoice_number}.pdf"'
        
        return response
        
    except Invoice.DoesNotExist:
        return Response({'error': 'Invoice not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsStoreUser])
def invoice_stats_view(request):
    user = request.user

    if user.role == 'admin':
        invoices = Invoice.objects.filter(company__owner=user)
    else:
        user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
        invoices = Invoice.objects.filter(store__id__in=user_stores)

    # Get invoice subsets for different stats
    paid_invoices = invoices.filter(status='paid')
    sent_invoices = invoices.filter(status='sent')
    draft_invoices = invoices.filter(status='draft')

    stats = {
        # Count statistics
        'total_invoices': invoices.count(),
        'draft_invoices': draft_invoices.count(),
        'sent_invoices': sent_invoices.count(),
        'paid_invoices': paid_invoices.count(),

        # Amount statistics
        'total_amount': invoices.aggregate(total=models.Sum('total_amount'))['total'] or 0,
        'total_revenue': paid_invoices.aggregate(total=models.Sum('total_amount'))['total'] or 0,
        'pending_amount': sent_invoices.aggregate(total=models.Sum('total_amount'))['total'] or 0,
        'draft_amount': draft_invoices.aggregate(total=models.Sum('total_amount'))['total'] or 0,

        # Tax breakdown (from paid invoices only)
        'total_tax_collected': (
            (paid_invoices.aggregate(cgst=models.Sum('cgst_amount'))['cgst'] or 0) +
            (paid_invoices.aggregate(sgst=models.Sum('sgst_amount'))['sgst'] or 0) +
            (paid_invoices.aggregate(igst=models.Sum('igst_amount'))['igst'] or 0)
        ),
        'total_cgst': paid_invoices.aggregate(total=models.Sum('cgst_amount'))['total'] or 0,
        'total_sgst': paid_invoices.aggregate(total=models.Sum('sgst_amount'))['total'] or 0,
        'total_igst': paid_invoices.aggregate(total=models.Sum('igst_amount'))['total'] or 0,
    }

    return Response(stats)