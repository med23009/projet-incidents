import 'package:flutter/material.dart';
import '../models/incident.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

class IncidentCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback onTap;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (incident.photoUrl != null || incident.additionalMedia.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: _buildMediaPreview(context),
                    ),
                    if (incident.additionalMedia.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${incident.additionalMedia.length + (incident.photoUrl != null ? 1 : 0)}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(incident.status),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(incident.status).withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(incident.status),
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  incident.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getTypeColor(incident.incidentType),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: _getTypeColor(incident.incidentType).withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getTypeIcon(incident.incidentType),
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  incident.incidentType,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getSyncStatusColor(incident.syncStatus),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: _getSyncStatusColor(incident.syncStatus).withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getSyncStatusIcon(incident.syncStatus),
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  incident.syncStatus.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        incident.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        incident.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  timeago.format(incident.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context) {
    // If there's a main photo, show it first
    if (incident.photoUrl != null) {
      return CachedNetworkImage(
        imageUrl: incident.photoUrl!,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 180,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 180,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
              const SizedBox(height: 8),
              const Text('Image not available', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    // If there's no main photo but there are additional media files
    else if (incident.additionalMedia.isNotEmpty) {
      final firstMedia = incident.additionalMedia.first;
      if (firstMedia['type'] == 'image') {
        return CachedNetworkImage(
          imageUrl: firstMedia['url'],
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 180,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            height: 180,
            color: Colors.grey[300],
            child: Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
          ),
        );
      } else if (firstMedia['type'] == 'video') {
        return Container(
          height: 180,
          color: Colors.black,
          child: const Center(
            child: Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
          ),
        );
      }
    }
    
    // Fallback if no media
    return Container(
      height: 180,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.photo, size: 40, color: Colors.grey),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'nouveau':
        return Colors.blue;
      case 'in progress':
      case 'en cours':
        return Colors.orange;
      case 'resolved':
      case 'résolu':
        return Colors.green;
      case 'closed':
      case 'fermé':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
      case 'incendie':
        return Colors.red;
      case 'accident':
        return Colors.amber;
      case 'crime':
        return Colors.purple;
      case 'medical':
      case 'médical':
        return Colors.green;
      case 'hazard':
      case 'danger':
        return Colors.orange;
      case 'breakdown':
      case 'panne':
        return Colors.teal;
      case 'obstruction':
        return Colors.indigo;
      case 'weather':
      case 'météo':
        return Colors.lightBlue;
      default:
        return Colors.blue;
    }
  }

  Color _getSyncStatusColor(String syncStatus) {
    switch (syncStatus.toLowerCase()) {
      case 'synced':
      case 'synchronisé':
        return Colors.green;
      case 'pending':
      case 'en attente':
        return Colors.orange;
      case 'failed':
      case 'échoué':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'new':
      case 'nouveau':
        return Icons.fiber_new;
      case 'in progress':
      case 'en cours':
        return Icons.pending;
      case 'resolved':
      case 'résolu':
        return Icons.check_circle;
      case 'closed':
      case 'fermé':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
  
  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
      case 'incendie':
        return Icons.local_fire_department;
      case 'accident':
        return Icons.car_crash;
      case 'crime':
        return Icons.gavel;
      case 'medical':
      case 'médical':
        return Icons.medical_services;
      case 'hazard':
      case 'danger':
        return Icons.warning;
      case 'breakdown':
      case 'panne':
        return Icons.build;
      case 'obstruction':
        return Icons.block;
      case 'weather':
      case 'météo':
        return Icons.wb_cloudy;
      default:
        return Icons.category;
    }
  }
  
  IconData _getSyncStatusIcon(String syncStatus) {
    switch (syncStatus.toLowerCase()) {
      case 'synced':
      case 'synchronisé':
        return Icons.cloud_done;
      case 'pending':
      case 'en attente':
        return Icons.cloud_upload;
      case 'failed':
      case 'échoué':
        return Icons.cloud_off;
      default:
        return Icons.cloud;
    }
  }
}
