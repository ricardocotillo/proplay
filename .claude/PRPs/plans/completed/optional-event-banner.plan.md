# Plan: Optional Event Banner

## Summary
Organizers can optionally upload a banner image when creating a session. The image is stored in Firebase Storage, its download URL is saved on the template, copied to the first live session, mirrored to `publicEvents`, and shown on the feed card, the landing "Próximos eventos" card, the public event screen and the session detail screen. No banner → current UI unchanged.

## User Story
As an event organizer, I want to attach an optional banner image to my event, so that my event stands out in the feed.

## Problem → Solution
Feed cards are text-only (`ListTile` + sport icon); landing cards use a fixed per-sport stock image → optional per-event `bannerUrl` rendered on top of the card; stock/icon fallback when absent.

## Metadata
- **Complexity**: Medium
- **Source PRD**: N/A
- **PRD Phase**: N/A
- **Estimated Files**: 12 edits, 1 new widget, 2 test edits

## Decisions (from user)
- Source: upload from device (image_picker → Firebase Storage).
- Placement: feed card (`_EventCard`), landing card (`_EventsGrid`), `PublicEventScreen`, `SessionDetailScreen`.
- Scope: template field, copied to live session (same path as `district` / `format`).
- Out of scope: edit existing events, CSV recurring script column.

---

## UX Design

### Before
```
┌ Card ─────────────────────────┐
│ (●) Pichanga          S/ 15   │
│     Fútbol · Miraflores 8/10  │
└───────────────────────────────┘
```
### After
```
┌ Card ─────────────────────────┐
│ [   banner 16:9 image        ]│  ← only when bannerUrl != null
│ (●) Pichanga          S/ 15   │
│     Fútbol · Miraflores 8/10  │
└───────────────────────────────┘
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Create session form | no image | "Banner (opcional)" picker + preview + remove | Spanish copy |
| Feed card | text only | image on top if present | `Clip.antiAlias` |
| Landing card | stock sport image | `bannerUrl` if present, else stock image | keeps existing fallback |
| `/events/:id`, session detail | no image | hero image if present | |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/models/session_model.dart` | all | Add field to ctor, props, copyWith, toMap, fromMap (mirror `format`) |
| P0 | `lib/models/session_template_model.dart` | 24-170 | Same, mirror `format` |
| P0 | `lib/services/session_service.dart` | 66-93 | `_createFirstLiveSession` copies template → live session |
| P0 | `lib/bloc/create_session/create_session_bloc.dart` | all | Upload orchestration goes here |
| P0 | `lib/screens/create_session_screen.dart` | 20-25, 200-245, 520-545 | Form fields, template build, `BlocProvider` |
| P0 | `functions/src/publicEvents.ts` | 5-10 | `PUBLIC_FIELDS` whitelist; banner must be added or it never reaches `publicEvents` |
| P1 | `lib/services/storage_service.dart` | all | Upload pattern |
| P1 | `lib/screens/group_edit_screen.dart` | 26, 44-57 | `image_picker` usage |
| P1 | `lib/widgets/cached_image.dart` | all | `PlatformCachedImage` (web-safe) |
| P1 | `lib/widgets/events_feed_view.dart` | 231-295 | `_EventCard` |
| P1 | `lib/screens/landing_screen.dart` | 297-365 | `_EventsGrid` card |
| P1 | `lib/screens/public_event_screen.dart` | 55-100 | Details column |
| P1 | `lib/screens/session_detail_screen.dart` | 136-160 | Header `Column` |
| P2 | `test/session_model_test.dart`, `functions/test/publicEvents.test.ts` | all | Test style |

## External Documentation
No external research needed — uses `image_picker` ^1.2.3 and `firebase_storage` already in `pubspec.yaml`.

---

## Patterns to Mirror

### OPTIONAL_FIELD (model)
// SOURCE: lib/models/session_model.dart:154-155, 190-191
```dart
if (district != null) 'district': district,
if (format != null) 'format': format,
...
format: map['format'] as String?,
```

### TEMPLATE → LIVE SESSION COPY
// SOURCE: lib/services/session_service.dart:89-90
```dart
district: template.district,
format: template.format,
```

