from django.db import models


class PinCode(models.Model):
    pincode = models.CharField(max_length=6, unique=True, db_index=True)
    post_office = models.CharField(max_length=100)
    city = models.CharField(max_length=100, db_index=True)
    district = models.CharField(max_length=100)
    state = models.CharField(max_length=100, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.pincode} - {self.city}, {self.state}"
    
    class Meta:
        db_table = 'pincodes'
        ordering = ['pincode']
        indexes = [
            models.Index(fields=['pincode']),
            models.Index(fields=['city']),
            models.Index(fields=['state']),
        ]
