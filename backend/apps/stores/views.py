from rest_framework import generics, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from apps.accounts.permissions import IsAdminUser, IsStoreUser, CanAccessStore, CanAccessCompany
from .models import Store, StoreUser
from .serializers import StoreSerializer, StoreUserSerializer, StoreWithUsersSerializer


class StoreListCreateView(generics.ListCreateAPIView):
    serializer_class = StoreSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['is_active', 'company', 'state']
    search_fields = ['name', 'city', 'phone']
    ordering_fields = ['name', 'created_at']
    ordering = ['-created_at']
    
    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            # For admin users, return only stores from companies they own
            if hasattr(user, 'companies') and user.companies.exists():
                # If user owns companies, show stores from their companies
                user_companies = user.companies.values_list('id', flat=True)
                return Store.objects.filter(company__id__in=user_companies)
            else:
                # If user doesn't own any companies, show no stores
                return Store.objects.none()
        else:
            # For non-admin users, show stores they have access to via assignments
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            return Store.objects.filter(id__in=user_stores)


class StoreDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = StoreWithUsersSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            # For admin users, return only stores from companies they own
            if hasattr(user, 'companies') and user.companies.exists():
                # If user owns companies, show stores from their companies
                user_companies = user.companies.values_list('id', flat=True)
                return Store.objects.filter(company__id__in=user_companies)
            else:
                # If user doesn't own any companies, show no stores
                return Store.objects.none()
        else:
            # For non-admin users, show stores they have access to via assignments
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            return Store.objects.filter(id__in=user_stores)


class StoreUserListCreateView(generics.ListCreateAPIView):
    serializer_class = StoreUserSerializer
    permission_classes = [IsAdminUser]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['is_active', 'store']
    search_fields = ['user__email', 'user__first_name', 'user__last_name']
    ordering = ['-assigned_at']
    
    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            user_companies = user.companies.values_list('id', flat=True)
            return StoreUser.objects.filter(store__company__id__in=user_companies)
        return StoreUser.objects.none()


class StoreUserDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = StoreUserSerializer
    permission_classes = [IsAdminUser]
    
    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            user_companies = user.companies.values_list('id', flat=True)
            return StoreUser.objects.filter(store__company__id__in=user_companies)
        return StoreUser.objects.none()


@api_view(['GET'])
@permission_classes([IsStoreUser])
def my_stores_view(request):
    user = request.user
    if user.role == 'admin':
        stores = Store.objects.filter(company__owner=user, is_active=True)
    else:
        user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
        stores = Store.objects.filter(id__in=user_stores, is_active=True)
    
    serializer = StoreSerializer(stores, many=True)
    return Response(serializer.data)