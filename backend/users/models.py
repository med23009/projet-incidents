from django.contrib.auth.models import AbstractUser
from django.db import models

# Create your models here.

class User(AbstractUser):
    ROLES = (
        ('user', 'User'),
        ('admin', 'Administrator'),
    )
    
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=100, blank=True, null=True)
    password = models.CharField(max_length=128)
    phone = models.CharField(max_length=15, blank=True, null=True)
    role = models.CharField(max_length=10, choices=ROLES, default='user')
    token = models.CharField(max_length=255, blank=True, null=True)
    last_login = models.DateTimeField(blank=True, null=True)
    
    class Meta:
        db_table = 'users'
        
    def __str__(self):
        return self.email
