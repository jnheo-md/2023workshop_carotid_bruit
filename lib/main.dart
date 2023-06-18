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

  @override
  void initState() {
    initialize(); //initialize recorder
    super.initState();
  }

  @override
  void dispose() {
    _mRecorder.closeRecorder(); //close recorder before dispose
    super.dispose();
  }

  void initialize() async {
    //open recorder before anything
    await _mRecorder.openRecorder();

    //get shared preferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    //all previous data is saved as 'data' as a list of JSON
    List<String>? saved = await prefs.getStringList('data');
    if (saved != null) {
      //if there is anything saved,
      for (String recording in saved) {
        try {
          //try decoding JSON
          Map recordingMap = jsonDecode(recording);

          //convert JSON into Recording object and save to array
          recordings.add(
            Recording(
              filePath: recordingMap['filePath'],
              date: recordingMap['date'],
              normalPercentage: int.parse(recordingMap['normalPercentage']),
              bruitPercentage: int.parse(recordingMap['bruitPercentage']),
            ),
          );
        } catch (e) {
          //if there is any error during json decoding
          //display empty array
          setState(() {
            recordings = [];
          });
        }
      }

      //now display changed recording list
      setState(() {
        recordings = recordings;
      });
    } else {
      //if nothing is saved, then display empty array
      setState(() {
        recordings = [];
      });
    }

    //no more loading needed
    setState(() {
      loading = false;
    });
  }

  //start recording audio
  void recordAudio() async {
    //get application documents directory to save data
    final appDir = await getApplicationDocumentsDirectory();

    //let's get permission to record audio from the user
    // TBD : need further code for cases when the user disagrees to record
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }

    //get current timestamp to be used as filename
    //timestamp : milliseconds since epoch (1970.1.1)
    String timestamp = "${DateTime.now().millisecondsSinceEpoch}";
    String filename = '${appDir.path}/$timestamp.wav';

    //now actually start recording
    _mRecorder
        .startRecorder(
      toFile: filename,
      codec: Codec.pcm16WAV, // 16 bit pcm encoded wav file
      audioSource: AudioSource.microphone, //from microphone
      sampleRate: 16000, //16khz sampling rate
    )
        .then((value) {
      setState(() {
        //can add code to display that it is currently recording
      });
    });
    currentRecordingFilePath = filename;
  }

  void stopRecording() async {
    //stop recording and save inference results
    await _mRecorder.stopRecorder();

    //get inference results
    //run inference method returns the following:
    // [ normal-seconds, bruit-seconds]
    List<int> results = await runInference(currentRecordingFilePath);

    //total count of non-background results (normal seconds + bruit seconds)
    int totalCount = results[0] + results[1];
    int normalPercentage = 0, bruitPercentage = 0;
    //prevent division by zero error
    if (totalCount != 0) {
      normalPercentage = ((results[0] / totalCount) * 100).round();
      bruitPercentage = ((results[1] / totalCount) * 100).round();
    }

    //displayed date is in string format
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy.MM.dd').format(now);

    //create recording from this filepath, date, and inference results
    Recording newRecording = Recording(
      filePath: currentRecordingFilePath,
      date: formattedDate,
      normalPercentage: normalPercentage,
      bruitPercentage: bruitPercentage,
    );

    //now add that recording to current list and update display
    setState(() {
      recordings.add(newRecording);
    });

    //save current recording list to shared preferences
    saveRecordings();
  }

  //method to run inference on audio and return a list of :
  // [ seconds-predicted-normal, seconds-predicted-bruit ]
  Future<List<int>> runInference(String path) async {
    //read wav file
    final wav = await Wav.readFile(path);
    //get interpreter
    final interpreter =
        await Interpreter.fromAsset('lib/assets/bruit_yamnet.tflite');

    //pre-define output format
    var output = List.filled(5, 0).reshape([5]);
    int normalCount = 0;
    int bruitCount = 0;

    //the wav.channels[0] variable contains a long 1-d list of values
    //for 16khz sampling rate, one second consists of 16000 values
    //so for each second, we will be running inference
    for (int j = 0; j < (wav.channels[0].length / 16000).floor(); j++) {
      //for each second (j is seconds passed from beginning)
      //create a new input of 16000 values (1 second)
      List<double> input = [];
      for (int i = j * 16000; i < (j + 1) * 16000; i++) {
        input.add(wav.channels[0][i]);
      }
      //then run inference on that one second
      interpreter.run(input, output);

      //output contains class probability of each class
      //get the index(class) with the maximum probability
      int maxIndex = output.indexOf(output.reduce((a, b) => a > b ? a : b));
      // class labels - 0: background, 1: bruit-noise, 2: normal, 3: normal-noise, 4: bruit

      if (maxIndex == 2) {
        //if this second's max probability was 'normal' class, then increase normal count
        normalCount++;
      } else if (maxIndex == 4) {
        //if this second's max probability was 'bruit' class, then increase bruit count
        bruitCount++;
      }
    }
    return [normalCount, bruitCount];
  }

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
  void removeRecording(Recording recording) {
    try {
      //remove file from documents dir
      final File file = File(recording.filePath);
      file.delete();
    } catch (e) {
      print('error removing file');
    }
    //now save current list
    saveRecordings();
  }

  //save current recording list
  void saveRecordings() async {
    //first get shared preferences...
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    //editing Recording object as serializable is the better way
    //we'll manually convert recording object to Map object
    //for the current tutorial
    List<String> saveRecordings = [];

    for (Recording record in recordings) {
      //convert each Recording object into Map
      Map<String, String> newMap = {
        'filePath': record.filePath,
        'date': record.date,
        'normalPercentage': '${record.normalPercentage}',
        'bruitPercentage': '${record.bruitPercentage}',
      };
      //then into json...
      saveRecordings.add(jsonEncode(newMap));
    }

    //now save into shared preferences
    await prefs.setStringList('data', saveRecordings);
  }

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
