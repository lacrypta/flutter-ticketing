import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'nostr_signer.dart';
import 'npub.dart';

/// The device's own Nostr identity, used to sign NIP-98 request auth.
///
/// The key is generated once on first use and never leaves the device. It
/// identifies **the terminal**, not the staff member — a LaWallet card can
/// reveal its holder's npub but cannot sign, so card taps can never be the
/// source of request auth.
///
/// Stored in [FlutterSecureStorage] (Keychain / EncryptedSharedPreferences),
/// deliberately *not* `shared_preferences`. The LaWallet POS reference keeps
/// its key in plain SharedPreferences despite documenting otherwise; that file
/// is world-readable to root and lands in device backups.
class DeviceIdentity {
  DeviceIdentity({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _privateKeyKey = 'device_nostr_private_key';

  final FlutterSecureStorage _storage;

  String? _cachedPrivate;
  String? _cachedPublic;

  /// The private key (64 hex chars), generating and persisting one on first
  /// call.
  Future<String> privateKey() async {
    final cached = _cachedPrivate;
    if (cached != null) return cached;

    final stored = await _storage.read(key: _privateKeyKey);
    if (stored != null && stored.length == 64) {
      return _cachedPrivate = stored;
    }

    final generated = randomHex32();
    await _storage.write(key: _privateKeyKey, value: generated);
    return _cachedPrivate = generated;
  }

  /// The x-only public key (64 hex chars).
  Future<String> publicKeyHex() async =>
      _cachedPublic ??= derivePublicKey(await privateKey());

  /// The public key as `npub1…`, for display and registration.
  Future<String> npub() async => hexToNpub(await publicKeyHex());

  /// Returns the private key only if one already exists — used by the NIP-98
  /// interceptor so that merely sending a request never silently mints an
  /// identity.
  Future<String?> existingPrivateKey() async {
    final cached = _cachedPrivate;
    if (cached != null) return cached;
    final stored = await _storage.read(key: _privateKeyKey);
    if (stored != null && stored.length == 64) return _cachedPrivate = stored;
    return null;
  }

  /// Destroys the identity. The device must be re-registered server-side
  /// afterwards, so this is a Settings action with a confirmation, never
  /// automatic.
  Future<void> reset() async {
    await _storage.delete(key: _privateKeyKey);
    _cachedPrivate = null;
    _cachedPublic = null;
  }
}
