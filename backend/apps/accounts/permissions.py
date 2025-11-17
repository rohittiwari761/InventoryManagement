from rest_framework import permissions


class IsAdminUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return (
            request.user and 
            request.user.is_authenticated and 
            request.user.role == 'admin'
        )


class IsStoreUser(permissions.BasePermission):
    def has_permission(self, request, view):
        return (
            request.user and
            request.user.is_authenticated and
            request.user.role in ['admin', 'store_user']
        )


class IsOwnerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        
        if hasattr(obj, 'owner'):
            return obj.owner == request.user
        elif hasattr(obj, 'created_by'):
            return obj.created_by == request.user
        elif hasattr(obj, 'user'):
            return obj.user == request.user
        
        return False


class CanAccessStore(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        user = request.user
        
        if user.role == 'admin':
            return True
        
        if hasattr(obj, 'store'):
            store = obj.store
        elif hasattr(obj, 'stores'):
            return any(
                user.store_assignments.filter(store=s, is_active=True).exists() 
                for s in obj.stores.all()
            )
        else:
            store = obj
        
        return user.store_assignments.filter(store=store, is_active=True).exists()


class CanAccessCompany(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        user = request.user
        
        if hasattr(obj, 'company'):
            company = obj.company
        elif hasattr(obj, 'owner'):
            if obj.owner == user:
                return True
            company = obj
        else:
            company = obj
        
        if user.role == 'admin' and company.owner == user:
            return True
        
        user_stores = user.store_assignments.filter(is_active=True).values_list('store', flat=True)
        return company.stores.filter(id__in=user_stores).exists()