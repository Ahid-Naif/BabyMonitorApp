import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  String _baseUrl = 'http://192.168.1.106:5000'; // Default URL
  List<String> _recordings = [];
  Key _webViewKey = UniqueKey();
  Timer? timer;
  NotificationsServices notificationsServices = NotificationsServices();

  @override
  void initState() {
    super.initState();
    _loadIP();
    notificationsServices.initializeNotifications();
    _startPeriodicCheck();
  }

  void _startPeriodicCheck() {
    timer = Timer.periodic(Duration(seconds: 10), (Timer t) async {
      try {
        var response = await http.get(Uri.parse('$_baseUrl/api/check-danger'));
        if (response.statusCode == 200 && json.decode(response.body) == true) {
          notificationsServices.sendNotification(
            'Danger!!!',
            'Baby might be suffocating.',
          );
        }
      } catch (e) {
        print("Error: $e");
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _deleteAllRecordings() async {
    // Implement the logic to send a request to the server to delete all recordings
    // For example, an HTTP DELETE request
    try {
      final response =
          await http.delete(Uri.parse('$_baseUrl/api/delete_all_recordings'));
      if (response.statusCode == 200) {
        setState(() {
          _recordings
              .clear(); // Clear the recordings list on successful deletion
        });
      } else {
        _showErrorDialog('Failed to delete recordings');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _reloadWebView() {
    setState(() {
      _webViewKey = UniqueKey(); // Reset the WebView key to force reload
    });
  }

  void _refresh() {
    setState(() {
      // Clear the recordings list before fetching new data
      _recordings.clear();

      // Reset the WebView key to force it to reload
      _webViewKey = UniqueKey();
    });

    // Re-fetch the recordings
    _fetchRecordings();
  }

  Future<void> _loadIP() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedIP = prefs.getString('serverIP');
    if (savedIP != null) {
      setState(() {
        _baseUrl = 'http://$savedIP:5000';
      });
    }
    _fetchRecordings();
  }

  Future<void> _fetchRecordings() async {
    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/api/stream_and_recordings'));
      if (response.statusCode == 200) {
        setState(() {
          _recordings = List<String>.from(json.decode(response.body));
        });
      } else {
        _showErrorDialog('Failed to load recordings');
      }
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _navigateToSettings() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    );

    if (result != null && result is String) {
      setState(() {
        _baseUrl = 'http://$result:5000';
        _webViewKey = UniqueKey(); // Reset the WebView key
      });
      _fetchRecordings();
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
        title: Text(
            'Recordings (${_recordings.length})'), // Display the count of recordings
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _recordings.isNotEmpty
                ? _deleteAllRecordings
                : null, // Disable if no recordings
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: WebView(
              key: _webViewKey,
              initialUrl: '$_baseUrl/video_feed',
              javascriptMode: JavascriptMode.unrestricted,
              onWebResourceError: (error) {
                // Log the error and consider providing a way to reload the WebView
                print("WebView error: ${error.description}");
                _reloadWebView(); // Reload WebView on error
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: _recordings.length,
              itemBuilder: (context, index) {
                String videoUrl = '$_baseUrl/static/${_recordings[index]}';
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

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadIP();
  }

  void _loadIP() async {
    final prefs = await SharedPreferences.getInstance();
    _ipController.text = prefs.getString('serverIP') ?? '';
  }

  void _saveSettings() async {
    final String ip = _ipController.text;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverIP', ip);
    Navigator.of(context).pop(ip);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'Server IP Address',
                hintText: 'e.g., 192.168.1.106',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              child: Text('Save'),
            ),
          ],
        ),
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

class NotificationsServices {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final AndroidInitializationSettings _androidInitializationSettings =
      AndroidInitializationSettings('logo');

  void initializeNotifications() async {
    InitializationSettings initializationSettings = InitializationSettings(
      android: _androidInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void sendNotification(String title, String body) async {
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails('channelId', 'channelName',
            importance: Importance.max, priority: Priority.high);

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
        0, title, body, notificationDetails);
  }
}
