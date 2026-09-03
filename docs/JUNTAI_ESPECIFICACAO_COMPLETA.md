# Juntaí — Especificação completa do aplicativo Flutter

> Documento-base para construir o app **Juntaí** com a mesma aparência, fluxo e organização visual dos mockups aprovados.
>
> Objetivo: criar um app social de atividades próximas, onde pessoas encontram atividades, entram em grupos, conversam no chat, criam eventos e gerenciam o próprio perfil.
>
> Stack principal recomendada: **Flutter + Firebase + Google Maps**.

---

## 1. Visão geral do produto

### Proposta do Juntaí

O Juntaí conecta pessoas que querem **fazer algo hoje ou nos próximos dias**.

Exemplos:

- Futebol
- Corrida
- Pedalar
- Games
- Cinema
- Café
- Restaurante
- Academia
- Praia
- Trilha
- Música
- Estudos
- Jogos de mesa
- Networking

### Fluxo principal

```text
Splash / Onboarding
        ↓
Login / Cadastro
        ↓
Permissão de localização
        ↓
Home / Explorar
        ↓
┌──────────────┬──────────────┬──────────────┐
│              │              │              │
Mapa       Criar atividade   Pesquisa      Perfil
│              │              │              │
Atividade      Publicar       Resultados     Editar
│
Detalhes da atividade
│
Participar
│
Chat do grupo
```

### Navegação inferior

A navegação principal do app terá 5 itens:

1. **Início**
2. **Mapa**
3. **Criar**
4. **Chat**
5. **Perfil**

O botão **Criar** será maior, circular, centralizado e destacado em verde.

---

# 2. Identidade visual

## Nome

**Juntaí**

## Conceito visual

A identidade precisa transmitir:

- pessoas
- amizade
- encontro
- proximidade
- localização
- atividades
- segurança
- simplicidade

## Logo

O logo deve usar:

- wordmark `Juntaí`
- cor verde principal
- tipografia arredondada
- ícone próprio combinando:
  - pin de localização
  - pessoas
  - encontro/conexão

## Ícone do aplicativo

Criar arquivo próprio para:

```text
assets/branding/app_icon.png
```

Sugestão:

- fundo verde
- pin branco
- 3 pessoas dentro do pin
- sem texto
- legível em tamanho pequeno

## Splash logo

```text
assets/branding/logo_full.png
assets/branding/logo_mark.png
```

---

# 3. Design System

## Cores

Os mockups aprovados usam branco + verde esmeralda + pequenos destaques coloridos.

Sugestão de tokens:

```dart
class AppColors {
  static const primary = Color(0xFF08A77B);
  static const primaryDark = Color(0xFF067A5D);
  static const primaryLight = Color(0xFFE7F8F2);

  static const background = Color(0xFFFDFDFD);
  static const surface = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF151922);
  static const textSecondary = Color(0xFF697386);
  static const border = Color(0xFFE4E8EE);

  static const blue = Color(0xFF2589F4);
  static const purple = Color(0xFF7C4DFF);
  static const orange = Color(0xFFD8892F);
  static const red = Color(0xFFFF5A66);

  static const success = Color(0xFF08A77B);
  static const warning = Color(0xFFFFB547);
  static const error = Color(0xFFE5484D);
}
```

## Espaçamentos

Usar grid de 4/8 px.

```text
4
8
12
16
20
24
32
40
48
```

Padrão recomendado:

```text
Margem horizontal da tela: 20–24 px
Espaço entre cards: 12–16 px
Padding interno do card: 16 px
Padding de botões: 14–18 px
```

## Border radius

```text
Input: 18–22
Card: 20–24
Chip: 16–18
Botão: 18–22
Avatar: circular
FAB Criar: circular
```

## Sombras

Usar sombras suaves.

```dart
BoxShadow(
  color: Colors.black.withValues(alpha: 0.06),
  blurRadius: 18,
  offset: const Offset(0, 6),
)
```

## Tipografia

Recomendação:

- **Google Fonts: Inter**
- alternativa: **Plus Jakarta Sans**

Pesos:

```text
Regular 400
Medium 500
SemiBold 600
Bold 700
```

Hierarquia:

```text
Título de tela       30–34 / Bold
Título principal     26–30 / Bold
Título de card       18–20 / SemiBold
Texto normal         15–17 / Regular
Texto auxiliar       13–14 / Regular
Label                 12–13 / Medium
```

---

# 4. Ícones

## Estratégia

### Criar do zero

Somente:

- logo
- app icon
- logo mark

### Usar pronto no Flutter

Usar **Material Icons Rounded** para manter consistência.

## Navegação

| Função | Ícone Flutter |
|---|---|
| Início | `Icons.home_rounded` |
| Mapa | `Icons.location_on_rounded` |
| Criar | `Icons.add_rounded` |
| Chat | `Icons.chat_bubble_rounded` |
| Perfil | `Icons.person_rounded` |

## Cabeçalho

| Função | Ícone |
|---|---|
| Pesquisa | `Icons.search_rounded` |
| Filtro | `Icons.tune_rounded` |
| Notificações | `Icons.notifications_none_rounded` |
| Voltar | `Icons.arrow_back_rounded` |
| Mais opções | `Icons.more_vert_rounded` |

## Atividade

| Função | Ícone |
|---|---|
| Local | `Icons.location_on_outlined` |
| Data | `Icons.calendar_month_outlined` |
| Horário | `Icons.access_time_rounded` |
| Participantes | `Icons.groups_rounded` |
| Compartilhar | `Icons.share_rounded` |
| Favorito | `Icons.favorite_border_rounded` |
| Favoritado | `Icons.favorite_rounded` |
| Participar | `Icons.person_add_alt_1_rounded` |

## Chat

| Função | Ícone |
|---|---|
| Emoji | `Icons.emoji_emotions_outlined` |
| Anexo | `Icons.attach_file_rounded` |
| Foto | `Icons.photo_camera_rounded` |
| Microfone | `Icons.mic_none_rounded` |
| Enviar | `Icons.send_rounded` |

## Perfil e segurança

| Função | Ícone |
|---|---|
| Editar | `Icons.edit_rounded` |
| Configurações | `Icons.settings_rounded` |
| Privacidade | `Icons.privacy_tip_rounded` |
| Bloquear | `Icons.block_rounded` |
| Denunciar | `Icons.flag_rounded` |
| Verificado | `Icons.verified_rounded` |
| Avaliação | `Icons.star_rounded` |
| Logout | `Icons.logout_rounded` |

## Categorias

| Categoria | Ícone |
|---|---|
| Futebol | `Icons.sports_soccer_rounded` |
| Corrida | `Icons.directions_run_rounded` |
| Pedalar | `Icons.directions_bike_rounded` |
| Games | `Icons.sports_esports_rounded` |
| Cinema | `Icons.movie_rounded` |
| Café | `Icons.local_cafe_rounded` |
| Restaurante | `Icons.restaurant_rounded` |
| Academia | `Icons.fitness_center_rounded` |
| Música | `Icons.music_note_rounded` |
| Praia | `Icons.beach_access_rounded` |
| Trilha | `Icons.terrain_rounded` |
| Estudos | `Icons.menu_book_rounded` |
| Pet | `Icons.pets_rounded` |
| Jogos de mesa | `Icons.casino_rounded` |

