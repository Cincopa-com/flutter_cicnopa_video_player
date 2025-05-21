# Changelog

All notable changes to this project will be documented.

## [0.0.2] - 2025-05-22

### Changed
- `video_name` no longer needs to be passed manually; it is now automatically extracted and used for analytics.

## [0.0.1] - 2025-05-20

### Added
- Initial release of `cincopa_video_player` package.
- HLS playback via `CincopaVideoPlayer` widget.
- Cincopa analytics event tracking: `video.play`, `video.pause`, and periodic `video.timeupdate`.
- Configurable user data (`email`, `cc_id`) and video metadata (`uid`, `video_name`).
- Example app showcasing stream switching and analytics integration.
