"""
Email service using Brevo (Sendinblue) API
This provides a robust email sending solution with proper error handling
"""

import logging
from django.conf import settings
import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException

logger = logging.getLogger(__name__)


class BrevoEmailService:
    """Service class for sending emails via Brevo API"""

    def __init__(self):
        """Initialize Brevo API client"""
        self.configuration = sib_api_v3_sdk.Configuration()
        # Get API key from settings, fallback to None
        self.api_key = getattr(settings, 'BREVO_API_KEY', None)

        if self.api_key:
            self.configuration.api_key['api-key'] = self.api_key
            self.api_instance = sib_api_v3_sdk.TransactionalEmailsApi(
                sib_api_v3_sdk.ApiClient(self.configuration)
            )
            self.is_configured = True
        else:
            self.api_instance = None
            self.is_configured = False
            logger.warning("Brevo API key not configured. Email sending will be disabled.")

    def send_email(self, to_email, subject, html_content, plain_content=None, from_name="Inventory System", from_email=None):
        """
        Send email using Brevo API

        Args:
            to_email (str): Recipient email address
            subject (str): Email subject
            html_content (str): HTML content of the email
            plain_content (str, optional): Plain text version
            from_name (str): Sender name
            from_email (str, optional): Sender email (uses DEFAULT_FROM_EMAIL if not provided)

        Returns:
            tuple: (success: bool, message: str)
        """
        if not self.is_configured:
            logger.error("Brevo API is not configured. Cannot send email.")
            return False, "Email service not configured"

        # Use DEFAULT_FROM_EMAIL if no from_email provided
        if not from_email:
            from_email = getattr(settings, 'DEFAULT_FROM_EMAIL', 'noreply@inventoryxyz.online')
            # Extract just the email address if it's in "Name <email>" format
            if '<' in from_email:
                from_email = from_email.split('<')[1].replace('>', '').strip()

        try:
            # Prepare email data
            send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
                to=[{"email": to_email}],
                sender={"email": from_email, "name": from_name},
                subject=subject,
                html_content=html_content,
                text_content=plain_content
            )

            # Send email via API
            api_response = self.api_instance.send_transac_email(send_smtp_email)
            logger.info(f"Email sent successfully to {to_email}. Message ID: {api_response.message_id}")
            return True, f"Email sent successfully. Message ID: {api_response.message_id}"

        except ApiException as e:
            error_message = f"Brevo API error: {e}"
            logger.error(f"Failed to send email to {to_email}. {error_message}")
            return False, error_message
        except Exception as e:
            error_message = f"Unexpected error: {str(e)}"
            logger.error(f"Failed to send email to {to_email}. {error_message}")
            return False, error_message

    def send_verification_email(self, user, verification_code):
        """
        Send email verification code to user

        Args:
            user: User object
            verification_code (str): 6-digit verification code

        Returns:
            tuple: (success: bool, message: str)
        """
        subject = 'Verify Your Email - Inventory Management System'

        # HTML email content
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; }}
                .container {{ padding: 20px; }}
                .header {{ background: #1565C0; color: white; padding: 20px; text-align: center; }}
                .content {{ padding: 30px; background: #f9f9f9; }}
                .code {{ font-size: 24px; font-weight: bold; color: #1565C0; text-align: center;
                         padding: 15px; background: white; border-radius: 8px; margin: 20px 0; }}
                .footer {{ color: #666; font-size: 14px; text-align: center; padding: 20px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Email Verification Required</h1>
                </div>
                <div class="content">
                    <h2>Hello {user.first_name} {user.last_name},</h2>
                    <p>Thank you for registering with our Inventory Management System!</p>
                    <p>To complete your registration, please use the following verification code:</p>
                    <div class="code">{verification_code}</div>
                    <p>This code will expire in 30 minutes.</p>
                    <p>If you didn't create this account, please ignore this email.</p>
                </div>
                <div class="footer">
                    <p>© 2024 Inventory Management System</p>
                    <p>This is an automated email, please do not reply.</p>
                </div>
            </div>
        </body>
        </html>
        """

        # Plain text version
        plain_content = f"""
        Hello {user.first_name} {user.last_name},

        Thank you for registering with our Inventory Management System!

        To complete your registration, please use the following verification code:

        {verification_code}

        This code will expire in 30 minutes.

        If you didn't create this account, please ignore this email.

        © 2024 Inventory Management System
        """

        return self.send_email(
            to_email=user.email,
            subject=subject,
            html_content=html_content,
            plain_content=plain_content
        )

    def send_password_reset_email(self, user, reset_token):
        """
        Send password reset token to user

        Args:
            user: User object
            reset_token (str): 6-digit reset token

        Returns:
            tuple: (success: bool, message: str)
        """
        subject = 'Reset Your Password - Inventory Management System'

        # HTML email content
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; }}
                .container {{ padding: 20px; }}
                .header {{ background: #1565C0; color: white; padding: 20px; text-align: center; }}
                .content {{ padding: 30px; background: #f9f9f9; }}
                .code {{ font-size: 24px; font-weight: bold; color: #1565C0; text-align: center;
                         padding: 15px; background: white; border-radius: 8px; margin: 20px 0; }}
                .footer {{ color: #666; font-size: 14px; text-align: center; padding: 20px; }}
                .warning {{ background: #fff3cd; border: 1px solid #ffeaa7; padding: 15px;
                           border-radius: 8px; margin: 20px 0; color: #856404; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Password Reset Request</h1>
                </div>
                <div class="content">
                    <h2>Hello {user.first_name} {user.last_name},</h2>
                    <p>We received a request to reset your password for your Inventory Management System account.</p>
                    <p>Please use the following code to reset your password:</p>
                    <div class="code">{reset_token}</div>
                    <div class="warning">
                        <strong>Important:</strong> This code will expire in 15 minutes for security reasons.
                    </div>
                    <p>If you didn't request a password reset, please ignore this email. Your password will remain unchanged.</p>
                    <p>For security, never share this code with anyone.</p>
                </div>
                <div class="footer">
                    <p>© 2024 Inventory Management System</p>
                    <p>This is an automated email, please do not reply.</p>
                </div>
            </div>
        </body>
        </html>
        """

        # Plain text version
        plain_content = f"""
        Hello {user.first_name} {user.last_name},

        We received a request to reset your password for your Inventory Management System account.

        Please use the following code to reset your password:

        {reset_token}

        IMPORTANT: This code will expire in 15 minutes for security reasons.

        If you didn't request a password reset, please ignore this email. Your password will remain unchanged.

        For security, never share this code with anyone.

        © 2024 Inventory Management System
        """

        return self.send_email(
            to_email=user.email,
            subject=subject,
            html_content=html_content,
            plain_content=plain_content
        )


# Create a singleton instance
email_service = BrevoEmailService()
