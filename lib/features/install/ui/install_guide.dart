import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout.dart';
import '../../../app/sheets.dart';
import '../../../app/widgets.dart';
import '../../../core/web_env.dart';

/// 이번에 열었을 때 안내 띠를 닫았는지 (다시 열면 또 보여요. 중요한 안내라서요)
final _bannerClosedProvider = StateProvider<bool>((ref) => false);

/// 웹을 브라우저 탭에서 열었을 때 맨 위에 보이는 '홈 화면에 추가' 안내 띠
class InstallBanner extends ConsumerWidget {
  const InstallBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isBrowserTab || ref.watch(_bannerClosedProvider)) return const SizedBox.shrink();
    final p = context.palette;
    return Material(
      color: p.warmSoft,
      child: InkWell(
        onTap: () => showInstallGuideSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 10, 4, 10),
          child: Row(
            children: [
              Icon(Icons.add_to_home_screen_rounded, color: p.warm),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '홈 화면에 추가해서 그 아이콘으로 써 주세요. 브라우저에서 쓰면 기록이 지워질 수 있어요.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
              TextButton(onPressed: () => showInstallGuideSheet(context), child: const Text('방법')),
              IconButton(
                tooltip: '닫기',
                onPressed: () => ref.read(_bannerClosedProvider.notifier).state = true,
                icon: Icon(Icons.close_rounded, color: p.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 홈 화면에 추가하는 방법 (아이폰 사파리 / 안드로이드 크롬)
void showInstallGuideSheet(BuildContext context) {
  final apple = isAppleDevice;
  final steps = apple
      ? const [
          '사파리로 이 페이지를 열어요. (카카오톡 안에서 열렸다면 오른쪽 아래 ⋯ → "Safari로 열기")',
          '아래쪽(또는 위쪽)의 공유 버튼 □↑ 을 눌러요.',
          '목록을 올려서 "홈 화면에 추가"를 누르고, 오른쪽 위 "추가"를 눌러요.',
          '홈 화면에 생긴 하나님앞에서 아이콘으로 열어요. 반은 처음 한 번 다시 골라요.',
        ]
      : const [
          '크롬으로 이 페이지를 열어요.',
          '오른쪽 위 ⋮ 메뉴를 눌러요.',
          '"홈 화면에 추가" 또는 "앱 설치"를 누르고 "설치"를 눌러요.',
          '홈 화면에 생긴 하나님앞에서 아이콘으로 열어요.',
        ];
  showAppSheet<void>(
    context,
    builder: (_) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(AppLayout.sidePadding, 0, AppLayout.sidePadding, 16),
      children: [
        CardHeader(
          icon: Icons.add_to_home_screen_rounded,
          title: apple ? '아이폰 홈 화면에 추가하기' : '홈 화면에 추가하기',
          tone: Tone.warm,
        ),
        const SizedBox(height: 16),
        for (final (i, s) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}.',
                    style: TextStyle(fontWeight: FontWeight.w800, color: context.palette.warm),
                  ),
                ),
                Expanded(child: Text(s, style: const TextStyle(fontSize: 15, height: 1.5))),
              ],
            ),
          ),
        const SizedBox(height: 4),
        const MutedText(
          '체크 기록은 이 폰에만 저장돼요. 브라우저의 방문 기록·웹사이트 데이터를 지우면 기록도 지워지니 주의해 주세요.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
      ],
    ),
  );
}