### PUBLIC PROJECTION WHITELIST
// SOURCE: functions/src/publicEvents.ts:5-10
```ts
const PUBLIC_FIELDS = ['templateId', ..., 'district', 'format', 'g', 'l'] as const;
```

### IMAGE PICK
// SOURCE: lib/screens/group_edit_screen.dart:44-57
```dart
final XFile? pickedFile = await _imagePicker.pickImage(
  source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
```

### STORAGE UPLOAD
// SOURCE: lib/services/storage_service.dart:32-50
```dart
final ref = _storage.ref().child('group_images/$fileName');
final snapshot = await ref.putFile(imageFile);
return await snapshot.ref.getDownloadURL();
```

### BLOC ERROR HANDLING
// SOURCE: lib/bloc/create_session/create_session_bloc.dart:20-31
```dart
emit(CreateSessionLoading());
try { await ...; emit(SessionCreationSuccess()); }
catch (e) { emit(SessionCreationFailure(e.toString())); }
```

### TEST STYLE
// SOURCE: test/session_model_test.dart:25-35 — `baseMap()` + `fromMap` / `toMap` roundtrip, asserts key absent when null.
// SOURCE: functions/test/publicEvents.test.ts — `node:test`, `buildPublicEvent('s1', {...base})`.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/models/session_model.dart` | UPDATE | `bannerUrl` field |
| `lib/models/session_template_model.dart` | UPDATE | `bannerUrl` field |
| `lib/services/session_service.dart` | UPDATE | copy `bannerUrl` to first live session |
| `lib/services/storage_service.dart` | UPDATE | `uploadEventBanner(groupId, XFile)` |
| `lib/bloc/create_session/create_session_bloc.dart` | UPDATE | inject `StorageService`, upload before create |
| `lib/bloc/create_session/create_session_event.dart` | UPDATE | optional `banner` (`XFile?`) on `CreateSessionTemplate` |
| `lib/screens/create_session_screen.dart` | UPDATE | picker UI, pass banner, provide `StorageService` |
| `lib/widgets/event_banner.dart` | CREATE | tiny shared 16:9 `PlatformCachedImage` widget (used by 3 screens) |
| `lib/widgets/events_feed_view.dart` | UPDATE | banner on `_EventCard` |
| `lib/screens/landing_screen.dart` | UPDATE | `bannerUrl ?? stock asset` |
| `lib/screens/public_event_screen.dart` | UPDATE | hero banner |
| `lib/screens/session_detail_screen.dart` | UPDATE | hero banner above header |
| `functions/src/publicEvents.ts` | UPDATE | add `'bannerUrl'` to `PUBLIC_FIELDS` |
| `test/session_model_test.dart`, `functions/test/publicEvents.test.ts` | UPDATE | cover new field |
| `docs/ARCHITECTURE.md` | UPDATE | §7 `bannerUrl` rows, Storage path, public projection list |

## NOT Building
- Editing/removing a banner on existing events or templates.
- `bannerUrl` column in the recurring-events CSV script.
- Image cropping, multiple images, banner on group lists / tickets.
- Deleting the Storage object when an event is deleted.
- A `storage.rules` file in git (none exists today; rules live in the console).

---

## Step-by-Step Tasks

### Task 1: Models
- **ACTION**: Add `final String? bannerUrl;` to `SessionModel` and `SessionTemplateModel`.
- **IMPLEMENT**: ctor param, `props`, `copyWith`, `toMap` (`if (bannerUrl != null) 'bannerUrl': bannerUrl`), `fromMap` (`map['bannerUrl'] as String?`).
- **MIRROR**: OPTIONAL_FIELD.
- **GOTCHA**: `copyWith` uses `??`, so it cannot clear the field; fine (no removal flow).
- **VALIDATE**: `flutter test test/session_model_test.dart`.

### Task 2: Copy to live session
- **ACTION**: In `_createFirstLiveSession` add `bannerUrl: template.bannerUrl,`.
- **MIRROR**: TEMPLATE → LIVE SESSION COPY.
- **GOTCHA**: `getUpcomingSessions*` build `filteredData` whitelists (lines ~108, 161, 231); group lists show no banner, so leave them.
- **VALIDATE**: `flutter analyze`.

