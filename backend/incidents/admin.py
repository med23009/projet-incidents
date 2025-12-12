from django.contrib import admin
from django.utils.html import format_html
from django.http import HttpResponseRedirect
from django.urls import path
from .models import Incident, IncidentMedia

class IncidentMediaInline(admin.TabularInline):
    model = IncidentMedia
    extra = 1
    fields = ('media_file', 'media_type', 'caption')

@admin.register(Incident)
class IncidentAdmin(admin.ModelAdmin):
    list_display = ('title', 'incident_type', 'status', 'user', 'created_at', 'sync_status')
    list_filter = ('incident_type', 'status', 'sync_status', 'created_at', 'user')
    search_fields = ('title', 'description', 'user__username', 'user__email')
    list_display_links = ('title',)  # Make title clickable for details
    list_per_page = 20  # Add pagination with 20 items per page
    fields = (
        'title', 'description', 'incident_type', 'status', 'user',
        'created_at', 'updated_at', 'sync_status',
        'display_location', 'display_photo', 'display_voice_note'
    )
    
    inlines = [IncidentMediaInline]
    date_hierarchy = 'created_at'
    
    def get_readonly_fields(self, request, obj=None):
        # Make all fields read-only except status
        if obj:  # This ensures we're in edit mode
            return [f.name for f in obj._meta.fields if f.name != 'status'] + [
                'display_location', 'display_photo', 'display_voice_note'
            ]
        return self.readonly_fields
    
    def has_add_permission(self, request):
        # Prevent adding new incidents from admin
        return False
        
    def has_delete_permission(self, request, obj=None):
        # Allow deleting incidents from admin
        return True
    
    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        if obj:  # Only in edit mode
            # Disable all fields except status
            for field_name, field in form.base_fields.items():
                if field_name != 'status':
                    field.disabled = True
        return form
    
    def save_model(self, request, obj, form, change):
        # Only save if status has changed
        if change and 'status' in form.changed_data:
            # Get the original object from the database
            original_obj = self.model.objects.get(pk=obj.pk)
            # Only update the status field
            original_obj.status = obj.status
            original_obj.save(update_fields=['status'])
        elif not change:  # This is a new object
            super().save_model(request, obj, form, change)
        
    def display_location(self, obj):
        if obj.latitude and obj.longitude:
            map_url = f"https://www.google.com/maps/search/?api=1&query={obj.latitude},{obj.longitude}"
            return format_html(
                '<a href="{}" target="_blank">View on Google Maps</a><br/>'
                'Latitude: {}, Longitude: {}',
                map_url, obj.latitude, obj.longitude
            )
        return "No location data available"
    display_location.short_description = "Location"
    
    def display_photo(self, obj):
        if obj.photo and hasattr(obj.photo, 'url'):
            return format_html('<a href="{}" target="_blank"><img src="{}" width="300" /></a>', 
                              obj.photo.url, obj.photo.url)
        elif obj.photo_url:
            return format_html('<a href="{}" target="_blank"><img src="{}" width="300" /></a>', 
                              obj.photo_url, obj.photo_url)
        return "No image available"
    display_photo.short_description = "Photo"
    
    def display_voice_note(self, obj):
        if obj.voice_note and hasattr(obj.voice_note, 'url'):
            return format_html(
                '<audio controls><source src="{}" type="audio/mpeg">'
                'Your browser does not support the audio element.</audio>',
                obj.voice_note.url
            )
        return "No audio available"
    display_voice_note.short_description = "Voice Note"
