import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dialogs.dart';
import '../../../app/layout.dart';
import '../../../app/sheets.dart';
import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/models/course.dart';
import '../../admin/ui/admin_screen.dart';
import '../../archive/ui/past_books_screen.dart';
import '../../backup/ui/backup_sheet.dart';
import '../../profile/ui/name_screen.dart';
import '../../roster/logic/roster_providers.dart';
import '../../roster/ui/leader_code.dart';
import '../../course/logic/course_providers.dart';
import '../../course/ui/course_picker_screen.dart';
import '../../install/ui/install_guide.dart';
import '../../record/logic/record_providers.dart';
import '../../theme/logic/theme_providers.dart';

/// 설정 한 줄 (아이콘, 제목, 설명, 누르면)
typedef _SettingRow = ({IconData icon, Tone tone, String title, String subtitle, VoidCallback onTap});

/// 설정: 반 바꾸기, 내 이름, 지난 출석부, 기록 저장·불러오기, 기록요령 보기, 테마, 관리자 모드
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key, required this.course});

  final Course? course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(myNameProvider);
    final theme = ref.watch(themeIdProvider);
    final pastCount = ref.watch(pastBooksProvider.select((b) => b.length));
    // 반장·총무로 정해졌는데 아직 코드를 안 넣었을 때만 보여요
    final needCode = ref.watch(leaderCodeNeededProvider);
    final rows = <_SettingRow>[
      (
        icon: Icons.school_rounded,
        tone: Tone.primary,
        title: '반 바꾸기',
        subtitle: course == null ? '반을 골라 주세요' : '${course!.name} · 기록은 반마다 따로 보관돼요',
        onTap: () => showCoursePickerSheet(context, ref),
      ),
      (
        icon: Icons.person_rounded,
        tone: Tone.accent,
        title: '내 이름',
        subtitle: name.isEmpty ? '본명을 적어 주세요' : '$name · 반장·총무가 출석부에서 이 이름으로 봐요',
        onTap: () async {
          final v = await showTextInputDialog(
            context,
            title: '내 이름',
            initialValue: name,
            label: '이름',
            hint: '예: 홍길동',
            helper: nameHelper,
          );
          if (v != null) await ref.read(myNameProvider.notifier).set(v);
        },
      ),
      if (needCode)
        (
          icon: Icons.badge_rounded,
          tone: Tone.warm,
          title: '반장·총무 코드 넣기',
          subtitle: '관리자에게 받은 숫자 4자리를 넣으면 출석부를 볼 수 있어요',
          onTap: () => askLeaderCode(context, ref),
        ),
      (
        icon: Icons.history_rounded,
        tone: Tone.accent,
        title: '지난 출석부',
        subtitle: pastCount == 0 ? '전에 들은 반의 체크표를 모아 봐요' : '$pastCount개 · 전에 들은 반의 체크표를 봐요',
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PastBooksScreen())),
      ),
      (
        icon: Icons.save_alt_rounded,
        tone: Tone.primary,
        title: '기록 저장·불러오기',
        subtitle: '폰을 바꾸거나 앱을 다시 깔 때 기록을 옮겨요',
        onTap: () => showBackupSheet(context),
      ),
      (
        icon: Icons.description_rounded,
        tone: Tone.success,
        title: '기록요령 보기',
        subtitle: '출석·성경·새벽기도 등 적는 방법',
        onTap: () => showGuideSheet(context, course),
      ),
      (
        icon: Icons.palette_rounded,
        tone: Tone.warm,
        title: '테마',
        subtitle: theme.label,
        onTap: () => _showThemeSheet(context),
      ),
      if (kIsWeb)
        (
          icon: Icons.add_to_home_screen_rounded,
          tone: Tone.warm,
          title: '홈 화면에 추가하는 방법',
          subtitle: '앱처럼 아이콘으로 열고, 기록을 안전하게 지켜요',
          onTap: () => showInstallGuideSheet(context),
        ),
      (
        icon: Icons.admin_panel_settings_rounded,
        tone: Tone.neutral,
        title: '관리자 모드',
        subtitle: '반·일정표·체크 항목 고치기 (관리자만)',
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AdminScreen())),
      ),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 8, AppLayout.sidePadding, 24),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = rows[i];
        return SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: r.onTap,
          child: Row(
            children: [
              IconBubble(icon: r.icon, tone: r.tone, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    MutedText(r.subtitle, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.palette.hint),
            ],
          ),
        );
      },
    );
  }

  void _showThemeSheet(BuildContext context) {
    showAppSheet<void>(
      context,
      builder: (sheet) => Consumer(
        builder: (context, ref, _) {
          final selected = ref.watch(themeIdProvider);
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 0, AppLayout.sidePadding, 16),
            children: [
              const SheetLabel('테마'),
              for (final id in AppThemeId.values)
                ListTile(
                  onTap: () {
                    ref.read(themeIdProvider.notifier).select(id);
                    Navigator.pop(sheet);
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: _Swatch(palette: id.palette),
                  title: Text(id.label),
                  subtitle: Text(id.description),
                  trailing: id == selected ? Icon(Icons.check_rounded, color: context.palette.primary) : null,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 테마 미리보기 동그라미 (그 테마 팔레트의 색)
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.background,
        border: Border.all(color: palette.primary, width: 8),
      ),
    );
  }
}

/// 기록요령 글 보기
void showGuideSheet(BuildContext context, Course? course) {
  final text = course?.guide.trim() ?? '';
  showAppSheet<void>(
    context,
    scrollable: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 0, AppLayout.sidePadding, 24),
        children: [
          const CardHeader(icon: Icons.description_rounded, title: '기록요령', tone: Tone.success),
          const SizedBox(height: 16),
          if (text.isEmpty)
            const MutedText('아직 기록요령이 없어요.')
          else
            SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.6)),
        ],
      ),
    ),
  );
}
