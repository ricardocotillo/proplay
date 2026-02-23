# ProPlay - Sistema de Matchmaking (Emparejamiento)

## Descripción General

ProPlay implementa un sistema de matchmaking inteligente que conecta a los usuarios con sesiones y eventos deportivos relevantes basándose en múltiples criterios de preferencia. El sistema filtra y ordena las sesiones disponibles para mostrar a cada usuario únicamente las actividades más relevantes según su perfil.

## Criterios de Emparejamiento

El sistema de matchmaking utiliza los siguientes criterios para emparejar usuarios con sesiones:

### 1. Deporte Preferido
### 2. Género
### 3. Edad
### 4. Ubicación Geográfica (próximamente)
### 5. Grupos del Usuario

---

## Estado de Implementación (Código)

### Hecho ✅

- [x] **Perfil de usuario**: `gender` y `age` existen en `UserModel` (nullable) y se persisten en Firestore.
- [x] **Creación de sesión**: se requiere `desiredGender` + rango de edad `minAge/maxAge` (UI con `RangeSlider` 18–80).
- [x] **Persistencia de sesión**: `SessionTemplateModel` y `SessionModel` incluyen `desiredGender`, `minAge`, `maxAge` en `toMap/fromMap`.
- [x] **Creación de live session**: `SessionService` copia `desiredGender/minAge/maxAge` del template al primer `liveSession`.
- [x] **Lecturas Firestore**: `getUpcomingSessionsForGroups()` y `getAllPublicSessions()` incluyen `desiredGender/minAge/maxAge` al construir `SessionModel`.
- [x] **Matchmaking (filtrado)**: `SessionService.getAllUpcomingSessions()` filtra sesiones públicas por:
  - [x] deporte
  - [x] género (`desiredGender` vs `userGender`)
  - [x] edad (`minAge/maxAge` vs `userAge`)
- [x] **BLoC de sesiones**: `LoadAllUserSessions` acepta `userGender` y `userAge` y los envía al service.
- [x] **Home UI**: `HomeScreen` pasa `userGender/userAge` al cargar sesiones y muestra `desiredGender` + `minAge-maxAge` en el card del carrusel.
- [x] **Sessions UI**: `SessionsScreen` pasa `userGender/userAge` al cargar sesiones.

### Próximo 🚧

- [x] **Ubicación**: persistir ubicación del usuario y de la sesión (modelo + UI + Firestore).
- [x] **Matchmaking por distancia**: filtrar/ordenar por distancia y/o radio máximo.

---

## Arquitectura del Sistema

### Flujo de Matchmaking

```
Usuario → Perfil de Preferencias → Algoritmo de Filtrado → Sesiones Emparejadas
   ↓                                         ↓
Preferencias:                         Filtros Aplicados:
- Deportes                           - Sport match
- Género                             - Gender match
- Edad                               - Age range match
- Ubicación                          - Distance match
- Grupos                             - Group membership
```

### Componentes Principales

```
lib/
├── models/
│   ├── user_model.dart              # Modelo con preferencias del usuario
│   ├── session_model.dart           # Modelo de sesión con criterios
│   └── user_preferences_model.dart  # Preferencias de matchmaking
├── services/
│   ├── session_service.dart         # Lógica de filtrado y matchmaking
│   └── user_service.dart            # Gestión de preferencias
├── bloc/
│   └── session/
│       ├── session_bloc.dart        # Estado de sesiones filtradas
│       ├── session_event.dart       # Eventos de carga con filtros
│       └── session_state.dart       # Estados con sesiones emparejadas
└── screens/
    ├── home_screen.dart             # Visualización de sesiones emparejadas
    └── sessions_screen.dart         # Lista completa de sesiones
```

---

## 1. Emparejamiento por Deporte

### Modelo de Usuario con Deportes Preferidos

Los usuarios pueden seleccionar uno o más deportes de su interés. Esta información se almacena en Firestore y se utiliza como primer criterio de filtrado.

