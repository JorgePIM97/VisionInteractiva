import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/vision_controller.dart';
import 'section.dart';

/// Panel derecho: detecciones del frame actual y controles de registro.
class DetectionsPanel extends StatelessWidget {
  const DetectionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VisionController>();
    final detections = c.streaming ? (c.meta?.detections ?? const <Detection>[]) : const <Detection>[];
    final counts = <String, int>{};
    for (final d in detections) {
      counts[d.name] = (counts[d.name] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _LogControls(),
          Text('Detecciones (${detections.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (counts.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in counts.entries)
                Chip(label: Text('${e.key} × ${e.value}'), visualDensity: VisualDensity.compact),
            ]),
          const SizedBox(height: 6),
          Expanded(
            child: detections.isEmpty
                ? Center(child: Text('Sin detecciones', style: Theme.of(context).textTheme.bodySmall))
                : ListView.separated(
                    itemCount: detections.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _DetectionTile(detections[i], showDepth: c.meta?.hasDepth ?? false),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DetectionTile extends StatelessWidget {
  final Detection d;
  final bool showDepth;
  const _DetectionTile(this.d, {required this.showDepth});

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final details = <String>[
      if (d.center != null) 'centro (${d.center![0]}, ${d.center![1]})',
      if (d.keypoints > 0) '${d.keypoints} puntos clave',
      if (d.xyz != null) 'X ${d.xyz![0].toStringAsFixed(2)}  Y ${d.xyz![1].toStringAsFixed(2)}  Z ${d.xyz![2].toStringAsFixed(2)} m',
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${d.name}  ${(d.conf * 100).toStringAsFixed(0)} %'),
      subtitle: details.isEmpty ? null : Text(details.join('\n'), style: small),
      trailing: showDepth && d.center != null
          ? Text(d.depthM == null ? 'N/D' : '${d.depthM!.toStringAsFixed(2)} m',
              style: Theme.of(context).textTheme.titleMedium)
          : null,
    );
  }
}

class _LogControls extends StatelessWidget {
  const _LogControls();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VisionController>();
    final log = c.logging;
    final ready = c.backendState == BackendState.ready;

    return Section(
      title: 'Registro de detecciones',
      help: 'Guarda en un archivo CSV (se abre con Excel) lo que el modelo detecta mientras corre el video.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: log.active ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
            onPressed: ready ? c.toggleLogging : null,
            icon: Icon(log.active ? Icons.stop : Icons.fiber_manual_record),
            label: Text(log.active ? 'Detener registro (${log.rows} filas)' : 'Grabar registro'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Cada'),
            const SizedBox(width: 8),
            DropdownButton<double>(
              value: c.logInterval,
              isDense: true,
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('frame')),
                DropdownMenuItem(value: 0.5, child: Text('0.5 s')),
                DropdownMenuItem(value: 1.0, child: Text('1 s')),
                DropdownMenuItem(value: 2.0, child: Text('2 s')),
                DropdownMenuItem(value: 5.0, child: Text('5 s')),
              ],
              onChanged: ready ? (v) => c.setLogInterval(v!) : null,
            ),
            const Spacer(),
            const Text('Guardar fotos'),
            Checkbox(value: c.logSnapshots, onChanged: ready ? (v) => c.setLogSnapshots(v ?? false) : null),
          ]),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: c.streaming
                    ? () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final path = await c.snapshot();
                        if (path != null) messenger.showSnackBar(SnackBar(content: Text('Captura guardada: $path')));
                      }
                    : null,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Captura'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: ready ? c.openLogsFolder : null,
                icon: const Icon(Icons.folder_open),
                label: const Text('Carpeta'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
