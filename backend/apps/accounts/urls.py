from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views
from . import user_management_views

urlpatterns = [
    path('register/', views.RegisterView.as_view(), name='register'),
    path('login/', views.LoginView.as_view(), name='login'),
    path('logout/', views.logout_view, name='logout'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('profile/', views.ProfileView.as_view(), name='profile'),
    path('change-password/', views.ChangePasswordView.as_view(), name='change_password'),
    path('invoice-settings/', views.InvoiceSettingsView.as_view(), name='invoice-settings'),

    # Email verification endpoints
    path('verify-email/', views.verify_email, name='verify_email'),
    path('resend-verification/', views.resend_verification_code, name='resend_verification'),
    
    # Password reset endpoints
    path('forgot-password/', views.forgot_password, name='forgot_password'),
    path('reset-password/', views.reset_password, name='reset_password'),

    # Debug endpoint
    path('check-email-config/', views.check_email_config, name='check-email-config'),

    # User management endpoints for admins
    path('users/', user_management_views.UserListCreateView.as_view(), name='user-list-create'),
    path('users/<int:pk>/', user_management_views.UserDetailView.as_view(), name='user-detail'),
    path('stores/<int:store_id>/users/', user_management_views.store_users_view, name='store-users'),
    path('assign-user-to-store/', user_management_views.assign_user_to_store_view, name='assign-user-to-store'),
    path('remove-user-from-store/<int:user_id>/<int:store_id>/', user_management_views.remove_user_from_store_view, name='remove-user-from-store'),
    path('admin-change-password/', user_management_views.admin_change_user_password_view, name='admin-change-password'),
    path('users/<int:user_id>/stores/', user_management_views.get_user_stores_view, name='user-stores'),

    # User approval endpoints
    path('users/<int:user_id>/approve/', user_management_views.approve_user_view, name='approve-user'),
    path('users/<int:user_id>/reject/', user_management_views.reject_user_view, name='reject-user'),
    path('users/pending/count/', user_management_views.pending_users_count_view, name='pending-users-count'),
]