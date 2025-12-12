from django.db import models
from django.conf import settings
import os

# Create your models here.

class Incident(models.Model):
    INCIDENT_TYPES = (
        ('general', 'General'),
        ('fire', 'Fire'),
        ('accident', 'Accident'),
        ('medical', 'Medical Emergency'),
        ('crime', 'Crime'),
        ('other', 'Other'),
    )
    
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
        ('closed', 'Closed'),
    )
    
    SYNC_STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('synced', 'Synced'),
        ('failed', 'Failed'),
    )
    
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    photo_path = models.CharField(max_length=255, blank=True, null=True)  # Chemin local sur le mobile
    photo = models.ImageField(upload_to='incidents/photos/', null=True, blank=True)
    photo_url = models.URLField(blank=True, null=True)  # Pour stocker l'URL après upload
    voice_note_path = models.CharField(max_length=255, blank=True, null=True)  # Chemin local sur le mobile
    voice_note = models.FileField(upload_to='incidents/voice_notes/', null=True, blank=True)
    latitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=7, null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField()  # Pas auto_now_add pour permettre la synchronisation avec timestamp du mobile
    updated_at = models.DateTimeField(auto_now=True)
    incident_type = models.CharField(max_length=20, choices=INCIDENT_TYPES, default='general')
    sync_status = models.CharField(max_length=20, choices=SYNC_STATUS_CHOICES, default='synced')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='incidents',
        db_column='user_id'  # Pour correspondre exactement à la BD SQLite
    )

    class Meta:
        db_table = 'incidents'
        
    def __str__(self):
        return f"{self.title} (ID: {self.id})"


class IncidentMedia(models.Model):
    MEDIA_TYPES = (
        ('image', 'Image'),
        ('video', 'Video'),
    )
    
    incident = models.ForeignKey(Incident, on_delete=models.CASCADE, related_name='additional_media')
    media_file = models.FileField(upload_to='incidents/media/')
    media_type = models.CharField(max_length=10, choices=MEDIA_TYPES, default='image')
    caption = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        db_table = 'incident_media'
        verbose_name = 'Incident Media'
        verbose_name_plural = 'Incident Media'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Media for {self.incident.title} (ID: {self.incident.id})"
    
    @property
    def filename(self):
        return os.path.basename(self.media_file.name)
    
    @property
    def is_image(self):
        return self.media_type == 'image'
    
    @property
    def is_video(self):
        return self.media_type == 'video'
