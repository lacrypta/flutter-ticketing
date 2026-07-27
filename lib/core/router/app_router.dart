import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/scanner/scanner_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/ticket/ticket_controller.dart';
import '../../features/ticket/ticket_flow_screen.dart';

abstract final class Routes {
  static const home = '/';
  static const scan = '/scan';
  static const ticket = '/ticket';
  static const history = '/history';
  static const settings = '/settings';
}

/// Top-level destinations only.
///
/// The ticket flow's nine phases are deliberately **not** routes: they are a
/// state machine, and putting them on the Navigator would let the operator back
/// into a stale check-in screen for an entrada that has already been claimed.
/// `/ticket` is one route that renders whichever phase the controller is in.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => HomeScreen(
          onScan: () => context.push(Routes.scan),
          onHistory: () => context.push(Routes.history),
          onSettings: () => context.push(Routes.settings),
        ),
      ),
      GoRoute(
        path: Routes.scan,
        builder: (context, state) => ScannerScreen(
          onBack: () => context.pop(),
          onToken: (token) {
            // Replace rather than push: backing out of a result should return
            // to home, not re-open a live camera pointed at the same QR.
            unawaited(ref.read(ticketFlowProvider.notifier).open(token));
            context.pushReplacement(Routes.ticket);
          },
        ),
      ),
      GoRoute(
        path: Routes.ticket,
        builder: (context, state) => TicketFlowScreen(
          onExit: () => context.go(Routes.home),
          onScanAgain: () {
            ref.read(ticketFlowProvider.notifier).reset();
            context.pushReplacement(Routes.scan);
          },
          onHistory: () => context.push(Routes.history),
        ),
      ),
      GoRoute(
        path: Routes.history,
        builder: (context, state) => HistoryScreen(
          onBack: () => context.pop(),
          onOpen: (token) {
            unawaited(ref.read(ticketFlowProvider.notifier).open(token));
            context.pushReplacement(Routes.ticket);
          },
        ),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) =>
            SettingsScreen(onBack: () => context.pop()),
      ),
    ],
  );
});

void unawaited(Future<void> future) {
  future.ignore();
}
