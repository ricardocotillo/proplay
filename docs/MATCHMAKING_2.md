# ProPlay - Sistema de Matchmaking (Referencia Técnica v2)

## Descripción General

ProPlay implementa un sistema de matchmaking inteligente que conecta a los usuarios con sesiones deportivas ("pichangas") relevantes. El sistema filtra y ordena las sesiones disponibles basándose en el perfil del usuario (deporte, género, edad) y su ubicación geográfica en tiempo real.

A diferencia de la versión inicial, esta implementación utiliza **GeoFirestore (geohashes)** para consultas espaciales eficientes y prioriza la proximidad física sobre radios de búsqueda fijos en la interfaz de usuario.

## Criterios de Emparejamiento

1.  **Deporte Preferido**: Solo se muestran sesiones que coinciden con la lista de deportes seleccionados por el usuario.
2.  **Género**: Filtrado estricto basado en la preferencia de la sesión (`desiredGender`) y el género del usuario.
3.  **Edad**: Filtrado por rango (`minAge`/`maxAge`) definido en la sesión.
4.  **Ubicación (Proximidad)**: Ordenamiento automático por distancia desde la posición actual del usuario.
5.  **Pertenencia a Grupos**: Las sesiones de los grupos a los que pertenece el usuario tienen prioridad y se muestran incluso si son privadas.

---

## Estado de Implementación

### Hecho ✅

-   **Perfil de Usuario**: `gender`, `age` y `sports` persistidos en Firestore (@/home/ricardo/dev/proplay/lib/models/user_model.dart:67-173).
-   **Modelos de Sesión**: `SessionModel` y `SessionTemplateModel` incluyen campos de ubicación y criterios de matchmaking (@/home/ricardo/dev/proplay/lib/models/session_model.dart:6-172).
-   **GeoFirestore**: Codificación automática de `locationLat`/`locationLng` a geohash (`g`) y lista de coordenadas (`l`) (@/home/ricardo/dev/proplay/lib/models/session_model.dart:137-140).
-   **Consultas Eficientes**: Implementación de `getPublicSessionsNearLocation` y `getGroupSessionsNearLocation` usando rangos de geohash (@/home/ricardo/dev/proplay/lib/services/session_service.dart:254-432).
-   **Lógica de Matchmaking**: `getAllUpcomingSessions` aplica todos los filtros (deporte, género, edad, distancia) y ordena por proximidad (@/home/ricardo/dev/proplay/lib/services/session_service.dart:435-578).
-   **Interfaz de Usuario**: `HomeScreen` y `UpcomingEventsCarousel` detectan ubicación y cargan sesiones recomendadas (@/home/ricardo/dev/proplay/lib/widgets/upcoming_events.dart:61-149).

### Próximo 🚧

-   **Nivel de Habilidad**: Filtrado por nivel (principiante, intermedio, avanzado).
-   **Historial de Jugadores**: Priorizar sesiones con amigos o jugadores frecuentes.
-   **Radio de Búsqueda Personalizable**: Permitir al usuario definir un `maxDistanceKm` en la configuración.

---

## Arquitectura del Sistema

### Flujo de Datos

```
[Geolocator] -> Coordenadas (Lat, Lng)
      |
      v
[User Profile] -> (Sports, Gender, Age)
      |
      v
[SessionBloc] -> Evento: LoadAllUserSessions
      |
      v
[SessionService] -> 1. Consulta Firestore (whereIn, geohash ranges)
                   2. Post-filtrado en cliente (exact distance, age, gender)
                   3. Ordenamiento (distancia -> fecha)
      |
      v
[UI] -> Carrusel (Home) / Lista (Sessions)
```

---

## 1. Modelos de Datos

### Perfil de Usuario (@/home/ricardo/dev/proplay/lib/models/user_model.dart)

El usuario debe completar su perfil para habilitar el matchmaking completo.

```dart
class UserModel {
  final String uid;
  final String? gender; // 'male', 'female', 'other'
  final int? age;
  final List<String> sports; // Lista de deportes favoritos
  
  // Getter para validar si el matchmaking puede funcionar plenamente
  bool get isMatchInfoComplete => gender != null && age != null;
}
```

### Sesión (@/home/ricardo/dev/proplay/lib/models/session_model.dart)

Tanto `SessionModel` como `SessionTemplateModel` comparten los criterios de matchmaking.

```dart
class SessionModel extends Equatable {
  final String sport;
  final int minAge;
  final int maxAge;
  final String desiredGender; // 'any', 'male', 'female'
  final double? locationLat;
  final double? locationLng;
  final String? locationAddress;

  // Conversión a Firestore con soporte GeoJSON/GeoFirestore
  Map<String, dynamic> toMap() {
    return {
      'sport': sport,
      'minAge': minAge,
      'maxAge': maxAge,
      'desiredGender': desiredGender,
      'locationLat': locationLat,
      'locationLng': locationLng,
      if (locationLat != null && locationLng != null) ...{
        'g': GeohashUtils.encode(locationLat!, locationLng!),
        'l': [locationLat, locationLng],
      },
      // ... otros campos
    };
  }
}
```

