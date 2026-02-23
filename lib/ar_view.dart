import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';

// AR 뷰가 생성된 후 각 매니저를 전달받는 콜백 타입 정의
typedef ARViewCreatedCallback = void Function(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager);

// 플랫폼(Android/iOS)별 AR 뷰 구현을 추상화하는 인터페이스
abstract class PlatformARView {
  // 현재 플랫폼에 맞는 구현체를 반환하는 팩토리 생성자
  factory PlatformARView(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.android:
        return AndroidARView();
      case TargetPlatform.iOS:
        return IosARView();
      default:
        throw FlutterError;
    }
  }

  // 플랫폼 뷰 위젯을 빌드하는 메서드
  Widget build(
      {required BuildContext context,
      required ARViewCreatedCallback arViewCreatedCallback,
      required PlaneDetectionConfig planeDetectionConfig});

  // 네이티브 플랫폼 뷰가 생성된 후 호출되는 콜백
  void onPlatformViewCreated(int id);
}

// 플랫폼 뷰 ID를 받아 각 매니저를 초기화하고 콜백으로 전달하는 함수
Future<void> createManagers(
    int id,
    BuildContext? context,
    ARViewCreatedCallback? arViewCreatedCallback,
    PlaneDetectionConfig? planeDetectionConfig) async {
  if (context == null ||
      arViewCreatedCallback == null ||
      planeDetectionConfig == null) {
    return;
  }
  // 세션/오브젝트/앵커/위치 매니저를 생성하여 콜백으로 전달
  arViewCreatedCallback(ARSessionManager(id, context, planeDetectionConfig),
      ARObjectManager(id), ARAnchorManager(id), ARLocationManager());
}

// Android 플랫폼용 AR 뷰 구현체
class AndroidARView implements PlatformARView {
  late BuildContext? _context;
  late ARViewCreatedCallback? _arViewCreatedCallback;
  late PlaneDetectionConfig? _planeDetectionConfig;

  @override
  void onPlatformViewCreated(int id) {
    if (kDebugMode) {
      print("Android platform view created!");
    }
    // 네이티브 뷰 생성 완료 후 매니저 초기화
    createManagers(id, _context, _arViewCreatedCallback, _planeDetectionConfig);
  }

  @override
  Widget build(
      {BuildContext? context,
      ARViewCreatedCallback? arViewCreatedCallback,
      PlaneDetectionConfig? planeDetectionConfig}) {
    _context = context;
    _arViewCreatedCallback = arViewCreatedCallback;
    _planeDetectionConfig = planeDetectionConfig;
    final String viewType = 'ar_flutter_plugin_plus';
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    // AndroidView: Flutter에서 네이티브 Android 뷰를 임베드하는 위젯
    return AndroidView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: StandardMessageCodec(),
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }
}

// iOS 플랫폼용 AR 뷰 구현체
class IosARView implements PlatformARView {
  BuildContext? _context;
  ARViewCreatedCallback? _arViewCreatedCallback;
  PlaneDetectionConfig? _planeDetectionConfig;

  @override
  void onPlatformViewCreated(int id) {
    if (kDebugMode) {
      print("iOS platform view created!");
    }
    // 네이티브 뷰 생성 완료 후 매니저 초기화
    createManagers(id, _context, _arViewCreatedCallback, _planeDetectionConfig);
  }

  @override
  Widget build(
      {BuildContext? context,
      ARViewCreatedCallback? arViewCreatedCallback,
      PlaneDetectionConfig? planeDetectionConfig}) {
    _context = context;
    _arViewCreatedCallback = arViewCreatedCallback;
    _planeDetectionConfig = planeDetectionConfig;
    final String viewType = 'ar_flutter_plugin_plus';
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    // UiKitView: Flutter에서 네이티브 iOS(UIKit) 뷰를 임베드하는 위젯
    return UiKitView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: StandardMessageCodec(),
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }
}

// AR 뷰를 화면에 표시하는 StatefulWidget
// 카메라 권한 확인 없이 바로 AR 뷰를 시작함
class ARView extends StatefulWidget {
  final String permissionPromptDescription;
  final String permissionPromptButtonText;
  final String permissionPromptParentalRestriction;
  final ARViewCreatedCallback onARViewCreated;
  final PlaneDetectionConfig planeDetectionConfig;
  final bool showPlatformType;

  // const 생성자: 모든 필드가 final이므로 컴파일 타임 상수로 생성 가능
  const ARView(
      {super.key,
      required this.onARViewCreated,
      this.planeDetectionConfig = PlaneDetectionConfig.none,
      this.showPlatformType = false,
      this.permissionPromptDescription =
          "Camera permission must be given to the app for AR functions to work",
      this.permissionPromptButtonText = "Grant Permission",
      this.permissionPromptParentalRestriction =
          "Camera permission is restriced by the OS, please check parental control settings"});

  @override
  State<ARView> createState() => _ARViewState();
}

class _ARViewState extends State<ARView> {
  @override
  void initState() {
    super.initState();
    // 권한 확인 로직을 제거하고 바로 AR 뷰를 표시함
    // (Info.plist의 NSCameraUsageDescription으로 시스템 권한 요청 처리)
  }

  @override
  Widget build(BuildContext context) {
    // 권한 상태 분기 없이 바로 플랫폼 AR 뷰를 렌더링
    // widget.showPlatformType: State에서 StatefulWidget 속성에 접근하는 올바른 방법
    return Column(children: [
      if (widget.showPlatformType) Text(Theme.of(context).platform.toString()),
      Expanded(
          child: PlatformARView(Theme.of(context).platform).build(
              context: context,
              arViewCreatedCallback: widget.onARViewCreated,
              planeDetectionConfig: widget.planeDetectionConfig)),
    ]);
  }
}
