# SNU CXI UX Evaluation - Claude 작업 노트

## 프로젝트 개요

4개 에이전트를 사용한 모바일 앱 UX 평가 시스템:
- **Agent 1 (UX Writing)**: 텍스트 요소 추출 및 UX Writing 이슈 평가
- **Agent 2 (Information Architecture)**: IA 메뉴 구조 추출 및 평가
- **Agent 3 (Icon Representativeness)**: 아이콘 분석 및 대표성 평가
- **Agent 4 (Task Flow)**: Task Flow 분석 및 적합성 평가

모든 에이전트는 DR (Design Representation) 단계와 E (Evaluation) 단계로 구성됩니다.

---

## 최근 작업 내역

### ✅ 완료된 작업 - 2026-01-26 (세션 4)

#### 1. Agent 1 출력 형식 문제 해결 ✅
**파일**: `lib/models/ux_issue_result.dart`
- **문제**: Agent 1의 이슈가 Agent 3 (Icon) 형식으로 출력되어 `icon_id`, `icon_function`, `component_id`, `importance_score` 등 불필요한 필드 포함
- **원인**: `IconUXIssue.toJson()` 메서드가 모든 에이전트에 대해 Agent 3 형식으로만 출력
- **해결**:
  - `AgentType` enum 추가 (uxWriting, ia, icon, taskFlow)
  - `IconUXIssue`에 `agentType` 필드 추가
  - `toJson()` 메서드를 Agent 타입별로 다른 형식 출력하도록 수정:
    - **Agent 1**: `problems` 키 사용, `id`, `text` 필드 포함, `importance_score` 제외
    - **Agent 2**: `ux_issues` 키, `ia_structure.id`, `importance_score` 포함
    - **Agent 3**: `ux_issues` 키, `icon_id`, `icon_function`, `component_id`, `importance_score` 포함
    - **Agent 4**: `ux_issues` 키, `user_activity`, `interaction_step`, `interaction_description`, `importance_score` 포함
  - `UXIssueResult.toJson()`도 Agent 1일 때 `problems` 키 사용하도록 수정

#### 2. Gemini 응답 로깅 강화 ✅
**파일**: `lib/services/ux_evaluation_service.dart`
- Agent 1 E 메서드에 상세 로깅 추가:
  - Gemini 원본 응답 (처음 500자)
  - 추출된 JSON (처음 500자)
  - JSON 최상위 키 출력 (`problems` vs `ux_issues` 확인)
- 프롬프트 로딩 로깅 추가:
  - `_loadUXWritingEvaluationPrompt()`: 프롬프트 파일 로드 성공 여부 및 미리보기
  - `_loadUXWritingHeuristics()`: 휴리스틱 파일 로드 성공 여부 및 미리보기
- **결과**: Gemini가 올바른 프롬프트를 받고 있는지, 올바른 JSON 키로 응답하는지 실시간 확인 가능

#### 3. UX Evaluation 상세보기 UI 개선 ✅
**파일**: `lib/screens/ux_evaluation_screen.dart`
- **문제**: 모든 에이전트의 이슈가 Agent 3 (Icon) 형식으로만 표시됨 (중요도, 아이콘 정보 등)
- **해결**:
  - `_buildUXIssueCard()` 메서드를 Agent 타입별로 분리:
    - `_buildUXWritingIssueCard()` - Agent 1 전용 (텍스트 요소 ID, 원본 텍스트 표시, 중요도 제외)
    - `_buildIAIssueCard()` - Agent 2 전용 (IA 구조 ID, 중요도 표시)
    - `_buildIconIssueCard()` - Agent 3 전용 (아이콘 정보, 중요도 표시)
    - `_buildTaskFlowIssueCard()` - Agent 4 전용 (Task Flow 정보, 중요도 표시)
  - `_buildUXIssuesList()` 메서드 수정:
    - Agent 1은 `importance_score`가 없으므로 정렬하지 않음
    - Agent 2, 3, 4는 중요도 기준 정렬 (높은 순)
- **결과**: 각 에이전트별로 적합한 정보만 표시되어 UI가 깔끔해짐

