// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:flutter_uploader_example/responses_screen.dart';
import 'package:flutter_uploader_example/upload_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uri uploadURL = Uri.parse(
  'https://us-central1-flutteruploadertest.cloudfunctions.net/upload',
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final FlutterUploader uploader = FlutterUploader();

String? selectedNotificationPayload;

void backgroundHandler() {
  WidgetsFlutterBinding.ensureInitialized();

  // Notice these instances belong to a forked isolate.
  var notifications = FlutterLocalNotificationsPlugin();
  var uploader = FlutterUploader();

  // Only show notifications for unprocessed uploads.
  SharedPreferences.getInstance().then((preferences) {
    var processed = preferences.getStringList('processed') ?? <String>[];

    if (Platform.isAndroid) {
      uploader.progress.listen((progress) {
        print(
            'IN BACKGROUND UPLOADER: ID: ${progress.taskId}, progress: ${progress.progress}');

        if (processed.contains(progress.taskId)) {
          return;
        }

        notifications.show(
          progress.taskId.hashCode,
          'FlutterUploader Example',
          'Upload in Progress',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'FlutterUploader.Example',
              'FlutterUploader',
              'Installed when you activate the Flutter Uploader Example',
              progress: progress.progress ?? 0,
              icon: 'ic_upload',
              enableVibration: false,
              importance: Importance.low,
              showProgress: true,
              onlyAlertOnce: true,
              maxProgress: 100,
              channelShowBadge: false,
            ),
            iOS: IOSNotificationDetails(),
          ),
        );
      });
    }

    uploader.result.listen((result) {
      print(
          'IN BACKGROUND UPLOADER: ${result.taskId}, status: ${result.status}, statusCode: ${result.statusCode}, headers: ${result.headers}');

      if (processed.contains(result.taskId)) {
        return;
      }

      processed.add(result.taskId);
      preferences.setStringList('processed', processed);

      notifications.cancel(result.taskId.hashCode);

      final successful = result.status == UploadTaskStatus.complete;

      var title = 'Upload Complete';
      if (result.status == UploadTaskStatus.failed) {
        title = 'Upload Failed';
      } else if (result.status == UploadTaskStatus.canceled) {
        title = 'Upload Canceled';
      }

      notifications
          .show(
        result.taskId.hashCode,
        'FlutterUploader Example',
        title,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'FlutterUploader.Example',
            'FlutterUploader',
            'Installed when you activate the Flutter Uploader Example',
            icon: 'ic_upload',
            enableVibration: !successful,
            importance: result.status == UploadTaskStatus.failed
                ? Importance.high
                : Importance.min,
          ),
          iOS: IOSNotificationDetails(
            presentAlert: true,
          ),
        ),
      )
          .catchError((e, stack) {
        print('error while showing notification: $e, $stack');
      });
    });
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await uploader.setBackgroundHandler(backgroundHandler);

  final notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    selectedNotificationPayload = notificationAppLaunchDetails!.payload;
  }

  const initializationSettingsAndroid =
      AndroidInitializationSettings('ic_upload');

  final initializationSettingsIOS = IOSInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {},
  );

  final initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onSelectNotification: (String? payload) async {
      if (payload != null) {
        debugPrint('notification payload: $payload');
      }
      selectedNotificationPayload = payload;
    },
  );

  runApp(App());
}

class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;

  bool allowCellular = true;

  @override
  void initState() {
    super.initState();

    SharedPreferences.getInstance()
        .then((sp) => sp.getBool('allowCellular') ?? true)
        .then(
      (result) {
        if (mounted) {
          setState(() => allowCellular = result);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlutterUploader Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(
                allowCellular
                    ? Icons.signal_cellular_connected_no_internet_4_bar
                    : Icons.wifi_outlined,
              ),
              onPressed: () async {
                final sp = await SharedPreferences.getInstance();
                await sp.setBool('allowCellular', !allowCellular);

                if (mounted) {
                  setState(() => allowCellular = !allowCellular);
                }
              },
            ),
          ],
        ),
        body: _currentIndex == 0
            ? UploadScreen(
                uploader: uploader,
                uploadURL: uploadURL,
                onUploadStarted: () {
                  setState(() => _currentIndex = 1);
                },
              )
            : ResponsesScreen(
                uploader: uploader,
              ),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.cloud_upload),
              label: 'Upload',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt),
              label: 'Responses',
            ),
          ],
          onTap: (newIndex) {
            setState(() => _currentIndex = newIndex);
          },
          currentIndex: _currentIndex,
        ),
      ),
    );
  }
}
