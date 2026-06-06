import 'package:flutter/material.dart';

import 'agent/agent.dart';
import 'theme/app_theme.dart';
import 'widgets/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoofyApp());
}

class GoofyApp extends StatefulWidget {
  const GoofyApp({super.key});

  @override
  State<GoofyApp> createState() => _GoofyAppState();
}

class _GoofyAppState extends State<GoofyApp> {
  late final Agent _hub = GoofyAgent();

  @override
  void initState() {
    super.initState();
    _hub.prepare();
  }

  @override
  void dispose() {
    _hub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goofy',
      theme: buildAppTheme(),
      home: HomeShell(hub: _hub),
    );
  }
}

