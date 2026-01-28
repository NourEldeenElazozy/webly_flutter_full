import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: Colors.white,
    primaryColor: appStore.primaryColors,
    hoverColor: Colors.grey,
    textTheme: GoogleFonts.cairoTextTheme(
      ThemeData.dark().textTheme, // نمرر ثيم النصوص المظلم ليقوم الخط بتغليفه
    ),
    appBarTheme: AppBarTheme(
      color: appStore.primaryColors,
     // brightness: appStore.primaryColors.isDark() ? Brightness.dark : Brightness.light,
    ),
    iconTheme: IconThemeData(color: Colors.black),
    cardTheme: CardThemeData(color: Colors.white),
  ).copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: Color(0xFF131d25),
    appBarTheme: AppBarTheme(
      color: appStore.primaryColors,
      //brightness: appStore.primaryColors.isDark() ? Brightness.dark : Brightness.light,
    ),
    primaryColor: appStore.primaryColors,
    textTheme: GoogleFonts.cairoTextTheme(
      ThemeData.dark().textTheme, // نمرر ثيم النصوص المظلم ليقوم الخط بتغليفه
    ),
    cardTheme: CardThemeData(color: Color(0xFF1D2939)),
    iconTheme: IconThemeData(color: Colors.white70),
  ).copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
