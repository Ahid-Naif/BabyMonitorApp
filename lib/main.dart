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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  List<String> _recordings = [];

  @override
  void initState() {
    super.initState();
    // Start the camera stream video player controller
    _controller =
        VideoPlayerController.network('http://192.168.1.103:5000/video_feed')
          ..initialize().then((_) {
            setState(() {});
            _controller!.play();
          });
    fetchRecordings();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> fetchRecordings() async {
    final response = await http
        .get(Uri.parse('http://192.168.1.103:5000/api/stream_and_recordings'));
    if (response.statusCode == 200) {
      setState(() {
        // Assuming your recordings list is just a list of strings
        // You'll need to adjust this parsing based on the actual structure of your response
        _recordings = List<String>.from(json.decode(response.body));
      });
    } else {
      throw Exception('Failed to load recordings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Stream and Recordings'),
      ),
      body: Column(
        children: <Widget>[
          if (_controller != null && _controller!.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _recordings.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_recordings[index]),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
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

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  VideoPlayerScreen({required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
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
      appBar: AppBar(title: Text('Play Video')),
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
