# AR Marker

<center><video src="https://github.com/user-attachments/assets/fe2f6330-b16a-40ee-96cb-4525eea8fe82" width="200" autoplay loop muted>Your browser does not support the video tag.</video></center>

<details>
<summary><strong>🇰🇷 Korean (한국어) - Click to expand</strong></summary>

## AR Marker

이미지 마커를 인식하고 그 위에 3D GLTF/GLB 모델을 증강현실로 표시하는 Flutter 앱

## 개요

- 카메라로 미리 정의된 마커 이미지를 인식하고, 감지된 각 마커 위에 대응하는 3D 모델을 실시간으로 렌더링
- 마커가 카메라 시야에서 벗어나면 모델 제거
- 5초 동안 마커가 감지되지 않으면 AR 세션을 자동으로 재시작하여 재인식 신뢰성을 높임

## 주요 기능

- **이미지 마커 트래킹** — 최대 6개의 고유 마커를 동시에 인식
- **3D 모델 렌더링** — 인식된 마커 위에 `.glb` 모델 배치
- **연속 트래킹** — 마커가 이동해도 모델이 따라다님
- **자동 제거** — 마커가 2초 이상 감지되지 않으면 모델 제거
- **세션 자동 리셋** — 5초간 아무 마커도 없으면 AR 세션 재시작하여 재인식 성능 향상
- **적응형 스케일** — 마커의 실제 물리 크기를 기준으로 모델 크기를 자동 계산
- **크로스플랫폼** — Android(ARCore) 및 iOS(ARKit) 모두 지원

## 기술 스택

| 구성 요소 | 기술 |
|---|---|
| 프레임워크 | Flutter 3 / Dart |
| AR 엔진 | `ar_flutter_plugin_plus` |
| 3D 포맷 | GLTF / GLB |
| 수학 라이브러리 | `vector_math` |

## 프로젝트 구조

```
lib/
├── main.dart        # 앱 진입점
├── ar_screen.dart   # AR 핵심 로직: 마커 감지, 모델 배치, 세션 관리
└── ar_view.dart     # 플랫폼 추상화 레이어 (Android / iOS 네이티브 뷰)

assets/
├── marker/          # 마커 이미지
└── model/           # 3D 모델

remove_texcoord2.py  # GLTF 파일에서 미지원 TEXCOORD_2+ 속성을 제거하는 유틸리티 스크립트
```

## 시작하기

### 사전 요구사항

- Flutter SDK `^3.5.0`
- Xcode(iOS용) 또는 Android Studio(Android용)
- ARKit 또는 ARCore를 지원하는 실제 기기 (시뮬레이터에서는 AR 미지원)

### 설치 및 실행

```bash
flutter pub get
flutter run
```

### 마커 및 모델 추가

1. 마커 이미지를 `assets/marker/[마커이름].png`에 저장
2. 대응하는 3D 모델을 `assets/model/[마커이름].glb`에 저장
3. 앱을 다시 빌드

GLTF 모델이 렌더링되지 않는 경우, 포함된 유틸리티로 미지원 텍스처 좌표 속성 제거

```bash
python3 remove_texcoord2.py assets/model/[마커이름].glb
```

## 동작 원리

1. 앱 시작 시 연속 이미지 트래킹(업데이트 간격: 200ms)이 활성화된 AR 세션 초기화
2. 마커가 감지되면 마커 이름과 월드 좌표계 내 위치·방향을 담은 4×4 변환 행렬이 `_handleImageDetected`로 전달
3. 해당하는 GLB 모델을 로드하여 마커 위치에 배치. 모델은 마커 면 위에 수직으로 서도록 X축 기준 −90° 회전
4. 500ms마다 타이머가 실행되어 각 마커의 마지막 감지 시각을 확인. 2초 이상 감지되지 않은 마커의 모델은 제거
5. 5초간 마커가 하나도 감지되지 않으면 AR 세션 전체를 리셋하여 추적 서브시스템이 환경을 처음부터 다시 스캔

## 라이선스

이 프로젝트는 [ISC License](LICENSE)를 따릅니다.

</details>

---

A Flutter application that detects image markers and overlays 3D GLTF/GLB models on top of them using augmented reality.

## Overview

AR Marker uses the device camera to recognize up to 6 predefined image markers and renders a corresponding 3D model on each detected marker in real time. When a marker leaves the camera's field of view, the model is automatically removed. If no markers are detected for 5 seconds, the AR session resets itself to improve re-detection reliability.

## Features

- **Image marker tracking** — recognizes up to 6 distinct markers simultaneously
- **3D model rendering** — places a `.glb` model on each detected marker
- **Continuous tracking** — models follow the marker as it moves in the frame
- **Auto-cleanup** — removes models when a marker is lost for more than 2 seconds
- **Session auto-reset** — restarts the AR session after 5 seconds of inactivity to improve re-detection
- **Adaptive scale** — calculates model scale based on the physical marker width so the model always appears at a consistent size relative to the marker
- **Cross-platform** — supports both Android (ARCore) and iOS (ARKit)

## Tech Stack

| Component | Technology |
|---|---|
| Framework | Flutter 3 / Dart |
| AR engine | [`ar_flutter_plugin_plus`](https://github.com/FranzGraaf/ar_flutter_plugin_plus) |
| 3D format | GLTF / GLB |
| Math | `vector_math` |

## Project Structure

```
lib/
├── main.dart        # App entry point
├── ar_screen.dart   # Core AR logic: marker detection, model placement, session management
└── ar_view.dart     # Platform abstraction layer (Android / iOS native view)

assets/
├── marker/          # Marker images (1.png – 6.png)
└── model/           # 3D models (1.glb – 6.glb)

remove_texcoord2.py  # Utility script to strip unsupported TEXCOORD_2+ attributes from GLTF files
```

## Getting Started

### Prerequisites

- Flutter SDK `^3.5.0`
- Xcode (for iOS) or Android Studio (for Android)
- A physical device with ARKit or ARCore support (AR does not work on simulators)

### Installation

```bash
flutter pub get
flutter run
```

### Adding Markers and Models

1. Place marker images as `assets/marker/1.png` through `assets/marker/6.png`.
2. Place corresponding 3D models as `assets/model/1.glb` through `assets/model/6.glb`.
3. Rebuild the app.

If a GLTF model fails to render, run the included utility to strip unsupported texture coordinate attributes:

```bash
python3 remove_texcoord2.py assets/model/your_model.gltf
```

## How It Works

1. On launch the app initializes an AR session with continuous image tracking enabled (update interval: 200 ms).
2. When a marker is detected, `_handleImageDetected` is called with the marker name and a 4×4 transformation matrix representing its position and orientation in world space.
3. The corresponding GLB model is loaded and placed at the marker location. The model is rotated −90° around the X axis so it stands upright on the marker surface.
4. A timer fires every 500 ms to check when each marker was last seen. Any marker not detected within 2 seconds has its model removed.
5. If no markers have been detected for 5 seconds, the entire AR session is reset to allow the tracking subsystem to re-scan the environment from scratch.

## License

This project is licensed under the [ISC License](LICENSE).
