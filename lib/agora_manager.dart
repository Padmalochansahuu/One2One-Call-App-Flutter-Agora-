import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;


import 'main.dart' show flutterLocalNotificationsPlugin; 

const String agoraAppId = "de8082743b1f482590c02789be1cebd0";

enum CallState {
  idle,
  calling,
  ringing,
  connected,
  ended,
}

class AgoraManager {
  RtcEngine? _engine;
  String? _currentChannelName;
  String? _callerId;
  String? _calleeId;
  String _currentUserId = '';
  String _remoteUserIdForCall = '';

  final ValueNotifier<CallState> callStateNotifier = ValueNotifier(CallState.idle);
  final ValueNotifier<int?> remoteUserUidNotifier = ValueNotifier(null);
  final ValueNotifier<bool> localAudioMutedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> localVideoDisabledNotifier = ValueNotifier(false);

  static final AgoraManager _instance = AgoraManager._internal();
  factory AgoraManager() {
    return _instance;
  }
  AgoraManager._internal();

  Future<void> _initializeAgora() async {
    if (agoraAppId.isEmpty || agoraAppId == "YOUR_AGORA_APP_ID") {
      print("Agora App ID is not set. Please replace YOUR_AGORA_APP_ID in agora_manager.dart");
      return;
    }
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: agoraAppId));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        print('Local user ${connection.localUid} joined channel ${connection.channelId}');
        if (callStateNotifier.value == CallState.calling || callStateNotifier.value == CallState.ringing) {
            callStateNotifier.value = CallState.connected;
        }
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        print('Remote user $remoteUid joined');
        remoteUserUidNotifier.value = remoteUid;
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        print('Remote user $remoteUid left channel');
        remoteUserUidNotifier.value = null;
        if (callStateNotifier.value == CallState.connected) {
            endCall();
        }
      },
      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        print('Local user left channel');
      },
      onError: (ErrorCodeType err, String msg) {
        print('Agora Error: $err, Message: $msg');
        if (callStateNotifier.value != CallState.idle && callStateNotifier.value != CallState.ended) {
            endCall(showNotification: false);
        }
      },
    ));

    await _engine!.enableVideo();
    await _engine!.enableAudio();
    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  void setCurrentUser(String currentId, String remoteId) {
    _currentUserId = currentId;
    _remoteUserIdForCall = remoteId;
    print("AgoraManager: Current user set to $_currentUserId, will interact with $_remoteUserIdForCall");
  }

  Future<void> initiateCall(String calleeId) async {
    if (_currentUserId.isEmpty) {
      print("Error: Current user ID not set in AgoraManager.");
      return;
    }
    await _requestPermissions();
    await _initializeAgora();

    _callerId = _currentUserId;
    _calleeId = calleeId;
    _remoteUserIdForCall = calleeId;

    _currentChannelName = 'call_${_callerId}_${_calleeId}_${const Uuid().v4().substring(0, 8)}';
    print('Initiating call from $_callerId to $_calleeId on channel: $_currentChannelName');

    callStateNotifier.value = CallState.calling;

    await _engine?.joinChannel(
      token: "",
      channelId: _currentChannelName!,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
     print("Call initiated. Caller joined. Callee '$_calleeId' should now be notified or join '$_currentChannelName'.");
  }

  Future<void> prepareToReceiveCall(String channelName, String callerId, String myUserId) async {
    if (_currentUserId != myUserId) {
      print("Warning: prepareToReceiveCall called for user $myUserId, but current manager user is $_currentUserId");
      setCurrentUser(myUserId, callerId);
    }

    if (callStateNotifier.value != CallState.idle && callStateNotifier.value != CallState.ended) {
        print("Already in a call or ringing. Ignoring new incoming call preparation.");
        return;
    }

    _currentChannelName = channelName;
    _callerId = callerId;
    _calleeId = myUserId;
    _remoteUserIdForCall = callerId;

    print('Receiving call from $_callerId to $_calleeId on channel: $_currentChannelName');
    callStateNotifier.value = CallState.ringing;
    _showIncomingCallNotification(channelName, callerId);
  }

  Future<void> _showIncomingCallNotification(String channelName, String callerId) async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
        print("Notification permission not granted. Cannot show incoming call notification.");
    }

    final fln.AndroidNotificationDetails androidPlatformChannelSpecifics =
        fln.AndroidNotificationDetails(
      'video_call_channel',
      'Video Call Notifications',
      channelDescription: 'Incoming video call',
      importance: fln.Importance.max, 
      priority: fln.Priority.high,   
      playSound: true,
      sound: fln.RawResourceAndroidNotificationSound('ringtone'), 
      fullScreenIntent: true,
    );
    const fln.DarwinNotificationDetails iOSPlatformChannelSpecifics = fln.DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ringtone.aiff',
      categoryIdentifier: 'CALL_CATEGORY',
    );
    final fln.NotificationDetails platformChannelSpecifics =
        fln.NotificationDetails(android: androidPlatformChannelSpecifics, iOS: iOSPlatformChannelSpecifics);

    final String payload = 'incoming_call,$channelName,$callerId';

    await flutterLocalNotificationsPlugin.show(
      0,
      'Incoming Call',
      'Call from $callerId',
      platformChannelSpecifics,
      payload: payload,
    );
     print("Showing incoming call notification for $callerId on channel $channelName with payload $payload");
  }

  Future<void> acceptCall() async {
    if (_currentChannelName == null || callStateNotifier.value != CallState.ringing) {
      print("Cannot accept call: No channel or not in ringing state.");
      return;
    }
    await _requestPermissions();
    await _initializeAgora();

    print('Accepting call on channel: $_currentChannelName');
    
    await _engine?.joinChannel(
      token: "", 
      channelId: _currentChannelName!,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
    flutterLocalNotificationsPlugin.cancel(0);
  }

  Future<void> rejectCall() async {
    print('Rejecting call on channel: $_currentChannelName');
    _resetCallState();
    flutterLocalNotificationsPlugin.cancel(0);
  }

  Future<void> endCall({bool showNotification = true}) async {
    print('Ending call on channel: $_currentChannelName');
    await _engine?.leaveChannel();
    _resetCallState();
    remoteUserUidNotifier.value = null;
    if (showNotification) { 
        flutterLocalNotificationsPlugin.cancel(0);
    } else {
        flutterLocalNotificationsPlugin.cancel(0); 
    }
  }

  void _resetCallState() {
    _currentChannelName = null;
    _callerId = null;
    _calleeId = null;
    callStateNotifier.value = CallState.ended;
    Future.delayed(const Duration(milliseconds: 500), () {
        if (callStateNotifier.value == CallState.ended) {
            callStateNotifier.value = CallState.idle;
        }
    });
  }

  Future<void> toggleAudioMute() async {
    bool currentlyMuted = localAudioMutedNotifier.value;
    await _engine?.muteLocalAudioStream(!currentlyMuted);
    localAudioMutedNotifier.value = !currentlyMuted;
  }

  Future<void> toggleLocalVideo() async {
    bool currentlyDisabled = localVideoDisabledNotifier.value;
    if (currentlyDisabled) {
      await _engine?.enableLocalVideo(true);
    } else {
      await _engine?.enableLocalVideo(false);
    }
    localVideoDisabledNotifier.value = !currentlyDisabled;
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  RtcEngine? get engine => _engine;
  String? get currentChannel => _currentChannelName;
  String get currentActualUserId => _currentUserId;
  String get remoteUserIdInCall => _remoteUserIdForCall;

  void dispose() {
    // Consider if these disposals are needed or if the singleton lives with the app.
    // callStateNotifier.dispose();
    // remoteUserUidNotifier.dispose();
    // localAudioMutedNotifier.dispose();
    // localVideoDisabledNotifier.dispose();
    // _engine?.release(); // for  singleton lifecycle
  }
}