import 'dart:convert';

import 'package:crypto/crypto.dart';

/// NIP-01 event primitives.
///
/// Ported from the LaWallet POS reference (`lib/data/nostr/event.dart`), which
/// is already golden-vector tested against real relays.
class NostrEvent {
  const NostrEvent({
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    this.id,
    this.sig,
  });

  factory NostrEvent.fromJson(Map<String, dynamic> json) => NostrEvent(
    id: json['id'] as String?,
    pubkey: json['pubkey'] as String,
    createdAt: json['created_at'] as int,
    kind: json['kind'] as int,
    tags: (json['tags'] as List)
        .map((t) => (t as List).map((e) => e.toString()).toList())
        .toList(),
    content: json['content'] as String? ?? '',
    sig: json['sig'] as String?,
  );

  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String? id;
  final String? sig;

  /// The canonical serialization the event id is derived from:
  /// `[0, pubkey, created_at, kind, tags, content]` as compact JSON.
  static String serialize({
    required String pubkey,
    required int createdAt,
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) => jsonEncode([0, pubkey, createdAt, kind, tags, content]);

  /// Event id = `sha256(serialization)`, lowercase hex.
  static String computeId({
    required String pubkey,
    required int createdAt,
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) => sha256
      .convert(
        utf8.encode(
          serialize(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: kind,
            tags: tags,
            content: content,
          ),
        ),
      )
      .toString();

  String get computedId => computeId(
    pubkey: pubkey,
    createdAt: createdAt,
    kind: kind,
    tags: tags,
    content: content,
  );

  /// First value of the first tag named [name], or null.
  String? tagValue(String name) {
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == name) {
        return tag.length > 1 ? tag[1] : null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id ?? computedId,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    if (sig != null) 'sig': sig,
  };
}
