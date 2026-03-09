/// Agent 1 (UX Writing) Heuristics 데이터 구조
///
/// 이 파일은 Agent1_Text_heuristics.md 파일의 내용을 구조화된 Dart 객체로 변환한 것입니다.
/// 각 휴리스틱 항목을 개별적으로 조회하고 활용할 수 있도록 설계되었습니다.
library;

/// 개별 휴리스틱 항목
///
/// 하나의 휴리스틱 원칙을 나타내며, 제목, 세부 설명, 예시로 구성됩니다.
class HeuristicItem {
  /// 휴리스틱 제목
  ///
  /// 예: "문구와 용어는 최대한 간결해야 한다."
  final String title;

  /// 세부 설명 리스트
  ///
  /// 해당 휴리스틱에 대한 상세한 설명 및 가이드라인
  final List<String> descriptions;

  /// 예시 리스트
  ///
  /// "예)"로 시작하는 구체적인 사용 예시들
  final List<String> examples;

  /// additional info
  final List<String> additional_info;

  const HeuristicItem({
    required this.title,
    required this.descriptions,
    required this.examples,
    required this.additional_info,
  });
}

/// 휴리스틱 대분류
///
/// 관련된 휴리스틱 항목들을 그룹화한 카테고리
class HeuristicCategory {
  /// 카테고리 고유 ID
  ///
  /// 예: "terminology_usage", "tone_manner"
  final String id;

  /// 카테고리 표시명
  ///
  /// 예: "용어 및 문구 사용", "Tone & Manner"
  final String category;

  /// 해당 카테고리에 속한 휴리스틱 항목 리스트
  final List<HeuristicItem> items;

  const HeuristicCategory({
    required this.id,
    required this.category,
    required this.items,
  });
}

