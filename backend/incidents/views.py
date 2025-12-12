from django.shortcuts import render
from rest_framework import viewsets, permissions, filters, status
from rest_framework.response import Response
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django_filters.rest_framework import DjangoFilterBackend
from .models import Incident
from .serializers import IncidentSerializer, UserSerializer
from django.contrib.auth import get_user_model
from django.db import models
from django.db.models import Count, Case, When, IntegerField
from django.utils import timezone
from datetime import timedelta

User = get_user_model()

# Create your views here.

class IsOwnerOrAdmin(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        return request.user.is_staff or obj.user == request.user

class IncidentViewSet(viewsets.ModelViewSet):
    serializer_class = IncidentSerializer
    parser_classes = (MultiPartParser, FormParser, JSONParser)
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrAdmin]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'incident_type', 'sync_status']
    search_fields = ['title', 'description']
    ordering_fields = ['created_at', 'updated_at', 'status']
    ordering = ['-created_at']

    def get_queryset(self):
        if self.request.user.role == 'admin':
            return Incident.objects.all()
        return Incident.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
        
    @action(detail=False, methods=['get'], url_path='statistics')
    def get_statistics(self, request):
        """
        Get statistics for the mobile app dashboard.
        Returns counts of incidents by type, status, and time periods.
        """
        # Get user specific queryset based on permissions
        queryset = self.get_queryset()
        
        # Time periods for recent incidents
        today = timezone.now().date()
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)
        
        # Get basic counts
        total_count = queryset.count()
        synced_count = queryset.filter(sync_status='synced').count()
        pending_sync_count = queryset.filter(sync_status='pending').count()
        recent_incidents = queryset.filter(created_at__date__gte=week_ago).count()
        
        # Count by incident type
        incidents_by_type = queryset.values('incident_type').annotate(
            count=Count('id')
        ).order_by('incident_type')
        
        # Count by status
        incidents_by_status = queryset.values('status').annotate(
            count=Count('id')
        ).order_by('status')
        
        # Count by time period
        incidents_by_time = {
            'today': queryset.filter(created_at__date=today).count(),
            'this_week': queryset.filter(created_at__date__gte=week_ago).count(),
            'this_month': queryset.filter(created_at__date__gte=month_ago).count(),
        }
        
        # Calculate sync completion rate
        sync_rate = 0
        if total_count > 0:
            sync_rate = (synced_count / total_count) * 100
        
        # Prepare response data
        statistics = {
            'total_incidents': total_count,
            'synced_incidents': synced_count,
            'pending_sync': pending_sync_count,
            'sync_completion_rate': sync_rate,
            'recent_incidents': recent_incidents,
            'incidents_by_type': list(incidents_by_type),
            'incidents_by_status': list(incidents_by_status),
            'incidents_by_time': incidents_by_time
        }
        
        return Response(statistics)
        
    @action(detail=False, methods=['get'], url_path='user-dashboard')
    def user_dashboard_stats(self, request):
        """
        Get user-friendly statistics for the mobile app dashboard.
        Focuses on incident status rather than sync status, which is more
        relevant for regular users than sync information.
        """
        # Get user specific queryset based on permissions
        queryset = self.get_queryset()
        
        # Time periods for incidents
        today = timezone.now().date()
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)
        
        # Count by incident status (what users care about most)
        resolved_count = queryset.filter(status='resolved').count()
        pending_count = queryset.filter(status='pending').count()
        in_progress_count = queryset.filter(status='in_progress').count()
        
        # Get total counts
        total_count = queryset.count()
        recent_incidents = queryset.filter(created_at__date__gte=week_ago).count()
        
        # Calculate resolution rate
        resolution_rate = 0
        if total_count > 0:
            resolution_rate = (resolved_count / total_count) * 100
            
        # Count by incident type
        incidents_by_type = queryset.values('incident_type').annotate(
            count=Count('id')
        ).order_by('incident_type')
        
        # Count recent activity - incidents by day of week
        # This shows usage patterns which users might find interesting
        day_of_week_counts = queryset.filter(
            created_at__date__gte=week_ago
        ).annotate(
            day_name=models.functions.Extract('created_at', 'dow')
        ).values('day_name').annotate(
            count=Count('id')
        ).order_by('day_name')
        
        # Transform day of week counts to a more readable format
        days_of_week = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        incidents_by_day = {day: 0 for day in days_of_week}
        for item in day_of_week_counts:
            # PostgreSQL DOW is 0 (Sunday) to 6 (Saturday), adjust to 0 (Monday) to 6 (Sunday)
            day_idx = (item['day_name'] - 1) % 7
            incidents_by_day[days_of_week[day_idx]] = item['count']
            
        # Monthly trend - last 6 months
        six_months_ago = today - timedelta(days=180)
        monthly_counts = queryset.filter(
            created_at__date__gte=six_months_ago
        ).annotate(
            month=models.functions.TruncMonth('created_at')
        ).values('month').annotate(
            count=Count('id')
        ).order_by('month')
        
        # Format the monthly data
        monthly_trend = [
            {
                'month': item['month'].strftime('%b %Y'),
                'count': item['count']
            } for item in monthly_counts
        ]
        
        # Prepare the response data focusing on what users care about
        user_statistics = {
            'total_incidents': total_count,
            'status_summary': {
                'resolved': resolved_count,
                'pending': pending_count,
                'in_progress': in_progress_count,
                'resolution_rate': resolution_rate
            },
            'recent_activity': {
                'recent_week': recent_incidents,
                'today': queryset.filter(created_at__date=today).count(),
                'by_day_of_week': incidents_by_day
            },
            'incidents_by_type': list(incidents_by_type),
            'monthly_trend': monthly_trend
        }
        
        return Response(user_statistics)
        
    @action(detail=False, methods=['post'], url_path='sync')
    def sync_incidents(self, request):
        """
        Synchronise les incidents en attente depuis l'application mobile.
        """
        incidents_data = request.data
        
        if not isinstance(incidents_data, list):
            incidents_data = [incidents_data]
            
        results = []
        for incident_data in incidents_data:
            # Conserver le created_at tel qu'il a été défini côté mobile
            created_at = incident_data.get('created_at')
            
            # Vérifier si l'incident existe déjà (en cas de resync)
            existing_incident = None
            if 'id' in incident_data and Incident.objects.filter(id=incident_data['id']).exists():
                # Mettre à jour l'incident existant
                existing_incident = Incident.objects.get(id=incident_data['id'])
                serializer = self.get_serializer(existing_incident, data=incident_data, partial=True)
            else:
                # Créer un nouvel incident
                serializer = self.get_serializer(data=incident_data)
                
            if serializer.is_valid():
                # Enregistrer les chemins locaux du mobile si fournis
                photo_path = incident_data.get('photo_path')
                voice_note_path = incident_data.get('voice_note_path')
                
                # Enregistrer l'incident avec tous les champs nécessaires
                saved_incident = serializer.save(
                    user=request.user, 
                    sync_status='synced',
                    photo_path=photo_path,
                    voice_note_path=voice_note_path
                )
                
                # Si l'incident a été synchronisé avec succès, renvoyer les données mises à jour
                results.append({
                    'success': True,
                    'data': self.get_serializer(saved_incident).data,
                    'message': 'Incident synchronisé avec succès'
                })
            else:
                results.append({
                    'success': False,
                    'errors': serializer.errors,
                    'message': 'Erreur lors de la synchronisation'
                })
                
        return Response(results, status=status.HTTP_200_OK)
        
class UserViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        # Les admins peuvent voir tous les utilisateurs
        if self.request.user.role == 'admin':
            return User.objects.all()
        # Les utilisateurs normaux ne peuvent voir que leur propre profil
        return User.objects.filter(id=self.request.user.id)
