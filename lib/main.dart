import 'package:flutter/cupertino.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const GifMakerApp());
}

class GifMakerApp extends StatelessWidget {
  const GifMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'GifMaker',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(primaryColor: CupertinoColors.activeBlue),
      home: HomeScreen(),
    );
  }
}
