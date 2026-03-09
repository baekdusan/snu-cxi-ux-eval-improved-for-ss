/// Agent 2 (Error Prevention & Forgiveness) Heuristics 데이터 구조
library;

import 'agent1_text_heuristics.dart';

/// Agent2 Error Prevention & Forgiveness Heuristics 전체 리스트
const List<HeuristicCategory> agent2ErrorHeuristics = [
  // 1. Error Prevention
  HeuristicCategory(
    id: 'error_prevention',
    category: 'Error Prevention',
    items: [
      HeuristicItem(
        title: '잘못된 조작을 방지 할 수 있도록 태스크를 수행하기 전에 적절한 상태를 만들어 준다.',
        descriptions: [
          '현재 사용할 수 없는 항목들은 보여주지 않거나 비활성화 한다.',
          '적절한 디폴트 값을 설정한다.'
        ],
        examples: [
          '애플리케이션 제거(Uninstall) 기능은 Home screen 편집 모드에서는 미제공하여 Home screen에서만 삭제하려다 설치된 애플리케이션 자체를 삭제하는 오류를 방지',
          'Setup-wizard 설정 시, 단계별 적절한 디폴트값을 미리 설정'
        ],
        additional_info: [
          '키보드의 "완료"는 항상 활성화되어 있어야 함. 키보드의 "완료" 버튼은 키보드를 통한 텍스트 입력 완료를 의미하는 것임. 이것은 다음 단계로의 이동을 의미하지 않음.'
          '한 화면에서 특정 UI 요소가 활성화되어 있는지 판단할 때는 그 화면만 기준으로 보지 말고, 다른 화면들과 비교해 상대적으로 얼마나 눈에 띄는지 함께 고려하라. 다른 화면들에 비해 해당 요소의 시각적 강조나 salience가 낮다면, 사용자 관점에서는 그것이 비활성화된 것으로 간주하라.'
        ],
      ),
      HeuristicItem(
        title: '회복하기 어려운 태스크 수행 시, 사전 경고 및 검토하는 단계를 제공한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '제공된 스크린샷 범위 안에서 직접적으로 확인 가능한 내용만을 근거로 평가하라. 저장 버튼을 눌렀을 때의 후속 동작이나, 뒤로가기 시 자동 저장 여부처럼 스크린샷에 나타나지 않은 인터랙션은 추측하지 말고 판단에서 제외하라.'
          '이 휴리스틱에서 "되돌리기 어려운 태스크"는 "뒤로가기" 버튼 등으로 복구할 수 없는 태크스를 의미한다. 되돌리거나 회복하는 기능이 충분히 제공되는 경우에는 이 휴리스틱을 적용하지 않는다.'
        ],
      ),
    ],
  ),

  // 2. Error Recovery
  HeuristicCategory(
    id: 'error_recovery',
    category: 'Error Recovery',
    items: [
      HeuristicItem(
        title: '행동의 결과를 취소하고 이전의 상태로 돌아갈 수 있는 방법을 제시한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '단, 이전 상태로 돌리는 것과 다시 태스크를 수행하는 것이 동등한 수준의 노고가 드는 경우에는 이전으로 돌아가는 방법을 반드시 제공할 필요는 없다.'
        ],
      ),
      HeuristicItem(
        title: '이전으로 취소할 수 없다면 초기 상태로 다시 돌아갈 수 있는 방법을 제시한다.',
        descriptions: [],
        examples: [],
        additional_info: [],
      ),
      HeuristicItem(
        title: '취소의 범위를 규정하고 이를 명확히 전달해야 한다.',
        descriptions: [
          '사용자의 입장에서는 모든 단계를 취소할 수 있으면 가장 편하겠지만 시스템 성능에 많은 부하를 줄 경우, 범위를 규정하고 사용자가 이를 인식할 수 있어야 한다.'
        ],
        examples: [],
        additional_info: [
          '단, "특정" 작업이 "진행 중"인 상태에서 뒤로가기를 누르는 경우, 보편적인 사용자 기대는 해당 작업이 취소된다는 것이므로, 뒤로가기로 충분하다.'
        ],
      ),
      HeuristicItem(
        title: '의도하지 않은 종료나 중단, 손실에 대해 결과를 보존/회복할 수 있어야 한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '이 휴리스틱은, "사용자가 의도하지 않은 종료" 상황에서 적용되어야 한다. 즉 사용자가 뒤로가기 버튼을 누르는 상황을 전제하지 않는다. 그보다는 시스템 오류 등으로 인해 사용자가 원하지 않는 종료가 발생했을 시를 전제한다.'
        ],
      ),
      HeuristicItem(
        title: '사용자의 실수를 시스템에서 적절히 처리해주는 방법을 마련한다.',
        descriptions: [
          '사용자가 의도했던 바를 파악하여 수정안을 제안한다.',
          '다양한 형식의 입력을 허용한다.'
        ],
        examples: [
          'Virtual keyboard에서 Auto replace 기능 제공'
        ],
        additional_info: [],
      ),
    ],
  ),
];