import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/vision_controller.dart';

/// Área central: el video anotado con los indicadores de rendimiento.
class VideoView extends StatelessWidget {
  const VideoView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VisionController>();
    final theme = Theme.of(context);
    final meta = c.meta;
    final showFrame = c.streaming && c.frame != null;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showFrame)
            Image.memory(c.frame!, gaplessPlayback: true, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
          else
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (c.backendState == BackendState.starting || (c.streaming && !c.statusIsError))
                  const CircularProgressIndicator()
                else
                  Icon(Icons.videocam_off, size: 64, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SelectableText(
                    c.statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.statusIsError ? Colors.redAccent : Colors.white70),
                  ),
                ),
              ]),
            ),
          if (showFrame && meta != null)
            Positioned(
              left: 12,
              top: 12,
              child: Wrap(spacing: 8, children: [
                _Badge(Icons.speed, '${meta.fps.toStringAsFixed(1)} FPS'),
                _Badge(Icons.timer_outlined, '${meta.inferMs.toStringAsFixed(1)} ms'),
                _Badge(meta.device == 'cuda' ? Icons.memory : Icons.developer_board, meta.device.toUpperCase()),
                _Badge(Icons.model_training, meta.model),
                if (c.logging.active) const _Badge(Icons.fiber_manual_record, 'GRABANDO', color: Colors.red),
              ]),
            ),
          if (showFrame && c.statusMessage.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                color: (c.statusIsError ? Colors.red.shade900 : Colors.black).withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(c.statusMessage, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: c.backendState != BackendState.ready
                  ? null
                  : (c.streaming ? c.stopStreaming : c.startStreaming),
              backgroundColor: c.backendState != BackendState.ready ? theme.disabledColor : null,
              icon: Icon(c.streaming ? Icons.stop : Icons.play_arrow),
              label: Text(c.streaming ? 'Detener' : 'Iniciar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Badge(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color ?? Colors.white),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
