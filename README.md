# Vixel - Flutter Video Editor

A powerful video editing app built with Flutter and FFmpeg. All video processing happens locally on your device - no server required!

## Features

- **Compress Video** - Reduce video file size with adjustable quality settings
- **Cut Video** - Trim videos with precise start/end time selection
- **Merge Videos** - Combine multiple videos into one
- **Extract Audio** - Pull audio tracks from videos (MP3, AAC, WAV, M4A)
- **Audio on Video** - Add or mix audio tracks with video
- **Photos to Video** - Create slideshows with transitions
- **Add Watermark** - Overlay text or image watermarks
- **Play Video** - Built-in video player with full controls

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **FFmpeg Kit** - Full GPL build with all codecs
- **Provider** - State management
- **Chewie** - Video player UI

## Getting Started

### Prerequisites

- Flutter SDK 3.29.0 or higher
- Android Studio / Xcode for building

### Installation

1. Clone the repository:
```bash
cd /Users/ashwinkumar.sharma/Projects/vixel-flutter
```

2. Get dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building for Android

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`

### Building for iOS

```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── job.dart              # Job status tracking
│   └── video_info.dart       # Video metadata
├── services/
│   ├── ffmpeg_service.dart   # FFmpeg operations
│   ├── ffprobe_service.dart  # Video analysis
│   ├── job_service.dart      # Job management
│   └── storage_service.dart  # File management
├── screens/
│   ├── home_screen.dart
│   ├── compress_video_screen.dart
│   ├── cut_video_screen.dart
│   ├── merge_videos_screen.dart
│   ├── extract_audio_screen.dart
│   ├── audio_on_video_screen.dart
│   ├── photos_to_video_screen.dart
│   ├── add_watermark_screen.dart
│   ├── play_video_screen.dart
│   ├── records_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── video_picker_card.dart
│   ├── processing_overlay.dart
│   ├── settings_card.dart
│   └── job_card.dart
└── theme/
    └── app_theme.dart
```

## FFmpeg Commands Reference

The app uses the same FFmpeg commands as the original Python backend:

### Compress
```
ffmpeg -i input.mp4 -c:v libx264 -vf scale=1280:-1 -b:v 1000k -preset fast -c:a aac -b:a 128k output.mp4
```

### Cut
```
ffmpeg -i input.mp4 -ss START -to END -c copy output.mp4
```

### Merge
```
ffmpeg -i video1.mp4 -i video2.mp4 -filter_complex "[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1" output.mp4
```

### Extract Audio
```
ffmpeg -i input.mp4 -vn -b:a 128k output.mp3
```

## License

This project uses FFmpeg under the GPL license.
