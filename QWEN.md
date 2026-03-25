# ProPlay - Claude Code Project Guide

## Project Overview
ProPlay is a Flutter application built with Firebase backend services, implementing a robust authentication system with user profile management.

## Architecture Pattern: BLoC (Business Logic Component)

This project **STRICTLY** follows the BLoC pattern for state management. All business logic must be separated from the UI layer.

### BLoC Structure
```
lib/
├── bloc/
│   └── auth/
│       ├── auth_bloc.dart    # Business logic
│       ├── auth_event.dart   # Events (user actions)
│       └── auth_state.dart   # States (UI states)
├── models/                    # Data models
├── services/                  # External service interactions
├── screens/                   # UI screens
├── widgets/                   # Reusable widgets
└── utils/                     # Helper utilities
```

### Key BLoC Principles
1. **Never put business logic in UI widgets** - Always use BLoC
2. **Events trigger actions** - User interactions dispatch events
3. **States represent UI** - UI rebuilds based on state changes
4. **Services are injected into BLoCs** - Not directly accessed from UI

## Firebase Configuration

### Services Used
- **Firebase Auth**: User authentication (email/password)
- **Cloud Firestore**: User data storage (users collection)
- **Firebase Storage**: File uploads (profile images)

### Firebase Structure
```
Firestore Collections:
├── users/
│   └── {userId}/
│       ├── uid: string
│       ├── email: string
│       ├── firstName: string
│       ├── lastName: string
│       ├── profileImageUrl: string?
│       └── createdAt: Timestamp
```

### Firebase Files
- `firebase.json` - Firebase configuration
- `lib/firebase_options.dart` - Generated Firebase options (DO NOT EDIT MANUALLY)

## Authentication Flow

### Login Flow
1. User enters credentials on `LoginScreen`
2. `AuthLoginRequested` event dispatched
3. `AuthBloc` calls `AuthService.signInWithEmailAndPassword()`
4. User document fetched from Firestore via `UserService`
5. `AuthAuthenticated` state emitted with `UserModel`
6. `AuthWrapper` navigates to `HomeScreen`

### Registration Flow
1. User fills registration form (first name, last name, email, password)
2. `AuthRegisterRequested` event dispatched with user info
3. `AuthBloc` creates Firebase Auth account
4. `UserModel` created and saved to Firestore
5. `AuthAuthenticated` state emitted
6. Navigation pops back to root, `AuthWrapper` shows `HomeScreen`

### Logout Flow
1. User taps logout in drawer
2. Confirmation dialog shown
3. `AuthLogoutRequested` event dispatched
4. `AuthBloc` calls `AuthService.signOut()`
5. `AuthUnauthenticated` state emitted
6. `AuthWrapper` navigates to `LoginScreen`

## Current User Access

### Global User Object
The current user is accessible globally through the `AuthHelper` utility:

```dart
// Method 1: Using context extension (recommended)
final user = context.currentUser;  // Read once, won't rebuild

// Method 2: Watch for changes (rebuilds on auth state change)
final user = context.watchUser;

// Method 3: Using AuthHelper class
final user = AuthHelper.getCurrentUser(context);

// Check authentication
bool authenticated = context.isAuthenticated;
```

### UserModel Properties
```dart
class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName';
}
```

## UI Components

### Screens
- `LoginScreen` - Email/password login with navigation to registration
- `RegistrationScreen` - User registration with first name, last name, email, password
- `HomeScreen` - Main app screen with profile image in AppBar
- `CreateGroupScreen` - Create a new group with name and sports
- `EditProfileScreen` - Edit user profile with first name, last name, email, password

### Widgets
- `AppDrawer` - Side drawer with user profile and menu options
  - User header with profile image/initials
  - Edit Profile (placeholder)
  - Log Out (with confirmation)

### Profile Image Display
- Uses `CachedNetworkImage` for efficient image loading
- Fallback to user initials when no profile image exists
- Circular avatar with theme colors
- Loading and error states handled

## Code Patterns & Guidelines

### 1. Always Use BLoC for State Management
```dart
// ✅ CORRECT - Dispatch event
context.read<AuthBloc>().add(AuthLoginRequested(
  email: email,
  password: password,
));

// ❌ WRONG - Direct service call from UI
await AuthService().signInWithEmailAndPassword(email, password);
```

### 2. Service Layer
Services handle external interactions only:
- `AuthService` - Firebase Auth operations
- `UserService` - Firestore user operations

```dart
// Services are injected into BLoCs
AuthBloc(
  authService: AuthService(),
  userService: UserService(),
)
```

### 3. File Naming Convention
- Screens: `{name}_screen.dart` (e.g., `login_screen.dart`)
- Widgets: `{name}.dart` (e.g., `app_drawer.dart`)
- Models: `{name}_model.dart` (e.g., `user_model.dart`)
- Services: `{name}_service.dart` (e.g., `auth_service.dart`)
- BLoCs: `{name}_bloc.dart`, `{name}_event.dart`, `{name}_state.dart`

