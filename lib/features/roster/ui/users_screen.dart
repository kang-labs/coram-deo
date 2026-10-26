import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../../../core/local_storage.dart';
import '../../../core/models/course.dart';
import '../../course/ui/course_picker_screen.dart' show CourseGroupHeader, groupCourses;
import '../data/roster_repository.dart';
import '../logic/roster_providers.dart';
import 'member_sheet.dart';

/// 사용자 관리 보기 방식. 고른 방식은 폰에 기억해요.
enum UsersView {
  byName('이름순', Icons.sort_by_alpha_rounded),
  byCourse('반별', Icons.groups_rounded);

  const UsersView(this.label, this.icon);

  final String label;
  final IconData icon;

  static const _key = 'usersView';

  static UsersView fromName(String? name) => values.firstWhere((v) => v.name == name, orElse: () => byName);
}

/// 관리자 '사용자 관리': 모든 반 사람을 이름순(옆에 반 이름) 또는 반별로. 이름으로 찾고,
/// 누르면 데이터 가져와 주기·반 옮기기·출석부에서 지우기 창이 떠요.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _query = '';
  late UsersView _view = UsersView.fromName(ref.read(sharedPreferencesProvider).getString(UsersView._key));

  void _setView(UsersView v) {
    setState(() => _view = v);
    ref.read(sharedPreferencesProvider).setString(UsersView._key, v.name);
  }

  /// 반별: '25기 양육훈련' 같은 묶음 머리글 → 반 이름(사람 수) → 그 반 사람들(이름순)
  List<Widget> _byCourse(List<UserEntry> shown, List<UserEntry> all) {
    final byCourse = <String, List<UserEntry>>{};
    final courses = <String, Course>{};
    for (final u in shown) {
      byCourse.putIfAbsent(u.course.id, () => []).add(u);
      courses[u.course.id] = u.course;
    }
    return [
      for (final (title, group) in groupCourses(courses.values.toList())) ...[
        if (title.isNotEmpty) CourseGroupHeader(title, padding: const EdgeInsets.only(top: 20)),
        for (final c in group) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Text(
              '${c.name.isEmpty ? '(이름 없는 반)' : c.name} · ${byCourse[c.id]!.length}명',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          for (final u in byCourse[c.id]!) _UserTile(entry: u, all: all, showCourse: false),
        ],
      ],
    ];
  }

  Future<void> _refresh() => ref.refresh(adminUsersProvider.future);

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('사용자 관리')),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: '사용자 목록을 못 불러왔어요',
          message: '인터넷 연결을 확인해 주세요.\n($e)',
          action: OutlinedButton(onPressed: _refresh, child: const Text('다시 불러오기')),
        ),
        data: (all) {
          final shown = [
            for (final u in all)
              if (nameMatches(u.member.name, _query)) u,
          ];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: AppLayout.listPadding(context),
              children: [
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: '이름으로 찾기'),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                SegmentedButton<UsersView>(
                  segments: [
                    for (final v in UsersView.values) ButtonSegment(value: v, label: Text(v.label), icon: Icon(v.icon)),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => _setView(s.first),
                ),
                const SizedBox(height: 8),
                MutedText('${all.length}명 · 앱에서 반을 고른 사람이 보여요. 아래로 당기면 새로 불러와요.', style: const TextStyle(fontSize: 13)),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: MutedText(all.isEmpty ? '아직 사용자가 없어요.' : '찾는 이름이 없어요.', textAlign: TextAlign.center),
                  ),
                if (_view == UsersView.byName)
                  for (final u in shown) _UserTile(entry: u, all: all)
                else
                  ..._byCourse(shown, all),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.entry, required this.all, this.showCourse = true});

  final UserEntry entry;
  final List<UserEntry> all;

  /// 반별 보기에서는 반 이름이 머리글에 있어서 빼요
  final bool showCourse;

  @override
  Widget build(BuildContext context) {
    final (:course, :member, :phoneCid) = entry;
    final older = member.older.length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Flexible(child: Text(member.name, overflow: TextOverflow.ellipsis)),
          if (showCourse) ...[
            const SizedBox(width: 8),
            // 반 이름이 길어도 좁은 폰에서 넘치지 않게
            Flexible(child: TinyBadge(course.name.isEmpty ? '(이름 없는 반)' : course.name, tone: Tone.neutral)),
          ],
        ],
      ),
      subtitle: Text(
        '${member.device == null ? '' : '${member.device!.label} · '}'
        '${memberDocLine(member)}${older == 0 ? '' : ' · 같은 이름 예전 $older'}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showMemberSheet(context, course, member, [
        for (final u in all)
          if (u.course.id == course.id) u.member,
      ], phoneCid: phoneCid),
    );
  }
}
