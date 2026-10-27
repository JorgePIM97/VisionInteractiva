import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_client.dart';

/// Arranca el backend de Python (uvicorn) si no está corriendo ya.
class BackendLauncher {
  final ApiClient api;
  Process? _process;
  final List<String> _output = [];

  BackendLauncher(this.api);

  /// Últimas líneas de la consola del backend, útiles para diagnosticar errores.
  String get recentOutput => _output.join('\n');

  /// Busca la carpeta `backend` subiendo desde el directorio actual y desde el ejecutable.
  static Directory? findBackendDir() {
    final starts = [Directory.current.path, File(Platform.resolvedExecutable).parent.path];
    for (final start in starts) {
      var dir = Directory(start);
      for (var i = 0; i < 8; i++) {
        final candidate = Directory('${dir.path}${Platform.pathSeparator}backend');
        if (File('${candidate.path}${Platform.pathSeparator}app${Platform.pathSeparator}main.py').existsSync()) {
          return candidate;
        }
        if (dir.parent.path == dir.path) break;
        dir = dir.parent;
      }
    }
    return null;
  }

  /// Devuelve null si el backend quedó listo, o un mensaje de error.
  Future<String?> ensureRunning({void Function(String)? onProgress}) async {
    if (await api.health()) return null;

    final backend = findBackendDir();
    if (backend == null) {
      return 'No se encontró la carpeta "backend". Arráncalo manualmente con start_backend.bat.';
    }
    final python = File('${backend.path}\\.venv\\Scripts\\python.exe');
    if (!python.existsSync()) {
      return 'No existe ${python.path}. Ejecuta primero setup_backend.bat.';
    }

    onProgress?.call('Iniciando el servidor de visión...');
    _process = await Process.start(
      python.path,
      ['-m', 'uvicorn', 'app.main:app', '--host', '127.0.0.1', '--port', '${api.port}'],
      workingDirectory: backend.path,
    );
    for (final stream in [_process!.stdout, _process!.stderr]) {
      stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        _output.add(line);
        if (_output.length > 40) _output.removeAt(0);
      });
    }

    var exited = false;
    unawaited(_process!.exitCode.then((_) => exited = true));
    // Importar torch y ultralytics puede tardar varios segundos la primera vez
    for (var i = 0; i < 120; i++) {
      if (exited) return 'El servidor se cerró al iniciar:\n$recentOutput';
      if (await api.health()) return null;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return 'El servidor no respondió a tiempo:\n$recentOutput';
  }

  void stop() {
    final process = _process;
    if (process == null) return;
    // El python.exe del venv es un lanzador que crea otro proceso hijo:
    // hay que terminar el árbol completo para no dejar el servidor huérfano.
    Process.runSync('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
    _process = null;
  }
}
