import 'package:flutter/material.dart';

/// Título de sección con un texto de ayuda opcional para los alumnos.
class Section extends StatelessWidget {
  final String title;
  final String? help;
  final Widget child;
  const Section({super.key, required this.title, this.help, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (help != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: help!,
                waitDuration: const Duration(milliseconds: 200),
                child: Icon(Icons.help_outline, size: 16, color: theme.colorScheme.outline),
              ),
            ],
          ]),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
