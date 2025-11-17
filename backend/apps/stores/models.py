from django.db import models
from django.conf import settings
from apps.companies.models import Company


class Store(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10)
    phone = models.CharField(max_length=15)
    email = models.EmailField(blank=True, null=True)

    LAYOUT_CHOICES = [
        ('classic', 'Classic Layout'),
        ('traditional', 'Traditional Layout'),
    ]
    invoice_layout_preference = models.CharField(
        max_length=20,
        choices=LAYOUT_CHOICES,
        default='traditional',
        help_text='Invoice PDF layout for all users in this store'
    )

    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='stores'
    )
    
    manager = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='managed_stores'
    )
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.name} ({self.company.name})"
    
    class Meta:
        db_table = 'stores'


class StoreUser(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='store_assignments'
    )
    store = models.ForeignKey(
        Store,
        on_delete=models.CASCADE,
        related_name='users'
    )
    
    is_active = models.BooleanField(default=True)
    assigned_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.user.email} -> {self.store.name}"
    
    class Meta:
        db_table = 'store_users'
        unique_together = ['user', 'store']