---

# 5. Estrutura de pastas Flutter

Arquitetura recomendada: **feature-first + clean architecture simplificada**.

```text
lib/
│
├── main.dart
├── bootstrap.dart
│
├── app/
│   ├── app.dart
│   ├── router/
│   │   ├── app_router.dart
│   │   ├── route_names.dart
│   │   └── route_guards.dart
│   │
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_theme.dart
│   │   ├── app_typography.dart
│   │   ├── app_spacing.dart
│   │   ├── app_radius.dart
│   │   └── app_shadows.dart
│   │
│   └── constants/
│       ├── app_constants.dart
│       ├── firestore_paths.dart
│       └── storage_paths.dart
│
├── core/
│   ├── errors/
│   │   ├── app_exception.dart
│   │   └── error_handler.dart
│   │
│   ├── extensions/
│   │   ├── context_extensions.dart
│   │   ├── date_extensions.dart
│   │   └── string_extensions.dart
│   │
│   ├── utils/
│   │   ├── validators.dart
│   │   ├── debouncer.dart
│   │   ├── geo_utils.dart
│   │   ├── date_utils.dart
│   │   └── image_utils.dart
│   │
│   ├── services/
│   │   ├── analytics_service.dart
│   │   ├── notification_service.dart
│   │   ├── permission_service.dart
│   │   ├── location_service.dart
│   │   └── deep_link_service.dart
│   │
│   └── widgets/
│       ├── app_button.dart
│       ├── app_outline_button.dart
│       ├── app_text_field.dart
│       ├── app_search_field.dart
│       ├── app_avatar.dart
│       ├── app_badge.dart
│       ├── app_empty_state.dart
│       ├── app_error_state.dart
│       ├── app_loading.dart
│       ├── app_bottom_nav.dart
│       ├── app_sheet.dart
│       └── app_dialog.dart
│
├── features/
│   │
│   ├── splash/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── splash_screen.dart
│   │   │   │   └── onboarding_screen.dart
│   │   │   └── widgets/
│   │   └── providers/
│   │
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── auth_remote_data_source.dart
│   │   ├── domain/
│   │   │   └── auth_user.dart
│   │   ├── providers/
│   │   │   └── auth_provider.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── login_screen.dart
│   │       │   ├── register_screen.dart
│   │       │   ├── forgot_password_screen.dart
│   │       │   └── verify_email_screen.dart
│   │       └── widgets/
│   │           ├── social_login_button.dart
│   │           └── password_field.dart
│   │
│   ├── home/
│   │   ├── providers/
│   │   │   ├── home_provider.dart
│   │   │   └── category_provider.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── home_screen.dart
│   │       └── widgets/
│   │           ├── home_header.dart
│   │           ├── category_row.dart
│   │           ├── category_chip.dart
│   │           ├── nearby_section.dart
│   │           └── activity_card.dart
│   │
│   ├── search/
│   │   ├── data/
│   │   │   └── search_repository.dart
│   │   ├── providers/
│   │   │   └── search_provider.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── search_screen.dart
│   │       │   └── filters_screen.dart
│   │       └── widgets/
│   │           ├── search_result_activity.dart
│   │           ├── search_result_user.dart
│   │           └── filter_chip.dart
│   │
│   ├── notifications/
│   │   ├── data/
│   │   │   └── notification_repository.dart
│   │   ├── providers/
│   │   │   └── notification_provider.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── notifications_screen.dart
│   │       └── widgets/
│   │           └── notification_tile.dart
│   │
│   ├── map/
│   │   ├── data/
│   │   │   └── map_repository.dart
│   │   ├── providers/
│   │   │   └── map_provider.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── map_screen.dart
│   │       └── widgets/
│   │           ├── map_activity_marker.dart
│   │           ├── selected_activity_card.dart
│   │           ├── map_filter_button.dart
│   │           └── my_location_button.dart
│   │
│   ├── activities/
│   │   ├── data/
│   │   │   ├── activity_repository.dart
│   │   │   └── activity_remote_data_source.dart
│   │   ├── domain/
│   │   │   ├── activity.dart
│   │   │   ├── activity_category.dart
│   │   │   └── participant.dart
│   │   ├── providers/
│   │   │   ├── activities_provider.dart
│   │   │   ├── activity_details_provider.dart
│   │   │   └── create_activity_provider.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── activity_details_screen.dart
│   │       │   ├── create_activity_screen.dart
│   │       │   ├── edit_activity_screen.dart
│   │       │   └── participants_screen.dart
│   │       └── widgets/
│   │           ├── activity_cover.dart
│   │           ├── activity_info_row.dart
│   │           ├── participants_avatar_row.dart
│   │           ├── privacy_selector.dart
│   │           ├── participant_counter.dart
│   │           └── activity_category_selector.dart
│   │
│   ├── chat/
│   │   ├── data/
│   │   │   ├── chat_repository.dart
│   │   │   └── chat_remote_data_source.dart
│   │   ├── domain/
│   │   │   ├── conversation.dart
│   │   │   └── chat_message.dart
│   │   ├── providers/
│   │   │   ├── conversations_provider.dart
│   │   │   └── chat_provider.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── conversations_screen.dart
│   │       │   └── group_chat_screen.dart
│   │       └── widgets/
│   │           ├── message_bubble.dart
│   │           ├── chat_input.dart
│   │           ├── typing_indicator.dart
│   │           └── unread_badge.dart
│   │
│   ├── profile/
│   │   ├── data/
│   │   │   └── profile_repository.dart
│   │   ├── domain/
│   │   │   └── user_profile.dart
│   │   ├── providers/
│   │   │   └── profile_provider.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── profile_screen.dart
│   │       │   ├── edit_profile_screen.dart
│   │       │   ├── settings_screen.dart
│   │       │   ├── privacy_screen.dart
│   │       │   ├── blocked_users_screen.dart
│   │       │   └── public_profile_screen.dart
│   │       └── widgets/
│   │           ├── profile_header.dart
│   │           ├── profile_stats.dart
│   │           ├── verification_badge.dart
│   │           └── profile_menu_tile.dart
│   │
│   └── moderation/
│       ├── data/
│       │   └── moderation_repository.dart
│       └── presentation/
│           ├── report_user_sheet.dart
│           ├── report_activity_sheet.dart
│           └── block_user_dialog.dart
│
└── shared/
    ├── models/
    ├── enums/
    └── widgets/
```

---

# 6. Assets

```text
assets/
│
├── branding/
│   ├── logo_full.png
│   ├── logo_mark.png
│   └── app_icon.png
│
├── illustrations/
│   ├── onboarding_people.png
│   ├── empty_activities.png
│   ├── empty_chat.png
│   └── location_permission.png
│
├── placeholders/
│   ├── avatar.png
│   └── activity_cover.png
│
└── map/
    └── marker_base.png
```

Adicionar ao `pubspec.yaml`.

---

# 7. Bibliotecas Flutter

> Evitar travar o projeto em versões específicas neste documento. Usar sempre versões estáveis compatíveis com a versão de Flutter adotada no projeto.

## Essenciais

```yaml
flutter_riverpod:
riverpod_annotation:
go_router:
freezed_annotation:
json_annotation:
intl:
uuid:
collection:
```

## Geração de código

