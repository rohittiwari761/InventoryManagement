from django.db import models
from django.conf import settings


class Company(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    address = models.TextField()
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    pincode = models.CharField(max_length=10)
    phone = models.CharField(max_length=15)
    email = models.EmailField()
    gstin = models.CharField(max_length=15, unique=True)
    pan = models.CharField(max_length=10)
    state_code = models.CharField(max_length=2, help_text="GST State Code", default="10")
    logo = models.ImageField(upload_to='company_logos/', blank=True, null=True)
    authorized_signature = models.ImageField(upload_to='company_signatures/', blank=True, null=True)
    website = models.URLField(blank=True, null=True)
    
    # Banking Details
    bank_name = models.CharField(max_length=100, blank=True, null=True)
    bank_account_number = models.CharField(max_length=20, blank=True, null=True)
    bank_ifsc = models.CharField(max_length=11, blank=True, null=True)
    bank_branch = models.CharField(max_length=100, blank=True, null=True)
    
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='companies'
    )
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return self.name
    
    class Meta:
        db_table = 'companies'
        verbose_name_plural = 'Companies'