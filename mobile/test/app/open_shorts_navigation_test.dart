import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vtube/app/main_shell.dart';
import 'package:vtube/app/routes.dart';

/// Shorts là 1 tab của StatefulShellRoute. Mở Shorts từ màn nằm ngoài thanh điều hướng
/// (Trang kênh, Kết quả tìm kiếm, Nhật ký xem, Thông báo...) phải dùng context.go:
/// context.push sẽ đẩy cả shell lên lần nữa, go_router báo "GlobalKey was used multiple times"
/// và màn Shorts không hiện ra.

/// Màn giả thay cho ShortsScreen: ghi lại điều kiện ShortsScreen dùng để quyết định có phát video.
class _ShortsProbe extends StatefulWidget {
  final int? start;
  final List<String> log;
  const _ShortsProbe({super.key, this.start, required this.log});

  @override
  State<_ShortsProbe> createState() => _ShortsProbeState();
}

class _ShortsProbeState extends State<_ShortsProbe> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabActive = ShortsTabScope.of(context);
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    widget.log.add('start=${widget.start} active=${tabActive && routeCurrent}');
  }

  @override
  Widget build(BuildContext context) => Text('SHORTS start=${widget.start}');
}

void main() {
  testWidgets('Từ Trang kênh mở Shorts bằng go(shortsAt): sang tab Shorts, đúng short và đang phát', (tester) async {
    final log = <String>[];
    late StatefulNavigationShell shell;
    final router = GoRouter(
      navigatorKey: GlobalKey<NavigatorState>(),
      initialLocation: AppRoutes.home,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, nav) {
            shell = nav;
            return ShortsTabScope(isActive: nav.currentIndex == 1, child: Scaffold(body: nav));
          },
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: AppRoutes.home, builder: (_, __) => const Text('HOME'))]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: AppRoutes.shorts,
                builder: (_, state) {
                  final start = int.tryParse(state.uri.queryParameters['start'] ?? '');
                  return _ShortsProbe(key: ValueKey('shorts-$start'), start: start, log: log);
                },
              ),
            ]),
          ],
        ),
        GoRoute(path: '/channel/:id', builder: (_, __) => const Scaffold(body: Text('CHANNEL'))),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    router.push(AppRoutes.channel(1));
    await tester.pumpAndSettle();
    expect(find.text('CHANNEL'), findsOneWidget);

    router.go(AppRoutes.shortsAt(35));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(shell.currentIndex, 1);
    expect(find.text('SHORTS start=35'), findsOneWidget);
    expect(log.last, 'start=35 active=true');
  });

  test('Không màn nào mở Shorts bằng context.push(AppRoutes.shortsAt(...))', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'push(Replacement)?\(\s*AppRoutes\.shortsAt').hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Shorts là tab của shell, hãy dùng context.go(AppRoutes.shortsAt(id))');
  });
}