---

### ✅ 완료된 작업 - 2026-01-26 (세션 3)

#### 1. Agent 3 DR 프롬프트 수정 ✅
**파일**: `lib/prompts/Agent3_DR_prompt.md`
- **문제**: Gemini API가 Agent 3 Icon 분석에서 일부 스크린샷만 처리하고 멈춤 (5/13 screens)
- **원인**: 프롬프트에 대화형 지시사항 포함 ("Wait for input", "If no files are uploaded, respond with...")
- **해결**:
  - "Wait for Input" 섹션 완전 제거
  - Step 번호 재정렬 (Step 2 → Step 2, Step 3 → Step 3, Step 4 → Step 3)
  - JSON-only 출력 강제 지시사항은 기존 유지
- **결과**: Agent 3이 모든 13개 스크린샷 정상 분석

#### 2. 코드 정리 및 주석 추가 ✅
모든 주요 파일에 상세한 주석을 추가하여 가독성 향상:

**파일**: `lib/services/icon_analysis_service.dart`
- 클래스 문서 대폭 확장:
  - 4개 에이전트 DR 설명
  - 데이터 흐름 (5단계)
  - 에러 핸들링 전략
- Gemini 배열 응답 처리 로직에 상세 주석:
  ```dart
  // ========================================
  // Gemini 배열 응답 처리 (중요!)
  // ========================================
  // Gemini JSON 모드가 간혹 배열로 응답하는 경우 처리:
  // - 정상: {"screens": [...]}
  // - 비정상1: [{"screens": [...]}]
  // - 비정상2: [{screen_id: ...}, ...]
  ```
- `_extractJson()` 메서드 주석 강화 (지원하는 5가지 패턴 설명)

**파일**: `lib/services/ux_evaluation_service.dart`
- 클래스 문서 대폭 확장:
  - 4개 에이전트 E 설명
  - 각 에이전트별 입력/출력/휴리스틱 명시
  - 데이터 흐름 (5단계)
  - 파일 의존성 명시

**파일**: `lib/main.dart`
- **MIAx 모드** 병렬 처리 섹션에 상세 주석:
  ```dart
  // ========================================
  // Step 3: DR 분석 수행 - 4개 에이전트 병렬 실행
  // ========================================
  // Future.wait()를 사용하여 4개 에이전트를 동시에 실행합니다.
  // - Agent 1 (UXWriting): 텍스트 요소 추출
  // - Agent 2 (IA): 메뉴 구조 추출
  // - Agent 3 (Icon): 아이콘 분석
  // - Agent 4 (Task Flow): Task Flow 분석
  //
  // 💡 MIAx 모드: Heuristic context 없이 DR만 수행
  //    (analysisData: null 전달)
  ```
- **MIA 모드** 병렬 처리 섹션에 상세 주석:
  - Agent 3에만 Heuristic context 전달되는 이유 설명
  - MIA(Manual Inspection with AI)의 동작 방식 설명

**파일**: `lib/screens/design_representation_screen.dart`
- `_handleNavigateToUXEvaluation()` 메서드에 상세 주석:
  - 처리 흐름 4단계 설명
  - 4개 에이전트 E 병렬 실행 로직 설명
  - MIA vs MIAx 모드 차이 명시
  ```dart
  /// UX Evaluation 화면으로 이동 (E 단계 수행)
  ///
  /// 4개 에이전트의 DR 결과를 바탕으로 E (Evaluation) 단계를 병렬 실행하여
  /// UX 이슈를 발견하고 Evaluation 화면으로 이동합니다.
  ///
  /// 처리 흐름:
  /// 1. 4개 에이전트 DR 결과 검증 (필수)
  /// 2. 로딩 다이얼로그 표시
  /// 3. 4개 에이전트 E 병렬 실행 (Future.wait)
  /// 4. UX Evaluation 화면으로 이동 (DR 결과 + E 결과 전달)
  ```

