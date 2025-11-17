from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Store, StoreUser
from apps.companies.serializers import CompanySerializer

User = get_user_model()


class StoreSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)
    manager_name = serializers.CharField(source='manager.get_full_name', read_only=True)
    
    class Meta:
        model = Store
        fields = (
            'id', 'name', 'description', 'address', 'city', 'state', 'pincode',
            'phone', 'email', 'invoice_layout_preference', 'company', 'company_name',
            'manager', 'manager_name', 'is_active', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class StoreUserSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.get_full_name', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    store_name = serializers.CharField(source='store.name', read_only=True)
    
    class Meta:
        model = StoreUser
        fields = (
            'id', 'user', 'user_name', 'user_email', 'store', 'store_name',
            'is_active', 'assigned_at'
        )
        read_only_fields = ('id', 'assigned_at')


class StoreWithUsersSerializer(StoreSerializer):
    users = StoreUserSerializer(many=True, read_only=True)
    
    class Meta(StoreSerializer.Meta):
        fields = StoreSerializer.Meta.fields + ('users',)