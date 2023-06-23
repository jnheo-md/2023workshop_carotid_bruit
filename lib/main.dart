import 'dart:convert';
import 'dart:io';

import 'package:carotid_bruit/recordingItem.dart';
import 'package:carotid_bruit/recordings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_sound_platform_interface/flutter_sound_recorder_platform_interface.dart';
import 'package:flutter_svg/svg.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:wav/wav.dart'; // get application dir
import 'package:intl/intl.dart'; //for date formatting

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FlutterSoundRecorder _mRecorder = FlutterSoundRecorder();

  //currently displayed recording list
  List<Recording> recordings = [];
  //boolean indicating loading status
  bool loading = true;
  //currently recording file path
  String currentRecordingFilePath = "";

  //start recording audio
  void recordAudio() async {}

  void stopRecording() async {}

  //toggle recording status
  void toggleRecord() async {
    if (_mRecorder.isRecording) {
      //then stop recording
      stopRecording();
    } else {
      //start recording
      recordAudio();
    }
  }

  //delete recording
  void removeRecording(Recording recording) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: loading
          ? const Center(child: Text("loading..."))
          : Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const SizedBox(height: 60),
                        SvgPicture.asset("lib/assets/logo.svg"),
                        const SizedBox(height: 27),
                        Expanded(
                          child: ListView.builder(
                              itemCount: recordings.length,
                              itemBuilder: (BuildContext context, int index) {
                                return Dismissible(
                                  key: UniqueKey(),
                                  background: Container(color: Colors.green),
                                  onDismissed: (DismissDirection direction) {
                                    setState(() {
                                      final removed =
                                          recordings.removeAt(index);
                                      removeRecording(removed);
                                    });
                                  },
                                  child: RecordingItem(
                                      recording: recordings[index]),
                                );
                              }),
                        )
                      ],
                    ),
                  ),
                ),
                AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    bottom: _mRecorder.isRecording ? 0 : 50,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                          curve: Curves.easeOutQuad,
                          width: _mRecorder.isRecording
                              ? MediaQuery.of(context).size.width
                              : 90,
                          height: _mRecorder.isRecording
                              ? MediaQuery.of(context).size.height
                              : 90,
                          duration: const Duration(milliseconds: 400),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(
                                _mRecorder.isRecording ? 0 : 90),
                          ),
                          child: Center(
                            child: IconButton(
                              highlightColor: Colors.white.withOpacity(0.3),
                              hoverColor: Colors.white.withOpacity(0.2),
                              icon: Icon(
                                _mRecorder.isRecording
                                    ? Icons.stop_circle
                                    : Icons.mic,
                                size: 50,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                toggleRecord();
                              },
                            ),
                          )),
                    ))
              ],
            ),
    );
  }
}