**파일**: `lib/screens/ux_evaluation_screen.dart`
- `_getIssuesForScreen()` 메서드에 상세 주석:
  - 파라미터 설명 (legacy vs 권장 방식)
  - Agent 4의 two-phase evaluation 특수 처리 설명
  - screenId 필터링 로직 설명

#### 3. README.md 전면 재작성 ✅
**파일**: `README.md`
- 프로젝트 개요 및 주요 특징
- 시스템 아키텍처 다이어그램 (3단계: MIA → DR → E)
- 4개 에이전트 상세 설명 (DR + E 역할)
- 기술 스택 및 디렉토리 구조
- 설치 및 실행 가이드
- 주요 기능 (MIA 모드, MIAx 모드, 병렬 처리)
- 핵심 로직 설명 (배열 응답 처리, Two-Phase Evaluation)
- 트러블슈팅 가이드
- 개발 가이드 (새로운 Heuristic/에이전트 추가 방법)
- 성능 최적화 설명

---

### ✅ 완료된 작업 - 2026-01-25 (세션 1 + 세션 2)

#### 1. 데이터 모델 확장 ✅
**파일**: `lib/models/icon_analysis_result.dart`
- `ScreenIconData` 클래스에 Agent 2, 4 필드 추가:
  - `IAStructure? iaStructure` (Agent 2)
  - `TaskFlowInfo? taskFlowInfo` (Agent 4)
- 새로운 모델 클래스 추가:
  - `IAStructure` - IA 메뉴 구조 (재귀적 트리 구조)
  - `TaskFlowInfo` - Task Flow 정보
  - `InteractionSequence` - 상호작용 시퀀스
  - `NavigationalInteraction` - 네비게이션 상호작용

**파일**: `lib/models/ux_issue_result.dart`
- `IconUXIssue` 클래스에 Agent 2, 4 필드 추가:
  - `iaStructureId` (Agent 2)
  - `userActivity`, `interactionStep`, `interactionDescription` (Agent 4)
- 새로운 factory 메서드 추가:
  - `IconUXIssue.fromIAJson()` (Agent 2 이슈용)
  - `IconUXIssue.fromTaskFlowJson()` (Agent 4 이슈용)
  - `UXIssueResult.fromIAJson()` (Agent 2 결과용)
- 새로운 클래스 추가:
  - `TaskFlowEvaluationResult` - Agent 4의 2단계 평가 결과 (flow-level + interaction-level)

#### 2. 서비스 레이어 구현
**파일**: `lib/services/icon_analysis_service.dart`
- Agent 2 DR 메서드 추가:
  - `analyzeIAStructureAllAtOnce()` - IA 구조 일괄 분석
  - `_loadAgent2DRPrompt()` - Agent 2 DR 프롬프트 로드
- Agent 4 DR 메서드 추가:
  - `analyzeTaskFlowAllAtOnce()` - Task Flow 일괄 분석
  - `_loadAgent4DRPrompt()` - Agent 4 DR 프롬프트 로드

**파일**: `lib/services/ux_evaluation_service.dart`
- Agent 2 E 메서드 추가:
  - `evaluateIAIssues()` - IA 이슈 평가
  - `_buildIAEvaluationPrompt()` - Agent 2 E 프롬프트 생성
  - `_loadAgent2EPrompt()`, `_loadIAHeuristics()`, `_loadIATerms()` - 참조 파일 로드
- Agent 4 E 메서드 추가:
  - `evaluateTaskFlowIssues()` - Task Flow 이슈 평가 (2단계: flow-level + interaction-level)
  - `_buildTaskFlowEvaluationPrompt()` - Agent 4 E 프롬프트 생성
  - `_loadAgent4EPrompt()`, `_loadTaskFlowHeuristics()`, `_loadTaskFlowTerms()` - 참조 파일 로드

#### 3. 병렬 처리 구현
**파일**: `lib/main.dart`
- **MIAx 모드** (lines 251-273): 4개 에이전트 병렬 실행
  - Agent 1 (UXWriting) + Agent 2 (IA) + Agent 3 (Icon) + Agent 4 (Task Flow)
  - `Future.wait()`로 동시 실행
  - 4개 결과를 `DesignRepresentationScreen`에 전달

