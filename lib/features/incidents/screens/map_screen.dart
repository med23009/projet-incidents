import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/incident_controller.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final IncidentController _incidentController = Get.find<IncidentController>();
  final LocationService _locationService = Get.find<LocationService>();
  
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  LatLng _initialPosition = const LatLng(0, 0);
  double _initialZoom = 2.0;
  
  @override
  void initState() {
    super.initState();
    _initializeMap();
  }
  
  Future<void> _initializeMap() async {
    try {
      // Obtenir la position actuelle
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _initialZoom = 13.0;
      }
      
      // Charger les incidents si nécessaire
      if (_incidentController.incidents.isEmpty) {
        await _incidentController.loadIncidents();
      }
      
      // Ajouter les marqueurs
      _updateMarkers();
      
      setState(() {});
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to initialize map: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  
  void _updateMarkers() {
    _markers.clear();
    
    for (final incident in _incidentController.incidents) {
      final marker = Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(incident.latitude, incident.longitude),
        child: GestureDetector(
          onTap: () => Get.toNamed('/incident_details', arguments: incident),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  incident.title,
                  style: const TextStyle(fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.location_on,
                color: _getMarkerColor(incident.status),
                size: 30,
              ),
            ],
          ),
        ),
      );
      
      _markers.add(marker);
    }
    
    setState(() {});
  }
  
  Color _getMarkerColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Map'),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _initialPosition,
          initialZoom: _initialZoom,
          maxZoom: 18.0,
          onTap: (tapPosition, point) {
            // Handle map tap if needed
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
            userAgentPackageName: 'com.accidentsapp',
            maxZoom: 19,
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed('/incident/create'),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Report'),
      ),
    );
  }
}
