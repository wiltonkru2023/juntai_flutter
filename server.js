const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const app = express();

app.use(cors());
app.use(express.json({ limit: '256kb' }));

const projectId =
  process.env.FIREBASE_PROJECT_ID;

const clientEmail =
  process.env.FIREBASE_CLIENT_EMAIL;

const privateKey =
  process.env.FIREBASE_PRIVATE_KEY?.replace(
    /\\n/g,
    '\n',
  );

if (
  !projectId ||
  !clientEmail ||
  !privateKey
) {
  console.error(
    'FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL e FIREBASE_PRIVATE_KEY são obrigatórios.',
  );

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

const FieldValue =
  admin.firestore.FieldValue;

const Timestamp =
  admin.firestore.Timestamp;

const SOCIAL_NOTIFICATION_TYPES =
  new Set([
    'new_message',
    'new_participant',
    'join_request',
  ]);

class ApiError extends Error {
  constructor(
    status,
    code,
    message,
  ) {
    super(message);

    this.status = status;
    this.code = code;
  }
}

function requiredString(
  value,
  field,
  maxLength = 300,
) {
  const text =
    String(value ?? '').trim();

  if (!text) {
    throw new ApiError(
      400,
      'invalid-argument',
      `${field} é obrigatório.`,
    );
  }

  if (text.length > maxLength) {
    throw new ApiError(
      400,
      'invalid-argument',
      `${field} ultrapassa o limite permitido.`,
    );
  }

  return text;
}

function optionalString(
  value,
  maxLength = 1000,
) {
  return String(value ?? '')
    .trim()
    .slice(0, maxLength);
}

function parseDate(
  value,
  field,
) {
  const date =
    new Date(
      String(value ?? ''),
    );

  if (
    Number.isNaN(
      date.getTime(),
    )
  ) {
    throw new ApiError(
      400,
      'invalid-argument',
      `${field} inválido.`,
    );
  }

  return date;
}

async function authenticate(
  req,
  _res,
  next,
) {
  try {
    const authHeader =
      String(
        req.headers.authorization ||
          '',
      );

    if (
      !authHeader.startsWith(
        'Bearer ',
      )
    ) {
      throw new ApiError(
        401,
        'unauthenticated',
        'Faça login para continuar.',
      );
    }

    const idToken =
      authHeader
        .substring(7)
        .trim();

    if (!idToken) {
      throw new ApiError(
        401,
        'unauthenticated',
        'Faça login para continuar.',
      );
    }

    req.user =
      await admin
        .auth()
        .verifyIdToken(
          idToken,
          true,
        );

    next();
  } catch (error) {
    if (
      error instanceof ApiError
    ) {
      return next(error);
    }

    return next(
      new ApiError(
        401,
        'unauthenticated',
        'Sessão inválida ou expirada.',
      ),
    );
  }
}

async function userData(uid) {
  const snapshot =
    await db
      .collection('users')
      .doc(uid)
      .get();

  if (!snapshot.exists) {
    throw new ApiError(
      412,
      'failed-precondition',
      'Complete seu perfil primeiro.',
    );
  }

  return snapshot.data() || {};
}

async function blockExists(
  ownerUid,
  blockedUid,
) {
  if (
    !ownerUid ||
    !blockedUid ||
    ownerUid === blockedUid
  ) {
    return false;
  }

  const snapshot =
    await db
      .collection('users')
      .doc(ownerUid)
      .collection('blocks')
      .doc(blockedUid)
      .get();

  return snapshot.exists;
}

async function blockedEither(
  uidA,
  uidB,
) {
  const [
    aBlockedB,
    bBlockedA,
  ] = await Promise.all([
    blockExists(
      uidA,
      uidB,
    ),
    blockExists(
      uidB,
      uidA,
    ),
  ]);

  return (
    aBlockedB ||
    bBlockedA
  );
}

async function isBlockedBy(
  targetUid,
  actorId,
) {
  if (
    !actorId ||
    targetUid === actorId
  ) {
    return false;
  }

  const snapshot =
    await db
      .collection('users')
      .doc(targetUid)
      .collection('blocks')
      .doc(actorId)
      .get();

  return snapshot.exists;
}

function shouldPush(
  type,
  preferences,
) {
  if (
    type ===
    'new_message'
  ) {
    return (
      preferences
        .chatNotifications !==
      false
    );
  }

  return (
    preferences
      .activityNotifications !==
    false
  );
}

async function notify(
  uid,
  data,
) {
  if (!uid) {
    return;
  }

  const type =
    String(
      data.type ||
        'generic',
    );

  const actorId =
    data.actorId
      ? String(
          data.actorId,
        )
      : '';

  if (
    actorId &&
    SOCIAL_NOTIFICATION_TYPES.has(
      type,
    ) &&
    (await isBlockedBy(
      uid,
      actorId,
    ))
  ) {
    return;
  }

  const userRef =
    db
      .collection('users')
      .doc(uid);

  const profile =
    await userRef.get();

  if (!profile.exists) {
    return;
  }

  const preferences =
    profile.data() || {};

  if (
    preferences
      .accountStatus ===
    'disabled'
  ) {
    return;
  }

  const notificationData = {
    type,

    title:
      String(
        data.title ||
          'Juntaí',
      ),

    body:
      String(
        data.body ||
          '',
      ),

    activityId:
      data.activityId
        ? String(
            data.activityId,
          )
        : null,

    actorId:
      actorId || null,

    read: false,

    createdAt:
      FieldValue
        .serverTimestamp(),
  };

  await userRef
    .collection(
      'notifications',
    )
    .add(
      notificationData,
    );

  if (
    !shouldPush(
      type,
      preferences,
    )
  ) {
    return;
  }

  const devices =
    await userRef
      .collection('devices')
      .get();

  const deviceRows =
    devices.docs
      .map(
        (doc) => ({
          doc,
          token:
            String(
              doc.data()
                .token ||
                '',
            ),
        }),
      )
      .filter(
        (row) =>
          row.token,
      );

  if (
    !deviceRows.length
  ) {
    return;
  }

  const pushData = {
    type,

    title:
      notificationData.title,

    body:
      notificationData.body,

    activityId:
      notificationData
        .activityId ||
      '',

    actorId:
      notificationData
        .actorId ||
      '',
  };

  const invalidCodes =
    new Set([
      'messaging/registration-token-not-registered',
      'messaging/invalid-registration-token',
    ]);

  for (
    let start = 0;
    start <
    deviceRows.length;
    start += 500
  ) {
    const batch =
      deviceRows.slice(
        start,
        start + 500,
      );

    const response =
      await admin
        .messaging()
        .sendEachForMulticast({
          tokens:
            batch.map(
              (row) =>
                row.token,
            ),

          notification: {
            title:
              notificationData
                .title,

            body:
              notificationData
                .body,
          },

          data: pushData,

          android: {
            priority:
              'high',

            notification: {
              channelId:
                'juntai_high_importance',
            },
          },

          apns: {
            payload: {
              aps: {
                sound:
                  'default',
              },
            },
          },
        });

    const deletes = [];

    response.responses
      .forEach(
        (
          item,
          index,
        ) => {
          if (
            !item.success &&
            invalidCodes.has(
              item.error
                ?.code,
            )
          ) {
            deletes.push(
              batch[
                index
              ].doc.ref.delete(),
            );
          }
        },
      );

    if (
      deletes.length
    ) {
      await Promise
        .allSettled(
          deletes,
        );
    }
  }
}

app.get(
  '/',
  (
    _req,
    res,
  ) => {
    res.json({
      ok: true,
      service:
        'juntai-api',
    });
  },
);

app.get(
  '/health',
  (
    _req,
    res,
  ) => {
    res.json({
      ok: true,
    });
  },
);

app.post(
  '/join-activity',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const activityId =
        requiredString(
          req.body
            ?.activityId,
          'activityId',
          200,
        );

      const activityRef =
        db
          .collection(
            'activities',
          )
          .doc(
            activityId,
          );

      const participantRef =
        activityRef
          .collection(
            'participants',
          )
          .doc(uid);

      const profileRef =
        db
          .collection(
            'users',
          )
          .doc(uid);

      const initialActivitySnapshot =
        await activityRef.get();

      if (
        !initialActivitySnapshot
          .exists
      ) {
        throw new ApiError(
          404,
          'not-found',
          'Atividade não encontrada.',
        );
      }

      const initialCreatorId =
        String(
          initialActivitySnapshot
            .data()
            ?.creatorId ||
            '',
        );

      if (
        await blockedEither(
          uid,
          initialCreatorId,
        )
      ) {
        throw new ApiError(
          403,
          'permission-denied',
          'A participação não está disponível entre usuários bloqueados.',
        );
      }

      let creatorId = '';
      let title =
        'Atividade';

      let joined = false;

      await db
        .runTransaction(
          async (
            transaction,
          ) => {
            const [
              activitySnapshot,
              participantSnapshot,
              profileSnapshot,
            ] =
              await Promise
                .all([
                  transaction.get(
                    activityRef,
                  ),

                  transaction.get(
                    participantRef,
                  ),

                  transaction.get(
                    profileRef,
                  ),
                ]);

            if (
              !activitySnapshot
                .exists
            ) {
              throw new ApiError(
                404,
                'not-found',
                'Atividade não encontrada.',
              );
            }

            if (
              !profileSnapshot
                .exists
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Complete seu perfil antes de participar.',
              );
            }

            const activity =
              activitySnapshot
                .data();

            const profile =
              profileSnapshot
                .data();

            creatorId =
              String(
                activity
                  .creatorId ||
                  '',
              );

            title =
              String(
                activity
                  .title ||
                  'Atividade',
              );

            if (
              activity
                .status !==
              'active'
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Atividade indisponível.',
              );
            }

            if (
              activity
                .isPrivate ===
              true
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Atividade privada requer solicitação.',
              );
            }

            if (
              creatorId ===
              uid
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Você é o organizador desta atividade.',
              );
            }

            if (
              participantSnapshot
                .exists
            ) {
              return;
            }

            const participantCount =
              Number(
                activity
                  .participantCount ||
                  0,
              );

            const maxParticipants =
              Number(
                activity
                  .maxParticipants ||
                  0,
              );

            if (
              maxParticipants <=
                0 ||
              participantCount >=
                maxParticipants
            ) {
              throw new ApiError(
                409,
                'resource-exhausted',
                'Atividade lotada.',
              );
            }

            const name =
              String(
                profile.name ||
                  '',
              ).trim();

            if (!name) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Complete seu perfil antes de participar.',
              );
            }

            transaction.set(
              participantRef,
              {
                userId:
                  uid,

                name,

                role:
                  'participant',

                joinedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            transaction.update(
              activityRef,
              {
                participantCount:
                  FieldValue
                    .increment(
                      1,
                    ),

                participantNames:
                  FieldValue
                    .arrayUnion(
                      name,
                    ),

                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            joined =
              true;
          },
        );

      if (
        joined &&
        creatorId &&
        creatorId !== uid
      ) {
        const profile =
          await userData(
            uid,
          );

        await notify(
          creatorId,
          {
            type:
              'new_participant',

            title:
              'Novo participante',

            body:
              `${String(profile.name || 'Alguém')} entrou em ${title}`,

            activityId,

            actorId:
              uid,
          },
        );
      }

      res.json({
        ok: true,
        joined,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

app.post(
  '/leave-activity',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const activityId =
        requiredString(
          req.body
            ?.activityId,
          'activityId',
          200,
        );

      const activityRef =
        db
          .collection(
            'activities',
          )
          .doc(
            activityId,
          );

      const participantRef =
        activityRef
          .collection(
            'participants',
          )
          .doc(uid);

      let left = false;

      await db
        .runTransaction(
          async (
            transaction,
          ) => {
            const [
              activitySnapshot,
              participantSnapshot,
            ] =
              await Promise
                .all([
                  transaction.get(
                    activityRef,
                  ),

                  transaction.get(
                    participantRef,
                  ),
                ]);

            if (
              !activitySnapshot
                .exists
            ) {
              throw new ApiError(
                404,
                'not-found',
                'Atividade não encontrada.',
              );
            }

            const activity =
              activitySnapshot
                .data();

            if (
              String(
                activity
                  .creatorId ||
                  '',
              ) === uid
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'O organizador não pode sair da própria atividade.',
              );
            }

            if (
              !participantSnapshot
                .exists
            ) {
              return;
            }

            const participant =
              participantSnapshot
                .data() ||
              {};

            const participantName =
              String(
                participant
                  .name ||
                  '',
              ).trim();

            const currentCount =
              Math.max(
                Number(
                  activity
                    .participantCount ||
                    1,
                ),
                1,
              );

            transaction.delete(
              participantRef,
            );

            transaction.update(
              activityRef,
              {
                participantCount:
                  Math.max(
                    currentCount -
                      1,
                    1,
                  ),

                ...(participantName
                  ? {
                      participantNames:
                        FieldValue
                          .arrayRemove(
                            participantName,
                          ),
                    }
                  : {}),

                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            left = true;
          },
        );

      res.json({
        ok: true,
        left,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

app.post(
  '/request-join-activity',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const activityId =
        requiredString(
          req.body
            ?.activityId,
          'activityId',
          200,
        );

      const activityRef =
        db
          .collection(
            'activities',
          )
          .doc(
            activityId,
          );

      const requestRef =
        activityRef
          .collection(
            'join_requests',
          )
          .doc(uid);

      const participantRef =
        activityRef
          .collection(
            'participants',
          )
          .doc(uid);

      const profileRef =
        db
          .collection(
            'users',
          )
          .doc(uid);

      const initialActivitySnapshot =
        await activityRef
          .get();

      if (
        !initialActivitySnapshot
          .exists
      ) {
        throw new ApiError(
          404,
          'not-found',
          'Atividade não encontrada.',
        );
      }

      const initialCreatorId =
        String(
          initialActivitySnapshot
            .data()
            ?.creatorId ||
            '',
        );

      if (
        await blockedEither(
          uid,
          initialCreatorId,
        )
      ) {
        throw new ApiError(
          403,
          'permission-denied',
          'A solicitação não está disponível entre usuários bloqueados.',
        );
      }

      let creatorId = '';
      let title =
        'Atividade';

      let requesterName =
        'Usuário';

      let created = false;

      await db
        .runTransaction(
          async (
            transaction,
          ) => {
            const [
              activitySnapshot,
              requestSnapshot,
              participantSnapshot,
              profileSnapshot,
            ] =
              await Promise
                .all([
                  transaction.get(
                    activityRef,
                  ),

                  transaction.get(
                    requestRef,
                  ),

                  transaction.get(
                    participantRef,
                  ),

                  transaction.get(
                    profileRef,
                  ),
                ]);

            if (
              !activitySnapshot
                .exists
            ) {
              throw new ApiError(
                404,
                'not-found',
                'Atividade não encontrada.',
              );
            }

            if (
              !profileSnapshot
                .exists
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Complete seu perfil antes de solicitar participação.',
              );
            }

            const activity =
              activitySnapshot
                .data();

            const profile =
              profileSnapshot
                .data();

            creatorId =
              String(
                activity
                  .creatorId ||
                  '',
              );

            title =
              String(
                activity
                  .title ||
                  'Atividade',
              );

            requesterName =
              String(
                profile.name ||
                  'Usuário',
              ).trim() ||
              'Usuário';

            if (
              activity
                .status !==
              'active'
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Atividade indisponível.',
              );
            }

            if (
              activity
                .isPrivate !==
              true
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Atividade não é privada.',
              );
            }

            if (
              creatorId ===
              uid
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Você é o organizador desta atividade.',
              );
            }

            if (
              participantSnapshot
                .exists
            ) {
              throw new ApiError(
                409,
                'already-exists',
                'Você já participa desta atividade.',
              );
            }

            const participantCount =
              Number(
                activity
                  .participantCount ||
                  0,
              );

            const maxParticipants =
              Number(
                activity
                  .maxParticipants ||
                  0,
              );

            if (
              maxParticipants <=
                0 ||
              participantCount >=
                maxParticipants
            ) {
              throw new ApiError(
                409,
                'resource-exhausted',
                'Atividade lotada.',
              );
            }

            if (
              requestSnapshot
                .exists &&
              requestSnapshot
                .data()
                ?.status ===
                'pending'
            ) {
              throw new ApiError(
                409,
                'already-exists',
                'Sua solicitação já foi enviada.',
              );
            }

            transaction.set(
              requestRef,
              {
                userId:
                  uid,

                name:
                  requesterName,

                photoUrl:
                  profile
                    .photoUrl ||
                  null,

                status:
                  'pending',

                createdAt:
                  FieldValue
                    .serverTimestamp(),

                respondedAt:
                  null,
              },
              {
                merge:
                  true,
              },
            );

            created =
              true;
          },
        );

      if (created) {
        await notify(
          creatorId,
          {
            type:
              'join_request',

            title:
              `${requesterName} quer participar`,

            body:
              title,

            activityId,

            actorId:
              uid,
          },
        );
      }

      res.json({
        ok: true,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

app.post(
  '/respond-join-request',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const activityId =
        requiredString(
          req.body
            ?.activityId,
          'activityId',
          200,
        );

      const userId =
        requiredString(
          req.body
            ?.userId,
          'userId',
          200,
        );

      const accept =
        req.body
          ?.accept ===
        true;

      const activityRef =
        db
          .collection(
            'activities',
          )
          .doc(
            activityId,
          );

      const requestRef =
        activityRef
          .collection(
            'join_requests',
          )
          .doc(
            userId,
          );

      const participantRef =
        activityRef
          .collection(
            'participants',
          )
          .doc(
            userId,
          );

      const profileRef =
        db
          .collection(
            'users',
          )
          .doc(
            userId,
          );

      if (
        accept &&
        (await blockedEither(
          uid,
          userId,
        ))
      ) {
        throw new ApiError(
          403,
          'permission-denied',
          'Não é possível aceitar uma solicitação entre usuários bloqueados.',
        );
      }

      let title =
        'Atividade';

      let requesterName =
        'Participante';

      await db
        .runTransaction(
          async (
            transaction,
          ) => {
            const [
              activitySnapshot,
              requestSnapshot,
              participantSnapshot,
              profileSnapshot,
            ] =
              await Promise
                .all([
                  transaction.get(
                    activityRef,
                  ),

                  transaction.get(
                    requestRef,
                  ),

                  transaction.get(
                    participantRef,
                  ),

                  transaction.get(
                    profileRef,
                  ),
                ]);

            if (
              !activitySnapshot
                .exists
            ) {
              throw new ApiError(
                404,
                'not-found',
                'Atividade não encontrada.',
              );
            }

            const activity =
              activitySnapshot
                .data();

            title =
              String(
                activity
                  .title ||
                  'Atividade',
              );

            if (
              String(
                activity
                  .creatorId ||
                  '',
              ) !== uid
            ) {
              throw new ApiError(
                403,
                'permission-denied',
                'Somente o organizador pode responder.',
              );
            }

            if (
              !requestSnapshot
                .exists
            ) {
              throw new ApiError(
                404,
                'not-found',
                'Solicitação não encontrada.',
              );
            }

            const joinRequest =
              requestSnapshot
                .data() ||
              {};

            if (
              joinRequest
                .status !==
              'pending'
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Esta solicitação já foi respondida.',
              );
            }

            requesterName =
              String(
                joinRequest
                  .name ||
                  profileSnapshot
                    .data()
                    ?.name ||
                  'Participante',
              ).trim() ||
              'Participante';

            if (
              accept &&
              !participantSnapshot
                .exists
            ) {
              if (
                activity
                  .status !==
                'active'
              ) {
                throw new ApiError(
                  412,
                  'failed-precondition',
                  'Atividade indisponível.',
                );
              }

              const participantCount =
                Number(
                  activity
                    .participantCount ||
                    0,
                );

              const maxParticipants =
                Number(
                  activity
                    .maxParticipants ||
                    0,
                );

              if (
                maxParticipants <=
                  0 ||
                participantCount >=
                  maxParticipants
              ) {
                throw new ApiError(
                  409,
                  'resource-exhausted',
                  'Atividade lotada.',
                );
              }

              transaction.set(
                participantRef,
                {
                  userId,

                  name:
                    requesterName,

                  role:
                    'participant',

                  joinedAt:
                    FieldValue
                      .serverTimestamp(),
                },
              );

              transaction.update(
                activityRef,
                {
                  participantCount:
                    FieldValue
                      .increment(
                        1,
                      ),

                  participantNames:
                    FieldValue
                      .arrayUnion(
                        requesterName,
                      ),

                  updatedAt:
                    FieldValue
                      .serverTimestamp(),
                },
              );
            }

            transaction.update(
              requestRef,
              {
                status:
                  accept
                    ? 'accepted'
                    : 'rejected',

                respondedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );
          },
        );

      await notify(
        userId,
        {
          type:
            accept
              ? 'join_approved'
              : 'join_rejected',

          title:
            accept
              ? 'Participação aprovada'
              : 'Solicitação recusada',

          body:
            title,

          activityId,

          actorId:
            uid,
        },
      );

      res.json({
        ok: true,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

app.post(
  '/report-content',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const targetType =
        requiredString(
          req.body
            ?.targetType,
          'targetType',
          30,
        );

      const targetId =
        requiredString(
          req.body
            ?.targetId,
          'targetId',
          300,
        );

      const reason =
        requiredString(
          req.body
            ?.reason,
          'reason',
          120,
        );

      const details =
        optionalString(
          req.body
            ?.details,
          1000,
        );

      if (
        ![
          'user',
          'activity',
          'chat',
        ].includes(
          targetType,
        )
      ) {
        throw new ApiError(
          400,
          'invalid-argument',
          'Tipo de denúncia inválido.',
        );
      }

      if (
        targetType ===
          'user' &&
        targetId === uid
      ) {
        throw new ApiError(
          400,
          'invalid-argument',
          'Você não pode denunciar o próprio perfil.',
        );
      }

      await db
        .collection(
          'reports',
        )
        .add({
          reporterId:
            uid,

          targetType,

          targetId,

          reason,

          details,

          status:
            'open',

          createdAt:
            FieldValue
              .serverTimestamp(),
        });

      res.json({
        ok: true,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

app.post(
  '/delete-account',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db
          .collection(
            'users',
          )
          .doc(uid);

      const createdActivities =
        await db
          .collection(
            'activities',
          )
          .where(
            'creatorId',
            '==',
            uid,
          )
          .get();

      for (
        const activity
        of createdActivities.docs
      ) {
        const currentStatus =
          activity
            .data()
            .status;

        await activity.ref
          .update({
            creatorName:
              'Usuário excluído',

            status:
              currentStatus ===
              'active'
                ? 'cancelled'
                : currentStatus,

            updatedAt:
              FieldValue
                .serverTimestamp(),
          });
      }

      await db
        .recursiveDelete(
          userRef,
        );

      await admin
        .auth()
        .deleteUser(
          uid,
        );

      res.json({
        ok: true,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

app.post(
  '/notify-chat-message',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const activityId =
        requiredString(
          req.body
            ?.activityId,
          'activityId',
          200,
        );

      const messageId =
        requiredString(
          req.body
            ?.messageId,
          'messageId',
          200,
        );

      const activityRef =
        db
          .collection(
            'activities',
          )
          .doc(
            activityId,
          );

      const messageRef =
        activityRef
          .collection(
            'chat',
          )
          .doc(
            messageId,
          );

      const [
        activitySnapshot,
        messageSnapshot,
        participantSnapshot,
      ] =
        await Promise
          .all([
            activityRef.get(),

            messageRef.get(),

            activityRef
              .collection(
                'participants',
              )
              .doc(uid)
              .get(),
          ]);

      if (
        !activitySnapshot
          .exists
      ) {
        throw new ApiError(
          404,
          'not-found',
          'Atividade não encontrada.',
        );
      }

      if (
        !messageSnapshot
          .exists
      ) {
        throw new ApiError(
          404,
          'not-found',
          'Mensagem não encontrada.',
        );
      }

      const activity =
        activitySnapshot
          .data() ||
        {};

      const message =
        messageSnapshot
          .data() ||
        {};

      const creatorId =
        String(
          activity
            .creatorId ||
            '',
        );

      if (
        !participantSnapshot
          .exists &&
        creatorId !== uid
      ) {
        throw new ApiError(
          403,
          'permission-denied',
          'Você não participa desta atividade.',
        );
      }

      if (
        String(
          message
            .senderId ||
            '',
        ) !== uid
      ) {
        throw new ApiError(
          403,
          'permission-denied',
          'Você não pode notificar uma mensagem de outro usuário.',
        );
      }

      const participants =
        await activityRef
          .collection(
            'participants',
          )
          .get();

      const title =
        String(
          activity
            .title ||
            'Atividade',
        );

      const senderName =
        String(
          message
            .senderName ||
            'Nova mensagem',
        );

      const text =
        message.type ===
        'image'
          ? '📷 Foto'
          : String(
              message.text ||
                '',
            ).slice(
              0,
              120,
            );

      await Promise.all(
        participants.docs
          .filter(
            (
              document,
            ) =>
              document.id !==
              uid,
          )
          .map(
            (
              document,
            ) =>
              notify(
                document.id,
                {
                  type:
                    'new_message',

                  title:
                    senderName,

                  body:
                    `${title}: ${text}`,

                  activityId,

                  actorId:
                    uid,
                },
              ),
          ),
      );

      if (
        creatorId &&
        creatorId !== uid &&
        !participants.docs
          .some(
            (d) =>
              d.id ===
              creatorId,
          )
      ) {
        await notify(
          creatorId,
          {
            type:
              'new_message',

            title:
              senderName,

            body:
              `${title}: ${text}`,

            activityId,

            actorId:
              uid,
          },
        );
      }

      res.json({
        ok: true,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

async function notifyActivityParticipants(
  activityId,
  creatorId,
  type,
  title,
  body,
) {
  const participants =
    await db
      .collection(
        'activities',
      )
      .doc(
        activityId,
      )
      .collection(
        'participants',
      )
      .get();

  await Promise.all(
    participants.docs
      .filter(
        (
          document,
        ) =>
          document.id !==
          creatorId,
      )
      .map(
        (
          document,
        ) =>
          notify(
            document.id,
            {
              type,

              title,

              body,

              activityId,

              actorId:
                creatorId,
            },
          ),
      ),
  );
}

app.post(
  '/update-activity',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const activityId =
        requiredString(
          req.body
            ?.activityId,
          'activityId',
          200,
        );

      const title =
        requiredString(
          req.body?.title,
          'title',
          120,
        );

      const description =
        optionalString(
          req.body
            ?.description,
          2000,
        );

      const category =
        requiredString(
          req.body
            ?.category,
          'category',
          40,
        );

      const address =
        requiredString(
          req.body
            ?.address,
          'address',
          300,
        );

      const latitude =
        Number(
          req.body
            ?.latitude,
        );

      const longitude =
        Number(
          req.body
            ?.longitude,
        );

      const geohash =
        optionalString(
          req.body
            ?.geohash,
          100,
        );

      const startsAt =
        parseDate(
          req.body
            ?.startsAt,
          'startsAt',
        );

      const maxParticipants =
        Number(
          req.body
            ?.maxParticipants,
        );

      const isPrivate =
        req.body
          ?.isPrivate ===
        true;

      if (
        !Number.isFinite(
          latitude,
        ) ||
        latitude < -90 ||
        latitude > 90
      ) {
        throw new ApiError(
          400,
          'invalid-argument',
          'Latitude inválida.',
        );
      }

      if (
        !Number.isFinite(
          longitude,
        ) ||
        longitude < -180 ||
        longitude > 180
      ) {
        throw new ApiError(
          400,
          'invalid-argument',
          'Longitude inválida.',
        );
      }

      if (
        !Number.isInteger(
          maxParticipants,
        ) ||
        maxParticipants <
          2 ||
        maxParticipants >
          10000
      ) {
        throw new ApiError(
          400,
          'invalid-argument',
          'Limite de participantes inválido.',
        );
      }

      if (
        startsAt.getTime() <=
        Date.now()
      ) {
        throw new ApiError(
          400,
          'invalid-argument',
          'Escolha uma data e horário futuros.',
        );
      }

      const activityRef =
        db
          .collection(
            'activities',
          )
          .doc(
            activityId,
          );

      let currentTitle =
        title;

      await db
        .runTransaction(
          async (
            transaction,
          ) => {
            const snapshot =
              await transaction
                .get(
                  activityRef,
                );

            if (
              !snapshot.exists
            ) {
              throw new ApiError(
                404,
                'not-found',
                'Atividade não encontrada.',
              );
            }

            const activity =
              snapshot.data() ||
              {};

            if (
              String(
                activity
                  .creatorId ||
                  '',
              ) !== uid
            ) {
              throw new ApiError(
                403,
                'permission-denied',
                'Somente o organizador pode editar esta atividade.',
              );
            }

            if (
              activity
                .status !==
              'active'
            ) {
              throw new ApiError(
                412,
                'failed-precondition',
                'Atividade indisponível para edição.',
              );
            }

            if (
              maxParticipants <
              Number(
                activity
                  .participantCount ||
                  1,
              )
            ) {
              throw new ApiError(
                400,
                'invalid-argument',
                'O limite não pode ser menor que o número atual de participantes.',
              );
            }

            currentTitle =
              title;

            transaction.update(
              activityRef,
              {
                title,

                description,

                category,

                address,

                latitude,

                longitude,

                geohash,

                startsAt:
                  Timestamp
                    .fromDate(
                      startsAt,
                    ),

                maxParticipants,

                isPrivate,

                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );
          },
        );

      await notifyActivityParticipants(
        activityId,
        uid,
        'activity_updated',
        'Atividade atualizada',
        currentTitle,
      );

      res.json({
        ok: true,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

app.post(
  '/cancel-activity',
  authenticate,
  async (
    req,
    res,
    next,
  ) => {
    try {
      const uid =
        req.user.uid;

      const activityId =
        requiredString(
          req.body
            ?.activityId,
          'activityId',
          200,
        );

      const activityRef =
        db
          .collection(
            'activities',
          )
          .doc(
            activityId,
          );

      let title =
        'Atividade';

      let changed =
        false;

      await db
        .runTransaction(
          async (
            transaction,
          ) => {
            const snapshot =
              await transaction
                .get(
                  activityRef,
                );

            if (
              !snapshot.exists
            ) {
              throw new ApiError(
                404,
                'not-found',
                'Atividade não encontrada.',
              );
            }

            const activity =
              snapshot.data() ||
              {};

            if (
              String(
                activity
                  .creatorId ||
                  '',
              ) !== uid
            ) {
              throw new ApiError(
                403,
                'permission-denied',
                'Somente o organizador pode cancelar esta atividade.',
              );
            }

            title =
              String(
                activity
                  .title ||
                  'Atividade',
              );

            if (
              activity
                .status ===
              'cancelled'
            ) {
              return;
            }

            transaction.update(
              activityRef,
              {
                status:
                  'cancelled',

                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            changed =
              true;
          },
        );

      if (changed) {
        await notifyActivityParticipants(
          activityId,
          uid,
          'activity_cancelled',
          'Atividade cancelada',
          title,
        );
      }

      res.json({
        ok: true,
        changed,
      });
    } catch (
      error
    ) {
      next(error);
    }
  },
);

app.use(
  (
    error,
    _req,
    res,
    _next,
  ) => {
    console.error(
      error,
    );

    if (
      error instanceof
      ApiError
    ) {
      return res
        .status(
          error.status,
        )
        .json({
          ok: false,

          code:
            error.code,

          message:
            error.message,
        });
    }

    return res
      .status(500)
      .json({
        ok: false,

        code:
          'internal',

        message:
          'Não foi possível concluir a operação.',
      });
  },
);

const port =
  Number(
    process.env.PORT ||
      3000,
  );

app.listen(
  port,
  '0.0.0.0',
  () => {
    console.log(
      `Juntaí API online na porta ${port}`,
    );
  },
);