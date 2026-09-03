const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const app = express();
app.use(cors());
app.use(express.json({ limit: '8mb' }));

const projectId = process.env.FIREBASE_PROJECT_ID;
const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');

const imageKitPublicKey = process.env.IMAGEKIT_PUBLIC_KEY || '';
const imageKitPrivateKey = process.env.IMAGEKIT_PRIVATE_KEY || '';
const imageKitUrlEndpoint = process.env.IMAGEKIT_URL_ENDPOINT || '';

if (!projectId || !clientEmail || !privateKey) {
  console.error('FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL e FIREBASE_PRIVATE_KEY são obrigatórios.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert({
    projectId,
    clientEmail,
    privateKey,
  }),
  projectId,
});

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const SOCIAL_NOTIFICATION_TYPES = new Set([
  'new_message',
  'private_message',
  'new_participant',
  'join_request',
]);

class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function requiredString(value, field, maxLength = 300) {
  const text = String(value ?? '').trim();
  if (!text) {
    throw new ApiError(400, 'invalid-argument', `${field} é obrigatório.`);
  }
  if (text.length > maxLength) {
    throw new ApiError(400, 'invalid-argument', `${field} ultrapassa o limite permitido.`);
  }
  return text;
}

function optionalString(value, maxLength = 1000) {
  return String(value ?? '').trim().slice(0, maxLength);
}

function parseDate(value, field) {
  const date = new Date(String(value ?? ''));
  if (Number.isNaN(date.getTime())) {
    throw new ApiError(400, 'invalid-argument', `${field} inválido.`);
  }
  return date;
}

async function authenticate(req, _res, next) {
  try {
    const authHeader = String(req.headers.authorization || '');
    if (!authHeader.startsWith('Bearer ')) {
      throw new ApiError(401, 'unauthenticated', 'Faça login para continuar.');
    }

    const idToken = authHeader.substring(7).trim();
    if (!idToken) {
      throw new ApiError(401, 'unauthenticated', 'Faça login para continuar.');
    }

    req.user = await admin.auth().verifyIdToken(idToken, true);
    next();
  } catch (error) {
    if (error instanceof ApiError) return next(error);
    return next(new ApiError(401, 'unauthenticated', 'Sessão inválida ou expirada.'));
  }
}

async function userData(uid) {
  const snapshot = await db.collection('users').doc(uid).get();
  if (!snapshot.exists) {
    throw new ApiError(412, 'failed-precondition', 'Complete seu perfil primeiro.');
  }
  return snapshot.data() || {};
}

async function blockExists(ownerUid, blockedUid) {
  if (!ownerUid || !blockedUid || ownerUid === blockedUid) return false;
  const snapshot = await db
    .collection('users')
    .doc(ownerUid)
    .collection('blocks')
    .doc(blockedUid)
    .get();
  return snapshot.exists;
}

async function blockedEither(uidA, uidB) {
  const [aBlockedB, bBlockedA] = await Promise.all([
    blockExists(uidA, uidB),
    blockExists(uidB, uidA),
  ]);
  return aBlockedB || bBlockedA;
}

async function isBlockedBy(targetUid, actorId) {
  if (!actorId || targetUid === actorId) return false;
  const snapshot = await db
    .collection('users')
    .doc(targetUid)
    .collection('blocks')
    .doc(actorId)
    .get();
  return snapshot.exists;
}

function shouldPush(type, preferences) {
  if (type === 'private_message' ||
      type === 'new_direct_message') {
    return preferences.directMessageNotifications !== false &&
      preferences.chatNotifications !== false;
  }

  if (type === 'new_message') {
    return preferences.groupMessageNotifications !== false &&
      preferences.chatNotifications !== false;
  }

  if (type === 'new_follower') {
    return preferences.followerNotifications !== false;
  }

  if (type === 'activity_invite' ||
      type === 'join_request') {
    return preferences.inviteNotifications !== false;
  }

  if (type === 'business_new_post' ||
      type === 'business_open_slots' ||
      type === 'group_discount_unlocked') {
    return preferences.businessNotifications !== false;
  }

  if (type === 'nearby_open_slots') {
    return preferences.nearbyOpenSlotsNotifications !== false;
  }

  if (type === 'event_reminder') {
    return preferences.eventReminderNotifications !== false;
  }

  return preferences.activityNotifications !== false;
}

async function notify(uid, data) {
  if (!uid) return;

  const type = String(data.type || 'generic');
  const actorId = data.actorId ? String(data.actorId) : '';

  if (
    actorId &&
    SOCIAL_NOTIFICATION_TYPES.has(type) &&
    (await isBlockedBy(uid, actorId))
  ) {
    return;
  }

  const userRef = db.collection('users').doc(uid);
  const profile = await userRef.get();
  if (!profile.exists) return;

  const preferences = profile.data() || {};
  if (preferences.accountStatus === 'disabled') return;

  const notificationData = {
    type,
    title: String(data.title || 'Juntaí'),
    body: String(data.body || ''),
    activityId: data.activityId ? String(data.activityId) : null,
    actorId: actorId || null,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  };

  await userRef.collection('notifications').add(notificationData);

  if (!shouldPush(type, preferences)) return;

  const devices = await userRef.collection('devices').get();
  const deviceRows = devices.docs
    .map((doc) => ({ doc, token: String(doc.data().token || '') }))
    .filter((row) => row.token);

  if (!deviceRows.length) return;

  const pushData = {
    type,
    title: notificationData.title,
    body: notificationData.body,
    activityId: notificationData.activityId || '',
    actorId: notificationData.actorId || '',
    route: notificationData.route || '',
    route: notificationData.route || '',
  };

  const invalidCodes = new Set([
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ]);

  for (let start = 0; start < deviceRows.length; start += 500) {
    const batch = deviceRows.slice(start, start + 500);
    const response = await admin.messaging().sendEachForMulticast({
      tokens: batch.map((row) => row.token),
      notification: {
        title: notificationData.title,
        body: notificationData.body,
      },
      data: pushData,
      android: {
        priority: 'high',
        notification: {
          channelId: 'juntai_high_importance',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default' },
        },
      },
    });

    const deletes = [];
    response.responses.forEach((item, index) => {
      if (!item.success && invalidCodes.has(item.error?.code)) {
        deletes.push(batch[index].doc.ref.delete());
      }
    });
    if (deletes.length) await Promise.allSettled(deletes);
  }
}

app.get('/', (_req, res) => {
  res.json({ ok: true, service: 'juntai-api' });
});

app.get('/health', (_req, res) => {
  res.json({ ok: true });
});

app.get('/.well-known/assetlinks.json', (_req, res) => {
  res.type('application/json').send([{
    relation: ['delegate_permission/common.handle_all_urls'],
    target: {
      namespace: 'android_app',
      package_name: 'app.juntai.juntai',
      sha256_cert_fingerprints: [process.env.ANDROID_SHA256_CERT_FINGERPRINT || 'F2:7F:06:12:E3:6A:3E:BA:9B:F9:B7:27:50:88:69:54:1B:34:4C:F4:52:82:55:F9:0E:4B:B1:FC:D8:79:40:36'],
    },
  }]);
});

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[char]);
}

app.get('/activity/:id', async (req, res, next) => {
  try {
    const activity = await db.collection('activities').doc(requiredString(req.params.id, 'id', 200)).get();
    if (!activity.exists) throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
    const data = activity.data() || {};
    const title = escapeHtml(data.title || 'Atividade no Juntaí');
    const address = escapeHtml(data.address || '');
    const appUrl = `juntai:///activity/${encodeURIComponent(activity.id)}`;
    res.type('html').send(`<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} • Juntaí</title><style>body{font-family:system-ui;background:#f7f5ff;margin:0;display:grid;place-items:center;min-height:100vh;color:#211a35}.card{background:white;padding:32px;border-radius:24px;max-width:520px;box-shadow:0 16px 50px #3210a522;text-align:center}a{display:inline-block;background:#6425e8;color:white;padding:14px 24px;border-radius:14px;text-decoration:none;font-weight:700}</style></head><body><main class="card"><h1>Juntaí</h1><h2>${title}</h2><p>${address}</p><a href="${appUrl}">Abrir no Juntaí</a></main></body></html>`);
  } catch (error) { next(error); }
});

app.post('/reserve-username', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const username = requiredString(req.body?.username, 'username', 20).toLowerCase();
    if (username.length < 3 || !/^[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$/.test(username)) {
      throw new ApiError(400, 'invalid-username', 'Use letras, números, ponto ou _, começando por uma letra.');
    }
    const ref = db.collection('usernames').doc(username);
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(ref);
      if (current.exists && String(current.data()?.uid) !== uid) throw new ApiError(409, 'username-taken', 'Este @usuário já está em uso.');
      transaction.set(ref, { uid, createdAt: current.data()?.createdAt || FieldValue.serverTimestamp() });
    });
    res.json({ ok: true, username });
  } catch (error) { next(error); }
});


