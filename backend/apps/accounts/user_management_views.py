from rest_framework import generics, permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter
from django.contrib.auth import get_user_model
from django.db import models
from .permissions import IsAdminUser
from .serializers import UserSerializer, CreateUserSerializer, AdminChangeUserPasswordSerializer

User = get_user_model()


class UserListCreateView(generics.ListCreateAPIView):
    """List and create users - only accessible by admins"""
    permission_classes = [IsAdminUser]
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['role', 'is_active']
    search_fields = ['email', 'first_name', 'last_name', 'username']
    ordering_fields = ['email', 'first_name', 'created_at']
    ordering = ['-created_at']
    
    def get_queryset(self):
        # Admin can only see users they created (plus themselves)
        user = self.request.user
        return User.objects.filter(
            models.Q(created_by=user) | models.Q(id=user.id)
        )
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CreateUserSerializer
        return UserSerializer
    
    def perform_create(self, serializer):
        # Set the current admin as the creator
        serializer.save(created_by=self.request.user)


class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update, or delete a user - only accessible by admins"""
    serializer_class = UserSerializer
    permission_classes = [IsAdminUser]
    
    def get_queryset(self):
        user = self.request.user
        return User.objects.filter(
            models.Q(created_by=user) | models.Q(id=user.id)
        )


@api_view(['GET'])
@permission_classes([IsAdminUser])
def store_users_view(request, store_id):
    """Get all users assigned to a specific store"""
    from apps.stores.models import StoreUser
    
    store_users = StoreUser.objects.filter(
        store_id=store_id,
        store__company__owner=request.user,
        is_active=True
    ).select_related('user')
    
    users_data = []
    for store_user in store_users:
        user_data = UserSerializer(store_user.user).data
        user_data['assigned_at'] = store_user.assigned_at
        users_data.append(user_data)
    
    return Response(users_data)


@api_view(['POST'])
@permission_classes([IsAdminUser])
def assign_user_to_store_view(request):
    """Assign a user to a store"""
    from apps.stores.models import Store, StoreUser
    
    user_id = request.data.get('user_id')
    store_id = request.data.get('store_id')
    
    if not user_id or not store_id:
        return Response(
            {'error': 'user_id and store_id are required'}, 
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        # Verify the admin owns the store
        store = Store.objects.get(id=store_id, company__owner=request.user)
        
        # Verify the admin created the user
        user = User.objects.get(id=user_id, created_by=request.user)
        
        # Create or update store assignment
        store_user, created = StoreUser.objects.get_or_create(
            user=user,
            store=store,
            defaults={'is_active': True}
        )
        
        if not created:
            store_user.is_active = True
            store_user.save()
        
        return Response({
            'message': 'User assigned to store successfully',
            'created': created
        })
    
    except Store.DoesNotExist:
        return Response(
            {'error': 'Store not found or access denied'}, 
            status=status.HTTP_404_NOT_FOUND
        )
    except User.DoesNotExist:
        return Response(
            {'error': 'User not found or access denied'}, 
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['DELETE'])
@permission_classes([IsAdminUser])
def remove_user_from_store_view(request, user_id, store_id):
    """Remove a user from a store"""
    from apps.stores.models import StoreUser
    
    try:
        store_user = StoreUser.objects.get(
            user_id=user_id,
            store_id=store_id,
            store__company__owner=request.user,
            user__created_by=request.user
        )
        
        store_user.is_active = False
        store_user.save()
        
        return Response({'message': 'User removed from store successfully'})
    
    except StoreUser.DoesNotExist:
        return Response(
            {'error': 'Store assignment not found or access denied'}, 
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['POST'])
@permission_classes([IsAdminUser])
def admin_change_user_password_view(request):
    """Allow admin to change user password without knowing old password"""
    serializer = AdminChangeUserPasswordSerializer(data=request.data, context={'request': request})
    
    if serializer.is_valid():
        target_user = serializer.validated_data['target_user']
        new_password = serializer.validated_data['new_password']
        
        # Change the password
        target_user.set_password(new_password)
        target_user.save()
        
        return Response({
            'message': f'Password changed successfully for user {target_user.email}',
            'user_email': target_user.email
        })
    
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAdminUser])
def get_user_stores_view(request, user_id):
    """Get all stores assigned to a specific user"""
    from apps.stores.models import StoreUser
    
    try:
        # Verify the admin created the user
        user = User.objects.get(id=user_id)
        
        # Get all store assignments for this user
        store_assignments = StoreUser.objects.filter(
            user_id=user_id,
            store__company__owner=request.user
        ).select_related('store')
        
        stores_data = []
        for assignment in store_assignments:
            stores_data.append({
                'store_id': assignment.store.id,
                'store_name': assignment.store.name,
                'is_active': assignment.is_active,
                'assigned_at': assignment.assigned_at
            })
        
        return Response(stores_data)

    except User.DoesNotExist:
        return Response(
            {'error': 'User not found'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['POST'])
@permission_classes([IsAdminUser])
def approve_user_view(request, user_id):
    """Approve a pending user"""
    from django.utils import timezone

    try:
        user = User.objects.get(
            id=user_id,
            created_by=request.user
        )

        if user.approval_status == 'approved':
            return Response(
                {'message': 'User is already approved'},
                status=status.HTTP_200_OK
            )

        user.approval_status = 'approved'
        user.approved_by = request.user
        user.approved_at = timezone.now()
        user.save()

        return Response({
            'message': 'User approved successfully',
            'user': UserSerializer(user).data
        })

    except User.DoesNotExist:
        return Response(
            {'error': 'User not found or access denied'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['POST'])
@permission_classes([IsAdminUser])
def reject_user_view(request, user_id):
    """Reject a pending user"""

    try:
        user = User.objects.get(
            id=user_id,
            created_by=request.user
        )

        user.approval_status = 'rejected'
        user.save()

        return Response({
            'message': 'User rejected successfully',
            'user': UserSerializer(user).data
        })

    except User.DoesNotExist:
        return Response(
            {'error': 'User not found or access denied'},
            status=status.HTTP_404_NOT_FOUND
        )


@api_view(['GET'])
@permission_classes([IsAdminUser])
def pending_users_count_view(request):
    """Get count of pending users for current admin"""
    count = User.objects.filter(
        created_by=request.user,
        approval_status='pending'
    ).count()

    return Response({'count': count})