```yaml
dev_dependencies:
  build_runner:
  riverpod_generator:
  freezed:
  json_serializable:
```

## Firebase

```yaml
firebase_core:
firebase_auth:
cloud_firestore:
firebase_storage:
firebase_messaging:
firebase_analytics:
firebase_crashlytics:
cloud_functions:
```

## Login social

```yaml
google_sign_in:
sign_in_with_apple:
```

## Mapas e localização

```yaml
google_maps_flutter:
geolocator:
geocoding:
permission_handler:
```

Opcional:

```yaml
flutter_google_places_sdk:
```

## Imagens

```yaml
image_picker:
cached_network_image:
flutter_image_compress:
```

## UI

```yaml
google_fonts:
shimmer:
flutter_svg:
```

## Armazenamento local

```yaml
flutter_secure_storage:
shared_preferences:
```

## Notificações locais

```yaml
flutter_local_notifications:
```

## Deep links e compartilhamento

```yaml
share_plus:
app_links:
url_launcher:
```

## Utilidades

```yaml
timeago:
connectivity_plus:
package_info_plus:
device_info_plus:
```

---

# 8. Backend recomendado

## Firebase

Serviços:

1. Firebase Authentication
2. Cloud Firestore
3. Firebase Storage
4. Firebase Cloud Messaging
5. Firebase Cloud Functions
6. Firebase Analytics
7. Firebase Crashlytics
8. Firebase App Check

### Motivo

O Juntaí precisa de:

- autenticação
- realtime
- chat
- push
- armazenamento de foto
- presença social
- escalabilidade inicial
- regras de segurança

Firebase atende muito bem a esse cenário.

---

# 9. Google Cloud / APIs externas

## Google Maps

Ativar no Google Cloud:

- Maps SDK for Android
- Maps SDK for iOS
- Places API
- Geocoding API

### Uso

- mapa de atividades
- autocomplete de endereço
- pesquisa de locais
- obtenção de lat/lng
- abrir local da atividade
- distância aproximada

### Segurança das chaves

Nunca usar uma API key irrestrita.

Android:

```text
Restringir por:
package name
SHA-1/SHA-256
```

iOS:

```text
Restringir por:
Bundle ID
```

---

# 10. Modelos principais

## UserProfile

```dart
class UserProfile {
  final String id;
  final String name;
  final String? photoUrl;
  final String city;
  final String? bio;
  final bool verified;
  final double rating;
  final List<String> interests;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
}
```

## Activity

```dart
class Activity {
  final String id;
  final String creatorId;

  final String title;
  final String description;
  final String category;

  final String address;
  final double latitude;
  final double longitude;
  final String geohash;

  final DateTime startsAt;

  final int maxParticipants;
  final int participantCount;

  final bool isPrivate;
  final String? coverUrl;

  final String status;

  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Status:

```text
active
full
cancelled
finished
```

## ChatMessage

```dart
class ChatMessage {
  final String id;
  final String senderId;
  final String type;
  final String text;
  final String? mediaUrl;
  final DateTime createdAt;
  final List<String> seenBy;
}
```

Tipos:

```text
text
image
system
```

## NotificationModel

```dart
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? activityId;
  final String? actorId;
  final bool read;
  final DateTime createdAt;
}
```

---

# 11. Estrutura do Firestore

```text
users/{userId}

users/{userId}/devices/{deviceId}

users/{userId}/notifications/{notificationId}

activities/{activityId}

activities/{activityId}/participants/{userId}

activities/{activityId}/chat/{messageId}

activities/{activityId}/join_requests/{requestId}

blocks/{blockId}

reports/{reportId}
```

## Documento `users`

```json
{
  "name": "Mariana Costa",
  "email": "mariana@email.com",
  "photoUrl": "...",
  "city": "São Paulo, SP",
  "bio": "Apaixonada por conectar pessoas...",
  "verified": false,
  "rating": 4.9,
  "interests": ["futebol", "cafe", "pedalar"],
  "activitiesCreated": 24,
  "activitiesJoined": 72,
  "friendsCount": 156,
  "createdAt": "...",
  "updatedAt": "..."
}
```

## Documento `activities`

```json
{
  "creatorId": "uid",
  "title": "Futebol no Parque",
  "description": "Vamos jogar...",
  "category": "football",
  "address": "Parque Ibirapuera, Vila Mariana",
  "latitude": -23.5874,
  "longitude": -46.6576,
  "geohash": "...",
  "startsAt": "...",
  "maxParticipants": 14,
  "participantCount": 10,
  "isPrivate": false,
  "coverUrl": "...",
  "status": "active",
  "createdAt": "...",
  "updatedAt": "..."
}
```

---

# 12. Firebase Storage

Estrutura:

```text
users/
  {userId}/
    avatar.jpg

activities/
  {activityId}/
    cover.jpg

chat/
  {activityId}/
    {messageId}.jpg
```

Regras:

- usuário altera apenas seus próprios arquivos
- capa da atividade apenas criador
- mídia de chat apenas participante da atividade
- validar tamanho
- validar MIME type

---

# 13. Autenticação

## Métodos

### MVP

- e-mail + senha
- Google
- Apple

### Fluxos

```text
Splash
 ↓
Firebase Auth verifica sessão
 ↓
Logado?
 ├─ Não → Login
 └─ Sim → Perfil completo?
           ├─ Não → Completar perfil
           └─ Sim → Home
```

## Login

Tela igual ao mockup:

```text
Juntaí

Entre para encontrar pessoas e
atividades perto de você.

[E-mail]
[Senha]

Esqueci minha senha

[ Entrar ]

[ Criar conta ]

ou continue com

[ Continuar com Google ]
[ Continuar com Apple ]
```

## Cadastro

Campos:

```text
Nome
E-mail
Senha
Confirmar senha
Data de nascimento
Cidade
Aceite dos Termos
Aceite da Política de Privacidade
```

Depois:

```text
Foto
Bio
Interesses
Localização
```

## Recuperar senha

Firebase:

```dart
FirebaseAuth.instance.sendPasswordResetEmail(...)
```

## Verificação de e-mail

Recomendada para contas de e-mail/senha.

---

# 14. Splash / Onboarding

## Tela

Igual ao mockup aprovado:

- logo grande
- pin com pessoas
- frase:
  - `Encontre pessoas para fazer algo hoje.`
- ilustração com pessoas
- categorias flutuantes
- botão `Começar`
- link `Entrar`

## Ações

`Começar`

```text
se não cadastrado → Cadastro
```

`Entrar`

```text
→ Login
```

---

# 15. Solicitação de localização

Depois do login:

```text
"Use sua localização para encontrar atividades perto de você."
```

Opções:

```text
[ Permitir localização ]
[ Agora não ]
```

Usar:

```dart
geolocator
permission_handler
```

Nunca impedir o uso do app caso usuário negue.

Fallback:

```text
Selecionar cidade manualmente
```

---

# 16. Home / Tela inicial

## Layout

### Header

```text
Juntaí                    🔔   Avatar

