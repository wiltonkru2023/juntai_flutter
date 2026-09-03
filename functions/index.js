const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const Timestamp = admin.firestore.Timestamp;

const SOCIAL_NOTIFICATION_TYPES = new Set([
  'new_message',
  'new_participant',
  'join_request',
]);

function requireAuth(request) {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError(
      'unauthenticated',
      'Faça login para continuar.',
    );
  }

  return uid;
}

function requiredString(value, field, maxLength = 300) {
  const text = String(value ?? '').trim();

  if (!text) {
    throw new HttpsError(
      'invalid-argument',
      `${field} é obrigatório.`,
    );
  }

  if (text.length > maxLength) {
    throw new HttpsError(
      'invalid-argument',
      `${field} ultrapassa o limite permitido.`,
    );
  }

  return text;
}

async function userData(uid) {
  const snapshot = await db
    .collection('users')
    .doc(uid)
    .get();

  if (!snapshot.exists) {
    throw new HttpsError(
      'failed-precondition',
      'Complete seu perfil primeiro.',
    );
  }

  return snapshot.data() || {};
}

async function blockExists(ownerUid, blockedUid) {
  if (
    !ownerUid ||
    !blockedUid ||
    ownerUid === blockedUid
  ) {
    return false;
  }

  const snapshot = await db
    .collection('users')
    .doc(ownerUid)
    .collection('blocks')
    .doc(blockedUid)
    .get();

  return snapshot.exists;
}

async function blockedEither(uidA, uidB) {
  const [
    aBlockedB,
    bBlockedA,
  ] = await Promise.all([
    blockExists(uidA, uidB),
    blockExists(uidB, uidA),
  ]);

  return aBlockedB || bBlockedA;
}

async function isBlockedBy(targetUid, actorId) {
  if (!actorId || targetUid === actorId) {
    return false;
  }

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
  if (!uid) {
    return;
  }

  const type = String(
    data.type || 'generic',
  );

  const actorId = data.actorId
    ? String(data.actorId)
    : '';

  if (
    actorId &&
    SOCIAL_NOTIFICATION_TYPES.has(type) &&
    (await isBlockedBy(uid, actorId))
  ) {
    return;
  }

  const userRef = db
    .collection('users')
    .doc(uid);

  const profile = await userRef.get();

  if (!profile.exists) {
    return;
  }

  const preferences =
    profile.data() || {};

  if (
    preferences.accountStatus ===
    'disabled'
  ) {
    return;
  }

  const notificationData = {
    type,
    title: String(
      data.title || 'Juntaí',
    ),
    body: String(
      data.body || '',
    ),
    activityId: data.activityId
      ? String(data.activityId)
      : null,
    actorId: actorId || null,
    read: false,
    createdAt:
      FieldValue.serverTimestamp(),
  };

  await userRef
    .collection('notifications')
    .add(notificationData);

  if (!shouldPush(type, preferences)) {
    return;
  }

  const devices = await userRef
    .collection('devices')
    .get();

  const deviceRows =
    devices.docs
      .map((doc) => ({
        doc,
        token: String(
          doc.data().token || '',
        ),
      }))
      .filter((row) => row.token);

  if (!deviceRows.length) {
    return;
  }

  const pushData = {
    type,
    title:
      notificationData.title,
    body:
      notificationData.body,
    activityId:
      notificationData.activityId || '',
    actorId:
      notificationData.actorId || '',
  };

  const response =
    await admin.messaging()
      .sendEachForMulticast({
        tokens: deviceRows.map(
          (row) => row.token,
        ),

        notification: {
          title:
            notificationData.title,
          body:
            notificationData.body,
        },

        data: pushData,

        android: {
          priority: 'high',
          notification: {
            channelId:
              'juntai_high_importance',
          },
        },

        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });

  const invalidCodes = new Set([
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ]);

  const deletes = [];

  response.responses.forEach(
    (item, index) => {
      if (
        !item.success &&
        invalidCodes.has(
          item.error?.code,
        )
      ) {
        deletes.push(
          deviceRows[
            index
          ].doc.ref.delete(),
        );
      }
    },
  );

  if (deletes.length) {
    await Promise.allSettled(
      deletes,
    );
  }
}


// ============================================================
// ENTRAR EM ATIVIDADE PÚBLICA
// ============================================================

