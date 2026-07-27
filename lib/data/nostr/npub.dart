import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';

/// NIP-19 `npub` encoding.
///
/// Only needed for display: the API and NIP-98 both use raw hex. Staff read the
/// npub off the Settings screen to register the device, and an npub is far less
/// error-prone to transcribe than 64 hex characters.
const String kNpubHrp = 'npub';

String hexToNpub(String pubkeyHex) {
  final data = _convertBits(hex.decode(pubkeyHex), 8, 5, pad: true);
  return const Bech32Codec().encode(Bech32(kNpubHrp, data));
}

String? npubToHex(String npub) {
  try {
    final decoded = const Bech32Codec().decode(npub);
    if (decoded.hrp != kNpubHrp) return null;
    final bytes = _convertBits(decoded.data, 5, 8, pad: false);
    if (bytes.length != 32) return null;
    return hex.encode(bytes);
  } catch (_) {
    return null;
  }
}

/// Regroups a byte stream from [from]-bit to [to]-bit units, as BIP-173
/// requires. The bech32 package operates on 5-bit groups and does not do this.
List<int> _convertBits(List<int> data, int from, int to, {required bool pad}) {
  var accumulator = 0;
  var bits = 0;
  final result = <int>[];
  final maxValue = (1 << to) - 1;

  for (final value in data) {
    if (value < 0 || value >> from != 0) {
      throw const FormatException('Valor fuera de rango');
    }
    accumulator = (accumulator << from) | value;
    bits += from;
    while (bits >= to) {
      bits -= to;
      result.add((accumulator >> bits) & maxValue);
    }
  }

  if (pad) {
    if (bits > 0) result.add((accumulator << (to - bits)) & maxValue);
  } else if (bits >= from || ((accumulator << (to - bits)) & maxValue) != 0) {
    throw const FormatException('Padding inválido');
  }

  return result;
}

/// `npub1abcd…wxyz` — for showing a key in a constrained space.
String shortenNpub(String npub, {int lead = 10, int tail = 6}) =>
    npub.length <= lead + tail + 1
    ? npub
    : '${npub.substring(0, lead)}…${npub.substring(npub.length - tail)}';
