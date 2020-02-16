import 'package:audio_player/audio_manager.dart';
import 'package:audio_player/audio_player_widget.dart';
import 'package:audio_player/audio_profiles.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  AudioPlayerWidget audioPlayerWidget;
  @override
  Widget build(BuildContext context) {
    
    var height = MediaQuery.of(context).size.height;
    
    List<AudioProfile> playList = new List<AudioProfile>();

    playList.add(new AudioProfile(1,'https://file-examples.com/wp-content/uploads/2017/11/file_example_MP3_5MG.mp3',
        'Music 1', 'Sub Title 1', 'https://image.shutterstock.com/image-illustration/3d-illustration-musical-notes-signs-600w-761313844.jpg'));

    playList.add(new AudioProfile(2, 'https://dl.prokerala.com/downloads/ringtones/files/mp3/thaarame-thaarame-masstamilan-in-48992.mp3',
        'Music 2', 'Sub Title 2', 'https://image.shutterstock.com/image-illustration/3d-illustration-musical-notes-signs-600w-761313844.jpg'));

    playList.add(new AudioProfile(3,'https://dl.prokerala.com/downloads/ringtones/files/mp3/enjeevantherifluteinstrumentalbyflutesivaringtone-26636-48727.mp3',
        'Music 3', 'Sub Title 3', 'https://image.shutterstock.com/image-illustration/3d-illustration-musical-notes-signs-600w-761313844.jpg'));

    return
     Scaffold(
       body: AudioPlayerWidget(playlist: playList,)
     );
  }
}