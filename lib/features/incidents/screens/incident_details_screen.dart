import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:just_audio/just_audio.dart';
import '../models/incident.dart';
import '../../auth/controllers/auth_controller.dart';
import "package:timeago/timeago.dart" as timeago;

class IncidentDetailsScreen extends StatefulWidget {
  const IncidentDetailsScreen({super.key});

  @override
  State<IncidentDetailsScreen> createState() => _IncidentDetailsScreenState();
}

class _IncidentDetailsScreenState extends State<IncidentDetailsScreen> {
  late final Incident incident;
  late final AuthController authController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    incident = Get.arguments;
    authController = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // Format duration to mm:ss
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // Play or pause audio
  Future<void> _playPause(String path) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      try {
        // Check if we need to load a new audio file
        if (_audioPlayer.audioSource == null || 
            (_audioPlayer.audioSource as AudioSource).toString() != path) {
          await _audioPlayer.setFilePath(path);
          
          // Listen to player state changes
          _audioPlayer.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              setState(() {
                _isPlaying = false;
                // Réinitialiser la position mais s'assurer qu'elle ne dépasse pas la durée
                _position = Duration.zero;
              });
              // Réinitialiser le lecteur pour éviter les problèmes lors de la prochaine lecture
              _audioPlayer.stop();
            }
          });
          
          // Listen to duration changes
          _audioPlayer.durationStream.listen((newDuration) {
            if (newDuration != null) {
              setState(() {
                _duration = newDuration;
              });
            }
          });
          
          // Listen to position changes
          _audioPlayer.positionStream.listen((newPosition) {
            setState(() {
              // S'assurer que la position ne dépasse jamais la durée totale
              if (newPosition <= _duration) {
                _position = newPosition;
              } else {
                _position = _duration;
              }
            });
          });
        }
        
        await _audioPlayer.play();
        setState(() {
          _isPlaying = true;
        });
      } catch (e) {
        print('Error playing audio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: ${e.toString()}'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Details'),
        actions: [
          if (authController.isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                // TODO: Implement admin actions
                switch (value) {
                  case 'update_status':
                    _showUpdateStatusDialog(context);
                    break;
                  case 'assign':
                    _showAssignDialog(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'update_status',
                  child: Text('Update Status'),
                ),
                const PopupMenuItem(
                  value: 'assign',
                  child: Text('Assign Responder'),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Afficher l'image depuis l'URL du serveur ou le chemin local
            if (incident.photoUrl != null && incident.photoUrl!.isNotEmpty)
              Image.network(
                incident.photoUrl!,
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Si l'image du serveur ne peut pas être chargée, essayer le fichier local
                  if (incident.photoPath != null && incident.photoPath!.isNotEmpty) {
                    return Image.file(
                      File(incident.photoPath!),
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 250,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    );
                  }
                  return Container(
                    height: 250,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  );
                },
              )
            else if (incident.photoPath != null && incident.photoPath!.isNotEmpty)
              // Si pas d'URL serveur, utiliser le fichier local
              Image.file(
                File(incident.photoPath!),
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(incident.syncStatus),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          incident.syncStatus.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    incident.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    incident.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 8),
                      Text(
                        'Reported ${timeago.format(incident.createdAt)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(incident.latitude, incident.longitude),
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: ['a', 'b', 'c'],
                          userAgentPackageName: 'com.accidentsapp',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40.0,
                              height: 40.0,
                              point: LatLng(incident.latitude, incident.longitude),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Afficher le lecteur audio si un fichier audio est disponible
                  if (incident.voiceNotePath != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Voice Note',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Lecteur audio pour les notes vocales
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Bouton play/pause
                              IconButton(
                                onPressed: () {
                                  if (incident.voiceNotePath != null) {
                                    _playPause(incident.voiceNotePath!);
                                  }
                                },
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.blue,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Barre de progression
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SliderTheme(
                                      data: SliderThemeData(
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        trackHeight: 4,
                                        thumbColor: Colors.blue,
                                        activeTrackColor: Colors.blue,
                                        inactiveTrackColor: Colors.grey[300],
                                      ),
                                      child: Slider(
                                        value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble()),
                                        max: _duration.inMilliseconds.toDouble(),
                                        onChanged: (value) {
                                          final position = Duration(milliseconds: value.toInt());
                                          _audioPlayer.seek(position);
                                        },
                                      ),
                                    ),
                                    // Affichage du temps
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(_position)),
                                        Text(_formatDuration(_duration)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateStatusDialog(BuildContext context) {
    // TODO: Implement status update dialog
  }

  void _showAssignDialog(BuildContext context) {
    // TODO: Implement responder assignment dialog
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
