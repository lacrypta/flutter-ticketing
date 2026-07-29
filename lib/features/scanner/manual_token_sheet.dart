import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../../domain/ticket/ticket_token.dart';
import '../../ui/components/lc_buttons.dart';
import '../../ui/components/lc_surface.dart';

/// Type a ticket code in by hand.
///
/// Not just a test hook — this is the fallback for the things that actually go
/// wrong at a door: a printed QR that's creased or wet, an attendee whose phone
/// screen is cracked across the code, a camera that won't focus under a strobe,
/// or a dead camera entirely. Without it, any of those means turning someone
/// away.
///
/// Input runs through the very same [parseTicketToken] the camera path uses, so
/// this cannot accept anything a scan wouldn't. In particular the host allowlist
/// still applies: a URL on any host other than `*.lacrypta.ar` is rejected, and
/// the operator is told why rather than left staring at a dead button.
class ManualTokenSheet extends StatefulWidget {
  const ManualTokenSheet({super.key});

  /// Returns the parsed token, or null if dismissed.
  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ManualTokenSheet(),
      );

  @override
  State<ManualTokenSheet> createState() => _ManualTokenSheetState();
}

class _ManualTokenSheetState extends State<ManualTokenSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    // Straight to the keyboard — the operator opened this to type.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final token = parseTicketToken(_controller.text);
    if (token == null) {
      setState(() => _error = _explain(_controller.text));
      return;
    }
    Navigator.of(context).pop(token);
  }

  /// Say *why* it was rejected. "Código inválido" on its own leaves the operator
  /// retyping the same thing.
  String _explain(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Ingresá un código.';

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      if (!kTicketQrSchemes.contains(uri.scheme)) {
        return 'Sólo se aceptan enlaces http o https.';
      }
      if (!uri.host.endsWith(kTicketQrHostSuffix)) {
        return 'Ese enlace no es de un subdominio de lacrypta.ar. '
            'Si estás probando contra otro servidor, pegá sólo el código.';
      }
      return 'El enlace tiene que apuntar a /ticket/ o /checkin/.';
    }

    if (trimmed.contains('/')) {
      return 'Eso parece un enlace incompleto. Pegá la URL entera o sólo el código.';
    }
    return 'Un código no puede tener espacios.';
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _controller.text = text.trim();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift clear of the keyboard, which covers this sheet entirely otherwise.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: LcColors.surface2,
          borderRadius: BorderRadius.vertical(top: LcRadius.sheet),
          border: Border(top: BorderSide(color: LcColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(
          LcSpace.lg,
          LcSpace.md,
          LcSpace.lg,
          LcSpace.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LcColors.whiteAlpha(0.18),
                    borderRadius: LcRadius.pillAll,
                  ),
                ),
              ),
              const SizedBox(height: LcSpace.lg),
              const LcEyebrow('sin cámara'),
              const SizedBox(height: LcSpace.sm),
              Text('Ingresar código', style: LcType.h2),
              const SizedBox(height: LcSpace.md),
              Text(
                'Pegá la URL de la entrada o tipeá el código.',
                style: LcType.bodyMuted,
              ),
              const SizedBox(height: LcSpace.md),
              TextField(
                controller: _controller,
                focusNode: _focus,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: LcType.body,
                decoration: InputDecoration(
                  hintText: 'a1b2c3d4-…  o  https://…lacrypta.ar/ticket/…',
                  hintStyle: LcType.caption,
                  filled: true,
                  fillColor: LcColors.surface1,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: LcSpace.md,
                    vertical: LcSpace.md,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: LcRadius.cardAll,
                    borderSide: BorderSide(color: LcColors.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: LcRadius.cardAll,
                    borderSide: BorderSide(color: LcColors.accent),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      LucideIcons.clipboard,
                      size: 18,
                      color: LcColors.textMuted,
                    ),
                    tooltip: 'Pegar',
                    onPressed: _paste,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: LcSpace.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.triangleAlert,
                      size: 16,
                      color: LcColors.amber,
                    ),
                    const SizedBox(width: LcSpace.sm),
                    Expanded(child: Text(_error!, style: LcType.notice)),
                  ],
                ),
              ],
              const SizedBox(height: LcSpace.lg),
              LcPrimaryButton(
                label: 'Validar',
                icon: LucideIcons.ticketCheck,
                onPressed: _submit,
              ),
              const SizedBox(height: LcSpace.sm),
              LcSecondaryButton(
                label: 'Cancelar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