```dart
// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final String credits;
  final bool superUser;
  final List<String> sports;  // 🏀 Deportes preferidos del usuario

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.createdAt,
    this.credits = '0.00',
    this.superUser = false,
    this.sports = const [],  // Por defecto: lista vacía
  });

  // Conversión a mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'credits': credits,
      'superUser': superUser,
      'sports': sports,  // Guardado en Firestore
    };
  }
}
```

### Modelo de Sesión con Deporte Específico

Cada sesión está asociada a un deporte específico que se utiliza para el emparejamiento.

```dart
// lib/models/session_model.dart
class SessionModel extends Equatable {
  final String id;
  final String templateId;
  final String groupId;
  final String title;
  final DateTime eventDate;
  final DateTime eventEndDate;
  final String status;
  final int playerCount;
  final int maxPlayers;
  final double costPerPlayer;
  final bool isPrivate;
  final List<SessionUserModel>? players;
  final String sport;  // 🏀 Deporte de la sesión

  const SessionModel({
    required this.id,
    required this.templateId,
    required this.groupId,
    required this.title,
    required this.eventDate,
    required this.eventEndDate,
    required this.status,
    required this.playerCount,
    required this.maxPlayers,
    required this.costPerPlayer,
    this.isPrivate = false,
    this.players,
    required this.sport,  // Requerido para matchmaking
  });
}
```

### Algoritmo de Filtrado por Deporte

El servicio de sesiones implementa la lógica principal de matchmaking por deporte en el método `getAllUpcomingSessions()`.

```dart
// lib/services/session_service.dart:187-225
Future<List<SessionModel>> getAllUpcomingSessions(
  List<String> userGroupIds, {
  List<String> userSports = const [],
}) async {
  try {
    // 1. Obtener sesiones de los grupos del usuario (privadas y públicas)
    final groupSessions = await getUpcomingSessionsForGroups(userGroupIds);

    // 2. Obtener todas las sesiones públicas disponibles
    final publicSessions = await getAllPublicSessions();

    // 3. Crear mapa para evitar duplicados
    final sessionMap = <String, SessionModel>{};

    // 4. Agregar sesiones de grupos primero (tienen prioridad)
    for (final session in groupSessions) {
      sessionMap[session.id] = session;
    }

    // 5. FILTRADO POR DEPORTE: Agregar sesiones públicas si:
    //    - No están ya en el mapa
    //    - El deporte coincide con las preferencias del usuario
    for (final session in publicSessions) {
      if (!sessionMap.containsKey(session.id)) {
        // ✅ Solo agregar si:
        //    - Usuario no tiene deportes especificados (ve todo), O
        //    - Deporte de sesión está en lista de deportes del usuario
        if (userSports.isEmpty || userSports.contains(session.sport)) {
          sessionMap[session.id] = session;
        }
      }
    }

    // 6. Convertir a lista y ordenar por fecha
    final allSessions = sessionMap.values.toList();
    allSessions.sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return allSessions;
  } catch (e) {
    rethrow;
  }
}
```

### Deportes Disponibles

```dart
// lib/screens/home_screen.dart:1110-1129
final List<String> availableSports = [
  'fútbol',
  'baloncesto',
  'voleibol',
  'tenis',
  'natación',
  'running',
  'ciclismo',
  'gimnasio',
  'pádel',
  'béisbol',
];
```

### Uso en UI

```dart
// lib/screens/sessions_screen.dart
BlocBuilder<SessionBloc, SessionState>(
  builder: (context, state) {
    if (state is SessionInitial) {
      final user = context.currentUser;
      final groupIds = groupState.groups.map((g) => g.id).toList();

      // 🎯 Cargar sesiones filtradas por deportes del usuario
      context.read<SessionBloc>().add(
        LoadAllUserSessions(
          groupIds: groupIds,
          userSports: user?.sports ?? [],  // Preferencias de deportes
        ),
      );
    }

    if (state is SessionLoaded) {
      // Mostrar sesiones emparejadas
      return ListView.builder(
        itemCount: state.sessions.length,
        itemBuilder: (context, index) {
          return SessionCard(session: state.sessions[index]);
        },
      );
    }
  },
)
```

