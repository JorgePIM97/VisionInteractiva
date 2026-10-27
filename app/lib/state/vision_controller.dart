import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/backend_launcher.dart';
import '../services/stream_client.dart';

enum BackendState { starting, ready, failed }

class VisionController extends ChangeNotifier {
  final ApiClient api;
  final BackendLauncher launcher;
  final StreamClient stream;
  StreamSubscription<StreamEvent>? _sub;
  Timer? _confDebounce;

  VisionController(this.api)
      : launcher = BackendLauncher(api),
        stream = StreamClient(api.streamUri);

  // --- Backend ---
  BackendState backendState = BackendState.starting;
  String statusMessage = 'Preparando...';
  bool statusIsError = false;

  // --- Opciones disponibles ---
  DeviceInfo? devices;
  List<ClassInfo> classes = [];
  List<SourceInfo> sources = [];
  bool loadingSources = false;

  // --- Configuración actual ---
  String task = 'detect';
  String size = 'n';
  String device = 'cpu';
  double conf = 0.4;
  SourceInfo? source;
  bool detectAll = true;
  Set<int> selectedClasses = {};
  bool showCenter = true;
  bool measureDepth = true;
  double logInterval = 0.5;
  bool logSnapshots = false;

  // --- Streaming ---
  bool streaming = false;
  Uint8List? frame;
  FrameMeta? meta;
  LoggingStatus logging = const LoggingStatus();

  bool get classFilterAvailable => task != 'pose';
  bool get depthAvailable => source?.hasDepth ?? false;

  Future<void> init() async {
    _setStatus('Iniciando el servidor de visión...');
    final error = await launcher.ensureRunning(onProgress: _setStatus);
    if (error != null) {
      backendState = BackendState.failed;
      _setStatus(error, error: true);
      return;
    }
    try {
      _setStatus('Cargando modelos y cámaras (la primera vez se descargan los pesos)...');
      devices = await api.devices();
      _applyConfig(await api.getConfig());
      classes = await api.classes('detect', 'n');
      logging = await api.loggingStatus();
      backendState = BackendState.ready;
      _setStatus('Listo. Elige una fuente y presiona Iniciar.');
      await refreshSources();
    } catch (e) {
      backendState = BackendState.failed;
      _setStatus('No se pudo comunicar con el servidor: $e', error: true);
    }
  }

  void _applyConfig(Map<String, dynamic> c) {
    task = c['task'] as String;
    size = c['size'] as String;
    device = c['device'] as String;
    conf = (c['conf'] as num).toDouble();
    final cls = c['classes'] as List?;
    detectAll = cls == null;
    if (cls != null) selectedClasses = cls.map((e) => e as int).toSet();
    showCenter = c['show_center'] as bool;
    measureDepth = c['measure_depth'] as bool;
    logInterval = (c['log_interval'] as num).toDouble();
    logSnapshots = c['log_snapshots'] as bool;
    final s = c['source'] as Map<String, dynamic>;
    source = SourceInfo(s['type'] as String, s['id'].toString(), _sourceName(s['type'] as String, s['id'].toString()));
  }

  String _sourceName(String type, String id) {
    for (final s in sources) {
      if (s.type == type && s.id == id) return s.name;
    }
    if (type == 'video') return 'Video: ${id.split(RegExp(r'[\\/]')).last}';
    return '$type $id';
  }

  void _setStatus(String message, {bool error = false}) {
    statusMessage = message;
    statusIsError = error;
    notifyListeners();
  }

  Future<void> _push(Map<String, dynamic> changes) async {
    try {
      await api.setConfig(changes);
    } catch (e) {
      _setStatus('Error al cambiar la configuración: $e', error: true);
    }
  }

  // --- Acciones de configuración ---
  Future<void> refreshSources() async {
    loadingSources = true;
    notifyListeners();
    try {
      sources = await api.sources();
      // Si no hay fuente válida elegida, preferir la RealSense
      if (source == null || (source!.type != 'video' && !sources.any((s) => s.key == source!.key))) {
        if (sources.isNotEmpty) await setSource(sources.first);
      } else {
        source = SourceInfo(source!.type, source!.id, _sourceName(source!.type, source!.id));
      }
    } catch (e) {
      _setStatus('No se pudieron listar las cámaras: $e', error: true);
    }
    loadingSources = false;
    notifyListeners();
  }

  Future<void> setTask(String value) async {
    task = value;
    notifyListeners();
    await _push({'task': value});
  }

