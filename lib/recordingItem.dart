import 'package:carotid_bruit/recordings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_svg/svg.dart';

class RecordingItem extends StatefulWidget {
  RecordingItem({super.key, required this.recording});

  final Recording recording;

  @override
  State<RecordingItem> createState() => _RecordingItemState();
}

class _RecordingItemState extends State<RecordingItem> {
  final FlutterSoundPlayer _myPlayer = FlutterSoundPlayer();

  @override
  void dispose() {
    _myPlayer.closePlayer();
    super.dispose();
  }

  void startPlayer() async {
    if (!_myPlayer.isPlaying) {
      await _myPlayer.openPlayer();
      await _myPlayer
          .startPlayer(
              fromURI: widget.recording.filePath,
              sampleRate: 16000,
              codec: Codec.pcm16WAV,
              whenFinished: () {
                setState(() {});
              })
          .then((value) {
        setState(() {});
      });
    } else {
      _myPlayer.stopPlayer().then((value) {
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    //boolean indicating if normal percentage is higher
    bool isNormal =
        widget.recording.normalPercentage > widget.recording.bruitPercentage
            ? true
            : false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 41,
              decoration: BoxDecoration(
                color: isNormal
                    ? const Color(0xFF0AA1FF)
                    : const Color(0xFFFF0A39),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNormal
                        ? "Normal ${widget.recording.normalPercentage}% Bruit ${widget.recording.bruitPercentage}%"
                        : "Bruit ${widget.recording.bruitPercentage}% Normal ${widget.recording.normalPercentage}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.recording.date,
                    style: const TextStyle(letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
            IconButton(
                onPressed: () {
                  startPlayer();
                },
                icon: _myPlayer.isPlaying
                    ? SvgPicture.asset('lib/assets/stop.svg')
                    : SvgPicture.asset('lib/assets/play.svg')),
          ],
        ),
      ),
    );
  }
}
