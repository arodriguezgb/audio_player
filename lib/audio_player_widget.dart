import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';
import 'package:audio_player/audio_profiles.dart';
import 'package:audiofileplayer/audiofileplayer.dart';
import 'package:audiofileplayer/audio_system.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

final Logger _logger = Logger('audiofileplayer_example');

GlobalKey<_AudioPlayerWidgetState> audioPlayerKey = GlobalKey();

class AudioPlayerWidget extends StatefulWidget{
  AudioPlayerWidget({Key key, this.playlist, this.startIndex = 0}) : super(key: key);

  final List<AudioProfile> playlist;
  final int startIndex;

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}


class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {

  List<AudioProfile> get playList => widget.playlist;
  int get startIndex => widget.startIndex;

  /// Identifiers for the two custom Android notification buttons.
  static const String replayButtonId = 'replayButtonId';
  static const String newReleasesButtonId = 'newReleasesButtonId';

  /// Preloaded audio data for the first card.

  double _audioVolume = 1.0;
  double _seekSliderValue = 0.0; // Normalized 0.0 - 1.0.



  Audio _backgroundAudio;
  bool _backgroundAudioPlaying;
  double _backgroundAudioDurationSeconds;
  double _backgroundAudioPositionSeconds = 0;
  bool _backgroundAudioLoading = false;
  String _backgroundAudioError;

  AudioProfile currentSong;
  int _currentIndex = 0;
  String title='';

  @override
  void initState() {

    AudioSystem.instance.addMediaEventListener(_mediaEventListener);
    play(playList[startIndex]);
  }
  @override
  void dispose() {
    AudioSystem.instance.removeMediaEventListener(_mediaEventListener);
    if(_backgroundAudio != null)
      _backgroundAudio.dispose();

    super.dispose();
  }

