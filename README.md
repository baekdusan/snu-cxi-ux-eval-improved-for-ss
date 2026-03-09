# SNU CXI UX Evaluation - Improved

3개 AI 에이전트를 활용한 모바일 앱 UX 자동 평가 시스템

## 프로젝트 개요

모바일 앱 스크린샷만으로 UX 품질을 종합적으로 평가하는 AI 기반 시스템입니다. Google Gemini 2.5 Flash (Firebase Vertex AI)를 활용하여 3개의 전문 에이전트가 각자의 영역을 분석하고 평가합니다.

### 주요 특징

- **3개 전문 에이전트**: UX Writing, Error Prevention & Forgiveness, Visual Consistency
- **3단계 파이프라인**: MIA (Manual Inspection) → DR (Design Representation) → E (Evaluation)
- **병렬 처리**: 3개 에이전트 `Future.wait()`를 통한 동시 실행
- **2가지 모드**: MIA (수동 검사 + AI) / MIAx (순수 자동 분석)
- **AI 어시스턴트**: 3-Intent 시스템 (사용법 안내, 추론 설명, 피드백 반영)
- **피드백 시스템**: 사용자 피드백 기반 이슈 개선 및 재평가
- **데이터 영속성**: 분석 결과 저장/불러오기
- **중요도 필터링**: 기준별 점수화를 통한 이슈 우선순위 분류
- **Flutter 웹 앱**: 크로스 플랫폼 지원

## 시스템 아키텍처

```
스크린샷 업로드
    ↓
┌─────────────────────────────────────────────┐
│  Stage 1: MIA (Manual Inspection)           │
│  - 사용자가 평가 맥락·사용 맥락 작성            │
│  - MIAx 모드: 이 단계 생략                     │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│  Stage 2: DR (Design Representation)        │
│  - 3개 에이전트 병렬 실행                       │
│    • Agent 1: 텍스트 요소 추출                  │
│    • Agent 2: 오류 예방·용서 패턴 추출           │
│    • Agent 3: 시각적 일관성 요소 추출             │
│  - MIA 모드: MIA 맥락이 프롬프트에 포함           │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│  Stage 3: E (Evaluation)                    │
│  - 3개 에이전트 병렬 실행                       │
│    • Agent 1 E: UX Writing 이슈 평가           │
│    • Agent 2 E: Error Prevention 이슈 평가     │
│    • Agent 3 E: Visual Consistency 이슈 평가   │
│  - 배치 처리: 휴리스틱 5개씩 병렬 API 호출       │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│  AI 어시스턴트 & 피드백                         │
│  - Intent 1: 사용법 질문 (텍스트 전용, 빠른 응답)  │
│  - Intent 2: AI 추론 설명 (이미지 포함)           │
│  - Intent 3: 피드백 → 이슈 수정 (FeedbackService) │
└─────────────────────────────────────────────┘
    ↓
UX 이슈 리포트 생성 & 다운로드
```

## 3개 에이전트 상세

### Agent 1: UX Writing

- **DR**: 모든 텍스트 요소 추출 (`id`, `text`, `component`)
- **E**: UX Writing Heuristics 적용
  - 용어 및 문구 사용 (명확성, 간결성, 이해 가능성)
  - Tone & Manner (사용자 중심, 긍정적 표현)
- **이슈 모델**: `UXWritingIssue` — `textElementId`, `text` 포함

### Agent 2: Error Prevention & Forgiveness

- **DR**: 입력, 확인, 오류/경고/피드백, 복구, 네비게이션/이탈 패턴 추출
- **E**: Error Prevention Heuristics 적용
  - 입력 유효성 검사, 오류 예방 패턴
  - 용서(Forgiveness) 설계 원칙
- **이슈 모델**: `ErrorPreventionIssue` — `elementId`, `elementType` 포함

### Agent 3: Visual Consistency

- **DR**: 스크린 레벨 + 요소 레벨 시각적 속성 추출
- **E**: Visual Consistency Heuristics 적용
  - 레이아웃, 형태, 색상 일관성
  - 스크린 레벨 vs 요소 레벨 위반 구분
- **이슈 모델**: `VisualConsistencyIssue` — `violationLevel`, `violatedAttribute`, `elementDescription` 포함

## 기술 스택

