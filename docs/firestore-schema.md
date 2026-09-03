# Firestore schema

```text
users/{uid}
users/{uid}/devices/{deviceId}
users/{uid}/notifications/{notificationId}
users/{uid}/favorites/{favoriteId}
users/{uid}/blocks/{blockedUid}
activities/{activityId}
activities/{activityId}/participants/{uid}
activities/{activityId}/join_requests/{uid}
activities/{activityId}/chat/{messageId}
reports/{reportId}
```

Participação pública deve passar pela callable `joinActivity`, garantindo limite de vagas e ausência de duplicidade. Chat só é liberado para participante/criador pelas Security Rules.