Bora fazer algo hoje? 👋
Encontre pessoas e atividades perto de você.
```

### Pesquisa

```text
[ 🔍 Buscar atividades ou pessoas       ⚙ ]
```

### Categorias

Scroll horizontal:

```text
⚽ Futebol
🏃 Corrida
🚴 Pedalar
🎮 Games
🎬 Cinema
☕ Café
```

### Perto de você

```text
📍 Perto de você                      Ver no mapa >
```

Cards:

```text
Imagem
Categoria
Título
Local
Hoje • 16:00
10 / 14 participantes
Avatares
1,2 km
[ Participar ]
```

---

# 17. ActivityCard

Componente principal:

```text
ActivityCard
```

Propriedades:

```dart
ActivityCard({
  required Activity activity,
  required VoidCallback onTap,
  required VoidCallback onJoin,
})
```

Exibir:

- imagem
- badge categoria
- título
- distância
- endereço
- horário
- participantes
- avatars
- botão participar

---

# 18. Pesquisa

## Tela de pesquisa

Pesquisar:

- atividades
- pessoas
- categorias

Campo:

```text
Buscar atividades ou pessoas
```

## Debounce

Executar busca apenas após aproximadamente 300–500 ms sem digitação.

Criar:

```text
core/utils/debouncer.dart
```

## Busca MVP

Firestore:

- categoria
- cidade
- status
- datas

## Busca textual avançada

Quando o app crescer, integrar:

- Algolia
- Typesense
- Meilisearch

A busca textual deve indexar:

### Atividade

```text
title
description
category
city
address
```

### Usuário

```text
name
city
interests
```

---

# 19. Filtros

Filtros:

```text
Categoria
Distância
Hoje
Amanhã
Fim de semana
Horário
Com vagas
Público
```

Distância:

```text
1 km
3 km
5 km
10 km
25 km
50 km
```

---

# 20. Mapa

## Biblioteca

```yaml
google_maps_flutter:
```

## Tela

Igual ao mockup:

```text
Mapa                            [ Filtrar ]

[ mapa ]

     📍 atividades

[ Card flutuante da atividade ]

                        [ Minha localização ]

Início  Mapa  +  Chat  Perfil
```

## Marcadores

Marcadores por categoria:

```text
Futebol   verde
Corrida   azul
Bike      verde claro
Games     roxo
Cinema    vermelho
Café      laranja
```

## Ao tocar no marcador

Mostrar card:

```text
Futebol no Parque
1,2 km
Parque Ibirapuera
Hoje • 16:00
10 / 14
[ Ver detalhes ]
```

---

# 21. Geolocalização

Usar:

```yaml
geolocator:
```

Funções:

```dart
Future<Position> getCurrentPosition();
Stream<Position> watchPosition();
Future<bool> requestPermission();
```

## Privacidade

Não armazenar posição contínua do usuário sem necessidade.

Guardar somente:

```text
cidade
latitude aproximada opcional
longitude aproximada opcional
```

Local exato deve ser usado apenas para:

- encontrar distância
- centralizar mapa
- criar atividade

---

# 22. Criar atividade

Tela igual ao mockup.

## Campos

### Categoria

```text
Futebol
Corrida
Pedalar
Games
Cinema
Café
...
```

### Título

```text
Ex.: Futebol no Parque
```

### Local

Usar autocomplete do Google Places.

### Data

DatePicker.

### Horário

TimePicker.

### Participantes

```text
mínimo: 2
máximo configurável
```

### Privacidade

```text
Público
Privado
```

### Descrição

Máximo inicial:

```text
300 caracteres
```

### Foto

Opcional:

```text
Adicionar capa
```

## Botão

```text
Publicar atividade
```

---

# 23. Validação para criação

Validar:

```text
título não vazio
categoria selecionada
local válido
data futura
horário válido
mínimo 2 participantes
descrição dentro do limite
```

---

# 24. ActivityRepository

Funções:

```dart
abstract class ActivityRepository {
  Future<String> createActivity(Activity activity);

  Future<void> updateActivity(Activity activity);

  Future<void> cancelActivity(String activityId);

  Future<void> joinActivity(String activityId);

  Future<void> leaveActivity(String activityId);

  Stream<Activity> watchActivity(String activityId);

  Stream<List<Activity>> watchNearbyActivities(...);

  Future<List<Activity>> searchActivities(...);

  Stream<List<UserProfile>> watchParticipants(String activityId);
}
```

---

# 25. Participar da atividade

## Público

Ao clicar:

```text
Participar
  ↓
verificar login
  ↓
verificar vagas
  ↓
adicionar participante
  ↓
atualizar contador
  ↓
entrar no chat
  ↓
notificar criador
```

## Privado

```text
Solicitar participação
```

Criador recebe:

```text
Mariana quer participar de Futebol no Parque
[Aceitar] [Recusar]
```

---

# 26. Cloud Functions importantes

Para evitar manipulação indevida do cliente:

## joinActivity

```text
- verificar autenticação
- verificar atividade existente
- verificar status
- verificar vagas
- evitar duplicidade
- criar participante
- incrementar participantCount
- criar notificação
```

## leaveActivity

```text
- remover participante
- decrementar contador
```

## createNotification

```text
- gravar Firestore
- enviar FCM
```

## deleteAccount

```text
- remover dados do usuário
- remover arquivos
- anonimizar dados necessários
```

## reportContent

```text
- salvar denúncia
- registrar alvo
- registrar motivo
```

---

# 27. Tela de detalhes da atividade

Igual ao mockup.

## Header

Imagem grande.

Sobre a imagem:

```text
←
Compartilhar
•••
```

## Conteúdo

```text
Futebol no Parque

[Futebol]

📍 Parque Ibirapuera, Vila Mariana
📅 Hoje • 16:00
👥 10 / 14 participantes
👤 Criado por Lucas

Descrição...
```

## Ações

```text
[ Participar ]

[ Compartilhar ] [ Chat do grupo ]
```

## Quem vai

Avatares:

```text
○ ○ ○ ○ ○ +5
```

---

# 28. Chat

## Estrutura

Cada atividade possui chat próprio:

```text
activities/{activityId}/chat/{messageId}
```

## Acesso

Apenas participantes devem acessar.

## Tela

Header:

```text
← [foto] Futebol no Parque
          10 / 14 participantes        ⋮
```

Mensagens:

```text
Lucas
Galera, reservei a quadra
para hoje às 16:00! ⚽

                      Boa, Lucas! 🙌

Mariana
Chego 15:50, beleza?
```

Input:

```text
🙂  Escrever mensagem...      📎 🎤    ➤
```

---

# 29. ChatRepository

```dart
abstract class ChatRepository {
  Stream<List<ChatMessage>> watchMessages(String activityId);

  Future<void> sendTextMessage({
    required String activityId,
    required String text,
  });

  Future<void> sendImageMessage({
    required String activityId,
    required File file,
  });

  Future<void> markAsRead({
    required String activityId,
  });

  Future<void> deleteMessage(...);
}
```

---

# 30. Realtime do chat

Firestore snapshot listener:

```dart
FirebaseFirestore.instance
    .collection('activities')
    .doc(activityId)
    .collection('chat')
    .orderBy('createdAt', descending: true)
    .snapshots();
```

Usar paginação.

Não carregar milhares de mensagens de uma vez.

Exemplo:

```text
20–40 mensagens por página
```

---

# 31. Lista de chats

Tela `Chat` na bottom navigation.

Cards:

```text
[foto] Futebol no Parque
       Mariana: Chego 15:50...
       10:18                           2
