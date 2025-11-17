from rest_framework import generics, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.db import models
from apps.accounts.permissions import IsAdminUser, IsStoreUser, CanAccessStore
from .models import Item, StoreInventory, InventoryTransaction, InventoryTransfer, TransferBatch
from .serializers import (
    ItemSerializer, StoreInventorySerializer, InventoryTransactionSerializer, 
    ItemWithInventorySerializer, InventoryTransferSerializer, CreateInventoryTransferSerializer
)


class ItemListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    
    def list(self, request, *args, **kwargs):
        """Override list method to handle different user types"""
        user = request.user
        
        if user.role == 'admin':
            # Admin users get regular item list
            queryset = Item.objects.filter(companies__owner=user).prefetch_related('companies').distinct()
            
            # Apply filters for Item model
            queryset = self.filter_queryset_for_items(queryset)
            
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = ItemSerializer(page, many=True)
                return self.get_paginated_response(serializer.data)
            
            serializer = ItemSerializer(queryset, many=True)
            return Response(serializer.data)
        else:
            # Store users get inventory data
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            queryset = StoreInventory.objects.filter(
                store__id__in=user_stores
            ).select_related('item', 'store', 'company')
            
            # Apply filters for StoreInventory model
            queryset = self.filter_queryset_for_inventory(queryset)
            
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = StoreInventorySerializer(page, many=True)
                return self.get_paginated_response(serializer.data)
            
            serializer = StoreInventorySerializer(queryset, many=True)
            return Response(serializer.data)
    
    def filter_queryset_for_items(self, queryset):
        """Apply filters for Item queryset"""
        # Apply search
        search_param = self.request.query_params.get('search')
        if search_param:
            queryset = queryset.filter(
                models.Q(name__icontains=search_param) |
                models.Q(sku__icontains=search_param) |
                models.Q(hsn_code__icontains=search_param)
            )
        
        # Apply ordering
        ordering_param = self.request.query_params.get('ordering', '-created_at')
        if ordering_param in ['name', '-name', 'price', '-price', 'created_at', '-created_at']:
            queryset = queryset.order_by(ordering_param)
        else:
            queryset = queryset.order_by('-created_at')
        
        return queryset
    
    def filter_queryset_for_inventory(self, queryset):
        """Apply filters for StoreInventory queryset"""
        # Apply search
        search_param = self.request.query_params.get('search')
        if search_param:
            queryset = queryset.filter(
                models.Q(item__name__icontains=search_param) |
                models.Q(item__sku__icontains=search_param)
            )
        
        # Apply ordering
        ordering_param = self.request.query_params.get('ordering', '-last_updated')
        if ordering_param in ['item__name', '-item__name', 'quantity', '-quantity', 'last_updated', '-last_updated']:
            queryset = queryset.order_by(ordering_param)
        else:
            queryset = queryset.order_by('-last_updated')
        
        return queryset
    
    def get_queryset(self):
        # This is required for the create operation
        user = self.request.user
        if user.role == 'admin':
            return Item.objects.filter(companies__owner=user).prefetch_related('companies').distinct()
        else:
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            return StoreInventory.objects.filter(
                store__id__in=user_stores
            ).select_related('item', 'store', 'company')
    
    def get_serializer_class(self):
        user = self.request.user
        if user.role == 'admin':
            return ItemSerializer
        else:
            return StoreInventorySerializer
    
    def perform_create(self, serializer):
        serializer.save()


class ItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ItemWithInventorySerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user

        if user.role == 'admin':
            # Admins see all items from companies they own
            return Item.objects.filter(
                companies__owner=user
            ).prefetch_related('companies').distinct()
        else:
            # Store users only see items that are available in their assigned stores
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            # Get items that have inventory in the user's stores
            item_ids = StoreInventory.objects.filter(
                store__id__in=user_stores
            ).values_list('item', flat=True).distinct()
            return Item.objects.filter(
                id__in=item_ids, is_active=True
            ).prefetch_related('companies')


class StoreInventoryListCreateView(generics.ListCreateAPIView):
    serializer_class = StoreInventorySerializer
    permission_classes = [IsStoreUser]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['store', 'item__companies']
    search_fields = ['item__name', 'item__sku']
    ordering_fields = ['item__name', 'quantity', 'last_updated']
    ordering = ['-last_updated']

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            user_companies = user.companies.values_list('id', flat=True)
            return StoreInventory.objects.filter(
                item__companies__id__in=user_companies
            ).select_related('item', 'store', 'company')
        else:
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            return StoreInventory.objects.filter(
                store__id__in=user_stores
            ).select_related('item', 'store', 'company')


class StoreInventoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = StoreInventorySerializer
    permission_classes = [IsStoreUser, CanAccessStore]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            user_companies = user.companies.values_list('id', flat=True)
            return StoreInventory.objects.filter(
                item__companies__id__in=user_companies
            ).select_related('item', 'store', 'company')
        else:
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            return StoreInventory.objects.filter(
                store__id__in=user_stores
            ).select_related('item', 'store', 'company')


class InventoryTransactionListCreateView(generics.ListCreateAPIView):
    serializer_class = InventoryTransactionSerializer
    permission_classes = [IsStoreUser]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['transaction_type', 'inventory__store']
    search_fields = ['inventory__item__name', 'notes']
    ordering_fields = ['created_at']
    ordering = ['-created_at']
    
    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            user_companies = user.companies.values_list('id', flat=True)
            return InventoryTransaction.objects.filter(
                inventory__item__companies__id__in=user_companies
            ).select_related('inventory__item', 'inventory__store', 'inventory__company')
        else:
            user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
            return InventoryTransaction.objects.filter(
                inventory__store__id__in=user_stores
            ).select_related('inventory__item', 'inventory__store', 'inventory__company')
    
    def perform_create(self, serializer):
        transaction = serializer.save()
        
        inventory = transaction.inventory
        if transaction.transaction_type in ['add', 'adjustment']:
            if transaction.quantity > 0:
                inventory.quantity += transaction.quantity
            else:
                inventory.quantity += transaction.quantity
        elif transaction.transaction_type in ['remove', 'sale']:
            inventory.quantity -= abs(transaction.quantity)
        
        inventory.save()


@api_view(['GET'])
@permission_classes([IsStoreUser])
def low_stock_items_view(request):
    user = request.user
    if user.role == 'admin':
        user_companies = user.companies.values_list('id', flat=True)
        low_stock = StoreInventory.objects.filter(
            item__companies__id__in=user_companies,
            quantity__lte=models.F('min_stock_level')
        ).select_related('item', 'store', 'company')
    else:
        user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
        low_stock = StoreInventory.objects.filter(
            store__id__in=user_stores,
            quantity__lte=models.F('min_stock_level')
        ).select_related('item', 'store', 'company')

    serializer = StoreInventorySerializer(low_stock, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsStoreUser])
