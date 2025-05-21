import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'agora_manager.dart';
import 'screens.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const String userAId = "user_A";
const String userBId = "user_B";
String currentUserId = ''; 

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'video_call_channel', 
  'Video Call Notifications',
  description: 'This channel is used for video call notifications.',
  importance: Importance.high,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('ringtone')
);


Future<void> _firebaseMessagingBackgroundHandler(NotificationResponse notificationResponse) async {

  print('Handling a background notification tap: ${notificationResponse.payload}');
  if (notificationResponse.payload != null && notificationResponse.payload!.isNotEmpty) {
    final payloadData = notificationResponse.payload!.split(',');
    if (payloadData.length == 3 && payloadData[0] == 'incoming_call') {
      final channelName = payloadData[1];
      final callerId = payloadData[2];
      
     
      await Future.delayed(const Duration(seconds: 1)); 

      final agoraManager = AgoraManager(); 
      if (currentUserId.isNotEmpty && agoraManager.callStateNotifier.value == CallState.ringing) {
       
         print("Call already in ringing state, UI should handle or user tapped existing ringing screen");
      } else if (currentUserId.isNotEmpty) {
       
        print("Notification tapped, attempting to accept call: $channelName from $callerId for $currentUserId");
        
        agoraManager.setCurrentUser(currentUserId, (currentUserId == userAId) ? userBId : userAId); 
        
        agoraManager.prepareToReceiveCall(channelName, callerId, currentUserId);
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => IncomingCallScreen(
              callerId: callerId,
              channelName: channelName,
              agoraManager: agoraManager,
              currentUserId: currentUserId,
            ),
          ),
        );
      } else {
         print("CurrentUserID not set or call state not suitable for notification tap handling.");
      }
    }
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _firebaseMessagingBackgroundHandler,
    onDidReceiveBackgroundNotificationResponse: _firebaseMessagingBackgroundHandler,
  );

   await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final NotificationPermission = await Permission.notification.status;
  if (NotificationPermission.isDenied) {
    await Permission.notification.request();
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AgoraManager agoraManager = AgoraManager();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Agora Video Call',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: UserSelectionScreen(agoraManager: agoraManager),
    );
  }
}

class UserSelectionScreen extends StatelessWidget {
  final AgoraManager agoraManager;
  const UserSelectionScreen({super.key, required this.agoraManager});

  void _selectUser(BuildContext context, String userId) {
    currentUserId = userId;
    String remoteId = (userId == userAId) ? userBId : userAId;
    agoraManager.setCurrentUser(userId, remoteId);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          currentUserId: userId,
          remoteUserId: remoteId,
          agoraManager: agoraManager,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select User')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: const Text('Login as User A'),
              onPressed: () => _selectUser(context, userAId),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Login as User B'),
              onPressed: () => _selectUser(context, userBId),
            ),
          ],
        ),
      ),
    );
  }
}