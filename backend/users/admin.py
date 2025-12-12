from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.html import format_html
from django.urls import path, reverse
from django.http import HttpResponseRedirect
from .models import User
from incidents.models import Incident

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ('username', 'email', 'role', 'phone', 'incident_count', 'is_staff')
    list_filter = ('role', 'is_staff', 'is_superuser')
    list_per_page = 20  # Add pagination with 20 items per page
    search_fields = ('username', 'email', 'phone')
    
    fieldsets = UserAdmin.fieldsets + (
        ('Additional Info', {'fields': ('role', 'phone', 'name', 'token')}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Additional Info', {'fields': ('role', 'phone', 'name')}),
    )
    
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path(
                '<path:object_id>/view_incidents/',
                self.admin_site.admin_view(self.view_user_incidents),
                name='user-incidents',
            ),
        ]
        return custom_urls + urls
    
    def incident_count(self, obj):
        """Display the number of incidents for this user as a clickable link"""
        count = Incident.objects.filter(user=obj).count()
        if count > 0:
            url = reverse('admin:user-incidents', args=[obj.pk])
            return format_html('<a href="{}">{}</a>', url, count)
        return count
    
    incident_count.short_description = 'Incidents'
    
    def view_user_incidents(self, request, object_id):
        """View all incidents for a specific user"""
        # Redirect to the incidents list filtered by this user
        return HttpResponseRedirect(
            reverse('admin:incidents_incident_changelist') + f'?user__id__exact={object_id}'
        )
    
    def delete_model(self, request, obj):
        """Delete user and all associated incidents"""
        # First delete all incidents associated with this user
        Incident.objects.filter(user=obj).delete()
        # Then delete the user
        super().delete_model(request, obj)
