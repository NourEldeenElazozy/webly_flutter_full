import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mightyweb/utils/bloc.dart';
import 'package:provider/provider.dart';
import '../AppTheme.dart';
import '../app_localizations.dart';
import '../model/LanguageModel.dart';
import '../screen/DataScreen.dart';
import '../utils/common.dart';
import '../utils/constant.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'component/NoInternetConnection.dart';
import 'model/MainResponse.dart';
import 'network/NetworkUtils.dart';
import 'store/AppStore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
AppStore appStore = AppStore();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = HttpOverridesSkipCertificate();
  await initialize();
  Future<void> sendDeviceTokenToServer(String userId) async {
    // تفعيل OneSignal
    OneSignal.initialize("a6cc9220-e4ee-4769-9163-4220de72190f");

    // طلب صلاحية الإشعارات
    await OneSignal.Notifications.requestPermission(true);

    // جلب Device Token
    String? deviceToken = OneSignal.User.pushSubscription?.id;

    if (deviceToken == null) {
      print("Device Token is null - user might not be subscribed yet");
      return;
    }

    print("Device Token: $deviceToken");

    // إرسال Token للسيرفر
    try {
      final response = await http.post(
        Uri.parse("https://edubridge.ly/save_device_token.php"),
        body: {
          "user_id": userId,
          "device_token": deviceToken,
        },
      );

      if (response.statusCode == 200) {
        print("Token saved successfully");
      } else {
        print("Failed to save token. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error saving token: $e");
    }
  }


  // List<ConnectivityResult> connectivityResult = await Connectivity().checkConnectivity  ();
  List<ConnectivityResult> connectivityResults = await Connectivity().checkConnectivity();
  ConnectivityResult connectivityResult = connectivityResults.first;
  appStore.setConnectionState(connectivityResult);

  appStore.setDarkMode(aIsDarkMode: getBoolAsync(isDarkModeOnPref));
  appStore.setLanguage(getStringAsync(APP_LANGUAGE, defaultValue: 'en'));

  if (isMobile) {
    MobileAds.instance.initialize();
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.Debug.setAlertLevel(OSLogLevel.none);
    OneSignal.consentRequired(false);
    OneSignal.initialize(getStringAsync(ONESINGLE, defaultValue: mOneSignalID));
    OneSignal.Notifications.requestPermission(true);
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('NOTIFICATION WILL DISPLAY LISTENER CALLED WITH: ${event.notification.jsonRepresentation()}');
      event.preventDefault();
      event.notification.display();
    });
  }
  MainResponse? config;
  try {
    config = await fetchData();
  } catch (e) {
    config = null;
  }
  runApp(MyApp(config: config));
}

class MyApp extends StatefulWidget {
  MyApp({required this.config});
  final MainResponse? config;
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver{
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setStatusBarColor(appStore.primaryColors, statusBarBrightness: Brightness.light);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((e) {
      if (e == ConnectivityResult.none) {
        log('not connected');
        push(NoInternetConnection());
      } else {
        pop();
        log('connected');
      }
    });
  }
  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print("App is in background, media will continue playing");
    } else if (state == AppLifecycleState.resumed) {
      print("App is back in foreground");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: appStore.isNetworkAvailable ? DataScreen(config: widget.config) : NoInternetConnection(),
        supportedLocales: Language.languagesLocale(),
        navigatorKey: navigatorKey,
        localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        localeResolutionCallback: (locale, supportedLocales) => locale,
        locale: Locale(getStringAsync(APP_LANGUAGE, defaultValue: 'en')),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: appStore.isDarkModeOn! ? ThemeMode.dark : ThemeMode.light,
        scrollBehavior: SBehavior(),
        builder: (context, child) {
          final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
            child: SafeArea(
              top: false,
              bottom: bottomPadding > 0,
              child: child!,
            ),
          );
        },
      );
    });
  }
}
