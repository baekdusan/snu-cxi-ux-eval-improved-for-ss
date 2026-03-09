# Evaluate 버튼 무한 대기 버그 — 디버깅 인수인계 문서

작성일: 2026-02-25

---

## 1. 문제 현상

**재현 조건**
1. 스크린샷 업로드 → DR(Design Representation) 생성 성공
2. "Evaluate" 버튼 클릭
3. 아래 로그를 마지막으로 **무한 대기** (앱이 멈추고 아무 일도 일어나지 않음)

```
🔄 배치 1/2 처리 중...
```

**발생 파일**: `lib/screens/design_representation_screen.dart` → `_handleNavigateToUXEvaluation()`
**실제 막히는 위치**: 내부적으로 `lib/services/ux_evaluation_service.dart` → `_evaluateWithHeuristics()` 안의 Agent 3 시스템 프롬프트 로딩

---

## 2. 시도한 수정사항과 결과

### Fix 1: Gemini API 스트리밍 타임아웃 추가
**파일**: `lib/services/gemini_service.dart`
**내용**: `generateContentStream()` 호출에 4분 타임아웃 추가

```dart
await for (final chunk in responseStream.timeout(
  const Duration(minutes: 4),
  onTimeout: (sink) {
    print('⚠️ [GeminiService] 스트리밍 타임아웃 (4분 초과) — 강제 종료');
    sink.close();
  },
)) { ... }
```

**결과**: ❌ 해결 안 됨
**이유**: 막히는 지점이 Gemini API 호출 이전 단계(`rootBundle.loadString()`)였기 때문

---

### Fix 2: 배치 사이즈 축소 (5 → 3)
**파일**: `lib/services/ux_evaluation_service.dart`
**내용**: 휴리스틱 배치 처리 크기를 5에서 3으로 감소

```dart
for (int i = 0; i < allHeuristicItems.length; i += 3) {
  final batchEnd = (i + 3 < allHeuristicItems.length) ? i + 3 : allHeuristicItems.length;
```

**결과**: ❌ 해결 안 됨
**이유**: 동시 `rootBundle.loadString()` 호출 수를 줄였지만 근본 원인(Platform Channel 블로킹)은 그대로

---

### Fix 3 (원본): 배치 루프 전에 GeminiService 사전 초기화
**파일**: `lib/services/ux_evaluation_service.dart`
**내용**: 배치 루프 시작 전에 `_getAgentGeminiService()` 호출하여 Firebase 초기화를 먼저 완료

**결과**: ❌ 더 악화됨 — 막히는 위치가 더 앞으로 이동
**이유**: Agent 1, 2, 3이 동시에 `FirebaseAI.vertexAI()` + `generativeModel()` 호출 → 경쟁 상태 발생
**조치**: 이 수정사항 롤백

---

### Fix 3 (수정본): 배치 루프 전에 프롬프트 템플릿만 사전 로딩
**파일**: `lib/services/ux_evaluation_service.dart`
**내용**: 배치 루프 전에 `_loadUserPrompt()`, `jsonEncode(drData.toJson())`, `_getAgentGeminiService()` 를 순서대로 실행하여 배치 항목 내부에서 파일 I/O 제거

**결과**: ❌ 해결 안 됨 — 여전히 같은 위치에서 막힘
**이유**: Agent 1, 2, 3이 `Future.wait()`로 병렬 실행되어 여전히 동시에 `_getAgentGeminiService()` 호출 경쟁 발생

---

### 디버그 로그 추가로 정확한 위치 특정
**파일**: `lib/services/ux_evaluation_service.dart`
**내용**: `_loadUserPrompt()`, `_getAgentGeminiService()` 내부에 `🔍` 접두사 로그 추가

**결과**: ✅ 근본 원인 특정 성공

```
🔍 [Agent 2] 시스템 프롬프트 로딩 완료 (3444 글자)   ← Agent 2 완료
🔍 [Agent 2] GeminiService 초기화 시작               ← Agent 2가 Firebase 초기화 시작
🔍 [Agent 3] 시스템 프롬프트 로딩 시작: lib/prompts/Agent3_E_system.md
             ↑ 여기서 영원히 응답 없음 (행)
```

---

## 3. 근본 원인 (Root Cause)

**Flutter Platform Channel Deadlock**

```
[Agent 2] Firebase 초기화
  └─ FirebaseAI.vertexAI() + generativeModel()
       └─ Flutter Platform Channel 점유 (네이티브 통신)
            ↕ 블로킹 중
[Agent 3] rootBundle.loadString('Agent3_E_system.md')
  └─ Flutter Platform Channel 통해 응답 대기
       └─ 영원히 응답 못 받음 (deadlock)
```

**설명**:
- `Future.wait([agent1E, agent2E, agent3E])` 로 3개 에이전트가 병렬 실행됨
- Agent 2가 시스템 프롬프트 로딩 완료 후 `GeminiService()` 생성자를 호출
- `GeminiService()` 내부 `FirebaseAI.vertexAI().generativeModel()` 이 Flutter Platform Channel을 점유
- 같은 시점에 Agent 3이 `rootBundle.loadString()` 으로 Platform Channel을 통해 파일 요청
- Platform Channel이 Firebase에 의해 점유된 상태라 Agent 3의 응답이 돌아오지 않음 → **무한 대기**

**왜 MIA나 DR에서는 안 생기나?**
- MIA/DR 단계는 에이전트가 순차적으로 실행되거나, 이미 캐시된 후 병렬 실행되어 경쟁이 없음

---

## 4. 시도한 해결책과 현재 상태