```

Ordenar por:

```text
última mensagem
```

Campos de conversation:

```text
lastMessage
lastMessageAt
unreadCount
```

---

# 32. Notificações — sininho

## Sininho

No header:

```text
🔔
```

Badge:

```text
2
```

Somente mostrar badge quando houver notificações não lidas.

## Tipos de notificações

```text
join_request
join_approved
new_participant
activity_updated
activity_cancelled
activity_reminder
new_message
rating_request
```

## Tela de notificações

Exemplos:

```text
Lucas aceitou sua participação
Futebol no Parque
Agora

Mariana entrou em sua atividade
2 min

Futebol no Parque começa em 1 hora
15:00
```

---

# 33. Push Notification

Usar:

```yaml
firebase_messaging:
flutter_local_notifications:
```

## Fluxo

```text
app obtém FCM token
 ↓
salva em users/{uid}/devices/{deviceId}
 ↓
evento acontece
 ↓
Cloud Function
 ↓
FCM
 ↓
celular recebe push
```

---

# 34. Perfil

Tela igual ao mockup.

## Header

```text
Juntaí                          🔔

[ Avatar ] Mariana Costa
           📍 São Paulo, SP

           Bio...

           ✓ Verificado
           ★ Nota 4,9
```

## Estatísticas

```text
24                 72                  156
Atividades         Participações       Amigos
organizadas        em atividades       na rede
```

## Próximas atividades

Cards compactos.

## Favoritos

Categorias favoritas.

## Menu

```text
Editar perfil >
Configurações >
Privacidade >
```

---

# 35. Editar perfil

Campos:

```text
Foto
Nome
Cidade
Bio
Interesses
```

Limites:

```text
nome: 60 caracteres
bio: 160–250
```

---

# 36. Perfil público

Mostrar:

```text
Avatar
Nome
Cidade
Bio
Verificado
Nota
Atividades criadas
Participações
Interesses
Avaliações
```

Ações:

```text
Bloquear
Denunciar
```

---

# 37. Avaliação

Após uma atividade finalizar:

```text
Como foi sua experiência?
★★★★★
```

Pode avaliar:

- organizador
- atividade

Evitar sistema complexo no MVP.

---

# 38. Segurança social

Obrigatório para o Juntaí.

## Bloquear usuário

Usuário bloqueado:

- não vê perfil completo
- não envia mensagem direta futura
- pode ser ocultado em resultados
- não deve ser recomendado

## Denunciar

Motivos:

```text
Assédio
Spam
Perfil falso
Conteúdo impróprio
Golpe
Ameaça
Outro
```

## ReportRepository

```dart
Future<void> reportUser(...)
Future<void> reportActivity(...)
Future<void> blockUser(...)
Future<void> unblockUser(...)
```

---

# 39. Firestore Security Rules

Regras essenciais:

## Usuário

```text
ler perfil público
editar apenas próprio perfil
```

## Atividade

```text
criador edita atividade
usuário autenticado pode consultar públicas
```

## Participantes

```text
entrada deve ser validada
```

Preferível realizar join por Cloud Function para controlar:

```text
vagas
duplicidade
status
privacidade
```

## Chat

```text
somente participante pode ler
somente participante pode enviar
senderId deve ser auth.uid
```

---

# 40. Firebase App Check

Ativar.

Ajuda a reduzir:

- chamadas abusivas
- scripts automatizados
- acesso direto não autorizado

---

# 41. Rotas

Usar:

```yaml
go_router:
```

Estrutura:

```text
/splash
/onboarding
/login
/register
/forgot-password

/home
/search
/notifications

/map

/activity/:id
/activity/create
/activity/:id/edit
/activity/:id/participants

/chats
/chat/:activityId

/profile
/profile/edit
/profile/:userId
/settings
/privacy
/blocked-users
```

---

# 42. Bottom Navigation

Criar componente:

```text
AppBottomNav
```

Itens:

```dart
const tabs = [
  BottomNavItem(
    label: 'Início',
    icon: Icons.home_rounded,
  ),
  BottomNavItem(
    label: 'Mapa',
    icon: Icons.location_on_rounded,
  ),
  BottomNavItem(
    label: 'Criar',
    icon: Icons.add_rounded,
    isCenterAction: true,
  ),
  BottomNavItem(
    label: 'Chat',
    icon: Icons.chat_bubble_outline_rounded,
  ),
  BottomNavItem(
    label: 'Perfil',
    icon: Icons.person_outline_rounded,
  ),
];
```

---

# 43. Estado com Riverpod

## Providers principais

```text
authProvider
currentUserProvider
locationProvider
homeActivitiesProvider
selectedCategoryProvider
searchProvider
notificationsProvider
unreadNotificationsCountProvider
mapActivitiesProvider
activityDetailsProvider
createActivityProvider
conversationsProvider
chatMessagesProvider
profileProvider
```

---

# 44. Componentes reutilizáveis

Criar antes de construir todas as telas.

## Base

```text
AppScaffold
AppButton
AppOutlineButton
AppTextField
AppSearchField
AppAvatar
AppBadge
AppChip
AppSectionHeader
AppLoading
AppError
AppEmpty
AppBottomNav
```

## Atividade

```text
ActivityCard
CompactActivityCard
ActivityInfoRow
CategoryChip
CategorySelector
ParticipantAvatarRow
ParticipantCounter
PrivacySelector
ActivityCover
```

## Chat

```text
MessageBubble
ChatInput
ConversationTile
UnreadBadge
```

## Perfil

```text
ProfileHeader
ProfileStats
ProfileMenuTile
VerifiedBadge
RatingBadge
```

---

# 45. Estados de UI obrigatórios

Toda tela deve ter:

## Loading

Skeleton/shimmer.

## Empty

Exemplo:

```text
Nenhuma atividade por perto.
Crie uma e chame a galera.
```

## Error

```text
Não foi possível carregar.
[Tentar novamente]
```

## Offline

```text
Sem conexão.
Algumas informações podem estar desatualizadas.
```

---

# 46. Home loading

Não mostrar spinner gigante.

Usar skeleton para:

- categorias
- cards
- avatars

Pacote:

```yaml
shimmer:
```

---

# 47. Imagens de atividade

## Upload

Antes de enviar:

```text
redimensionar
comprimir
remover metadados desnecessários
```

Pacotes:

```yaml
image_picker:
flutter_image_compress:
```

## Sugestão

```text
máximo 1920 px
JPEG ~75–85%
```

---

# 48. Avatar

Tamanho visual:

```text
perfil: 96–120
header: 44–48
participantes: 32–40
chat: 36–44
```

Usar `CachedNetworkImage`.

---

# 49. Distância

Para tela home e mapa:

```text
0,7 km
1,2 km
1,5 km
```

Calcular a partir de:

```text
localização atual
latitude/longitude da atividade
```

Utilizar função Haversine ou API utilitária local.

Não chamar servidor apenas para calcular distância simples.

---

# 50. Ordenação da Home

Sugestão:

1. atividade acontecendo em breve
2. distância
3. vagas disponíveis
4. categoria favorita
5. popularidade

No MVP:

```text
distance + startsAt
```

---

# 51. Favoritos

Usuário pode salvar:

- atividade
- categoria

Estrutura:

```text
users/{uid}/favorites/{favoriteId}
```

ou arrays pequenos no perfil para categorias.

---

# 52. Analytics

Eventos:

```text
app_open
login
register
search
search_filter
activity_view
activity_create
activity_join
activity_leave
map_open
map_marker_click
chat_message_send
profile_view
notification_open
report_submit
```

Usar Firebase Analytics.

---

# 53. Crash reporting

Usar:

```yaml
firebase_crashlytics:
```

Registrar:

- erros de rede
- exceções inesperadas
- falhas de Firebase
- erros de upload

Nunca registrar:

- senha
- token
- conteúdo privado de chat
- dados pessoais desnecessários

---

# 54. Performance

## Firestore

Evitar:

```text
ler todas as atividades
```

Usar:

```text
paginação
filtros
índices
limites
```

## Imagens

Sempre cachear.

## Chat

Paginação.

## Mapa

Mostrar somente atividades visíveis na área ou raio.

---

# 55. Índices Firestore prováveis

Exemplos:

```text
activities:
status + startsAt

