import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/vision_controller.dart';
import 'class_picker.dart';
import 'section.dart';

/// Panel izquierdo: modelo, dispositivo, fuente y opciones de detección.
class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VisionController>();
    final ready = c.backendState == BackendState.ready;
    final cuda = c.devices?.cuda ?? false;

    return AbsorbPointer(
      absorbing: !ready,
      child: Opacity(
        opacity: ready ? 1 : 0.5,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Section(
              title: 'Tarea',
              help: 'Detección: encuentra objetos y los encierra en un rectángulo.\n'
                  'Segmentación: además pinta la silueta exacta de cada objeto.\n'
                  'Pose: encuentra 17 puntos clave del cuerpo humano.',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'detect', label: Text('Detectar')),
                  ButtonSegment(value: 'segment', label: Text('Segmentar')),
                  ButtonSegment(value: 'pose', label: Text('Pose')),
                ],
                selected: {c.task},
                showSelectedIcon: false,
                onSelectionChanged: (s) => c.setTask(s.first),
              ),
            ),
            Section(
              title: 'Tamaño del modelo',
              help: 'n = nano (más rápido, menos preciso)\ns = small\nm = medium (más lento, más preciso)',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'n', label: Text('Nano')),
                  ButtonSegment(value: 's', label: Text('Small')),
                  ButtonSegment(value: 'm', label: Text('Medium')),
                ],
                selected: {c.size},
                showSelectedIcon: false,
                onSelectionChanged: (s) => c.setSize(s.first),
              ),
            ),
            Section(
              title: 'Procesar con',
              help: 'CUDA usa la tarjeta gráfica NVIDIA, que hace miles de operaciones en paralelo.\n'
                  'Compara los milisegundos de inferencia entre CUDA y CPU.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'cuda', label: const Text('GPU (CUDA)'), icon: const Icon(Icons.memory), enabled: cuda),
                      const ButtonSegment(value: 'cpu', label: Text('CPU'), icon: Icon(Icons.developer_board)),
                    ],
                    selected: {c.device},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => c.setDevice(s.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cuda ? c.devices!.gpu ?? '' : 'No se detectó una GPU con CUDA',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Section(title: 'Fuente de video', child: _SourceSelector(c)),
            Section(
              title: 'Confianza mínima: ${(c.conf * 100).round()} %',
              help: 'El modelo solo muestra los objetos de los que está al menos así de seguro.',
              child: Slider(value: c.conf, min: 0.05, max: 0.95, divisions: 18, onChanged: c.setConf),
            ),
            if (c.task != 'pose')
              Section(
                title: 'Centro y profundidad',
                help: 'El centro es el punto medio del rectángulo: ((x1+x2)/2, (y1+y2)/2).\n'
                    'La cámara RealSense mide la distancia a ese punto con dos sensores infrarrojos (visión estéreo).',
                child: Column(children: [
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostrar el centro del bounding box'),
                    value: c.showCenter,
                    onChanged: (v) => c.setShowCenter(v ?? false),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Medir la profundidad en el centro'),
                    subtitle: c.depthAvailable ? null : const Text('Requiere la cámara RealSense'),
                    value: c.measureDepth && c.depthAvailable,
                    onChanged: c.depthAvailable ? (v) => c.setMeasureDepth(v ?? false) : null,
                  ),
                ]),
              ),
            if (c.classFilterAvailable)
              const Section(
                title: 'Objetos a detectar',
                help: 'El modelo fue pre-entrenado con el conjunto COCO, que tiene 80 tipos de objetos.',
                child: ClassPicker(),
              )
            else
              Text('El modelo de pose solo detecta personas.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SourceSelector extends StatelessWidget {
  final VisionController c;
  const _SourceSelector(this.c);

  static const _videoKey = '__video__';

  IconData _icon(String type) => switch (type) {
        'realsense' => Icons.threed_rotation,
        'webcam' => Icons.videocam,
        _ => Icons.movie,
      };

  @override
  Widget build(BuildContext context) {
    final items = <SourceInfo>[...c.sources];
    final current = c.source;
    if (current != null && current.type == 'video') items.add(current);

    return Row(children: [
      Expanded(
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: items.any((s) => s.key == current?.key) ? current!.key : null,
          key: ValueKey('${current?.key}-${items.length}'),
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          hint: const Text('Elige una cámara'),
          items: [
            for (final s in items)
              DropdownMenuItem(
                value: s.key,
                child: Row(children: [
                  Icon(_icon(s.type), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            const DropdownMenuItem(
              value: _videoKey,
              child: Row(children: [
                Icon(Icons.folder_open, size: 18),
                SizedBox(width: 8),
                Text('Abrir archivo de video...'),
              ]),
            ),
          ],
          onChanged: (key) {
            if (key == _videoKey) {
              c.pickVideo();
            } else if (key != null) {
              c.setSource(items.firstWhere((s) => s.key == key));
            }
          },
        ),
      ),
      IconButton(
        tooltip: 'Buscar cámaras',
        onPressed: c.loadingSources ? null : c.refreshSources,
        icon: c.loadingSources
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh),
      ),
    ]);
  }
}