### Fix 4: 병렬 실행 전 순차 사전 워밍업
**파일**: `lib/screens/design_representation_screen.dart`
**위치**: `_handleNavigateToUXEvaluation()` 내부, `Future.wait(futures)` 호출 직전 (약 1450번째 줄)
**아이디어**: `Future.wait()` 전에 순차적으로 모든 프롬프트 파일을 로딩하여 `rootBundle` 캐시를 채움
→ 이후 병렬 실행 시 캐시 히트가 되어 Platform Channel 접근 없음 → Deadlock 없음

**현재 코드 (컴파일 에러 있음)**:
```dart
final pathsToPreload = <String>[
  if (futureIndexMap.containsKey(1)) ...[
    'lib/prompts/Agent1_E_prompt.md',
    'lib/prompts/Agent1_E_system.md',
  ],
  if (futureIndexMap.containsKey(2)) ...[
    'lib/prompts/Agent2_E_prompt.md',
    'lib/prompts/Agent2_E_system.md',
  ],
  if (futureIndexMap.containsKey(3)) ...[
    'lib/prompts/Agent3_E_prompt.md',
    'lib/prompts/Agent3_E_system.md',
  ],
];
for (final path in pathsToPreload) {
  await rootBundle.loadString(path);
}
```

**에러**: Flutter FrontendCompiler null crash
```
Null check operator used on a null value
#0  FrontendCompiler.compileExpressionToJs (package:frontend_server/frontend_server.dart:1178)
ChromeProxyService: Failed to evaluate expression 'true'
```

**원인**: `collection-if + spread` 문법(`if (...) ...[...]`)이 Flutter 증분 컴파일러의 null pointer 버그 유발

---

## 5. 다음 작업자가 해야 할 것

### Step 1: 코드 수정 (5분 작업)

**파일**: `lib/screens/design_representation_screen.dart`
**위치**: 약 1455번째 줄 (위의 `pathsToPreload` 블록)

**현재 코드를 아래 코드로 교체**:

```dart
// 현재 (broken — collection-if spread):
final pathsToPreload = <String>[
  if (futureIndexMap.containsKey(1)) ...[
    'lib/prompts/Agent1_E_prompt.md',
    'lib/prompts/Agent1_E_system.md',
  ],
  if (futureIndexMap.containsKey(2)) ...[
    'lib/prompts/Agent2_E_prompt.md',
    'lib/prompts/Agent2_E_system.md',
  ],
  if (futureIndexMap.containsKey(3)) ...[
    'lib/prompts/Agent3_E_prompt.md',
    'lib/prompts/Agent3_E_system.md',
  ],
];
for (final path in pathsToPreload) {
  await rootBundle.loadString(path);
}

// 교체할 코드 (안전한 문법):
if (futureIndexMap.containsKey(1)) {
  await rootBundle.loadString('lib/prompts/Agent1_E_prompt.md');
  await rootBundle.loadString('lib/prompts/Agent1_E_system.md');
}
if (futureIndexMap.containsKey(2)) {
  await rootBundle.loadString('lib/prompts/Agent2_E_prompt.md');
  await rootBundle.loadString('lib/prompts/Agent2_E_system.md');
}
if (futureIndexMap.containsKey(3)) {
  await rootBundle.loadString('lib/prompts/Agent3_E_prompt.md');
  await rootBundle.loadString('lib/prompts/Agent3_E_system.md');
}
```

동작은 완전히 동일 — 단지 컴파일러 친화적인 문법으로 교체.

### Step 2: flutter clean 실행

```bash
flutter clean
flutter run
```

stale 빌드 캐시 제거 필수. `clean` 없이 실행하면 이전 크래시 상태가 남아있을 수 있음.

### Step 3: 검증

아래 로그가 모두 출력되면 수정 성공:
```
🔍 [Agent 1] 시스템 프롬프트 로딩 완료 (N 글자)
🔍 [Agent 2] 시스템 프롬프트 로딩 완료 (N 글자)
🔍 [Agent 3] 시스템 프롬프트 로딩 완료 (N 글자)   ← 이게 핵심
🔄 배치 1/2 처리 중...
🔄 배치 2/2 처리 중...
✅ [GeminiService] API 호출 성공 ...
```

Agent 3 시스템 프롬프트 로딩 완료 로그가 막히지 않고 출력되면 deadlock 해결된 것.

### Step 4: 디버그 로그 정리 (선택)

수정 검증 후 `lib/services/ux_evaluation_service.dart`에서 `🔍` 접두사 로그들 제거 가능.

---

## 6. 파일 위치 요약

| 파일 | 역할 | 수정 상태 |
|------|------|-----------|
| `lib/screens/design_representation_screen.dart` | Evaluate 진입점, 사전 워밍업 코드 | ⚠️ 컴파일 에러 있음 (Step 1 필요) |
| `lib/services/ux_evaluation_service.dart` | 에이전트별 평가 로직, 배치 처리 | ✅ 수정 완료 (디버그 로그 남아있음) |
| `lib/services/gemini_service.dart` | Gemini API 래퍼 | ✅ 타임아웃 추가 완료 |

---

## 7. 만약 Fix 4도 안 된다면

**대안 접근법**: `GeminiService`를 싱글톤으로 앱 시작 시 미리 초기화

```dart
// main.dart의 앱 시작 시점에:
await GeminiService.preWarm(); // Firebase 연결 미리 완료
```

또는 `FirebaseAI.vertexAI()` 초기화를 `compute()` isolate에서 실행하여 Platform Channel 경쟁 회피.

단, 이는 아키텍처 변경이 크므로 Fix 4(사전 워밍업) 검증 후에 고려.
