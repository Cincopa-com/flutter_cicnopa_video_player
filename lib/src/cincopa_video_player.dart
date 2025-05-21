import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'cincopa_video_analytics_service.dart';

class CincopaVideoPlayer extends StatefulWidget {
  final String hlsUrl;
  final Map<String, String>? userData;
  final Map<String, String>? configs;

  const CincopaVideoPlayer({
    Key? key,
    required this.hlsUrl,
    this.userData,
    this.configs,
  }) : super(key: key);

  @override
  State<CincopaVideoPlayer> createState() => _CincopaVideoPlayerState();
}

class _CincopaVideoPlayerState extends State<CincopaVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _isPlaying = false;
  Duration _currentTime = Duration.zero;
  late final CincopaVideoAnalyticsService _analyticsService;
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  
  String _videoName = '';
  //String _posterUrl = '';
 
  
  @override
  void initState() {
    super.initState();
    final rid = extractRidFromUrl(widget.hlsUrl)!;
    _analyticsService = CincopaVideoAnalyticsService(
      rid: rid,
      uid: widget.configs?['uid'],
      userEmail: widget.userData?['email'],
      userName: widget.userData?['name'],
      userAccountId: widget.userData?['acc_id'],
    );
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.hlsUrl))
      ..initialize().then((_) {


        // ────── NEW: fetch title & poster ──────
        _fetchVideoMetadata(rid).then((_) {
          // init analytics with fetched video_name
          _analyticsService.initialize(
            _controller.value.duration.inMilliseconds,
            _videoName,
          );
          _startControlsTimer();
          _controller.play();
          setState(() {});
        });
        _controller.addListener(_videoListener);
      });
  }

  // ────── NEW FUNCTION: fetch video_name & poster URL ──────
  Future<void> _fetchVideoMetadata(String rid) async {
    final url = 'https://rt.cincopa.com/jsonv2.aspx?fid=A4HAcLOLOO68!$rid';
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        if (items.isNotEmpty) {
          final item = items[0] as Map<String, dynamic>;
          _videoName = item['title'] ?? item['filename'] ?? '';
          //final versions = item['versions'] as Map<String, dynamic>? ?? {};
          //_posterUrl = (versions['jpg_600x450'] as Map<String, dynamic>?)?['url'] ?? '';
        }
      }
    } catch (_) { /* ignore errors */ }
  }


  void _videoListener() {
    final playing = _controller.value.isPlaying;
    if (playing != _isPlaying) {
      _isPlaying = playing;
      _startControlsTimer();
      _analyticsService.sendPlayPauseEvent(_isPlaying);
      setState(() {});
    }
    if (playing) {
      final pos = _controller.value.position;
      if (pos != _currentTime) {
        _currentTime = pos;
        _analyticsService.updatePlaybackPosition(_currentTime.inSeconds);
      }
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _startControlsTimer();
      } else {
        _controlsTimer?.cancel();
      }
    });
  }

  Future<void> _toggleFullScreen() async {
    final wasPlaying = _controller.value.isPlaying;
    if (wasPlaying) await _controller.pause();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenVideoPlayer(controller: _controller),
      ),
    );
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (wasPlaying) _controller.play();
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _analyticsService.dispose();
    _controlsTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _seekRelative(Duration offset) {
    final current = _controller.value.position;
    final target = current + offset;
    final min = Duration.zero;
    final max = _controller.value.duration;
    final clamped = target < min
        ? min
        : target > max
            ? max
            : target;
    _controller.seekTo(clamped);
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControlsVisibility,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_controller),

            // when hidden: thin bottom bar only
            if (!_controlsVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 3,
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: false,
                    colors: VideoProgressColors(
                      playedColor: Color(0xFF0086CF),
                      bufferedColor: Colors.white60,
                      backgroundColor: Colors.white24,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

            if (_controlsVisible)
              // controls + integrated progress bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // thicker, interactive progress bar
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (e) {
                          final box = context.findRenderObject() as RenderBox;
                          final pos = box.globalToLocal(e.globalPosition);
                          final pct = pos.dx / box.size.width;
                          final seekTo = _controller.value.duration * pct;
                          _controller.seekTo(seekTo < Duration.zero
                              ? Duration.zero
                              : seekTo > _controller.value.duration
                                  ? _controller.value.duration
                                  : seekTo);
                        },
                        child: SizedBox(
                          height: 10,
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: Color(0xFF0086CF),
                              bufferedColor: Colors.white60,
                              backgroundColor: Colors.white24,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),

                      // controls row (44px tall, centered buttons)
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.replay_10, color: Colors.white),
                              onPressed: () =>
                                  _seekRelative(const Duration(seconds: -10)),
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _controller.value.isPlaying
                                      ? _controller.pause()
                                      : _controller.play();
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.forward_10, color: Colors.white),
                              onPressed: () =>
                                  _seekRelative(const Duration(seconds: 10)),
                            ),
                            Expanded(
                              child: Text(
                                '${_formatDuration(_currentTime)} / '
                                '${_formatDuration(_controller.value.duration)}',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.fullscreen, color: Colors.white),
                              onPressed: _toggleFullScreen,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullScreenVideoPlayer({Key? key, required this.controller})
      : super(key: key);

  @override
  State<_FullScreenVideoPlayer> createState() =>
      _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  bool _controlsVisible = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _startControlsTimer();
      } else {
        _controlsTimer?.cancel();
      }
    });
  }

  void _seekRelative(Duration offset) {
    final current = widget.controller.value.position;
    final target = current + offset;
    final min = Duration.zero;
    final max = widget.controller.value.duration;
    final clamped = target < min
        ? min
        : target > max
            ? max
            : target;
    widget.controller.seekTo(clamped);
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControlsVisibility,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),
            ),

            if (!_controlsVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 3,
                  child: VideoProgressIndicator(
                    widget.controller,
                    allowScrubbing: false,
                    colors: VideoProgressColors(
                      playedColor: Color(0xFF0086CF),
                      bufferedColor: Colors.white60,
                      backgroundColor: Colors.white24,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

            if (_controlsVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black54,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (e) {
                          final box =
                              context.findRenderObject() as RenderBox;
                          final pos =
                              box.globalToLocal(e.globalPosition);
                          final pct = pos.dx / box.size.width;
                          final seekTo =
                              widget.controller.value.duration * pct;
                          widget.controller.seekTo(seekTo < Duration.zero
                              ? Duration.zero
                              : seekTo >
                                      widget.controller.value.duration
                                  ? widget.controller.value.duration
                                  : seekTo);
                        },
                        child: SizedBox(
                          height: 10,
                          child: VideoProgressIndicator(
                            widget.controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: Color(0xFF0086CF),
                              bufferedColor: Colors.white60,
                              backgroundColor: Colors.white24,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        height: 44,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.replay_10,
                                  color: Colors.white),
                              onPressed: () =>
                                  _seekRelative(Duration(seconds: -10)),
                            ),
                            IconButton(
                              icon: Icon(
                                widget.controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  widget.controller.value.isPlaying
                                      ? widget
                                          .controller
                                          .pause()
                                      : widget
                                          .controller
                                          .play();
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.forward_10,
                                  color: Colors.white),
                              onPressed: () =>
                                  _seekRelative(Duration(seconds: 10)),
                            ),
                            Expanded(
                              child: Text(
                                '${_formatDuration(widget.controller.value.position)} / '
                                '${_formatDuration(widget.controller.value.duration)}',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.fullscreen_exit,
                                  color: Colors.white),
                              onPressed: () =>
                                  Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
