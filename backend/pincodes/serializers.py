from rest_framework import serializers
from .models import PinCode


class PinCodeSerializer(serializers.ModelSerializer):
    class Meta:
        model = PinCode
        fields = ['pincode', 'post_office', 'city', 'district', 'state']
        read_only_fields = ['pincode', 'post_office', 'city', 'district', 'state']


class PinCodeLookupSerializer(serializers.Serializer):
    pincode = serializers.CharField(max_length=6, min_length=6)
    
    def validate_pincode(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("PIN code must contain only digits")
        return value