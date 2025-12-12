from django import forms
from incidents.models import Incident

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
        
    # Champs cachés pour gérer la suppression de fichiers
    clear_photo = forms.BooleanField(required=False, widget=forms.HiddenInput())
    clear_audio = forms.BooleanField(required=False, widget=forms.HiddenInput())
    
    def clean(self):
        cleaned_data = super().clean()
        # Logique personnalisée de validation si nécessaire
        return cleaned_data
    
    def save(self, commit=True):
        instance = super().save(commit=False)
        
        # Gestion de la suppression de photo
        if self.cleaned_data.get('clear_photo'):
            instance.photo.delete()
            instance.photo = None
        
        # Gestion de la suppression d'audio
        if self.cleaned_data.get('clear_audio'):
            instance.voice_note.delete()
            instance.voice_note = None
        
        if commit:
            instance.save()
        
        return instance 