import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ar_view.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

const int _markerCount = 6;

// 마커가 이 시간(ms) 동안 감지되지 않으면 소실로 판단
// continuousImageTracking 업데이트 간격(500ms)보다 충분히 크게 설정
const int _markerLostThresholdMs = 2000;

List<String> get _markerPaths =>
    List.generate(_markerCount, (i) => 'assets/marker/${i + 1}.png');

String _modelPath(int n) => 'assets/model/$n.glb';

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;

  // 현재 화면에 표시 중인 노드 (마커 키 → 노드)
  final Map<String, ARNode> _placedNodes = {};

  // 마커별 마지막 감지 시각 (마커 키 → DateTime)
  final Map<String, DateTime> _lastDetectedAt = {};

  // 마커 소실 감지용 주기적 타이머
  Timer? _lostCheckTimer;

  // 마지막으로 어떤 마커든 인식된 시각 (세션 리셋 판단용)
  DateTime? _lastAnyDetectedAt;

  // 세션 리셋 중 플래그
  bool _isResetting = false;

  // 진행 중인 placeModel 작업이 있으면 중복 호출 방지
  bool _isPlacing = false;

  String _statusMessage = '카메라를 마커에 향해 주세요';

  @override
  void dispose() {
    _lostCheckTimer?.cancel();
    _arSessionManager?.dispose();
    super.dispose();
  }

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;

    _arSessionManager!.onImageDetected = _handleImageDetected;

    _arSessionManager!.onInitialize(
      showAnimatedGuide: false,
      showFeaturePoints: false,
      showPlanes: false,
      handleTaps: false,
      trackingImagePaths: _markerPaths,
      continuousImageTracking: true,
      imageTrackingUpdateIntervalMs: 200,
    );

    _arObjectManager!.onInitialize();

    // 마커 소실 감지 타이머 시작 (500ms마다 확인)
    _lostCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkLostMarkers();
    });
  }

  void _handleImageDetected(
    String imageName,
    vm.Matrix4 transformation,
    double width,
    double height,
  ) {
    final markerNumber = _parseMarkerNumber(imageName);
    if (markerNumber == null) return;

    final markerKey = 'marker_$markerNumber';

    // 마지막 감지 시각 갱신
    final now = DateTime.now();
    _lastDetectedAt[markerKey] = now;
    _lastAnyDetectedAt = now;

    _placeModel(imageName, transformation, width);
  }

  /// 타이머로 주기적으로 호출 — 오래된 마커 노드 제거
  Future<void> _checkLostMarkers() async {
    final now = DateTime.now();
    final lostKeys = <String>[];

    for (final entry in _lastDetectedAt.entries) {
      final elapsed = now.difference(entry.value).inMilliseconds;
      if (elapsed > _markerLostThresholdMs && _placedNodes.containsKey(entry.key)) {
        lostKeys.add(entry.key);
      }
    }

    for (final key in lostKeys) {
      final node = _placedNodes[key];
      if (node != null) {
        await _arObjectManager?.removeNode(node);
        _placedNodes.remove(key);
        _lastDetectedAt.remove(key);
      }
    }

    if (lostKeys.isNotEmpty && mounted) {
      setState(() {
        _statusMessage = _placedNodes.isEmpty ? '카메라를 마커에 향해 주세요' : _statusMessage;
      });
    }

    // 마커가 없는 상태에서 5초 이상 경과하면 세션 리셋 (재인식 시도)
    if (_placedNodes.isEmpty && !_isResetting) {
      final lastSeen = _lastAnyDetectedAt;
      final elapsedSinceLast = lastSeen == null
          ? Duration(seconds: 99)
          : DateTime.now().difference(lastSeen);
      if (elapsedSinceLast.inSeconds >= 5) {
        _resetSession();
      }
    }
  }

  /// ARKit 세션 리셋 — 이미 추적 중이던 앵커를 버리고 처음부터 다시 이미지 탐색
  Future<void> _resetSession() async {
    if (_isResetting) return;
    _isResetting = true;

    // 남아있는 노드 모두 제거
    for (final node in _placedNodes.values) {
      await _arObjectManager?.removeNode(node);
    }
    _placedNodes.clear();
    _lastDetectedAt.clear();
    _lastAnyDetectedAt = DateTime.now(); // 연속 리셋 방지

    // 이미지 트래킹 설정을 다시 적용해 세션 재시작
    await _arSessionManager?.onInitialize(
      showAnimatedGuide: false,
      showFeaturePoints: false,
      showPlanes: false,
      handleTaps: false,
      trackingImagePaths: _markerPaths,
      continuousImageTracking: true,
      imageTrackingUpdateIntervalMs: 200,
    );

    _isResetting = false;
  }

  Future<void> _placeModel(String imageName, vm.Matrix4 transformation, double markerWidth) async {
    if (_isPlacing) return;
    _isPlacing = true;

    try {
      final markerNumber = _parseMarkerNumber(imageName);
      if (markerNumber == null) return;

      final markerKey = 'marker_$markerNumber';

      // 같은 마커가 이미 표시 중이면 무시 (continuousTracking 업데이트 무시)
      if (_placedNodes.containsKey(markerKey)) return;

      // 다른 마커의 노드가 있으면 모두 제거
      for (final node in _placedNodes.values) {
        await _arObjectManager?.removeNode(node);
      }
      _placedNodes.clear();

      // 마커 실제 폭(m) 기준으로 화면 좁은 쪽 50% 크기 계산
      // markerWidth가 0이면 FOV 기반으로 fallback
      final scale = markerWidth > 0.001
          ? _scaleFromMarker(markerWidth)
          : _computeScale(transformation);

      // 마커 위에 모델을 세워서 앞면이 보이도록:
      // 1) 마커 평면에서 X축으로 -90° 회전 → 모델이 마커에 수직으로 섬
      // 2) 마커의 transformation을 곱해 월드 좌표로 변환
      final rotation = vm.Matrix4.rotationX(-math.pi / 2);
      final finalTransform = transformation * rotation;

      final node = ARNode(
        type: NodeType.localGLB,
        uri: _modelPath(markerNumber),
        scale: vm.Vector3(scale, scale, scale),
        transformation: finalTransform,
      );

      final success = await _arObjectManager?.addNode(node);

      if (success == true && mounted) {
        _placedNodes[markerKey] = node;
        setState(() {
          _statusMessage = '마커 $markerNumber 인식';
        });
      }
    } finally {
      _isPlacing = false;
    }
  }

  /// 마커 실제 폭(markerWidth, 단위: m)을 기준으로
  /// 화면 좁은 쪽 50%에 해당하는 ARKit 월드 단위 스케일을 반환합니다.
  ///
  /// ARKit에서 1단위 = 1m이고, GLB 모델의 기준 크기는 보통 1단위(1m)입니다.
  /// 화면에서 마커가 차지하는 비율을 기반으로 목표 크기를 역산합니다.
  double _scaleFromMarker(double markerWidth) {
    final size = MediaQuery.of(context).size;
    // 화면 좁은 쪽 물리 크기 (pt)
    final shortSidePt = math.min(size.width, size.height);
    // 목표 크기 = 화면 좁은 쪽의 50% → 마커 폭 대비 비율로 환산
    // 화면에서 마커가 차지하는 pt 크기를 알 수 없으므로
    // 마커 실제 크기(m) 기준: 모델을 markerWidth * (shortSidePt 비율) 로 스케일
    // 일반적으로 마커는 화면의 약 30% 정도를 차지한다고 가정
    const markerScreenRatio = 0.3;
    final markerPt = shortSidePt * markerScreenRatio;
    final targetPt = shortSidePt * 0.5;
    // 마커 1m → markerPt pt 이므로 목표 pt → 몇 m인지 환산
    return markerWidth * (targetPt / markerPt);
  }

  /// FOV 기반 fallback 스케일 계산
  double _computeScale(vm.Matrix4 transformation) {
    final tx = transformation.storage[12];
    final ty = transformation.storage[13];
    final tz = transformation.storage[14];
    final distance = math.sqrt(tx * tx + ty * ty + tz * tz);
    if (distance < 0.01) return 0.1;

    final size = MediaQuery.of(context).size;
    final shortSidePt = math.min(size.width, size.height);
    const vFovRad = 60.0 * math.pi / 180.0;
    final screenHeightWorld = 2.0 * distance * math.tan(vFovRad / 2.0);
    final ptToWorld = screenHeightWorld / size.height;
    return shortSidePt * ptToWorld * 0.5;
  }

  int? _parseMarkerNumber(String imageName) {
    final baseName = imageName.split('/').last.split('.').first;
    final number = int.tryParse(baseName);
    if (number == null || number < 1 || number > _markerCount) return null;
    return number;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.none,
          ),

          // 상단 상태 메시지
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
