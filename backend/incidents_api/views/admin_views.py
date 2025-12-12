from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import get_object_or_404, render, redirect
from django.conf import settings
from django.http import HttpResponseRedirect
from incidents.models import Incident
from django.db.models import Count
from django.utils import timezone
from datetime import timedelta

# Créer un formulaire intégré puisque le fichier forms.py pourrait ne pas être accessible
from django import forms

class IncidentForm(forms.ModelForm):
    class Meta:
        model = Incident
        fields = ['title', 'description', 'incident_type', 'status', 'latitude', 'longitude', 'photo', 'voice_note', 'sync_status']
        widgets = {
            'description': forms.Textarea(attrs={'rows': 4, 'class': 'form-control'}),
            'title': forms.TextInput(attrs={'class': 'form-control'}),
            'incident_type': forms.Select(attrs={'class': 'form-select'}),
            'status': forms.Select(attrs={'class': 'form-select'}),
            'sync_status': forms.Select(attrs={'class': 'form-select'}),
            'latitude': forms.NumberInput(attrs={'step': '0.000001', 'class': 'form-control'}),
            'longitude': forms.NumberInput(attrs={'step': '0.000001', 'class': 'form-control'}),
            'photo': forms.ClearableFileInput(attrs={'class': 'form-control'}),
            'voice_note': forms.ClearableFileInput(attrs={'class': 'form-control'}),
        }
    
    clear_photo = forms.BooleanField(required=False, widget=forms.HiddenInput())
    clear_audio = forms.BooleanField(required=False, widget=forms.HiddenInput())
    
    def save(self, commit=True):
        instance = super().save(commit=False)
        
        if self.cleaned_data.get('clear_photo'):
            instance.photo.delete()
            instance.photo = None
        
        if self.cleaned_data.get('clear_audio'):
            instance.voice_note.delete()
            instance.voice_note = None
        
        if commit:
            instance.save()
        
        return instance

# Remplacer staff_member_required par une fonction personnalisée
def is_staff(user):
    return user.is_authenticated and user.is_staff

@login_required
@user_passes_test(is_staff)
def admin_dashboard(request):
    """Vue du tableau de bord d'administration"""
    # Statistiques générales
    total_incidents = Incident.objects.count()
    
    # Statistiques des utilisateurs
    from django.contrib.auth import get_user_model
    User = get_user_model()
    total_users = User.objects.count()
    active_users = User.objects.filter(is_active=True).count()
    
    # Derniers utilisateurs inscrits (5 derniers) avec le nombre d'incidents
    latest_users = User.objects.all().annotate(incident_count=Count('incidents')).order_by('-date_joined')[:5]
    
    # Incidents récents (7 derniers jours)
    week_ago = timezone.now() - timedelta(days=7)
    recent_incidents = Incident.objects.filter(created_at__gte=week_ago).count()
    
    # Statistiques par statut
    status_stats_raw = Incident.objects.values('status').annotate(count=Count('status'))
    status_stats = []
    for stat in status_stats_raw:
        percentage = 0
        if total_incidents > 0:
            percentage = int((stat['count'] * 100) / total_incidents)
        
        status_name = stat['status']
        for status_choice in Incident.STATUS_CHOICES:
            if status_choice[0] == status_name:
                status_name = status_choice[1]
                break
                
        status_stats.append({
            'status': stat['status'],
            'status_name': status_name,
            'count': stat['count'],
            'percentage': percentage
        })
    
    # Statistiques par type d'incident
    type_stats_raw = Incident.objects.values('incident_type').annotate(count=Count('incident_type'))
    type_stats = []
    for stat in type_stats_raw:
        percentage = 0
        if total_incidents > 0:
            percentage = int((stat['count'] * 100) / total_incidents)
            
        type_name = stat['incident_type']
        for type_choice in Incident.INCIDENT_TYPES:
            if type_choice[0] == type_name:
                type_name = type_choice[1]
                break
                
        type_stats.append({
            'incident_type': stat['incident_type'],
            'type_name': type_name,
            'count': stat['count'],
            'percentage': percentage
        })
    
    # Incidents récents (les 5 derniers)
    latest_incidents = Incident.objects.all().order_by('-created_at')[:5]
    
    # Récupérer tous les incidents avec des coordonnées GPS pour la carte
    incidents_with_coords = Incident.objects.filter(
        latitude__isnull=False, 
        longitude__isnull=False
    ).values('id', 'title', 'incident_type', 'status', 'latitude', 'longitude')
    
    # Convertir les valeurs Decimal en float pour éviter les erreurs JavaScript
    map_incidents = []
    for incident in incidents_with_coords:
        map_incidents.append({
            'id': incident['id'],
            'title': incident['title'],
            'incident_type': incident['incident_type'],
            'status': incident['status'],
            'latitude': float(incident['latitude']),
            'longitude': float(incident['longitude'])
        })
    
    context = {
        'page_title': 'Tableau de bord',
        'total_incidents': total_incidents,
        'recent_incidents': recent_incidents,
        'status_stats': status_stats,
        'type_stats': type_stats,
        'latest_incidents': latest_incidents,
        'incident_types': dict(Incident.INCIDENT_TYPES),
        'status_choices': dict(Incident.STATUS_CHOICES),
        'google_maps_api_key': getattr(settings, 'GOOGLE_MAPS_API_KEY', ''),
        'map_incidents': map_incidents,
        'total_users': total_users,
        'active_users': active_users,
        'latest_users': latest_users,
    }
    
    return render(request, 'admin/dashboard.html', context)