| 분류 | 기술 |
|------|------|
| Frontend | Flutter (Web) |
| AI Model | Google Gemini 2.5 Flash |
| AI Platform | Firebase Vertex AI |
| 인증 | Firebase Anonymous Auth |
| 언어 | Dart |
| 아키텍처 | Multi-Agent System + Parallel Processing |

## 디렉토리 구조

```
lib/
├── main.dart                              # 앱 진입점, 이미지 업로드, 모드 분기
├── firebase_options.dart                  # Firebase 설정
├── constants/
│   └── MIA_prompt.dart                    # MIA 분석 프롬프트 생성
├── models/
│   ├── DR_result.dart                     # DRResult, DRData, TextElement
│   ├── ux_issue_result.dart               # UXIssue (abstract), 3개 서브클래스, ImportanceEvaluation
│   ├── MIA_result.dart                    # MIA 분석 결과
│   ├── saved_MIA_result.dart              # 영속화 래퍼
│   ├── evaluation_context.dart            # 평가 범위 메타데이터
│   ├── usage_context.dart                 # 앱 사용 맥락
│   └── screen_purpose.dart                # 스크린별 목적
├── services/
│   ├── gemini_service.dart                # Gemini API 클라이언트 (JSON 모드, temperature=0)
│   ├── dr_generation_service.dart         # Stage 2: 3개 에이전트 DR 생성
│   ├── ux_evaluation_service.dart         # Stage 3: 3개 에이전트 E 평가
│   ├── analysis_service.dart              # Stage 1: MIA 분석
│   ├── ai_assistant_service.dart          # 3-Intent AI 어시스턴트
│   ├── feedback_service.dart              # 사용자 피드백 기반 이슈 개선
│   ├── data_persistence_service.dart      # 분석 결과 저장/불러오기
│   └── debug_logger.dart                  # 디버그 로깅
├── screens/
│   ├── design_representation_screen.dart  # DR 결과 화면 + E 실행 트리거
│   └── ux_evaluation_screen.dart          # E 결과 화면 + 피드백
├── prompts/                               # AI 프롬프트 (마크다운)
│   ├── Agent1_DR_prompt.md                # Agent 1 DR (MIAx용)
│   ├── Agent1_DR_MIA_prompt.md            # Agent 1 DR (MIA용)
│   ├── Agent1_E_prompt.md                 # Agent 1 E 사용자 프롬프트
│   ├── Agent1_E_system.md                 # Agent 1 E 시스템 프롬프트
│   ├── Agent2_DR_prompt.md                # Agent 2 DR (MIAx용)
│   ├── Agent2_DR_MIA_prompt.md            # Agent 2 DR (MIA용)
│   ├── Agent2_E_prompt.md                 # Agent 2 E 사용자 프롬프트
│   ├── Agent2_E_system.md                 # Agent 2 E 시스템 프롬프트
│   ├── Agent3_DR_prompt.md                # Agent 3 DR (MIAx용)
│   ├── Agent3_DR_MIA_prompt.md            # Agent 3 DR (MIA용)
│   ├── Agent3_E_prompt.md                 # Agent 3 E 사용자 프롬프트
│   ├── Agent3_E_system.md                 # Agent 3 E 시스템 프롬프트
│   ├── AIAssistant_system.md              # AI 어시스턴트 시스템 프롬프트
│   ├── AIAssistant_user_dr.md             # AI 어시스턴트 DR 화면용
│   ├── AIAssistant_user_eval.md           # AI 어시스턴트 E 화면용
│   ├── Feedback_system.md                 # 피드백 시스템 프롬프트
│   └── Feedback_user.md                   # 피드백 사용자 프롬프트
├── references/                            # 휴리스틱 레퍼런스
│   ├── Agent1_Text_heuristics.md          # UX Writing 휴리스틱 (마크다운)
│   ├── agent1_text_heuristics.dart        # UX Writing 휴리스틱 (Dart 상수)
│   ├── agent2_error_heuristics.dart       # Error Prevention 휴리스틱
│   └── agent3_visual_heuristics.dart      # Visual Consistency 휴리스틱
└── utils/
    └── download_helper.dart               # JSON 다운로드 유틸리티
```

## 데이터 모델

### 이슈 클래스 구조 (상속)