---

## 2. Emparejamiento por Género

### Modelo de Usuario con Género

El perfil de usuario incluye información de género que se utiliza para filtrar sesiones con preferencias de género específicas.

```dart
// lib/models/user_model.dart (EXTENSIÓN)
class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final String credits;
  final bool superUser;
  final List<String> sports;
  final String? gender;  // 🚻 'male', 'female', 'other', 'prefer_not_to_say'

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.createdAt,
    this.credits = '0.00',
    this.superUser = false,
    this.sports = const [],
    this.gender,  // Opcional
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'credits': credits,
      'superUser': superUser,
      'sports': sports,
      'gender': gender,  // Guardado en Firestore
    };
  }
}
```

### Modelo de Sesión con Preferencia de Género

Las sesiones pueden especificar una preferencia de género para los participantes.

```dart
// lib/models/session_model.dart (EXTENSIÓN)
class SessionModel extends Equatable {
  final String id;
  final String templateId;
  final String groupId;
  final String title;
  final DateTime eventDate;
  final DateTime eventEndDate;
  final String status;
  final int playerCount;
  final int maxPlayers;
  final double costPerPlayer;
  final bool isPrivate;
  final List<SessionUserModel>? players;
  final String sport;
  final String desiredGender;  // 🚻 'any', 'male', 'female'

  const SessionModel({
    required this.id,
    required this.templateId,
    required this.groupId,
    required this.title,
    required this.eventDate,
    required this.eventEndDate,
    required this.status,
    required this.playerCount,
    required this.maxPlayers,
    required this.costPerPlayer,
    this.isPrivate = false,
    this.players,
    required this.sport,
    required this.desiredGender,
  });

  // Verificar si usuario cumple requisito de género
  bool matchesGenderRequirement(String? userGender) {
    // Sesión abierta a todos
    if (desiredGender == 'any') {
      return true;
    }

    // Usuario sin género especificado = no puede unirse a sesiones restringidas
    if (userGender == null) {
      return false;
    }

    // Comparar género del usuario con requisito de sesión
    return desiredGender == userGender;
  }
}
```

### Algoritmo de Filtrado por Género

```dart
// lib/services/session_service.dart (EXTENSIÓN)
Future<List<SessionModel>> getAllUpcomingSessions(
  List<String> userGroupIds, {
  List<String> userSports = const [],
  String? userGender,  // 🚻 Género del usuario
  int? userAge,         // 🎂 Edad del usuario
}) async {
  try {
    final groupSessions = await getUpcomingSessionsForGroups(userGroupIds);
    final publicSessions = await getAllPublicSessions();
    final sessionMap = <String, SessionModel>{};

    // Sesiones de grupos (prioridad)
    for (final session in groupSessions) {
      sessionMap[session.id] = session;
    }

    // Filtrado por deporte + género + edad
    for (final session in publicSessions) {
      if (!sessionMap.containsKey(session.id)) {
        // ✅ Filtro de deporte
        final sportMatch = userSports.isEmpty || userSports.contains(session.sport);

        // ✅ Filtro de género
        final genderMatch = session.matchesGenderRequirement(userGender);

        // ✅ Filtro de edad
        final ageMatch = session.matchesAgeRequirement(userAge);

        // Solo agregar si cumple TODOS los criterios
        if (sportMatch && genderMatch && ageMatch) {
          sessionMap[session.id] = session;
        }
      }
    }

    final allSessions = sessionMap.values.toList();
    allSessions.sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return allSessions;
  } catch (e) {
    rethrow;
  }
}
```

### Uso en UI

