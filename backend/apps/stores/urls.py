from django.urls import path
from . import views

urlpatterns = [
    path('', views.StoreListCreateView.as_view(), name='store-list-create'),
    path('<int:pk>/', views.StoreDetailView.as_view(), name='store-detail'),
    path('my-stores/', views.my_stores_view, name='my-stores'),
    path('users/', views.StoreUserListCreateView.as_view(), name='store-user-list-create'),
    path('users/<int:pk>/', views.StoreUserDetailView.as_view(), name='store-user-detail'),
]