from rest_framework import serializers
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from .models import User


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ('email', 'username', 'first_name', 'last_name', 'phone', 'password', 'password_confirm')
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError("Passwords don't match")
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('password_confirm')
        user = User.objects.create_user(**validated_data)
        return user


class UserLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()
    
    def validate(self, attrs):
        email = attrs.get('email')
        password = attrs.get('password')

        if email and password:
            user = authenticate(username=email, password=password)
            if not user:
                raise serializers.ValidationError('Invalid email or password')
            if not user.is_active:
                raise serializers.ValidationError('User account is disabled')

            # For admin users: check email verification
            if user.role == 'admin' and not user.is_verified:
                raise serializers.ValidationError({
                    'non_field_errors': ['EMAIL_NOT_VERIFIED'],
                    'email': email,
                    'message': 'Please verify your email address before logging in. Check your inbox for the verification code.'
                })

            # For store users: check admin approval status
            if user.role == 'store_user':
                if user.approval_status == 'pending':
                    raise serializers.ValidationError({
                        'non_field_errors': ['PENDING_APPROVAL'],
                        'email': email,
                        'message': 'Your account is pending admin approval. Please contact your administrator.'
                    })
                elif user.approval_status == 'rejected':
                    raise serializers.ValidationError({
                        'non_field_errors': ['ACCOUNT_REJECTED'],
                        'email': email,
                        'message': 'Your account access has been denied. Please contact your administrator.'
                    })

            attrs['user'] = user
        else:
            raise serializers.ValidationError('Must include email and password')

        return attrs


class UserSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(read_only=True)
    created_by_name = serializers.CharField(source='created_by.full_name', read_only=True)
    approved_by_name = serializers.CharField(source='approved_by.full_name', read_only=True, allow_null=True)
    assigned_stores = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ('id', 'email', 'username', 'first_name', 'last_name', 'phone', 'role',
                 'invoice_layout_preference', 'full_name', 'created_by', 'created_by_name',
                 'is_verified', 'is_active', 'created_at', 'updated_at', 'assigned_stores',
                 'approval_status', 'approved_by', 'approved_by_name', 'approved_at')
        read_only_fields = ('id', 'created_by', 'created_at', 'updated_at', 'approval_status',
                           'approved_by', 'approved_at')

    def get_assigned_stores(self, obj):
        """Get list of stores assigned to this user"""
        from apps.stores.models import StoreUser

        store_assignments = StoreUser.objects.filter(
            user=obj,
            is_active=True
        ).select_related('store')

        return [{
            'id': assignment.store.id,
            'name': assignment.store.name,
            'assigned_at': assignment.assigned_at.isoformat() if assignment.assigned_at else None
        } for assignment in store_assignments]


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('first_name', 'last_name', 'phone', 'invoice_layout_preference')


class CreateUserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True)
    
    class Meta:
        model = User
        fields = ('email', 'username', 'first_name', 'last_name', 'phone', 'role', 'password', 'password_confirm')
    
    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError("Passwords don't match")

        # Default to store_user if no role specified, only allow store_user
        role = attrs.get('role', 'store_user')
        if role not in ['store_user']:
            attrs['role'] = 'store_user'  # Force to store_user

        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        # Ensure role is store_user
        validated_data['role'] = 'store_user'
        # Set approval_status to pending (requires admin approval)
        validated_data['approval_status'] = 'pending'
        # Set is_verified to True (skip email verification for admin-created users)
        validated_data['is_verified'] = True
        user = User.objects.create_user(**validated_data)
        # NO email is sent to the user - they need admin approval to login
        return user


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])
    
    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Old password is incorrect')
        return value


class AdminChangeUserPasswordSerializer(serializers.Serializer):
    """Serializer for admin to change user password without knowing old password"""
    user_id = serializers.IntegerField(required=True)
    new_password = serializers.CharField(required=True, validators=[validate_password])
    new_password_confirm = serializers.CharField(required=True)
    
    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError("New passwords don't match")
        
        # Verify that the user exists and admin has permission to change their password
        user_id = attrs['user_id']
        request_user = self.context['request'].user
        
        try:
            target_user = User.objects.get(id=user_id)
            
            # Admin can change password of any non-admin user
            if target_user.role == 'admin':
                raise serializers.ValidationError("Cannot change password of admin users")
                
            attrs['target_user'] = target_user
            
        except User.DoesNotExist:
            raise serializers.ValidationError("User not found")
        
        return attrs

class InvoiceSettingsSerializer(serializers.ModelSerializer):
    """Serializer for user invoice settings"""

    class Meta:
        model = User
        fields = (
            # Layout Settings
            'invoice_layout_preference',
            'allow_store_override',
            # Default Values
            'invoice_default_payment_terms',
            'invoice_default_tax_rate',
            'invoice_validity_days',
            'invoice_terms_and_conditions',
            # Numbering Configuration
            'invoice_number_prefix',
            'invoice_number_separator',
            'invoice_sequence_padding',
            'invoice_reset_frequency',
        )

    def validate_invoice_default_payment_terms(self, value):
        """Validate payment terms is a positive number"""
        if value < 0:
            raise serializers.ValidationError("Payment terms must be a positive number")
        return value

    def validate_invoice_default_tax_rate(self, value):
        """Validate tax rate is between 0 and 100"""
        if value < 0 or value > 100:
            raise serializers.ValidationError("Tax rate must be between 0 and 100")
        return value

    def validate_invoice_validity_days(self, value):
        """Validate validity days is a positive number"""
        if value < 0:
            raise serializers.ValidationError("Validity days must be a positive number")
        return value

    def validate_invoice_sequence_padding(self, value):
        """Validate sequence padding is between 1 and 10"""
        if value < 1 or value > 10:
            raise serializers.ValidationError("Sequence padding must be between 1 and 10")
        return value

    def validate_invoice_number_prefix(self, value):
        """Validate prefix is not too long and contains valid characters"""
        if len(value) > 10:
            raise serializers.ValidationError("Prefix cannot be longer than 10 characters")
        if not value.replace('_', '').replace('-', '').isalnum():
            raise serializers.ValidationError("Prefix can only contain letters, numbers, hyphens, and underscores")
        return value

    def validate_invoice_number_separator(self, value):
        """Validate separator is a single character"""
        if len(value) > 5:
            raise serializers.ValidationError("Separator cannot be longer than 5 characters")
        return value
