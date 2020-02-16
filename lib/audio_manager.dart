import 'package:audiofileplayer/audiofileplayer.dart';
import 'package:audiofileplayer/audio_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logging/logging.dart';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'audio_profiles.dart';
import 'package:http/http.dart' as http;

class AudioManager {
  Audio _backgroundAudio;
  bool backgroundAudioPlaying;
  double backgroundAudioDurationSeconds;
  double backgroundAudioPositionSeconds = 0;
  double seekSliderValue;

  int _currentIndex = 0;

  final Logger _logger = Logger('audiofileplayer_example');
  List<AudioProfile> audioProfiles;
  AudioProfile currentSong;
  static const String replayButtonId = 'replayButtonId';
  static const String newReleasesButtonId = 'newReleasesButtonId';

  AudioManager({this.audioProfiles, int defaultIndex = 0}) {
    AudioSystem.instance.addMediaEventListener(_mediaEventListener);
    play(audioProfiles[defaultIndex]);
  }

  dispose() {
    AudioSystem.instance.removeMediaEventListener(_mediaEventListener);
    _backgroundAudio.dispose();
  }

   Future<bool> isPlaying() async{
    return backgroundAudioPlaying == null ? false : true;
   }
  void _mediaEventListener(MediaEvent mediaEvent) {
    _logger.info('App received media event of type: ${mediaEvent.type}');
    final MediaActionType type = mediaEvent.type;
    if (type == MediaActionType.play) {
      resumeBackgroundAudio();
    } else if (type == MediaActionType.pause) {
      pauseBackgroundAudio();
    } else if (type == MediaActionType.playPause) {
      backgroundAudioPlaying
          ? pauseBackgroundAudio()
          : resumeBackgroundAudio();
    } else if (type == MediaActionType.stop) {
      stopBackgroundAudio();
    } else if (type == MediaActionType.seekTo) {
      _backgroundAudio.seek(mediaEvent.seekToPositionSeconds);
      AudioSystem.instance
          .setPlaybackState(true, mediaEvent.seekToPositionSeconds);
    }
    else if (type == MediaActionType.skipForward) {
        next();
    }
    else if (type == MediaActionType.skipBackward) {
        previous();
    }
    else if (type == MediaActionType.custom) {
      if (mediaEvent.customEventId == replayButtonId) {
        _backgroundAudio.play();
        AudioSystem.instance.setPlaybackState(true, 0.0);
      } else if (mediaEvent.customEventId == newReleasesButtonId) {
        _logger
            .info('New-releases button is not implemented in this exampe app.');
      }
    }
  }

  void play(AudioProfile audioProfile) {
    currentSong = audioProfile;
    backgroundAudioPlaying = true;

    _backgroundAudio = Audio.loadFromRemoteUrl( audioProfile.url,
        onDuration: (double durationSeconds) =>
        backgroundAudioDurationSeconds = durationSeconds,
        onPosition: (double positionSeconds) {
          backgroundAudioPositionSeconds = positionSeconds;

          seekSliderValue = backgroundAudioPositionSeconds / backgroundAudioDurationSeconds;
        },
        onComplete: (){
          next();
        },
        looping: false,
        playInBackground: true);

    _backgroundAudio.resume();
  }
  void next(){
    if (_currentIndex+1 < audioProfiles.length) {
      stopBackgroundAudio();
      _currentIndex += 1;
      currentSong = audioProfiles[_currentIndex];
      play(currentSong);
    }
  }
  void previous(){
    if (_currentIndex > 0) {
      stopBackgroundAudio();
      _currentIndex -= 1;
      currentSong = audioProfiles[_currentIndex];
      play(currentSong);
    }
  }

  double currentposition(){
    return backgroundAudioPositionSeconds;
  }

  double duration(){
    return backgroundAudioDurationSeconds;
  }
  void seek(double positionSeconds){
    _backgroundAudio.seek(positionSeconds);
  }

