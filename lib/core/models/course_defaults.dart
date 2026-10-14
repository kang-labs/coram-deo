import '../dates.dart';
import 'course.dart';

/// 새 반의 기본 체크 항목 (제자대학2학기 종이 표 그대로). 항목·칸 id는 폰 기록과 이어지니 바꾸지 마세요.
/// 칸이 하나인 항목의 칸 id는 'main'. tool/dev/seed.py에도 같은 목록이 있어요 — 바꾸면 함께 고칩니다(테스트가 확인).
const defaultItems = <ItemDef>[
  ItemDef(
    id: 'attend',
    label: '출석/후기',
    parts: [
      PartDef(id: 'att', label: '출석', type: PartType.attend),
      PartDef(id: 'review', label: '후기', type: PartType.mark),
    ],
  ),
  ItemDef(
    id: 'prep',
    label: '교재예습',
    parts: [PartDef(id: 'main', label: '교재예습', type: PartType.mark)],
  ),
  ItemDef(
    id: 'book',
    label: '필독서 읽기',
    parts: [PartDef(id: 'main', label: '필독서', type: PartType.mark)],
  ),
  ItemDef(
    id: 'bible',
    label: '성경읽기',
    parts: [PartDef(id: 'main', label: '성경', type: PartType.days)],
  ),
  ItemDef(
    id: 'qt',
    label: '큐티',
    parts: [PartDef(id: 'main', label: '큐티', type: PartType.days)],
  ),
  ItemDef(
    id: 'prayer',
    label: '기도',
    parts: [PartDef(id: 'main', label: '기도', type: PartType.days)],
  ),
  ItemDef(
    id: 'dawn',
    label: '새벽기도',
    parts: [PartDef(id: 'main', label: '새벽', type: PartType.dawn)],
  ),
  ItemDef(
    id: 'task',
    label: '강사 특별과제',
    parts: [PartDef(id: 'main', label: '과제', type: PartType.mark)],
  ),
  ItemDef(
    id: 'verse',
    label: '구절암송',
    parts: [PartDef(id: 'main', label: '암송', type: PartType.ox)],
  ),
  ItemDef(
    id: 'monday',
    label: '월요목회 도고기도',
    parts: [PartDef(id: 'main', label: '도고', type: PartType.mark)],
  ),
  ItemDef(
    id: 'friday',
    label: '금요기도회',
    parts: [
      PartDef(id: 'att', label: '출석', type: PartType.mark),
      PartDef(id: 'review', label: '후기', type: PartType.mark),
      PartDef(id: 'pulpit', label: '강단기도', type: PartType.mark),
    ],
  ),
  ItemDef(
    id: 'festival',
    label: '축제예배/후기',
    parts: [
      PartDef(id: 'att', label: '참석', type: PartType.mark),
      PartDef(id: 'review', label: '후기', type: PartType.mark),
    ],
  ),
  ItemDef(
    id: 'passion',
    label: '열정예배/후기',
    parts: [
      PartDef(id: 'att', label: '참석', type: PartType.mark),
      PartDef(id: 'review', label: '후기', type: PartType.mark),
    ],
  ),
  ItemDef(
    id: 'cell',
    label: '셀가족모임',
    parts: [PartDef(id: 'main', label: '셀', type: PartType.mark)],
  ),
  ItemDef(
    id: 'happy',
    label: '행복모임 인도',
    parts: [PartDef(id: 'main', label: '행복', type: PartType.mark)],
  ),
];

/// 새 반의 기본 기록요령 글
const defaultGuide = '''- 출석: 출석(○) 지각(지)로 표기, 결석 3회부터는 과락 처리됩니다. 꼭 반장을 통해 사전 연락하세요.
- 성경: 1일 맥체인 성경읽기(셀라이프 캘린더) 읽은 날짜 기록 / 7일간 다 했을 경우 '7'이라고 표시
- 큐티: <셀라이프> 한 날짜 기록 / 7일간 다 했을 경우 '7'이라고 표시
- 교재예습, 필독서 읽기, 과제, 후기: 했으면(○), 안 했으면(X)로 표시
  - 교재예습: 말씀구절을 손으로 직접 기록합니다(5절 이상의 구절은 첫 구절, 마지막 구절만 기록). 예습하면 더 큰 은혜가 있습니다.
  - 필독서 읽기: 정해진 주에 정해진 분량만큼 읽고 나눔을 준비합니다.
- 축제예배, 셀가족모임, 행복모임, 금요기도회: 참석(○) 불참(X)로 표기
- 기도: 한 시간만큼 기록 / 하루 1시간, 일주일간 7시간 했으면 '7'이라고 표시
- 새벽기도: 주 3회 참석: 0, 2회 참석: −1, 1회 참석: −2, 미참석: −3''';

/// 새 반 주 수 기본값
const defaultWeekCount = 12;

/// 항목 id 새로 만들기: 기존 id와 겹치지 않는 'item_xxx'
String newItemId(Iterable<String> existing, {DateTime? now}) => _uniqueId('item', existing, now);

String _uniqueId(String prefix, Iterable<String> existing, DateTime? now) {
  final taken = existing.toSet();
  final base = '${prefix}_${(now ?? DateTime.now()).millisecondsSinceEpoch.toRadixString(36)}';
  var id = base;
  for (var n = 2; taken.contains(id); n++) {
    id = '${base}_$n';
  }
  return id;
}

/// 칸 id가 없던 예전 데이터(서버 문서·폰 기록의 칸 순번)를 읽을 때 쓰는 칸 id.
/// 기본 항목이면 그 항목의 [index]번째 기본 칸 id, 아니면 'p0', 'p1' ….
String legacyPartId(String itemId, int index) {
  for (final item in defaultItems) {
    if (item.id == itemId) return index < item.parts.length ? item.parts[index].id : 'p$index';
  }
  return 'p$index';
}

/// 항목 안에서 겹치지 않는 새 칸 id ('p_xxx')
String newPartId(Iterable<String> existing, {DateTime? now}) => _uniqueId('p', existing, now);

/// 1주 날짜부터 7일씩 [count]주 일정을 채웁니다. 이미 있던 주의 내용은 순서대로 유지해요.
List<WeekInfo> fillWeeks(DateTime firstClassDate, int count, List<WeekInfo> existing) {
  return [
    for (var i = 0; i < count; i++)
      (i < existing.length ? existing[i] : const WeekInfo(date: '')).copyWith(
        date: ymd(addDays(firstClassDate, i * 7)),
      ),
  ];
}
