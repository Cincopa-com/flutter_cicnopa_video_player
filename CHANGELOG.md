# Changelog

All notable changes to this project will be documented.

## [0.0.4] - 2025-05-26
### Changed
- Bug fixing

## [0.0.3] - 2025-05-26
### Changed
- The `configs` parameter now accepts `{ autoplay: false }` to disable the default autoplay behavior.

## [0.0.2] - 2025-05-22
### Changed
- `video_name` is now extracted automatically and no longer needs to be passed manually for analytics.

## [0.0.1] - 2025-05-20
### Added
- Initial release of the `cincopa_video_player` package  
- HLS playback via the `CincopaVideoPlayer` widget  
- Cincopa analytics event tracking: `video.play`, `video.pause`, and periodic `video.timeupdate`  
- Configurable user data (`email`, `acc_id`) and video metadata (`uid`, `video_name`)  
- Example app showcasing stream switching and analytics integration  
