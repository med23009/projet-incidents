from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_yasg.views import get_schema_view
from drf_yasg import openapi
from rest_framework import permissions
from incidents_api.views.admin_views import (
    admin_incident_detail, 
    admin_incident_edit, 
    admin_incidents_list, 
    admin_dashboard,
    admin_incident_resolve,
    admin_incident_delete,
    admin_incident_update_status
)
# Import the custom admin views directly
from incidents_api.views.admin_views import (
    admin_dashboard, 
    admin_incidents_list, 
    admin_incident_detail, 
    admin_incident_edit, 
    admin_incident_resolve, 
    admin_incident_delete, 
    admin_incident_update_status,
    admin_users_list,
    admin_user_delete,
    admin_incident_add_media
)

schema_view = get_schema_view(
    openapi.Info(
        title="Urban Incidents API",
        default_version='v1',
        description="API for reporting and managing urban incidents",
    ),
    public=True,
    permission_classes=(permissions.AllowAny,),
)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/users/', include('users.urls')),
    path('api/incidents/', include('incidents.urls')),
    path('swagger/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
    
    # URLs du panneau d'administration personnalisé
    path('', admin_dashboard, name='admin_dashboard'),  # Page d'accueil = tableau de bord
    path('admin-panel/', admin_dashboard, name='admin_dashboard_alt'),  # URL alternative
    
    # Incidents routes
    path('admin-panel/incidents/', admin_incidents_list, name='admin_incidents_list'),
    path('admin-panel/incidents/<int:incident_id>/', admin_incident_detail, name='admin_incident_detail'),
    path('admin-panel/incidents/<int:incident_id>/edit/', admin_incident_edit, name='admin_incident_edit'),
    path('admin-panel/incidents/<int:incident_id>/resolve/', admin_incident_resolve, name='admin_incident_resolve'),
    path('admin-panel/incidents/<int:incident_id>/delete/', admin_incident_delete, name='admin_incident_delete'),
    path('admin-panel/incidents/<int:incident_id>/update-status/', admin_incident_update_status, name='admin_incident_update_status'),
    path('admin-panel/incidents/<int:incident_id>/add-media/', admin_incident_add_media, name='admin_incident_add_media'),
    
    # Users routes
    path('admin-panel/users/', admin_users_list, name='admin_users_list'),
    path('admin-panel/users/<int:user_id>/delete/', admin_user_delete, name='admin_user_delete'),
    
    # URLs d'authentification Django
    path('accounts/', include('django.contrib.auth.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
