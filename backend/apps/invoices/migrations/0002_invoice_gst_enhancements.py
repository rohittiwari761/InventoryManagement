# Generated migration for GST compliance enhancements

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('invoices', '0001_initial'),
    ]

    operations = [
        # Customer enhancements
        migrations.AddField(
            model_name='customer',
            name='state_code',
            field=models.CharField(blank=True, help_text='GST State Code', max_length=2, null=True),
        ),
        migrations.AddField(
            model_name='customer',
            name='customer_type',
            field=models.CharField(choices=[('registered', 'Registered'), ('unregistered', 'Unregistered'), ('composition', 'Composition'), ('export', 'Export')], default='registered', max_length=20),
        ),
        
        # Invoice enhancements
        migrations.AddField(
            model_name='invoice',
            name='place_of_supply',
            field=models.CharField(help_text='Place of supply with state name', max_length=100, default=''),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='invoice',
            name='reverse_charge',
            field=models.CharField(choices=[('Yes', 'Yes'), ('No', 'No')], default='No', max_length=5),
        ),
        migrations.AddField(
            model_name='invoice',
            name='invoice_type',
            field=models.CharField(choices=[('tax_invoice', 'Tax Invoice'), ('bill_of_supply', 'Bill of Supply'), ('export_invoice', 'Export Invoice')], default='tax_invoice', max_length=20),
        ),
        migrations.AddField(
            model_name='invoice',
            name='cess_amount',
            field=models.DecimalField(decimal_places=2, default=0.0, max_digits=12),
        ),
        migrations.AddField(
            model_name='invoice',
            name='tcs_amount',
            field=models.DecimalField(decimal_places=2, default=0.0, help_text='Tax Collected at Source', max_digits=12),
        ),
        migrations.AddField(
            model_name='invoice',
            name='round_off',
            field=models.DecimalField(decimal_places=2, default=0.0, max_digits=5),
        ),
        migrations.AddField(
            model_name='invoice',
            name='terms_and_conditions',
            field=models.TextField(default='1. Goods once sold will not be taken back.\\n2. Interest @ 18% p.a. will be charged on delayed payments.\\n3. Subject to jurisdiction only.\\n4. All disputes subject to arbitration only.'),
        ),
        migrations.AddField(
            model_name='invoice',
            name='amount_in_words',
            field=models.CharField(blank=True, max_length=500, null=True),
        ),
        
        # Invoice Item enhancements
        migrations.AddField(
            model_name='invoiceitem',
            name='cess_rate',
            field=models.DecimalField(decimal_places=2, default=0.0, max_digits=5),
        ),
        migrations.AddField(
            model_name='invoiceitem',
            name='cess_amount',
            field=models.DecimalField(decimal_places=2, default=0.0, max_digits=12),
        ),
    ]