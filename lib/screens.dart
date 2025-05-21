import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'agora_manager.dart';
import 'main.dart'; 

class HomeScreen extends StatefulWidget {
  final String currentUserId;
  final String remoteUserId;
  final AgoraManager agoraManager;

  const HomeScreen({
    super.key,
    required this.currentUserId,
    required this.remoteUserId,
    required this.agoraManager,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late TextEditingController _calleeIdController;
  late TextEditingController _channelToJoinController; 
  late TextEditingController _callerForJoinController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _calleeIdController = TextEditingController(text: widget.remoteUserId);
    _channelToJoinController = TextEditingController();
    _callerForJoinController = TextEditingController();

    widget.agoraManager.callStateNotifier.addListener(_onCallStateChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.agoraManager.callStateNotifier.removeListener(_onCallStateChanged);
    _calleeIdController.dispose();
    _channelToJoinController.dispose();
    _callerForJoinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
    
      if (widget.agoraManager.callStateNotifier.value != CallState.ringing) {
        flutterLocalNotificationsPlugin.cancel(0);
      }
    }
  }


  void _onCallStateChanged() {
    final callState = widget.agoraManager.callStateNotifier.value;
    print("HomeScreen: Call state changed to $callState for user ${widget.currentUserId}");

    if (callState == CallState.ringing && widget.agoraManager.currentActualUserId == widget.currentUserId) {
       // Check if this user is the intended callee
       if (widget.agoraManager.callStateNotifier.value == CallState.ringing &&
           (ModalRoute.of(context)?.isCurrent ?? false)) { 

          // Ensure no dialog is already open
          bool isDialogAlreadyShown = false;
          Navigator.popUntil(context, (route) {
            if (route is PopupRoute) {
              isDialogAlreadyShown = true;
            }
            return true; 
          });
          
          if(isDialogAlreadyShown){
            print("Incoming call dialog might already be shown.");
           
          }
          
          
          if (widget.agoraManager.remoteUserIdInCall.isNotEmpty) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext dialogContext) {
                return IncomingCallDialog(
                  callerId: widget.agoraManager.remoteUserIdInCall, 
                  agoraManager: widget.agoraManager,
                  onAccepted: () {
                    Navigator.pop(dialogContext);
                    _navigateToCallScreen();
                  },
                  onRejected: () {
                    Navigator.pop(dialogContext);
                  },
                );
              },
            );
          } else {
             print("Ringing state but callerId not identified in AgoraManager. Check logic.");
          }
       }
    } else if (callState == CallState.connected) {
    
      _navigateToCallScreen();
    }
  }

  void _navigateToCallScreen() {
    if (ModalRoute.of(context)?.settings.name != '/videoCall') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            currentUserId: widget.currentUserId,
            remoteUserId: widget.agoraManager.remoteUserIdInCall, 
            channelName: widget.agoraManager.currentChannel!,
            agoraManager: widget.agoraManager,
          ),
          settings: const RouteSettings(name: '/videoCall'),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User: ${widget.currentUserId} - Home'),
        actions: [
            IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                    widget.agoraManager.endCall(showNotification: false);
                    currentUserId = '';
                    Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => UserSelectionScreen(agoraManager: widget.agoraManager)),
                        (Route<dynamic> route) => false,
                    );
                },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Logged in as: ${widget.currentUserId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Call User:', style: Theme.of(context).textTheme.titleMedium),
            TextField(
              controller: _calleeIdController,
              decoration: const InputDecoration(
                hintText: 'Enter User ID to call (e.g., user_B)',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call),
              label: const Text('Start Video Call'),
              onPressed: () {
                final calleeId = _calleeIdController.text.trim();
                if (calleeId.isNotEmpty && calleeId != widget.currentUserId) {
                  widget.agoraManager.initiateCall(calleeId).then((_) {
                 
                     _navigateToCallScreen(); 
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid Callee ID, different from yourself.')),
                  );
                }
              },
            ),
            const SizedBox(height: 30),
            const Divider(),
            Text('For Callee Simulation (Manual):', style: Theme.of(context).textTheme.titleMedium),
            Text('If another user called you with a channel name, enter it here to simulate receiving the call.', style: Theme.of(context).textTheme.bodySmall),
            TextField(
              controller: _channelToJoinController,
              decoration: const InputDecoration(
                labelText: 'Channel Name (from caller)',
              ),
            ),
            TextField(
              controller: _callerForJoinController,
              decoration: const InputDecoration(
                labelText: 'Caller ID (who called you)',
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.phonelink_ring),
              label: const Text('Simulate Receive Call / Join'),
              onPressed: () {
                final channel = _channelToJoinController.text.trim();
                final caller = _callerForJoinController.text.trim();
                if (channel.isNotEmpty && caller.isNotEmpty && caller != widget.currentUserId) {
                  widget.agoraManager.prepareToReceiveCall(channel, caller, widget.currentUserId);

                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter Channel Name and a valid Caller ID.')),
                  );
                }
              },
            ),

             const SizedBox(height: 30),
            ValueListenableBuilder<CallState>(
              valueListenable: widget.agoraManager.callStateNotifier,
              builder: (context, state, child) {
                return Text('Current Call State: ${state.toString().split('.').last}', style: const TextStyle(fontSize: 16));
              }
            ),
          ],
        ),
      ),
    );
  }
}


