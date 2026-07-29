import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/lc_colors.dart';
import '../../core/theme/lc_metrics.dart';
import '../../core/theme/lc_typography.dart';
import '../../data/api/api_providers.dart';

import '../../data/settings/settings_repository.dart';
import '../../ui/components/lc_buttons.dart';
import '../../ui/components/lc_screen.dart';
import '../../ui/components/lc_surface.dart';
import '../../ui/gallery/design_gallery.dart';

/// The device's npub, generated on first read.
final deviceNpubProvider = FutureProvider<String>(
  (ref) => ref.watch(deviceIdentityProvider).npub(),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final npub = ref.watch(deviceNpubProvider);

    return LcScreen(
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: LcSpace.md),
          const LcEyebrow('dispositivo'),
          const SizedBox(height: LcSpace.sm),
          Text('Ajustes', style: LcType.h1),

          const _SectionLabel('Servidor'),
          _BaseUrlCard(current: settings.eventsBaseUrl),

          const _SectionLabel('Identidad del dispositivo'),
          npub.when(
            loading: () => const LcCard(child: Text('Generando clave…')),
            error: (error, _) =>
                LcCard(child: Text('$error', style: LcType.notice)),
            data: (value) => _NpubCard(npub: value),
          ),

          const SizedBox(height: LcSpace.sm),
          LcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Firmar con NIP-98', style: LcType.h3),
                          const SizedBox(height: 4),
                          Text(
                            'Agrega Authorization: Nostr a cada pedido.',
                            style: LcType.caption,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.nip98Enabled,
                      onChanged: (value) => ref
                          .read(settingsProvider.notifier)
                          .setNip98Enabled(value),
                    ),
                  ],
                ),
                const SizedBox(height: LcSpace.sm),
                // Honest about the current state of the world: turning this on
                // today changes nothing, because the check-in route validates
                // dashboard JWTs only.
                Text(
                  'El backend todavía no valida NIP-98 en /api/checkin. '
                  'Activalo recién cuando la npub de arriba esté registrada '
                  'en users y el endpoint use authenticateRequestOrNip98.',
                  style: LcType.caption,
                ),
              ],
            ),
          ),

          const _SectionLabel('Impresora'),
          LcCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final choice in PrinterBackendChoice.values)
                  RadioListTile<PrinterBackendChoice>(
                    value: choice,
                    // ignore: deprecated_member_use
                    groupValue: settings.printerBackend,
                    // ignore: deprecated_member_use
                    onChanged: (value) => value == null
                        ? null
                        : ref
                              .read(settingsProvider.notifier)
                              .setPrinterBackend(value),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: LcColors.accent,
                    title: Text(_printerLabel(choice), style: LcType.body),
                  ),
                const SizedBox(height: LcSpace.sm),
                Text(
                  'La impresión llega en M2. ZCS funciona sólo en terminales '
                  'Ciontek; Bluetooth ESC/POS funciona en Android y iOS.',
                  style: LcType.caption,
                ),
              ],
            ),
          ),

          const _SectionLabel('Diagnóstico'),
          LcSecondaryButton(
            label: 'Sistema de diseño',
            icon: LucideIcons.palette,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DesignGallery()),
            ),
          ),
          const SizedBox(height: LcSpace.xxl),
        ],
      ),
    );
  }

  static String _printerLabel(PrinterBackendChoice choice) => switch (choice) {
    PrinterBackendChoice.auto => 'Automático',
    PrinterBackendChoice.zcs => 'Terminal ZCS (Ciontek)',
    PrinterBackendChoice.bluetooth => 'Bluetooth ESC/POS',
    PrinterBackendChoice.none => 'Sin impresora',
  };
}

/// Retarget the app at a different backend without rebuilding.
///
/// Needed to point a device at a local `next dev` server, and at a staging
/// deployment later. The value is persisted by [SettingsRepository]; `dioProvider`
/// watches settings, so saving rebuilds the HTTP client immediately.
///
/// Note a plain-HTTP URL only works in a **debug** build — release keeps
/// Android's default cleartext ban (see `src/debug/res/xml/network_security_config.xml`).
class _BaseUrlCard extends ConsumerStatefulWidget {
  const _BaseUrlCard({required this.current});

  final String current;

  @override
  ConsumerState<_BaseUrlCard> createState() => _BaseUrlCardState();
}

class _BaseUrlCardState extends ConsumerState<_BaseUrlCard> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _dirty => _controller.text.trim() != widget.current;

  Future<void> _save() async {
    final value = _controller.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (value.isEmpty) return;
    await ref
        .read(settingsProvider.notifier)
        .update(ref.read(settingsProvider).copyWith(eventsBaseUrl: value));
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Servidor: $value')));
  }

  Future<void> _reset() async {
    _controller.text = AppConfig.eventsBaseUrl;
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return LcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LcEyebrow('base url'),
          const SizedBox(height: LcSpace.sm),
          TextField(
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            style: LcType.body,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              filled: true,
              fillColor: LcColors.surface1,
              contentPadding: EdgeInsets.symmetric(
                horizontal: LcSpace.md,
                vertical: LcSpace.md,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: LcRadius.cardAll,
                borderSide: BorderSide(color: LcColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: LcRadius.cardAll,
                borderSide: BorderSide(color: LcColors.accent),
              ),
            ),
          ),
          const SizedBox(height: LcSpace.sm),
          Row(
            children: [
              Expanded(
                child: LcSecondaryButton(
                  label: 'Guardar',
                  icon: LucideIcons.check,
                  height: LcTouch.small,
                  onPressed: _dirty ? _save : null,
                ),
              ),
              const SizedBox(width: LcSpace.sm),
              Expanded(
                child: LcSecondaryButton(
                  label: 'Restaurar',
                  icon: LucideIcons.rotateCcw,
                  height: LcTouch.small,
                  onPressed: widget.current == AppConfig.eventsBaseUrl
                      ? null
                      : _reset,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The device npub, as text *and* a QR — whoever registers the device is
/// usually at a laptop, and scanning beats transcribing 63 characters.
class _NpubCard extends StatelessWidget {
  const _NpubCard({required this.npub});

  final String npub;

  @override
  Widget build(BuildContext context) {
    return LcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LcEyebrow('npub de este dispositivo'),
          const SizedBox(height: LcSpace.md),
          Center(
            child: Container(
              padding: const EdgeInsets.all(LcSpace.sm),
              decoration: const BoxDecoration(
                color: LcColors.textPrimary,
                borderRadius: LcRadius.cardAll,
              ),
              child: QrImageView(
                data: npub,
                size: 176,
                backgroundColor: LcColors.textPrimary,
                // Quiet zone is drawn by the padding above, not by the widget.
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: LcSpace.md),
          SelectableText(
            npub,
            style: LcType.caption.copyWith(color: LcColors.textDim),
          ),
          const SizedBox(height: LcSpace.sm),
          LcSecondaryButton(
            label: 'Copiar npub',
            icon: LucideIcons.copy,
            height: LcTouch.small,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: npub));
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('npub copiada')));
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: LcSpace.xl, bottom: LcSpace.sm),
    child: Row(
      children: [
        LcEyebrow(text, color: LcColors.accent),
        const SizedBox(width: LcSpace.sm),
        const Expanded(child: Divider(color: LcColors.borderSubtle)),
      ],
    ),
  );
}
