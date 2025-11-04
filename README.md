# cincopa\_video\_player

A Flutter package that wraps an HLS video stream with built‑in Cincopa analytics tracking. Easily embed Cincopa-powered video playback in your Flutter apps, send events on play/pause/timeupdate, and configure user and video metadata.

## Features

* **HLS playback**: Stream `.m3u8` sources via a Flutter-friendly widget.
* **Cincopa analytics**: Automatically send `video.play`, `video.pause`, and periodic `video.timeupdate` events to Cincopa endpoints.
* **Configurable metadata**: Pass user data (e.g. `email`, `acc_id`) and video config (e.g. `autoplay`).
* **Customizable UI**: Control `aspectRatio`, `key`, and embed inside any layout.

## Installation

In your Flutter app’s `pubspec.yaml`, add:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cincopa_video_player:
    ^0.0.1  # or path/git reference to your local package
```

Then run:

```bash
flutter pub get
```

## Usage

Import the package and use the `CincopaVideoPlayer` widget:

```dart
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
  String _videoTitle = 'Amazing Cincopa  Video';
  Key _videoPlayerKey = UniqueKey();

  // User data for analytics
  Map<String, String> get _userData {
    final random = Random();
    final id = random.nextInt(1000000);
    return {
      'email': 'user${id}@example.com',
      'acc_id': '${1000 + id}',
    };
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
                  userData: _userData
                ),
              ),
              ElevatedButton(
                onPressed: () => _switchVideo(
                  'https://rtcdn.cincopa.com/AcCDOtcj2pv-.m3u8',
                  'Another Cincopa Video',
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
```

## API Reference

### `CincopaVideoPlayer`

| Parameter     | Type                 | Description                                     |
| ------------- | -------------------- | ----------------------------------------------- |
| `hlsUrl`      | `String`             | The `.m3u8` stream URL to play.                 |
| `userData`    | `Map<String,String>` | Metadata for Cincopa analytics (email, acc\_id).|
| `key`         | `Key?`               | Optional key to force widget rebuilds.          |
| `aspectRatio` | `double?`            | Aspect ratio for the player container.          |

## Example

See the full `example/` directory for a working demo app that switches streams and shows analytics events in action.

## Contributing

Feel free to open issues or PRs on GitHub. Please follow the Flutter package conventions and include tests for new features.

## License

MIT © Cincopa