class IncomingCallDialog extends StatelessWidget {
  final String callerId;
  final AgoraManager agoraManager;
  final VoidCallback onAccepted;
  final VoidCallback onRejected;

  const IncomingCallDialog({
    super.key,
    required this.callerId,
    required this.agoraManager,
    required this.onAccepted,
    required this.onRejected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Incoming Call'),
      content: Text('Video call from $callerId'),
      actions: <Widget>[
        TextButton(
          child: const Text('Decline', style: TextStyle(color: Colors.red)),
          onPressed: () {
            agoraManager.rejectCall();
            onRejected();
          },
        ),
        TextButton(
          child: const Text('Accept', style: TextStyle(color: Colors.green)),
          onPressed: () {
            agoraManager.acceptCall();
            onAccepted();
          },
        ),
      ],
    );
  }
}

class IncomingCallScreen extends StatelessWidget {
  final String callerId;
  final String channelName; 
  final AgoraManager agoraManager;
  final String currentUserId; 

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.channelName,
    required this.agoraManager,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.teal[700],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Incoming Call from',
              style: TextStyle(fontSize: 24, color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 10),
            Text(
              callerId,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 100), // Spacer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                FloatingActionButton(
                  heroTag: 'declineCallBtnFull',
                  onPressed: () {
                    agoraManager.rejectCall();
                    Navigator.popUntil(context, (route) => route.settings.name != '/videoCall' && route.isFirst);
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: 'acceptCallBtnFull',
                  onPressed: () {
                    agoraManager.acceptCall().then((_) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoCallScreen(
                              currentUserId: currentUserId,
                              remoteUserId: callerId,
                              channelName: agoraManager.currentChannel!,
                              agoraManager: agoraManager,
                            ),
                             settings: const RouteSettings(name: '/videoCall'),
                          ),
                        );
                    });
                  },
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class VideoCallScreen extends StatefulWidget {
  final String currentUserId;
  final String remoteUserId;
  final String channelName;
  final AgoraManager agoraManager;

  const VideoCallScreen({
    super.key,
    required this.currentUserId,
    required this.remoteUserId,
    required this.channelName,
    required this.agoraManager,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  @override
  void initState() {
    super.initState();
    widget.agoraManager.callStateNotifier.addListener(_handleCallStateChangeForNav);
  }

  @override
  void dispose() {
    widget.agoraManager.callStateNotifier.removeListener(_handleCallStateChangeForNav);
    super.dispose();
  }

  void _handleCallStateChangeForNav() {
    final callState = widget.agoraManager.callStateNotifier.value;
    if (callState == CallState.ended || callState == CallState.idle) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.popUntil(context, (route) => route.settings.name != '/videoCall' && route.isFirst);
      }
    }
  }

  Widget _localVideoView() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.agoraManager.localVideoDisabledNotifier,
      builder: (context, isVideoDisabled, child) {
        if (isVideoDisabled || widget.agoraManager.engine == null) {
          return Container(
            color: Colors.grey[800],
            child: const Center(child: Icon(Icons.videocam_off, color: Colors.white, size: 48)),
          );
        }
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: widget.agoraManager.engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        );
      },
    );
  }

  Widget _remoteVideoView() {
    return ValueListenableBuilder<int?>(
      valueListenable: widget.agoraManager.remoteUserUidNotifier,
      builder: (context, remoteUid, child) {
        if (remoteUid != null && widget.agoraManager.engine != null) {
          return AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: widget.agoraManager.engine!,
              canvas: VideoCanvas(uid: remoteUid),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          );
        } else {
          return Container(
            color: Colors.grey[700],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Waiting for remote user...", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: _remoteVideoView()),
            Positioned(
              top: 20,
              right: 20,
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: _localVideoView(),
              ),
            ),
            // Call controls
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.agoraManager.localAudioMutedNotifier,
                    builder: (context, isMuted, child) {
                      return FloatingActionButton(
                        heroTag: 'muteBtn',
                        onPressed: () => widget.agoraManager.toggleAudioMute(),
                        backgroundColor: isMuted ? Colors.white : Colors.blueAccent,
                        child: Icon(isMuted ? Icons.mic_off : Icons.mic, color: isMuted ? Colors.black : Colors.white),
                      );
                    }
                  ),
                  FloatingActionButton(
                    heroTag: 'endCallBtn',
                    onPressed: () {
                      widget.agoraManager.endCall();
                    },
                    backgroundColor: Colors.redAccent,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  ValueListenableBuilder<bool>(
                     valueListenable: widget.agoraManager.localVideoDisabledNotifier,
                     builder: (context, isDisabled, child) {
                       return FloatingActionButton(
                         heroTag: 'toggleVideoBtn',
                         onPressed: () => widget.agoraManager.toggleLocalVideo(),
                         backgroundColor: isDisabled ? Colors.white : Colors.blueAccent,
                         child: Icon(isDisabled ? Icons.videocam_off : Icons.videocam, color: isDisabled ? Colors.black : Colors.white),
                       );
                     }
                  ),
                  FloatingActionButton(
                    heroTag: 'switchCameraBtn',
                    onPressed: () => widget.agoraManager.switchCamera(),
                    backgroundColor: Colors.blueAccent,
                    child: const Icon(Icons.switch_camera, color: Colors.white),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: ValueListenableBuilder<CallState>(
                valueListenable: widget.agoraManager.callStateNotifier,
                builder: (context, state, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'State: ${state.toString().split('.').last}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}