  void stopBackgroundAudio() {
    _backgroundAudio.pause();
    backgroundAudioPlaying = false;
    AudioSystem.instance.stopBackgroundDisplay();
  }


  void pauseBackgroundAudio() {
    _backgroundAudio.pause();
    backgroundAudioPlaying = false;

    AudioSystem.instance
        .setPlaybackState(false, backgroundAudioPositionSeconds);

    AudioSystem.instance.setAndroidNotificationButtons(<dynamic>[
      AndroidMediaButtonType.play,
      AndroidMediaButtonType.stop,
      const AndroidCustomMediaButton(
          'new releases', newReleasesButtonId, 'ic_new_releases_black_36dp'),
    ], androidCompactIndices: <int>[
      0
    ]);

    AudioSystem.instance.setSupportedMediaActions(<MediaActionType>{
      MediaActionType.playPause,
      MediaActionType.play,
      MediaActionType.next,
      MediaActionType.previous,
    });
  }

  Future<void> resumeBackgroundAudio() async {
    _backgroundAudio.resume();
    backgroundAudioPlaying = true;

    //final Uint8List imageBytes = await generateImageBytes();

    http.Response response = await http.get(currentSong.album_art_url);
    final Uint8List imageBytes = response.bodyBytes;

    AudioSystem.instance.setMetadata(AudioMetadata(
        title: currentSong.title,
        artist: currentSong.author,
        album: currentSong.author,
        genre: "Audio book",
        durationSeconds: backgroundAudioDurationSeconds,
        artBytes: imageBytes));

    AudioSystem.instance
        .setPlaybackState(true, backgroundAudioPositionSeconds);

    AudioSystem.instance.setAndroidNotificationButtons(<dynamic>[
      AndroidMediaButtonType.pause,
      AndroidMediaButtonType.stop,
      const AndroidCustomMediaButton(
          'replay', replayButtonId, 'ic_replay_black_36dp')
    ], androidCompactIndices: <int>[
      0
    ]);
    AudioSystem.instance.setSupportedMediaActions(<MediaActionType>{
      MediaActionType.playPause,
      MediaActionType.pause,
      MediaActionType.next,
      MediaActionType.previous,
      MediaActionType.skipForward,
      MediaActionType.skipBackward,
      MediaActionType.seekTo,
    }, skipIntervalSeconds: 30);
  }

  /// Generates a 200x200 png, with randomized colors, to use as art for the
  /// notification/lockscreen.
  static Future<Uint8List> generateImageBytes() async {
    // Random color generation methods: pick contrasting hues.
    final Random random = Random();
    final double bgHue = random.nextDouble() * 360;
    final double fgHue = (bgHue + 180.0) % 360;
    final HSLColor bgHslColor =
    HSLColor.fromAHSL(1.0, bgHue, random.nextDouble() * .5 + .5, .5);
    final HSLColor fgHslColor =
    HSLColor.fromAHSL(1.0, fgHue, random.nextDouble() * .5 + .5, .5);

    final Size size = const Size(200.0, 200.0);
    final Offset center = const Offset(100.0, 100.0);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Rect rect = Offset.zero & size;
    final Canvas canvas = Canvas(recorder, rect);
    final Paint bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = bgHslColor.toColor();
    final Paint fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = fgHslColor.toColor()
      ..strokeWidth = 8;
    // Draw background color.
    canvas.drawRect(rect, bgPaint);
    // Draw 5 inset squares around the center.
    for (int i = 0; i < 5; i++) {
      canvas.drawRect(
          Rect.fromCenter(center: center, width: i * 40.0, height: i * 40.0),
          fgPaint);
    }
    // Render to image, then compress to PNG ByteData, then return as Uint8List.
    final ui.Image image = await recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final ByteData encodedImageData =
    await image.toByteData(format: ui.ImageByteFormat.png);
    return encodedImageData.buffer.asUint8List();
  }
}
