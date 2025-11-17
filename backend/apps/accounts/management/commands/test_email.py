from django.core.management.base import BaseCommand
from django.conf import settings
from apps.accounts.email_service import email_service


class Command(BaseCommand):
    help = 'Test email configuration using Brevo API'

    def add_arguments(self, parser):
        parser.add_argument('--to', type=str, help='Email address to send test email to', default='tiwari.rohit761@gmail.com')

    def handle(self, *args, **options):
        to_email = options['to']

        self.stdout.write('=' * 60)
        self.stdout.write('Testing Brevo Email Service Configuration')
        self.stdout.write('=' * 60)

        # Check configuration
        self.stdout.write(f'\n📧 Email Service: Brevo API')
        self.stdout.write(f'✓ API Key Configured: {email_service.is_configured}')
        self.stdout.write(f'✓ From Email: {settings.DEFAULT_FROM_EMAIL}')

        if not email_service.is_configured:
            self.stdout.write(self.style.ERROR('\n❌ Brevo API key is not configured!'))
            self.stdout.write(self.style.WARNING('Please set BREVO_API_KEY in your environment variables or .env file'))
            return

        # Test sending verification-style email
        verification_code = "123456"

        self.stdout.write(f'\n📤 Sending test email to: {to_email}')
        self.stdout.write(f'📝 Test verification code: {verification_code}\n')

        try:
            # Create a mock user object for testing
            class MockUser:
                def __init__(self):
                    self.email = to_email
                    self.first_name = "Test"
                    self.last_name = "User"

            mock_user = MockUser()

            # Send verification email using our service
            success, message = email_service.send_verification_email(mock_user, verification_code)

            if success:
                self.stdout.write(self.style.SUCCESS(f'\n✅ Email sent successfully!'))
                self.stdout.write(f'📬 Message: {message}')
                self.stdout.write(f'\n🔍 Check your email inbox at: {to_email}')
                self.stdout.write(f'🗑️  Don\'t forget to check spam folder!')
                self.stdout.write(f'\n📝 Verification code in email: {verification_code}')
            else:
                self.stdout.write(self.style.ERROR(f'\n❌ Failed to send email!'))
                self.stdout.write(f'Error: {message}')

            # Also test password reset email
            self.stdout.write(f'\n\n📤 Testing password reset email...')
            reset_token = "987654"

            success, message = email_service.send_password_reset_email(mock_user, reset_token)

            if success:
                self.stdout.write(self.style.SUCCESS(f'✅ Password reset email sent successfully!'))
                self.stdout.write(f'📬 Message: {message}')
                self.stdout.write(f'📝 Reset token in email: {reset_token}')
            else:
                self.stdout.write(self.style.ERROR(f'❌ Failed to send password reset email!'))
                self.stdout.write(f'Error: {message}')

            self.stdout.write('\n' + '=' * 60)
            self.stdout.write('Test Complete!')
            self.stdout.write('=' * 60 + '\n')

        except Exception as e:
            self.stdout.write(self.style.ERROR(f'\n❌ Unexpected error: {str(e)}'))
            import traceback
            self.stdout.write(traceback.format_exc())