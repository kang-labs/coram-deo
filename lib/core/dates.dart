/// 날짜만 다루는 도우미. 시간·시간대 없이 UTC 자정으로 맞춰서 날짜 계산이 어긋나지 않게 합니다.
library;

/// 날짜만 남긴 값 (UTC 자정)
DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// 오늘 (날짜만)
DateTime todayDate() => dateOnly(DateTime.now());

/// 'yyyy-MM-dd' → 날짜. 형식이 틀리면 null.
DateTime? tryParseYmd(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final date = DateTime.utc(y, mo, d);
  // 2월 30일처럼 넘어가는 날짜는 틀린 값으로
  return date.month == mo ? date : null;
}

String pad2(int n) => n.toString().padLeft(2, '0');

/// 날짜 → 'yyyy-MM-dd' (저장용)
String ymd(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

/// 날짜 → 'M/d' (화면용)
String md(DateTime d) => '${d.month}/${d.day}';

/// 요일 한 글자 (DateTime.weekday: 월1 … 일7)
const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

String weekdayLabel(int weekday) => weekdayLabels[(weekday - 1) % 7];

/// 'M/d(요일)'
String mdw(DateTime d) => '${md(d)}(${weekdayLabel(d.weekday)})';

/// 날짜 더하기 (시간대 영향 없이)
DateTime addDays(DateTime d, int days) => DateTime.utc(d.year, d.month, d.day + days);

/// 두 날짜 사이 일수 (b − a)
int daysBetween(DateTime a, DateTime b) => dateOnly(b).difference(dateOnly(a)).inDays;