activities:
category + status + startsAt

activities:
city + status + startsAt

activities:
geohash + status

notifications:
userId + read + createdAt
```

Os índices exatos serão gerados conforme as queries finais.

---

# 56. Notificação de lembrete

Cloud Scheduler / Functions:

```text
1 hora antes da atividade
```

Exemplo:

```text
Futebol no Parque começa às 16:00.
```

Pode ser adicionado após MVP inicial.

---

# 57. Deep Links

Compartilhar atividade deve gerar link:

```text
juntai.app/activity/abc123
```

Ao clicar:

```text
app instalado → abre ActivityDetails
app não instalado → site/landing page
```

Usar App Links / Universal Links.

Flutter:

```yaml
app_links:
```

---

# 58. Compartilhar atividade

Texto:

```text
Bora participar de Futebol no Parque?
Hoje às 16:00 no Parque Ibirapuera.

Abrir no Juntaí:
https://juntai.app/activity/abc123
```

Pacote:

```yaml
share_plus:
```

---

# 59. Configurações

Tela:

```text
Conta
Notificações
Localização
Privacidade
Usuários bloqueados
Ajuda
Termos de uso
Política de privacidade
Excluir conta
Sair
```

---

# 60. Privacidade

Controles:

```text
Mostrar cidade
Mostrar atividades no perfil
Permitir convites
Permitir mensagens
Notificações de chat
Notificações de atividades
```

---

# 61. Exclusão de conta

Obrigatório implementar fluxo completo:

```text
Configurações
↓
Excluir minha conta
↓
Confirmar senha/reautenticar
↓
Confirmar exclusão
↓
Cloud Function
```

Excluir:

- perfil
- tokens
- avatar
- favoritos
- informações privadas

Manter/anonimizar apenas o necessário para integridade dos eventos e prevenção de abuso.

---

# 62. Tela Chat — detalhes visuais

## Bolha recebida

```text
branco
texto escuro
sombra muito leve
avatar à esquerda
nome verde
```

## Bolha enviada

```text
verde muito claro
alinhada à direita
check de leitura
```

## Sistema

Exemplo:

```text
Você entrou no grupo
```

Chip cinza claro centralizado.

---

# 63. Presença e leitura

No MVP:

```text
lastSeenAt
seenBy
unreadCount
```

Não implementar sistema de presença complexo logo no início.

---

# 64. Notificações no Chat

Quando receber mensagem:

- app em foreground → badge/local notification opcional
- app em background → FCM
- chat aberto → evitar push redundante

---

# 65. Criador da atividade

Permissões adicionais:

```text
editar atividade
cancelar atividade
aceitar solicitação privada
remover participante
moderar chat
```

Ações sensíveis devem ter confirmação.

---

# 66. Cancelar atividade

Popup:

```text
Cancelar atividade?

Os participantes serão avisados.