```dart
// lib/screens/sessions_screen.dart (CON GÉNERO)
final user = context.currentUser;
final groupIds = groupState.groups.map((g) => g.id).toList();

context.read<SessionBloc>().add(
  LoadAllUserSessions(
    groupIds: groupIds,
    userSports: user?.sports ?? [],
    userGender: user?.gender,  // 🚻 Género para filtrado
  ),
);
```

---

## 3. Emparejamiento por Edad

### Modelo de Usuario con Edad

```dart
// lib/models/user_model.dart (EXTENSIÓN)
class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final String credits;
  final bool superUser;
  final List<String> sports;
  final String? gender;
  final int? age;  // 🎂 Edad

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.createdAt,
    this.credits = '0.00',
    this.superUser = false,
    this.sports = const [],
    this.gender,
    this.age,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'credits': credits,
      'superUser': superUser,
      'sports': sports,
      'gender': gender,
      'age': age,
    };
  }
}
```

### Modelo de Sesión con Rango de Edad

```dart
// lib/models/session_model.dart (EXTENSIÓN)
class SessionModel extends Equatable {
  final String id;
  final String templateId;
  final String groupId;
  final String title;
  final DateTime eventDate;
  final DateTime eventEndDate;
  final String status;
  final int playerCount;
  final int maxPlayers;
  final double costPerPlayer;
  final bool isPrivate;
  final List<SessionUserModel>? players;
  final String sport;
  final String desiredGender;
  final int minAge;  // 🎂 Edad mínima
  final int maxAge;  // 🎂 Edad máxima

  const SessionModel({
    required this.id,
    required this.templateId,
    required this.groupId,
    required this.title,
    required this.eventDate,
    required this.eventEndDate,
    required this.status,
    required this.playerCount,
    required this.maxPlayers,
    required this.costPerPlayer,
    this.isPrivate = false,
    this.players,
    required this.sport,
    required this.desiredGender,
    required this.minAge,
    required this.maxAge,
  });

  // Verificar si usuario cumple requisito de edad
  bool matchesAgeRequirement(int? userAge) {
    // Usuario sin edad especificada = no puede unirse a sesiones con restricción
    if (userAge == null) {
      return false;
    }

    // Verificar rango de edad
    if (userAge < minAge) {
      return false;
    }

    if (userAge > maxAge) {
      return false;
    }

    return true;
  }

  // Obtener descripción del rango de edad
  String get ageRangeDescription {
    return '$minAge-$maxAge años';
  }
}
```

### Algoritmo de Filtrado por Edad

```dart
// lib/services/session_service.dart (EXTENSIÓN)
Future<List<SessionModel>> getAllUpcomingSessions(
  List<String> userGroupIds, {
  List<String> userSports = const [],
  String? userGender,
  int? userAge,  // 🎂 Edad del usuario
}) async {
  try {
    final groupSessions = await getUpcomingSessionsForGroups(userGroupIds);
    final publicSessions = await getAllPublicSessions();
    final sessionMap = <String, SessionModel>{};

    for (final session in groupSessions) {
      sessionMap[session.id] = session;
    }

    for (final session in publicSessions) {
      if (!sessionMap.containsKey(session.id)) {
        // ✅ Filtro de deporte
        final sportMatch = userSports.isEmpty || userSports.contains(session.sport);

        // ✅ Filtro de género
        final genderMatch = session.matchesGenderRequirement(userGender);

        // ✅ Filtro de edad
        final ageMatch = session.matchesAgeRequirement(userAge);

        // Solo agregar si cumple TODOS los criterios
        if (sportMatch && genderMatch && ageMatch) {
          sessionMap[session.id] = session;
        }
      }
    }

    final allSessions = sessionMap.values.toList();
    allSessions.sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return allSessions;
  } catch (e) {
    rethrow;
  }
}
```

### Uso en UI

