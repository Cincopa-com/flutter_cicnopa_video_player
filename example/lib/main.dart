import 'package:flutter/material.dart';
import 'package:cincopa_video_player/cincopa_video_player.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Example HLS URL
  String _hlsStreamUrl = 'https://rtcdn.cincopa.com/AcEDQoI4gGxV.m3u8';
  String _videoTitle = 'Cincopa Video Player demo';
  Key _videoPlayerKey = UniqueKey();

  // User data for analytics
  Map<String, String> get _userData {
    final random = Random();
    final id = random.nextInt(1000000);
    return {'email': 'user${id}@example.com', 'acc_id': '${1000 + id}'};
  }

  void _switchVideo(String newUrl, String newTitle) {
    setState(() {
      _hlsStreamUrl = newUrl;
      _videoTitle = newTitle;
      _videoPlayerKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text(_videoTitle)),
        body: Center(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                key: _videoPlayerKey,
                child: CincopaVideoPlayer(
                  hlsUrl: _hlsStreamUrl,
                  userData: _userData,
                ),
              ),
              ElevatedButton(
                onPressed:
                    () => _switchVideo(
                      'https://rtcdn.cincopa.com/AcCDOtcj2pv-.m3u8',
                      'For Marketers',
                    ),
                child: const Text('Switch Video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
