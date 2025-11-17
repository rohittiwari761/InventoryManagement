from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone
import random
import string


class User(AbstractUser):
    USER_ROLES = (
        ('admin', 'Admin'),
        ('store_user', 'Store User'),
    )

    INVOICE_LAYOUT_CHOICES = (
        ('classic', 'Classic Layout'),
        ('traditional', 'Traditional Layout'),
    )

    INVOICE_RESET_FREQUENCY_CHOICES = (
        ('never', 'Never Reset'),
        ('yearly', 'Reset Yearly'),
        ('monthly', 'Reset Monthly'),
    )

    APPROVAL_STATUS_CHOICES = (
        ('pending', 'Pending Approval'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    )

    email = models.EmailField(unique=True)
    phone = models.CharField(max_length=15, blank=True, null=True)
    role = models.CharField(max_length=20, choices=USER_ROLES, default='admin')

    # Invoice Layout Settings
    invoice_layout_preference = models.CharField(
        max_length=20,
        choices=INVOICE_LAYOUT_CHOICES,
        default='classic',
        help_text='Preferred invoice PDF layout format'
    )
    allow_store_override = models.BooleanField(
        default=True,
        help_text='Allow stores to override user invoice layout preference'
    )

    # Invoice Default Values
    invoice_default_payment_terms = models.IntegerField(
        default=30,
        help_text='Default payment terms in days (e.g., 30 for Net 30)'
    )
    invoice_default_tax_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=18.00,
        help_text='Default GST tax rate percentage (e.g., 18.00 for 18%)'
    )
    invoice_validity_days = models.IntegerField(
        default=30,
        help_text='Default invoice validity period in days'
    )
    invoice_terms_and_conditions = models.TextField(
        blank=True,
        null=True,
        default='1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged on delayed payments.\n3. Subject to jurisdiction only.\n4. All disputes subject to arbitration only.',
        help_text='Default terms and conditions for invoices'
    )

    # Invoice Numbering Configuration
    invoice_number_prefix = models.CharField(
        max_length=10,
        default='INV',
        help_text='Prefix for invoice numbers (e.g., INV, BILL, TXN)'
    )
    invoice_number_separator = models.CharField(
        max_length=5,
        default='/',
        help_text='Separator character for invoice numbers (e.g., /, -, _)'
    )
    invoice_sequence_padding = models.IntegerField(
        default=4,
        help_text='Number of digits for sequence padding (e.g., 4 for 0001)'
    )
    invoice_reset_frequency = models.CharField(
        max_length=20,
        choices=INVOICE_RESET_FREQUENCY_CHOICES,
        default='yearly',
        help_text='How often to reset invoice numbering sequence'
    )
    created_by = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='created_users',
        help_text='Admin who created this user'
    )
    is_verified = models.BooleanField(default=False)
    verification_code = models.CharField(max_length=6, blank=True, null=True)
    verification_code_created = models.DateTimeField(blank=True, null=True)
    reset_password_token = models.CharField(max_length=6, blank=True, null=True)
    reset_password_token_created = models.DateTimeField(blank=True, null=True)

    # Admin Approval System
    approval_status = models.CharField(
        max_length=20,
        choices=APPROVAL_STATUS_CHOICES,
        default='pending',
        help_text='Admin approval status for user access'
    )
    approved_by = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='approved_users',
        help_text='Admin who approved this user'
    )
    approved_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text='Timestamp when user was approved'
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username', 'first_name', 'last_name']
    
    def __str__(self):
        return f"{self.email} ({self.role})"
    
    @property
    def is_admin(self):
        return self.role == 'admin'

    @property
    def full_name(self):
        return f"{self.first_name} {self.last_name}".strip() or self.username
    
    def generate_verification_code(self):
        """Generate a 6-digit verification code"""
        self.verification_code = ''.join(random.choices(string.digits, k=6))
        self.verification_code_created = timezone.now()
        self.save()
        return self.verification_code
    
    def is_verification_code_valid(self):
        """Check if verification code is still valid (30 minutes)"""
        if not self.verification_code_created:
            return False
        
        expiry_time = self.verification_code_created + timezone.timedelta(minutes=30)
        return timezone.now() <= expiry_time
    
    def generate_reset_password_token(self):
        """Generate a 6-digit password reset token"""
        self.reset_password_token = ''.join(random.choices(string.digits, k=6))
        self.reset_password_token_created = timezone.now()
        self.save()
        return self.reset_password_token
    
    def is_reset_password_token_valid(self):
        """Check if password reset token is still valid (15 minutes)"""
        if not self.reset_password_token_created:
            return False
        
        expiry_time = self.reset_password_token_created + timezone.timedelta(minutes=15)
        return timezone.now() <= expiry_time
    
    class Meta:
        db_table = 'users'