  static String _stringForSeconds(double seconds) {
    if (seconds == null) return null;
    return '${(seconds ~/ 60)}:${(seconds.truncate() % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;

    return ListView(
      children: <Widget>[
        Container(
          height: height/ 1.8,
          child: getChaptersWidgets(playList, context),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(title)
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        previous();
                      },
                      iconSize: 45.0,
                      icon: Icon(Icons.skip_previous),
                    ),
                    IconButton(
                      onPressed: () async{
                        if(!_backgroundAudioPlaying) {
                          if(_backgroundAudio == null)
                            play(currentSong);

                          _backgroundAudio.resume();
                          setState(() {
                            _backgroundAudioPlaying = true;
                          });
                        }
                        else {
                          _backgroundAudio.pause();
                          setState(() {
                            _backgroundAudioPlaying = false;
                          });
                        }
                      },
                      iconSize: 45.0,
                      icon: _backgroundAudioPlaying ? Icon(Icons.pause) : Icon(Icons.play_arrow),
                    ),
                    IconButton(
                      onPressed: () async{
                        next();
                      },
                      iconSize: 45.0,
                      icon: Icon(Icons.skip_next),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 400,
                height: 25,
                child: SliderTheme(
                  data: SliderThemeData(
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 3,
                    thumbColor: Colors.pink,
                    inactiveTrackColor: Colors.grey,
                    activeTrackColor: Colors.pink,
                    overlayColor: Colors.transparent,
                  ),
                  child: Slider(
                    value:
                    _seekSliderValue,
                    onChanged: (double val) async {
                      setState(() => _seekSliderValue = val);
                      final double positionSeconds = val * _backgroundAudioDurationSeconds;
                      _backgroundAudio.seek(positionSeconds);
                    },
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${_stringForSeconds(_backgroundAudioPositionSeconds) ?? ''} / ${_stringForSeconds(_backgroundAudioDurationSeconds)  ?? ''}',
                    style: TextStyle(fontSize: 24.0),
                  ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }
  void _mediaEventListener(MediaEvent mediaEvent) {
    _logger.info('App received media event of type: ${mediaEvent.type}');
    final MediaActionType type = mediaEvent.type;
    if (type == MediaActionType.play) {
      resumeBackgroundAudio();
    } else if (type == MediaActionType.pause) {
      pauseBackgroundAudio();
    } else if (type == MediaActionType.playPause) {
      _backgroundAudioPlaying
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
    _backgroundAudioError = null;
    _backgroundAudioLoading = true;
//    if(_backgroundAudio != null)
//      _backgroundAudio.dispose();
    AudioSystem.instance.stopBackgroundDisplay();

    _backgroundAudio = Audio.loadFromRemoteUrl( audioProfile.url,
        onDuration: (double durationSeconds) {
          setState(() {
            _backgroundAudioDurationSeconds = durationSeconds;
            _backgroundAudioLoading = false;
          });
        },
        onPosition: (double positionSeconds) {
          setState(() {
            _backgroundAudioPositionSeconds = positionSeconds;
            _seekSliderValue = _backgroundAudioPositionSeconds / _backgroundAudioDurationSeconds;
          });
        },
        onComplete: (){
          next();
        },
        onError: (String message) => setState(() {
          _backgroundAudioError = message;
          _backgroundAudio.dispose();
          _backgroundAudio = null;
          _backgroundAudioPlaying = false;
          _backgroundAudioLoading = false;

          print(message);

        }),
        looping: false,
        playInBackground: true);

    setState(() {
      title = audioProfile.title;
      currentSong = audioProfile;
    });

    resumeBackgroundAudio();
  }
  void next(){
    if (_currentIndex+1 < playList.length) {
      stopBackgroundAudio();
      play(playList[_currentIndex+1 ]);

      setState(() {
        _currentIndex += 1;
      });

    }
  }
  void previous(){
    if (_currentIndex > 0) {
      stopBackgroundAudio();

      play(playList[_currentIndex - 1]);

      setState(() {
        _currentIndex -= 1;
      });
    }
  }

  double currentposition(){
    return _backgroundAudioPositionSeconds;
  }

  double duration(){
    return _backgroundAudioDurationSeconds;
  }
  void seek(double positionSeconds){
    _backgroundAudio.seek(positionSeconds);
  }

  void playTrack(int index){
    if (index < playList.length && index >= 0) {

      stopBackgroundAudio();
      play(playList[index]);

      setState(() {
        _currentIndex = index;
      });

    }
  }
  void stopBackgroundAudio() {
    _backgroundAudio.pause();
    setState(() => _backgroundAudioPlaying = false);
    AudioSystem.instance.stopBackgroundDisplay();
  }


  void pauseBackgroundAudio() {
    _backgroundAudio.pause();

    setState(() => _backgroundAudioPlaying = false);

    AudioSystem.instance
        .setPlaybackState(false, _backgroundAudioPositionSeconds);

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
    setState(() => _backgroundAudioPlaying = true);

    //final Uint8List imageBytes = await generateImageBytes();

    http.Response response = await http.get(currentSong.album_art_url);
    final Uint8List imageBytes = response.bodyBytes;

    AudioSystem.instance.setMetadata(AudioMetadata(
        title: currentSong.title,
        artist: currentSong.author,
        album: currentSong.author,
        genre: "Audio book",
        durationSeconds: _backgroundAudioDurationSeconds,
        artBytes: imageBytes));

    AudioSystem.instance
        .setPlaybackState(true, _backgroundAudioPositionSeconds);

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

  Widget getChaptersWidgets(List<AudioProfile> chapters, context) {
    return Scrollbar(
        child : new ListView.builder(
            itemCount: chapters.length,
            itemBuilder: (BuildContext context, int index) {
              AudioProfile item = chapters[index];
              return makeCard(item, context, index);
            }
        )
    );
  }

  Card makeCard(AudioProfile model, BuildContext context, int index) => Card(
    elevation: 8.0,
    margin: new EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
    child: Container(
      decoration: BoxDecoration(color: Color.fromRGBO(64, 75, 96, .9)),
      child: _buildListItem(model: model, context: context, index:index),
    ),
  );

  Widget _buildListItem({AudioProfile model, BuildContext context, int index}) {
    return ListTile(
      contentPadding:   EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      title: GestureDetector(
        onTap: (){
          playTrack(index);
        },
        child: Text(model.title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
      ),
      leading: Text(model.index.toString()),
      subtitle: Text(model.author),
      trailing: index == _currentIndex ? new Image(image: new AssetImage("assets/nowplaying.gif"),) : null,
    );
  }
}