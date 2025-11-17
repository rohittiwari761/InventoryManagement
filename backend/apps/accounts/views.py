from rest_framework import status, generics, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.conf import settings
import threading
import logging

from .serializers import (
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserSerializer,
    UserProfileUpdateSerializer,
    ChangePasswordSerializer,
    InvoiceSettingsSerializer
)
from .email_service import email_service

User = get_user_model()
logger = logging.getLogger(__name__)


def send_verification_email(user):
    """Send verification code email to user - runs in background thread"""
    verification_code = user.generate_verification_code()

    try:
        # Use Brevo API to send email
        success, message = email_service.send_verification_email(user, verification_code)

        if success:
            logger.info(f"Verification email sent successfully to {user.email}")
        else:
            logger.error(f"Failed to send verification email to {user.email}: {message}")
    except Exception as e:
        # Log the error but don't fail the registration
        logger.error(f"Email sending failed for {user.email}: {e}")


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (AllowAny,)
    serializer_class = UserRegistrationSerializer
    
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        
        # Check if this user needs email verification
        admin_emails = [
            'tiwari.rohit761@gmail.com',
            'admin@',
            '@company.com',
            'root@',
            'administrator@'
        ]
        
        needs_verification = any(pattern in user.email.lower() for pattern in admin_emails) or user.role == 'admin'
        
        if needs_verification:
            # Send verification email
            user.is_verified = False
            user.is_active = True  # User account is active but must verify email before login
            user.save()

            # Send email in background thread to avoid blocking the response
            email_thread = threading.Thread(target=send_verification_email, args=(user,))
            email_thread.daemon = True  # Thread will automatically close when main program exits
            email_thread.start()

            return Response({
                'message': 'Registration successful! Please check your email for verification code.',
                'email_verification_required': True,
                'email': user.email
            }, status=status.HTTP_201_CREATED)
        else:
            # Old flow - generate tokens immediately
            user.is_verified = True
            user.save()
            
            refresh = RefreshToken.for_user(user)
            
            return Response({
                'message': 'Registration successful!',
                'email_verification_required': False,
                'user': UserSerializer(user).data,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }, status=status.HTTP_201_CREATED)


class LoginView(generics.GenericAPIView):
    permission_classes = (AllowAny,)
    serializer_class = UserLoginSerializer
    
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'user': UserSerializer(user).data,
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        })


class ProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = (IsAuthenticated,)
    serializer_class = UserSerializer
    
    def get_object(self):
        return self.request.user
    
    def get_serializer_class(self):
        if self.request.method == 'PATCH' or self.request.method == 'PUT':
            return UserProfileUpdateSerializer
        return UserSerializer
    
    def update(self, request, *args, **kwargs):
        # Use the update serializer for validation and updating
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        update_serializer = UserProfileUpdateSerializer(instance, data=request.data, partial=partial)
        update_serializer.is_valid(raise_exception=True)
        update_serializer.save()
        
        # Return complete user data using UserSerializer
        full_user_serializer = UserSerializer(instance)
        return Response(full_user_serializer.data)


