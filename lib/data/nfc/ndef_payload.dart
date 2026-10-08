import 'dart:convert';
import 'dart:typed_data';

import 'package:nfc_manager/ndef_record.dart';

import '../../core/error/app_exception.dart';

/// NFC Forum URI identifier codes. The first payload byte selects a prefix
/// so the rest of the record can stay short.
const List<String> _uriPrefixes = <String>[
  '',
  'http://www.',
  'https://www.',
  'http://',
  'https://',
  'tel:',
  'mailto:',
  'ftp://anonymous:anonymous@',
  'ftp://ftp.',
  'ftps://',
  'sftp://',
  'smb://',
  'nfs://',
  'ftp://',
  'dav://',
  'news:',
  'telnet://',
  'imap:',
  'rtsp://',
  'urn:',
  'pop:',
  'sip:',
  'sips:',
  'tftp:',
  'btspp://',
  'btl2cap://',
  'btgoep://',
  'tcpobex://',
  'irdaobex://',
  'file://',
  'urn:epc:id:',
  'urn:epc:tag:',
  'urn:epc:pat:',
  'urn:epc:raw:',
  'urn:epc:',
  'urn:nfc:',
];

/// The string a LaWallet card left on the tag: an LNURL, a URL, or the
/// LUD-19 JSON itself.
String cardPayloadFromNdef(NdefMessage? message) {
  if (message == null || message.records.isEmpty) {
    throw const NfcException('La tarjeta está vacía');
  }

  final candidates = <String>[
    for (final record in message.records)
      if (_recordText(record) case final text?) text.trim(),
  ].where((text) => text.isNotEmpty);

  if (candidates.isEmpty) {
    throw const NfcException('La tarjeta no tiene un link');
  }

  for (final text in candidates) {
    final lower = text.toLowerCase();
    if (lower.startsWith('lnurl') ||
        lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('lightning:') ||
        text.startsWith('{')) {
      return text;
    }
  }
  return candidates.first;
}

String? _recordText(NdefRecord record) {
  if (record.typeNameFormat == TypeNameFormat.wellKnown &&
      _isType(record, 0x55)) {
    return _uri(record.payload);
  }
  if (record.typeNameFormat == TypeNameFormat.wellKnown &&
      _isType(record, 0x54)) {
    return _text(record.payload);
  }
  if (record.typeNameFormat == TypeNameFormat.absoluteUri) {
    final type = _utf8(record.type);
    if (type.startsWith('http://') || type.startsWith('https://')) return type;
    final payload = _utf8(record.payload);
    return payload.isEmpty ? null : payload;
  }
  if (record.typeNameFormat == TypeNameFormat.media) {
    return _utf8(record.payload);
  }
  final payload = _utf8(record.payload);
  return payload.isEmpty ? null : payload;
}

bool _isType(NdefRecord record, int byte) =>
    record.type.length == 1 && record.type.first == byte;

String? _uri(Uint8List payload) {
  if (payload.isEmpty) return null;
  final code = payload.first;
  final prefix = code < _uriPrefixes.length ? _uriPrefixes[code] : '';
  return '$prefix${_utf8(payload.sublist(1))}';
}

String? _text(Uint8List payload) {
  if (payload.isEmpty) return null;
  final status = payload.first;
  final langLength = status & 0x3F;
  if (payload.length <= 1 + langLength) return null;
  return _utf8(payload.sublist(1 + langLength));
}

String _utf8(Uint8List bytes) => utf8.decode(bytes, allowMalformed: true);
