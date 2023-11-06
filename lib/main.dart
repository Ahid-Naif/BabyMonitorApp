import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Stream and Recordings',
      home: StreamAndRecordingsPage(),
    );
  }
}

class StreamAndRecordingsPage extends StatefulWidget {
  @override
  _StreamAndRecordingsPageState createState() =>
      _StreamAndRecordingsPageState();
}

class _StreamAndRecordingsPageState extends State<StreamAndRecordingsPage> {
  final List<String> _recordings = [];
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _fetchRecordings();
  }

  Future<void> _fetchRecordings() async {
    try {
      final response = await http.get(
          Uri.parse('http://192.168.1.103:5000/api/stream_and_recordings'));
      if (response.statusCode == 200) {
        setState(() {
          _recordings.addAll(List<String>.from(json.decode(response.body)));
        });
      } else {
        _showErrorDialog('Failed to load recordings');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Stream and Recordings'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Mjpeg(
              stream: 'http://192.168.1.103:5000/video_feed',
              error: (context, error, stack) {
                print(error); // Optionally print the error to the console.
                return Text('Failed to load the live stream',
                    style: TextStyle(color: Colors.red));
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _recordings.length,
              itemBuilder: (context, index) {
                String videoUrl =
                    'http://192.168.1.103:5000/static/${_recordings[index]}';
                return ListTile(
                  title: Text('Recording ${index + 1}'),
                  subtitle: Text(_recordings[index]),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          VideoPlaybackScreen(videoUrl: videoUrl),
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlaybackScreen extends StatefulWidget {
  final String videoUrl;

  VideoPlaybackScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlaybackScreenState createState() => _VideoPlaybackScreenState();
}

class _VideoPlaybackScreenState extends State<VideoPlaybackScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Playback'),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_controller.value.isPlaying) {
              _controller.pause();
            } else {
              _controller.play();
            }
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
