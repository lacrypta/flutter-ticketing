# La Crypta Ticketing

Native door-scanner / POS for La Crypta events. Scan a ticket QR, check the
attendee in, hand out their benefits, print a receipt.

**Android-first, iOS-ready.** Replaces the React PWA at
[`lacrypta/ticketing`](https://github.com/lacrypta/ticketing), which can only
print from inside a host Android WebView and has no offline handling.

| | |
|---|---|
| **Backend** | `https://events.lacrypta.ar` (the La Crypta CRM) |
| **Stack** | Flutter 3.29+ · Riverpod 3 (hand-written providers) · go_router |
| **Min SDK** | Android 24 · iOS 15.5 |

---

## Why native

Three things the PWA structurally cannot do:

1. **Survive bad wifi.** Venue connectivity dies mid-queue. A durable outbox
   replays check-ins and gift claims when the network returns.
2. **Talk to a printer directly.** No WebView host, no `window.Android.print`
   bridge — the app drives the thermal printer itself.
3. **Read NFC.** LaWallet card taps as a second credential path alongside QR.

---

## Status

| Milestone | What | State |
|---|---|---|
| **M0** | Token parser, NIP-98, nostr signing, theme, components | ✅ done |
| **M1** | API client + all check-in screens | ✅ done |
| **M2** | Printing (ZCS terminal + Bluetooth ESC/POS) | ⬜ next |
| **M3** | Offline outbox + sync | ⬜ |
| **M4** | Staff PIN lock, NIP-98 wired on | ⬜ (ships dark) |
| **M5** | NFC card read → npub → ticket lookup | ⬜ (blocked, see below) |

Today the app is a **complete, better-looking replacement for the web app** on
any Android phone: scan → validate → check in → benefits → history.

---

## Run it

```bash
flutter pub get
flutter run
```

Point it at another backend without touching source:

```bash
flutter run --dart-define=EVENTS_BASE_URL=https://staging.lacrypta.ar
```

You can also change it at runtime in **Ajustes → Servidor**, which is the
quicker loop when testing.

### Against a local lacrypta-crm

```bash
flutter run --dart-define=EVENTS_BASE_URL=http://10.0.2.2:3100
```

`10.0.2.2` is the Android emulator's alias for the host loopback. Plain HTTP
only works in a **debug** build — `src/debug/res/xml/network_security_config.xml`
exempts `10.0.2.2` / `localhost` / `127.0.0.1` and nothing else. Release builds
keep Android's default cleartext ban.

The QR parser rejects hosts outside `*.lacrypta.ar`, so a local `/ticket/<uuid>`
URL will not scan — paste the bare ticket code into **Ingresar código** instead.

Tests (no device needed):

```bash
flutter test
```

---

## The API

Four endpoints, no SDK. Contract read from the CRM's own route handlers, not
inferred from the web client.

| Method | Path | Returns |
|---|---|---|
| `GET` | `/api/checkin/{code}` | attendee, event, checked-in state, `staff_required`, ticket inventory |
| `POST` | `/api/checkin/{code}` | `checked_in` \| `already_checked_in` — **idempotent** |
| `GET` | `/api/checkin/{code}/gifts` | `{gift_data: {item_key: remaining}}` |
| `POST` | `/api/checkin/{code}/gifts/consume` | remaining counts — **not idempotent** |

Error states the web app has no screen for, and this app does:

- `409 event_ended` — the event is over, so the ticket expired.
- `401/403 staff_required` — the event requires a manager to check people in.
  **The attendee is fine**; the device is not authorised. Showing "invalid"
  here would turn away someone holding a valid ticket.

Check-in is **per entrada, not per attendee**: a buyer with four tickets can be
scanned four times, and each scan claims only its own item. The UI surfaces the
inventory so a repeat name doesn't look like a bug.

### QR format

```
https://<subdomain>.lacrypta.ar/ticket/<TOKEN>
https://<subdomain>.lacrypta.ar/checkin/<TOKEN>
```

A bare string with no `/` and no whitespace is also accepted as a raw token.

Two behaviours are ported deliberately and covered by tests: **the apex domain
`lacrypta.ar` is rejected** (the check is `endsWith('.lacrypta.ar')`), and query
strings and fragments are discarded. See `lib/domain/ticket/ticket_token.dart`.

---

## Security, honestly

**For events without `staff_checkin_required`, the ticket code in the URL is the
only credential.** No header, no key, no cookie. Anyone who can reach the host
and knows a code can check it in and consume its gifts. That is the server's
design; this client cannot fix it.

The app implements **NIP-98** (`kind 27235`) request signing with a device-held
nostr key in the platform keystore, and ships it **disabled by default** —
because it currently does nothing. See below.

Local scan history holds attendee names and live ticket codes. It is in-memory
today; **before M3 makes it durable**, decide on `sqlcipher_flutter_libs` plus a
post-event retention policy. A local PIN stops someone picking up an unattended
terminal at the bar; it does not stop `adb`, a stolen device, or a backup
extraction.

---

## Backend asks

Two changes we cannot make from here.

**1. Let NIP-98 authenticate check-in.** `lib/auth-server.ts` already has a
complete kind-27235 verifier and an `authenticateRequestOrNip98` helper — but
`app/api/checkin/[code]/route.ts` calls plain `authenticateRequest` (dashboard
JWT only). Changing that one call, plus inserting this device's pubkey into
`users` with a manager-level org membership, is what makes staff-required events
checkable from the app. Until then, **any event with
`staff_checkin_required = true` cannot be checked in from this app at all.**

The CSRF gate is already compatible: `requireDashboardMutationSecurity` exempts
`Authorization: Nostr` when no `Origin` header is sent, which is exactly what a
native client does.

Get the device npub from **Ajustes → Identidad del dispositivo** (shown as text
and as a QR).

**2. Fix `loadCheckinTicket` — `/gifts` currently 404s for every ticket.**
Verified against a live local CRM: `GET /api/checkin/{code}` returns `200` for a
code that `GET /api/checkin/{code}/gifts` rejects with `404 Ticket inválido`.
Two independent defects in `lib/checkin-tickets.ts`:

- It resolves `code` against **`orders.ticket_code` only**, while real per-ticket
  codes live on `items.ticket_code`. `resolveCheckinContext` in the same file
  already handles both — `loadCheckinTicket` needs the same second branch.
- Its embed is a bare `events (...)`, where `resolveCheckinContext` uses the
  explicit `events!orders_org_event_fkey (...)`. With two FK paths from `orders`
  to `events`, PostgREST cannot disambiguate and the embed fails — so even an
  order-level code 404s on the route's `!row.events` guard. The failure is
  silent because the query destructures `{ data }` and drops `error`.

Until that lands, this app treats a 404 from `/gifts` as "no benefits" rather
than an error, so a successful check-in never renders "Ticket inválido"
underneath itself. The React PWA has no such guard and shows the error.

**3. Make gift consume idempotent.** It currently isn't, and stock is not
reserved. Two devices offline can both promise the last pizza. Unfixable
client-side — it needs a server-side idempotency key.

---

## NFC (M5) — and why it's last

The intended flow is: tap a LaWallet card → read its NDEF URL → request that URL
with an action header → get the holder's npub → look up their ticket.

**Two links in that chain do not exist yet.** The `getNpub` action is not
implemented on any LaWallet backend (the shipping action is `info`), and there
is no npub→ticket endpoint at all. Both are isolated behind
`lib/core/config/lawallet_config.dart` so they become a one-file change once the
contracts are agreed. M5 ships first as a diagnostics-only "read a card, show me
the npub" tool.

Note also that a card can *reveal* an npub but cannot **sign** — the private key
is not on the card. NIP-98 request auth therefore always comes from the device
key, never from a tap.

### iOS is a secondary door

Android runs an always-on reader (`NfcAdapter.enableReaderMode`), so a tap is
captured from any screen and never hijacked by the system Tag viewer. **iOS
cannot do this** — Core NFC requires a user-initiated session with a system
modal sheet every time. On iOS, NFC is an explicit button press. Plan staffing
accordingly: iPhones are backup scanners, not the primary door.

---

## Printing (M2)

Two backends behind one `PrinterBackend` interface, chosen at runtime and
overridable in Ajustes:

- **ZCS SmartPos** — the built-in printer on Ciontek terminals (Z92, CS30Pro),
  via a platform channel. **Android only.**
- **Bluetooth ESC/POS** — `print_bluetooth_thermal` + `esc_pos_utils_plus`.
  Android and iOS.

The ZCS SDK jars are **proprietary and not redistributable**, so they are
gitignored. Drop `SmartPos_*.jar` and `zxing-core-*.jar` into
`android/app/libs/` to build that path; without them the resolver falls back to
Bluetooth.

Both backends render from one `Receipt` model, so the output is identical.

---

## Design

Dark-only, brutalist-terminal: near-black ground, hairline borders instead of
drop shadows, huge tight-set type, one acid-lime accent doing all the
signalling, and a lime perspective grid receding to a horizon.

Brand assets are **bundled**, not hot-linked: Standerd (8 weights) and the
isotype, from [`lacrypta/branding`](https://github.com/lacrypta/branding) (MIT).

Three constraints the code encodes, each found by measuring rather than assuming:

- **Standerd's max real weight is 800.** The brand disables synthetic bold, so
  asking Flutter for `w900` smears.
- **`FontFeature.tabularFigures()` is a silent no-op** — Standerd has no `tnum`,
  and a `1` is ~57% the width of a `0`. Counters and timestamps use `LcTabular`,
  which slots digits by layout instead.
- **Standerd has no glyph for `₿ ✓ ⌫ ⚡ ★ ∞`.** Use an icon, never the
  character. (The PIN keypad's backspace is the concrete trap.)

Browse the live style guide in-app: **Ajustes → Sistema de diseño**.

---

## Layout

```
lib/
  core/       config, errors, router, theme
  data/       api client, nostr/NIP-98, settings  (all I/O lives here)
  domain/     entities, token parser, use-cases   (pure Dart)
  features/   screens, one folder per flow
  ui/         design system: theme, backdrop, components
```

Dependencies point strictly downward: `features → domain → data → core`.

The ticket flow's nine phases are **one route**, not nine. It is a state
machine — putting the phases on the Navigator would let an operator back into a
stale check-in screen for an entrada that has already been claimed.

---

## Toolchain notes

- **AGP is pinned to 8.9.1**, not the 9.x the Flutter template generates.
  `jni 1.0.1` (pulled in by `path_provider_android`) skips applying
  `kotlin-android` on AGP 9 but still uses a `kotlin {}` block, so the build
  fails. Revisit when `jni` ships a fix.
- **`drift_dev` is pinned exactly to `2.34.0`.** Later versions need
  `analyzer ^13`, which cannot co-resolve with the analyzer `flutter_riverpod`
  drags in through `test`.
- `sqlite3_flutter_libs` is EOL; `package:sqlite3` v3 bundles the natives.

---

## License

MIT — see [LICENSE](LICENSE).