- **MIA 모드** (lines 1001-1035): 4개 에이전트 병렬 실행
  - Agent 3에만 Heuristic context 전달
  - 나머지는 동일한 병렬 처리

#### 4. 화면 통합 ✅
**파일**: `lib/screens/design_representation_screen.dart`
- 생성자에 `agent2Result`, `agent4Result` 파라미터 추가
- 상태 변수 추가: `_agent2Data`, `_agent4Data`
- `initState()`에서 초기화
- `_handleNavigateToUXEvaluation()` 업데이트:
  - 4개 에이전트 검증 (null 체크)
  - E 단계에서 4개 에이전트 병렬 실행
  - `UXEvaluationScreen`에 4개 결과 전달
- `_buildEvaluationContent()` 메서드 완성:
  - moduleIndex 1 (Agent 2 - IA): IA 메뉴 구조 표시 구현
  - moduleIndex 3 (Agent 4 - Task Flow): Task Flow 정보 표시 구현
- `_getScreenDataByIndex()` 메서드 업데이트:
  - `agentIndex` 파라미터 (1/2/3/4) 지원 추가
  - switch문으로 각 에이전트 데이터 선택
- Detail Modal 메서드 추가:
  - `_showIAStructureDetailModal()` - IA 트리 구조 표시
  - `_buildIATreeView()` - 재귀적 트리 뷰 렌더링
  - `_showTaskFlowDetailModal()` - Task Flow 상세 표시

**파일**: `lib/screens/ux_evaluation_screen.dart`
- 생성자에 `agent2Result`, `agent4Result`, `agent2IssueResult`, `agent4IssueResult` 파라미터 추가
- 상태 변수 추가: `_agent2IssueResult`, `_agent4IssueResult`
- `initState()`에서 초기화
- `_getIssuesForScreen()` 메서드 업데이트:
  - `agentIndex` 파라미터 (1/2/3/4) 지원 추가
  - Agent 4의 two-phase 이슈 (`getAllIssues()`) 처리

#### 5. 디버그 로깅 시스템 ✅
**파일**: `lib/services/debug_logger.dart` (신규 생성)
- `DebugLogger` 클래스 구현:
  - `logMIAInput()` - Stage 1 (MIA) 입력 로깅
  - `logDRInput()` - Stage 2 (DR) 입력 로깅 (에이전트별)
  - `logEInput()` - Stage 3 (E) 입력 로깅 (에이전트별)
- 로그 포맷: 스크린샷 정보, 프롬프트 미리보기, 레퍼런스 파일, 중간 결과

---

## 🔴 남은 작업 (우선순위 순)

### 1. End-to-End 테스팅 (우선순위: 최고)
실제 스크린샷으로 테스트:

**a) MIAx 모드 테스트**
- [x] 스크린샷 업로드 → 4개 에이전트 DR 병렬 실행 확인 ✅
- [x] DR 화면에서 4개 모듈 모두 데이터 표시 확인 ✅
- [x] Agent 2, 4 detail modal 작동 확인 ✅
- [x] "Evaluate" 클릭 → 4개 에이전트 E 병렬 실행 확인 ✅
- [x] Evaluation 화면에서 4개 에이전트 이슈 모두 표시 확인 ✅
- [x] Agent별 상세보기 UI 차별화 확인 ✅

**b) MIA 모드 테스트**
- [ ] Heuristic 평가 작성 → 스크린샷 업로드
- [ ] 4개 에이전트 DR 병렬 실행 (Agent 3에 MIA context 전달)
- [ ] 동일한 UI 플로우 확인

**c) 에러 핸들링 테스트**
- [ ] Agent 2 실패 시 다른 에이전트 계속 진행 확인
- [ ] Partial failure 경고 메시지 표시 확인

**d) 디버그 로그 확인**
- [x] 콘솔에 각 단계별 입력 로그 출력 확인 ✅
- [x] 프롬프트, 레퍼런스, 중간 결과 모두 로깅되는지 확인 ✅

---

## 주요 파일 위치