@login_required
@user_passes_test(is_staff)
def admin_incidents_list(request):
    incidents = Incident.objects.all().order_by('-created_at')
    
    # Filtres
    status_filter = request.GET.get('status', '')
    type_filter = request.GET.get('type', '')
    search_query = request.GET.get('q', '')
    user_id = request.GET.get('user_id', '')
    
    # Filter title for when viewing a specific user's incidents
    page_title = 'Liste des incidents'
    
    if status_filter:
        incidents = incidents.filter(status=status_filter)
    if type_filter:
        incidents = incidents.filter(incident_type=type_filter)
    if search_query:
        incidents = incidents.filter(title__icontains=search_query) | incidents.filter(description__icontains=search_query)
    if user_id:
        # Filter incidents by user ID
        try:
            user_id = int(user_id)
            incidents = incidents.filter(user_id=user_id)
            
            # Get the username for the title
            from django.contrib.auth import get_user_model
            User = get_user_model()
            try:
                user = User.objects.get(id=user_id)
                page_title = f'Incidents de {user.username}'
            except User.DoesNotExist:
                pass
        except ValueError:
            # Invalid user ID format
            pass
    
    return render(request, 'admin/incidents_list.html', {
        'page_title': page_title,
        'incidents': incidents,
        'status_filter': status_filter,
        'type_filter': type_filter,
        'search_query': search_query,
        'user_id': user_id,  # Pass the user_id to the template
        'incident_types': dict(Incident.INCIDENT_TYPES),
        'status_choices': dict(Incident.STATUS_CHOICES),
    })

@login_required
@user_passes_test(is_staff)
def admin_incident_detail(request, incident_id):
    incident = get_object_or_404(Incident, id=incident_id)
    
    # Make sure latitude and longitude are float values for JavaScript
    if incident.latitude is not None and incident.longitude is not None:
        incident.latitude = float(incident.latitude)
        incident.longitude = float(incident.longitude)
    
    # Get the user who reported the incident
    user_info = None
    if incident.user:
        user_info = {
            'id': incident.user.id,
            'username': incident.user.username,
            'email': incident.user.email,
            'date_joined': incident.user.date_joined,
        }
    
    return render(request, 'admin/incident_detail.html', {
        'page_title': f'Incident #{incident.id}',
        'incident': incident,
        'user_info': user_info,
        'google_maps_api_key': getattr(settings, 'GOOGLE_MAPS_API_KEY', '')
    })

@login_required
@user_passes_test(is_staff)
def admin_incident_edit(request, incident_id):
    incident = get_object_or_404(Incident, id=incident_id)
    
    if request.method == 'POST':
        # Only update the status field
        original_data = {
            'title': incident.title,
            'description': incident.description,
            'incident_type': incident.incident_type,
            'latitude': incident.latitude,
            'longitude': incident.longitude,
            'sync_status': incident.sync_status,
            'user': incident.user,
            # Keep all other fields unchanged
        }
        
        # Create a copy of POST data that we can modify
        post_data = request.POST.copy()
        
        # Apply the original values for all fields except status
        for field, value in original_data.items():
            if field in post_data and field != 'status':
                post_data[field] = value
        
        form = IncidentForm(post_data, instance=incident)
        
        if form.is_valid():
            # Only save the status field
            incident.status = form.cleaned_data['status']
            incident.save(update_fields=['status'])
            
            messages.success(request, f"Le statut de l'incident #{incident.id} a été mis à jour avec succès.")
            return redirect('admin_incident_detail', incident_id=incident.id)
    else:
        form = IncidentForm(instance=incident)
    
    return render(request, 'admin/incident_edit.html', {
        'page_title': f'Éditer incident #{incident.id}',
        'form': form,
        'incident': incident,
        'is_create': False,
        'google_maps_api_key': getattr(settings, 'GOOGLE_MAPS_API_KEY', '')
    })