[Voltar]
[Cancelar atividade]
```

Depois:

- status = cancelled
- notificar participantes
- bloquear novas entradas

---

# 67. Limite de participantes

Join deve usar transação/Cloud Function.

Evitar corrida:

```text
2 pessoas pegando a última vaga ao mesmo tempo
```

---

# 68. Report e moderação

Collection:

```text
reports/{reportId}
```

Campos:

```json
{
  "reporterId": "...",
  "targetType": "user",
  "targetId": "...",
  "reason": "harassment",
  "details": "...",
  "status": "open",
  "createdAt": "..."
}
```

---

# 69. Painel administrativo futuro

Não é necessário no Flutter inicial, mas o backend deve permitir:

- listar denúncias
- bloquear usuário
- remover atividade
- revisar conteúdo
- suspender conta

Pode ser:

```text
Flutter Web Admin
```

ou painel web separado.

---

# 70. Permissões Android/iOS

## Localização

Android:

```text
ACCESS_FINE_LOCATION
ACCESS_COARSE_LOCATION
```

iOS:

```text
NSLocationWhenInUseUsageDescription
```

## Fotos

Configurar conforme `image_picker`.

## Notificações

iOS requer permissão explícita.

Android moderno também solicita permissão de notificação.

---

# 71. Android

Configurar:

```text
applicationId
minSdk
targetSdk
google-services.json
Maps API key
Firebase App Check
```

Nome:

```text
Juntaí
```

---

# 72. iOS

Configurar:

```text
Bundle ID
GoogleService-Info.plist
Maps API key
Sign in with Apple
Push Notifications
Background Modes
Associated Domains
```

---

# 73. Ambientes

Criar:

```text
dev
staging
prod
```

Exemplo:

```text
com.juntai.app.dev
com.juntai.app.staging
com.juntai.app
```

Firebase separado para produção é recomendado.

---

# 74. Variáveis

Não hardcodar secrets.

Pode usar:

```text
--dart-define
```

Exemplo:

```text
APP_ENV
API_BASE_URL
```

Chaves móveis públicas ainda devem possuir restrições por aplicativo.

---

# 75. Logging

Criar serviço:

```text
AppLogger
```

Níveis:

```text
debug
info
warning
error
```

Em produção:

- não imprimir tokens
- não imprimir senha
- não imprimir conteúdo de chat

---

# 76. Testes

## Unit tests

Testar:

```text
validators
repositories
providers
geo utils
activity join logic
```

## Widget tests

```text
ActivityCard
ChatBubble
LoginForm
CreateActivityForm
BottomNav
```

## Integration

Fluxos:

```text
cadastro
login
criar atividade
participar
enviar mensagem
abrir mapa
editar perfil
```

---

# 77. Firebase Emulator Suite

Usar durante desenvolvimento:

- Auth emulator
- Firestore emulator
- Functions emulator
- Storage emulator

Evita usar produção durante testes.

---

# 78. Fluxos funcionais completos

## Cadastro

```text
Onboarding
→ Criar conta
→ Nome
→ E-mail
→ Senha
→ Aceitar termos
→ Firebase Auth
→ Criar users/{uid}
→ Completar perfil
→ Localização
→ Home
```

## Login

```text
Login
→ Firebase Auth
→ buscar perfil
→ Home
```

## Pesquisa

```text
Home
→ campo busca
→ SearchScreen
→ digitar
→ debounce
→ resultados
→ tocar atividade
→ ActivityDetails
```

## Notificação

```text
Sininho
→ NotificationsScreen
→ tocar notificação
→ abrir atividade/chat/perfil
→ marcar como lida
```

## Participar

```text
ActivityDetails
→ Participar
→ backend valida
→ participante adicionado
→ contador atualizado
→ chat liberado
→ notificação criador
```

## Criar

```text
Criar
→ categoria
→ título
→ local
→ data
→ horário
→ participantes
→ privacidade
→ descrição
→ capa opcional
→ publicar
→ activity criada
→ criador adicionado como participante
→ chat criado
→ ActivityDetails
```

## Chat

```text
Chat tab
→ lista de conversas
→ selecionar atividade
→ GroupChat
→ enviar mensagem
→ Firestore
→ realtime
→ push para demais participantes
```

## Perfil

```text
Perfil
→ dados
→ estatísticas
→ próximas atividades
→ favoritos
→ editar
→ configurações
```

---

# 79. Tela por tela — checklist

## Splash

- [ ] logo mark
- [ ] wordmark
- [ ] animação simples opcional
- [ ] verificar sessão

## Onboarding

- [ ] ilustração
- [ ] frase
- [ ] Começar
- [ ] Entrar

## Login

- [ ] e-mail
- [ ] senha
- [ ] mostrar/ocultar senha
- [ ] recuperar senha
- [ ] Google
- [ ] Apple
- [ ] criar conta

## Cadastro

- [ ] nome
- [ ] email
- [ ] senha
- [ ] confirmar senha
- [ ] data nascimento
- [ ] cidade
- [ ] termos
- [ ] privacidade

## Completar perfil

- [ ] foto
- [ ] bio
- [ ] interesses

## Home

- [ ] logo
- [ ] sininho
- [ ] avatar
- [ ] título
- [ ] busca
- [ ] filtro
- [ ] categorias
- [ ] perto de você
- [ ] cards
- [ ] bottom nav

## Pesquisa

- [ ] busca
- [ ] debounce
- [ ] resultados atividades
- [ ] resultados pessoas
- [ ] filtro

## Mapa

- [ ] Google Map
- [ ] marcador
- [ ] filtros
- [ ] card selecionado
- [ ] minha localização

## Criar

- [ ] categorias
- [ ] título
- [ ] local
- [ ] data
- [ ] horário
- [ ] participantes
- [ ] público/privado
- [ ] descrição
- [ ] foto
- [ ] publicar

## Detalhes

- [ ] capa
- [ ] título
- [ ] categoria
- [ ] local
- [ ] data
- [ ] participantes
- [ ] criador
- [ ] descrição
- [ ] participar
- [ ] compartilhar
- [ ] chat
- [ ] quem vai
- [ ] denunciar

## Chat

- [ ] lista conversas
- [ ] chat grupo
- [ ] texto
- [ ] imagem
- [ ] timestamp
- [ ] leitura
- [ ] push
- [ ] denunciar/bloquear

## Perfil

- [ ] avatar
- [ ] nome
- [ ] cidade
- [ ] bio
- [ ] verificado
- [ ] avaliação
- [ ] estatísticas
- [ ] próximas atividades
- [ ] favoritos
- [ ] editar perfil
- [ ] configurações
- [ ] privacidade

## Notificações

- [ ] badge
- [ ] lista
- [ ] marcar como lida
- [ ] deep link

---

# 80. Prioridade de desenvolvimento

## Fase 1 — Fundação

1. criar projeto Flutter
2. tema
3. rotas
4. Firebase
5. componentes base
6. bottom nav

## Fase 2 — Auth

1. splash
2. onboarding
3. login
4. cadastro
5. recuperação
6. completar perfil

## Fase 3 — Home

1. header
2. busca
3. categorias
4. ActivityCard
5. Firestore activities
6. filtros básicos

## Fase 4 — Mapa

1. Google Maps
2. localização
3. markers
4. card selecionado

## Fase 5 — Atividade

1. criar
2. detalhes
3. participar
4. participantes
5. edição/cancelamento

## Fase 6 — Chat

1. lista
2. group chat
3. enviar texto
4. imagem
5. unread
6. push

## Fase 7 — Perfil

1. perfil
2. editar
3. estatísticas
4. favoritos
5. configurações

## Fase 8 — Segurança

1. regras Firestore
2. App Check
3. bloquear
4. denunciar
5. exclusão de conta
6. Crashlytics

---

# 81. Ordem recomendada para o MVP

Não desenvolver tudo ao mesmo tempo.

Primeira versão funcional:

```text
Splash
Onboarding
Login
Cadastro
Home
Pesquisa
Mapa
Criar atividade
Detalhes
Participar
Chat de grupo
Perfil
Notificações
Bloquear
Denunciar
```

Deixar para V2:

```text
áudio no chat
videochamada
chamada de voz
stories
feed social
amizade formal
pagamentos
eventos pagos
ranking complexo
verificação avançada
```

---

# 82. Componentes prioritários para copiar o visual do mockup

Criar primeiro:

```text
AppBottomNav
AppHeader
AppSearchField
CategoryChip
ActivityCard
DistanceBadge
ParticipantAvatarStack
PrimaryButton
SecondaryButton
ProfileStatCard
MessageBubble
MapSelectedActivityCard
```

Se esses componentes estiverem corretos, praticamente todo o aplicativo manterá a mesma identidade visual.

---

# 83. Layout responsivo

Não usar valores completamente fixos baseados em uma única tela.

Usar:

```dart
MediaQuery
LayoutBuilder
SafeArea
Expanded
Flexible
AspectRatio
```

Testar em:

```text
360x800
390x844
412x915
tablet
```

---

# 84. Acessibilidade

Obrigatório:

- contraste
- fonte escalável
- área mínima de toque ~44–48 px
- semantics em botões importantes
- texto descritivo em imagens
- não depender somente de cor

---

# 85. UI — regra geral

O Juntaí deve parecer:

```text
leve
branco
limpo
moderno
social
seguro
amigável
```

Evitar:

```text
gradientes exagerados
bordas pesadas
muitas cores simultâneas
ícones de estilos diferentes
cards apertados
texto pequeno
```

---

# 86. Código de tema sugerido

```dart
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Inter',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
    ),
  );
}
```

---

# 87. Exemplo de botão principal

```dart
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
```

---

# 88. Exemplo de `ActivityCard`

Composição:

```text
Card
├─ image
├─ category badge
├─ title
├─ distance badge
├─ location row
├─ date row
├─ participants row
├─ avatars
└─ button
```

O widget não deve realizar chamadas de rede diretamente.

Recebe dados do provider/repository.

---

# 89. Regras de arquitetura

## UI

Somente:

```text
renderização
eventos do usuário
```

## Provider / Controller

Responsável por:

```text
estado
loading
erro
coordenação
```

## Repository

Responsável por:

```text
Firestore
Firebase Auth
Storage
Functions
```

## Service

Responsável por:

```text
localização
notificações
analytics
permissions
```

---

# 90. Padrão de resposta de estado

Recomendado Riverpod AsyncValue:

```text
loading
data
error
```

Não manter dezenas de booleanos:

```text
isLoading
isError
hasData
```

quando `AsyncValue` resolve.

---

# 91. Tratamento de erros

Mensagens amigáveis.

Exemplos:

Auth:

```text
E-mail ou senha incorretos.
```

Mapa:

```text
Não foi possível obter sua localização.
```

Atividade:

```text
Essa atividade já está lotada.
```

Chat:

```text
Não foi possível enviar a mensagem.
```

---

# 92. Snackbar

Usar para confirmações rápidas:

```text
Atividade publicada.
Você entrou na atividade.
Mensagem enviada.
Perfil atualizado.
```

---

# 93. Loading button

Durante operação:

```text
[ spinner  Publicando... ]
```

Desabilitar duplo clique.

---

# 94. Dados iniciais de categorias

Criar enum:

```dart
enum ActivityCategory {
  football,
  running,
  cycling,
  games,
  cinema,
  coffee,
  restaurant,
  gym,
  music,
  beach,
  hiking,
  study,
  pets,
  boardGames,
}
```

Mapear label + icon + cor em extensão.

---

# 95. Código de categoria

```dart
extension ActivityCategoryX on ActivityCategory {
  String get label => switch (this) {
    ActivityCategory.football => 'Futebol',
    ActivityCategory.running => 'Corrida',
    ActivityCategory.cycling => 'Pedalar',
    ActivityCategory.games => 'Games',
    ActivityCategory.cinema => 'Cinema',
    ActivityCategory.coffee => 'Café',
    _ => name,
  };

