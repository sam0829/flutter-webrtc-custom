import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'utils.dart';

class MediaStreamTrack {
  MethodChannel _channel = WebRTC.methodChannel();
  final channel = EventChannel('audio_data');
  String _trackId;
  String _label;
  String _kind;
  bool _enabled;

  MediaStreamTrack(this._trackId, this._label, this._kind, this._enabled);

  set enabled(bool enabled) {
    _channel.invokeMethod('mediaStreamTrackSetEnable',
        <String, dynamic>{'trackId': _trackId, 'enabled': enabled});
    _enabled = enabled;
  }

  bool get enabled => _enabled;
  String get label => _label;
  String get kind => _kind;
  String get id => _trackId;

  Future<bool> hasTorch() => _channel.invokeMethod(
        'mediaStreamTrackHasTorch',
        <String, dynamic>{'trackId': _trackId},
      );

  Future<void> setTorch(bool torch) => _channel.invokeMethod(
        'mediaStreamTrackSetTorch',
        <String, dynamic>{'trackId': _trackId, 'torch': torch},
      );

  ///Future contains isFrontCamera
  ///Throws error if switching camera failed
  Future<bool> switchCamera() => _channel.invokeMethod(
        'mediaStreamTrackSwitchCamera',
        <String, dynamic>{'trackId': _trackId},
      );

  void setVolume(double volume) async {
    await _channel.invokeMethod(
      'setVolume',
      <String, dynamic>{'trackId': _trackId, 'volume': volume},
    );
  }

  void setMicrophoneMute(bool mute) async {
    print('MediaStreamTrack:setMicrophoneMute $mute');
    await _channel.invokeMethod(
      'setMicrophoneMute',
      <String, dynamic>{'trackId': _trackId, 'mute': mute},
    );
  }

  void enableSpeakerphone(bool enable) async {
    print('MediaStreamTrack:enableSpeakerphone $enable');
    await _channel.invokeMethod(
      'enableSpeakerphone',
      <String, dynamic>{'trackId': _trackId, 'enable': enable},
    );
  }

  /// On Flutter Web returns Future<dynamic> which contains data url on success
  captureFrame([String filePath]) => _channel.invokeMethod(
        'captureFrame',
        <String, dynamic>{'trackId': _trackId, 'path': filePath},
      );

  StreamController<AudioData> controller;

  Stream<AudioData> captureAudio() {
    controller?.close();
    controller = StreamController<AudioData>.broadcast();
    _channel.invokeMethod(
      'captureAudio',
      <String, dynamic>{'trackId': _trackId},
    );

    channel.receiveBroadcastStream().listen((dynamic event) {
      //print('###################################### RECEIVED $event');
      if (event is Map) {
        controller.add(
            AudioData(bytes: event['bytes'], sampleRate: event['sample_rate']));
      }
    }, onError: (dynamic error) {
      print('###################################### RECEIVED ERROR $error');
      controller.addError(error);
      print('Received error: ${error.message}');
    });

    return controller.stream;
  }

  Future<void> captureAudioIOs() {
    return _channel.invokeMethod(
      'captureAudioIOs',
      <String, dynamic>{'audioTrackId': _trackId},
    );
  }

  Future<void> dispose() async {
    await _channel.invokeMethod(
      'trackDispose',
      <String, dynamic>{'trackId': _trackId},
    );
  }
}

class AudioData {
  Uint8List bytes;
  int sampleRate;

  AudioData({
    this.bytes,
    this.sampleRate,
  });

  String toString() {
    return 'bytes: ${bytes.length}, sample rate: $sampleRate';
  }
}