```dart
abstract class UXIssue {
  final String issueId;
  final String screenId;
  final String problemDescription;
  final String heuristicViolated;
  final String heuristicCategory;
  final String reasoning;
  final String recommendation;
}

class UXWritingIssue extends UXIssue {         // Agent 1
  final int textElementId;
  final String text;
}

class ErrorPreventionIssue extends UXIssue {   // Agent 2
  final int? elementId;
  final String? elementType;
}

class VisualConsistencyIssue extends UXIssue {  // Agent 3
  final String violationLevel;    // "screen" | "element"
  final int? elementId;
  final String? elementDescription;
  final String violatedAttribute; // "layout" | "shape" | "color" 등
}
```

### 중요도 필터 모델

```dart
class ImportanceEvaluation {
  final String issueId;
  final Map<String, CriteriaResult> criteriaEvaluation;
  final int totalScore;              // 9점 이상: important
  final List<String> matchedCriteria;
}
```

### AgentType Enum

```dart
enum AgentType {
  uxWriting,         // Agent 1
  errorPrevention,   // Agent 2
  visualConsistency, // Agent 3
}
```

## 설치 및 실행

### 사전 요구사항

- Flutter SDK (Dart 3.10.4 이상)
- Google Cloud Project + Firebase 프로젝트
- Vertex AI API 활성화

### 환경 설정

1. 저장소 클론
```bash
git clone https://github.com/LET-Lab/snu-cxi-ux-eval-improved.git
cd snu-cxi-ux-eval-improved
```

2. 의존성 설치
```bash
flutter pub get
```

3. 환경 변수 설정
```bash
# .env 파일 생성 (Firebase 설정은 firebase_options.dart에 자동 생성)
```

4. Firebase 설정
- `flutterfire configure` 실행 또는 `firebase_options.dart` 수동 설정
- Vertex AI API 활성화

### 실행

```bash
flutter run -d chrome
```

## 주요 기능

### MIA 모드 (Manual Inspection with AI)

1. 사용자가 평가 범위, 특이사항 입력
2. 스크린샷 업로드 → Stage 1 MIA 분석 (사용 맥락, 스크린 목적 생성)
3. MIA 맥락이 DR 프롬프트에 포함되어 맥락 인지 분석 수행
4. 3개 에이전트 DR → E 병렬 실행

### MIAx 모드 (자동 분석)

1. 스크린샷만 업로드 (Stage 1 생략)
2. 맥락 없이 순수 AI 기반 DR → E 실행
3. 더 빠르지만 맥락 정보 없음

### AI 어시스턴트 (3-Intent 시스템)

DR 화면과 E 화면 모두에서 사용 가능한 채팅 인터페이스:

| Intent | 설명 | 처리 방식 |
|--------|------|----------|
| `system_usage` | 사용법 질문 | 텍스트 전용, 즉시 응답 (~1-2초) |
| `explain_reasoning` | AI 추론 설명 요청 | 이미지 포함 전체 처리 |
| `feedback` | 이슈 수정 피드백 | FeedbackService 호출, 이슈 갱신 |

- Stage 1: 텍스트 전용 의도 분류 (빠른 분류)
- Stage 2: Intent에 따라 전체 처리 (Intent 2, 3만 이미지 포함)

### 피드백 시스템

- 사용자가 이슈를 선택하고 코멘트 작성
- FeedbackService가 현재 이슈 + DR 데이터 + 사용자 코멘트를 종합
- Gemini가 수정된 이슈 목록 + 변경 요약 반환
- UI에서 실시간 이슈 목록 갱신

### 데이터 영속성

- 분석 결과를 JSON 파일로 저장/불러오기
- 파일명 패턴: `A1_*_DR*.json`, `A2_*_E*.json` 등
- JSON 구조로부터 에이전트 및 단계 자동 감지
- 이전 분석 이어서 작업 가능

### 결과 다운로드

- JSON 형식으로 전체 분석 결과 다운로드
- 에이전트별 DR 결과 + E 이슈 포함

## 핵심 로직

### 병렬 처리

