import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/widgets.dart';
import '../data/roster_repository.dart';
import '../logic/roster_providers.dart';
import 'member_sheet.dart';

/// 관리자 '사용자 관리': 모든 반 사람을 이름순으로 한 목록에(옆에 반 이름). 이름으로 찾고,
/// 누르면 데이터 가져와 주기·반 옮기기·출석부에서 지우기 창이 떠요.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _query = '';

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
              padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 24),
              children: [
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: '이름으로 찾기'),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),
                MutedText('${all.length}명 · 앱에서 반을 고른 사람이 보여요. 아래로 당기면 새로 불러와요.', style: const TextStyle(fontSize: 13)),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: MutedText(all.isEmpty ? '아직 사용자가 없어요.' : '찾는 이름이 없어요.', textAlign: TextAlign.center),
                  ),
                for (final u in shown) _UserTile(entry: u, all: all),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.entry, required this.all});

  final UserEntry entry;
  final List<UserEntry> all;

  @override
  Widget build(BuildContext context) {
    final (:course, :member, :movingTo) = entry;
    final older = member.older.length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Flexible(child: Text(member.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          // 반 이름이 길어도 좁은 폰에서 넘치지 않게
          Flexible(child: TinyBadge(course.name.isEmpty ? '(이름 없는 반)' : course.name, tone: Tone.neutral)),
        ],
      ),
      subtitle: Text(
        '${memberDocLine(member)}${older == 0 ? '' : ' · 같은 이름 예전 $older'}'
        '${movingTo == null ? '' : ' · 반 옮기는 중'}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showMemberSheet(context, course, member, [
        for (final u in all)
          if (u.course.id == course.id) u.member,
      ], movingTo: movingTo),
    );
  }
}
