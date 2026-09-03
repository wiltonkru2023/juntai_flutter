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
  if (type === 'new_message') {
    return preferences.chatNotifications !== false;
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

    if (!['profile', 'activity', 'chat', 'discovery'].includes(purpose)) {
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
      websiteUrl: optionalString(req.body?.websiteUrl, 500),
      description: optionalString(req.body?.description, 800),
      verified: false, reviewStatus: 'pending', plan: 'free',
      monthlyPostLimit: 1, activePostLimit: 1, postsUsedThisMonth: 0,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    res.json({ ok: true, businessId: uid });
  } catch (error) { next(error); }
});

app.post('/create-business-post', authenticate, async (req, res, next) => {
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