  IconData get icon => switch (this) {
    ActivityCategory.football => Icons.sports_soccer_rounded,
    ActivityCategory.running => Icons.directions_run_rounded,
    ActivityCategory.cycling => Icons.directions_bike_rounded,
    ActivityCategory.games => Icons.sports_esports_rounded,
    ActivityCategory.cinema => Icons.movie_rounded,
    ActivityCategory.coffee => Icons.local_cafe_rounded,
    _ => Icons.interests_rounded,
  };
}
```

---

# 96. Pesquisa por localização

Para atividades próximas usar geohash.

Opções:

- geoflutterfire_plus
- geohash próprio + consultas por intervalos

Guardar:

```text
lat
lng
geohash
```

No MVP, filtrar por cidade + raio aproximado.

---

# 97. Política de localização pública

Não mostrar:

```text
localização em tempo real da pessoa
```

Mostrar:

```text
local da atividade
cidade do perfil
```

Isso é importante para segurança.

---

# 98. Observabilidade

Criar dashboards básicos:

```text
cadastros
usuários ativos
atividades criadas
taxa de participação
mensagens enviadas
notificações abertas
denúncias
```

---

# 99. README técnico do projeto

O repositório deve incluir:

```text
README.md
docs/
  architecture.md
  firestore-schema.md
  firebase-setup.md
  maps-setup.md
  release.md
```

---

# 100. Resultado esperado

A versão inicial do **Juntaí** deve possuir:

### Identidade

- logo
- app icon
- splash

### Conta

- cadastro
- login
- recuperação de senha
- login Google
- login Apple

### Descoberta

- Home
- busca
- categorias
- filtros
- localização
- atividades próximas

### Mapa

- marcadores
- card selecionado
- minha localização

### Atividades

- criar
- editar
- excluir/cancelar
- detalhes
- participar
- sair
- lista de participantes

### Comunicação

- lista de chats
- chat em tempo real
- notificações push
- sininho
- badges

### Perfil

- perfil próprio
- editar
- perfil público
- estatísticas
- favoritos
- configurações
- privacidade

### Segurança

- bloquear
- denunciar
- regras Firestore
- App Check
- exclusão de conta

---

# 101. Definição final da stack

```text
Frontend:
Flutter

Linguagem:
Dart

Arquitetura:
Feature-first
Repository pattern
Riverpod

Rotas:
go_router

Backend:
Firebase

Autenticação:
Firebase Auth

Banco realtime:
Cloud Firestore

Arquivos:
Firebase Storage

Push:
Firebase Cloud Messaging

Server logic:
Cloud Functions

Mapa:
Google Maps

Busca de locais:
Google Places

Geolocalização:
Geolocator

Analytics:
Firebase Analytics

Erros:
Crashlytics

Segurança:
Firebase Security Rules
Firebase App Check

Imagens:
image_picker
flutter_image_compress
cached_network_image

UI:
Material 3
Material Icons Rounded
Google Fonts
```

---

# 102. Primeira sequência de implementação

A ordem mais segura para iniciar o código é:

```text
01. Criar projeto Flutter
02. Configurar Firebase
03. Configurar Google Maps
04. Criar app theme
05. Criar router
06. Criar componentes globais
07. Criar bottom navigation
08. Splash
09. Onboarding
10. Login
11. Cadastro
12. Perfil inicial
13. Home mockada
14. Firestore Activity
15. ActivityCard real
16. Pesquisa
17. Mapa
18. Criar atividade
19. Detalhes
20. Join/Leave
21. Chat
22. Push/sininho
23. Perfil
24. Segurança
25. Testes
26. Release
```

---

# 103. Requisito visual principal

O código deve reproduzir os mockups aprovados mantendo:

- fundo branco
- verde Juntaí
- cards grandes e arredondados
- sombras leves
- espaços generosos
- ícones Material Rounded
- imagens grandes nos cards
- avatares circulares
- bottom navigation fixa
- botão central Criar
- headers limpos
- textos escuros e fortes
- labels secundárias cinza
- badges em cores suaves

Não deve ser uma interpretação genérica.

A implementação deve seguir os mockups como referência visual principal.

---

# 104. Entrega técnica ideal

Ao terminar o projeto, a estrutura mínima de entrega deve ser:

```text
juntai/
├── android/
├── ios/
├── assets/
├── lib/
├── test/
├── integration_test/
├── functions/
├── docs/
├── firebase.json
├── firestore.rules
├── firestore.indexes.json
├── storage.rules
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

# 105. Checklist para considerar o MVP pronto

- [ ] App abre sem erro
- [ ] Splash correta
- [ ] Cadastro funciona
- [ ] Login funciona
- [ ] Logout funciona
- [ ] Home carrega atividades
- [ ] Busca funciona
- [ ] Filtros funcionam
- [ ] Mapa funciona
- [ ] Localização funciona
- [ ] Criar atividade funciona
- [ ] Detalhes funcionam
- [ ] Participar funciona
- [ ] Limite de vagas é respeitado
- [ ] Chat realtime funciona
- [ ] Push funciona
- [ ] Sininho atualiza badge
- [ ] Perfil funciona
- [ ] Avatar upload funciona
- [ ] Editar perfil funciona
- [ ] Bloquear funciona
- [ ] Denunciar funciona
- [ ] Regras Firestore testadas
- [ ] App Check ativo
- [ ] Crashlytics ativo
- [ ] Analytics básico ativo
- [ ] Android release funcionando
- [ ] iOS release funcionando

---

## Conclusão

Este documento define a base completa do **Juntaí** para reproduzir o estilo dos mockups aprovados e transformar o design em um aplicativo Flutter real, organizado e escalável.

O ponto central da implementação deve ser:

```text
UI muito próxima dos mockups
+
arquitetura organizada
+
Firebase seguro
+
mapa e localização
+
atividades em tempo real
+
chat
+
notificações
+
perfil
+
moderação
```

Com essa estrutura, o app já nasce organizado para evoluir sem precisar ser refeito do zero.