```dart
// lib/screens/sessions_screen.dart (CON EDAD)
final user = context.currentUser;
final groupIds = groupState.groups.map((g) => g.id).toList();

context.read<SessionBloc>().add(
  LoadAllUserSessions(
    groupIds: groupIds,
    userSports: user?.sports ?? [],
    userGender: user?.gender,
    userAge: user?.age,  // 🎂 Edad del usuario
  ),
);
```

---

## 4. Emparejamiento por Ubicación

### Modelo de Usuario con Ubicación

```dart
// lib/models/user_location_model.dart
class UserLocation {
  final double latitude;
  final double longitude;
  final String? city;
  final String? country;
  final DateTime lastUpdated;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.city,
    this.country,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'country': country,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      city: map['city'] as String?,
      country: map['country'] as String?,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }
}

// lib/models/user_model.dart (EXTENSIÓN)
class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final String credits;
  final bool superUser;
  final List<String> sports;
  final String? gender;
  final DateTime? dateOfBirth;
  final UserLocation? location;  // 📍 Ubicación del usuario

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.createdAt,
    this.credits = '0.00',
    this.superUser = false,
    this.sports = const [],
    this.gender,
    this.dateOfBirth,
    this.location,
  });
}
```

### Modelo de Sesión con Ubicación

```dart
// lib/models/session_location_model.dart
class SessionLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String? venueName;  // Nombre del lugar (ej: "Polideportivo Municipal")
  final String? city;
  final String? postalCode;

  const SessionLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.venueName,
    this.city,
    this.postalCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'venueName': venueName,
      'city': city,
      'postalCode': postalCode,
    };
  }

  factory SessionLocation.fromMap(Map<String, dynamic> map) {
    return SessionLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String,
      venueName: map['venueName'] as String?,
      city: map['city'] as String?,
      postalCode: map['postalCode'] as String?,
    );
  }
}

// lib/models/session_model.dart (EXTENSIÓN)
class SessionModel extends Equatable {
  final String id;
  final String templateId;
  final String groupId;
  final String title;
  final DateTime eventDate;
  final DateTime eventEndDate;
  final String status;
  final int playerCount;
  final int maxPlayers;
  final double costPerPlayer;
  final bool isPrivate;
  final List<SessionUserModel>? players;
  final String sport;
  final String? genderPreference;
  final int? minAge;
  final int? maxAge;
  final SessionLocation? location;  // 📍 Ubicación de la sesión

  const SessionModel({
    required this.id,
    required this.templateId,
    required this.groupId,
    required this.title,
    required this.eventDate,
    required this.eventEndDate,
    required this.status,
    required this.playerCount,
    required this.maxPlayers,
    required this.costPerPlayer,
    this.isPrivate = false,
    this.players,
    required this.sport,
    this.genderPreference,
    this.minAge,
    this.maxAge,
    this.location,
  });
}
```

### Utilidad de Cálculo de Distancia

```dart
// lib/utils/location_utils.dart
import 'dart:math';

class LocationUtils {
  // Calcular distancia entre dos coordenadas usando fórmula de Haversine
  // Retorna distancia en kilómetros
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadiusKm * c;

    return distance;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Formatear distancia para mostrar al usuario
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      return '${distanceKm.round()} km';
    }
  }
}
```

### Preferencias de Distancia del Usuario

