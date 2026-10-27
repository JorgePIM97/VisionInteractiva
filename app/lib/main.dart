import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/api_client.dart';
import 'state/vision_controller.dart';

void main() {
  runApp(const VisionApp());
}

class VisionApp extends StatefulWidget {
  const VisionApp({super.key});

  @override
  State<VisionApp> createState() => _VisionAppState();
}

class _VisionAppState extends State<VisionApp> {
  late final VisionController controller;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    controller = VisionController(ApiClient())..init();
    // Al cerrar la ventana, detener el servidor de Python que lanzó la app
    _lifecycle = AppLifecycleListener(onExitRequested: () async {
      await controller.shutdown();
      return AppExitResponse.exit;
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        title: 'Visión Interactiva',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, useMaterial3: true),
        home: const HomeScreen(),
      ),
    );
  }
}