exports.joinActivity =
  onCall(async (request) => {
    const uid =
      requireAuth(request);

    const activityId =
      requiredString(
        request.data?.activityId,
        'activityId',
        200,
      );

    const activityRef =
      db.collection('activities')
        .doc(activityId);

    const participantRef =
      activityRef
        .collection('participants')
        .doc(uid);

    const profileRef =
      db.collection('users')
        .doc(uid);

    const initialActivitySnapshot =
      await activityRef.get();

    if (
      !initialActivitySnapshot.exists
    ) {
      throw new HttpsError(
        'not-found',
        'Atividade não encontrada.',
      );
    }

    const initialCreatorId =
      String(
        initialActivitySnapshot
          .data()?.creatorId || '',
      );

    if (
      await blockedEither(
        uid,
        initialCreatorId,
      )
    ) {
      throw new HttpsError(
        'permission-denied',
        'A participação não está disponível entre usuários bloqueados.',
      );
    }

    let creatorId = '';
    let title = 'Atividade';
    let joined = false;

    await db.runTransaction(
      async (transaction) => {
        const [
          activitySnapshot,
          participantSnapshot,
          profileSnapshot,
        ] = await Promise.all([
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
          !activitySnapshot.exists
        ) {
          throw new HttpsError(
            'not-found',
            'Atividade não encontrada.',
          );
        }

        if (
          !profileSnapshot.exists
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Complete seu perfil antes de participar.',
          );
        }

        const activity =
          activitySnapshot.data();

        const profile =
          profileSnapshot.data();

        creatorId =
          String(
            activity.creatorId || '',
          );

        title =
          String(
            activity.title ||
              'Atividade',
          );

        if (
          activity.status !==
          'active'
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Atividade indisponível.',
          );
        }

        if (
          activity.isPrivate ===
          true
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Atividade privada requer solicitação.',
          );
        }

        if (
          creatorId === uid
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Você é o organizador desta atividade.',
          );
        }

        if (
          participantSnapshot.exists
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
          maxParticipants <= 0 ||
          participantCount >=
            maxParticipants
        ) {
          throw new HttpsError(
            'resource-exhausted',
            'Atividade lotada.',
          );
        }

        const name =
          String(
            profile.name || '',
          ).trim();

        if (!name) {
          throw new HttpsError(
            'failed-precondition',
            'Complete seu perfil antes de participar.',
          );
        }

        transaction.set(
          participantRef,
          {
            userId: uid,
            name,
            role: 'participant',
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
                .increment(1),

            participantNames:
              FieldValue
                .arrayUnion(name),

            updatedAt:
              FieldValue
                .serverTimestamp(),
          },
        );

        joined = true;
      },
    );

    if (
      joined &&
      creatorId &&
      creatorId !== uid
    ) {
      const profile =
        await userData(uid);

      await notify(
        creatorId,
        {
          type:
            'new_participant',

          title:
            'Novo participante',

          body:
            `${String(
              profile.name ||
                'Alguém',
            )} entrou em ${title}`,

          activityId,

          actorId: uid,
        },
      );
    }

    return {
      ok: true,
      joined,
    };
  });


// ============================================================
// SAIR DA ATIVIDADE
// ============================================================