```dart
// lib/models/user_preferences_model.dart
class UserPreferences {
  final List<String> sports;
  final String? gender;
  final int? minAge;
  final int? maxAge;
  final double? maxDistanceKm;  // 📍 Distancia máxima en km (null = sin límite)

  const UserPreferences({
    this.sports = const [],
    this.gender,
    this.minAge,
    this.maxAge,
    this.maxDistanceKm = 10.0,  // Por defecto: 10 km
  });

  Map<String, dynamic> toMap() {
    return {
      'sports': sports,
      'gender': gender,
      'minAge': minAge,
      'maxAge': maxAge,
      'maxDistanceKm': maxDistanceKm,
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      sports: List<String>.from(map['sports'] ?? []),
      gender: map['gender'] as String?,
      minAge: map['minAge'] as int?,
      maxAge: map['maxAge'] as int?,
      maxDistanceKm: map['maxDistanceKm'] != null
          ? (map['maxDistanceKm'] as num).toDouble()
          : null,
    );
  }
}

// lib/models/user_model.dart (EXTENSIÓN FINAL)
class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? profileImageUrl;
  final DateTime createdAt;
  final String credits;
  final bool superUser;
  final List<String> sports;
  final String? gender;
  final DateTime? dateOfBirth;
  final UserLocation? location;
  final UserPreferences preferences;  // ⚙️ Preferencias de matchmaking

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.profileImageUrl,
    required this.createdAt,
    this.credits = '0.00',
    this.superUser = false,
    this.sports = const [],
    this.gender,
    this.dateOfBirth,
    this.location,
    UserPreferences? preferences,
  }) : preferences = preferences ?? const UserPreferences();
}
```

### Algoritmo Completo de Filtrado con Ubicación

```dart
// lib/services/session_service.dart (VERSIÓN COMPLETA)
Future<List<SessionModel>> getAllUpcomingSessions(
  List<String> userGroupIds, {
  List<String> userSports = const [],
  String? userGender,
  int? userAge,
  UserLocation? userLocation,  // 📍 Ubicación del usuario
  double? maxDistanceKm,       // 📍 Distancia máxima en km
}) async {
  try {
    final groupSessions = await getUpcomingSessionsForGroups(userGroupIds);
    final publicSessions = await getAllPublicSessions();
    final sessionMap = <String, SessionModel>{};

    // Sesiones de grupos (siempre se muestran, sin filtro de distancia)
    for (final session in groupSessions) {
      sessionMap[session.id] = session;
    }

    // Filtrado completo para sesiones públicas
    for (final session in publicSessions) {
      if (!sessionMap.containsKey(session.id)) {
        // ✅ Filtro 1: Deporte
        final sportMatch = userSports.isEmpty || userSports.contains(session.sport);

        // ✅ Filtro 2: Género
        final genderMatch = session.matchesGenderRequirement(userGender);

        // ✅ Filtro 3: Edad
        final ageMatch = session.matchesAgeRequirement(userAge);

        // ✅ Filtro 4: Ubicación/Distancia
        bool locationMatch = true;
        if (userLocation != null &&
            session.location != null &&
            maxDistanceKm != null) {
          final distance = LocationUtils.calculateDistance(
            userLocation.latitude,
            userLocation.longitude,
            session.location!.latitude,
            session.location!.longitude,
          );
          locationMatch = distance <= maxDistanceKm;
        }

        // Solo agregar si cumple TODOS los criterios
        if (sportMatch && genderMatch && ageMatch && locationMatch) {
          sessionMap[session.id] = session;
        }
      }
    }

    // Convertir a lista
    final allSessions = sessionMap.values.toList();

    // Ordenar por distancia si hay ubicación del usuario
    if (userLocation != null) {
      allSessions.sort((a, b) {
        // Sesiones sin ubicación al final
        if (a.location == null && b.location == null) {
          return a.eventDate.compareTo(b.eventDate);
        }
        if (a.location == null) return 1;
        if (b.location == null) return -1;

        // Calcular distancias
        final distanceA = LocationUtils.calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          a.location!.latitude,
          a.location!.longitude,
        );
        final distanceB = LocationUtils.calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          b.location!.latitude,
          b.location!.longitude,
        );

        // Ordenar por distancia primero, luego por fecha
        final distanceComparison = distanceA.compareTo(distanceB);
        if (distanceComparison != 0) return distanceComparison;
        return a.eventDate.compareTo(b.eventDate);
      });
    } else {
      // Sin ubicación: ordenar solo por fecha
      allSessions.sort((a, b) => a.eventDate.compareTo(b.eventDate));
    }

    return allSessions;
  } catch (e) {
    rethrow;
  }
}
```

