from rest_framework import serializers
from .models import Company


class CompanySerializer(serializers.ModelSerializer):
    owner_name = serializers.CharField(source='owner.get_full_name', read_only=True)
    
    class Meta:
        model = Company
        fields = (
            'id', 'name', 'description', 'address', 'city', 'state', 'pincode',
            'phone', 'email', 'gstin', 'pan', 'state_code', 'website', 'logo',
            'authorized_signature', 'bank_name', 'bank_account_number', 'bank_ifsc',
            'bank_branch', 'owner', 'owner_name', 'is_active', 'created_at', 'updated_at'
        )
        read_only_fields = ('id', 'owner', 'created_at', 'updated_at')
    
    def create(self, validated_data):
        validated_data['owner'] = self.context['request'].user
        return super().create(validated_data)