exports.leaveActivity =
  onCall(async (request) => {
    const uid =
      requireAuth(request);

    const activityId =
      requiredString(
        request.data?.activityId,
        'activityId',
        200,
      );

    const activityRef =
      db.collection('activities')
        .doc(activityId);

    const participantRef =
      activityRef
        .collection('participants')
        .doc(uid);

    let left = false;

    await db.runTransaction(
      async (transaction) => {
        const [
          activitySnapshot,
          participantSnapshot,
        ] = await Promise.all([
          transaction.get(
            activityRef,
          ),
          transaction.get(
            participantRef,
          ),
        ]);

        if (
          !activitySnapshot.exists
        ) {
          throw new HttpsError(
            'not-found',
            'Atividade não encontrada.',
          );
        }

        const activity =
          activitySnapshot.data();

        if (
          String(
            activity.creatorId ||
              '',
          ) === uid
        ) {
          throw new HttpsError(
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
            .data() || {};

        const participantName =
          String(
            participant.name || '',
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
                currentCount - 1,
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

    return {
      ok: true,
      left,
    };
  });


// ============================================================
// SOLICITAR PARTICIPAÇÃO EM ATIVIDADE PRIVADA
// ============================================================

exports.requestJoinActivity =
  onCall(async (request) => {
    const uid =
      requireAuth(request);

    const activityId =
      requiredString(
        request.data?.activityId,
        'activityId',
        200,
      );

    const activityRef =
      db.collection('activities')
        .doc(activityId);

    const requestRef =
      activityRef
        .collection('join_requests')
        .doc(uid);

    const participantRef =
      activityRef
        .collection('participants')
        .doc(uid);

    const profileRef =
      db.collection('users')
        .doc(uid);

    const initialActivitySnapshot =
      await activityRef.get();

    if (
      !initialActivitySnapshot
        .exists
    ) {
      throw new HttpsError(
        'not-found',
        'Atividade não encontrada.',
      );
    }

    const initialCreatorId =
      String(
        initialActivitySnapshot
          .data()?.creatorId || '',
      );

    if (
      await blockedEither(
        uid,
        initialCreatorId,
      )
    ) {
      throw new HttpsError(
        'permission-denied',
        'Não é possível solicitar participação entre usuários bloqueados.',
      );
    }

    let creatorId = '';
    let title = 'Atividade';
    let requesterName =
      'Usuário';
    let created = false;

    await db.runTransaction(
      async (transaction) => {
        const [
          activitySnapshot,
          requestSnapshot,
          participantSnapshot,
          profileSnapshot,
        ] = await Promise.all([
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
          !activitySnapshot.exists
        ) {
          throw new HttpsError(
            'not-found',
            'Atividade não encontrada.',
          );
        }

        if (
          !profileSnapshot.exists
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Complete seu perfil antes de solicitar participação.',
          );
        }

        const activity =
          activitySnapshot.data();

        const profile =
          profileSnapshot.data();

        creatorId =
          String(
            activity.creatorId || '',
          );

        title =
          String(
            activity.title ||
              'Atividade',
          );

        requesterName =
          String(
            profile.name ||
              'Usuário',
          ).trim() ||
          'Usuário';

        if (
          activity.status !==
          'active'
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Atividade indisponível.',
          );
        }

        if (
          activity.isPrivate !==
          true
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Atividade não é privada.',
          );
        }

        if (
          creatorId === uid
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Você é o organizador desta atividade.',
          );
        }

        if (
          participantSnapshot.exists
        ) {
          throw new HttpsError(
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
          maxParticipants <= 0 ||
          participantCount >=
            maxParticipants
        ) {
          throw new HttpsError(
            'resource-exhausted',
            'Atividade lotada.',
          );
        }

        if (
          requestSnapshot.exists &&
          requestSnapshot
            .data()?.status ===
            'pending'
        ) {
          throw new HttpsError(
            'already-exists',
            'Sua solicitação já foi enviada.',
          );
        }

        transaction.set(
          requestRef,
          {
            userId: uid,

            name:
              requesterName,

            photoUrl:
              profile.photoUrl ||
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
            merge: true,
          },
        );

        created = true;
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

    return {
      ok: true,
    };
  });


// ============================================================
// ACEITAR / RECUSAR SOLICITAÇÃO
// ============================================================

exports.respondJoinRequest =
  onCall(async (request) => {
    const uid =
      requireAuth(request);

    const activityId =
      requiredString(
        request.data?.activityId,
        'activityId',
        200,
      );

    const userId =
      requiredString(
        request.data?.userId,
        'userId',
        200,
      );

    const accept =
      request.data?.accept ===
      true;

    const activityRef =
      db.collection('activities')
        .doc(activityId);

    const requestRef =
      activityRef
        .collection('join_requests')
        .doc(userId);

    const participantRef =
      activityRef
        .collection('participants')
        .doc(userId);

    const profileRef =
      db.collection('users')
        .doc(userId);

    if (
      accept &&
      await blockedEither(
        uid,
        userId,
      )
    ) {
      throw new HttpsError(
        'permission-denied',
        'Não é possível aceitar uma solicitação entre usuários bloqueados.',
      );
    }

    let title =
      'Atividade';

    let requesterName =
      'Participante';

    await db.runTransaction(
      async (transaction) => {
        const [
          activitySnapshot,
          requestSnapshot,
          participantSnapshot,
          profileSnapshot,
        ] = await Promise.all([
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
          !activitySnapshot.exists
        ) {
          throw new HttpsError(
            'not-found',
            'Atividade não encontrada.',
          );
        }

        const activity =
          activitySnapshot.data();

        title =
          String(
            activity.title ||
              'Atividade',
          );

        if (
          String(
            activity.creatorId ||
              '',
          ) !== uid
        ) {
          throw new HttpsError(
            'permission-denied',
            'Somente o organizador pode responder.',
          );
        }

        if (
          !requestSnapshot.exists
        ) {
          throw new HttpsError(
            'not-found',
            'Solicitação não encontrada.',
          );
        }

        const joinRequest =
          requestSnapshot.data() ||
          {};

        if (
          joinRequest.status !==
          'pending'
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Esta solicitação já foi respondida.',
          );
        }

        requesterName =
          String(
            joinRequest.name ||
            profileSnapshot
              .data()?.name ||
            'Participante',
          ).trim() ||
          'Participante';

        if (
          accept &&
          !participantSnapshot
            .exists
        ) {
          if (
            activity.status !==
            'active'
          ) {
            throw new HttpsError(
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
            throw new HttpsError(
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
                  .increment(1),

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

    return {
      ok: true,
    };
  });


// ============================================================
// DENÚNCIAS
// ============================================================

exports.reportContent =
  onCall(async (request) => {
    const uid =
      requireAuth(request);

    const targetType =
      requiredString(
        request.data?.targetType,
        'targetType',
        30,
      );

    const targetId =
      requiredString(
        request.data?.targetId,
        'targetId',
        300,
      );

    const reason =
      requiredString(
        request.data?.reason,
        'reason',
        120,
      );

    const details =
      String(
        request.data?.details ||
          '',
      )
        .trim()
        .slice(0, 1000);

    if (
      ![
        'user',
        'activity',
        'chat',
      ].includes(targetType)
    ) {
      throw new HttpsError(
        'invalid-argument',
        'Tipo de denúncia inválido.',
      );
    }

    if (
      targetType === 'user' &&
      targetId === uid
    ) {
      throw new HttpsError(
        'invalid-argument',
        'Você não pode denunciar o próprio perfil.',
      );
    }

    await db
      .collection('reports')
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

    return {
      ok: true,
    };
  });


// ============================================================
// EXCLUIR CONTA
// ============================================================

exports.deleteAccount =
  onCall(async (request) => {
    const uid =
      requireAuth(request);

    const userRef =
      db.collection('users')
        .doc(uid);

    const createdActivities =
      await db
        .collection('activities')
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
      const data =
        activity.data();

      await activity.ref.update({
        creatorName:
          'Usuário excluído',

        status:
          data.status ===
          'active'
            ? 'cancelled'
            : data.status,

        updatedAt:
          FieldValue
            .serverTimestamp(),
      });
    }

    await db.recursiveDelete(
      userRef,
    );

    await admin.auth()
      .deleteUser(uid);

    return {
      ok: true,
    };
  });


// ============================================================
// NOVA MENSAGEM NO CHAT
// ============================================================

exports.onChatMessage =
  onDocumentCreated(
    'activities/{activityId}/chat/{messageId}',
    async (event) => {
      const message =
        event.data?.data();

      if (!message) {
        return;
      }

      const {
        activityId,
      } = event.params;

      const senderId =
        String(
          message.senderId ||
            '',
        );

      const activityRef =
        db.collection(
          'activities',
        ).doc(
          activityId,
        );

      const [
        activitySnapshot,
        participants,
      ] = await Promise.all([
        activityRef.get(),

        activityRef
          .collection(
            'participants',
          )
          .get(),
      ]);

      const title =
        String(
          activitySnapshot
            .data()?.title ||
            'Atividade',
        );

      const senderName =
        String(
          message.senderName ||
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
            (document) =>
              document.id !==
              senderId,
          )
          .map(
            (document) =>
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
                    senderId,
                },
              ),
          ),
      );
    },
  );


// ============================================================
// DETECTAR ALTERAÇÕES IMPORTANTES NA ATIVIDADE
// ============================================================

function timestampValue(
  value,
) {
  if (
    value instanceof
    Timestamp
  ) {
    return value.toMillis();
  }

  return value ?? null;
}

function changed(
  before,
  after,
  key,
) {
  return (
    JSON.stringify(
      timestampValue(
        before[key],
      ),
    ) !==
    JSON.stringify(
      timestampValue(
        after[key],
      ),
    )
  );
}

exports.onActivityUpdated =
  onDocumentUpdated(
    'activities/{activityId}',
    async (event) => {
      const before =
        event.data?.before
          .data();

      const after =
        event.data?.after
          .data();

      if (
        !before ||
        !after
      ) {
        return;
      }

      const {
        activityId,
      } = event.params;

      const cancelled =
        before.status !==
          'cancelled' &&
        after.status ===
          'cancelled';

      const importantKeys = [
        'title',
        'description',
        'category',
        'address',
        'latitude',
        'longitude',
        'startsAt',
        'maxParticipants',
        'isPrivate',
      ];

      const importantChange =
        importantKeys.some(
          (key) =>
            changed(
              before,
              after,
              key,
            ),
        );

      if (
        !cancelled &&
        !importantChange
      ) {
        return;
      }

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

      const creatorId =
        String(
          after.creatorId ||
            '',
        );

      const title =
        String(
          after.title ||
            'Atividade',
        );

      await Promise.all(
        participants.docs
          .filter(
            (document) =>
              document.id !==
              creatorId,
          )
          .map(
            (document) =>
              notify(
                document.id,
                {
                  type:
                    cancelled
                      ? 'activity_cancelled'
                      : 'activity_updated',

                  title:
                    cancelled
                      ? 'Atividade cancelada'
                      : 'Atividade atualizada',

                  body:
                    title,

                  activityId,

                  actorId:
                    creatorId,
                },
              ),
          ),
      );
    },
  );