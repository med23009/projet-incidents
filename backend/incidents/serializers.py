from rest_framework import serializers
from .models import Incident, IncidentMedia
from django.contrib.auth import get_user_model

User = get_user_model()

class IncidentMediaSerializer(serializers.ModelSerializer):
    class Meta:
        model = IncidentMedia
        fields = ('id', 'media_file', 'media_type', 'caption', 'created_at')

class IncidentSerializer(serializers.ModelSerializer):
    user = serializers.PrimaryKeyRelatedField(read_only=True)
    photo_url = serializers.SerializerMethodField()
    voice_note_url = serializers.SerializerMethodField()
    additional_media = IncidentMediaSerializer(many=True, read_only=True)

    class Meta:
        model = Incident
        fields = (
            'id', 'title', 'description', 'incident_type', 'photo', 'photo_url',
            'photo_path', 'voice_note', 'voice_note_url', 'voice_note_path', 
            'latitude', 'longitude', 'status', 'created_at', 'updated_at', 
            'user', 'sync_status', 'additional_media'
        )
        read_only_fields = ('id', 'updated_at')

    def get_photo_url(self, obj):
        if obj.photo:
            return self.context['request'].build_absolute_uri(obj.photo.url)
        return None

    def get_voice_note_url(self, obj):
        if obj.voice_note:
            return self.context['request'].build_absolute_uri(obj.voice_note.url)
        return None

    def create(self, validated_data):
        if 'sync_status' not in validated_data:
            validated_data['sync_status'] = 'synced'
        
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'phone', 'role', 'name', 'token', 'last_login')
        read_only_fields = ('id',)