```dart
// Stage 2: 3개 에이전트 DR 병렬 실행
final drResults = await Future.wait([
  drGenerationService.generateAgent1DR(base64Images, miaResult),
  drGenerationService.generateAgent2DR(base64Images, miaResult),
  drGenerationService.generateAgent3DR(base64Images, miaResult),
]);

// Stage 3: 3개 에이전트 E 병렬 실행
final evalResults = await Future.wait([
  uxEvaluationService.evaluateUXWritingIssues(...),
  uxEvaluationService.evaluateErrorPreventionIssues(...),
  uxEvaluationService.evaluateVisualConsistencyIssues(...),
]);
```

### 배치 기반 휴리스틱 평가 (E 단계)

- 각 에이전트의 휴리스틱을 5개씩 배치로 분할
- 배치별로 독립 Gemini API 호출 (병렬)
- API 호출 횟수 최적화 및 응답 시간 단축

### Gemini 배열 응답 처리

Gemini JSON 모드가 간혹 배열로 응답하는 경우를 자동 처리:

```
정상:     {"screens": [...]}
비정상1:  [{"screens": [...]}]     → 첫 번째 요소 추출
비정상2:  [{screen_id: ...}, ...]  → {"screens": [...]} 로 래핑
```

### 503 에러 자동 재시도

DR 생성 시 Vertex AI 503 에러 발생 시 최대 3회 자동 재시도 (대기 시간 증가)

### Per-Agent GeminiService 캐싱

```dart
// 에이전트별 독립 GeminiService 인스턴스 (시스템 프롬프트 포함)
// Lazy 초기화 + 캐싱으로 중복 초기화 방지
GeminiService? _agent1GeminiService;
GeminiService? _agent2GeminiService;
GeminiService? _agent3GeminiService;
```

### MIA 맥락 프롬프트 통합

MIA 모드 활성화 시 DR 프롬프트에 MIA 맥락 자동 포함:
- 대상 사용자 프로필
- 사용 환경 및 목표
- 태스크 시나리오
- 스크린별 목적
- 평가 범위

에이전트별 MIA 전용 프롬프트 파일 사용 (`Agent*_DR_MIA_prompt.md`)

## 의존성

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  firebase_core: ^4.3.0          # Firebase 초기화
  firebase_auth: ^6.1.3          # 익명 인증
  firebase_ai: ^3.6.1            # Vertex AI (Gemini)
  image_picker: ^1.1.2           # 이미지 선택
  file_picker: ^8.1.6            # 파일 선택
  http: ^1.2.0                   # HTTP 요청
  flutter_dotenv: ^5.1.0         # 환경 변수
```

## 트러블슈팅

### Gemini API 빈 응답

- **원인**: 프롬프트에 대화형 지시사항 포함 ("Wait for input" 등)
- **해결**: JSON-only 출력 강제, 대화형 지시 제거

### JSON 파싱 실패

- **원인**: Gemini가 배열 형식으로 응답
- **해결**: `_extractJson()` 메서드에서 3가지 패턴 자동 처리

### 503 Service Unavailable

- **원인**: Vertex AI 서버 과부하
- **해결**: 자동 재시도 로직 (최대 3회, 대기 시간 증가)

### 할당량 초과 (Quota Exceeded)

- **원인**: 동시 API 호출 과다
- **해결**: 자동 재시도 로직 (5s, 10s, 15s 대기)

## 개발 가이드

### 새로운 휴리스틱 추가

1. `lib/references/` 디렉토리에 휴리스틱 파일 추가 (`.dart` 또는 `.md`)
2. 해당 에이전트의 E 서비스에서 로드 메서드 추가
3. E 프롬프트에 레퍼런스 섹션 추가

### 새로운 에이전트 추가

1. `lib/models/ux_issue_result.dart`에 `UXIssue` 서브클래스 추가
2. `lib/services/dr_generation_service.dart`에 DR 메서드 추가
3. `lib/services/ux_evaluation_service.dart`에 E 메서드 추가
4. `lib/prompts/`에 프롬프트 파일 작성 (DR, DR_MIA, E_system, E_prompt)
5. `lib/references/`에 휴리스틱 파일 작성
6. `pubspec.yaml`의 assets에 새 프롬프트 파일 등록
7. `main.dart` 및 화면 파일에서 병렬 처리 및 UI 로직 추가

## 라이선스

이 프로젝트는 연구 목적으로 개발되었습니다.

## 문의

프로젝트 관련 문의: SNU LET Lab ([Contact](https://www.let.snu.ac.kr/))
