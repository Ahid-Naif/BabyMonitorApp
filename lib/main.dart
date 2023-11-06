import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchRecordings();
  }

  Future<void> _fetchRecordings() async {
    try {
      final response = await http.get(
          Uri.parse('http://192.168.1.106:5000/api/stream_and_recordings'));
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Stream and Recordings'),
      ),
      body: Column(
        children: [
          // Adjusted the flex property to ensure that the WebView and the ListView are displayed proportionately.
          Expanded(
            flex: 2, // Giving the WebView less space
            child: WebView(
              initialUrl: 'http://192.168.1.106:5000/video_feed',
              javascriptMode: JavascriptMode.unrestricted,
            ),
          ),
          Expanded(
            flex: 3, // Giving more space to the ListView for recordings
            child: ListView.builder(
              itemCount: _recordings.length,
              itemBuilder: (context, index) {
                String videoUrl =
                    'http://192.168.1.106:5000/static/${_recordings[index]}';
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
      }).catchError((error) {
        print('Error initializing video player: $error');
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
