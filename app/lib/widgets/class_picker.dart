import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/vision_controller.dart';

/// Lista de clases del modelo pre-entrenado con búsqueda y la opción "Detectar todo".
class ClassPicker extends StatefulWidget {
  const ClassPicker({super.key});

  @override
  State<ClassPicker> createState() => _ClassPickerState();
}

class _ClassPickerState extends State<ClassPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VisionController>();
    final names = {for (final cls in c.classes) cls.id: cls.name};
    final filtered = c.classes.where((cls) => cls.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Detectar todo'),
          subtitle: Text(c.detectAll
              ? 'Las ${c.classes.length} clases'
              : '${c.selectedClasses.length} clase(s) seleccionada(s)'),
          value: c.detectAll,
          onChanged: c.setDetectAll,
        ),
        if (!c.detectAll) ...[
          if (c.selectedClasses.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in c.selectedClasses.toList()..sort())
                  InputChip(
                    label: Text(names[id] ?? '$id'),
                    onDeleted: () => c.toggleClass(id, false),
                    visualDensity: VisualDensity.compact,
                  ),
                ActionChip(
                  label: const Text('Quitar todas'),
                  onPressed: c.clearClasses,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Selecciona al menos un objeto.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar (ej. person, cup, dog)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 280,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final cls = filtered[i];
                return CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  title: Text(cls.name),
                  secondary: Text('${cls.id}', style: Theme.of(context).textTheme.bodySmall),
                  value: c.selectedClasses.contains(cls.id),
                  onChanged: (v) => c.toggleClass(cls.id, v ?? false),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
