import 'package:flutter_test/flutter_test.dart';
import 'package:vision_interactiva/models.dart';

void main() {
  test('FrameMeta interpreta el JSON del backend', () {
    final meta = FrameMeta.fromJson({
      'type': 'frame',
      'frame': 3,
      'fps': 29.5,
      'infer_ms': 7.2,
      'device': 'cuda',
      'task': 'detect',
      'model': 'yolov8n',
      'source': 'realsense:123',
      'has_depth': true,
      'width': 640,
      'height': 480,
      'detections': [
        {
          'cls': 0,
          'name': 'person',
          'conf': 0.91,
          'bbox': [10, 20, 110, 220],
          'center': [60, 120],
          'depth_m': 1.234,
          'xyz': [0.1, 0.2, 1.234],
        },
        {'cls': 41, 'name': 'cup', 'conf': 0.5, 'bbox': [1, 2, 3, 4], 'center': [2, 3], 'depth_m': null, 'xyz': null},
      ],
      'logging': {'active': true, 'session': 'C:\\logs\\s1', 'rows': 4, 'logs_dir': 'C:\\logs'},
    });
    expect(meta.detections, hasLength(2));
    expect(meta.detections.first.depthM, closeTo(1.234, 1e-9));
    expect(meta.detections.last.depthM, isNull);
    expect(meta.logging!.rows, 4);
  });
}
