# Incidents App API Documentation

This document provides comprehensive documentation for the Incidents App REST API.

## Base URL

```
http://localhost:8000/api/
```

## Authentication

The API uses JWT (JSON Web Token) authentication.

### Login

```
POST /api/auth/login/
```

**Request Body:**
```json
{
  "username": "your_username",
  "password": "your_password"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "your_username",
    "email": "your_email@example.com",
    "is_staff": false
  }
}
```

### Register

```
POST /api/auth/register/
```

**Request Body:**
```json
{
  "username": "new_user",
  "email": "new_user@example.com",
  "password": "secure_password",
  "password_confirm": "secure_password"
}
```

**Response:**
```json
{
  "id": 2,
  "username": "new_user",
  "email": "new_user@example.com"
}
```

## Incidents

### List Incidents

```
GET /api/incidents/
```

**Headers:**
```
Authorization: Bearer <your_token>
```

**Query Parameters:**
- `page`: Page number for pagination
- `status`: Filter by status (e.g., "new", "in_progress", "resolved")
- `type`: Filter by incident type
- `search`: Search term for title or description

**Response:**
```json
{
  "count": 42,
  "next": "http://localhost:8000/api/incidents/?page=2",
  "previous": null,
  "results": [
    {
      "id": 1,
      "title": "Traffic Accident",
      "description": "Two cars collided at the intersection",
      "photo_url": "http://localhost:8000/media/incidents/photo1.jpg",
      "latitude": 40.7128,
      "longitude": -74.0060,
      "created_at": "2025-04-22T12:34:56Z",
      "status": "new",
      "incident_type": "accident",
      "sync_status": "synced",
      "user_id": 1,
      "additional_media": [
        {
          "type": "image",
          "url": "http://localhost:8000/media/incidents/media/image1.jpg",
          "caption": "Front view"
        },
        {
          "type": "video",
          "url": "http://localhost:8000/media/incidents/media/video1.mp4",
          "caption": "Witness statement"
        }
      ]
    },
    // More incidents...
  ]
}
```

### Get Incident Details

```
GET /api/incidents/{id}/
```

**Headers:**
```
Authorization: Bearer <your_token>
```

**Response:**
```json
{
  "id": 1,
  "title": "Traffic Accident",
  "description": "Two cars collided at the intersection",
  "photo_url": "http://localhost:8000/media/incidents/photo1.jpg",
  "voice_note_url": "http://localhost:8000/media/incidents/voice1.mp3",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "created_at": "2025-04-22T12:34:56Z",
  "status": "new",
  "incident_type": "accident",
  "sync_status": "synced",
  "user_id": 1,
  "additional_media": [
    {
      "type": "image",
      "url": "http://localhost:8000/media/incidents/media/image1.jpg",
      "caption": "Front view"
    },
    {
      "type": "video",
      "url": "http://localhost:8000/media/incidents/media/video1.mp4",
      "caption": "Witness statement"
    }
  ]
}
```

### Create Incident

```
POST /api/incidents/
```

**Headers:**
```
Authorization: Bearer <your_token>
Content-Type: multipart/form-data
```

**Form Data:**
- `title`: Incident title
- `description`: Incident description
- `photo`: Image file (optional)
- `voice_note`: Audio file (optional)
- `latitude`: Latitude coordinate
- `longitude`: Longitude coordinate
- `incident_type`: Type of incident
- `media_files`: Multiple files for additional media (optional)
- `media_types`: Types for each media file (comma-separated)
- `media_captions`: Captions for each media file (comma-separated)

**Response:**
```json
{
  "id": 3,
  "title": "New Incident",
  "description": "Description of the new incident",
  "photo_url": "http://localhost:8000/media/incidents/photo3.jpg",
  "voice_note_url": "http://localhost:8000/media/incidents/voice3.mp3",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "created_at": "2025-04-22T15:30:45Z",
  "status": "new",
  "incident_type": "hazard",
  "sync_status": "synced",
  "user_id": 1,
  "additional_media": [
    {
      "type": "image",
      "url": "http://localhost:8000/media/incidents/media/new_image1.jpg",
      "caption": "Scene overview"
    }
  ]
}
```

### Update Incident

```
PUT /api/incidents/{id}/
```

**Headers:**
```
Authorization: Bearer <your_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "title": "Updated Incident Title",
  "description": "Updated description",
  "status": "in_progress"
}
```

**Response:**
```json
{
  "id": 1,
  "title": "Updated Incident Title",
  "description": "Updated description",
  "photo_url": "http://localhost:8000/media/incidents/photo1.jpg",
  "voice_note_url": "http://localhost:8000/media/incidents/voice1.mp3",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "created_at": "2025-04-22T12:34:56Z",
  "status": "in_progress",
  "incident_type": "accident",
  "sync_status": "synced",
  "user_id": 1,
  "additional_media": [
    // Media items...
  ]
}
```

### Delete Incident

```
DELETE /api/incidents/{id}/
```

**Headers:**
```
Authorization: Bearer <your_token>
```

**Response:**
```
204 No Content
```

### Add Media to Incident

```
POST /api/incidents/{id}/add_media/
```

**Headers:**
```
Authorization: Bearer <your_token>
Content-Type: multipart/form-data
```

**Form Data:**
- `media_file`: Media file (image or video)
- `media_type`: Type of media ("image" or "video")
- `caption`: Caption for the media (optional)

**Response:**
```json
{
  "id": 5,
  "incident": 1,
  "media_file": "http://localhost:8000/media/incidents/media/new_media.jpg",
  "media_type": "image",
  "caption": "New evidence"
}
```

## User Management

### Get User Profile

```
GET /api/users/profile/
```

**Headers:**
```
Authorization: Bearer <your_token>
```

**Response:**
```json
{
  "id": 1,
  "username": "your_username",
  "email": "your_email@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "date_joined": "2025-01-15T10:30:45Z",
  "is_staff": false
}
```

### Update User Profile

```
PUT /api/users/profile/
```

**Headers:**
```
Authorization: Bearer <your_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "first_name": "John",
  "last_name": "Smith",
  "email": "john.smith@example.com"
}
```

**Response:**
```json
{
  "id": 1,
  "username": "your_username",
  "email": "john.smith@example.com",
  "first_name": "John",
  "last_name": "Smith",
  "date_joined": "2025-01-15T10:30:45Z",
  "is_staff": false
}
```

## Error Responses

### 400 Bad Request

```json
{
  "error": "Bad Request",
  "message": "Invalid input data",
  "details": {
    "field_name": [
      "Error message for this field"
    ]
  }
}
```

### 401 Unauthorized

```json
{
  "error": "Unauthorized",
  "message": "Authentication credentials were not provided or are invalid"
}
```

### 403 Forbidden

```json
{
  "error": "Forbidden",
  "message": "You do not have permission to perform this action"
}
```

### 404 Not Found

```json
{
  "error": "Not Found",
  "message": "The requested resource was not found"
}
```

### 500 Internal Server Error

```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred"
}
```