  Future<void> setSize(String value) async {
    size = value;
    notifyListeners();
    await _push({'size': value});
  }

  Future<void> setDevice(String value) async {
    device = value;
    notifyListeners();
    await _push({'device': value});
  }

  Future<void> setSource(SourceInfo value) async {
    source = value;
    notifyListeners();
    await _push({'source': value.toJson()});
  }

  void setConf(double value) {
    conf = value;
    notifyListeners();
    _confDebounce?.cancel();
    _confDebounce = Timer(const Duration(milliseconds: 250), () => _push({'conf': value}));
  }

  Future<void> setDetectAll(bool value) async {
    detectAll = value;
    notifyListeners();
    await _pushClasses();
  }

  Future<void> toggleClass(int id, bool selected) async {
    selected ? selectedClasses.add(id) : selectedClasses.remove(id);
    notifyListeners();
    await _pushClasses();
  }

  Future<void> clearClasses() async {
    selectedClasses.clear();
    notifyListeners();
    await _pushClasses();
  }

  Future<void> _pushClasses() =>
      _push({'classes': detectAll ? null : (selectedClasses.toList()..sort())});

  Future<void> setShowCenter(bool value) async {
    showCenter = value;
    notifyListeners();
    await _push({'show_center': value});
  }

  Future<void> setMeasureDepth(bool value) async {
    measureDepth = value;
    notifyListeners();
    await _push({'measure_depth': value});
  }

  Future<void> setLogInterval(double value) async {
    logInterval = value;
    notifyListeners();
    await _push({'log_interval': value});
  }

  Future<void> setLogSnapshots(bool value) async {
    logSnapshots = value;
    notifyListeners();
    await _push({'log_snapshots': value});
  }

  /// Abre el diálogo de Windows para elegir un video (sin plugins nativos).
  Future<void> pickVideo() async {
    const script = r'''
Add-Type -AssemblyName System.Windows.Forms
$d = New-Object System.Windows.Forms.OpenFileDialog
$d.Filter = "Videos e imágenes|*.mp4;*.avi;*.mov;*.mkv;*.wmv;*.jpg;*.png|Todos|*.*"
$d.Title = "Elegir video"
if ($d.ShowDialog() -eq "OK") { [Console]::Out.Write($d.FileName) }
''';
    final result = await Process.run('powershell', ['-NoProfile', '-STA', '-Command', script]);
    final path = (result.stdout as String).trim();
    if (path.isEmpty) return;
    await setSource(SourceInfo('video', path, 'Video: ${path.split(RegExp(r'[\\/]')).last}'));
  }

  // --- Streaming ---
  Future<void> startStreaming() async {
    try {
      await stream.connect();
    } catch (e) {
      _setStatus('No se pudo conectar al stream: $e', error: true);
      return;
    }
    streaming = true;
    _sub ??= stream.events.listen(_onEvent);
    _setStatus('Conectado.');
  }

  Future<void> stopStreaming() async {
    streaming = false;
    await stream.disconnect();
    _setStatus('Detenido.');
  }

  void _onEvent(StreamEvent event) {
    switch (event) {
      case FrameEvent(:final meta, :final jpeg):
        this.meta = meta;
        frame = jpeg;
        if (meta.logging != null) logging = meta.logging!;
        statusIsError = false;
        statusMessage = '';
        notifyListeners();
      case StatusEvent(:final message, :final error):
        _setStatus(message, error: error);
      case ClosedEvent(:final error):
        streaming = false;
        _setStatus(error == null ? 'Stream cerrado.' : 'Se perdió la conexión: $error', error: error != null);
    }
  }

  // --- Registros ---
  Future<void> toggleLogging() async {
    try {
      logging = logging.active ? await api.stopLogging() : await api.startLogging();
      notifyListeners();
    } catch (e) {
      _setStatus('Error con el registro: $e', error: true);
    }
  }

  Future<String?> snapshot() async {
    try {
      return await api.snapshot();
    } catch (e) {
      _setStatus('No se pudo guardar la captura: $e', error: true);
      return null;
    }
  }

  Future<void> openLogsFolder() async {
    final dir = logging.session ?? logging.logsDir;
    if (dir.isNotEmpty) await Process.run('explorer', [dir]);
  }

  Future<void> shutdown() async {
    _confDebounce?.cancel();
    await _sub?.cancel();
    await stream.dispose();
    launcher.stop();
  }
}