/// Agent1 Text Heuristics 전체 리스트
///
/// 총 8개의 대분류 카테고리로 구성:
/// 1. 용어 및 문구 사용 (7개 항목)
/// 2. Tone & Manner (5개 항목)
/// 3. Globalization & Localization (4개 항목)
/// 4. Intuitive
/// 6. Easy
/// 7. Cultural (2개 항목)
/// 8. 일관성
/// 9. 배려성
///
/// 사용 예시:
/// ```dart
/// // 특정 카테고리 검색
/// final category = agent1TextHeuristics.firstWhere(
///   (c) => c.id == 'tone_manner'
/// );
///
/// // 모든 항목 순회
/// for (var category in agent1TextHeuristics) {
///   for (var item in category.items) {
///     print('${category.category}: ${item.title}');
///   }
/// }
/// ```
const List<HeuristicCategory> agent1TextHeuristics = [
  // 2. 용어 및 문구 사용
  HeuristicCategory(
    id: 'terminology_usage',
    category: '용어 및 문구 사용',
    items: [
      HeuristicItem(
        title: '사용자에게 필요한 시점에 핵심적인 정보를 전달할 수 있는 문구를 제공한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, 기능의 이름이 익숙하지 않거나 이해하기 어려운 경우에는 기능에 대한 부가 설명을 제공하는 것을 허용한다.',
          '다만, AI 가이드라인(AI가 생성한 결과물이 불완전할 수 있음을 명시)을 준수하기 위해 추가된 텍스트는 예외적으로 과업 수행을 방해할 수 있다.',
          '다만, 사용자에게 새로운 기능을 소개하고 다음 행동을 유도하는 텍스트의 경우 직설적인 표현보다 부드러운 표현을 우선 사용한다.',
        ],
      ),
      HeuristicItem(
        title: '대표 사용자가 이해할 수 있는 용어를 사용한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, 텍스트가 사용자에게 영감을 주고 창의적인 활동을 보조하는 목적으로 활용될 때는 텍스트가 일반적이지 않더라도, 주변 이미지와 같은 다른 UX 요소들을 통해 의미가 전달되면 허용한다.',
          '해당 텍스트의 위치 및 주변 UI 요소들이 텍스트에 맥락을 부여하여 사용자의 의미 파악을 도울 수 있다는 점을 고려한다.',
          '타겟 사용자의 특성을 고려하여 이해 난이도를 판단해야 한다.',
        ],
      ),
      HeuristicItem(
        title: '문구와 용어는 최대한 간결해야 한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, 사용자에게 새로운 기능을 소개하고 다음 행동을 유도하는 텍스트의 경우 간결성을 희생하여 부드러운 표현을 쓴다.',
          '다만, 사용자에게 직접적인 안내가 필요한 경우 간결성을 희생하여 부드러운 표현을 쓴다.',
          '문장이 이미 충분히 간결한지, 더 줄일 경우 필요한 정보가 누락될 수 위험은 없는지 고려한다.',
          '지적된 간결성 문제를 해결하기 위해 문장을 분리하더라도, 그로 인해 전반적 간결성이 오히려 저하되지 않는지(전체 텍스트 길이 증가) 함께 고려한다.',
          '다만, AI 가이드라인(AI 모델이 데이터를 처리하는 방식을 명확하게 사전에 알려야 함)을 준수하기 위해 추가된 텍스트는 예외적으로 내용을 명확하게 전달하기 위해 간결하지 않은 표현을 사용할 수 있다.',
          '다만, 기능의 이름이 익숙하지 않거나 이해하기 어려운 경우에는 기능에 대한 부가 설명을 제공하는 것을 허용한다.',
        ],
      ),
      HeuristicItem(
        title: '중복된 표현을 사용하지 않는다.',
        descriptions: [],
        examples: [
          '"Settings" 앱 하위 항목명으로 "Setting(s)"이라는 단어 사용을 지양한다.',
          'On/off 스위치와 같이 충분한 동작유도성 (Affordance)을 가지고 있는 GUI 요소의 조작방법을 설명하는 문구를 같은 화면상에 제공하지 않는다.',
          '체크박스 등 GUI 로 충분한 상태 정보를 제공하는 경우, 설정 상태를 중복 설명하지 않는다.',
          '팝업 헤더에는 문장부호와 부연설명이 포함된 \'Save before closing?\'와 같은 문구 대신 Save (item) 와 같이 간결하고 명확한 문구를 사용한다.',
        ],
        additional_info: [
          '다만, AI 가이드라인(AI가 생성한 결과물임을 명시해야함)을 준수하기 위해 추가된 텍스트는 예외적으로 중복된 표현을 사용할 수 있다.',
          '다만, 중복된 표현을 제거하였을 때 목적어가 사라지는 등 의미 파악에 제약이 생기면 중복된 표현을 허용한다.',
          '다만, 텍스트 주변의 이미지와 텍스트가 서로 같은 대상을 지칭할 경우에는 정보를 더 명확하게 제공하기 위한 것이므로 중복 제공이라고 판단하지 않는다.',
          '다만, ‘현재 수정 및 작업 중인 대상’의 경우 별도의 표현 없이 인지 가능하더라도 대상을 명확히 표기하는 것이 필요하다.',
          '다만, 화면 내 다른 UI 요소를 포괄하는 상위 레벨의 의미를 지닌 텍스트의 경우 분류/제목과 같은 역할을 하므로 중복된 표현으로 간주하지 않는다.',
          '다만, 익숙하지 않거나 이해하기 어려운 용어의 경우 중복이 일부 발생하더라도 명확하게 부가 설명을 제공하는 것이 필요하다.'
        ],
      ),
      HeuristicItem(
        title: '명확한 메시지를 전달해야 한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '해당 텍스트의 위치 및 주변 UI들이 텍스트에 맥락을 부여하여 사용자의 의미 파악을 도울 수 있다는 점을 고려한다.',
          '평가 시 단일 스크린에 국한하지 말고, 앞뒤 스크린을 포함한 과업 시나리오 전체 맥락에서 텍스트의 의미가 명확한지 판단해야 한다.'
          '단, 문장의 일부분이 잘려서 앞부분만 보이는 경우 명확성의 판단 대상으로 삼지 않는다.',
          '단, 사용자가 입력한 텍스트는 평가하지 않는다.'
        ],
      ),
      HeuristicItem(
        title: '동일한 대상이나 동작을 지칭할 때는 일관성 있는 용어를 사용한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '단, 문장의 일부분이 잘려서 앞부분만 보이는 경우 일관성의 판단 대상으로 삼지 않는다.',
          '단, 사용자가 입력한 텍스트는 평가하지 않는다.'
        ],
      ),
      HeuristicItem(
        title: '대소문자의 표기와 문장부호, 인칭대명사 등을 일관성 있게 사용한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, 명사구로 끝나는 경우 마침표를 표시하지 않아도 된다.',
          '다만, 동사구로 끝나는 경우 마침표를 표시하지 않아도 된다.',
          '다만, 사용자에게 직접적인 안내가 필요한 경우, 표현을 부드럽게 만드는 데 도움이 된다면, 상황에 맞게 1/2/3인칭이나 문어체/구어체가 혼용될 수 있다.',
        ],
      ),
    ],
  ),

  // 3. Tone & Manner
  HeuristicCategory(
    id: 'tone_manner',
    category: 'Tone & Manner',
    items: [
      HeuristicItem(
        title: '디바이스 중심이 아니라 사용자 중심의 표현을 사용하여, 목적한 태스크에 사용자가 집중할 수 있게 한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, AI 가이드라인(AI가 생성한 결과물이 불완전할 수 있음을 명시)을 준수하기 위해 추가된 텍스트는 예외적으로 세부 및 제약 사항을 설명할 수 있다.',
          '다만, AI 가이드라인(AI로 생성된 이미지는 비즈니스 목적으로의 사용을 금지함)을 준수하기 위해 추가된 텍스트는 예외적으로 세부 및 제약 사항을 설명할 수 있다.',
          '주어가 생략되어 있는 경우 문맥을 파악하여 사용자 중심 혹은 디바이스 중심 서술 여부를 판단한다.',
          '다만, 시스템의 현재 상태/진행상황을 서술하는 경우에는 디바이스 중심 서술을 사용할 수 있다.',
          '다만, 디바이스가 능동적으로 수행한 결과를 전달할 때에는 디바이스 중심 서술을 사용할 수 있다.',
          '다만, 시스템 설정 옵션을 서술할 때에는 디바이스 중심 서술을 사용할 수 있다.',
        ],
      ),
      HeuristicItem(
        title: '가능한 긍정적인 표현과 어조를 사용한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, AI 가이드라인(AI가 생성한 결과물이 불완전할 수 있음을 명시)을 준수하기 위해 추가된 텍스트는 예외적으로 세부 및 제약 사항을 설명할 수 있다.',
          '다만, AI 가이드라인(AI로 생성된 이미지는 비즈니스 목적으로의 사용을 금지함)을 준수하기 위해 추가된 텍스트는 예외적으로 긍정적이고 친숙한 표현을 사용하지 않을 수 있다.',
        ],
      ),
      HeuristicItem(
        title: '문제 발생 시, 사용자를 비난하는 표현을 지양한다.',
        descriptions: [],
        examples: [
          'You have reached the maximum number of folders. (X) Maximum number of folders (has been) reached. (O)',
        ],
        additional_info: [],
      ),
      HeuristicItem(
        title: '일상생활에서 사용하는 친숙한 표현을 사용한다.',
        descriptions: [],
        examples: [
          'Yesterday, Tomorrow',
          'Store open 9:00 AM–Midnight, Reminder for tomorrow afternoon',
        ],
        additional_info: [
          '타겟 사용자의 언어적 특성을 고려하여 친숙함의 정도를 판단해야 한다.',
        ],
      ),
      HeuristicItem(
        title: '편안하고 친절한 어조의 문구를 사용하되, 일부 S Voice 등 특화 앱을 제외하고는 구어체 문구는 지양한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, 사용자에게 상황을 직접적이면서도 부드럽게 안내해야 하는 경우, 구체어 표현 사용이 사용자의 이해 또는 수용을 돕는다고 판단되면 이를 허용한다.',
        ],
      ),
    ],
  ),

  // 4. Globalization & Localization
  HeuristicCategory(
    id: 'globalization_localization',
    category: 'Globalization & Localization',
    items: [
      HeuristicItem(
        title: '번역되었을 때의 상황을 고려하여, 영문 기준으로 적절한 여유 공간을 확보한 상태에서 표시될 수 있도록 한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '번역 시 글자수가 늘어나더라도 번역된 글자 1개가 차지하는 실제 공간을 고려하여 번역문의 길이를 추정하여야 한다. 글자에 따라 가로길이(width)가 가변적인 영어의 i나 l은, 한국어 1글자보다 차지하는 공간이 작다.',
          '번역으로 인해 문장이 길어졌다는 이유만으로는 이슈를 보고하지 않는다. ‘번역문이 해당 텍스트 요소가 포함된 컴포넌트/프레임의 경계를 명확히 초과’하여 심각한 수준의 문제를 유발하는 것이 확실할 때만 보고한다.',
          '번역 시 단어 선택에 대한 다양한 경우의 수를 고려하여 번역된 문장/단어의 길이를 판단한다.',
          '다만, 문장의 일부분이 잘려서 특정 부분만 보이는 경우 번역된 문장을 길이 평가 대상으로 고려하지 않는다.',
        ],
      ),
      HeuristicItem(
        title: '번역 시 다른 의미로 바뀔 수 있는 모호한 표현은 사용하지 않는다.',
        descriptions: [],
        examples: [
          'Abort 대신 End, Quit, Stop 사용',
        ],
        additional_info: [
          '과업 맥락, 주변 UI 요소 등 사용자가 의미를 파악하는 데 도움을 줄 수 있는 정보들도 함께 고려한다.',
          '다만, 문장의 일부분이 잘려서 특정 부분만 보이는 경우 번역된 문장을 의미 평가 대상으로 고려하지 않는다.',
        ],
      ),
      HeuristicItem(
        title: '다국어 번역을 고려하여, 특정 문화권에서만 통용되는 관용구나 상징적 용어 사용을 지양한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '과업 맥락, 주변 UI 요소 등 사용자가 의미를 파악하는 데 도움을 줄 수 있는 정보들을 고려하여 번역된 단어의 해석 용이성 및 모호성을 평가한다.',
        ],
      ),
      HeuristicItem(
        title: '각 지역별/국가별 표기 방법의 차이에 대해 고려해야 한다.',
        descriptions: [],
        examples: [
          '국가별 날짜 표기 방법:\n- 한국: 2010 년 5 월 7 일 금요일\n- 미국: Friday, May 7, 2010\n- 프랑스: vendredi 7 mai 2010\n- 러시아: 7 мая 2010 г.',
        ],
        additional_info: [
          '별도의 지시사항이 없다면, UI에 쓰인 언어를 참고하여 지역별 국가별 사용자를 가정하고 해당 사용자에게 맞는 표기 방식인지를 판단한다. ',
        ],
      ),
    ],
  ),

  // 5. Intuitive
  HeuristicCategory(
    id: 'intuitive',
    category: 'Intuitive',
    items: [
      HeuristicItem(
        title: '사용자가 이해하기 쉽고 명확한 용어를 사용한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '대체 가능한 용어 중 이해하기 쉬운 용어가 없으며, 관련된 이미지가 같이 제공되는 경우에는 대표 사용자가 이미지를 참고하여 해당 용어를 이해할 수 있는지 평가한다.',
          '해당 텍스트의 위치 및 주변 UI 요소들이 텍스트에 맥락을 부여하여 사용자의 의미 파악을 도울 수 있다는 점을 고려한다.',
          '다만, 용어를 명확하게 썼을 때 사용자의 자유도를 제한할 우려가 있다면, 용어의 명확성보다는 사용자의 자유도를 우선시한다.',
          '다만, 용어를 명확하게 썼을 때 문장이 과하게 길어져 간결성이 훼손할 우려가 있다면, 용어의 명확성보다는 간결성을 우선시한다.',
        ],
      ),
    ],
  ),

  // 6. Easy
  HeuristicCategory(
    id: 'easy',
    category: 'Easy',
    items: [
      HeuristicItem(
        title: '간결한 용어와 문구를 사용한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, 사용자에게 직접적인 안내를 제공하는 텍스트의 경우 간결성을 희생하여 부드러운 표현을 쓴다.',
          '다만, 사용자에게 새로운 기능을 소개하고 다음 행동을 유도하는 텍스트의 경우 간결성의 희생하여 부드러운 표현을 쓴다.',
          '문장이 이미 충분히 간결한지, 더 줄일 경우 필요한 정보가 누락될 위험은 없는지도 고려한다.',          
          '다만, 법적 내용(약관, 고지사항 등)은 정보 제공의 완전성을 위해 문장이 길어질 수 있으며, 이는 간결성 원칙 위반으로 보지 않는다.',
          '지적된 간결성 문제를 해결하기 위해 문장을 분리하더라도, 그로 인해 전반적 간결성이 오히려 저하되지 않는지(전체 텍스트 길이 증가) 함께 고려한다.',
        ],
      ),
    ],
  ),

  // 7. Cultural
  HeuristicCategory(
    id: 'cultural',
    category: 'Cultural',
    items: [
      HeuristicItem(
        title: '언어, 문화적 배경에 따라, 공통의 의미로 인식되기 어려운 요소는 가급적 피한다.',
        descriptions: [],
        additional_info: [
          '언어권 예시: 영미권, 중화권, 독일어권, 러시아권 등',
          '문화권 예시: 동아시아권, 아메리카권, 라틴권, 기독교권, 이슬람권 등',
        ],
        examples: [],
      ),
      HeuristicItem(
        title: '언어, 문화적 배경에 따라, 공통 적용 할 수 없는 요소들은 현지화(Localization)하여 제공한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '언어권 예시: 영미권, 중화권, 독일어권, 러시아권 등',
          '문화권 예시: 동아시아권, 아메리카권, 라틴권, 기독교권, 이슬람권 등',
        ],
      ),
    ],
  ),

  // 8. 일관성
  HeuristicCategory(
    id: 'consistency',
    category: '일관성',
    items: [
      HeuristicItem(
        title: '제공된 정보의 일관성을 유지해야 한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '정보를 표현하는 명칭, 문구 등을 일관되게 제공하여야 한다.',
          '텍스트가 사용된 맥락, 기능의 특성, UI 레이아웃 상의 위치 및 구조를 고려하여 텍스트의 의미를 파악해야 한다.',
          '단, 문장의 일부분이 잘려서 앞부분만 보이는 경우 일관성의 판단 대상으로 삼지 않는다.',
          '단, 사용자가 입력한 텍스트는 평가하지 않는다.'
        ],
      ),
    ],
  ),

  // 9. 배려성
  HeuristicCategory(
    id: 'consideration',
    category: '배려성',
    items: [
      HeuristicItem(
        title: '긍정적이고 친숙한 표현을 사용해야 한다.',
        descriptions: [],
        examples: [],
        additional_info: [
          '다만, AI 가이드라인(AI가 생성한 결과물이 불완전할 수 있음을 명시)을 준수하기 위해 추가된 텍스트는 예외적으로 세부 및 제약 사항을 설명할 수 있다.',
          '다만, AI 가이드라인(AI로 생성된 이미지는 비즈니스 목적으로의 사용을 금지함)을 준수하기 위해 추가된 텍스트는 예외적으로 긍정적이고 친숙한 표현을 사용하지 않을 수 있다.',
          '다만, 시스템 기능상 조사가 수식하는 단어를 사용자가 다양하게 선택할 수 있는 상황에서는 일반적인 문장처럼 특정 조사를 지정하면 선택의 다양성을 해칠 수 있어 예외적으로 일반적이지 않은 조사 표현을 허용한다.',
        ],
      ),
    ],
  ),
];

/// 헬퍼 함수: 카테고리 ID로 검색
HeuristicCategory? getCategoryById(String id) {
  try {
    return agent1TextHeuristics.firstWhere((c) => c.id == id);
  } catch (e) {
    return null;
  }
}

/// 헬퍼 함수: 전체 항목 개수 계산
int getTotalItemCount() {
  return agent1TextHeuristics.fold(
    0,
    (sum, category) => sum + category.items.length,
  );
}

/// 헬퍼 함수: 카테고리별 항목 개수
Map<String, int> getItemCountByCategory() {
  return Map.fromEntries(
    agent1TextHeuristics.map(
      (c) => MapEntry(c.category, c.items.length),
    ),
  );
}
