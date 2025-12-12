import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:developer' as developer;
import 'package:get/get.dart';

class AudioService extends GetxService {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  String? _currentRecordingPath;
  bool _isRecording = false;
  bool _isPlaying = false;

  // Implement async initialization
  Future<AudioService> init() async {
    developer.log('Initializing AudioService');
    // Check microphone permission on init
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      developer.log('AudioService: Microphone permission already granted');
    } else {
      developer.log('AudioService: Microphone permission not granted. Will request when needed.');
    }
    return this;
  }

  Future<bool> startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        developer.log('Microphone permission denied');
        return false;
      }

      final directory = await getApplicationDocumentsDirectory();
      _currentRecordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );
      
      _isRecording = true;
      developer.log('Recording started at $_currentRecordingPath');
      return true;
    } catch (e, stackTrace) {
      developer.log('Error starting recording', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;
      
      final path = await _audioRecorder.stop();
      _isRecording = false;
      developer.log('Recording stopped at $path');
      return path;
    } catch (e, stackTrace) {
      developer.log('Error stopping recording', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> playRecording(String path) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();
      _isPlaying = true;
      
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });
      
      developer.log('Playing recording from $path');
      return true;
    } catch (e, stackTrace) {
      developer.log('Error playing recording', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> stopPlaying() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        _isPlaying = false;
        developer.log('Playback stopped');
      }
    } catch (e, stackTrace) {
      developer.log('Error stopping playback', error: e, stackTrace: stackTrace);
    }
  }

  @override
  void onClose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.onClose();
  }
  
  // Add dispose method to be called from widgets
  void dispose() {
    // No need to do anything special here since onClose will handle
    // actual cleanup when the service is disposed by GetX
    developer.log('AudioService dispose called from widget');
  }
} 