def store_inventory_view(request, store_id):
    user = request.user

    try:
        # Get the store to check its company
        from apps.stores.models import Store
        from django.core.paginator import Paginator, EmptyPage

        store = Store.objects.select_related('company').get(id=store_id)

        if user.role == 'admin':
            # Admin sees all inventory from their companies in this store (multi-company marketplace)
            user_companies = user.companies.values_list('id', flat=True)
            store_inventory = StoreInventory.objects.filter(
                store_id=store_id,
                company__id__in=user_companies  # Show all admin's companies' items in this store
            ).select_related('item', 'company').order_by('-id')
        else:
            if not user.store_assignments.filter(store_id=store_id, is_active=True).exists():
                return Response({'error': 'Access denied to this store'}, status=status.HTTP_403_FORBIDDEN)
            store_inventory = StoreInventory.objects.filter(
                store_id=store_id
            ).select_related('item', 'store', 'company').order_by('-id')

        # Search filtering
        search_query = request.query_params.get('search', '').strip()
        if search_query:
            from django.db.models import Q
            store_inventory = store_inventory.filter(
                Q(item__name__icontains=search_query) |
                Q(item__sku__icontains=search_query) |
                Q(company__name__icontains=search_query)
            )

        # Deduplicate BEFORE pagination (more efficient)
        seen_keys = set()
        unique_inventory_qs = []
        for inv in store_inventory:
            key = f"{inv.item_id}_{inv.company_id}"
            if key not in seen_keys:
                seen_keys.add(key)
                unique_inventory_qs.append(inv.id)

        # Get deduplicated queryset
        store_inventory = StoreInventory.objects.filter(
            id__in=unique_inventory_qs
        ).select_related('item', 'store', 'company').order_by('-id')

        # Pagination
        page_number = request.query_params.get('page', 1)
        page_size = request.query_params.get('page_size', 100)

        try:
            page_size = min(int(page_size), 100)  # Max 100 items per page
        except (ValueError, TypeError):
            page_size = 100

        paginator = Paginator(store_inventory, page_size)

        try:
            page_obj = paginator.page(page_number)
        except EmptyPage:
            page_obj = paginator.page(paginator.num_pages)

        serializer = StoreInventorySerializer(page_obj.object_list, many=True)

        # Build pagination URLs
        request_url = request.build_absolute_uri().split('?')[0]
        next_url = None
        previous_url = None

        # Build query parameters
        params = f"page_size={page_size}"
        if search_query:
            params += f"&search={search_query}"

        if page_obj.has_next():
            next_url = f"{request_url}?page={page_obj.next_page_number()}&{params}"

        if page_obj.has_previous():
            previous_url = f"{request_url}?page={page_obj.previous_page_number()}&{params}"

        return Response({
            'count': paginator.count,
            'next': next_url,
            'previous': previous_url,
            'results': serializer.data
        })

    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def admin_add_stock_view(request):
    """Allow admin to add stock to any store in their company"""
    try:
        item_id = request.data.get('item_id')
        store_id = request.data.get('store_id')
        company_id = request.data.get('company_id')
        quantity = request.data.get('quantity')
        notes = request.data.get('notes', 'Admin stock addition')

        if not all([item_id, store_id, company_id, quantity]):
            return Response(
                {'error': 'item_id, store_id, company_id, and quantity are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verify admin owns the store's company
        from apps.stores.models import Store
        from apps.companies.models import Company
        store = Store.objects.get(id=store_id, company__owner=request.user)
        company = Company.objects.get(id=company_id, owner=request.user)

        # Verify item belongs to the specified company
        item = Item.objects.filter(id=item_id, companies=company).first()
        if not item:
            raise Item.DoesNotExist()

        # Get or create store inventory with company
        inventory, created = StoreInventory.objects.get_or_create(
            item=item,
            store=store,
            company=company,
            defaults={'quantity': 0, 'min_stock_level': 0, 'max_stock_level': 0}
        )

        # Create transaction record
        transaction = InventoryTransaction.objects.create(
            inventory=inventory,
            transaction_type='add',
            quantity=abs(float(quantity)),
            notes=notes
        )

        # Update inventory quantity
        from decimal import Decimal
        inventory.quantity += Decimal(str(abs(float(quantity))))
        inventory.save()

        return Response({
            'message': 'Stock added successfully',
            'inventory_id': inventory.id,
            'new_quantity': inventory.quantity,
            'transaction_id': transaction.id
        })
        
    except Store.DoesNotExist:
        return Response(
            {'error': 'Store not found or access denied'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Item.DoesNotExist:
        return Response(
            {'error': 'Item not found or access denied'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def admin_update_stock_view(request):
    """Allow admin to set stock quantity for any store in their company"""
    try:
        item_id = request.data.get('item_id')
        store_id = request.data.get('store_id')
        company_id = request.data.get('company_id')
        new_quantity = request.data.get('quantity')
        notes = request.data.get('notes', 'Admin stock adjustment')

        if not all([item_id, store_id, company_id]) or new_quantity is None:
            return Response(
                {'error': 'item_id, store_id, company_id, and quantity are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Verify admin owns the store's company
        from apps.stores.models import Store
        from apps.companies.models import Company
        store = Store.objects.get(id=store_id, company__owner=request.user)
        company = Company.objects.get(id=company_id, owner=request.user)

        # Verify item belongs to the specified company
        item = Item.objects.filter(id=item_id, companies=company).first()
        if not item:
            raise Item.DoesNotExist()

        # Get or create store inventory with company
        inventory, created = StoreInventory.objects.get_or_create(
            item=item,
            store=store,
            company=company,
            defaults={'quantity': 0, 'min_stock_level': 0, 'max_stock_level': 0}
        )
        
        from decimal import Decimal
        old_quantity = inventory.quantity
        new_quantity = Decimal(str(float(new_quantity)))
        quantity_change = new_quantity - old_quantity
        
        # Create transaction record
        transaction_type = 'adjustment'
        if quantity_change > 0:
            transaction_type = 'add'
        elif quantity_change < 0:
            transaction_type = 'remove'
        
        if quantity_change != 0:
            transaction = InventoryTransaction.objects.create(
                inventory=inventory,
                transaction_type=transaction_type,
                quantity=abs(quantity_change),
                notes=f"{notes} (Old: {old_quantity}, New: {new_quantity})"
            )
        
        # Update inventory quantity
        inventory.quantity = new_quantity
        inventory.save()
        
        return Response({
            'message': 'Stock updated successfully',
            'inventory_id': inventory.id,
            'old_quantity': old_quantity,
            'new_quantity': new_quantity,
            'quantity_change': quantity_change,
            'transaction_id': transaction.id if quantity_change != 0 else None
        })
        
    except Store.DoesNotExist:
        return Response(
            {'error': 'Store not found or access denied'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Item.DoesNotExist:
        return Response(
            {'error': 'Item not found or access denied'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAdminUser])
def admin_store_stock_view(request, store_id):
    """Get all stock items for a specific store (admin only) with pagination and search"""
    try:
        # Verify admin owns the store's company
        from apps.stores.models import Store
        from django.core.paginator import Paginator, EmptyPage
        from django.db.models import Q

        store = Store.objects.get(id=store_id, company__owner=request.user)

        # Get search parameter
        search_query = request.query_params.get('search', '').strip()

        # Get all inventory for this store with company information
        inventories = StoreInventory.objects.filter(store=store).select_related('item', 'company')

        # Apply search filter if provided
        if search_query:
            inventories = inventories.filter(
                Q(item__name__icontains=search_query) |
                Q(item__sku__icontains=search_query) |
                Q(company__name__icontains=search_query)
            )

        # Serialize existing inventory
        inventory_data = []
        for inventory in inventories:
            inventory_data.append({
                'id': inventory.id,
                'item_id': inventory.item.id,
                'item_name': inventory.item.name,
                'item_sku': inventory.item.sku,
                'item_unit': inventory.item.unit,
                'item_price': inventory.item.price,
                'company': inventory.company.id,
                'company_name': inventory.company.name,
                'quantity': inventory.quantity,
                'min_stock_level': inventory.min_stock_level,
                'max_stock_level': inventory.max_stock_level,
                'is_low_stock': inventory.is_low_stock,
                'last_updated': inventory.last_updated,
                'has_inventory': True
            })

        # Deduplicate by (item_id, company_id) to prevent duplicate entries
        unique_inventory = {}
        for inv_data in inventory_data:
            key = (inv_data['item_id'], inv_data['company'])
            # Keep the entry with higher quantity or the first one found
            if key not in unique_inventory or inv_data['quantity'] > unique_inventory[key]['quantity']:
                unique_inventory[key] = inv_data

        inventory_list = list(unique_inventory.values())

        # Pagination
        page_number = request.query_params.get('page', 1)
        page_size = request.query_params.get('page_size', 100)

        try:
            page_size = min(int(page_size), 100)  # Max 100 items per page
        except (ValueError, TypeError):
            page_size = 100

        paginator = Paginator(inventory_list, page_size)

        try:
            page_obj = paginator.page(page_number)
        except EmptyPage:
            page_obj = paginator.page(paginator.num_pages)

        # Build pagination URLs
        request_url = request.build_absolute_uri().split('?')[0]
        next_url = None
        previous_url = None

        # Build query parameters
        params = f"page_size={page_size}"
        if search_query:
            params += f"&search={search_query}"

        if page_obj.has_next():
            next_url = f"{request_url}?page={page_obj.next_page_number()}&{params}"

        if page_obj.has_previous():
            previous_url = f"{request_url}?page={page_obj.previous_page_number()}&{params}"

        return Response({
            'store_id': store.id,
            'store_name': store.name,
            'count': paginator.count,
            'next': next_url,
            'previous': previous_url,
            'inventory': page_obj.object_list
        })
        
    except Store.DoesNotExist:
        return Response(
            {'error': 'Store not found or access denied'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class InventoryTransferListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAdminUser]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['status', 'from_store', 'to_store', 'item']
    search_fields = ['item__name', 'notes']
    ordering_fields = ['created_at', 'completed_at']
    ordering = ['-created_at']
    
    def get_queryset(self):
        user = self.request.user
        # Only show transfers for stores owned by the admin
        user_companies = user.companies.values_list('id', flat=True)
        return InventoryTransfer.objects.filter(
            from_store__company__id__in=user_companies,
            to_store__company__id__in=user_companies
        )
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CreateInventoryTransferSerializer
        return InventoryTransferSerializer
    
    def perform_create(self, serializer):
        transfer = serializer.save(initiated_by=self.request.user)
        # Immediately process the transfer
        self._process_transfer(transfer)
    
    def _process_transfer(self, transfer):
        """Process the inventory transfer"""
        from decimal import Decimal
        from django.utils import timezone
        from django.db import transaction

        try:
            with transaction.atomic():
                # Get source inventory (must include company)
                source_inventory = StoreInventory.objects.get(
                    item=transfer.item,
                    store=transfer.from_store,
                    company=transfer.company
                )

                # Get or create destination inventory (must include company)
                dest_inventory, created = StoreInventory.objects.get_or_create(
                    item=transfer.item,
                    store=transfer.to_store,
                    company=transfer.company,
                    defaults={'quantity': Decimal('0.00')}
                )

                # Update quantities
                source_inventory.quantity -= Decimal(str(transfer.quantity))
                dest_inventory.quantity += Decimal(str(transfer.quantity))

                # Save inventories
                source_inventory.save()
                dest_inventory.save()

                # Create transaction records
                InventoryTransaction.objects.create(
                    inventory=source_inventory,
                    transaction_type='transfer',
                    quantity=-float(transfer.quantity),
                    notes=f'Transfer to {transfer.to_store.name}: {transfer.notes or ""}'
                )

                InventoryTransaction.objects.create(
                    inventory=dest_inventory,
                    transaction_type='transfer',
                    quantity=float(transfer.quantity),
                    notes=f'Transfer from {transfer.from_store.name}: {transfer.notes or ""}'
                )

                # Mark transfer as completed
                transfer.status = 'completed'
                transfer.completed_at = timezone.now()
                transfer.save()

        except Exception as e:
            # Mark transfer as cancelled if it fails
            transfer.status = 'cancelled'
            transfer.save()
            raise e


class InventoryTransferDetailView(generics.RetrieveAPIView):
    permission_classes = [IsAdminUser]
    serializer_class = InventoryTransferSerializer
    
    def get_queryset(self):
        user = self.request.user
        user_companies = user.companies.values_list('id', flat=True)
        return InventoryTransfer.objects.filter(
            from_store__company__id__in=user_companies,
            to_store__company__id__in=user_companies
        )


@api_view(['GET'])
@permission_classes([IsAdminUser])
def inventory_transfer_history(request):
    """Get transfer history for admin's stores - returns batches and standalone transfers"""
    from .serializers import TransferBatchSerializer
    user = request.user
    user_companies = user.companies.values_list('id', flat=True)

    # Get batches (grouped transfers)
    batches = TransferBatch.objects.filter(
        from_store__company__id__in=user_companies,
        to_store__company__id__in=user_companies
    ).prefetch_related('transfers', 'transfers__item', 'transfers__company').order_by('-created_at')[:50]

    # Get standalone transfers (not part of any batch)
    standalone_transfers = InventoryTransfer.objects.filter(
        from_store__company__id__in=user_companies,
        to_store__company__id__in=user_companies,
        batch__isnull=True
    ).order_by('-created_at')[:50]

    batch_serializer = TransferBatchSerializer(batches, many=True)
    transfer_serializer = InventoryTransferSerializer(standalone_transfers, many=True)

    # Combine and sort by created_at
    combined = []
    for batch in batch_serializer.data:
        combined.append({'type': 'batch', 'data': batch})
    for transfer in transfer_serializer.data:
        combined.append({'type': 'transfer', 'data': transfer})

    # Sort by created_at descending
    combined.sort(key=lambda x: x['data']['created_at'], reverse=True)

    return Response(combined[:50])


@api_view(['POST'])
@permission_classes([IsAdminUser])
def create_batch_transfer(request):
    """Create a batch transfer of multiple items"""
    from decimal import Decimal
    from django.utils import timezone
    from django.db import transaction

    # Validate required fields
    from_store_id = request.data.get('from_store_id')
    to_store_id = request.data.get('to_store_id')
    items_data = request.data.get('items', [])
    notes = request.data.get('notes', '')

    if not from_store_id or not to_store_id:
        return Response({'error': 'from_store_id and to_store_id are required'}, status=status.HTTP_400_BAD_REQUEST)

    if not items_data:
        return Response({'error': 'items list cannot be empty'}, status=status.HTTP_400_BAD_REQUEST)

    # PRE-VALIDATION: Validate ALL items BEFORE creating any transfers
    validation_errors = []

    for idx, item_data in enumerate(items_data):
        item_id = item_data.get('item_id')
        company_id = item_data.get('company_id')
        quantity = item_data.get('quantity')

        # Check required fields
        if not all([item_id, company_id, quantity]):
            validation_errors.append({
                "item_index": idx,
                "item_id": item_id,
                "error": "Missing required fields (item_id, company_id, or quantity)"
            })
            continue

        # Check quantity is positive
        try:
            qty_decimal = Decimal(str(quantity))
            if qty_decimal <= 0:
                validation_errors.append({
                    "item_index": idx,
                    "item_id": item_id,
                    "error": f"Quantity must be greater than 0 (got {quantity})"
                })
                continue
        except (ValueError, TypeError) as e:
            validation_errors.append({
                "item_index": idx,
                "item_id": item_id,
                "error": f"Invalid quantity value: {quantity}"
            })
            continue

        # Check source inventory exists and has enough stock
        try:
            source_inv = StoreInventory.objects.select_related('item').get(
                item_id=item_id,
                store_id=from_store_id,
                company_id=company_id
            )

            if source_inv.quantity < qty_decimal:
                validation_errors.append({
                    "item_index": idx,
                    "item_id": item_id,
                    "item_name": source_inv.item.name,
                    "error": f"Insufficient inventory. Available: {source_inv.quantity}, Requested: {quantity}"
                })

        except StoreInventory.DoesNotExist:
            validation_errors.append({
                "item_index": idx,
                "item_id": item_id,
                "error": "Item not found in source store for this company"
            })

    # If ANY validation errors, return them and don't create transfers
    if validation_errors:
        return Response({
            'error': 'Transfer validation failed',
            'message': f'{len(validation_errors)} of {len(items_data)} items failed validation',
            'details': validation_errors,
            'failed_items': len(validation_errors),
            'total_items': len(items_data)
        }, status=status.HTTP_400_BAD_REQUEST)

    # All validation passed - proceed with creating transfers
    try:
        with transaction.atomic():
            # Create batch record
            batch = TransferBatch.objects.create(
                from_store_id=from_store_id,
                to_store_id=to_store_id,
                notes=notes,
                initiated_by=request.user
            )

            successful_transfers = []

            # Create individual transfers
            for item_data in items_data:
                item_id = item_data.get('item_id')
                company_id = item_data.get('company_id')
                quantity = item_data.get('quantity')

                if not all([item_id, company_id, quantity]):
                    continue

                # Create transfer record
                transfer = InventoryTransfer.objects.create(
                    batch=batch,
                    item_id=item_id,
                    company_id=company_id,
                    from_store_id=from_store_id,
                    to_store_id=to_store_id,
                    quantity=Decimal(str(quantity)),
                    notes=notes,
                    initiated_by=request.user
                )

                # Process transfer immediately
                try:
                    # Get source inventory
                    source_inventory = StoreInventory.objects.get(
                        item_id=item_id,
                        store_id=from_store_id,
                        company_id=company_id
                    )

                    # Get or create destination inventory
                    dest_inventory, created = StoreInventory.objects.get_or_create(
                        item_id=item_id,
                        store_id=to_store_id,
                        company_id=company_id,
                        defaults={'quantity': Decimal('0.00')}
                    )

                    # SAFETY CHECK: Verify source has enough inventory (final safeguard)
                    qty_decimal = Decimal(str(quantity))
                    if source_inventory.quantity < qty_decimal:
                        raise ValueError(
                            f"Insufficient inventory for {source_inventory.item.name}. "
                            f"Available: {source_inventory.quantity}, Requested: {quantity}"
                        )

                    # Update quantities (now safe - verified above)
                    source_inventory.quantity -= qty_decimal
                    dest_inventory.quantity += qty_decimal

                    # Save inventories
                    source_inventory.save()
                    dest_inventory.save()

                    # Create transaction records
                    InventoryTransaction.objects.create(
                        inventory=source_inventory,
                        transaction_type='transfer',
                        quantity=-float(quantity),
                        notes=f'Batch transfer to {dest_inventory.store.name}: {notes}'
                    )

                    InventoryTransaction.objects.create(
                        inventory=dest_inventory,
                        transaction_type='transfer',
                        quantity=float(quantity),
                        notes=f'Batch transfer from {source_inventory.store.name}: {notes}'
                    )

                    # Mark transfer as completed
                    transfer.status = 'completed'
                    transfer.completed_at = timezone.now()
                    transfer.save()

                    successful_transfers.append(transfer.id)

                except Exception as e:
                    # Mark this individual transfer as cancelled
                    transfer.status = 'cancelled'
                    transfer.save()

            # Mark batch as completed
            batch.status = 'completed'
            batch.completed_at = timezone.now()
            batch.save()

            return Response({
                'message': f'{len(successful_transfers)} items transferred successfully',
                'batch_id': str(batch.batch_id),
                'transfer_count': len(successful_transfers),
                'total_items': len(items_data)
            }, status=status.HTTP_201_CREATED)

    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)