import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class SavedRecordingsScreen extends StatefulWidget {
  const SavedRecordingsScreen({super.key});

  @override
  State<SavedRecordingsScreen> createState() => _SavedRecordingsScreenState();
}

class _SavedRecordingsScreenState extends State<SavedRecordingsScreen> {
  List<FileSystemEntity> recordings = [];
  final AudioPlayer audioPlayer = AudioPlayer();
  String? currentlyPlaying;
  String? currentLocation;

  @override
  void initState() {
    super.initState();
    loadRecordings();
    retrieveLocation();
  }

  Future<void> retrieveLocation() async {
    final location = await getLocationName();
    setState(() {
      currentLocation = location;
    });
  }

  Future<void> loadRecordings() async {
    final dir = await getApplicationDocumentsDirectory();
    final allFiles = dir.listSync();
    setState(() {
      recordings =
          allFiles.where((file) => file.path.endsWith('.m4a')).toList();
    });
  }

  Future<String> getDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      await player.setFilePath(filePath);
      final duration = player.duration ?? Duration.zero;
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final h = twoDigits(duration.inHours);
      final m = twoDigits(duration.inMinutes.remainder(60));
      final s = twoDigits(duration.inSeconds.remainder(60));
      return "$h:$m:$s";
    } catch (_) {
      return "--:--:--";
    } finally {
      await player.dispose();
    }
  }

  Future<String> getLocationName() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          return "Location permission denied";
        }
      }

      final position = await Geolocator.getCurrentPosition();
      final latitude = position.latitude.toStringAsFixed(5);
      final longitude = position.longitude.toStringAsFixed(5);

      try {
        final placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final name =
              "${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}"
                  .trim();
          return name.isNotEmpty ? name : "Lat: $latitude, Long: $longitude";
        }
      } catch (_) {}

      return "Lat: $latitude, Long: $longitude";
    } catch (e) {
      return "Location unavailable";
    }
  }

  Future<void> deleteRecording(FileSystemEntity file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Recording"),
        content: const Text("Are you sure you want to delete this recording?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await file.delete();
      loadRecordings();
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Recordings")),
      body: recordings.isEmpty
          ? const Center(child: Text("No saved recordings found."))
          : ListView.builder(
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                final file = recordings[index];
                final rawTimestamp = file.uri.pathSegments.last
                    .replaceAll('recording_', '')
                    .replaceAll('.m4a', '');
                final date = DateTime.fromMillisecondsSinceEpoch(
                    int.tryParse(rawTimestamp) ?? 0);
                final filename = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);

                return FutureBuilder<String>(
                  future: getDuration(file.path),
                  builder: (context, durationSnapshot) {
                    final durationText = durationSnapshot.data ?? "--:--:--";
                    return ListTile(
                      title: Text(filename),
                      subtitle: Text(
                          "Duration: $durationText\n${currentLocation ?? 'Fetching location...'}"),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(currentlyPlaying == file.path
                                ? Icons.stop
                                : Icons.play_arrow),
                            onPressed: () async {
                              if (currentlyPlaying == file.path) {
                                await audioPlayer.stop();
                                setState(() => currentlyPlaying = null);
                              } else {
                                await audioPlayer.setFilePath(file.path);
                                await audioPlayer.play();
                                setState(() => currentlyPlaying = file.path);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => deleteRecording(file),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
