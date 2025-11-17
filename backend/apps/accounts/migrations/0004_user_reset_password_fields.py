# Generated manually on 2025-08-25 for password reset functionality

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0003_user_verification_code_user_verification_code_created'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='reset_password_token',
            field=models.CharField(blank=True, max_length=6, null=True),
        ),
        migrations.AddField(
            model_name='user',
            name='reset_password_token_created',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]