class ChangePasswordView(generics.UpdateAPIView):
    """Change password - Admin users only"""
    permission_classes = (IsAuthenticated,)
    serializer_class = ChangePasswordSerializer

    def get_object(self):
        return self.request.user

    def update(self, request, *args, **kwargs):
        user = self.get_object()

        # Check if user is admin
        if user.role != 'admin':
            return Response({
                'error': 'Password changes are only available for admin users. Please contact your administrator to reset your password.',
                'is_admin_only': True
            }, status=status.HTTP_403_FORBIDDEN)

        serializer = self.get_serializer(data=request.data)

        if serializer.is_valid():
            user.set_password(serializer.validated_data['new_password'])
            user.save()
            return Response({'message': 'Password changed successfully'})

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout_view(request):
    try:
        refresh_token = request.data["refresh"]
        token = RefreshToken(refresh_token)
        token.blacklist()
        return Response({'message': 'Logout successful'}, status=status.HTTP_200_OK)
    except Exception as e:
        return Response({'error': 'Invalid token'}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([AllowAny])
def check_email_config(request):
    """Debug endpoint to check email configuration"""
    brevo_api_key = getattr(settings, 'BREVO_API_KEY', None)

    return Response({
        'email_service': 'Brevo API',
        'brevo_api_configured': bool(brevo_api_key),
        'brevo_service_ready': email_service.is_configured,
        'DEFAULT_FROM_EMAIL': settings.DEFAULT_FROM_EMAIL,
        # Legacy SMTP config (kept for fallback)
        'smtp_backend': settings.EMAIL_BACKEND,
        'smtp_host': settings.EMAIL_HOST,
        'smtp_port': settings.EMAIL_PORT,
        'smtp_tls': settings.EMAIL_USE_TLS,
        'smtp_user_configured': bool(settings.EMAIL_HOST_USER),
    })


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_email(request):
    """Verify email with verification code"""
    try:
        email = request.data.get('email')
        verification_code = request.data.get('verification_code')
        
        if not email or not verification_code:
            return Response({'error': 'Email and verification code are required'}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Check if code is valid
        if user.verification_code != verification_code:
            return Response({'verification_code': ['Invalid verification code']}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        if not user.is_verification_code_valid():
            return Response({'verification_code': ['Verification code has expired']}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        # Verify the user
        user.is_verified = True
        user.is_active = True
        user.verification_code = None
        user.verification_code_created = None
        user.save()
        
        # Generate tokens
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'message': 'Email verified successfully!',
            'user': UserSerializer(user).data,
            'access': str(refresh.access_token),
            'refresh': str(refresh)
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([AllowAny])
def resend_verification_code(request):
    """Resend verification code to user email"""
    try:
        email = request.data.get('email')
        
        if not email:
            return Response({'error': 'Email is required'}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        if user.is_verified:
            return Response({'error': 'User is already verified'}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        # Send new verification email
        send_verification_email(user)
        
        return Response({
            'message': 'Verification code sent to your email'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


def send_reset_password_email(user):
    """Send password reset token email to user"""
    reset_token = user.generate_reset_password_token()

    try:
        # Use Brevo API to send email
        success, message = email_service.send_password_reset_email(user, reset_token)

        if success:
            logger.info(f"Password reset email sent successfully to {user.email}")
        else:
            logger.error(f"Failed to send password reset email to {user.email}: {message}")
    except Exception as e:
        # Log the error but don't fail the request
        logger.error(f"Email sending failed for {user.email}: {e}")


@api_view(['POST'])
@permission_classes([AllowAny])
def forgot_password(request):
    """Send password reset token to user email - Admin users only"""
    try:
        email = request.data.get('email')

        if not email:
            return Response({'email': ['Email is required']},
                          status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            # For security, don't reveal if email exists or not
            return Response({
                'message': 'If this email exists in our system, you will receive a password reset code shortly.'
            }, status=status.HTTP_200_OK)

        # Check if user is admin
        if user.role != 'admin':
            return Response({
                'error': 'Password reset is only available for admin users. Please contact your administrator to reset your password.',
                'is_admin_only': True
            }, status=status.HTTP_403_FORBIDDEN)

        # Send password reset email
        send_reset_password_email(user)

        return Response({
            'message': 'If this email exists in our system, you will receive a password reset code shortly.'
        }, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({'error': 'An error occurred while processing your request'},
                       status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password(request):
    """Reset password using reset token"""
    try:
        email = request.data.get('email')
        reset_token = request.data.get('reset_token')
        new_password = request.data.get('new_password')
        
        if not all([email, reset_token, new_password]):
            return Response({'error': 'Email, reset token, and new password are required'}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'Invalid reset request'}, 
                          status=status.HTTP_404_NOT_FOUND)
        
        # Check if token is valid
        if user.reset_password_token != reset_token:
            return Response({'reset_token': ['Invalid reset token']}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        if not user.is_reset_password_token_valid():
            return Response({'reset_token': ['Reset token has expired. Please request a new one.']}, 
                          status=status.HTTP_400_BAD_REQUEST)
        
        # Reset the password
        user.set_password(new_password)
        user.reset_password_token = None
        user.reset_password_token_created = None
        user.save()
        
        return Response({
            'message': 'Password reset successful! You can now login with your new password.'
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

class InvoiceSettingsView(generics.RetrieveUpdateAPIView):
    """
    API endpoint for retrieving and updating user invoice settings.
    GET: Returns current user's invoice settings
    PUT/PATCH: Updates user's invoice settings
    """
    permission_classes = [IsAuthenticated]
    serializer_class = InvoiceSettingsSerializer

    def get_object(self):
        """Return the current authenticated user"""
        return self.request.user

    def retrieve(self, request, *args, **kwargs):
        """Get current user's invoice settings"""
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    def update(self, request, *args, **kwargs):
        """Update user's invoice settings"""
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        return Response({
            'message': 'Invoice settings updated successfully',
            'settings': serializer.data
        })

    def perform_update(self, serializer):
        """Perform the update operation"""
        serializer.save()
