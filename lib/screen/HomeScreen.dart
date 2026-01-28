import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../app_localizations.dart';
import '../component/AppBarComponent.dart';
import '../component/FloatingComponent.dart';
import '../component/SideMenuComponent.dart';
import '../main.dart';
import '../model/MainResponse.dart';
import '../screen/DashboardScreen.dart';
import '../utils/AppWidget.dart';
import '../utils/common.dart';
import '../utils/constant.dart';
import '../utils/loader.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:store_redirect/store_redirect.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'QRScannerScreen.dart';

class HomeScreen extends StatefulWidget {
  static String tag = '/HomeScreen';

  final String? mUrl, title;

  HomeScreen({this.mUrl, this.title});

  @override
  _HomeScreenState createState() => new _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  InAppWebViewController? webViewController;
  ReceivePort port = ReceivePort();
  PullToRefreshController? pullToRefreshController;

  Future<void> loadDeviceToken() async {
    // 1. تهيئة OneSignal أولاً
    OneSignal.initialize("a6cc9220-e4ee-4769-9163-4220de72190f");

    // 2. طلب صلاحية الإشعارات (يجب أن يقبلها المستخدم)
    await OneSignal.Notifications.requestPermission(true);

    // 3. جلب Device Token
    String? deviceToken = OneSignal.User.pushSubscription?.id;

    if (deviceToken != null && deviceToken.isNotEmpty) {
      print("Device Token loaded: $deviceToken");
    } else {
      print("Device Token not available yet - user might not be subscribed");
    }
  }



  List<TabsResponse> mTabList = [];
  List<MenuStyleModel> mBottomMenuList = [];

  String? mInitialUrl;
  String? deviceToken;

  bool isWasConnectionLoss = false;
  bool mIsPermissionGrant = false;


  void _getInstanceId() async {
    await Firebase.initializeApp();
    FirebaseInAppMessaging.instance.triggerEvent("");
    // FirebaseMessaging.instance.sendMessage();
    FirebaseMessaging.instance.getInitialMessage();
  }

