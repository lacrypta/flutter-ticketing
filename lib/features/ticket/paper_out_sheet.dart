import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../../data/printer/printer_channel.dart';
import '../../ui/components/lc_buttons.dart';
import '../../ui/components/lc_surface.dart';

/// The roll ran out while a voucher was printing.
///
/// The benefit is already consumed, so the attendee is owed a whole slip, not
/// the stub that came out. This holds the door until staff load a roll and
/// [reprint] lays the full voucher out again from the top.
///
/// Returns null once a reprint came out clean, otherwise the error still
/// standing — [PrinterChannel.paperOut] if staff gave up on the printer — so
/// the caller can fall back to the on-screen slip.
Future<String?> showPaperOutSheet(
  BuildContext context, {
  required String gift,
  required Future<String?> Function() reprint,
}) async {
  final outcome = await showModalBottomSheet<({String? error})>(
    context: context,
    isScrollControlled: true,
    // A stray tap on the backdrop must not throw away the reprint.
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaperOutSheet(gift: gift, reprint: reprint),
  );
  return outcome == null ? PrinterChannel.paperOut : outcome.error;
}

class _PaperOutSheet extends StatefulWidget {
  const _PaperOutSheet({required this.gift, required this.reprint});

  final String gift;
  final Future<String?> Function() reprint;

  @override
  State<_PaperOutSheet> createState() => _PaperOutSheetState();
}

class _PaperOutSheetState extends State<_PaperOutSheet> {
  bool _busy = false;
  bool _stillOut = false;

  Future<void> _reprint() async {
    setState(() => _busy = true);
    final error = await widget.reprint();
    if (!mounted) return;
    // Out again: the roll is not seated or the cover is open. Stay put so the
    // next try is one tap away.
    if (error == PrinterChannel.paperOut) {
      setState(() {
        _busy = false;
        _stillOut = true;
      });
      return;
    }
    Navigator.of(context).pop((error: error));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Container(
        decoration: const BoxDecoration(
          color: LcColors.surface2,
          borderRadius: BorderRadius.vertical(top: LcRadius.sheet),
          border: Border(top: BorderSide(color: LcColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(
          LcSpace.lg,
          LcSpace.xl,
          LcSpace.lg,
          LcSpace.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LcEyebrow('sin papel', color: LcColors.amber),
              const SizedBox(height: LcSpace.sm),
              Text('Se cortó el cupón', style: LcType.h2),
              const SizedBox(height: LcSpace.md),
              Text(
                'Cargá un rollo nuevo y reimprimí el cupón de '
                '${widget.gift} completo. Si salió un pedazo, descartalo.',
                style: LcType.bodyMuted,
              ),
              if (_stillOut) ...[
                const SizedBox(height: LcSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.triangleAlert,
                      size: 16,
                      color: LcColors.amber,
                    ),
                    const SizedBox(width: LcSpace.sm),
                    Expanded(
                      child: Text(
                        'Sigue sin papel. Revisá que el rollo esté bien '
                        'puesto y la tapa cerrada.',
                        style: LcType.notice,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: LcSpace.lg),
              LcPrimaryButton(
                label: _busy ? 'Imprimiendo…' : 'Reimprimir cupón',
                icon: LucideIcons.printer,
                busy: _busy,
                onPressed: _reprint,
              ),
              const SizedBox(height: LcSpace.sm),
              LcSecondaryButton(
                label: 'Mostrar en pantalla',
                onPressed: _busy
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop((error: PrinterChannel.paperOut)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