### 4. Import Organization
```dart
// Flutter imports
import 'package:flutter/material.dart';

// Package imports
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Project imports
import 'package:proplay/services/auth_service.dart';
import 'package:proplay/models/user_model.dart';
```

### 5. State Management Best Practices
- Use `BlocBuilder` for UI that depends on state
- Use `BlocListener` for one-time actions (navigation, dialogs)
- Use `BlocConsumer` when you need both
- Always provide specific state types (avoid dynamic)

### 6. Navigation Patterns
```dart
// Pop to root (used after registration)
Navigator.of(context).popUntil((route) => route.isFirst);

// Simple navigation
Navigator.push(context, MaterialPageRoute(
  builder: (context) => const SomeScreen(),
));

// Pop current screen
Navigator.pop(context);
```

## Dependencies

### Core Dependencies
```yaml
firebase_core: ^4.1.1           # Firebase initialization
firebase_auth: ^6.1.0           # Authentication
cloud_firestore: ^6.0.2         # Database
firebase_storage: ^13.0.2       # File storage
flutter_bloc: ^9.1.1            # BLoC state management
equatable: ^2.0.7               # Value equality
provider: ^6.1.5+1              # Dependency injection
cached_network_image: ^3.4.1    # Image caching
image_picker: ^1.2.0            # Image picker
```

## Key Files to Never Modify Manually
- `lib/firebase_options.dart` - Generated by FlutterFire CLI
- `android/app/google-services.json` - Firebase Android config
- `ios/Runner/GoogleService-Info.plist` - Firebase iOS config

## Common Tasks

### Adding a New Screen
1. Create screen file in `lib/screens/`
2. If needs state management, create corresponding BLoC
3. Add navigation from existing screen
4. Follow BLoC pattern for all logic

### Adding a New BLoC
1. Create folder in `lib/bloc/{name}/`
2. Create `{name}_event.dart` with events
3. Create `{name}_state.dart` with states (extend Equatable)
4. Create `{name}_bloc.dart` with business logic
5. Provide BLoC in widget tree
6. Dispatch events from UI, listen to states

### Adding Firestore Collection
1. Create model in `lib/models/`
2. Add `toMap()` and `fromMap()` methods
3. Create service in `lib/services/`
4. Inject service into relevant BLoC
5. Use BLoC to interact with service

### Adding Authentication Feature
1. Add method to `AuthService`
2. Create event in `auth_event.dart`
3. Add handler in `auth_bloc.dart`
4. Update states if needed in `auth_state.dart`
5. Dispatch event from UI

## Error Handling

### Firebase Auth Errors
Handled in `AuthService._handleAuthException()`:
- user-not-found
- wrong-password
- email-already-in-use
- invalid-email
- weak-password

### UI Error Display
- Use `BlocListener` for error state
- Show `SnackBar` for errors
- Use `ScaffoldMessenger.of(context).showSnackBar()`

## Testing Guidelines
- Unit test BLoCs (test events → states)
- Mock services in BLoC tests
- Widget tests for screens
- Integration tests for flows

## Important Notes

### When Adding New Features
1. ✅ Always follow BLoC pattern
2. ✅ Keep business logic in BLoCs
3. ✅ Services only for external interactions
4. ✅ UI only for presentation
5. ✅ Use proper file structure
6. ✅ Follow naming conventions

### When Debugging
1. Check BLoC state transitions
2. Verify events are dispatched correctly
3. Ensure services are injected properly
4. Check Firebase console for data
5. Review error messages in auth_service

### Performance Considerations
- Use `const` constructors when possible
- Implement `Equatable` for states and events
- Use `CachedNetworkImage` for images
- Avoid rebuilding entire tree (use specific BlocBuilder)

## Project Status

### Completed Features
- ✅ Firebase Authentication (email/password)
- ✅ User registration with Firestore integration
- ✅ Login/Logout functionality
- ✅ Global user state management
- ✅ Profile image display with fallback
- ✅ App drawer with user menu
- ✅ Navigation flow

### Placeholder Features (To Implement)
- ⏳ Edit Profile screen
- ⏳ Profile image upload
- ⏳ Password reset
- ⏳ Email verification

## Quick Reference

### Get Current User
```dart
final user = context.currentUser;
```

### Dispatch Auth Event
```dart
context.read<AuthBloc>().add(SomeAuthEvent());
```

### Listen to Auth State
```dart
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    if (state is AuthAuthenticated) {
      return HomeScreen();
    }
    return LoginScreen();
  },
)
```

### Access User Data
```dart
final user = context.currentUser;
final fullName = user?.fullName;
final email = user?.email;
final profileUrl = user?.profileImageUrl;
```

---

**Last Updated**: Project initialization with authentication system
**Flutter Version**: 3.9.2+
**Firebase Project**: proplay-eac23