### 프롬프트 파일
- `/lib/prompts/Agent1_DR_prompt.md` ✅
- `/lib/prompts/Agent1_E_prompt.md` ✅
- `/lib/prompts/Agent2_DR_prompt.md` ✅
- `/lib/prompts/Agent2_E_prompt.md` ✅
- `/lib/prompts/Agent3_DR_prompt.md` ✅
- `/lib/prompts/Agent3_E_prompt.md` ✅
- `/lib/prompts/Agent4_DR_prompt.md` ✅
- `/lib/prompts/Agent4_E_prompt.md` ✅

### 레퍼런스 파일
- `/lib/references/Agent1_Text_heuristics.md` ✅
- `/lib/references/Agent2_IA_heuristics.md` ✅
- `/lib/references/Agent2_Terms_and_definitions.md` ✅
- `/lib/references/Agent3_Icon_heuristics.md` ✅
- `/lib/references/Agent4_Terms_and_definitions.md` ✅
- `/lib/references/Agent4_heuristics.md` ✅

### 모델 파일
- `/lib/models/icon_analysis_result.dart` - Agent 1, 2, 3, 4 DR 결과 ✅
- `/lib/models/ux_issue_result.dart` - Agent 1, 2, 3, 4 E 결과 ✅
- `/lib/models/analysis_result.dart` - MIA Heuristic 결과 ✅

### 서비스 파일
- `/lib/services/icon_analysis_service.dart` - Agent 1, 2, 3, 4 DR ✅
- `/lib/services/ux_evaluation_service.dart` - Agent 1, 2, 3, 4 E ✅
- `/lib/services/analysis_service.dart` - MIA Heuristic ✅
- `/lib/services/gemini_service.dart` - Gemini API ✅

### 화면 파일
- `/lib/main.dart` - 진입점, 병렬 처리 ✅
- `/lib/screens/design_representation_screen.dart` - DR 화면 ✅
- `/lib/screens/ux_evaluation_screen.dart` - Evaluation 화면 ✅
- `/lib/screens/heuristic_evaluation_page.dart` - MIA 화면 ✅

---

## 다음 세션에서 할 일

### 우선순위 1: 추가 테스팅 (선택)
1. **MIA 모드 테스트**:
   - Heuristic 평가 작성 → 스크린샷 업로드
   - 4개 에이전트 DR 병렬 실행 (Agent 3에 MIA context 전달)
   - 동일한 UI 플로우 확인

2. **에러 핸들링 테스트**:
   - 잘못된 JSON 응답 처리 확인
   - Partial failure (한 에이전트만 실패) 시나리오

### 우선순위 2: 추가 개선사항 (선택)
1. Error handling 강화 (partial success 경고 메시지)
2. Download 기능 업데이트 (4개 에이전트 결과 모두 포함)
3. UI 폴리싱 (로딩 메시지, 프로그레스 바 등)
4. 디버그 로깅 제거 또는 프로덕션 모드 분리

---

## 참고사항

### Agent별 특징
- **Agent 1**: 프롬프트만 있음 (레퍼런스 = 휴리스틱)
- **Agent 2**: 프롬프트 + 2개 레퍼런스 (IA Heuristics, Terms)
- **Agent 3**: 프롬프트 + 1개 레퍼런스 (Icon Heuristics)
- **Agent 4**: 프롬프트 + 2개 레퍼런스 (Heuristics, Terms), **2단계 평가** (flow-level + interaction-level)

### 병렬 처리 패턴
```dart
final results = await Future.wait([
  service.method1(),  // Agent 1
  service.method2(),  // Agent 2
  service.method3(),  // Agent 3
  service.method4(),  // Agent 4
]);

final result1 = results[0];
final result2 = results[1];
final result3 = results[2];
final result4 = results[3];
```

### 에러 핸들링
Partial success를 위해 각 Future에 `.catchError()` 추가 가능:
```dart
final results = await Future.wait([
  service.method1().catchError((e) {
    print('Agent 1 실패: $e');
    return EmptyResult();
  }),
  // ... 나머지 에이전트
], eagerError: false);
```
