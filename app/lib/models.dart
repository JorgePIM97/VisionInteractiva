/// Estructuras de datos que intercambia la app con el backend.
library;

class ClassInfo {
  final int id;
  final String name;
  const ClassInfo(this.id, this.name);

  factory ClassInfo.fromJson(Map<String, dynamic> j) => ClassInfo(j['id'] as int, j['name'] as String);
}

class SourceInfo {
  final String type; // realsense | webcam | video
  final String id;
  final String name;
  const SourceInfo(this.type, this.id, this.name);

  factory SourceInfo.fromJson(Map<String, dynamic> j) =>
      SourceInfo(j['type'] as String, j['id'].toString(), (j['name'] ?? j['id']).toString());

  Map<String, dynamic> toJson() => {'type': type, 'id': id};

  String get key => '$type:$id';
  bool get hasDepth => type == 'realsense';
}

class DeviceInfo {
  final bool cuda;
  final String? gpu;
  final String torch;
  const DeviceInfo({required this.cuda, this.gpu, required this.torch});

  factory DeviceInfo.fromJson(Map<String, dynamic> j) =>
      DeviceInfo(cuda: j['cuda'] as bool, gpu: j['gpu'] as String?, torch: j['torch'] as String);
}

class Detection {
  final int cls;
  final String name;
  final double conf;
  final List<double> bbox;
  final List<int>? center;
  final double? depthM;
  final List<double>? xyz;
  final int keypoints;

  const Detection({
    required this.cls,
    required this.name,
    required this.conf,
    required this.bbox,
    this.center,
    this.depthM,
    this.xyz,
    this.keypoints = 0,
  });

  factory Detection.fromJson(Map<String, dynamic> j) => Detection(
        cls: j['cls'] as int,
        name: j['name'] as String,
        conf: (j['conf'] as num).toDouble(),
        bbox: (j['bbox'] as List).map((v) => (v as num).toDouble()).toList(),
        center: (j['center'] as List?)?.map((v) => (v as num).toInt()).toList(),
        depthM: (j['depth_m'] as num?)?.toDouble(),
        xyz: (j['xyz'] as List?)?.map((v) => (v as num).toDouble()).toList(),
        keypoints: (j['keypoints'] as List?)?.length ?? 0,
      );
}

class LoggingStatus {
  final bool active;
  final String? session;
  final int rows;
  final String logsDir;
  const LoggingStatus({this.active = false, this.session, this.rows = 0, this.logsDir = ''});

  factory LoggingStatus.fromJson(Map<String, dynamic> j) => LoggingStatus(
        active: j['active'] as bool,
        session: j['session'] as String?,
        rows: j['rows'] as int,
        logsDir: j['logs_dir'] as String,
      );
}

class FrameMeta {
  final int frame;
  final double fps;
  final double inferMs;
  final String device;
  final String task;
  final String model;
  final String source;
  final bool hasDepth;
  final List<Detection> detections;
  final LoggingStatus? logging;

  const FrameMeta({
    required this.frame,
    required this.fps,
    required this.inferMs,
    required this.device,
    required this.task,
    required this.model,
    required this.source,
    required this.hasDepth,
    required this.detections,
    this.logging,
  });

  factory FrameMeta.fromJson(Map<String, dynamic> j) => FrameMeta(
        frame: j['frame'] as int,
        fps: (j['fps'] as num).toDouble(),
        inferMs: (j['infer_ms'] as num).toDouble(),
        device: j['device'] as String,
        task: j['task'] as String,
        model: j['model'] as String,
        source: j['source'] as String,
        hasDepth: j['has_depth'] as bool,
        detections: (j['detections'] as List).map((d) => Detection.fromJson(d as Map<String, dynamic>)).toList(),
        logging: j['logging'] == null ? null : LoggingStatus.fromJson(j['logging'] as Map<String, dynamic>),
      );
}