  @override
  void initState() {
    requestNotificationPermission();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    Future.delayed(Duration(seconds: 2), () {
      loadDeviceToken();
    });
    Iterable mTabs = jsonDecode(getStringAsync(TABS));
    mTabList = mTabs.map((model) => TabsResponse.fromJson(model)).toList();
    _getInstanceId();
    loadDeviceToken();
    if (getStringAsync(IS_WEBRTC) == "true") {
      checkWebRTCPermission();
    }
    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: appStore.primaryColors, enabled: getStringAsync(IS_PULL_TO_REFRESH) == "true" ? true : false),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
    init();
   // loadInterstitialAds();
  }
  Future<void> requestNotificationPermission() async {
    // 1️⃣ تهيئة OneSignal أولًا
    OneSignal.initialize("a6cc9220-e4ee-4769-9163-4220de72190f");

    // 2️⃣ طلب صلاحية الإشعارات من المستخدم
    bool accepted = await OneSignal.Notifications.requestPermission(true);

    if (accepted) {
      print("User accepted push notifications");
    } else {
      print("User declined push notifications");
    }

    // 3️⃣ بعد القبول، جلب Device Token
    String? deviceToken = OneSignal.User.pushSubscription?.id;

    if (deviceToken != null) {
      print("Device Token: $deviceToken");
    } else {
      print("Device Token not available yet");
    }
  }
  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        if (result == PermissionStatus.granted) {
          mIsPermissionGrant = true;
          setState(() {});
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    init();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> init() async {
    String? referralCode = getReferralCodeFromNative();
    if (referralCode!.isNotEmpty) {
      mInitialUrl = referralCode;
    }
    if (deviceToken != null && mInitialUrl != null) {
      if (!mInitialUrl!.contains('?')) {
        mInitialUrl = "$mInitialUrl?token=$deviceToken";
      } else {
        mInitialUrl = "$mInitialUrl&token=$deviceToken";
      }
    }

    if (getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER) {
      Iterable mBottom = jsonDecode(getStringAsync(MENU_STYLE));
      mBottomMenuList = mBottom.map((model) => MenuStyleModel.fromJson(model)).toList();
    } else {
      Iterable mBottom = jsonDecode(getStringAsync(BOTTOMMENU));
      mBottomMenuList = mBottom.map((model) => MenuStyleModel.fromJson(model)).toList();
    }
    if (getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER) {
      if (mBottomMenuList.isNotEmpty) {
        mInitialUrl = widget.mUrl;
      } else {
        mInitialUrl = getStringAsync(URL);
      }
    } else if (getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS) {
      log(widget.mUrl);
      if (mTabList.isNotEmpty) {
        mInitialUrl = widget.mUrl;
        log(mInitialUrl);
      } else {
        mInitialUrl = getStringAsync(URL);
      }
    } else {
      mInitialUrl = getStringAsync(URL);
    }

    if (webViewController != null) {
      await webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(mInitialUrl!)));
    } else {
      log("sorry");
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      init();
    });
  }

  String? _extractTelegramUsername(String url) {
    final RegExp usernameRegex = RegExp(
      r'(?:https?://)?(?:www\.)?(?:t\.me|telegram\.me)[/]?([\w-]+)',
      caseSensitive: false,
    );
    final match = usernameRegex.firstMatch(url);
    return match?.group(1);
  }
  @override
  Widget build(BuildContext context) {
    var appLocalization = AppLocalizations.of(context);
    Future<bool> _exitApp() async {
      String? currentUrl = (await webViewController?.getUrl())?.toString();
      if (await webViewController!.canGoBack() && currentUrl != mInitialUrl) {
        webViewController!.goBack();
        return false;
      } else {
        log("--------------Show_exit");

        if (getStringAsync(IS_Exit_POP_UP) == "true") {
          return mConfirmationDialog(() {
            Navigator.of(context).pop(false);
          }, context, appLocalization);
        } else {
          exit(0);
        }
      }
    }

    Widget mLoadWeb({String? mURL}) {
      return Stack(
        children: [
          FutureBuilder(
              future: Future.delayed(Duration(milliseconds: 200)),
              builder: (context, snapshot) {
                return InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(mURL.isEmptyOrNull ? mInitialUrl.validate() : mURL!)),
                    initialSettings: InAppWebViewSettings(
                      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      allowBackgroundAudioPlaying: true,
                      transparentBackground: true,
                      // crossPlatform: InAppWebViewOptions(
                      useShouldOverrideUrlLoading: true,
                      userAgent: getStringAsync(USER_AGENT),
                      mediaPlaybackRequiresUserGesture: false,
                      allowsAirPlayForMediaPlayback: true,
                      allowFileAccessFromFileURLs: true,
                      useOnDownloadStart: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      javaScriptEnabled: getStringAsync(IS_JAVASCRIPT_ENABLE) == "true" ? true : false,
                      supportZoom: getStringAsync(IS_ZOOM_FUNCTIONALITY) == "true" ? true : false,
                      incognito: getStringAsync(IS_COOKIE) == "true" ? true : false,
                      clearCache: getStringAsync(IS_COOKIE) == "true" ? true : false,
                      useHybridComposition: true,
                      allowsInlineMediaPlayback: true,
                    ),
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      log("onLoadStart");
                      if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(true);
                      setState(() {});
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        pullToRefreshController!.endRefreshing();
                        if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(false);
                        setState(() {});
                      }
                    },
                    onLoadStop: (controller, url) async {
                      log("onLoadStop");
                      pullToRefreshController!.endRefreshing();
                      if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(false);
                      //webViewController!.evaluateJavascript(source: 'document.getElementsByClassName("navbar-main")[0].style.display="none";');

                      await webViewController!.evaluateJavascript(source: """
                        if (typeof XMLHttpRequest.prototype.originalOpen === 'undefined') {
                          XMLHttpRequest.prototype.originalOpen = XMLHttpRequest.prototype.open;
                          XMLHttpRequest.prototype.open = function(method, url) {
                            this.originalOpen.apply(this, arguments);
                            if (url.includes('.mp3') || url.includes('.m4a')) {
                              this.setRequestHeader('Range', 'bytes=0-');
                            }
                          };
                        }
                      """);
                      if (getStringAsync(DISABLE_HEADER) == "true") {
                        webViewController!
                            .evaluateJavascript(source: "javascript:(function() { " + "var head = document.getElementsByTagName('header')[0];" + "head.parentNode.removeChild(head);" + "})()")
                            .then((value) => debugPrint('Page finished loading Javascript'))
                            .catchError((onError) => debugPrint('$onError'));
                      }

                      if (getStringAsync(DISABLE_FOOTER) == "true") {
                        webViewController!.evaluateJavascript(
                            source: "javascript:(function() {"
                                + "var footer = document.getElementsByTagName('footer')[0];"
                                + "if (footer) footer.parentNode.removeChild(footer);"
                                + "var customFooter = document.querySelector('section[data-ppt-blockid=\"footer1\"]');"
                                + "if (customFooter) customFooter.parentNode.removeChild(customFooter);"
                                + "console.log('Footer removed');"
                                + "})()"
                        ).then((value) => debugPrint('Footer removal script executed'))
                            .catchError((onError) => debugPrint('$onError'));
                      }
                      await webViewController!.evaluateJavascript(
                          source: """
                            console.log("WebView is ready. Adding enhanced media handlers...");

                            // Handle media ended and cue the next track
                            document.querySelectorAll('audio, video').forEach(media => {
                              media.setAttribute('preload', 'auto');
                              if(media.tagName === 'VIDEO') {
                                media.setAttribute('playsinline', 'true');
                                media.setAttribute('webkit-playsinline', 'true');
                              }
                              
                              // Handle media errors (fixes ERR_FAILED)
                              media.addEventListener('error', (e) => {
                                console.error('Media error:', e);
                                if(media.src.includes('.mp3')) {
                                  const newSrc = media.src.split('?')[0];
                                  console.log('Retrying without range header:', newSrc);
                                  media.src = newSrc;
                                  media.load();
                                  media.play().catch(err => console.error('Fallback play failed:', err));
                                }
                              });
                              
                              // Next track handling
                              media.addEventListener('ended', function() {
                                console.log('Media ended, attempting to load next...');
                                if (media.dataset.next) {
                                  console.log('Loading next media: ' + media.dataset.next);
                                  media.src = media.dataset.next;
                                  media.load();
                                  media.play().catch(e => console.error('Error playing next media:', e));
                                } else {
                                  console.log('No next media found.');
                                }
                              });
                            });

                            // Keep audio playing when app is minimized
                            document.addEventListener('visibilitychange', function() {
                              if (document.visibilityState === 'hidden') {
                                console.log('App minimized, ensuring media continues playing...');
                                document.querySelectorAll('video, audio').forEach(media => {
                                  if (!media.paused) {
                                    try {
                                      const context = new (window.AudioContext || window.webkitAudioContext)();
                                      const source = context.createMediaElementSource(media);
                                      source.connect(context.destination);
                                    } catch(e) {
                                      console.error('Audio context creation failed:', e);
                                    }
                                    media.play().catch(e => console.log('Background play attempt:', e));
                                  }
                                });
                              }
                            });

                            // Improve buffering
                            document.querySelectorAll('audio, video').forEach(media => {
                              media.addEventListener('canplay', () => {
                                console.log('Media ready, ensuring playback...');
                                if (media.paused && !media.ended) {
                                  media.play().catch(e => console.error('Autoplay failed:', e));
                                } 
                              });
                            });

                            console.log("Enhanced media handlers attached successfully.");
                          """
                      );
                      setState(() {});
                    },
                    onEnterFullscreen: (controller) async {
                      try {
                        final aspectRatioRaw = await controller.evaluateJavascript(source:
                        '''
                          (function() {
                            var video = document.querySelector('video');
                            if (video) {
                              return video.videoWidth / video.videoHeight;
                            }
                            return null;
                          })();
                        '''
                        );

                        if (aspectRatioRaw != null) {
                          final cleaned = aspectRatioRaw.toString().replaceAll('"', '');
                          final aspect = double.tryParse(cleaned);

                          if (aspect != null) {
                            if (aspect > 1.0) {
                              await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                              await SystemChrome.setPreferredOrientations([
                                DeviceOrientation.landscapeLeft,
                                DeviceOrientation.landscapeRight,
                              ]);
                            } else {
                              // Portrait
                              await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                              await SystemChrome.setPreferredOrientations([
                                DeviceOrientation.portraitUp,
                                DeviceOrientation.portraitDown,
                              ]);
                            }
                          }
                        } else {
                          debugPrint("Aspect ratio is null; defaulting to portrait orientation.");
                          await SystemChrome.setPreferredOrientations([
                            DeviceOrientation.portraitUp,
                            DeviceOrientation.portraitDown,
                          ]);
                        }
                      } catch (e) {
                        debugPrint("Error setting orientation: $e");
                        await SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                        ]);
                      }
                    },
                    onExitFullscreen: (controller) async {
                      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                      await SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                    },
                    onReceivedError: (InAppWebViewController controller, WebResourceRequest request, WebResourceError error) {
                      log("onLoadError");
                      log("WebView error: ${error.description}");
                      if (getStringAsync(IS_LOADER) == "true") appStore.setLoading(false);
                      pullToRefreshController!.endRefreshing();
                      setState(() {});
                    },
                    shouldOverrideUrlLoading: (controller, navigationAction) async {
                      var uri = navigationAction.request.url;
                      var url = navigationAction.request.url.toString();
                      log("URL->" + url.toString());

                      print("----------------------------Navigating to URL: $url");

                      // Telegram URL handling
                      if (url.startsWith('tg:') || url.contains('t.me') || url.contains('telegram.me')) {
                        try {
                          final username = _extractTelegramUsername(url);

                          if (username != null) {
                            final appUri = Uri.parse('tg://resolve?domain=$username');
                            final webUri = Uri.parse('https://t.me/$username');

                            if (await canLaunchUrl(appUri)) {
                              await launchUrl(appUri, mode: LaunchMode.externalNonBrowserApplication);
                            } else if (await canLaunchUrl(webUri)) {
                              await launchUrl(webUri, mode: LaunchMode.externalApplication);
                            } else {
                              // Fallback to original URL if both app and web launch fail
                              await launchUrl(
                                  Uri.parse(url),
                                  mode: LaunchMode.externalApplication
                              );
                            }
                          } else {
                            // Handle non-username URLs (e.g., invite links)
                            final parsedUri = Uri.parse(url);
                            if (await canLaunchUrl(parsedUri)) {
                              await launchUrl(parsedUri, mode: LaunchMode.externalApplication);
                            }
                          }
                          return NavigationActionPolicy.CANCEL;
                        } catch (e) {
                          print("Telegram launch error: $e");
                          await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication
                          );
                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                      if (url.contains("youtube.com")) {
                        return NavigationActionPolicy.ALLOW;
                      }

                      if (Platform.isAndroid && url.contains("intent")) {
                        if (url.contains("maps")) {
                          var mNewURL = url.replaceAll("intent://", "https://");
                          if (await canLaunchUrl(Uri.parse(mNewURL))) {
                            await launchUrl(Uri.parse(mNewURL), mode: LaunchMode.externalApplication);
                            return NavigationActionPolicy.CANCEL;
                          }
                        } else {
                          String id = url.substring(url.indexOf('id%3D') + 5, url.indexOf('#Intent'));
                          await StoreRedirect.redirect(androidAppId: id);
                          return NavigationActionPolicy.CANCEL;
                        }
                      } else if (url.contains("linkedin.com") ||
                          url.contains("market://") ||
                          url.contains("whatsapp://") ||
                          url.contains("truecaller://") ||
                          url.contains("pinterest.com") ||
                          url.contains("snapchat.com") ||
                          url.contains("youtube.com") ||
                          url.contains("instagram.com") ||
                          url.contains("play.google.com") ||
                          url.contains("mailto:") ||
                          url.contains("tel:") ||
                          url.contains("share=telegram") ||
                          url.contains("messenger.com")) {
                        if (url.contains("https://api.whatsapp.com/send?phone=+")) {
                          url = url.replaceAll("https://api.whatsapp.com/send?phone=+", "https://api.whatsapp.com/send?phone=");
                        } else if (url.contains("whatsapp://send/?phone=%20")) {
                          url = url.replaceAll("whatsapp://send/?phone=%20", "whatsapp://send/?phone=");
                        }
                        if (!url.contains("whatsapp://")) {
                          url = Uri.encodeFull(url);
                        }
                        try {
                          if (await canLaunchUrl(Uri.parse(url))) {
                            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          } else {
                            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          }
                          return NavigationActionPolicy.CANCEL;
                        } catch (e) {
                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          return NavigationActionPolicy.CANCEL;
                        }
                      } else if (!["http", "https", "chrome", "data", "javascript", "about"].contains(uri!.scheme)) {
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                      return NavigationActionPolicy.ALLOW;
                    },

                    onDownloadStartRequest: (controller, downloadStartRequest) {
                      launchUrl(Uri.parse(downloadStartRequest.url.toString()), mode: LaunchMode.externalApplication);
                    },
                    onGeolocationPermissionsShowPrompt: (InAppWebViewController controller, String origin) async {
                      await Permission.location.request();
                      return Future.value(GeolocationPermissionShowPromptResponse(origin: origin, allow: true, retain: true));
                    },
                    onPermissionRequest: (InAppWebViewController controller, PermissionRequest request) async {
                      List resources = request.resources;
                      if (resources.length >= 1) {} else {
                        resources.forEach((element) async {
                          if (element.contains("AUDIO_CAPTURE")) {
                            await Permission.microphone.request();
                          }
                          if (element.contains("VIDEO_CAPTURE")) {
                            await Permission.camera.request();
                          }
                        });
                      }
                      return PermissionResponse(resources: request.resources, action: PermissionResponseAction.GRANT);
                    }).visible(isWasConnectionLoss == false);
              }),
          //NoInternetConnection().visible(isWasConnectionLoss == true),
          // Loaders(name: appStore.loaderValues).center().visible(appStore.isLoading)
          Container(color: Colors.white, height: context.height(), width: context.width(), child: Loaders(name: appStore.loaderValues).center()).visible(appStore.isLoading)
        ],
      );
    }
    Widget mBody() {
      return Container(
        color:appStore.primaryColors,
        child: SafeArea(
          child: Scaffold(
            // backgroundColor: context.cardColor,
            drawerEdgeDragWidth: 0,
            appBar: getStringAsync(NAVIGATIONSTYLE) != NAVIGATION_STYLE_FULL_SCREEN
                ? PreferredSize(
              child: AppBarComponent(
                onTap: (value) {
                  if (value == RIGHT_ICON_RELOAD) {
                    webViewController!.reload();
                  }
                  if (RIGHT_ICON_SHARE == value) {
                    Share.share(getStringAsync(SHARE_CONTENT));
                  }
                  if (RIGHT_ICON_CLOSE == value || LEFT_ICON_CLOSE == value) {
                    if (getStringAsync(IS_Exit_POP_UP) == "true") {
                      mConfirmationDialog(() {
                        Navigator.of(context).pop(false);
                      }, context, appLocalization);
                    }
                  }
                  if (RIGHT_ICON_SCAN == value) {
                    QRScannerScreen().launch(context, pageRouteAnimation: PageRouteAnimation.Slide);
                  }
                  if (LEFT_ICON_BACK_1 == value) {
                    _exitApp();
                  }
                  if (LEFT_ICON_BACK_2 == value) {
                    _exitApp();
                  }
                  if (LEFT_ICON_HOME == value) {
                    DashBoardScreen().launch(context);
                  }
                },
              ),
              preferredSize: Size.fromHeight((getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR ||
                  getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER ||
                  getStringAsync(HEADERSTYLE) == HEADER_STYLE_CENTER ||
                  getStringAsync(DISABLE_LEFT_ICON)==true  ||
                  getStringAsync(HEADERSTYLE) == HEADER_STYLE_LEFT ||
                  getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER ||
                  getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS)
                  ? getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR
                  ? 100.0
                  : 60.0
                  : 0.0),
            )
                : PreferredSize(
              child: SizedBox(),
              preferredSize: Size.fromHeight(0.0),
            ),
            floatingActionButton: getStringAsync(IS_FLOATING) == "true" ? FloatingComponent() : SizedBox(),
            drawer: Drawer(
              child: SideMenuComponent(onTap: () {
                mInitialUrl = getStringAsync(URL).isNotEmpty ? getStringAsync(URL) : "https://www.google.com";
                webViewController!.reload();
              }),
            ).visible(getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER ||
                getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER ||
                getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS),
            body: getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS && appStore.mTabList.length != 0
                ? TabBarView(
              physics: NeverScrollableScrollPhysics(),
              children: [
                for (int i = 0; i < mTabList.length; i++) mLoadWeb(mURL: mTabList[i].url),
              ],
            )
                : mLoadWeb(mURL: mInitialUrl),
            bottomNavigationBar: getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_BOTTOM_NAVIGATION_SIDE_DRAWER
                ? SizedBox.shrink()
                : showBannerAds(),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: _exitApp,
      child: getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_TAB_BAR || getStringAsync(NAVIGATIONSTYLE) == NAVIGATION_STYLE_SIDE_DRAWER_TABS
          ? DefaultTabController(
        length: appStore.mTabList.length,
        child: mBody(),
      )
          : mBody(),
    );
  }
}
