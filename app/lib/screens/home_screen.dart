import 'package:flutter/material.dart';

import '../widgets/control_panel.dart';
import '../widgets/detections_panel.dart';
import '../widgets/video_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final divider = VerticalDivider(width: 1, color: Theme.of(context).dividerColor);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visión Interactiva · YOLOv8'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      ),
      body: Row(
        children: [
          const SizedBox(width: 340, child: ControlPanel()),
          divider,
          const Expanded(child: VideoView()),
          divider,
          const SizedBox(width: 320, child: DetectionsPanel()),
        ],
      ),
    );
  }
}