app.post('/upload-image', authenticate, async (req, res, next) => {
  try {
    if (!imageKitPrivateKey) {
      throw new ApiError(
        503,
        'image-service-not-configured',
        'O serviço de imagens ainda não está configurado no servidor.',
      );
    }

    const uid = req.user.uid;
    const purpose = requiredString(req.body?.purpose, 'purpose', 30);
    const encoded = requiredString(req.body?.base64, 'base64', 7_500_000);
    const requestedName = optionalString(req.body?.fileName, 160);
    const mimeType = optionalString(req.body?.mimeType, 80).toLowerCase();

    if (!['profile', 'activity', 'chat', 'discovery', 'business'].includes(purpose)) {
      throw new ApiError(400, 'invalid-argument', 'Destino de imagem inválido.');
    }

    const allowedMimeTypes = new Set([
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    ]);

    if (!allowedMimeTypes.has(mimeType)) {
      throw new ApiError(
        400,
        'invalid-argument',
        'Formato de imagem não suportado. Use JPG, PNG, WEBP ou HEIC.',
      );
    }

    let bytes;
    try {
      bytes = Buffer.from(encoded, 'base64');
    } catch (_) {
      throw new ApiError(400, 'invalid-argument', 'Imagem inválida.');
    }

    if (!bytes.length) {
      throw new ApiError(400, 'invalid-argument', 'Imagem vazia.');
    }

    if (bytes.length > 4 * 1024 * 1024) {
      throw new ApiError(
        413,
        'payload-too-large',
        'A imagem ficou grande demais. Escolha uma foto menor.',
      );
    }

    const extensionByMime = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'image/heic': 'heic',
      'image/heif': 'heif',
    };

    const extension = extensionByMime[mimeType] || 'jpg';
    const safeRequestedName = requestedName
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .replace(/\.+/g, '.')
      .slice(0, 120);

    const generatedName =
      purpose === 'profile'
        ? `profile_${uid}.${extension}`
        : `${purpose}_${Date.now()}_${Math.random().toString(36).slice(2, 10)}.${extension}`;

    const fileName = safeRequestedName || generatedName;
    const folder = `/juntai/${purpose}/${uid}`;

    const form = new FormData();
    form.append('file', new Blob([bytes], { type: mimeType }), fileName);
    form.append('fileName', fileName);
    form.append('folder', folder);
    form.append('useUniqueFileName', purpose === 'profile' ? 'false' : 'true');

    const auth = Buffer.from(`${imageKitPrivateKey}:`).toString('base64');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45000);

    let uploadResponse;
    try {
      uploadResponse = await fetch(
        'https://upload.imagekit.io/api/v1/files/upload',
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${auth}`,
            Accept: 'application/json',
          },
          body: form,
          signal: controller.signal,
        },
      );
    } finally {
      clearTimeout(timeout);
    }

    const payload = await uploadResponse.json().catch(() => ({}));

    if (!uploadResponse.ok) {
      console.error('ImageKit upload error:', uploadResponse.status, payload);
      throw new ApiError(
        502,
        'image-upload-failed',
        String(payload?.message || 'Não foi possível enviar a imagem.'),
      );
    }

    const url = String(payload?.url || '').trim();
    const fileId = String(payload?.fileId || '').trim();

    if (!url) {
      throw new ApiError(
        502,
        'image-upload-failed',
        'O servidor de imagens não retornou a URL da foto.',
      );
    }

    res.json({
      ok: true,
      url,
      fileId,
      urlEndpoint: imageKitUrlEndpoint,
      publicKeyConfigured: Boolean(imageKitPublicKey),
    });
  } catch (error) {
    if (error?.name === 'AbortError') {
      return next(
        new ApiError(
          504,
          'image-upload-timeout',
          'O envio da imagem demorou demais. Tente novamente.',
        ),
      );
    }

    next(error);
  }
});

app.post('/create-business', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const ref = db.collection('business_profiles').doc(uid);
    if ((await ref.get()).exists) throw new ApiError(409, 'already-exists', 'Você já possui um perfil comercial.');
    const latitude = Number(req.body?.latitude);
    const longitude = Number(req.body?.longitude);
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) throw new ApiError(400, 'invalid-location', 'Localização inválida.');
    await ref.set({
      ownerId: uid,
      name: requiredString(req.body?.name, 'name', 80),
      category: requiredString(req.body?.category, 'category', 50),
      city: requiredString(req.body?.city, 'city', 80),
      address: requiredString(req.body?.address, 'address', 250),
      latitude, longitude,
      websiteUrl: optionalHttpUrl(req.body?.websiteUrl, 'websiteUrl', 500),
      description: optionalString(req.body?.description, 800),
      verified: false, reviewStatus: 'pending', plan: 'free',
      monthlyPostLimit: 1, activePostLimit: 1, postsUsedThisMonth: 0, usageMonth: usageMonthKey(),
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    res.json({ ok: true, businessId: uid });
  } catch (error) { next(error); }
});

app.post('/create-business-post-legacy-disabled', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const businessRef = db.collection('business_profiles').doc(uid);
    const businessSnapshot = await businessRef.get();
    if (!businessSnapshot.exists) throw new ApiError(412, 'business-required', 'Crie seu perfil comercial primeiro.');
    const business = businessSnapshot.data() || {};
    const active = await db.collection('discoveries').where('businessId', '==', uid).where('status', '==', 'published').get();
    const activeLimit = Number(business.activePostLimit || 1);
    if (active.size >= activeLimit) throw new ApiError(409, 'plan-limit', 'Seu plano atingiu o limite de publicações ativas.');
    const type = optionalString(req.body?.type, 30) || 'experience';
    if (!['experience', 'event', 'open_slots', 'promotion', 'schedule'].includes(type)) throw new ApiError(400, 'invalid-type', 'Tipo de publicação inválido.');
    const startsAt = req.body?.eventStartsAt ? parseDate(req.body.eventStartsAt, 'eventStartsAt') : null;
    const ref = db.collection('discoveries').doc();
    await db.runTransaction(async (transaction) => {
      transaction.set(ref, {
        businessId: uid, businessName: String(business.name), businessCategory: String(business.category), businessVerified: business.verified === true,
        type, title: requiredString(req.body?.title, 'title', 120), description: requiredString(req.body?.description, 'description', 1200),
        coverUrl: requiredString(req.body?.coverUrl, 'coverUrl', 500), address: String(business.address), latitude: Number(business.latitude), longitude: Number(business.longitude), websiteUrl: optionalString(business.websiteUrl, 500),
        groupBenefit: optionalString(req.body?.groupBenefit, 300), ctaLabel: requiredString(req.body?.ctaLabel || 'Criar atividade aqui', 'ctaLabel', 40),
        officialEvent: req.body?.officialEvent === true, eventStartsAt: startsAt ? Timestamp.fromDate(startsAt) : null,
        sponsored: false, status: 'published', views: 0, opens: 0, activitiesCreated: 0, participantsGenerated: 0,
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(businessRef, { postsUsedThisMonth: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() });
    });
    res.json({ ok: true, postId: ref.id });
  } catch (error) { next(error); }
});

app.post('/business-post-view', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const postId = requiredString(req.body?.postId, 'postId', 200);
    const event = requiredString(req.body?.event, 'event', 20);
    if (!['impression', 'open'].includes(event)) throw new ApiError(400, 'invalid-event', 'Métrica inválida.');
    const postRef = db.collection('discoveries').doc(postId);
    const markerRef = postRef.collection('metric_users').doc(`${uid}_${event}`);
    let counted = false;
    await db.runTransaction(async (transaction) => {
      const [post, marker] = await Promise.all([transaction.get(postRef), transaction.get(markerRef)]);
      if (!post.exists) throw new ApiError(404, 'not-found', 'Publicação não encontrada.');
      if (marker.exists) return;
      transaction.set(markerRef, { userId: uid, event, createdAt: FieldValue.serverTimestamp() });
      transaction.update(postRef, { [event === 'open' ? 'opens' : 'views']: FieldValue.increment(1) });
      counted = true;
    });
    res.json({ ok: true, counted });
  } catch (error) { next(error); }
});



app.post('/address-search', authenticate, async (req, res, next) => {
  try {
    const query = requiredString(req.body?.query, 'query', 160);

    if (query.length < 3) {
      return res.json({ ok: true, suggestions: [] });
    }

    const photonUrl = new URL('https://photon.komoot.io/api/');
    photonUrl.searchParams.set('q', query.toLowerCase().includes('brasil') ? query : `${query}, Brasil`);
    photonUrl.searchParams.set('limit', '6');
    photonUrl.searchParams.set('lang', 'pt');

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 7000);

    let response;
    try {
      response = await fetch(photonUrl, {
        headers: {
          'Accept': 'application/json',
          'Accept-Language': 'pt-BR,pt;q=0.9',
          'User-Agent': 'Juntai/0.1 address-search',
        },
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }

    if (!response.ok) {
      throw new ApiError(502, 'geocoder-unavailable', 'A busca de endereços está temporariamente indisponível.');
    }

    const payload = await response.json();
    const features = Array.isArray(payload?.features) ? payload.features : [];

    const suggestions = features
      .map((feature) => {
        const properties = feature?.properties || {};
        const coordinates = feature?.geometry?.coordinates;

        if (!Array.isArray(coordinates) || coordinates.length < 2) {
          return null;
        }

        const longitude = Number(coordinates[0]);
        const latitude = Number(coordinates[1]);

        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
          return null;
        }

        const pieces = [];
        const add = (value) => {
          const text = String(value || '').trim();
          if (text && !pieces.some((item) => item.toLowerCase() === text.toLowerCase())) {
            pieces.push(text);
          }
        };

        const street = String(properties.street || '').trim();
        const houseNumber = String(properties.housenumber || '').trim();

        if (street) {
          add(houseNumber ? `${street}, ${houseNumber}` : street);
        } else {
          add(properties.name);
        }

        add(properties.district);
        add(properties.city);
        add(properties.state);
        add(properties.postcode);
        add(properties.country);

        if (!pieces.length) {
          add(properties.name);
        }

        return {
          label: pieces.join(' - '),
          latitude,
          longitude,
        };
      })
      .filter(Boolean)
      .filter((item, index, array) =>
        array.findIndex((candidate) => candidate.label === item.label) === index,
      );

    return res.json({ ok: true, suggestions });
  } catch (error) {
    if (error?.name === 'AbortError') {
      return next(new ApiError(504, 'geocoder-timeout', 'A busca de endereços demorou para responder.'));
    }
    next(error);
  }
});

app.post('/join-activity', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);

    const activityRef = db.collection('activities').doc(activityId);
    const participantRef = activityRef.collection('participants').doc(uid);
    const profileRef = db.collection('users').doc(uid);

    const initialActivitySnapshot = await activityRef.get();
    if (!initialActivitySnapshot.exists) {
      throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
    }

    const initialCreatorId = String(initialActivitySnapshot.data()?.creatorId || '');
    if (await blockedEither(uid, initialCreatorId)) {
      throw new ApiError(
        403,
        'permission-denied',
        'A participação não está disponível entre usuários bloqueados.',
      );
    }

    let creatorId = '';
    let title = 'Atividade';
    let joined = false;

    await db.runTransaction(async (transaction) => {
      const [activitySnapshot, participantSnapshot, profileSnapshot] =
        await Promise.all([
          transaction.get(activityRef),
          transaction.get(participantRef),
          transaction.get(profileRef),
        ]);

      if (!activitySnapshot.exists) {
        throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
      }
      if (!profileSnapshot.exists) {
        throw new ApiError(412, 'failed-precondition', 'Complete seu perfil antes de participar.');
      }

      const activity = activitySnapshot.data();
      const profile = profileSnapshot.data();
      creatorId = String(activity.creatorId || '');
      title = String(activity.title || 'Atividade');

      if (activity.status !== 'active') {
        throw new ApiError(412, 'failed-precondition', 'Atividade indisponível.');
      }
      if (activity.isPrivate === true) {
        throw new ApiError(412, 'failed-precondition', 'Atividade privada requer solicitação.');
      }
      if (creatorId === uid) {
        throw new ApiError(412, 'failed-precondition', 'Você é o organizador desta atividade.');
      }
      if (participantSnapshot.exists) return;

      const participantCount = Number(activity.participantCount || 0);
      const maxParticipants = Number(activity.maxParticipants || 0);
      if (maxParticipants <= 0 || participantCount >= maxParticipants) {
        throw new ApiError(409, 'resource-exhausted', 'Atividade lotada.');
      }

      const name = String(profile.name || '').trim();
      if (!name) {
        throw new ApiError(412, 'failed-precondition', 'Complete seu perfil antes de participar.');
      }

      transaction.set(participantRef, {
        userId: uid,
        name,
        role: 'participant',
        joinedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(activityRef, {
        participantCount: FieldValue.increment(1),
        participantNames: FieldValue.arrayUnion(name),
        updatedAt: FieldValue.serverTimestamp(),
      });

      joined = true;
    });

    if (joined && creatorId && creatorId !== uid) {
      const profile = await userData(uid);
      await notify(creatorId, {
        type: 'new_participant',
        title: 'Novo participante',
        body: `${String(profile.name || 'Alguém')} entrou em ${title}`,
        activityId,
        actorId: uid,
      });
    }

    res.json({ ok: true, joined });
  } catch (error) {
    next(error);
  }
});

app.post('/leave-activity', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);

    const activityRef = db.collection('activities').doc(activityId);
    const participantRef = activityRef.collection('participants').doc(uid);
    let left = false;

    await db.runTransaction(async (transaction) => {
      const [activitySnapshot, participantSnapshot] = await Promise.all([
        transaction.get(activityRef),
        transaction.get(participantRef),
      ]);

      if (!activitySnapshot.exists) {
        throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
      }

      const activity = activitySnapshot.data();
      if (String(activity.creatorId || '') === uid) {
        throw new ApiError(412, 'failed-precondition', 'O organizador não pode sair da própria atividade.');
      }
      if (!participantSnapshot.exists) return;

      const participant = participantSnapshot.data() || {};
      const participantName = String(participant.name || '').trim();
      const currentCount = Math.max(Number(activity.participantCount || 1), 1);

      transaction.delete(participantRef);
      transaction.update(activityRef, {
        participantCount: Math.max(currentCount - 1, 1),
        ...(participantName
          ? { participantNames: FieldValue.arrayRemove(participantName) }
          : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      left = true;
    });

    res.json({ ok: true, left });
  } catch (error) {
    next(error);
  }
});

app.post('/request-join-activity', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);

    const activityRef = db.collection('activities').doc(activityId);
    const requestRef = activityRef.collection('join_requests').doc(uid);
    const participantRef = activityRef.collection('participants').doc(uid);
    const profileRef = db.collection('users').doc(uid);

    const initialActivitySnapshot = await activityRef.get();
    if (!initialActivitySnapshot.exists) {
      throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
    }

    const initialCreatorId = String(initialActivitySnapshot.data()?.creatorId || '');
    if (await blockedEither(uid, initialCreatorId)) {
      throw new ApiError(
        403,
        'permission-denied',
        'A solicitação não está disponível entre usuários bloqueados.',
      );
    }

    let creatorId = '';
    let title = 'Atividade';
    let requesterName = 'Usuário';
    let created = false;

    await db.runTransaction(async (transaction) => {
      const [activitySnapshot, requestSnapshot, participantSnapshot, profileSnapshot] =
        await Promise.all([
          transaction.get(activityRef),
          transaction.get(requestRef),
          transaction.get(participantRef),
          transaction.get(profileRef),
        ]);

      if (!activitySnapshot.exists) {
        throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
      }
      if (!profileSnapshot.exists) {
        throw new ApiError(412, 'failed-precondition', 'Complete seu perfil antes de solicitar participação.');
      }

      const activity = activitySnapshot.data();
      const profile = profileSnapshot.data();
      creatorId = String(activity.creatorId || '');
      title = String(activity.title || 'Atividade');
      requesterName = String(profile.name || 'Usuário').trim() || 'Usuário';

      if (activity.status !== 'active') {
        throw new ApiError(412, 'failed-precondition', 'Atividade indisponível.');
      }
      if (activity.isPrivate !== true) {
        throw new ApiError(412, 'failed-precondition', 'Atividade não é privada.');
      }
      if (creatorId === uid) {
        throw new ApiError(412, 'failed-precondition', 'Você é o organizador desta atividade.');
      }
      if (participantSnapshot.exists) {
        throw new ApiError(409, 'already-exists', 'Você já participa desta atividade.');
      }

      const participantCount = Number(activity.participantCount || 0);
      const maxParticipants = Number(activity.maxParticipants || 0);
      if (maxParticipants <= 0 || participantCount >= maxParticipants) {
        throw new ApiError(409, 'resource-exhausted', 'Atividade lotada.');
      }

      if (requestSnapshot.exists && requestSnapshot.data()?.status === 'pending') {
        throw new ApiError(409, 'already-exists', 'Sua solicitação já foi enviada.');
      }

      transaction.set(
        requestRef,
        {
          userId: uid,
          name: requesterName,
          photoUrl: profile.photoUrl || null,
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
          respondedAt: null,
        },
        { merge: true },
      );
      created = true;
    });

    if (created) {
      await notify(creatorId, {
        type: 'join_request',
        title: `${requesterName} quer participar`,
        body: title,
        activityId,
        actorId: uid,
      });
    }

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post('/respond-join-request', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);
    const userId = requiredString(req.body?.userId, 'userId', 200);
    const accept = req.body?.accept === true;

    const activityRef = db.collection('activities').doc(activityId);
    const requestRef = activityRef.collection('join_requests').doc(userId);
    const participantRef = activityRef.collection('participants').doc(userId);
    const profileRef = db.collection('users').doc(userId);

    if (accept && (await blockedEither(uid, userId))) {
      throw new ApiError(
        403,
        'permission-denied',
        'Não é possível aceitar uma solicitação entre usuários bloqueados.',
      );
    }

    let title = 'Atividade';
    let requesterName = 'Participante';

    await db.runTransaction(async (transaction) => {
      const [activitySnapshot, requestSnapshot, participantSnapshot, profileSnapshot] =
        await Promise.all([
          transaction.get(activityRef),
          transaction.get(requestRef),
          transaction.get(participantRef),
          transaction.get(profileRef),
        ]);

      if (!activitySnapshot.exists) {
        throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
      }

      const activity = activitySnapshot.data();
      title = String(activity.title || 'Atividade');
      if (String(activity.creatorId || '') !== uid) {
        throw new ApiError(403, 'permission-denied', 'Somente o organizador pode responder.');
      }
      if (!requestSnapshot.exists) {
        throw new ApiError(404, 'not-found', 'Solicitação não encontrada.');
      }

      const joinRequest = requestSnapshot.data() || {};
      if (joinRequest.status !== 'pending') {
        throw new ApiError(412, 'failed-precondition', 'Esta solicitação já foi respondida.');
      }

      requesterName = String(
        joinRequest.name || profileSnapshot.data()?.name || 'Participante',
      ).trim() || 'Participante';

      if (accept && !participantSnapshot.exists) {
        if (activity.status !== 'active') {
          throw new ApiError(412, 'failed-precondition', 'Atividade indisponível.');
        }

        const participantCount = Number(activity.participantCount || 0);
        const maxParticipants = Number(activity.maxParticipants || 0);
        if (maxParticipants <= 0 || participantCount >= maxParticipants) {
          throw new ApiError(409, 'resource-exhausted', 'Atividade lotada.');
        }

        transaction.set(participantRef, {
          userId,
          name: requesterName,
          role: 'participant',
          joinedAt: FieldValue.serverTimestamp(),
        });

        transaction.update(activityRef, {
          participantCount: FieldValue.increment(1),
          participantNames: FieldValue.arrayUnion(requesterName),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.update(requestRef, {
        status: accept ? 'accepted' : 'rejected',
        respondedAt: FieldValue.serverTimestamp(),
      });
    });

    await notify(userId, {
      type: accept ? 'join_approved' : 'join_rejected',
      title: accept ? 'Participação aprovada' : 'Solicitação recusada',
      body: title,
      activityId,
      actorId: uid,
    });

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post('/report-content', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const targetType = requiredString(req.body?.targetType, 'targetType', 30);
    const targetId = requiredString(req.body?.targetId, 'targetId', 300);
    const reason = requiredString(req.body?.reason, 'reason', 120);
    const details = optionalString(req.body?.details, 1000);

    if (!['user', 'activity', 'chat'].includes(targetType)) {
      throw new ApiError(400, 'invalid-argument', 'Tipo de denúncia inválido.');
    }
    if (targetType === 'user' && targetId === uid) {
      throw new ApiError(400, 'invalid-argument', 'Você não pode denunciar o próprio perfil.');
    }

    await db.collection('reports').add({
      reporterId: uid,
      targetType,
      targetId,
      reason,
      details,
      status: 'open',
      createdAt: FieldValue.serverTimestamp(),
    });

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post('/delete-account', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const userRef = db.collection('users').doc(uid);

    const createdActivities = await db
      .collection('activities')
      .where('creatorId', '==', uid)
      .get();

    for (const activity of createdActivities.docs) {
      const currentStatus = activity.data().status;
      await activity.ref.update({
        creatorName: 'Usuário excluído',
        status: currentStatus === 'active' ? 'cancelled' : currentStatus,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    await db.recursiveDelete(userRef);
    await admin.auth().deleteUser(uid);

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post('/notify-chat-message', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);
    const messageId = requiredString(req.body?.messageId, 'messageId', 200);

    const activityRef = db.collection('activities').doc(activityId);
    const messageRef = activityRef.collection('chat').doc(messageId);

    const [activitySnapshot, messageSnapshot, participantSnapshot] = await Promise.all([
      activityRef.get(),
      messageRef.get(),
      activityRef.collection('participants').doc(uid).get(),
    ]);

    if (!activitySnapshot.exists) {
      throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
    }
    if (!messageSnapshot.exists) {
      throw new ApiError(404, 'not-found', 'Mensagem não encontrada.');
    }

    const activity = activitySnapshot.data() || {};
    const message = messageSnapshot.data() || {};
    const creatorId = String(activity.creatorId || '');

    if (!participantSnapshot.exists && creatorId !== uid) {
      throw new ApiError(403, 'permission-denied', 'Você não participa desta atividade.');
    }
    if (String(message.senderId || '') !== uid) {
      throw new ApiError(403, 'permission-denied', 'Você não pode notificar uma mensagem de outro usuário.');
    }

    const participants = await activityRef.collection('participants').get();
    const title = String(activity.title || 'Atividade');
    const senderName = String(message.senderName || 'Nova mensagem');
    const text = message.type === 'image'
      ? '📷 Foto'
      : message.type === 'audio'
        ? '🎤 Áudio'
        : String(message.text || '').slice(0, 120);

    await Promise.all(
      participants.docs
        .filter((document) => document.id !== uid)
        .map((document) =>
          notify(document.id, {
            type: 'new_message',
            title: senderName,
            body: `${title}: ${text}`,
            activityId,
            actorId: uid,
          }),
        ),
    );

    if (creatorId && creatorId !== uid && !participants.docs.some((d) => d.id === creatorId)) {
      await notify(creatorId, {
        type: 'new_message',
        title: senderName,
        body: `${title}: ${text}`,
        activityId,
        actorId: uid,
      });
    }

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

async function notifyActivityParticipants(activityId, creatorId, type, title, body) {
  const participants = await db
    .collection('activities')
    .doc(activityId)
    .collection('participants')
    .get();

  await Promise.all(
    participants.docs
      .filter((document) => document.id !== creatorId)
      .map((document) =>
        notify(document.id, {
          type,
          title,
          body,
          activityId,
          actorId: creatorId,
        }),
      ),
  );
}

app.post('/update-activity', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);
    const title = requiredString(req.body?.title, 'title', 120);
    const description = optionalString(req.body?.description, 2000);
    const category = requiredString(req.body?.category, 'category', 40);
    const address = requiredString(req.body?.address, 'address', 300);
    const latitude = Number(req.body?.latitude);
    const longitude = Number(req.body?.longitude);
    const geohash = optionalString(req.body?.geohash, 100);
    const startsAt = parseDate(req.body?.startsAt, 'startsAt');
    const maxParticipants = Number(req.body?.maxParticipants);
    const isPrivate = req.body?.isPrivate === true;

    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
      throw new ApiError(400, 'invalid-argument', 'Latitude inválida.');
    }
    if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
      throw new ApiError(400, 'invalid-argument', 'Longitude inválida.');
    }
    if (!Number.isInteger(maxParticipants) || maxParticipants < 2 || maxParticipants > 10000) {
      throw new ApiError(400, 'invalid-argument', 'Limite de participantes inválido.');
    }
    if (startsAt.getTime() <= Date.now()) {
      throw new ApiError(400, 'invalid-argument', 'Escolha uma data e horário futuros.');
    }

    const activityRef = db.collection('activities').doc(activityId);
    let currentTitle = title;

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(activityRef);
      if (!snapshot.exists) {
        throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
      }

      const activity = snapshot.data() || {};
      if (String(activity.creatorId || '') !== uid) {
        throw new ApiError(403, 'permission-denied', 'Somente o organizador pode editar esta atividade.');
      }
      if (activity.status !== 'active') {
        throw new ApiError(412, 'failed-precondition', 'Atividade indisponível para edição.');
      }
      if (maxParticipants < Number(activity.participantCount || 1)) {
        throw new ApiError(400, 'invalid-argument', 'O limite não pode ser menor que o número atual de participantes.');
      }

      currentTitle = title;
      transaction.update(activityRef, {
        title,
        description,
        category,
        address,
        latitude,
        longitude,
        geohash,
        startsAt: Timestamp.fromDate(startsAt),
        maxParticipants,
        isPrivate,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    await notifyActivityParticipants(
      activityId,
      uid,
      'activity_updated',
      'Atividade atualizada',
      currentTitle,
    );

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post('/cancel-activity', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);
    const activityRef = db.collection('activities').doc(activityId);
    let title = 'Atividade';
    let changed = false;

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(activityRef);
      if (!snapshot.exists) {
        throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
      }

      const activity = snapshot.data() || {};
      if (String(activity.creatorId || '') !== uid) {
        throw new ApiError(403, 'permission-denied', 'Somente o organizador pode cancelar esta atividade.');
      }

      title = String(activity.title || 'Atividade');
      if (activity.status === 'cancelled') return;

      transaction.update(activityRef, {
        status: 'cancelled',
        updatedAt: FieldValue.serverTimestamp(),
      });
      changed = true;
    });

    if (changed) {
      await notifyActivityParticipants(
        activityId,
        uid,
        'activity_cancelled',
        'Atividade cancelada',
        title,
      );
    }

    res.json({ ok: true, changed });
  } catch (error) {
    next(error);
  }
});

// ---- Juntaí v2: áudio por URL, mensagens privadas e comércio completo ----
function usageMonthKey(date = new Date()) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}

function optionalHttpUrl(value, field, maxLength = 500) {
  const text = optionalString(value, maxLength);
  if (text && !/^https?:\/\//i.test(text)) {
    throw new ApiError(400, 'invalid-url', `${field} deve começar com http:// ou https://.`);
  }
  return text;
}

app.post('/upload-audio', authenticate, async (req, res, next) => {
  try {
    if (!imageKitPrivateKey) {
      throw new ApiError(
        503,
        'audio-service-not-configured',
        'O serviço de mídia ainda não está configurado no servidor.',
      );
    }

    const uid = req.user.uid;
    const purpose = requiredString(req.body?.purpose, 'purpose', 30);
    const encoded = requiredString(req.body?.base64, 'base64', 6_000_000);
    const requestedName = optionalString(req.body?.fileName, 160);
    const mimeType = optionalString(req.body?.mimeType, 80).toLowerCase();

    if (!['chat', 'private_chat'].includes(purpose)) {
      throw new ApiError(400, 'invalid-argument', 'Destino de áudio inválido.');
    }

    const allowedMimeTypes = new Set([
      'audio/mp4',
      'audio/m4a',
      'audio/x-m4a',
      'audio/aac',
    ]);

    if (!allowedMimeTypes.has(mimeType)) {
      throw new ApiError(400, 'invalid-argument', 'Formato de áudio não suportado.');
    }

    let bytes;
    try {
      bytes = Buffer.from(encoded, 'base64');
    } catch (_) {
      throw new ApiError(400, 'invalid-argument', 'Áudio inválido.');
    }

    if (!bytes.length) {
      throw new ApiError(400, 'invalid-argument', 'Áudio vazio.');
    }
    if (bytes.length > 4 * 1024 * 1024) {
      throw new ApiError(413, 'payload-too-large', 'O áudio ficou grande demais. Grave uma mensagem menor.');
    }

    const extension = mimeType === 'audio/aac' ? 'aac' : 'm4a';
    const safeRequestedName = requestedName
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .replace(/\.+/g, '.')
      .slice(0, 120);
    const generatedName = `${purpose}_${Date.now()}_${Math.random().toString(36).slice(2, 10)}.${extension}`;
    const fileName = safeRequestedName || generatedName;
    const folder = `/juntai/audio/${purpose}/${uid}`;

    const form = new FormData();
    form.append('file', new Blob([bytes], { type: mimeType }), fileName);
    form.append('fileName', fileName);
    form.append('folder', folder);
    form.append('useUniqueFileName', 'true');

    const auth = Buffer.from(`${imageKitPrivateKey}:`).toString('base64');
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 45000);

    let uploadResponse;
    try {
      uploadResponse = await fetch('https://upload.imagekit.io/api/v1/files/upload', {
        method: 'POST',
        headers: {
          Authorization: `Basic ${auth}`,
          Accept: 'application/json',
        },
        body: form,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }

    const payload = await uploadResponse.json().catch(() => ({}));
    if (!uploadResponse.ok) {
      console.error('ImageKit audio upload error:', uploadResponse.status, payload);
      throw new ApiError(
        502,
        'audio-upload-failed',
        String(payload?.message || 'Não foi possível enviar o áudio.'),
      );
    }

    const url = String(payload?.url || '').trim();
    const fileId = String(payload?.fileId || '').trim();
    if (!url) {
      throw new ApiError(502, 'audio-upload-failed', 'O servidor não retornou a URL do áudio.');
    }

    res.json({ ok: true, url, fileId });
  } catch (error) {
    if (error?.name === 'AbortError') {
      return next(new ApiError(504, 'audio-upload-timeout', 'O envio do áudio demorou demais. Tente novamente.'));
    }
    next(error);
  }
});

app.post('/update-business', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const ref = db.collection('business_profiles').doc(uid);
    const snapshot = await ref.get();
    if (!snapshot.exists) {
      throw new ApiError(404, 'business-not-found', 'Perfil comercial não encontrado.');
    }

    const current = snapshot.data() || {};
    const latitude = Number(req.body?.latitude);
    const longitude = Number(req.body?.longitude);
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
        !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
      throw new ApiError(400, 'invalid-location', 'Localização inválida.');
    }

    const nextData = {
      name: requiredString(req.body?.name, 'name', 80),
      category: requiredString(req.body?.category, 'category', 50),
      city: requiredString(req.body?.city, 'city', 80),
      address: requiredString(req.body?.address, 'address', 250),
      latitude,
      longitude,
      websiteUrl: optionalHttpUrl(req.body?.websiteUrl, 'websiteUrl', 500),
      description: optionalString(req.body?.description, 800),
    };

    const criticalChanged =
      nextData.name !== String(current.name || '') ||
      nextData.category !== String(current.category || '') ||
      nextData.city !== String(current.city || '') ||
      nextData.address !== String(current.address || '') ||
      Number(current.latitude) !== latitude ||
      Number(current.longitude) !== longitude;

    await ref.update({
      ...nextData,
      ...(criticalChanged ? { verified: false, reviewStatus: 'pending' } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const posts = await db.collection('discoveries').where('businessId', '==', uid).get();
    await Promise.all(posts.docs.map((post) => post.ref.update({
      businessName: nextData.name,
      businessCategory: nextData.category,
      businessVerified: criticalChanged ? false : current.verified === true,
      address: nextData.address,
      latitude,
      longitude,
      websiteUrl: nextData.websiteUrl,
      updatedAt: FieldValue.serverTimestamp(),
    })));

    res.json({ ok: true, reviewStatus: criticalChanged ? 'pending' : current.reviewStatus });
  } catch (error) {
    next(error);
  }
});

app.post(['/create-business-post', '/create-business-post-v2'], authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const businessRef = db.collection('business_profiles').doc(uid);
    const postRef = db.collection('discoveries').doc();
    const activeQuery = db
      .collection('discoveries')
      .where('businessId', '==', uid)
      .where('status', '==', 'published');

    const type = optionalString(req.body?.type, 30) || 'experience';
    if (!['experience', 'event', 'open_slots', 'promotion', 'schedule'].includes(type)) {
      throw new ApiError(400, 'invalid-type', 'Tipo de publicação inválido.');
    }

    const startsAt = req.body?.eventStartsAt
      ? parseDate(req.body.eventStartsAt, 'eventStartsAt')
      : null;
    if (startsAt && startsAt.getTime() <= Date.now()) {
      throw new ApiError(400, 'invalid-event-date', 'Escolha uma data futura para o evento.');
    }
    const month = usageMonthKey();

    await db.runTransaction(async (transaction) => {
      const [businessSnapshot, activeSnapshot] = await Promise.all([
        transaction.get(businessRef),
        transaction.get(activeQuery),
      ]);

      if (!businessSnapshot.exists) {
        throw new ApiError(412, 'business-required', 'Crie seu perfil comercial primeiro.');
      }

      const business = businessSnapshot.data() || {};
      if (business.reviewStatus !== 'approved') {
        throw new ApiError(
          403,
          'business-not-approved',
          'Seu perfil comercial precisa ser aprovado antes de publicar.',
        );
      }

      const activeLimit = Math.max(Number(business.activePostLimit || 1), 1);
      if (activeSnapshot.size >= activeLimit) {
        throw new ApiError(409, 'active-plan-limit', 'Seu plano atingiu o limite de publicações ativas.');
      }

      const monthlyLimit = Math.max(Number(business.monthlyPostLimit || 1), 1);
      const used = String(business.usageMonth || '') === month
        ? Math.max(Number(business.postsUsedThisMonth || 0), 0)
        : 0;
      if (used >= monthlyLimit) {
        throw new ApiError(409, 'monthly-plan-limit', 'Seu plano atingiu o limite de publicações deste mês.');
      }

      const coverUrl = optionalHttpUrl(req.body?.coverUrl, 'coverUrl', 500);
      if (!coverUrl) {
        throw new ApiError(400, 'invalid-argument', 'coverUrl é obrigatório.');
      }

      transaction.set(postRef, {
        businessId: uid,
        businessName: String(business.name || ''),
        businessCategory: String(business.category || ''),
        businessVerified: business.verified === true,
        type,
        title: requiredString(req.body?.title, 'title', 120),
        description: requiredString(req.body?.description, 'description', 1200),
        coverUrl,
        address: String(business.address || ''),
        latitude: Number(business.latitude),
        longitude: Number(business.longitude),
        websiteUrl: optionalHttpUrl(business.websiteUrl, 'websiteUrl', 500),
        groupBenefit: optionalString(req.body?.groupBenefit, 300),
        ctaLabel: requiredString(req.body?.ctaLabel || 'Criar atividade aqui', 'ctaLabel', 40),
        officialEvent: req.body?.officialEvent === true,
        eventStartsAt: startsAt ? Timestamp.fromDate(startsAt) : null,
        sponsored: false,
        status: 'published',
        views: 0,
        opens: 0,
        activitiesCreated: 0,
        participantsGenerated: 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.update(businessRef, {
        postsUsedThisMonth: used + 1,
        usageMonth: month,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    res.json({ ok: true, postId: postRef.id });
  } catch (error) {
    next(error);
  }
});

app.post('/update-business-post', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const postId = requiredString(req.body?.postId, 'postId', 200);
    const postRef = db.collection('discoveries').doc(postId);
    const businessRef = db.collection('business_profiles').doc(uid);
    const [postSnapshot, businessSnapshot] = await Promise.all([
      postRef.get(),
      businessRef.get(),
    ]);

    if (!postSnapshot.exists) {
      throw new ApiError(404, 'not-found', 'Publicação não encontrada.');
    }
    const post = postSnapshot.data() || {};
    if (String(post.businessId || '') !== uid) {
      throw new ApiError(403, 'permission-denied', 'Você não pode editar esta publicação.');
    }
    if (post.status === 'archived') {
      throw new ApiError(412, 'archived', 'Publicação arquivada não pode ser editada.');
    }
    if (!businessSnapshot.exists) {
      throw new ApiError(412, 'business-required', 'Perfil comercial não encontrado.');
    }

    const business = businessSnapshot.data() || {};
    const type = optionalString(req.body?.type, 30) || String(post.type || 'experience');
    if (!['experience', 'event', 'open_slots', 'promotion', 'schedule'].includes(type)) {
      throw new ApiError(400, 'invalid-type', 'Tipo de publicação inválido.');
    }
    const startsAt = req.body?.eventStartsAt
      ? parseDate(req.body.eventStartsAt, 'eventStartsAt')
      : null;
    if (startsAt && startsAt.getTime() <= Date.now()) {
      throw new ApiError(400, 'invalid-event-date', 'Escolha uma data futura para o evento.');
    }
    const coverUrl = optionalHttpUrl(req.body?.coverUrl, 'coverUrl', 500);
    if (!coverUrl) {
      throw new ApiError(400, 'invalid-argument', 'coverUrl é obrigatório.');
    }

    await postRef.update({
      businessName: String(business.name || post.businessName || ''),
      businessCategory: String(business.category || post.businessCategory || ''),
      businessVerified: business.verified === true,
      type,
      title: requiredString(req.body?.title, 'title', 120),
      description: requiredString(req.body?.description, 'description', 1200),
      coverUrl,
      address: String(business.address || post.address || ''),
      latitude: Number(business.latitude ?? post.latitude),
      longitude: Number(business.longitude ?? post.longitude),
      websiteUrl: optionalHttpUrl(business.websiteUrl, 'websiteUrl', 500),
      groupBenefit: optionalString(req.body?.groupBenefit, 300),
      ctaLabel: requiredString(req.body?.ctaLabel || 'Criar atividade aqui', 'ctaLabel', 40),
      officialEvent: req.body?.officialEvent === true,
      eventStartsAt: startsAt ? Timestamp.fromDate(startsAt) : null,
      updatedAt: FieldValue.serverTimestamp(),
    });

    res.json({ ok: true, postId });
  } catch (error) {
    next(error);
  }
});

app.post('/archive-business-post', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const postId = requiredString(req.body?.postId, 'postId', 200);
    const postRef = db.collection('discoveries').doc(postId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(postRef);
      if (!snapshot.exists) {
        throw new ApiError(404, 'not-found', 'Publicação não encontrada.');
      }
      const data = snapshot.data() || {};
      if (String(data.businessId || '') !== uid) {
        throw new ApiError(403, 'permission-denied', 'Você não pode arquivar esta publicação.');
      }
      if (data.status === 'archived') return;
      transaction.update(postRef, {
        status: 'archived',
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

app.post('/register-discovery-activity', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const discoveryId = requiredString(req.body?.discoveryId, 'discoveryId', 200);
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);
    const discoveryRef = db.collection('discoveries').doc(discoveryId);
    const activityRef = db.collection('activities').doc(activityId);
    const markerRef = discoveryRef.collection('activity_links').doc(activityId);
    let counted = false;

    await db.runTransaction(async (transaction) => {
      const [discovery, activity, marker] = await Promise.all([
        transaction.get(discoveryRef),
        transaction.get(activityRef),
        transaction.get(markerRef),
      ]);
      if (!discovery.exists) {
        throw new ApiError(404, 'not-found', 'Descoberta não encontrada.');
      }
      if (!activity.exists) {
        throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
      }
      const activityData = activity.data() || {};
      if (String(activityData.creatorId || '') !== uid) {
        throw new ApiError(403, 'permission-denied', 'Somente o criador pode vincular a atividade.');
      }
      if (String(activityData.sourceDiscoveryId || '') !== discoveryId) {
        throw new ApiError(412, 'invalid-source', 'A atividade não pertence a esta descoberta.');
      }
      if (marker.exists) return;

      transaction.set(markerRef, {
        activityId,
        creatorId: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(discoveryRef, {
        activitiesCreated: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      counted = true;
    });

    res.json({ ok: true, counted });
  } catch (error) {
    next(error);
  }
});

app.post('/record-discovery-participant', authenticate, async (req, res, next) => {
  try {
    const actorUid = req.user.uid;
    const activityId = requiredString(req.body?.activityId, 'activityId', 200);
    const requestedUserId = optionalString(req.body?.userId, 200);
    const participantUid = requestedUserId || actorUid;
    const activityRef = db.collection('activities').doc(activityId);
    const activitySnapshot = await activityRef.get();

    if (!activitySnapshot.exists) {
      throw new ApiError(404, 'not-found', 'Atividade não encontrada.');
    }

    const activity = activitySnapshot.data() || {};
    if (participantUid !== actorUid && String(activity.creatorId || '') !== actorUid) {
      throw new ApiError(403, 'permission-denied', 'Somente o organizador pode registrar outro participante.');
    }

    const participant = await activityRef.collection('participants').doc(participantUid).get();
    if (!participant.exists) {
      throw new ApiError(412, 'not-participant', 'O usuário ainda não participa da atividade.');
    }

    const discoveryId = String(activity.sourceDiscoveryId || '').trim();
    if (!discoveryId) {
      return res.json({ ok: true, counted: false, reason: 'no-discovery' });
    }

    const discoveryRef = db.collection('discoveries').doc(discoveryId);
    const markerRef = discoveryRef.collection('participant_users').doc(participantUid);
    let counted = false;

    await db.runTransaction(async (transaction) => {
      const [discovery, marker] = await Promise.all([
        transaction.get(discoveryRef),
        transaction.get(markerRef),
      ]);
      if (!discovery.exists) return;
      if (marker.exists) return;

      transaction.set(markerRef, {
        userId: participantUid,
        firstActivityId: activityId,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(discoveryRef, {
        participantsGenerated: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      counted = true;
    });

    res.json({ ok: true, counted });
  } catch (error) {
    next(error);
  }
});

app.post('/send-private-message', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const otherUid = requiredString(req.body?.otherUserId, 'otherUserId', 200);

    if (otherUid === uid) {
      throw new ApiError(400, 'invalid-recipient', 'Escolha outro usuario para conversar.');
    }
    if (await blockedEither(uid, otherUid)) {
      throw new ApiError(
        403,
        'blocked',
        'Nao e possivel enviar mensagens entre usuarios bloqueados.',
      );
    }

    const targetProfile = await db.collection('users').doc(otherUid).get();
    if (!targetProfile.exists) {
      throw new ApiError(404, 'user-not-found', 'Usuario nao encontrado.');
    }

    const raw = req.body?.message;
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
      throw new ApiError(400, 'invalid-message', 'Mensagem invalida.');
    }

    const type = requiredString(raw.type, 'type', 20);
    if (!['text', 'image', 'audio', 'activity'].includes(type)) {
      throw new ApiError(400, 'invalid-message-type', 'Tipo de mensagem invalido.');
    }

    const ids = [uid, otherUid].sort();
    const conversationId = `${ids[0]}_${ids[1]}`;
    const conversationRef = db.collection('private_conversations').doc(conversationId);
    const messageRef = conversationRef.collection('messages').doc();

    const message = {
      senderId: uid,
      type,
      text: '',
      createdAt: FieldValue.serverTimestamp(),
      deliveredTo: [uid],
      seenBy: [uid],
      hiddenFor: [],
      deletedForEveryone: false,
    };

    let preview = optionalString(req.body?.preview, 180);

    if (type === 'text') {
      message.text = requiredString(raw.text, 'text', 4000);
      preview = preview || message.text.slice(0, 180);
    }

    if (type === 'image') {
      const mediaUrl = optionalHttpUrl(raw.mediaUrl, 'mediaUrl', 2048);
      if (!mediaUrl) {
        throw new ApiError(400, 'invalid-image', 'A foto enviada nao possui URL valida.');
      }
      message.mediaUrl = mediaUrl;
      preview = preview || 'Foto';
    }

    if (type === 'audio') {
      const audioUrl = optionalHttpUrl(raw.audioUrl, 'audioUrl', 2048);
      if (!audioUrl) {
        throw new ApiError(400, 'invalid-audio', 'O audio enviado nao possui URL valida.');
      }

      const durationMs = Number(raw.audioDurationMs);
      if (!Number.isInteger(durationMs) || durationMs < 1 || durationMs > 60000) {
        throw new ApiError(400, 'invalid-audio-duration', 'Duracao de audio invalida.');
      }

      const mimeType = optionalString(raw.audioMimeType, 40) || 'audio/mp4';
      if (!['audio/mp4', 'audio/m4a', 'audio/x-m4a', 'audio/aac'].includes(mimeType)) {
        throw new ApiError(400, 'invalid-audio-type', 'Formato de audio invalido.');
      }

      message.audioUrl = audioUrl;
      message.audioMimeType = mimeType;
      message.audioDurationMs = durationMs;
      message.viewOnce = raw.viewOnce === true;
      preview = preview || 'Audio';
    }

    if (type === 'activity') {
      const activityId = requiredString(raw.activityId, 'activityId', 200);
      const activitySnapshot = await db.collection('activities').doc(activityId).get();

      if (!activitySnapshot.exists) {
        throw new ApiError(404, 'activity-not-found', 'Atividade nao encontrada.');
      }

      const activity = activitySnapshot.data() || {};
      if (activity.status !== 'active') {
        throw new ApiError(412, 'activity-unavailable', 'Atividade indisponivel.');
      }

      if (activity.isPrivate === true && String(activity.creatorId || '') !== uid) {
        const membership = await activitySnapshot.ref
          .collection('participants')
          .doc(uid)
          .get();
        if (!membership.exists) {
          throw new ApiError(
            403,
            'permission-denied',
            'Voce nao pode compartilhar esta atividade privada.',
          );
        }
      }

      const activityTitle = String(activity.title || 'Atividade').slice(0, 180);
      message.text = activityTitle;
      message.activityId = activityId;
      message.activityTitle = activityTitle;
      if (activity.startsAt) {
        message.activityStartsAt = activity.startsAt;
      }
      preview = preview || `Atividade: ${activityTitle}`.slice(0, 180);
    }

    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(conversationRef);

      if (current.exists) {
        const currentParticipants = Array.isArray(current.data()?.participants)
          ? current.data().participants.map(String).sort()
          : [];

        if (
          currentParticipants.length !== 2 ||
          currentParticipants[0] !== ids[0] ||
          currentParticipants[1] !== ids[1]
        ) {
          throw new ApiError(409, 'invalid-conversation', 'Conversa privada invalida.');
        }
      }

      transaction.set(
        conversationRef,
        {
          participants: ids,
          updatedAt: FieldValue.serverTimestamp(),
          ...(current.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
          lastMessage: (preview || 'Nova mensagem').slice(0, 180),
          lastSenderId: uid,
          lastMessageId: messageRef.id,
        },
        { merge: true },
      );

      transaction.set(messageRef, message);
    });

    res.json({
      ok: true,
      conversationId,
      messageId: messageRef.id,
    });
  } catch (error) {
    next(error);
  }
});
app.post('/notify-private-message', authenticate, async (req, res, next) => {
  try {
    const uid = req.user.uid;
    const conversationId = requiredString(req.body?.conversationId, 'conversationId', 300);
    const messageId = requiredString(req.body?.messageId, 'messageId', 200);
    const conversationRef = db.collection('private_conversations').doc(conversationId);
    const messageRef = conversationRef.collection('messages').doc(messageId);

    const [conversationSnapshot, messageSnapshot] = await Promise.all([
      conversationRef.get(),
      messageRef.get(),
    ]);

    if (!conversationSnapshot.exists || !messageSnapshot.exists) {
      throw new ApiError(404, 'not-found', 'Conversa ou mensagem não encontrada.');
    }

    const conversation = conversationSnapshot.data() || {};
    const message = messageSnapshot.data() || {};
    const participants = Array.isArray(conversation.participants)
      ? conversation.participants.map(String)
      : [];

    if (!participants.includes(uid) || String(message.senderId || '') !== uid) {
      throw new ApiError(403, 'permission-denied', 'Você não pode notificar esta mensagem.');
    }

    const targetUid = participants.find((id) => id !== uid);
    if (!targetUid) {
      throw new ApiError(412, 'invalid-conversation', 'Conversa privada inválida.');
    }
    if (await blockedEither(uid, targetUid)) {
      throw new ApiError(403, 'blocked', 'Não é possível enviar mensagens entre usuários bloqueados.');
    }

    const profile = await userData(uid);
    const senderName = String(profile.name || 'Nova mensagem');
    const preview = message.type === 'image'
      ? '📷 Foto'
      : message.type === 'audio'
        ? '🎤 Áudio'
        : message.type === 'activity'
          ? `📅 ${String(message.activityTitle || message.text || 'Atividade').slice(0, 100)}`
          : String(message.text || '').slice(0, 140);

    await notify(targetUid, {
      type: 'private_message',
      title: senderName,
      body: preview || 'Nova mensagem',
      actorId: uid,
    });

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});
// ---- fim Juntaí v2 ----


// JUNTAI_BLUEPRINT_V6

const BP_PLANS = {
  free: {
    price: 0,
    monthlyPostLimit: 1,
    activePostLimit: 1,
  },
  local: {
    price: 29.90,
    monthlyPostLimit: 5,
    activePostLimit: 5,
  },
  pro: {
    price: 59.90,
    monthlyPostLimit: 15,
    activePostLimit: 15,
  },
  premium: {
    price: 99.90,
    monthlyPostLimit: 50,
    activePostLimit: 50,
  },
};

const BP_POST_TYPES =
  new Set([
    'experience',
    'event',
    'open_slots',
    'promotion',
    'schedule',
  ]);

const BP_BENEFIT_TYPES =
  new Set([
    'percentage_discount',
    'fixed_discount',
    'free_item',
    'group_reward',
    'special_price',
    'priority_entry',
  ]);

const BP_REPORT_TYPES =
  new Set([
    'user',
    'business',
    'business_post',
    'activity',
    'direct_message',
    'group_message',
    'chat',
  ]);

function bpNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n)
    ? n
    : fallback;
}

function bpUsername(value) {
  const username =
    String(value || '')
      .trim()
      .toLowerCase()
      .replace(/^@+/, '');

  if (username.length < 3 ||
      username.length > 30 ||
      !/^[a-z][a-z0-9_]*(\.[a-z0-9_]+)*$/
        .test(username)) {
    throw new ApiError(
      400,
      'invalid-username',
      'Use letras, nÃºmeros, ponto ou _, comeÃ§ando por letra.',
    );
  }

  return username;
}

function bpDayKey(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

async function bpMetric(
  businessId,
  field,
  amount = 1,
) {
  if (!businessId ||
      !field ||
      !amount) {
    return;
  }

  const businessRef =
    db.collection('business_profiles')
      .doc(businessId);

  const dailyRef =
    businessRef
      .collection('metrics_daily')
      .doc(bpDayKey());

  const batch = db.batch();

  batch.set(
    dailyRef,
    {
      date: bpDayKey(),
      [field]:
        FieldValue.increment(amount),
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  if (field ===
      'participantsGenerated') {
    batch.set(
      businessRef,
      {
        participantsGenerated:
          FieldValue.increment(amount),
        updatedAt:
          FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  await batch.commit();
}

function bpBenefitCode() {
  const chars =
    'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  let code = 'JUNTAI-';

  for (let i = 0; i < 4; i += 1) {
    code += chars[
      Math.floor(
        Math.random() * chars.length,
      )
    ];
  }

  return code;
}

async function bpCreateBenefit({
  businessId,
  postId = null,
  activityId = null,
  benefitType,
  benefitValue,
  benefitLabel,
  participants = [],
}) {
  for (
    let attempt = 0;
    attempt < 10;
    attempt += 1
  ) {
    const code = bpBenefitCode();

    const ref =
      db.collection('benefit_codes')
        .doc(code);

    if ((await ref.get()).exists) {
      continue;
    }

    await ref.set({
      code,
      businessId,
      postId,
      activityId,
      benefitType:
        benefitType || 'group_reward',
      benefitValue:
        benefitValue ?? null,
      benefitLabel:
        benefitLabel ||
        'BenefÃ­cio JuntaÃ­',
      participantIds: participants,
      participantCount:
        participants.length,
      status: 'active',
      createdAt:
        FieldValue.serverTimestamp(),
      redeemedAt: null,
      redeemedByBusinessId: null,
    });

    await bpMetric(
      businessId,
      'couponUnlocks',
      1,
    );

    return code;
  }

  throw new ApiError(
    500,
    'code-generation-failed',
    'NÃ£o foi possÃ­vel gerar o cÃ³digo.',
  );
}

async function bpAdmin(
  req,
  _res,
  next,
) {
  try {
    if (req.user?.admin === true) {
      return next();
    }

    const allowed =
      String(
        process.env.ADMIN_EMAILS || '',
      )
        .split(',')
        .map((v) =>
          v.trim().toLowerCase())
        .filter(Boolean);

    const email =
      String(req.user?.email || '')
        .toLowerCase();

    if (email &&
        allowed.includes(email)) {
      return next();
    }

    throw new ApiError(
      403,
      'admin-required',
      'Acesso administrativo necessÃ¡rio.',
    );
  } catch (error) {
    next(error);
  }
}

async function bpPayment({
  title,
  price,
  externalReference,
}) {
  const token =
    String(
      process.env
        .MERCADO_PAGO_ACCESS_TOKEN ||
        '',
    ).trim();

  if (!token) {
    throw new ApiError(
      503,
      'payment-not-configured',
      'Configure MERCADO_PAGO_ACCESS_TOKEN no Render.',
    );
  }

  const publicApi =
    String(
      process.env.PUBLIC_API_URL ||
      'https://juntai-flutter.onrender.com',
    ).replace(/\/+$/, '');

  const response =
    await fetch(
      'https://api.mercadopago.com/checkout/preferences',
      {
        method: 'POST',
        headers: {
          Authorization:
            `Bearer ${token}`,
          'Content-Type':
            'application/json',
        },
        body: JSON.stringify({
          items: [{
            id: externalReference,
            title,
            quantity: 1,
            currency_id: 'BRL',
            unit_price:
              Number(price),
          }],
          external_reference:
            externalReference,
          notification_url:
            `${publicApi}/blueprint/mercadopago/webhook`,
          back_urls: {
            success:
              `${publicApi}/payment/success`,
            pending:
              `${publicApi}/payment/pending`,
            failure:
              `${publicApi}/payment/failure`,
          },
          auto_return: 'approved',
        }),
      },
    );

  const payload =
    await response
      .json()
      .catch(() => ({}));

  if (!response.ok ||
      !payload.init_point) {
    console.error(
      'Mercado Pago:',
      response.status,
      payload,
    );

    throw new ApiError(
      502,
      'payment-provider-error',
      'NÃ£o foi possÃ­vel iniciar o pagamento.',
    );
  }

  return payload.init_point;
}

async function bpNotifyFollowers(
  businessId,
  post,
) {
  const followers =
    await db
      .collection('business_profiles')
      .doc(businessId)
      .collection('followers')
      .get();

  const type =
    post.type === 'open_slots' ||
    post.type === 'schedule'
      ? 'business_open_slots'
      : 'business_new_post';

  await Promise.allSettled(
    followers.docs.map(
      async (follower) => {
        const preferences =
          follower.data() || {};

        if (post.type === 'event' &&
            preferences.notifyEvents ===
              false) {
          return;
        }

        if ((post.type ===
              'open_slots' ||
             post.type ===
              'schedule') &&
            preferences
              .notifyOpenSlots ===
              false) {
          return;
        }

        if (post.benefitType &&
            preferences
              .notifyBenefits ===
              false) {
          return;
        }

        if (type ===
              'business_new_post' &&
            preferences.notifyPosts ===
              false) {
          return;
        }

        await notify(
          follower.id,
          {
            type,
            title:
              String(
                post.businessName ||
                'Novidade no JuntaÃ­',
              ),
            body:
              String(
                post.title ||
                'Nova publicaÃ§Ã£o',
              ),
            route:
              `/discovery/${post.id}`,
          },
        );
      },
    ),
  );
}

app.post(
  '/blueprint/change-username',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const username =
        bpUsername(
          req.body?.username,
        );

      const userRef =
        db.collection('users')
          .doc(uid);

      const newRef =
        db.collection('usernames')
          .doc(username);

      await db.runTransaction(
        async (transaction) => {
          const user =
            await transaction
              .get(userRef);

          if (!user.exists) {
            throw new ApiError(
              404,
              'user-not-found',
              'Perfil nÃ£o encontrado.',
            );
          }

          const target =
            await transaction
              .get(newRef);

          if (target.exists &&
              String(
                target.data()?.uid ||
                '',
              ) !== uid) {
            throw new ApiError(
              409,
              'username-taken',
              'Este @usuÃ¡rio jÃ¡ estÃ¡ em uso.',
            );
          }

          const old =
            String(
              user.data()?.username ||
              '',
            ).toLowerCase();

          if (old === username) {
            return;
          }

          transaction.set(
            newRef,
            {
              uid,
              createdAt:
                target.data()
                  ?.createdAt ||
                FieldValue
                  .serverTimestamp(),
            },
          );

          transaction.update(
            userRef,
            {
              username,
              usernameLower:
                username,
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
          );

          if (old) {
            const oldRef =
              db.collection('usernames')
                .doc(old);

            const oldDoc =
              await transaction
                .get(oldRef);

            if (oldDoc.exists &&
                String(
                  oldDoc.data()?.uid ||
                  '',
                ) === uid) {
              transaction.delete(
                oldRef,
              );
            }
          }
        },
      );

      res.json({
        ok: true,
        username,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/sync-social-counters',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const userRef =
        db.collection('users')
          .doc(uid);

      const [
        followers,
        following,
      ] = await Promise.all([
        userRef
          .collection('followers')
          .count()
          .get(),
        userRef
          .collection('following')
          .count()
          .get(),
      ]);

      await userRef.set(
        {
          followersCount:
            followers.data().count,
          followingCount:
            following.data().count,
          updatedAt:
            FieldValue
              .serverTimestamp(),
        },
        { merge: true },
      );

      res.json({
        ok: true,
        followersCount:
          followers.data().count,
        followingCount:
          following.data().count,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/follow-user',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const targetUid =
        requiredString(
          req.body?.userId,
          'userId',
          200,
        );

      const follow =
        req.body?.follow === true;

      if (uid === targetUid) {
        throw new ApiError(
          400,
          'invalid-target',
          'VocÃª nÃ£o pode seguir a si mesmo.',
        );
      }

      if (await blockedEither(
        uid,
        targetUid,
      )) {
        throw new ApiError(
          403,
          'blocked',
          'AÃ§Ã£o indisponÃ­vel entre usuÃ¡rios bloqueados.',
        );
      }

      const myRef =
        db.collection('users')
          .doc(uid);

      const targetRef =
        db.collection('users')
          .doc(targetUid);

      const followingRef =
        myRef
          .collection('following')
          .doc(targetUid);

      const followerRef =
        targetRef
          .collection('followers')
          .doc(uid);

      let changed = false;

      await db.runTransaction(
        async (transaction) => {
          const target =
            await transaction
              .get(targetRef);

          if (!target.exists) {
            throw new ApiError(
              404,
              'not-found',
              'UsuÃ¡rio nÃ£o encontrado.',
            );
          }

          const relation =
            await transaction
              .get(followingRef);

          if (follow &&
              !relation.exists) {
            transaction.set(
              followingRef,
              {
                userId: targetUid,
                createdAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            transaction.set(
              followerRef,
              {
                userId: uid,
                createdAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            transaction.set(
              myRef,
              {
                followingCount:
                  FieldValue
                    .increment(1),
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
              { merge: true },
            );

            transaction.set(
              targetRef,
              {
                followersCount:
                  FieldValue
                    .increment(1),
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
              { merge: true },
            );

            changed = true;
          }

          if (!follow &&
              relation.exists) {
            transaction.delete(
              followingRef,
            );

            transaction.delete(
              followerRef,
            );

            transaction.set(
              myRef,
              {
                followingCount:
                  FieldValue
                    .increment(-1),
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
              { merge: true },
            );

            transaction.set(
              targetRef,
              {
                followersCount:
                  FieldValue
                    .increment(-1),
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
              { merge: true },
            );

            changed = true;
          }
        },
      );

      if (changed && follow) {
        const me =
          await userData(uid);

        await notify(
          targetUid,
          {
            type:
              'new_follower',
            title:
              `@${String(
                me.username ||
                'alguÃ©m',
              )} comeÃ§ou a seguir vocÃª`,
            body:
              String(me.name || ''),
            actorId: uid,
            route:
              `/profile/user/${uid}`,
          },
        );
      }

      res.json({
        ok: true,
        following: follow,
        changed,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/create-business',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const ref =
        db.collection('business_profiles')
          .doc(uid);

      if ((await ref.get()).exists) {
        throw new ApiError(
          409,
          'already-exists',
          'VocÃª jÃ¡ possui perfil comercial.',
        );
      }

      const username =
        bpUsername(
          req.body?.username,
        );

      const usernameRef =
        db.collection(
          'business_usernames',
        ).doc(username);

      const latitude =
        bpNumber(
          req.body?.latitude,
          NaN,
        );

      const longitude =
        bpNumber(
          req.body?.longitude,
          NaN,
        );

      if (!Number.isFinite(latitude) ||
          !Number.isFinite(longitude)) {
        throw new ApiError(
          400,
          'invalid-location',
          'LocalizaÃ§Ã£o invÃ¡lida.',
        );
      }

      const accountType =
        optionalString(
          req.body?.accountType,
          30,
        ) || 'business';

      if (![
        'business',
        'organizer',
        'institution',
      ].includes(accountType)) {
        throw new ApiError(
          400,
          'invalid-account-type',
          'Tipo de conta comercial invÃ¡lido.',
        );
      }

      await db.runTransaction(
        async (transaction) => {
          const reserved =
            await transaction
              .get(usernameRef);

          if (reserved.exists) {
            throw new ApiError(
              409,
              'business-username-taken',
              'Este @comercial jÃ¡ estÃ¡ em uso.',
            );
          }

          transaction.set(
            usernameRef,
            {
              businessId: uid,
              ownerUid: uid,
              createdAt:
                FieldValue
                  .serverTimestamp(),
            },
          );

          transaction.set(
            ref,
            {
              businessId: uid,
              ownerId: uid,
              ownerUid: uid,
              name:
                requiredString(
                  req.body?.name,
                  'name',
                  80,
                ),
              username,
              category:
                requiredString(
                  req.body?.category,
                  'category',
                  60,
                ),
              description:
                optionalString(
                  req.body?.description,
                  1200,
                ),
              photoUrl:
                optionalString(
                  req.body?.photoUrl,
                  2048,
                ) || null,
              coverUrl:
                optionalString(
                  req.body?.coverUrl,
                  2048,
                ) || null,
              galleryUrls:
                Array.isArray(
                  req.body?.galleryUrls,
                )
                  ? req.body.galleryUrls
                      .map((v) =>
                        optionalString(
                          v,
                          2048,
                        ))
                      .filter(Boolean)
                      .slice(0, 8)
                  : [],
              city:
                requiredString(
                  req.body?.city,
                  'city',
                  80,
                ),
              state:
                requiredString(
                  req.body?.state,
                  'state',
                  40,
                ),
              address:
                requiredString(
                  req.body?.address,
                  'address',
                  250,
                ),
              latitude,
              longitude,
              phone:
                optionalString(
                  req.body?.phone,
                  40,
                ),
              websiteUrl:
                optionalString(
                  req.body?.websiteUrl,
                  500,
                ),
              instagram:
                optionalString(
                  req.body?.instagram,
                  100,
                ),
              accountType,
              institutionType:
                optionalString(
                  req.body
                    ?.institutionType,
                  100,
                ),
              verified: false,
              followersCount: 0,
              participantsGenerated: 0,
              profileVisits: 0,
              rating: 0,
              reviewStatus: 'pending',
              status: 'active',
              plan: 'free',
              monthlyPostLimit:
                BP_PLANS.free
                  .monthlyPostLimit,
              activePostLimit:
                BP_PLANS.free
                  .activePostLimit,
              postsUsedThisMonth: 0,
              usageMonth:
                usageMonthKey(),
              billingPeriodStart: null,
              billingPeriodEnd: null,
              createdAt:
                FieldValue
                  .serverTimestamp(),
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
          );
        },
      );

      res.json({
        ok: true,
        businessId: uid,
        username,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/update-business',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const ref =
        db.collection('business_profiles')
          .doc(uid);

      const current =
        await ref.get();

      if (!current.exists) {
        throw new ApiError(
          404,
          'not-found',
          'Perfil comercial nÃ£o encontrado.',
        );
      }

      const old =
        current.data() || {};

      const oldUsername =
        String(old.username || '');

      const username =
        bpUsername(
          req.body?.username ||
          oldUsername,
        );

      await db.runTransaction(
        async (transaction) => {
          if (username !==
              oldUsername) {
            const newRef =
              db.collection(
                'business_usernames',
              ).doc(username);

            const reserved =
              await transaction
                .get(newRef);

            if (reserved.exists) {
              throw new ApiError(
                409,
                'business-username-taken',
                'Este @comercial jÃ¡ estÃ¡ em uso.',
              );
            }

            transaction.set(
              newRef,
              {
                businessId: uid,
                ownerUid: uid,
                createdAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            if (oldUsername) {
              transaction.delete(
                db.collection(
                  'business_usernames',
                ).doc(oldUsername),
              );
            }
          }

          const criticalChanged =
            String(old.name || '') !==
              String(
                req.body?.name || '',
              ) ||
            String(
              old.category || '',
            ) !==
              String(
                req.body?.category ||
                '',
              ) ||
            String(
              old.address || '',
            ) !==
              String(
                req.body?.address ||
                '',
              ) ||
            String(old.city || '') !==
              String(
                req.body?.city || '',
              ) ||
            String(old.state || '') !==
              String(
                req.body?.state || '',
              );

          transaction.update(
            ref,
            {
              name:
                requiredString(
                  req.body?.name,
                  'name',
                  80,
                ),
              username,
              category:
                requiredString(
                  req.body?.category,
                  'category',
                  60,
                ),
              description:
                optionalString(
                  req.body?.description,
                  1200,
                ),
              photoUrl:
                optionalString(
                  req.body?.photoUrl,
                  2048,
                ) || null,
              coverUrl:
                optionalString(
                  req.body?.coverUrl,
                  2048,
                ) || null,
              galleryUrls:
                Array.isArray(
                  req.body?.galleryUrls,
                )
                  ? req.body.galleryUrls
                      .map((v) =>
                        optionalString(
                          v,
                          2048,
                        ))
                      .filter(Boolean)
                      .slice(0, 8)
                  : [],
              city:
                requiredString(
                  req.body?.city,
                  'city',
                  80,
                ),
              state:
                requiredString(
                  req.body?.state,
                  'state',
                  40,
                ),
              address:
                requiredString(
                  req.body?.address,
                  'address',
                  250,
                ),
              latitude:
                bpNumber(
                  req.body?.latitude,
                  old.latitude,
                ),
              longitude:
                bpNumber(
                  req.body?.longitude,
                  old.longitude,
                ),
              phone:
                optionalString(
                  req.body?.phone,
                  40,
                ),
              websiteUrl:
                optionalString(
                  req.body?.websiteUrl,
                  500,
                ),
              instagram:
                optionalString(
                  req.body?.instagram,
                  100,
                ),
              accountType:
                optionalString(
                  req.body?.accountType,
                  30,
                ) ||
                old.accountType ||
                'business',
              institutionType:
                optionalString(
                  req.body
                    ?.institutionType,
                  100,
                ),
              ...(criticalChanged
                ? {
                    verified: false,
                    reviewStatus:
                      'pending',
                  }
                : {}),
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
          );
        },
      );

      res.json({
        ok: true,
        username,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/follow-business',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const businessId =
        requiredString(
          req.body?.businessId,
          'businessId',
          200,
        );

      const follow =
        req.body?.follow === true;

      const businessRef =
        db.collection('business_profiles')
          .doc(businessId);

      const followerRef =
        businessRef
          .collection('followers')
          .doc(uid);

      let changed = false;

      await db.runTransaction(
        async (transaction) => {
          const business =
            await transaction
              .get(businessRef);

          if (!business.exists) {
            throw new ApiError(
              404,
              'not-found',
              'ComÃ©rcio nÃ£o encontrado.',
            );
          }

          const relation =
            await transaction
              .get(followerRef);

          if (follow &&
              !relation.exists) {
            transaction.set(
              followerRef,
              {
                userId: uid,
                notifyPosts: true,
                notifyEvents: true,
                notifyOpenSlots: true,
                notifyBenefits: true,
                createdAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            transaction.update(
              businessRef,
              {
                followersCount:
                  FieldValue
                    .increment(1),
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            changed = true;
          }

          if (!follow &&
              relation.exists) {
            transaction.delete(
              followerRef,
            );

            transaction.update(
              businessRef,
              {
                followersCount:
                  FieldValue
                    .increment(-1),
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            changed = true;
          }
        },
      );

      if (changed && follow) {
        await bpMetric(
          businessId,
          'followersGained',
          1,
        );
      }

      res.json({
        ok: true,
        following: follow,
        changed,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/business-follow-preferences',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const businessId =
        requiredString(
          req.body?.businessId,
          'businessId',
          200,
        );

      const ref =
        db.collection('business_profiles')
          .doc(businessId)
          .collection('followers')
          .doc(uid);

      if (!(await ref.get()).exists) {
        throw new ApiError(
          412,
          'not-following',
          'Siga o comÃ©rcio primeiro.',
        );
      }

      await ref.update({
        notifyPosts:
          req.body?.notifyPosts !==
          false,
        notifyEvents:
          req.body?.notifyEvents !==
          false,
        notifyOpenSlots:
          req.body
            ?.notifyOpenSlots !==
          false,
        notifyBenefits:
          req.body
            ?.notifyBenefits !==
          false,
        updatedAt:
          FieldValue
            .serverTimestamp(),
      });

      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/create-post',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const businessRef =
        db.collection('business_profiles')
          .doc(uid);

      const business =
        await businessRef.get();

      if (!business.exists) {
        throw new ApiError(
          412,
          'business-required',
          'Crie seu perfil comercial.',
        );
      }

      const b =
        business.data() || {};

      if (b.reviewStatus !==
            'approved' ||
          b.status !== 'active') {
        throw new ApiError(
          403,
          'business-not-approved',
          'Seu perfil precisa estar aprovado e ativo.',
        );
      }

      const type =
        optionalString(
          req.body?.type,
          30,
        ) || 'experience';

      if (!BP_POST_TYPES.has(type)) {
        throw new ApiError(
          400,
          'invalid-type',
          'Tipo de publicaÃ§Ã£o invÃ¡lido.',
        );
      }

      const month =
        usageMonthKey();

      const used =
        String(
          b.usageMonth || '',
        ) === month
          ? Math.max(
              Number(
                b.postsUsedThisMonth ||
                0,
              ),
              0,
            )
          : 0;

      const monthlyLimit =
        Math.max(
          Number(
            b.monthlyPostLimit ||
            1,
          ),
          1,
        );

      if (used >= monthlyLimit) {
        throw new ApiError(
          409,
          'monthly-plan-limit',
          'Seu plano atingiu o limite mensal.',
        );
      }

      const active =
        await db
          .collection('discoveries')
          .where(
            'businessId',
            '==',
            uid,
          )
          .where(
            'status',
            '==',
            'published',
          )
          .get();

      if (active.size >=
          Math.max(
            Number(
              b.activePostLimit ||
              1,
            ),
            1,
          )) {
        throw new ApiError(
          409,
          'active-plan-limit',
          'Seu plano atingiu o limite de publicaÃ§Ãµes ativas.',
        );
      }

      const startsAt =
        req.body?.eventStartsAt
          ? parseDate(
              req.body.eventStartsAt,
              'eventStartsAt',
            )
          : null;

      const endsAt =
        req.body?.eventEndsAt
          ? parseDate(
              req.body.eventEndsAt,
              'eventEndsAt',
            )
          : null;

      if (startsAt &&
          endsAt &&
          endsAt <= startsAt) {
        throw new ApiError(
          400,
          'invalid-date',
          'O fim precisa ser depois do inÃ­cio.',
        );
      }

      const minParticipants =
        Math.max(
          0,
          Math.trunc(
            bpNumber(
              req.body
                ?.minParticipants,
              0,
            ),
          ),
        );

      const maxParticipants =
        Math.max(
          0,
          Math.trunc(
            bpNumber(
              req.body
                ?.maxParticipants,
              0,
            ),
          ),
        );

      if ((type === 'open_slots' ||
           type === 'schedule') &&
          (maxParticipants < 2 ||
           minParticipants < 1 ||
           minParticipants >
             maxParticipants)) {
        throw new ApiError(
          400,
          'invalid-capacity',
          'Capacidade invÃ¡lida.',
        );
      }

      const benefitType =
        optionalString(
          req.body?.benefitType,
          40,
        ) || null;

      if (benefitType &&
          !BP_BENEFIT_TYPES
            .has(benefitType)) {
        throw new ApiError(
          400,
          'invalid-benefit',
          'BenefÃ­cio invÃ¡lido.',
        );
      }

      const postRef =
        db.collection('discoveries')
          .doc();

      const post = {
        id: postRef.id,
        businessId: uid,
        businessName:
          String(b.name || ''),
        businessCategory:
          String(b.category || ''),
        businessVerified:
          b.verified === true,
        type,
        title:
          requiredString(
            req.body?.title,
            'title',
            120,
          ),
        description:
          requiredString(
            req.body?.description,
            'description',
            1500,
          ),
        coverUrl:
          requiredString(
            req.body?.coverUrl,
            'coverUrl',
            2048,
          ),
        galleryUrls:
          Array.isArray(
            req.body?.galleryUrls,
          )
            ? req.body.galleryUrls
                .map((v) =>
                  optionalString(
                    v,
                    2048,
                  ))
                .filter(Boolean)
                .slice(0, 6)
            : [],
        address:
          String(b.address || ''),
        latitude:
          Number(b.latitude || 0),
        longitude:
          Number(b.longitude || 0),
        websiteUrl:
          String(
            b.websiteUrl || '',
          ),
        ctaLabel:
          optionalString(
            req.body?.ctaLabel,
            50,
          ) ||
          (type === 'open_slots'
            ? 'Eu vou'
            : 'Criar atividade aqui'),
        officialEvent:
          req.body?.officialEvent ===
            true ||
          type === 'event',
        eventStartsAt:
          startsAt
            ? Timestamp.fromDate(
                startsAt,
              )
            : null,
        eventEndsAt:
          endsAt
            ? Timestamp.fromDate(
                endsAt,
              )
            : null,
        price:
          req.body?.price == null
            ? null
            : bpNumber(
                req.body.price,
                null,
              ),
        juntaiPrice:
          req.body?.juntaiPrice ==
            null
            ? null
            : bpNumber(
                req.body
                  .juntaiPrice,
                null,
              ),
        minParticipants,
        maxParticipants,
        claimedParticipants: 0,
        benefitType,
        benefitValue:
          req.body?.benefitValue ==
            null
            ? null
            : bpNumber(
                req.body
                  .benefitValue,
                null,
              ),
        benefitMinParticipants:
          Math.max(
            0,
            Math.trunc(
              bpNumber(
                req.body
                  ?.benefitMinParticipants,
                0,
              ),
            ),
          ),
        groupBenefit:
          optionalString(
            req.body?.groupBenefit,
            400,
          ),
        benefitUnlocked: false,
        benefitCode: null,
        availabilitySlots:
          Array.isArray(
            req.body
              ?.availabilitySlots,
          )
            ? req.body
                .availabilitySlots
                .slice(0, 20)
                .map((slot) => ({
                  label:
                    optionalString(
                      slot?.label,
                      40,
                    ),
                  capacity:
                    Math.max(
                      1,
                      Math.trunc(
                        bpNumber(
                          slot?.capacity,
                          maxParticipants ||
                            1,
                        ),
                      ),
                    ),
                  claimed: 0,
                }))
                .filter(
                  (slot) =>
                    slot.label,
                )
            : [],
        sponsored: false,
        sponsoredUntil: null,
        sponsoredCity: null,
        status: 'published',
        views: 0,
        opens: 0,
        profileVisits: 0,
        wantToGoClicks: 0,
        interestedCount: 0,
        shareCount: 0,
        activitiesCreated: 0,
        groupsCreated: 0,
        participantsGenerated: 0,
        couponUnlocks: 0,
        couponValidations: 0,
        slotsFilled: 0,
        createdAt:
          FieldValue
            .serverTimestamp(),
        updatedAt:
          FieldValue
            .serverTimestamp(),
      };

      await db.runTransaction(
        async (transaction) => {
          transaction.set(
            postRef,
            post,
          );

          transaction.update(
            businessRef,
            {
              postsUsedThisMonth:
                used + 1,
              usageMonth: month,
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
          );
        },
      );

      await bpNotifyFollowers(
        uid,
        post,
      ).catch(console.error);

      res.json({
        ok: true,
        postId: postRef.id,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/update-post',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const postId =
        requiredString(
          req.body?.postId,
          'postId',
          200,
        );

      const ref =
        db.collection('discoveries')
          .doc(postId);

      const snapshot =
        await ref.get();

      if (!snapshot.exists) {
        throw new ApiError(
          404,
          'not-found',
          'PublicaÃ§Ã£o nÃ£o encontrada.',
        );
      }

      const current =
        snapshot.data() || {};

      if (String(
            current.businessId ||
            '',
          ) !== uid) {
        throw new ApiError(
          403,
          'permission-denied',
          'Sem permissÃ£o.',
        );
      }

      const startsAt =
        req.body?.eventStartsAt
          ? parseDate(
              req.body.eventStartsAt,
              'eventStartsAt',
            )
          : null;

      const endsAt =
        req.body?.eventEndsAt
          ? parseDate(
              req.body.eventEndsAt,
              'eventEndsAt',
            )
          : null;

      await ref.update({
        title:
          requiredString(
            req.body?.title,
            'title',
            120,
          ),
        description:
          requiredString(
            req.body?.description,
            'description',
            1500,
          ),
        coverUrl:
          requiredString(
            req.body?.coverUrl,
            'coverUrl',
            2048,
          ),
        galleryUrls:
          Array.isArray(
            req.body?.galleryUrls,
          )
            ? req.body.galleryUrls
                .map((v) =>
                  optionalString(
                    v,
                    2048,
                  ))
                .filter(Boolean)
                .slice(0, 6)
            : current.galleryUrls ||
              [],
        ctaLabel:
          optionalString(
            req.body?.ctaLabel,
            50,
          ) ||
          current.ctaLabel,
        officialEvent:
          req.body?.officialEvent ===
            true ||
          current.type === 'event',
        eventStartsAt:
          startsAt
            ? Timestamp.fromDate(
                startsAt,
              )
            : current.eventStartsAt ||
              null,
        eventEndsAt:
          endsAt
            ? Timestamp.fromDate(
                endsAt,
              )
            : current.eventEndsAt ||
              null,
        price:
          req.body?.price == null
            ? null
            : bpNumber(
                req.body.price,
                null,
              ),
        juntaiPrice:
          req.body?.juntaiPrice ==
            null
            ? null
            : bpNumber(
                req.body
                  .juntaiPrice,
                null,
              ),
        minParticipants:
          Math.max(
            0,
            Math.trunc(
              bpNumber(
                req.body
                  ?.minParticipants,
                current
                  .minParticipants ||
                  0,
              ),
            ),
          ),
        maxParticipants:
          Math.max(
            0,
            Math.trunc(
              bpNumber(
                req.body
                  ?.maxParticipants,
                current
                  .maxParticipants ||
                  0,
              ),
            ),
          ),
        benefitType:
          optionalString(
            req.body?.benefitType,
            40,
          ) || null,
        benefitValue:
          req.body?.benefitValue ==
            null
            ? null
            : bpNumber(
                req.body
                  .benefitValue,
                null,
              ),
        benefitMinParticipants:
          Math.max(
            0,
            Math.trunc(
              bpNumber(
                req.body
                  ?.benefitMinParticipants,
                current
                  .benefitMinParticipants ||
                  0,
              ),
            ),
          ),
        groupBenefit:
          optionalString(
            req.body?.groupBenefit,
            400,
          ),
        availabilitySlots:
          Array.isArray(
            req.body
              ?.availabilitySlots,
          )
            ? req.body
                .availabilitySlots
                .slice(0, 20)
                .map((slot) => ({
                  label:
                    optionalString(
                      slot?.label,
                      40,
                    ),
                  capacity:
                    Math.max(
                      1,
                      Math.trunc(
                        bpNumber(
                          slot?.capacity,
                          1,
                        ),
                      ),
                    ),
                  claimed:
                    Math.max(
                      0,
                      Math.trunc(
                        bpNumber(
                          slot?.claimed,
                          0,
                        ),
                      ),
                    ),
                }))
                .filter(
                  (slot) =>
                    slot.label,
                )
            : current
                .availabilitySlots ||
              [],
        updatedAt:
          FieldValue
            .serverTimestamp(),
      });

      res.json({
        ok: true,
        postId,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/archive-post',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const postId =
        requiredString(
          req.body?.postId,
          'postId',
          200,
        );

      const ref =
        db.collection('discoveries')
          .doc(postId);

      const snapshot =
        await ref.get();

      if (!snapshot.exists) {
        throw new ApiError(
          404,
          'not-found',
          'PublicaÃ§Ã£o nÃ£o encontrada.',
        );
      }

      if (String(
            snapshot.data()
              ?.businessId ||
            '',
          ) !== uid) {
        throw new ApiError(
          403,
          'permission-denied',
          'Sem permissÃ£o.',
        );
      }

      await ref.update({
        status: 'archived',
        updatedAt:
          FieldValue
            .serverTimestamp(),
      });

      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/business-metric',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const postId =
        requiredString(
          req.body?.postId,
          'postId',
          200,
        );

      const event =
        requiredString(
          req.body?.event,
          'event',
          40,
        );

      const mapping = {
        impression: 'views',
        open: 'opens',
        share: 'shareCount',
        wantToGo:
          'wantToGoClicks',
      };

      const field =
        mapping[event];

      if (!field) {
        throw new ApiError(
          400,
          'invalid-event',
          'MÃ©trica invÃ¡lida.',
        );
      }

      const ref =
        db.collection('discoveries')
          .doc(postId);

      const snapshot =
        await ref.get();

      if (!snapshot.exists) {
        throw new ApiError(
          404,
          'not-found',
          'PublicaÃ§Ã£o nÃ£o encontrada.',
        );
      }

      const post =
        snapshot.data() || {};

      let counted = true;

      if (event === 'impression' ||
          event === 'open') {
        const marker =
          ref.collection('metric_users')
            .doc(
              `${uid}_${event}`,
            );

        await db.runTransaction(
          async (transaction) => {
            const current =
              await transaction
                .get(marker);

            if (current.exists) {
              counted = false;
              return;
            }

            transaction.set(
              marker,
              {
                userId: uid,
                event,
                createdAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            transaction.update(
              ref,
              {
                [field]:
                  FieldValue
                    .increment(1),
              },
            );
          },
        );
      } else {
        await ref.update({
          [field]:
            FieldValue.increment(1),
        });
      }

      if (counted) {
        await bpMetric(
          String(
            post.businessId ||
            '',
          ),
          event === 'impression'
            ? 'impressions'
            : field,
          1,
        );
      }

      res.json({
        ok: true,
        counted,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/business-profile-visit',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const businessId =
        requiredString(
          req.body?.businessId,
          'businessId',
          200,
        );

      const ref =
        db.collection('business_profiles')
          .doc(businessId);

      const marker =
        ref.collection(
          'profile_visit_users',
        ).doc(uid);

      let counted = false;

      await db.runTransaction(
        async (transaction) => {
          const business =
            await transaction
              .get(ref);

          if (!business.exists) {
            throw new ApiError(
              404,
              'not-found',
              'ComÃ©rcio nÃ£o encontrado.',
            );
          }

          const visit =
            await transaction
              .get(marker);

          if (visit.exists) {
            return;
          }

          transaction.set(
            marker,
            {
              userId: uid,
              createdAt:
                FieldValue
                  .serverTimestamp(),
            },
          );

          transaction.update(
            ref,
            {
              profileVisits:
                FieldValue
                  .increment(1),
            },
          );

          counted = true;
        },
      );

      if (counted) {
        await bpMetric(
          businessId,
          'profileVisits',
          1,
        );
      }

      res.json({
        ok: true,
        counted,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/set-interested',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const postId =
        requiredString(
          req.body?.postId,
          'postId',
          200,
        );

      const interested =
        req.body?.interested === true;

      const ref =
        db.collection('discoveries')
          .doc(postId);

      const interestRef =
        ref.collection('interested')
          .doc(uid);

      let changed = false;
      let businessId = '';

      await db.runTransaction(
        async (transaction) => {
          const post =
            await transaction
              .get(ref);

          if (!post.exists) {
            throw new ApiError(
              404,
              'not-found',
              'PublicaÃ§Ã£o nÃ£o encontrada.',
            );
          }

          businessId =
            String(
              post.data()
                ?.businessId ||
              '',
            );

          const current =
            await transaction
              .get(interestRef);

          if (interested &&
              !current.exists) {
            transaction.set(
              interestRef,
              {
                userId: uid,
                createdAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            transaction.update(
              ref,
              {
                interestedCount:
                  FieldValue
                    .increment(1),
                wantToGoClicks:
                  FieldValue
                    .increment(1),
              },
            );

            changed = true;
          }

          if (!interested &&
              current.exists) {
            transaction.delete(
              interestRef,
            );

            transaction.update(
              ref,
              {
                interestedCount:
                  FieldValue
                    .increment(-1),
              },
            );

            changed = true;
          }
        },
      );

      if (changed &&
          interested) {
        await bpMetric(
          businessId,
          'wantToGoClicks',
          1,
        );
      }

      res.json({
        ok: true,
        interested,
        changed,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/claim-open-slot',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const postId =
        requiredString(
          req.body?.postId,
          'postId',
          200,
        );

      const slotLabel =
        optionalString(
          req.body?.slotLabel,
          40,
        );

      const ref =
        db.collection('discoveries')
          .doc(postId);

      const claimId =
        slotLabel
          ? `${uid}_${Buffer
              .from(slotLabel)
              .toString('base64url')}`
          : uid;

      const claimRef =
        ref.collection('claims')
          .doc(claimId);

      let businessId = '';
      let becameFull = false;

      await db.runTransaction(
        async (transaction) => {
          const postSnapshot =
            await transaction
              .get(ref);

          if (!postSnapshot.exists) {
            throw new ApiError(
              404,
              'not-found',
              'PublicaÃ§Ã£o nÃ£o encontrada.',
            );
          }

          const existing =
            await transaction
              .get(claimRef);

          if (existing.exists) {
            throw new ApiError(
              409,
              'already-claimed',
              'Sua vaga jÃ¡ estÃ¡ confirmada.',
            );
          }

          const post =
            postSnapshot.data() ||
            {};

          businessId =
            String(
              post.businessId ||
              '',
            );

          if (![
            'open_slots',
            'schedule',
          ].includes(post.type)) {
            throw new ApiError(
              412,
              'not-open-slots',
              'Esta publicaÃ§Ã£o nÃ£o possui vagas.',
            );
          }

          let claimedParticipants =
            Math.max(
              Number(
                post.claimedParticipants ||
                0,
              ),
              0,
            );

          const maxParticipants =
            Math.max(
              Number(
                post.maxParticipants ||
                0,
              ),
              0,
            );

          let availabilitySlots =
            Array.isArray(
              post.availabilitySlots,
            )
              ? post.availabilitySlots
                  .map((v) => ({
                    ...v,
                  }))
              : [];

          if (post.type ===
              'schedule') {
            if (!slotLabel) {
              throw new ApiError(
                400,
                'slot-required',
                'Escolha um horÃ¡rio.',
              );
            }

            const index =
              availabilitySlots
                .findIndex(
                  (s) =>
                    String(s.label) ===
                    slotLabel,
                );

            if (index < 0) {
              throw new ApiError(
                404,
                'slot-not-found',
                'HorÃ¡rio nÃ£o encontrado.',
              );
            }

            const capacity =
              Math.max(
                Number(
                  availabilitySlots[
                    index
                  ].capacity || 0,
                ),
                0,
              );

            const claimed =
              Math.max(
                Number(
                  availabilitySlots[
                    index
                  ].claimed || 0,
                ),
                0,
              );

            if (capacity > 0 &&
                claimed >= capacity) {
              throw new ApiError(
                409,
                'slot-full',
                'HorÃ¡rio lotado.',
              );
            }

            availabilitySlots[
              index
            ].claimed =
              claimed + 1;

            if (capacity > 0 &&
                claimed + 1 >=
                  capacity) {
              becameFull = true;
            }

            claimedParticipants +=
              1;
          } else {
            if (maxParticipants <=
                  0 ||
                claimedParticipants >=
                  maxParticipants) {
              throw new ApiError(
                409,
                'post-full',
                'Grupo completo.',
              );
            }

            claimedParticipants +=
              1;

            if (claimedParticipants >=
                maxParticipants) {
              becameFull = true;
            }
          }

          transaction.set(
            claimRef,
            {
              userId: uid,
              slotLabel:
                slotLabel || null,
              createdAt:
                FieldValue
                  .serverTimestamp(),
            },
          );

          transaction.update(
            ref,
            {
              claimedParticipants,
              availabilitySlots,
              wantToGoClicks:
                FieldValue
                  .increment(1),
              ...(becameFull
                ? {
                    slotsFilled:
                      FieldValue
                        .increment(1),
                  }
                : {}),
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
          );
        },
      );

      const latest =
        await ref.get();

      const post =
        latest.data() || {};

      const threshold =
        Math.max(
          Number(
            post.benefitMinParticipants ||
            0,
          ),
          0,
        );

      const claimed =
        Math.max(
          Number(
            post.claimedParticipants ||
            0,
          ),
          0,
        );

      let unlockedCode = null;

      if (threshold > 0 &&
          claimed >= threshold &&
          post.benefitType &&
          !post.benefitUnlocked) {
        const claims =
          await ref
            .collection('claims')
            .get();

        const participantIds =
          [...new Set(
            claims.docs
              .map((doc) =>
                String(
                  doc.data()
                    .userId || '',
                ))
              .filter(Boolean),
          )];

        const code =
          await bpCreateBenefit({
            businessId,
            postId,
            benefitType:
              post.benefitType,
            benefitValue:
              post.benefitValue,
            benefitLabel:
              post.groupBenefit,
            participants:
              participantIds,
          });

        await ref.update({
          benefitUnlocked: true,
          benefitCode: code,
          couponUnlocks:
            FieldValue
              .increment(1),
        });

        unlockedCode = code;

        await Promise.allSettled(
          participantIds.map(
            (participantUid) =>
              notify(
                participantUid,
                {
                  type:
                    'group_discount_unlocked',
                  title:
                    'BenefÃ­cio desbloqueado ðŸŽ',
                  body:
                    String(
                      post.groupBenefit ||
                      'Seu grupo desbloqueou um benefÃ­cio.',
                    ),
                  route:
                    `/benefit/${code}`,
                },
              ),
          ),
        );
      }

      await bpMetric(
        businessId,
        'wantToGoClicks',
        1,
      );

      if (becameFull) {
        await bpMetric(
          businessId,
          'slotsFilled',
          1,
        );
      }

      res.json({
        ok: true,
        benefitCode:
          unlockedCode,
        full: becameFull,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/benefit-status',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const code =
        requiredString(
          req.body?.code,
          'code',
          40,
        ).toUpperCase();

      const snapshot =
        await db
          .collection('benefit_codes')
          .doc(code)
          .get();

      if (!snapshot.exists) {
        throw new ApiError(
          404,
          'invalid-code',
          'CÃ³digo nÃ£o encontrado.',
        );
      }

      const data =
        snapshot.data() || {};

      const business =
        await db
          .collection(
            'business_profiles',
          )
          .doc(
            String(
              data.businessId ||
              '',
            ),
          )
          .get();

      const participantIds =
        Array.isArray(
          data.participantIds,
        )
          ? data.participantIds
              .map(String)
          : [];

      const ownerUid =
        business.data()
          ?.ownerUid ||
        business.data()
          ?.ownerId ||
        '';

      const canRedeem =
        business.exists &&
        String(ownerUid) === uid;

      const canView =
        canRedeem ||
        participantIds
          .includes(uid);

      if (!canView) {
        throw new ApiError(
          403,
          'permission-denied',
          'VocÃª nÃ£o pode acessar este benefÃ­cio.',
        );
      }

      res.json({
        ok: true,
        code,
        status: data.status,
        benefitType:
          data.benefitType,
        benefitValue:
          data.benefitValue,
        benefitLabel:
          data.benefitLabel,
        participantCount:
          data.participantCount,
        canRedeem,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/redeem-benefit',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const code =
        requiredString(
          req.body?.code,
          'code',
          40,
        ).toUpperCase();

      const ref =
        db.collection('benefit_codes')
          .doc(code);

      let businessId = '';

      await db.runTransaction(
        async (transaction) => {
          const benefit =
            await transaction
              .get(ref);

          if (!benefit.exists) {
            throw new ApiError(
              404,
              'invalid-code',
              'CÃ³digo nÃ£o encontrado.',
            );
          }

          const data =
            benefit.data() || {};

          businessId =
            String(
              data.businessId ||
              '',
            );

          const businessRef =
            db.collection(
              'business_profiles',
            ).doc(businessId);

          const business =
            await transaction
              .get(businessRef);

          const ownerUid =
            business.data()
              ?.ownerUid ||
            business.data()
              ?.ownerId ||
            '';

          if (!business.exists ||
              String(ownerUid) !==
                uid) {
            throw new ApiError(
              403,
              'permission-denied',
              'Somente o comÃ©rcio pode validar este cÃ³digo.',
            );
          }

          if (data.status ===
              'redeemed') {
            throw new ApiError(
              409,
              'already-redeemed',
              'Este cÃ³digo jÃ¡ foi utilizado.',
            );
          }

          transaction.update(
            ref,
            {
              status: 'redeemed',
              redeemedAt:
                FieldValue
                  .serverTimestamp(),
              redeemedByBusinessId:
                businessId,
            },
          );

          if (data.postId) {
            transaction.update(
              db.collection(
                'discoveries',
              ).doc(
                String(
                  data.postId,
                ),
              ),
              {
                couponValidations:
                  FieldValue
                    .increment(1),
              },
            );
          }
        },
      );

      await bpMetric(
        businessId,
        'couponValidations',
        1,
      );

      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/register-discovery-activity',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const discoveryId =
        requiredString(
          req.body?.discoveryId,
          'discoveryId',
          200,
        );

      const activityId =
        requiredString(
          req.body?.activityId,
          'activityId',
          200,
        );

      const discoveryRef =
        db.collection('discoveries')
          .doc(discoveryId);

      const activityRef =
        db.collection('activities')
          .doc(activityId);

      const markerRef =
        discoveryRef
          .collection('activity_links')
          .doc(activityId);

      let counted = false;
      let businessId = '';

      await db.runTransaction(
        async (transaction) => {
          const discovery =
            await transaction
              .get(discoveryRef);

          const activity =
            await transaction
              .get(activityRef);

          if (!discovery.exists ||
              !activity.exists) {
            throw new ApiError(
              404,
              'not-found',
              'Descoberta ou atividade nÃ£o encontrada.',
            );
          }

          const ad =
            activity.data() || {};

          if (String(
                ad.creatorId ||
                '',
              ) !== uid ||
              String(
                ad.sourceDiscoveryId ||
                '',
              ) !== discoveryId) {
            throw new ApiError(
              403,
              'invalid-source',
              'VÃ­nculo de atividade invÃ¡lido.',
            );
          }

          businessId =
            String(
              discovery.data()
                ?.businessId ||
              '',
            );

          const marker =
            await transaction
              .get(markerRef);

          if (marker.exists) {
            return;
          }

          transaction.set(
            markerRef,
            {
              activityId,
              creatorId: uid,
              createdAt:
                FieldValue
                  .serverTimestamp(),
            },
          );

          transaction.update(
            discoveryRef,
            {
              activitiesCreated:
                FieldValue
                  .increment(1),
              groupsCreated:
                FieldValue
                  .increment(1),
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
          );

          counted = true;
        },
      );

      if (counted) {
        await bpMetric(
          businessId,
          'groupsCreated',
          1,
        );
      }

      res.json({
        ok: true,
        counted,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/record-discovery-participant',
  authenticate,
  async (req, res, next) => {
    try {
      const actorUid =
        req.user.uid;

      const activityId =
        requiredString(
          req.body?.activityId,
          'activityId',
          200,
        );

      const participantUid =
        optionalString(
          req.body?.userId,
          200,
        ) || actorUid;

      const activityRef =
        db.collection('activities')
          .doc(activityId);

      const activity =
        await activityRef.get();

      if (!activity.exists) {
        throw new ApiError(
          404,
          'not-found',
          'Atividade nÃ£o encontrada.',
        );
      }

      const ad =
        activity.data() || {};

      if (participantUid !==
            actorUid &&
          String(
            ad.creatorId ||
            '',
          ) !== actorUid) {
        throw new ApiError(
          403,
          'permission-denied',
          'Sem permissÃ£o.',
        );
      }

      const participant =
        await activityRef
          .collection('participants')
          .doc(participantUid)
          .get();

      if (!participant.exists) {
        throw new ApiError(
          412,
          'not-participant',
          'UsuÃ¡rio nÃ£o participa.',
        );
      }

      const discoveryId =
        String(
          ad.sourceDiscoveryId ||
          '',
        );

      if (!discoveryId) {
        return res.json({
          ok: true,
          counted: false,
        });
      }

      const discoveryRef =
        db.collection('discoveries')
          .doc(discoveryId);

      const markerRef =
        discoveryRef
          .collection(
            'participant_users',
          )
          .doc(participantUid);

      let counted = false;
      let businessId = '';

      await db.runTransaction(
        async (transaction) => {
          const discovery =
            await transaction
              .get(discoveryRef);

          if (!discovery.exists) {
            return;
          }

          const marker =
            await transaction
              .get(markerRef);

          if (marker.exists) {
            return;
          }

          businessId =
            String(
              discovery.data()
                ?.businessId ||
              '',
            );

          transaction.set(
            markerRef,
            {
              userId:
                participantUid,
              firstActivityId:
                activityId,
              createdAt:
                FieldValue
                  .serverTimestamp(),
            },
          );

          transaction.update(
            discoveryRef,
            {
              participantsGenerated:
                FieldValue
                  .increment(1),
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
          );

          counted = true;
        },
      );

      if (counted) {
        await bpMetric(
          businessId,
          'participantsGenerated',
          1,
        );
      }

      res.json({
        ok: true,
        counted,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/business-dashboard',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const business =
        await db
          .collection(
            'business_profiles',
          )
          .doc(uid)
          .get();

      if (!business.exists) {
        throw new ApiError(
          404,
          'not-found',
          'Perfil comercial nÃ£o encontrado.',
        );
      }

      const week = {};

      for (
        let offset = 0;
        offset < 7;
        offset += 1
      ) {
        const date = new Date();

        date.setUTCDate(
          date.getUTCDate() -
          offset,
        );

        const daily =
          await business.ref
            .collection(
              'metrics_daily',
            )
            .doc(bpDayKey(date))
            .get();

        if (!daily.exists) {
          continue;
        }

        const data =
          daily.data() || {};

        Object.entries(data)
          .forEach(
            ([key, value]) => {
              if (typeof value ===
                  'number') {
                week[key] =
                  Number(
                    week[key] || 0,
                  ) + value;
              }
            },
          );
      }

      res.json({
        ok: true,
        week,
        business:
          business.data(),
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/checkout-plan',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const plan =
        requiredString(
          req.body?.plan,
          'plan',
          20,
        ).toLowerCase();

      const spec =
        BP_PLANS[plan];

      if (!spec ||
          plan === 'free') {
        throw new ApiError(
          400,
          'invalid-plan',
          'Plano invÃ¡lido.',
        );
      }

      const checkoutUrl =
        await bpPayment({
          title:
            `JuntaÃ­ ${plan.toUpperCase()} - mensal`,
          price:
            spec.price,
          externalReference:
            `plan|${uid}|${plan}|${Date.now()}`,
        });

      res.json({
        ok: true,
        checkoutUrl,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/sponsor-post',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const postId =
        requiredString(
          req.body?.postId,
          'postId',
          200,
        );

      const packageId =
        requiredString(
          req.body?.package,
          'package',
          20,
        );

      const prices = {
        '24h': 9.90,
        '3d': 19.90,
        city3d: 39.90,
      };

      if (!prices[packageId]) {
        throw new ApiError(
          400,
          'invalid-package',
          'Pacote invÃ¡lido.',
        );
      }

      const post =
        await db
          .collection('discoveries')
          .doc(postId)
          .get();

      if (!post.exists ||
          String(
            post.data()
              ?.businessId ||
            '',
          ) !== uid) {
        throw new ApiError(
          403,
          'permission-denied',
          'PublicaÃ§Ã£o invÃ¡lida.',
        );
      }

      const city =
        optionalString(
          req.body?.city,
          100,
        );

      if (packageId ===
            'city3d' &&
          !city) {
        throw new ApiError(
          400,
          'city-required',
          'Informe a cidade da campanha.',
        );
      }

      const checkoutUrl =
        await bpPayment({
          title:
            `Destaque JuntaÃ­ ${packageId}`,
          price:
            prices[packageId],
          externalReference:
            `campaign|${uid}|${postId}|${packageId}|${encodeURIComponent(city)}|${Date.now()}`,
        });

      res.json({
        ok: true,
        checkoutUrl,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/mercadopago/webhook',
  async (req, res, next) => {
    try {
      const token =
        String(
          process.env
            .MERCADO_PAGO_ACCESS_TOKEN ||
          '',
        ).trim();

      if (!token) {
        return res
          .status(204)
          .end();
      }

      const paymentId =
        String(
          req.query?.['data.id'] ||
          req.body?.data?.id ||
          req.body?.id ||
          '',
        ).trim();

      if (!paymentId) {
        return res
          .status(204)
          .end();
      }

      const response =
        await fetch(
          `https://api.mercadopago.com/v1/payments/${encodeURIComponent(paymentId)}`,
          {
            headers: {
              Authorization:
                `Bearer ${token}`,
            },
          },
        );

      const payment =
        await response
          .json()
          .catch(() => ({}));

      if (!response.ok ||
          payment.status !==
            'approved') {
        return res
          .status(204)
          .end();
      }

      const external =
        String(
          payment
            .external_reference ||
          '',
        );

      const parts =
        external.split('|');

      if (parts[0] ===
            'plan' &&
          parts.length >= 3) {
        const uid =
          parts[1];

        const plan =
          parts[2];

        const spec =
          BP_PLANS[plan];

        if (spec) {
          const now =
            new Date();

          const end =
            new Date(now);

          end.setUTCMonth(
            end.getUTCMonth() +
            1,
          );

          await db
            .collection(
              'business_profiles',
            )
            .doc(uid)
            .set(
              {
                plan,
                monthlyPostLimit:
                  spec
                    .monthlyPostLimit,
                activePostLimit:
                  spec
                    .activePostLimit,
                billingPeriodStart:
                  Timestamp
                    .fromDate(now),
                billingPeriodEnd:
                  Timestamp
                    .fromDate(end),
                paymentProvider:
                  'mercadopago',
                lastPaymentId:
                  paymentId,
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
              { merge: true },
            );
        }
      }

      if (parts[0] ===
            'campaign' &&
          parts.length >= 5) {
        const uid =
          parts[1];

        const postId =
          parts[2];

        const packageId =
          parts[3];

        const city =
          decodeURIComponent(
            parts[4] || '',
          );

        const hours =
          packageId === '24h'
            ? 24
            : 72;

        const until =
          new Date(
            Date.now() +
            hours *
            60 *
            60 *
            1000,
          );

        await db
          .collection('campaigns')
          .doc(paymentId)
          .set(
            {
              campaignId:
                paymentId,
              businessId: uid,
              postId,
              package:
                packageId,
              city:
                city || null,
              status: 'active',
              startsAt:
                FieldValue
                  .serverTimestamp(),
              endsAt:
                Timestamp
                  .fromDate(until),
              paymentId,
              createdAt:
                FieldValue
                  .serverTimestamp(),
            },
            { merge: true },
          );

        await db
          .collection('discoveries')
          .doc(postId)
          .update({
            sponsored: true,
            sponsoredUntil:
              Timestamp
                .fromDate(until),
            sponsoredCity:
              city || null,
            updatedAt:
              FieldValue
                .serverTimestamp(),
          });
      }

      res
        .status(204)
        .end();
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/report-content',
  authenticate,
  async (req, res, next) => {
    try {
      const uid = req.user.uid;

      const targetType =
        requiredString(
          req.body?.targetType,
          'targetType',
          40,
        );

      const targetId =
        requiredString(
          req.body?.targetId,
          'targetId',
          400,
        );

      const reason =
        requiredString(
          req.body?.reason,
          'reason',
          120,
        );

      const details =
        optionalString(
          req.body?.details,
          1200,
        );

      if (!BP_REPORT_TYPES
          .has(targetType)) {
        throw new ApiError(
          400,
          'invalid-report-type',
          'Tipo de denÃºncia invÃ¡lido.',
        );
      }

      await db
        .collection('reports')
        .add({
          reporterId: uid,
          targetType,
          targetId,
          reason,
          details,
          status: 'open',
          createdAt:
            FieldValue
              .serverTimestamp(),
          updatedAt:
            FieldValue
              .serverTimestamp(),
        });

      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/admin/bootstrap',
  authenticate,
  async (req, res, next) => {
    try {
      const allowed =
        String(
          process.env
            .ADMIN_EMAILS ||
          '',
        )
          .split(',')
          .map((v) =>
            v.trim()
              .toLowerCase())
          .filter(Boolean);

      const email =
        String(
          req.user.email ||
          '',
        ).toLowerCase();

      if (!allowed
          .includes(email)) {
        throw new ApiError(
          403,
          'admin-required',
          'E-mail nÃ£o autorizado.',
        );
      }

      await admin.auth()
        .setCustomUserClaims(
          req.user.uid,
          { admin: true },
        );

      res.json({
        ok: true,
        refreshToken: true,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/admin/overview',
  authenticate,
  bpAdmin,
  async (_req, res, next) => {
    try {
      const [
        businesses,
        reports,
        campaigns,
      ] = await Promise.all([
        db.collection(
          'business_profiles',
        )
          .limit(300)
          .get(),

        db.collection('reports')
          .limit(300)
          .get(),

        db.collection('campaigns')
          .limit(300)
          .get(),
      ]);

      res.json({
        ok: true,
        businesses:
          businesses.docs.map(
            (doc) => ({
              id: doc.id,
              ...doc.data(),
            }),
          ),
        reports:
          reports.docs.map(
            (doc) => ({
              id: doc.id,
              ...doc.data(),
            }),
          ),
        campaigns:
          campaigns.docs.map(
            (doc) => ({
              id: doc.id,
              ...doc.data(),
            }),
          ),
      });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/admin/business-review',
  authenticate,
  bpAdmin,
  async (req, res, next) => {
    try {
      const businessId =
        requiredString(
          req.body?.businessId,
          'businessId',
          200,
        );

      const action =
        requiredString(
          req.body?.action,
          'action',
          30,
        );

      const allowed =
        new Set([
          'approve',
          'reject',
          'suspend',
          'activate',
          'verify',
          'unverify',
        ]);

      if (!allowed.has(action)) {
        throw new ApiError(
          400,
          'invalid-action',
          'AÃ§Ã£o invÃ¡lida.',
        );
      }

      const update = {
        updatedAt:
          FieldValue
            .serverTimestamp(),
      };

      if (action === 'approve') {
        update.reviewStatus =
          'approved';
      }

      if (action === 'reject') {
        update.reviewStatus =
          'rejected';
      }

      if (action === 'suspend') {
        update.status =
          'suspended';
      }

      if (action === 'activate') {
        update.status =
          'active';
      }

      if (action === 'verify') {
        update.verified = true;
      }

      if (action === 'unverify') {
        update.verified = false;
      }

      await db
        .collection(
          'business_profiles',
        )
        .doc(businessId)
        .update(update);

      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/admin/set-plan',
  authenticate,
  bpAdmin,
  async (req, res, next) => {
    try {
      const businessId =
        requiredString(
          req.body?.businessId,
          'businessId',
          200,
        );

      const plan =
        requiredString(
          req.body?.plan,
          'plan',
          20,
        ).toLowerCase();

      const spec =
        BP_PLANS[plan];

      if (!spec) {
        throw new ApiError(
          400,
          'invalid-plan',
          'Plano invÃ¡lido.',
        );
      }

      await db
        .collection(
          'business_profiles',
        )
        .doc(businessId)
        .update({
          plan,
          monthlyPostLimit:
            spec.monthlyPostLimit,
          activePostLimit:
            spec.activePostLimit,
          updatedAt:
            FieldValue
              .serverTimestamp(),
        });

      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/admin/report-status',
  authenticate,
  bpAdmin,
  async (req, res, next) => {
    try {
      const reportId =
        requiredString(
          req.body?.reportId,
          'reportId',
          200,
        );

      const status =
        requiredString(
          req.body?.status,
          'status',
          30,
        );

      if (![
        'open',
        'reviewing',
        'resolved',
        'dismissed',
      ].includes(status)) {
        throw new ApiError(
          400,
          'invalid-status',
          'Status invÃ¡lido.',
        );
      }

      await db
        .collection('reports')
        .doc(reportId)
        .update({
          status,
          reviewedBy:
            req.user.uid,
          updatedAt:
            FieldValue
              .serverTimestamp(),
        });

      res.json({ ok: true });
    } catch (error) {
      next(error);
    }
  },
);

app.post(
  '/blueprint/cron/reminders',
  async (req, res, next) => {
    try {
      const secret =
        String(
          process.env
            .CRON_SECRET ||
          '',
        );

      if (!secret ||
          String(
            req.headers[
              'x-cron-secret'
            ] || '',
          ) !== secret) {
        throw new ApiError(
          401,
          'invalid-cron-secret',
          'NÃ£o autorizado.',
        );
      }

      const now =
        new Date();

      const inTwoHours =
        new Date(
          now.getTime() +
          2 *
          60 *
          60 *
          1000,
        );

      const activities =
        await db
          .collection('activities')
          .where(
            'status',
            '==',
            'active',
          )
          .get();

      let reminders = 0;
      let benefits = 0;

      for (
        const activityDoc
        of activities.docs
      ) {
        const activity =
          activityDoc.data() ||
          {};

        const startsAt =
          activity.startsAt
            ?.toDate?.();

        if (startsAt &&
            startsAt > now &&
            startsAt <=
              inTwoHours &&
            !activity
              .reminder2hSentAt) {
          const participants =
            await activityDoc.ref
              .collection(
                'participants',
              )
              .get();

          await Promise.allSettled(
            participants.docs.map(
              (participant) =>
                notify(
                  participant.id,
                  {
                    type:
                      'event_reminder',
                    title:
                      'Sua atividade comeÃ§a em breve',
                    body:
                      String(
                        activity.title ||
                        'Atividade',
                      ),
                    activityId:
                      activityDoc.id,
                    route:
                      `/activity/${activityDoc.id}`,
                  },
                ),
            ),
          );

          await activityDoc.ref
            .update({
              reminder2hSentAt:
                FieldValue
                  .serverTimestamp(),
            });

          reminders += 1;
        }

        const discoveryId =
          String(
            activity
              .sourceDiscoveryId ||
            '',
          );

        if (discoveryId &&
            !activity.benefitCode) {
          const discovery =
            await db
              .collection(
                'discoveries',
              )
              .doc(discoveryId)
              .get();

          const d =
            discovery.data() ||
            {};

          const threshold =
            Math.max(
              Number(
                d.benefitMinParticipants ||
                0,
              ),
              0,
            );

          const count =
            Math.max(
              Number(
                activity.participantCount ||
                0,
              ),
              0,
            );

          if (threshold > 0 &&
              count >= threshold &&
              d.benefitType) {
            const participants =
              await activityDoc.ref
                .collection(
                  'participants',
                )
                .get();

            const ids =
              participants.docs
                .map((p) => p.id);

            const code =
              await bpCreateBenefit({
                businessId:
                  String(
                    d.businessId ||
                    '',
                  ),
                postId:
                  discoveryId,
                activityId:
                  activityDoc.id,
                benefitType:
                  d.benefitType,
                benefitValue:
                  d.benefitValue,
                benefitLabel:
                  d.groupBenefit,
                participants:
                  ids,
              });

            await activityDoc.ref
              .update({
                benefitCode:
                  code,
                benefitUnlockedAt:
                  FieldValue
                    .serverTimestamp(),
              });

            await Promise.allSettled(
              ids.map(
                (participantUid) =>
                  notify(
                    participantUid,
                    {
                      type:
                        'group_discount_unlocked',
                      title:
                        'BenefÃ­cio desbloqueado ðŸŽ',
                      body:
                        String(
                          d.groupBenefit ||
                          'Seu grupo desbloqueou um benefÃ­cio.',
                        ),
                      activityId:
                        activityDoc.id,
                      route:
                        `/benefit/${code}`,
                    },
                  ),
              ),
            );

            benefits += 1;
          }
        }
      }

      res.json({
        ok: true,
        reminders,
        benefits,
      });
    } catch (error) {
      next(error);
    }
  },
);

app.get(
  '/business/:id',
  async (req, res, next) => {
    try {
      const id =
        requiredString(
          req.params.id,
          'id',
          200,
        );

      const business =
        await db
          .collection(
            'business_profiles',
          )
          .doc(id)
          .get();

      if (!business.exists) {
        throw new ApiError(
          404,
          'not-found',
          'ComÃ©rcio nÃ£o encontrado.',
        );
      }

      const d =
        business.data() || {};

      const title =
        escapeHtml(
          d.name || 'JuntaÃ­',
        );

      const text =
        escapeHtml(
          d.description ||
          d.category ||
          '',
        );

      res.type('html')
        .send(
          `<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} â€¢ JuntaÃ­</title><body style="font-family:system-ui;padding:30px;max-width:650px;margin:auto"><h1>JuntaÃ­</h1><h2>${title}</h2><p>${text}</p><a href="juntai:///business/${encodeURIComponent(id)}">Abrir no JuntaÃ­</a></body></html>`,
        );
    } catch (error) {
      next(error);
    }
  },
);

app.get(
  '/discovery/:id',
  async (req, res, next) => {
    try {
      const id =
        requiredString(
          req.params.id,
          'id',
          200,
        );

      const post =
        await db
          .collection('discoveries')
          .doc(id)
          .get();

      if (!post.exists) {
        throw new ApiError(
          404,
          'not-found',
          'Descoberta nÃ£o encontrada.',
        );
      }

      const d =
        post.data() || {};

      const title =
        escapeHtml(
          d.title ||
          'Descoberta',
        );

      const text =
        escapeHtml(
          d.description || '',
        );

      res.type('html')
        .send(
          `<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} â€¢ JuntaÃ­</title><body style="font-family:system-ui;padding:30px;max-width:650px;margin:auto"><h1>JuntaÃ­</h1><h2>${title}</h2><p>${text}</p><a href="juntai:///discovery/${encodeURIComponent(id)}">Abrir no JuntaÃ­</a></body></html>`,
        );
    } catch (error) {
      next(error);
    }
  },
);

app.get(
  '/profile/:username',
  async (req, res, next) => {
    try {
      const username =
        bpUsername(
          req.params.username,
        );

      const lookup =
        await db
          .collection('usernames')
          .doc(username)
          .get();

      if (!lookup.exists) {
        throw new ApiError(
          404,
          'not-found',
          'Perfil nÃ£o encontrado.',
        );
      }

      const uid =
        String(
          lookup.data()?.uid ||
          '',
        );

      const profile =
        await db
          .collection('users')
          .doc(uid)
          .get();

      const d =
        profile.data() || {};

      const title =
        escapeHtml(
          d.name ||
          `@${username}`,
        );

      res.type('html')
        .send(
          `<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} â€¢ JuntaÃ­</title><body style="font-family:system-ui;padding:30px;max-width:650px;margin:auto"><h1>JuntaÃ­</h1><h2>${title}</h2><p>@${escapeHtml(username)}</p><a href="juntai:///profile/${encodeURIComponent(username)}">Abrir no JuntaÃ­</a></body></html>`,
        );
    } catch (error) {
      next(error);
    }
  },
);

app.get(
  '/benefit/:code',
  async (req, res, next) => {
    try {
      const code =
        requiredString(
          req.params.code,
          'code',
          40,
        ).toUpperCase();

      const benefit =
        await db
          .collection(
            'benefit_codes',
          )
          .doc(code)
          .get();

      if (!benefit.exists) {
        throw new ApiError(
          404,
          'not-found',
          'BenefÃ­cio nÃ£o encontrado.',
        );
      }

      const d =
        benefit.data() || {};

      res.type('html')
        .send(
          `<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>BenefÃ­cio JuntaÃ­</title><body style="font-family:system-ui;padding:30px;max-width:650px;margin:auto"><h1>JuntaÃ­</h1><h2>${escapeHtml(d.benefitLabel || 'BenefÃ­cio')}</h2><p><strong>${escapeHtml(code)}</strong></p><a href="juntai:///benefit/${encodeURIComponent(code)}">Abrir no JuntaÃ­</a></body></html>`,
        );
    } catch (error) {
      next(error);
    }
  },
);

app.get(
  '/payment/:status',
  (req, res) => {
    const status =
      escapeHtml(
        req.params.status || '',
      );

    res.type('html')
      .send(
        `<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><body style="font-family:system-ui;padding:30px;text-align:center"><h1>JuntaÃ­</h1><p>Pagamento: ${status}</p><a href="juntai:///business">Voltar ao app</a></body></html>`,
      );
  },
);

// /JUNTAI_BLUEPRINT_V6

app.use((error, _req, res, _next) => {
  console.error(error);

  if (error instanceof ApiError) {
    return res.status(error.status).json({
      ok: false,
      code: error.code,
      message: error.message,
    });
  }

  return res.status(500).json({
    ok: false,
    code: 'internal',
    message: 'Não foi possível concluir a operação.',
  });
});

const port = Number(process.env.PORT || 3000);
app.listen(port, '0.0.0.0', () => {
  console.log(`Juntaí API online na porta ${port}`);
});