### Extensión para Agregar Distancia a Sesiones

```dart
// lib/models/session_with_distance.dart
class SessionWithDistance {
  final SessionModel session;
  final double? distanceKm;  // null si no hay ubicación

  const SessionWithDistance({
    required this.session,
    this.distanceKm,
  });

  String get distanceText {
    if (distanceKm == null) return 'Ubicación no disponible';
    return LocationUtils.formatDistance(distanceKm!);
  }
}

// lib/services/session_service.dart (MÉTODO ALTERNATIVO)
Future<List<SessionWithDistance>> getAllUpcomingSessionsWithDistance(
  List<String> userGroupIds,
  UserLocation? userLocation,
  UserPreferences preferences,
) async {
  final sessions = await getAllUpcomingSessions(
    userGroupIds,
    userSports: preferences.sports,
    userGender: preferences.gender,
    userAge: _calculateAge(preferences),
    userLocation: userLocation,
    maxDistanceKm: preferences.maxDistanceKm,
  );

  return sessions.map((session) {
    double? distance;
    if (userLocation != null && session.location != null) {
      distance = LocationUtils.calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        session.location!.latitude,
        session.location!.longitude,
      );
    }
    return SessionWithDistance(session: session, distanceKm: distance);
  }).toList();
}
```

### Uso en UI con Todas las Preferencias

```dart
// lib/screens/sessions_screen.dart (VERSIÓN COMPLETA)
final user = context.currentUser;
final groupIds = groupState.groups.map((g) => g.id).toList();

context.read<SessionBloc>().add(
  LoadAllUserSessions(
    groupIds: groupIds,
    userSports: user?.sports ?? [],
    userGender: user?.gender,
    userAge: user?.age,
    userLocation: user?.location,
    maxDistanceKm: user?.preferences.maxDistanceKm ?? 10.0,
  ),
);

// Mostrar sesiones con distancia
BlocBuilder<SessionBloc, SessionState>(
  builder: (context, state) {
    if (state is SessionLoaded) {
      return ListView.builder(
        itemCount: state.sessions.length,
        itemBuilder: (context, index) {
          final sessionWithDistance = state.sessions[index];
          return SessionCard(
            session: sessionWithDistance.session,
            distance: sessionWithDistance.distanceText,  // "2.5 km"
          );
        },
      );
    }
  },
)
```

---

## 5. Eventos del BLoC para Matchmaking

### Eventos Actualizados

```dart
// lib/bloc/session/session_event.dart
abstract class SessionEvent extends Equatable {
  const SessionEvent();

  @override
  List<Object?> get props => [];
}

class LoadSessions extends SessionEvent {
  final String groupId;

  const LoadSessions(this.groupId);

  @override
  List<Object> get props => [groupId];
}

class LoadAllUserSessions extends SessionEvent {
  final List<String> groupIds;
  final List<String> userSports;
  final String? userGender;
  final int? userAge;
  final UserLocation? userLocation;
  final double? maxDistanceKm;

  const LoadAllUserSessions({
    required this.groupIds,
    this.userSports = const [],
    this.userGender,
    this.userAge,
    this.userLocation,
    this.maxDistanceKm,
  });

  @override
  List<Object?> get props => [
        groupIds,
        userSports,
        userGender,
        userAge,
        userLocation,
        maxDistanceKm,
      ];
}

class DeleteSession extends SessionEvent {
  final String sessionId;

  const DeleteSession(this.sessionId);

  @override
  List<Object> get props => [sessionId];
}
```

### BLoC con Lógica de Matchmaking

