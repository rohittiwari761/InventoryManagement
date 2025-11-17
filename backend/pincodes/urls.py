from django.urls import path
from . import views

urlpatterns = [
    path('', views.PinCodeListView.as_view(), name='pincode-list'),
    path('lookup/<str:pincode>/', views.lookup_pincode, name='pincode-lookup'),
    path('lookup/', views.lookup_pincode_post, name='pincode-lookup-post'),
]