---

## 2. Servicio de Matchmaking (@/home/ricardo/dev/proplay/lib/services/session_service.dart)

El motor principal reside en `SessionService.getAllUpcomingSessions`.

### Algoritmo de Filtrado y Ordenamiento

```dart
Future<List<SessionModel>> getAllUpcomingSessions(
  List<String> userGroupIds, {
  List<String> userSports = const [],
  String? userGender,
  int? userAge,
  double? userLat,
  double? userLng,
  double? maxDistanceKm,
}) async {
  // 1. Obtiene sesiones de grupos y públicas (vía geohash si hay lat/lng)
  // 2. Aplica filtros post-consulta:
  
  final sportMatch = userSports.contains(session.sport);
  final genderMatch = _matchesGenderRequirement(
    sessionDesiredGender: session.desiredGender,
    userGender: userGender,
  );
  final ageMatch = _matchesAgeRequirement(
    sessionMinAge: session.minAge,
    sessionMaxAge: session.maxAge,
    userAge: userAge,
  );
  
  // 3. Ordenamiento por distancia (si el usuario tiene ubicación)
  if (userLat != null && userLng != null) {
    allSessions.sort((a, b) {
      // Cálculo de distancia Haversine
      final distanceA = LocationUtils.calculateDistance(userLat, userLng, a.lat, a.lng);
      final distanceB = LocationUtils.calculateDistance(userLat, userLng, b.lat, b.lng);
      
      final distanceComparison = distanceA.compareTo(distanceB);
      if (distanceComparison != 0) return distanceComparison;
      return a.eventDate.compareTo(b.eventDate); // Empate -> por fecha
    });
  }
}
```

### Optimización con Geohash (@/home/ricardo/dev/proplay/lib/utils/geohash_utils.dart)

Para evitar descargar todas las sesiones públicas de la base de datos, se utilizan consultas de rango sobre el campo `g` (geohash).

```dart
// Ejemplo de consulta por cercanía en Firestore
Query query = _firestore.collection('liveSessions')
    .where('isPrivate', isEqualTo: false)
    .where('g', isGreaterThanOrEqualTo: range.start)
    .where('g', isLessThanOrEqualTo: range.end)
    .where('desiredGender', isEqualTo: gender)
    .where('sport', isEqualTo: selectedSport);
```

---

## 3. Integración con la UI

### Carrusel de Recomendaciones (@/home/ricardo/dev/proplay/lib/widgets/upcoming_events.dart)

El componente `UpcomingEventsCarousel` es el punto de entrada principal para el usuario.

1.  **Validación**: Verifica si el usuario tiene `gender`, `age` y `sports` configurados. Si no, muestra un botón para completar el perfil.
2.  **Ubicación**: Recibe `userLat` y `userLng` desde `HomeScreen` (vía `Geolocator`).
3.  **Carga**: Dispara `LoadAllUserSessions` con `maxDistanceKm: null` para obtener todas las pichangas que coincidan con su perfil, ordenadas de más cerca a más lejos.

### Pantalla de Sesiones (@/home/ricardo/dev/proplay/lib/screens/sessions_screen.dart)

Muestra la lista completa de pichangas disponibles siguiendo la misma lógica de proximidad.

---

## 4. Estructura en Firestore

Las sesiones se almacenan en la colección `liveSessions` con la siguiente estructura clave para matchmaking:

-   `sport`: String (ej. "fútbol")
-   `isPrivate`: Boolean
-   `desiredGender`: String ("any", "male", "female")
-   `minAge`: Number
-   `maxAge`: Number
-   `locationLat`/`locationLng`: Geopunto simplificado
-   `g`: String (Geohash de precisión 6)
-   `l`: Array [Lat, Lng] (Coordenadas para compatibilidad GeoFirestore)
-   `eventDate`: Timestamp (Fecha de inicio)

---

## Resumen de Flujo para el Desarrollador

Si deseas agregar un nuevo filtro al matchmaking (ej. "nivel de habilidad"):

1.  Agrega el campo `skillLevel` a `UserModel` y `SessionModel`.
2.  Actualiza el método `toMap` y `fromMap` en ambos modelos.
3.  Modifica `SessionService.getAllUpcomingSessions` para incluir el post-filtrado por `skillLevel`.
4.  Si es posible filtrar en la consulta de Firestore, actualiza `getPublicSessionsNearLocation` y `getGroupSessionsNearLocation`.
5.  Actualiza los eventos de `SessionBloc` para pasar el nuevo parámetro.
6.  Actualiza la UI para mostrar o permitir filtrar por este nuevo criterio.

---

**Última Actualización**: 25 de Junio, 2026 (Reflejando implementación de Geohash y Proximidad)
**Versión de Documentación**: 2.0
**,EmptyFile:false,TargetFile:
