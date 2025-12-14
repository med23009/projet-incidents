<div align="center">
  <img src="assets/icons/palestine_flag.png" alt="Palestine Flag" width="200"/>
</div>

# 🚨 Urban Incidents Reporter

A modern Flutter application for reporting and managing urban incidents in real-time.

## 📑 Table of Contents
- [Features](#-features)
- [Tech Stack](#️-tech-stack)
- [Palestine Support](#-palestine-support)
- [Project Structure](#-project-structure)
- [Detailed Documentation](#-detailed-documentation)
  - [Frontend](#frontend)
  - [Backend](#backend)
  - [Communication Flow](#communication-flow)
- [Package Details](#-package-details)
- [Getting Started](#-getting-started)
- [Supported Platforms](#-supported-platforms)
- [Security Features](#-security-features)
- [Contributing](#-contributing)
- [License](#-license)
- [Developer](#-developer)
- [Acknowledgments](#-acknowledgments)

## 🇵🇸 Palestine Support

This application stands in solidarity with Palestine. The app icon features the Palestinian flag as a symbol of our support for Palestinian rights and freedom.

## 🌟 Features

- 📱 Beautiful and intuitive user interface
- 🔐 Secure authentication with biometric support
- 📍 Real-time incident mapping
- 📸 Multiple media uploads (photos and videos) for incident documentation
- 🎤 Voice recording for detailed descriptions
- 🔄 Offline-first architecture
- 📊 Incident tracking and management
- 👥 Role-based access (Citizen/Admin)
- 🌐 Multi-language support
- 🌙 Dark/Light theme

## 🛠️ Tech Stack

- **Frontend**: Flutter
  - **State Management**: GetX
  - **Local Database**: SQLite
  - **Authentication**: JWT + Biometric
  - **Maps**: Google Maps Flutter
  - **Media**: Image Picker, Flutter Sound, Cached Network Image
  - **Location**: Geolocator
  - **Internationalization**: Flutter Intl

- **Backend**: Django
  - **Database**: SQLite
  - **API**: Django REST Framework
  - **Authentication**: JWT
  - **Media Storage**: Django Storage

## 📁 Project Structure

The project is organized using a feature-based architecture:

```
accidentsapp/
├── lib/
│   ├── core/                 # Core functionality used across the app
│   │   ├── auth/             # Authentication services
│   │   ├── constants/        # App-wide constants
│   │   ├── database/         # Local database configuration
│   │   ├── network/          # Network services and API clients
│   │   ├── services/         # Common services
│   │   ├── theme/            # App theming
│   │   ├── utils/            # Utility functions
│   │   └── widgets/          # Reusable widgets
│   │
│   ├── features/             # App features
│   │   ├── auth/             # Authentication feature
│   │   │   ├── controllers/  # Controllers for auth screens
│   │   │   ├── models/       # Auth data models
│   │   │   ├── repositories/ # Auth data repositories
│   │   │   ├── screens/      # Auth UI screens
│   │   │   └── services/     # Auth-specific services
│   │   │
│   │   ├── home/             # Home feature
│   │   │   └── screens/      # Home screens
│   │   │
│   │   └── incidents/        # Incidents feature
│   │       ├── controllers/  # Incident controllers
│   │       ├── models/       # Incident data models
│   │       ├── repositories/ # Incident data repositories
│   │       ├── screens/      # Incident UI screens
│   │       ├── services/     # Incident-specific services
│   │       └── widgets/      # Incident-specific widgets
│   │
│   └── main.dart             # App entry point
│
├── backend/                  # Django backend
│   ├── admin_panel/          # Admin panel app
│   ├── docs/                 # API documentation
│   ├── incidents/            # Incidents app
│   ├── incidents_api/        # Incidents API
│   ├── templates/            # HTML templates
│   └── users/                # Users app
│
└── assets/                   # App assets
    ├── icons/                # App icons
    ├── images/               # App images
    └── flags/                # Language flags
```

## 📚 Detailed Documentation

### <a name="frontend"></a>Frontend

The frontend is built with Flutter, a cross-platform UI toolkit that allows us to build natively compiled applications from a single codebase.

#### Key Components

1. **State Management with GetX**
   - Reactive state management
   - Dependency injection
   - Route management
   - Example code:
   ```dart
   // Controller registration
   Get.put(AuthController());
   
   // State management
   final count = 0.obs;
   void increment() => count.value++;
   
   // Navigation
   Get.to(() => IncidentDetailsScreen(id: incidentId));
   ```

2. **Local Database with SQLite**
   - Used for offline-first architecture
   - Stores user data and incidents locally
   - Example code:
   ```dart
   // Database initialization
   final db = await openDatabase(
     join(await getDatabasesPath(), 'incidents_database.db'),
     onCreate: (db, version) {
       return db.execute(
         'CREATE TABLE incidents(id INTEGER PRIMARY KEY, title TEXT, description TEXT, latitude REAL, longitude REAL, status TEXT)',
       );
     },
     version: 1,
   );
   
   // Insert data
   await db.insert(
     'incidents',
     incident.toMap(),
     conflictAlgorithm: ConflictAlgorithm.replace,
   );
   ```

3. **Authentication System**
   - JWT token authentication
   - Biometric authentication
   - Secure storage for tokens
   - Example code:
   ```dart
   // JWT Authentication
   final response = await http.post(
     Uri.parse('$apiUrl/auth/login/'),
     headers: <String, String>{
       'Content-Type': 'application/json',
     },
     body: jsonEncode(<String, String>{
       'username': username,
       'password': password,
     }),
   );
   
   // Biometric Authentication
   final localAuth = LocalAuthentication();
   final didAuthenticate = await localAuth.authenticate(
     localizedReason: 'Please authenticate to access the app',
     options: const AuthenticationOptions(biometricOnly: true),
   );
   ```

   **Biometric Authentication Implementation Details:**
   
   The app uses the `local_auth` package to implement biometric authentication (fingerprint, face ID, etc.). Here's how it works:
   
   1. **Check Biometric Availability:**
   ```dart
   Future<bool> isBiometricAvailable() async {
     final localAuth = LocalAuthentication();
     final canCheckBiometrics = await localAuth.canCheckBiometrics;
     final isDeviceSupported = await localAuth.isDeviceSupported();
     return canCheckBiometrics && isDeviceSupported;
   }
   ```
   
   2. **Get Available Biometric Types:**
   ```dart
   Future<List<BiometricType>> getAvailableBiometrics() async {
     final localAuth = LocalAuthentication();
     return await localAuth.getAvailableBiometrics();
   }
   ```
   
   3. **Authenticate User:**
   ```dart
   Future<bool> authenticateUser() async {
     final localAuth = LocalAuthentication();
     try {
       return await localAuth.authenticate(
         localizedReason: 'Authenticate to access your account',
         options: const AuthenticationOptions(
           stickyAuth: true,
           biometricOnly: false,
         ),
       );
     } catch (e) {
       print('Authentication error: $e');
       return false;
     }
   }
   ```
   
   4. **Integration with Login Flow:**
   ```dart
   void loginWithBiometrics() async {
     // Check if biometrics are available
     if (await isBiometricAvailable()) {
       // Authenticate user
       final authenticated = await authenticateUser();
       if (authenticated) {
         // Retrieve stored credentials from secure storage
         final username = await _secureStorage.read(key: 'username');
         final password = await _secureStorage.read(key: 'password');
         
         if (username != null && password != null) {
           // Login with stored credentials
           await loginWithCredentials(username, password);
         } else {
           // Handle case where credentials aren't stored
           Get.snackbar('Error', 'No stored credentials found');
         }
       }
     } else {
       Get.snackbar('Not Available', 'Biometric authentication not available on this device');
     }
   }
   ```
   
   5. **Security Considerations:**
   - Biometric data never leaves the user's device
   - Credentials are stored in secure storage (Flutter Secure Storage)
   - Fallback to password authentication is always available
   - Biometric settings can be toggled in app settings

4. **Maps Integration**
   - Google Maps for incident location
   - Geolocation services
   - Example code:
   ```dart
   GoogleMap(
     mapType: MapType.normal,
     initialCameraPosition: CameraPosition(
       target: LatLng(incident.latitude, incident.longitude),
       zoom: 14.0,
     ),
     markers: Set<Marker>.of(markers),
     onMapCreated: (GoogleMapController controller) {
       _controller.complete(controller);
     },
   )
   ```

5. **Media Handling (Images)**
   - The app supports images for comprehensive incident documentation
   
   **Image Capture and Upload:**
   ```dart
   Future<void> captureImage(ImageSource source) async {
     try {
       final pickedFile = await ImagePicker().pickImage(
         source: source,
         imageQuality: 80,
       );
       
       if (pickedFile != null) {
         // Add to incident media list
         final media = IncidentMedia(
           file: File(pickedFile.path),
           type: MediaType.image,
           isUploaded: false,
         );
         
         incidentMediaList.add(media);
         update(); // Update UI
         
         // Prepare for upload when online
         _mediaUploadQueue.add(media);
       }
     } catch (e) {
       print('Error capturing image: $e');
       Get.snackbar('Error', 'Failed to capture image');
     }
   }
   ```

### <a name="backend"></a>Backend

The backend is built with Django, a high-level Python web framework that encourages rapid development and clean, pragmatic design.

#### Key Components

1. **Django REST Framework**
   - RESTful API design
   - Serialization
   - Authentication
   - Example code:
   ```python
   # Serializer
   class IncidentSerializer(serializers.ModelSerializer):
       class Meta:
           model = Incident
           fields = ['id', 'title', 'description', 'latitude', 'longitude', 
                     'created_at', 'updated_at', 'status', 'reporter']
   
   # ViewSet
   class IncidentViewSet(viewsets.ModelViewSet):
       queryset = Incident.objects.all()
       serializer_class = IncidentSerializer
       permission_classes = [IsAuthenticated]
       
       def get_queryset(self):
           user = self.request.user
           if user.is_staff:
               return Incident.objects.all()
           return Incident.objects.filter(reporter=user)
   ```

2. **JWT Authentication**
   - Token-based authentication
   - Refresh tokens
   - Example code:
   ```python
   # settings.py
   REST_FRAMEWORK = {
       'DEFAULT_AUTHENTICATION_CLASSES': (
           'rest_framework_simplejwt.authentication.JWTAuthentication',
       ),
   }
   
   SIMPLE_JWT = {
       'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
       'REFRESH_TOKEN_LIFETIME': timedelta(days=14),
       'ROTATE_REFRESH_TOKENS': True,
   }
   ```

3. **SQLite Database**
   - Relational database for data storage
   - Example model:
   ```python
   class Incident(models.Model):
       STATUS_CHOICES = (
           ('pending', 'Pending'),
           ('in_progress', 'In Progress'),
           ('resolved', 'Resolved'),
           ('closed', 'Closed'),
       )
       
       title = models.CharField(max_length=255)
       description = models.TextField()
       latitude = models.FloatField()
       longitude = models.FloatField()
       created_at = models.DateTimeField(auto_now_add=True)
       updated_at = models.DateTimeField(auto_now=True)
       status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
       reporter = models.ForeignKey(User, on_delete=models.CASCADE, related_name='incidents')
       
       def __str__(self):
           return self.title
   ```

4. **Media Storage**
   - File uploads handling
   - Example code:
   ```python
   class IncidentMedia(models.Model):
       incident = models.ForeignKey(Incident, on_delete=models.CASCADE, related_name='media')
       file = models.FileField(upload_to='incident_media/%Y/%m/%d/')
       file_type = models.CharField(max_length=10, choices=(
           ('image', 'Image'),
           ('video', 'Video'),
           ('audio', 'Audio'),
       ))
       uploaded_at = models.DateTimeField(auto_now_add=True)
   ```

### <a name="communication-flow"></a>Communication Flow

The frontend and backend communicate through RESTful API endpoints. Here's the typical flow:

1. **Authentication Flow**
   ```
   Flutter App                                Django Backend
       |                                           |
       |--- POST /api/auth/login/ --------------->|
       |                                           |
       |<-- 200 OK (access & refresh tokens) -----|
       |                                           |
       |--- GET /api/user/ (with token) --------->|
       |                                           |
       |<-- 200 OK (user data) ------------------|
   ```

2. **Incident Reporting Flow**
   ```
   Flutter App                                Django Backend
       |                                           |
       |--- POST /api/incidents/ ---------------->|
       |                                           |
       |<-- 201 Created (incident data) ----------|
       |                                           |
       |--- POST /api/incidents/{id}/media/ ----->|
       |                                           |
       |<-- 202 Accepted (processing) ------------|
       |                                           |
       |--- GET /api/incidents/{id}/ ------------>|
       |                                           |
       |<-- 200 OK (updated incident data) -------|
   ```

3. **Offline Synchronization Flow**
   ```
   Flutter App                                Django Backend
       |                                           |
       |--- POST /api/sync/ (batch updates) ----->|
       |                                           |
       |<-- 200 OK (sync results) ----------------|
   ```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK
- Android Studio / VS Code
- Python 3.8+ (for backend)
- Django 4.0+ (for backend)
- Git

### Installation

1. Clone the repository

```bash
git clone https://github.com/med23009/projet-incidents.git
```

2. Install frontend dependencies

```bash
cd accidentsapp
flutter pub get
```

3. Install backend dependencies

```bash
cd backend
pip install -r requirements.txt
```

4. Run migrations

```bash
python manage.py migrate
```

5. Create a superuser

```bash
python manage.py createsuperuser
```

6. Start the backend server

```bash
python manage.py runserver
```

7. Run the Flutter app

```bash
cd ..
flutter run
```

## 📱 Supported Platforms

- Android
- iOS
- Web (experimental)

## 🔒 Security Features

- Biometric authentication
- JWT token-based security
- Secure local storage
- Encrypted data transmission
- HTTPS enforcement
- CSRF protection
- XSS prevention
- Rate limiting

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request


## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Django community for the robust backend framework
- All contributors and supporters
- The open-source community
