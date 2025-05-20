import 'dart:async';
import 'dart:convert' as convert;
import 'dart:math';
import 'package:http/http.dart' as http;

class CincopaVideoAnalyticsService {
  final String rid;
  final String? uid;
  final String? userEmail;
  final String? userName;
  final String? userAccountId;
  static String? _sessionID;
  final Map<int, int> _heatmap = {};
  int _lastPosition = -1;
  int _totalUniqueSeconds = 0;
  int? _durationInMilliseconds;
  String? _videoName;
  String? _hmid;
  Timer? _debounceTimer;
  DateTime? _nextCommitTime;

  static const String _analyticsBaseUrl =
      'https://analytics.cincopa.com/ohm.aspx';
  static const int _baseUpdateIntervalSeconds = 5;

  CincopaVideoAnalyticsService({
    required this.rid,
    this.uid,
    this.userEmail,
    this.userName,
    this.userAccountId,
  }) {
    _generateHmid();
    _initializeSessionID();
  }

  static String get sessionID {
    _initializeSessionID();
    return _sessionID!;
  }

  static void _initializeSessionID() {
    if (_sessionID == null) {
      _sessionID = DateTime.now().millisecondsSinceEpoch.toString();
      print('[Analytics] Session ID: $_sessionID');
    }
  }

  /// Initialize with duration and optional video name
  void initialize(int? durationMilliseconds, String? videoName) {
    _durationInMilliseconds = durationMilliseconds;
    _videoName = videoName ?? rid;
    _scheduleNextUpdate();
    _sendInitialStats();
  }

  /// Trigger on play/pause
  void sendPlayPauseEvent(bool isPlaying) {
    print('[Analytics] sendPlayPauseEvent: isPlaying=$isPlaying');
    _sendUpdateAndSendStats(forceSend: true);
    _nextCommitTime = null;
    _scheduleNextUpdate();
  }

  /// Call with each new second of playback
  void updatePlaybackPosition(int seconds) {
    if (seconds > 0 && seconds != _lastPosition) {
      _heatmap[seconds] = (_heatmap[seconds] ?? 0) + 1;
      _lastPosition = seconds;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(
        const Duration(milliseconds: 200),
        _checkAndSendUpdate,
      );
    }
  }

  void _checkAndSendUpdate() {
    final now = DateTime.now();
    if (_nextCommitTime == null || now.isAfter(_nextCommitTime!)) {
      _sendUpdateAndSendStats();
      _scheduleNextUpdate();
    }
  }

  void _scheduleNextUpdate() {
    _nextCommitTime = DateTime.now().add(
      const Duration(seconds: _baseUpdateIntervalSeconds),
    );
    print(
      '[Analytics] Next commit scheduled in ${_baseUpdateIntervalSeconds}s at $_nextCommitTime'
    );
  }

  /// Builds the compact hm-range string
  String _generateHmRange(Map<int, int> hm, int durSeconds) {
    _totalUniqueSeconds = 0;
    int lastSec = -2;
    int lastWriteSec = -2;
    int lastVol = 0;
    final buf = StringBuffer();
    final secs = hm.keys.toList()..sort();

    for (final sec in secs) {
      if (durSeconds == 0 || _totalUniqueSeconds < durSeconds) {
        _totalUniqueSeconds++;
      }
      final vol = hm[sec]!;
      if (lastVol != vol) {
        if (lastSec >= 0) {
          if (lastWriteSec != lastSec) buf.write('-$lastSec');
          if (lastVol > 1) buf.write(':$lastVol');
        }
        if (lastSec >= 0) buf.write(',');
        buf.write(sec);
        lastWriteSec = sec;
      } else if (lastSec + 1 < sec) {
        if (lastWriteSec != lastSec) buf.write('-$lastSec');
        if (lastVol > 1) buf.write(':$lastVol');
        buf.write(',');
        buf.write(sec);
        lastWriteSec = sec;
      }
      lastSec = sec;
      lastVol = vol;
    }

    if (_totalUniqueSeconds > 0 && lastSec >= 0) {
      if (lastWriteSec != lastSec) buf.write('-$lastSec');
      if (lastVol > 1) buf.write(':$lastVol');
    }

    return buf.toString();
  }

  void _sendUpdateAndSendStats({bool forceSend = false}) {
    if (_heatmap.isEmpty && !forceSend) return;

    final durSeconds = ((_durationInMilliseconds ?? 0) / 1000).floor();
    final hmlist = _generateHmRange(_heatmap, durSeconds);

    final Map<String, dynamic> payload = {
      'ckid': sessionID,
      'uid': uid ?? '',
      'hmid': _hmid ?? '',
      'rid': rid,
      'hm': hmlist,
      'prg': _totalUniqueSeconds,
      'name': _videoName ?? '',
      'dur': durSeconds,
    };


     final Map<String, dynamic> ud = {};
      if (userEmail != null) ud['email'] = userEmail;
      if (userName != null) ud['name'] = userName;
      if (userAccountId != null) ud['acc_id'] = userAccountId;
      if (ud.isNotEmpty) payload['ud'] = ud;


    final jsonString = convert.jsonEncode(payload);
    print('[Analytics] Sending payload j=$jsonString');

    final uri = Uri.parse(_analyticsBaseUrl).replace(
      queryParameters: {
        'j': jsonString,
        'setref': 'flutter-app',
      },
    );
    http.get(uri).then((response) {
      print(
          '[Analytics] Sent to $uri, status: ${response.statusCode}');
    }).catchError((error) {
      print('[Analytics] Error sending analytics: $error');
    });
  }

  void _sendInitialStats() {
    print('[Analytics] Sending initial stats');
    _sendUpdateAndSendStats(forceSend: true);
  }

  void _generateHmid() {
    _hmid = Random().nextInt(1 << 32).toString();
    print('[Analytics] Generated hmid: $_hmid');
  }

  /// Cancel pending timer
  void dispose() {
    _debounceTimer?.cancel();
  }
}

String? extractRidFromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final segs = uri.pathSegments;
    if (segs.isNotEmpty && segs.last.endsWith('.m3u8')) {
      return segs.last.replaceFirst('.m3u8', '');
    }
  } catch (_) {}
  return null;
}