### Task 3: Public projection (Cloud Function)
- **ACTION**: Add `'bannerUrl'` to `PUBLIC_FIELDS`.
- **GOTCHA**: Without this the feed/landing/public screen never see the banner. Existing events have no banner, so no backfill needed. Deploy order is by hand: functions before the app ships.
- **VALIDATE**: `(cd functions && npm run build && npm test)`.

### Task 4: StorageService upload
- **ACTION**: Add `Future<String> uploadEventBanner(String groupId, XFile file)`.
- **IMPLEMENT**: path `event_banners/$groupId/${DateTime.now().millisecondsSinceEpoch}.jpg`; `final bytes = await file.readAsBytes(); await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));` then `getDownloadURL()`. Wrap in try/catch and throw `Exception('Failed to upload event banner: $e')` like siblings.
- **IMPORTS**: `package:image_picker/image_picker.dart` (XFile).
- **GOTCHA**: Do NOT use `dart:io` `File` + `putFile` (existing group upload): the app ships on web (proplayapp.com) where `File(path)` fails. `putData` works on all platforms. Unique name per upload so cached URLs don't go stale.
- **VALIDATE**: `flutter analyze`.

### Task 5: Bloc
- **ACTION**: `CreateSessionBloc({required SessionService sessionService, required StorageService storageService})`. Event `CreateSessionTemplate(template, {XFile? banner})`, props include banner.
- **IMPLEMENT**: in handler, after `emit(CreateSessionLoading())`: `var t = event.template; if (event.banner != null) { t = t.copyWith(bannerUrl: await _storageService.uploadEventBanner(t.groupId, event.banner!)); } await _sessionService.createSessionTemplate(t);`
- **MIRROR**: BLOC ERROR HANDLING. Upload failure → `SessionCreationFailure`; no template written.
- **GOTCHA**: `props` in this event is `List<Object>`; use `[template, ?banner]` (null-aware element) or change to `List<Object?>`.
- **VALIDATE**: `flutter analyze`.

### Task 6: Create form UI
- **ACTION**: In `create_session_screen.dart`, state `XFile? _banner; Uint8List? _bannerBytes;`. Above the "Formato" field add a "Banner (opcional)" block: `OutlinedButton.icon` "Elegir imagen" → `_pickBanner()`; when set, show `ClipRRect` 16:9 preview with `Image.memory(_bannerBytes!)` and a `TextButton` "Quitar".
- **IMPLEMENT**: `pickImage(source: gallery, maxWidth: 1600, imageQuality: 85)`, read bytes at pick time. Pass `banner: _banner` in `CreateSessionTemplate`. Provide `StorageService()` at line 23 `BlocProvider`.
- **MIRROR**: IMAGE PICK.
- **GOTCHA**: `Image.file` is not web-safe, use `Image.memory`. Confirm the submit button disables during `CreateSessionLoading` (upload can take seconds). No Firebase calls in the widget.
- **VALIDATE**: manual (see below).

### Task 7: Shared banner widget
- **ACTION**: Create `lib/widgets/event_banner.dart`: `EventBanner({required String url})` → `AspectRatio(16/9)` + `PlatformCachedImage(fit: BoxFit.cover, placeholder and errorWidget: neutral grey box)`.
- **MIRROR**: `lib/widgets/cached_image.dart` API.
- **GOTCHA**: A broken URL must not break the card.

### Task 8: Feed card
- **ACTION**: `_EventCard`: `Card(clipBehavior: Clip.antiAlias)` with `Column` of `[if (session.bannerUrl != null) EventBanner(url: ...), ListTile(...)]`.

### Task 9: Landing card
- **ACTION**: In `_EventsGrid`, inside the existing `AspectRatio`, use `e.bannerUrl != null ? PlatformCachedImage(imageUrl: e.bannerUrl!, fit: BoxFit.cover) : Image.asset(...)`.
- **GOTCHA**: `test/landing_screen_test.dart` exists; null-banner behaviour must stay identical.

