# Generated manually on 2025-08-25 for email verification

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0002_user_created_by_alter_user_role'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='verification_code',
            field=models.CharField(blank=True, max_length=6, null=True),
        ),
        migrations.AddField(
            model_name='user',
            name='verification_code_created',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]