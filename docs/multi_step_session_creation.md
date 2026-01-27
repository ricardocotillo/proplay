# Multi-Step Session Creation with Location Picker

## Overview

This document describes the implementation of a multi-step form for creating sessions in the ProPlay app, featuring an integrated Google Maps location picker.

---

## Plan Summary

Transform the `CreateSessionScreen` from a single scrollable form into a 3-step wizard:

| Step | Name | Description |
|------|------|-------------|
| 1 | Location | Full-screen map picker with address autocomplete |
| 2 | Date & Time | Start/end date and time selection |
| 3 | Details | Title, max players, cost, age range, gender, privacy |

---

## Implemented Steps

### 1. Created Constants File
**File:** `lib/utils/constants.dart`

```dart
class AppConstants {
  static const String googleMapsApiKey = 'AIzaSyAZY0zvn5s0I2Eh5aEGy06QelTsC2SeUYg';
}
```

### 2. Added Location Fields to Models

**File:** `lib/models/session_template_model.dart`

Added fields:
- `locationLat: double?`
- `locationLng: double?`
- `locationAddress: String?`

Updated methods:
- Constructor with optional location parameters
- `props` list for Equatable
- `copyWith()` method
- `toMap()` serialization
- `fromMap()` deserialization

**File:** `lib/models/session_model.dart`

Same location fields added to maintain parity with template model.

### 3. Updated Session Service

**File:** `lib/services/session_service.dart`

Changes:
- `_createFirstLiveSession()` now passes location data to live sessions
- All query methods (`getUpcomingSessions`, `getUpcomingSessionsForGroups`, `getAllPublicSessions`) include location fields in `filteredData`

### 4. Created Step Indicator Widget

**File:** `lib/widgets/step_indicator.dart`

Features:
- Displays numbered circles with connecting lines
- Shows checkmark for completed steps
- Highlights current step
- Optional step labels
- Theme-aware colors

### 5. Rewrote Create Session Screen

**File:** `lib/screens/create_session_screen.dart`

#### Architecture
- `PageView` with `NeverScrollableScrollPhysics` for controlled navigation
- `PageController` for programmatic step transitions
- Local state management for step data (not in BLoC)
- BLoC retained only for final submission

#### Step 1: Location Picker
- Full-screen `MapLocationPicker` widget
- Default position: Buenos Aires (-34.6037, -58.3816)
- Address autocomplete search bar
- `onNext` callback captures lat/lng/address and advances

#### Step 2: Date & Time
- Summary card showing selected location (tappable to edit)
- Start date/time pickers
- End date/time pickers
- Validation: end must be after start
- Back/Next navigation buttons

#### Step 3: Details
- Summary cards for location and date/time
- Form fields: title, max players, total cost
- Age range slider (18-80)
- Gender dropdown (any/male/female)
- Private session checkbox
- Back/Submit navigation buttons

---

## File Changes Summary

| File | Action | Lines Changed |
|------|--------|---------------|
| `lib/utils/constants.dart` | Created | ~4 |
| `lib/widgets/step_indicator.dart` | Created | ~95 |
| `lib/models/session_template_model.dart` | Modified | ~25 |
| `lib/models/session_model.dart` | Modified | ~25 |
| `lib/services/session_service.dart` | Modified | ~15 |
| `lib/screens/create_session_screen.dart` | Rewritten | ~680 |

---

## Firestore Schema Update

```
sessionTemplates/{templateId}
├── ... existing fields ...
├── locationLat: number | null
├── locationLng: number | null
└── locationAddress: string | null

liveSessions/{sessionId}
├── ... existing fields ...
├── locationLat: number | null
├── locationLng: number | null
└── locationAddress: string | null
```

---

## Future Optimizations

### High Priority

1. **Location Restriction by Country**
   - Add `SearchConfig` filter to restrict autocomplete to specific countries
   - Consider user's locale or app settings for default country

2. **Geolocation Permission Handling**
   - Request location permission on app start
   - Use device location as default map position
   - Show permission rationale dialog

3. **Offline Support**
   - Cache last selected location
   - Allow manual coordinate entry as fallback

### Medium Priority

4. **Map Customization**
   - Custom map styles matching app theme
   - Custom marker icon for selected location
   - Dark mode map style

5. **Address Validation**
   - Verify address has sufficient detail (street number, city)
   - Warning for vague locations like "Argentina"

6. **Form State Persistence**
   - Save draft session to local storage
   - Restore on app restart or accidental back navigation
   - Clear draft on successful submission

7. **Step Animations**
   - Add hero animations between steps
   - Animate summary cards expansion/collapse

### Low Priority

8. **Accessibility Improvements**
   - Screen reader support for map picker
   - Alternative text input for location
   - High contrast step indicator

9. **Analytics Integration**
   - Track step completion rates
   - Identify drop-off points
   - Measure time spent per step

10. **A/B Testing**
    - Test different step orders
    - Test mandatory vs optional location
    - Test map vs list-only location selection

### Technical Debt

11. **Extract Step Widgets**
    - Move each step to separate widget file
    - Improve code organization and testability

12. **BLoC for Multi-Step State (Optional)**
    - Consider moving step state to BLoC if complexity grows
    - Would enable undo/redo functionality
    - Better state persistence

13. **Unit Tests**
    - Test step validation logic
    - Test date/time combination
    - Test model serialization with location

14. **Integration Tests**
    - Full flow test: location → date → details → submit
    - Test back navigation preserves data
    - Test Firestore write includes location

---

## Dependencies

```yaml
# Already in pubspec.yaml
map_location_picker: ^3.1.0
```

### Required Google Cloud APIs
- Maps SDK for Android
- Maps SDK for iOS
- Places API
- Geocoding API

---

## Testing Checklist

- [ ] Step 1: Search for location works
- [ ] Step 1: Map shows selected location marker
- [ ] Step 1: Tapping confirm advances to step 2
- [ ] Step 2: Date pickers work correctly
- [ ] Step 2: Time pickers work correctly
- [ ] Step 2: Validation prevents invalid date ranges
- [ ] Step 2: Location summary card shows address
- [ ] Step 2: Tapping location card goes back to step 1
- [ ] Step 3: All form fields work
- [ ] Step 3: Summary cards show correct data
- [ ] Step 3: Submit creates session in Firestore
- [ ] Firestore: `sessionTemplates` has location fields
- [ ] Firestore: `liveSessions` has location fields
- [ ] Back navigation preserves entered data
- [ ] Loading state shows during submission
- [ ] Success message shows after creation
- [ ] Screen pops after successful creation

---

## Related Files

- `android/app/src/main/AndroidManifest.xml` - Google Maps API key
- `ios/Runner/AppDelegate.swift` - Google Maps initialization
- `ios/Runner/Info.plist` - Location permission descriptions
- `map_picker.md` - Package documentation reference
