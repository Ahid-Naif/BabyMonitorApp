import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  final List<String> _recordings = [];

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _fetchRecordings();
  }

  Future<void> _initializeVideoPlayer() async {
    _controller = VideoPlayerController.network(
      'http://192.168.1.103:5000/video_feed',
    )..initialize().then((_) {
        setState(() {});
        _controller!.play();
      });
  }

  Future<void> _fetchRecordings() async {
    try {
      final response = await http.get(
          Uri.parse('http://192.168.1.103:5000/api/stream_and_recordings'));
      if (response.statusCode == 200) {
        setState(() {
          List<dynamic> fileList = json.decode(response.body);
          _recordings.clear();
          for (var file in fileList) {
            _recordings.add(file);
          }
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
    _controller?.dispose();
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
          if (_controller != null && _controller!.value.isInitialized)
            Container(
              padding: EdgeInsets.all(10),
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _recordings.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('Recording ${index + 1}'),
                  subtitle: Text(_recordings[index]),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlaybackScreen(
                            videoUrl:
                                'http://192.168.1.103:5000/static/${_recordings[index]}'),
                      ),
                    );
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
        setState(() {
          _controller.play();
        });
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
