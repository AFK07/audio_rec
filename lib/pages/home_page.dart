import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart'; // ✅ Correct
import 'package:just_audio/just_audio.dart'; // ✅ Playback
import 'package:path_provider/path_provider.dart'; // ✅ File path
import 'package:path/path.dart' as p; // ✅ Path operations

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioRecorder audioRecorder =
      AudioRecorder(); // ✅ Correct instantiation
  final AudioPlayer audioPlayer = AudioPlayer();

  String? recordingPath;
  bool isRecording = false;
  bool isPlaying = false;

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recorder')),
      body: _buildUI(),
      floatingActionButton: _recordingButton(),
    );
  }

  Widget _buildUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (recordingPath != null && File(recordingPath!).existsSync())
            ElevatedButton(
              onPressed: () async {
                if (audioPlayer.playing) {
                  await audioPlayer.stop();
                  setState(() => isPlaying = false);
                } else {
                  await audioPlayer.setFilePath(recordingPath!);
                  await audioPlayer.play();
                  setState(() => isPlaying = true);
                }
              },
              child: Text(isPlaying ? 'Stop Playing' : 'Play Recording'),
            )
          else
            const Text("No recording yet."),
        ],
      ),
    );
  }

  Widget _recordingButton() {
    return FloatingActionButton(
      onPressed: () async {
        if (isRecording) {
          final path = await audioRecorder.stop();
          setState(() {
            isRecording = false;
            recordingPath = path;
          });
        } else {
          final hasPermission = await audioRecorder.hasPermission();
          if (hasPermission) {
            final dir = await getApplicationDocumentsDirectory();
            final filePath = p.join(
              dir.path,
              'recording_${DateTime.now().millisecondsSinceEpoch}.m4a',
            );

            await audioRecorder.start(
              const RecordConfig(
                encoder: AudioEncoder.aacLc,
                bitRate: 128000,
                // Removed: samplingRate (not supported in v5.x)
              ),
              path: filePath,
            );

            setState(() {
              isRecording = true;
              recordingPath = null;
            });
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Microphone permission denied.")),
            );
          }
        }
      },
      child: Icon(isRecording ? Icons.stop : Icons.mic),
    );
  }
}