@login_required
@user_passes_test(is_staff)
def admin_incident_resolve(request, incident_id):
    """Vue pour marquer un incident comme résolu"""
    incident = get_object_or_404(Incident, id=incident_id)
    
    if incident.status != 'resolved':
        incident.status = 'resolved'
        incident.save()
        messages.success(request, f"L'incident #{incident.id} a été marqué comme résolu.")
    
    return redirect('admin_incident_detail', incident_id=incident.id)

@login_required
@user_passes_test(is_staff)
def admin_incident_delete(request, incident_id):
    """Vue pour supprimer un incident"""
    incident = get_object_or_404(Incident, id=incident_id)
    incident_id = incident.id
    
    try:
        incident.delete()
        messages.success(request, f"L'incident #{incident_id} a été supprimé avec succès.")
        return redirect('admin_incidents_list')
    except Exception as e:
        messages.error(request, f"Erreur lors de la suppression de l'incident: {str(e)}")
        return redirect('admin_incident_detail', incident_id=incident_id) 

@login_required
@user_passes_test(is_staff)
def admin_incident_update_status(request, incident_id):
    """
    View to update incident status directly from the incidents list
    """
    if request.method == 'POST':
        incident = get_object_or_404(Incident, id=incident_id)
        new_status = request.POST.get('status')
        
        # Validate that the status is one of the allowed choices
        valid_statuses = [status[0] for status in Incident.STATUS_CHOICES]
        
        if new_status in valid_statuses:
            # Only update the status field
            incident.status = new_status
            incident.save(update_fields=['status'])
            messages.success(request, f"Le statut de l'incident #{incident.id} a été mis à jour avec succès.")
        else:
            messages.error(request, "Statut invalide.")
    
    # Redirect back to the incidents list, preserving any filters
    referer = request.META.get('HTTP_REFERER')
    if referer:
        return HttpResponseRedirect(referer)
    return redirect('admin_incidents_list')


@login_required
@user_passes_test(is_staff)
def admin_users_list(request):
    """Vue pour afficher la liste des utilisateurs"""
    # Import User model here to avoid circular imports
    from django.contrib.auth import get_user_model
    User = get_user_model()
    
    users = User.objects.all().order_by('-date_joined')
    
    # Add incident count to each user
    users = users.annotate(incident_count=Count('incidents'))
    
    # Filters
    role_filter = request.GET.get('role', '')
    search_query = request.GET.get('search', '')
    
    if role_filter:
        users = users.filter(role=role_filter)
    if search_query:
        users = users.filter(username__icontains=search_query) | \
               users.filter(email__icontains=search_query) | \
               users.filter(phone__icontains=search_query)
    
    # Pagination
    from django.core.paginator import Paginator
    paginator = Paginator(users, 20)  # 20 users per page
    page_number = request.GET.get('page', 1)
    users_page = paginator.get_page(page_number)
    
    return render(request, 'admin/users_list.html', {
        'users': users_page,
        'role_filter': role_filter,
        'search_query': search_query,
    })


@login_required
@user_passes_test(is_staff)
def admin_user_delete(request, user_id):
    """Vue pour supprimer un utilisateur et tous ses incidents"""
    # Import User model here to avoid circular imports
    from django.contrib.auth import get_user_model
    User = get_user_model()
    
    user = get_object_or_404(User, id=user_id)
    
    if request.method == 'POST':
        # Delete all incidents associated with this user
        Incident.objects.filter(user=user).delete()
        
        # Delete the user
        username = user.username
        user.delete()
        
        messages.success(request, f"L'utilisateur {username} et tous ses incidents ont été supprimés.")
        return redirect('admin_users_list')


@login_required
@user_passes_test(is_staff)
def admin_incident_add_media(request, incident_id):
    """Vue pour ajouter un média additionnel à un incident"""
    incident = get_object_or_404(Incident, id=incident_id)
    
    if request.method == 'POST' and request.FILES.get('media_file'):
        from incidents.models import IncidentMedia
        
        media_file = request.FILES['media_file']
        media_type = request.POST.get('media_type', 'image')
        caption = request.POST.get('caption', '')
        
        # Créer le nouveau média
        new_media = IncidentMedia(
            incident=incident,
            media_file=media_file,
            media_type=media_type,
            caption=caption
        )
        new_media.save()
        
        messages.success(request, "Le média a été ajouté avec succès.")
    else:
        messages.error(request, "Veuillez sélectionner un fichier à télécharger.")
    
    return redirect('admin_incident_detail', incident_id=incident.id)