```dart
// lib/bloc/session/session_bloc.dart (HANDLER ACTUALIZADO)
class SessionBloc extends Bloc<SessionEvent, SessionState> {
  final SessionService _sessionService;

  SessionBloc({required SessionService sessionService})
      : _sessionService = sessionService,
        super(SessionInitial()) {

    on<LoadAllUserSessions>(_onLoadAllUserSessions);
    on<LoadSessions>(_onLoadSessions);
    on<DeleteSession>(_onDeleteSession);
  }

  Future<void> _onLoadAllUserSessions(
    LoadAllUserSessions event,
    Emitter<SessionState> emit,
  ) async {
    emit(SessionLoading());
    try {
      // 🎯 Llamar al servicio con TODOS los criterios de matchmaking
      final sessions = await _sessionService.getAllUpcomingSessions(
        event.groupIds,
        userSports: event.userSports,
        userGender: event.userGender,
        userAge: event.userAge,
        userLocation: event.userLocation,
        maxDistanceKm: event.maxDistanceKm,
      );

      emit(SessionLoaded(sessions));
    } catch (e) {
      emit(SessionError(e.toString()));
    }
  }

  // ... otros handlers
}
```

---

## Resumen del Sistema de Matchmaking

### Criterios Aplicados (en orden)

1. **Grupos del Usuario** → Sesiones de grupos siempre visibles
2. **Deporte** → Filtrar por deportes preferidos
3. **Género** → Filtrar por `desiredGender` de la sesión
4. **Edad** → Filtrar por `minAge/maxAge` de la sesión
5. **Ubicación** (próximamente) → Filtrar por distancia máxima

### Priorización de Resultados

```
Ordenamiento de Sesiones:
1. Sesiones de grupos del usuario (sin orden específico)
2. Sesiones públicas ordenadas por:
   - Distancia (cuando se implemente ubicación)
   - Fecha del evento
```

### Estructura de Firestore

```
users/
  {userId}/
    ├── sports: ['fútbol', 'baloncesto']
    ├── gender: 'male'
    ├── age: 34
    └── location: { ... }  // (próximamente)

liveSessions/
  {sessionId}/
    ├── sport: 'fútbol'
    ├── desiredGender: 'any'
    ├── minAge: 18
    ├── maxAge: 45
    ├── location: { ... }  // (próximamente)
    ├── eventDate: Timestamp
    └── ... otros campos
```

### Ejemplo de Flujo Completo

```dart
// 1. Usuario con perfil completo
final user = UserModel(
  uid: 'user123',
  email: 'juan@example.com',
  firstName: 'Juan',
  lastName: 'Pérez',
  sports: ['fútbol', 'baloncesto'],
  gender: 'male',
  age: 34,
);

// 2. Cargar sesiones emparejadas
context.read<SessionBloc>().add(
  LoadAllUserSessions(
    groupIds: ['group1', 'group2'],
    userSports: user.sports,
    userGender: user.gender,
    userAge: user.age,  // 34
  ),
);

// 3. Sistema filtra automáticamente:
//    ✅ Sesiones de fútbol o baloncesto
//    ✅ desiredGender = 'any' o igual al género del usuario
//    ✅ Edad 34 dentro del rango permitido
//    🚧 (Próximamente) A menos de X km de distancia

// 4. Resultado: Sesiones ordenadas por fecha
```

---

## Mejoras Futuras Planificadas

- [ ] **Nivel de Habilidad**: Emparejar jugadores de nivel similar
- [ ] **Historial de Juego**: Priorizar sesiones con jugadores conocidos
- [ ] **Disponibilidad Horaria**: Filtrar por franjas horarias preferidas
- [ ] **Precio**: Filtrar por rango de precio aceptable
- [ ] **Ratio de Confirmación**: Priorizar sesiones con alta tasa de asistencia
- [ ] **Sistema de Recomendación**: ML para sugerir sesiones basado en comportamiento

---

**Última Actualización**: Sistema de matchmaking con filtros múltiples
**Versión**: 1.0
**Estado**: Deporte ✅ | Género ✅ | Edad ✅ | Ubicación 🚧