### Task 10: Public event + session detail screens
- **ACTION**: `PublicEventScreen._Details`: before the title add `if (event.bannerUrl != null) ...[ClipRRect(borderRadius: BorderRadius.circular(12), child: EventBanner(...)), SizedBox(height: 16)]`. `SessionDetailScreen`: first child of the root `Column` (before "Session Info Card"): `if (session.bannerUrl != null) ConstrainedBox(constraints: BoxConstraints(maxHeight: 180), child: EventBanner(...))`.
- **GOTCHA**: Session detail header sits in a non-scrolling `Column` with an `Expanded` list; cap the banner height so phones keep list space.

### Task 11: Docs + Storage rule note
- **ACTION**: `docs/ARCHITECTURE.md` §7: add `bannerUrl` (string?, download URL, optional) to `sessionTemplates`, `liveSessions`, `publicEvents` field lists (near lines 305, 329); document Storage path `event_banners/{groupId}/{ts}.jpg`.
- **DEPLOY GOTCHA**: No `storage.rules` in git. Before release, check the console Storage rules allow signed-in writes to `event_banners/**` (suggest: `allow write: if request.auth != null && request.resource.size < 5 * 1024 * 1024 && request.resource.contentType.matches('image/.*')`). Guests can load images through token download URLs. Do not deploy rules from this repo.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected | Edge? |
|---|---|---|---|
| Session `fromMap` without `bannerUrl` | `baseMap()` | `bannerUrl` null, `toMap` has no key | yes |
| Session roundtrip with `bannerUrl` | map + `'bannerUrl': 'https://x/y.jpg'` | preserved in `toMap` / `fromMap` | |
| Template `copyWith(bannerUrl:)` | template | field set; `toMap` includes it | |
| `buildPublicEvent` with `bannerUrl` | base + `bannerUrl` | copied to projection | |
| `buildPublicEvent` without | base | `out.bannerUrl === undefined` | yes |
| Landing test | existing | unchanged (null banner → stock image) | |

### Edge Cases Checklist
- [ ] No banner picked → event created exactly as before
- [ ] Picker cancelled
- [ ] Very large image (resized by `maxWidth`/`imageQuality`)
- [ ] Upload fails → failure snackbar, no template/session written
- [ ] Broken/expired URL → card still renders
- [ ] Private event with banner: not mirrored to `publicEvents` (existing behaviour)
- [ ] Web build: pick + upload + preview work (no `dart:io` on this path)

---

## Validation Commands

### Static Analysis
```bash
flutter analyze   # always reports include_file_not_found (pre-existing)
```
EXPECT: no new issues

### Unit Tests
```bash
flutter test test/session_model_test.dart test/landing_screen_test.dart
(cd functions && npm run build && npm test)
```
EXPECT: pass

### Full Test Suite
```bash
flutter test   # default counter smoke test fails (pre-existing)
```
EXPECT: no new failures

### Browser Validation
```bash
flutter run -d chrome
```
EXPECT: create a public session with a banner → card shows image in `/events` and landing (after functions deployed); without banner → unchanged.

### Manual Validation
- [ ] Create session with banner on web and on mobile
- [ ] Banner visible in feed, landing, `/events/:id` (signed out), session detail
- [ ] Create session without banner → no empty gap anywhere

---

## Acceptance Criteria
- [ ] All tasks completed
- [ ] Tests written and passing
- [ ] No new analyzer errors
- [ ] Matches UX design
- [ ] ARCHITECTURE doc updated

## Completion Checklist
- [ ] Firebase calls only in services / bloc (none in widgets)
- [ ] Product copy Spanish
- [ ] No hardcoded sport lists or credits handling touched
- [ ] Self-contained

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Console Storage rules block `event_banners/**` writes | Med | Upload fails in prod | Check console rules before release; Task 11 |
| `dart:io` `File` breaks web upload | High if copied from group upload | Banner broken on web | Use `XFile` + `putData` (Task 4) |
| Functions not deployed before app | Med | Banner missing on public feed | Deploy functions first (existing order) |
| Large images slow the feed | Low | Perf | Resize at pick (1600px, q85) |
| Orphaned Storage files | Low | Cost | Accepted (NOT building) |

## Notes
Banner is per template at creation; recurring weekly events created later by the CSV script will not carry a banner (explicitly out of scope).
