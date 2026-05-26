import * as admin from "firebase-admin";
import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

// Inicializar el SDK de Firebase Admin de forma segura
admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();

function getPrefix(auth?: any): string {
  return auth?.token?.email?.startsWith("demo.") ? "demo_" : "";
}

function getCol(colName: string, auth?: any): admin.firestore.CollectionReference {
  const prefix = getPrefix(auth);
  return db.collection(`${prefix}${colName}`);
}

/**
 * -----------------------------------------------------------------------------
 * 1. GESTIÓN DE ROLES DINÁMICOS Y CUSTOM CLAIMS (RBAC)
 * -----------------------------------------------------------------------------
 */

/**
 * Función Auxiliar: Sincroniza el Custom Claim 'role' del usuario en Auth
 * basándose en su documento de perfil en Firestore.
 */
async function syncUserClaims(uid: string, role: string, isApprovedVet?: boolean, branchId?: string): Promise<void> {
  // v1.1.0: RBAC Fluido — los claims granulares se derivan del rol + estado de aprobación.
  // canPerformMedical: vets aprobados y admins pueden acceder a registros médicos/conductuales.
  // canPerformServices: vets aprobados y admins pueden acceder a datos de estética/guardería.
  // isAdmin: acceso total, incluyendo edición/borrado de evaluaciones conductuales.
  // branchId: aislamiento multi-tenant; se propaga desde el documento Firestore al JWT.
  const isVetApproved  = role === "vet" && (isApprovedVet === true);
  const isAdminRole    = role === "admin";
  const isServiceStaff = role === "groomer" || role === "caretaker";

  const claims: Record<string, boolean | string> = {
    role:               role,
    isApprovedVet:      isApprovedVet || false,
    canPerformMedical:  isVetApproved || isAdminRole,
    canPerformServices: isVetApproved || isAdminRole || isServiceStaff,
    isAdmin:            isAdminRole,
  };

  // branchId solo se inyecta cuando está presente; los usuarios sin sucursal
  // (owners, vets independientes) no llevan este claim en su JWT.
  if (branchId) {
    claims.branchId = branchId;
  }

  await auth.setCustomUserClaims(uid, claims);
  console.log(`[RBAC] Custom Claims actualizados para ${uid}:`, claims);
}

/**
 * TRIGGER 1B (Firestore): onUserProfileCreated
 * Escucha la creación de perfiles en la colección '/users'.
 * Sincroniza los Custom Claims si el documento se creó con un rol específico.
 */
export const onUserProfileCreatedV2 = onDocumentCreated("users/{userId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const uid = event.params.userId;
  const data = snapshot.data();
  let role = data?.role || "owner";
  const isApprovedVet = data?.isApprovedVet || false;
  let branchId = data?.branchId as string | undefined;

  // Auto-link: si existe una invitación pendiente para este email, aplicarla
  const email = data?.email as string | undefined;
  if (email && role === "owner") {
    try {
      const inviteSnap = await db.collection("staff_invitations")
        .where("email", "==", email)
        .where("status", "==", "pending")
        .limit(1)
        .get();
      if (!inviteSnap.empty) {
        const invite = inviteSnap.docs[0];
        const inviteData = invite.data();
        role = inviteData.role;
        branchId = inviteData.branchId;
        await db.collection("users").doc(uid).update({ role, branchId });
        await invite.ref.update({
          status: "accepted",
          acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
          acceptedByUid: uid,
        });
        console.log(`[Invite] Auto-linked ${email} as ${role} in branch ${branchId}`);
      }
    } catch (err) {
      console.error(`[Invite] Error linking invitation for ${email}:`, err);
    }
  }

  console.log(`[Firestore Trigger] Perfil creado para ${uid}. Sincronizando rol: ${role}${branchId ? `, sucursal: ${branchId}` : ""}`);
  try {
    await syncUserClaims(uid, role, isApprovedVet, branchId);
  } catch (error) {
    console.error(`[Firestore Trigger] Error sincronizando claims al crear perfil de ${uid}:`, error);
  }
});

export const onUserProfileCreatedDemo = onDocumentCreated("demo_users/{userId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;
  const uid = event.params.userId;
  const data = snapshot.data();
  let role = data?.role || "owner";
  const isApprovedVet = data?.isApprovedVet || false;
  let branchId = data?.branchId as string | undefined;

  // Auto-link demo: si existe una invitación pendiente para este email, aplicarla
  const email = data?.email as string | undefined;
  if (email && role === "owner") {
    try {
      const inviteSnap = await db.collection("demo_staff_invitations")
        .where("email", "==", email)
        .where("status", "==", "pending")
        .limit(1)
        .get();
      if (!inviteSnap.empty) {
        const invite = inviteSnap.docs[0];
        const inviteData = invite.data();
        role = inviteData.role;
        branchId = inviteData.branchId;
        await db.collection("demo_users").doc(uid).update({ role, branchId });
        await invite.ref.update({
          status: "accepted",
          acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
          acceptedByUid: uid,
        });
        console.log(`[Invite Demo] Auto-linked ${email} as ${role} in branch ${branchId}`);
      }
    } catch (err) {
      console.error(`[Invite Demo] Error linking invitation for ${email}:`, err);
    }
  }

  console.log(`[Firestore Trigger Demo] Perfil creado para ${uid}. Sincronizando rol: ${role}${branchId ? `, sucursal: ${branchId}` : ""}`);
  try {
    await syncUserClaims(uid, role, isApprovedVet, branchId);
  } catch (error) {
    console.error(`[Firestore Trigger Demo] Error sincronizando claims al crear perfil de ${uid}:`, error);
  }
});

/**
 * TRIGGER 1C (Firestore): onUserProfileUpdated
 * Escucha actualizaciones en '/users' (útil cuando el Admin aprueba a un Veterinario).
 * Sincroniza los Custom Claims reactivamente.
 */
export const onUserProfileUpdatedV2 = onDocumentUpdated("users/{userId}", async (event) => {
  const change = event.data;
  if (!change) return;
  const uid = event.params.userId;
  const beforeData = change.before.data();
  const afterData = change.after.data();

  const roleChanged = beforeData?.role !== afterData?.role;
  const approvalChanged = beforeData?.isApprovedVet !== afterData?.isApprovedVet;
  const branchChanged = beforeData?.branchId !== afterData?.branchId;

  if (roleChanged || approvalChanged || branchChanged) {
    const newRole = afterData?.role || "owner";
    const isApprovedVet = afterData?.isApprovedVet || false;
    const branchId = afterData?.branchId as string | undefined;

    console.log(`[Firestore Trigger] Cambio de rol/aprobación/sucursal detectado para ${uid}. Actualizando Claims.`);
    try {
      await syncUserClaims(uid, newRole, isApprovedVet, branchId);
    } catch (error) {
      console.error(`[Firestore Trigger] Error al actualizar claims tras modificación de ${uid}:`, error);
    }

    // Asignar trial de 6 meses al aprobar un vet por primera vez
    if (approvalChanged && isApprovedVet && !beforeData?.isApprovedVet) {
      const currentTier = afterData?.subscriptionTier;
      if (!currentTier || currentTier === "free") {
        const trialEndsAt = new Date();
        trialEndsAt.setMonth(trialEndsAt.getMonth() + 6);
        await db.collection("users").doc(uid).update({
          subscriptionTier: "trial",
          trialEndsAt: admin.firestore.Timestamp.fromDate(trialEndsAt),
        });
        console.log(`[Subscription] Trial de 6 meses asignado a vet ${uid} hasta ${trialEndsAt.toISOString()}`);
      }
    }
  }
});

export const onUserProfileUpdatedDemo = onDocumentUpdated("demo_users/{userId}", async (event) => {
  const change = event.data;
  if (!change) return;
  const uid = event.params.userId;
  const beforeData = change.before.data();
  const afterData = change.after.data();

  const roleChanged = beforeData?.role !== afterData?.role;
  const approvalChanged = beforeData?.isApprovedVet !== afterData?.isApprovedVet;
  const branchChanged = beforeData?.branchId !== afterData?.branchId;

  if (roleChanged || approvalChanged || branchChanged) {
    const newRole = afterData?.role || "owner";
    const isApprovedVet = afterData?.isApprovedVet || false;
    const branchId = afterData?.branchId as string | undefined;

    console.log(`[Firestore Trigger Demo] Cambio de rol/aprobación/sucursal detectado para ${uid}. Actualizando Claims.`);
    try {
      await syncUserClaims(uid, newRole, isApprovedVet, branchId);
    } catch (error) {
      console.error(`[Firestore Trigger Demo] Error al actualizar claims tras modificación de ${uid}:`, error);
    }

    // Asignar trial de 6 meses al aprobar un vet demo por primera vez
    if (approvalChanged && isApprovedVet && !beforeData?.isApprovedVet) {
      const currentTier = afterData?.subscriptionTier;
      if (!currentTier || currentTier === "free") {
        const trialEndsAt = new Date();
        trialEndsAt.setMonth(trialEndsAt.getMonth() + 6);
        await db.collection("demo_users").doc(uid).update({
          subscriptionTier: "trial",
          trialEndsAt: admin.firestore.Timestamp.fromDate(trialEndsAt),
        });
      }
    }
  }
});


/**
 * -----------------------------------------------------------------------------
 * 2. SISTEMA DE PERMISOS DINÁMICOS POR CÓDIGO QR
 * -----------------------------------------------------------------------------
 */

interface GenerateQrPayload {
  petId: string;
  ownerId: string;
  // null = sin límite (el dueño revoca manualmente) | número = duración en minutos
  durationMinutes?: number | null;
}

/**
 * CALLABLE 2: generateQrToken
 * Invocable únicamente por el Dueño ('owner') de la mascota.
 * Genera un código token de un solo uso con validez de exactamente 15 minutos.
 */
export const generateQrToken = onCall<GenerateQrPayload>(async (request) => {
  // 1. Validar autenticación
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const callerUid = request.auth.uid;
  const { petId, ownerId } = request.data;
  // null = sin límite; número positivo = minutos de acceso
  const durationMinutes: number | null = request.data.durationMinutes ?? null;

  if (!petId || !ownerId) {
    throw new HttpsError("invalid-argument", "Los campos 'petId' y 'ownerId' son obligatorios.");
  }

  if (durationMinutes !== null && (typeof durationMinutes !== "number" || durationMinutes <= 0)) {
    throw new HttpsError("invalid-argument", "durationMinutes debe ser un número positivo o null.");
  }

  // 2. Validar que el llamante es realmente el dueño de la mascota o un Administrador (RBAC)
  const isOwner = callerUid === ownerId;
  const isAdmin = request.auth.token.role === "admin";

  if (!isOwner && !isAdmin) {
    throw new HttpsError("permission-denied", "No tienes permisos para generar pases QR de esta mascota.");
  }

  try {
    // 3. Validar existencia de la mascota y correspondencia del dueño en Firestore
    const petDoc = await getCol("pets", request.auth).doc(petId).get();
    if (!petDoc.exists) {
      throw new HttpsError("not-found", "La mascota especificada no existe.");
    }

    const petData = petDoc.data();
    if (petData?.ownerId !== ownerId) {
      throw new HttpsError("permission-denied", "Inconsistencia de propiedad detectada.");
    }

    // 4. Crear el token único con alta entropía
    const tokenRef = getCol("qr_tokens", request.auth).doc();
    const tokenId = tokenRef.id;

    const now = Date.now();
    const expiresAt = new Date(now + 15 * 60 * 1000); // +15 Minutos (validez del QR)

    const tokenPayload = {
      tokenId: tokenId,
      petId: petId,
      ownerId: ownerId,
      vetId: null,
      status: "pending",
      durationMinutes: durationMinutes,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      leaseExpiresAt: null,
    };

    await tokenRef.set(tokenPayload);
    const durationLabel = durationMinutes === null ? "sin límite" : `${durationMinutes} min`;
    console.log(`[QR Service] Token QR generado: ${tokenId} | Duración: ${durationLabel} (Expira escáner: ${expiresAt.toISOString()})`);

    return {
      success: true,
      tokenId: tokenId,
      expiresAt: expiresAt.getTime(),
      durationMinutes: durationMinutes,
    };

  } catch (error: any) {
    console.error("[QR Service] Error en generateQrToken:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Error al procesar la solicitud de generación de QR.");
  }
});


interface ValidateQrPayload {
  tokenId: string;
  vetId: string;
}

/**
 * CALLABLE 3: validateQrLease
 * Invocable únicamente por Veterinarios ('vet') aprobados.
 * Valida el código QR y otorga un arrendamiento de acceso clínico de exactamente 2 horas.
 */
export const validateQrLease = onCall<ValidateQrPayload>(async (request) => {
  // 1. Validar autenticación
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const callerUid = request.auth.uid;
  const callerClaims = request.auth.token;
  const { tokenId, vetId } = request.data;

  if (!tokenId || !vetId) {
    throw new HttpsError("invalid-argument", "Los campos 'tokenId' y 'vetId' son obligatorios.");
  }

  // 2. Validar que sea Veterinario verificado
  let isVet = callerClaims.role === "vet";
  let isApproved = callerClaims.isApprovedVet === true;
  const isAdmin = callerClaims.role === "admin";

  // Fallback: Si el token JWT tiene latencia de propagación, comprobar la base de datos Firestore en tiempo real
  if ((!isVet || !isApproved) && !isAdmin) {
    try {
      const userDoc = await getCol("users", request.auth).doc(callerUid).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData?.role === "vet") {
          isVet = true;
        }
        if (userData?.isApprovedVet === true) {
          isApproved = true;
        }
      }
    } catch (e) {
      console.error("[QR Service] Error consultando fallback de rol en Firestore:", e);
    }
  }

  if ((!isVet || !isApproved) && !isAdmin) {
    throw new HttpsError("permission-denied", "Solo veterinarios aprobados pueden escanear QR.");
  }

  if (callerUid !== vetId && !isAdmin) {
    throw new HttpsError("permission-denied", "Inconsistencia en la identificación del veterinario.");
  }

  // 2.5 Verificar límite de pacientes activos según tier de suscripción
  if (!isAdmin) {
    const vetProfileDoc = await getCol("users", request.auth).doc(callerUid).get();
    const subscriptionTier = vetProfileDoc.data()?.subscriptionTier || "free";
    const maxActivePatients: number =
      subscriptionTier === "free" ? 5 :
      subscriptionTier === "basico" ? 25 :
      999999; // trial, profesional, premium = ilimitado

    if (maxActivePatients < 999999) {
      const activeSnap = await getCol("qr_tokens", request.auth)
        .where("vetId", "==", callerUid)
        .where("status", "==", "active")
        .get();
      if (activeSnap.size >= maxActivePatients) {
        throw new HttpsError(
          "resource-exhausted",
          `Has alcanzado el límite de ${maxActivePatients} pacientes activos de tu plan. Actualiza tu suscripción para continuar.`
        );
      }
    }
  }

  try {
    // 3. Buscar el token en Firestore
    const tokenRef = getCol("qr_tokens", request.auth).doc(tokenId);
    const tokenDoc = await tokenRef.get();

    if (!tokenDoc.exists) {
      throw new HttpsError("not-found", "El código QR escaneado no es válido.");
    }

    const tokenData = tokenDoc.data();

    // 4. Validaciones de expiración y estado
    if (tokenData?.status !== "pending") {
      throw new HttpsError("failed-precondition", `Este código QR ya no está disponible.`);
    }

    const now = admin.firestore.Timestamp.now();
    const expiresAt = tokenData.expiresAt as admin.firestore.Timestamp;

    if (now.toMillis() > expiresAt.toMillis()) {
      // Marcar como expirado para auditoría
      await tokenRef.update({ status: "expired" });
      throw new HttpsError("deadline-exceeded", "El código QR ha expirado.");
    }

    // 5. Configurar duración del arrendamiento
    const durationMinutes: number | null = tokenData.durationMinutes ?? null;
    // null = sin límite → 365 días (el dueño revoca manualmente)
    const leaseDurationMs = durationMinutes !== null
      ? durationMinutes * 60 * 1000
      : 365 * 24 * 60 * 60 * 1000;
    const leaseExpiresAt = new Date(Date.now() + leaseDurationMs);
    const leaseExpiresTimestamp = admin.firestore.Timestamp.fromDate(leaseExpiresAt);

    // 6. Ejecutar en una transacción atómica para asegurar la consistencia del arrendamiento
    await db.runTransaction(async (transaction) => {
      // A. Actualizar token primario
      transaction.update(tokenRef, {
        status: "active",
        vetId: vetId,
        leaseExpiresAt: leaseExpiresTimestamp,
      });

      // B. Crear el documento índice compuesto [vetId_petId]
      // Esto permite validar el permiso en reglas de seguridad Firestore en complejidad O(1)
      const compositeDocId = `${vetId}_${tokenData.petId}`;
      const compositeRef = getCol("qr_tokens", request.auth).doc(compositeDocId);

      transaction.set(compositeRef, {
        tokenId: tokenId,
        petId: tokenData.petId,
        ownerId: tokenData.ownerId,
        vetId: vetId,
        status: "active",
        durationMinutes: durationMinutes,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        leaseExpiresAt: leaseExpiresTimestamp,
      });
    });

    const durationLabel = durationMinutes === null ? "sin límite" : `${durationMinutes} min`;
    console.log(`[QR Service] Arrendamiento creado (${durationLabel}). Vet ${vetId} -> Mascota ${tokenData.petId}`);

    return {
      success: true,
      petId: tokenData.petId,
      durationMinutes: durationMinutes,
      leaseExpiresAt: durationMinutes === null ? null : leaseExpiresAt.getTime(),
    };

  } catch (error: any) {
    console.error("[QR Service] Error en validateQrLease:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Error al procesar el arrendamiento clínico.");
  }
});


/**
 * -----------------------------------------------------------------------------
 * 3. SISTEMA DE PAGOS POR SPEI — APROBACIÓN DE COMPROBANTE
 * -----------------------------------------------------------------------------
 */

interface ApproveComprobantePayload {
  paymentId: string;
}

/**
 * CALLABLE 4: approveComprobante
 * Invocable únicamente por el Veterinario dueño del cobro.
 * Valida el comprobante SPEI y marca el pago como 'paid' vía Admin SDK,
 * lo que bypasea las Firestore Security Rules (los clientes no pueden hacer esto).
 */
export const approveComprobante = onCall<ApproveComprobantePayload>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const callerUid = request.auth.uid;
  const callerClaims = request.auth.token;
  const { paymentId } = request.data;

  if (!paymentId) {
    throw new HttpsError("invalid-argument", "El campo 'paymentId' es obligatorio.");
  }

  // Validar rol de veterinario aprobado (con fallback a Firestore igual que validateQrLease)
  let isVet = callerClaims.role === "vet";
  let isApproved = callerClaims.isApprovedVet === true;
  const isAdmin = callerClaims.role === "admin";

  if ((!isVet || !isApproved) && !isAdmin) {
    try {
      const userDoc = await getCol("users", request.auth).doc(callerUid).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData?.role === "vet") isVet = true;
        if (userData?.isApprovedVet === true) isApproved = true;
      }
    } catch (e) {
      console.error("[Payments] Error en fallback de rol:", e);
    }
  }

  if ((!isVet || !isApproved) && !isAdmin) {
    throw new HttpsError("permission-denied", "Solo veterinarios aprobados pueden aprobar comprobantes.");
  }

  try {
    const paymentRef = getCol("payments", request.auth).doc(paymentId);
    const paymentDoc = await paymentRef.get();

    if (!paymentDoc.exists) {
      throw new HttpsError("not-found", "El pago especificado no existe.");
    }

    const paymentData = paymentDoc.data()!;

    if (!isAdmin && paymentData.vetId !== callerUid) {
      throw new HttpsError("permission-denied", "Este cobro no te pertenece.");
    }

    if (paymentData.status !== "pending_review") {
      throw new HttpsError("failed-precondition", `El pago tiene estado '${paymentData.status}', se requiere 'pending_review'.`);
    }

    // Admin SDK bypasea las Security Rules: solo el backend puede marcar como 'paid'
    await paymentRef.update({
      status: "paid",
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[Payments] Comprobante aprobado por ${callerUid} para pago ${paymentId}`);
    return { success: true };

  } catch (error: any) {
    console.error("[Payments] Error en approveComprobante:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", "Error al aprobar el comprobante.");
  }
});

interface RevokeVetAccessPayload {
  petId: string;
  vetId: string;
}

/**
 * CALLABLE 4B: revokeVetAccess
 * Invocable por el Dueño ('owner') de la mascota o un Administrador.
 * Elimina el arrendamiento QR activo, revocando el acceso del veterinario al expediente clínico.
 */
export const revokeVetAccess = onCall<RevokeVetAccessPayload>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const callerUid = request.auth.uid;
  const { petId, vetId } = request.data;

  if (!petId || !vetId) {
    throw new HttpsError("invalid-argument", "Los campos 'petId' y 'vetId' son obligatorios.");
  }

  // Validar que el caller es el dueño de la mascota o un Admin
  const petDoc = await getCol("pets", request.auth).doc(petId).get();
  if (!petDoc.exists) {
    throw new HttpsError("not-found", "Mascota no encontrada.");
  }

  const isOwner = petDoc.data()?.ownerId === callerUid;
  const isAdmin = request.auth.token.role === "admin";

  if (!isOwner && !isAdmin) {
    throw new HttpsError("permission-denied", "Solo el dueño de la mascota puede revocar accesos.");
  }

  // Eliminar el documento índice compuesto que habilita el acceso en Firestore rules
  const compositeDocId = `${vetId}_${petId}`;
  await getCol("qr_tokens", request.auth).doc(compositeDocId).delete();

  console.log(`[QR Service] Acceso revocado. Vet ${vetId} ya no puede acceder a mascota ${petId}`);
  return { success: true };
});

interface SetupDemoPayload {
  role: string;
  displayName: string;
}

const DEMO_PET_IDS = ["pet_carlos_001", "pet_carlos_002", "pet_sofia_001"] as const;

/**
 * Deletes all documents in a subcollection (used for cleanup).
 */
async function deleteSubcollectionDocs(
  parentRef: admin.firestore.DocumentReference,
  subcollection: string
): Promise<admin.firestore.DocumentReference[]> {
  const snap = await parentRef.collection(subcollection).get();
  return snap.docs.map((d) => d.ref);
}

/**
 * Resets the demo environment to a clean, richly-seeded state on every demo login.
 * Deletes all user-generated data (medical records, vaccination entries, QR tokens,
 * notifications) and replaces them with fresh seed data.
 */
async function cleanupAndReseedDemo(uid: string): Promise<void> {
  const nowMs = Date.now();
  const day = 24 * 60 * 60 * 1000;
  const ts = (offsetMs: number) => admin.firestore.Timestamp.fromMillis(nowMs + offsetMs);

  // ── 1. Collect all refs to delete ────────────────────────────────────────
  // Clear rate-limit attempt log so demo users never get throttled between sessions
  db.collection("demo_link_attempts").doc(uid).delete().catch(() => undefined);

  const [notifSnap, qrSnap, reservationSnap, ...subcollectionRefGroups] = await Promise.all([
    db.collection("demo_users").doc(uid).collection("notifications").get(),
    db.collection("demo_qr_tokens").where("petId", "in", [...DEMO_PET_IDS]).get(),
    db.collection("demo_boarding_reservations").where("petId", "in", [...DEMO_PET_IDS]).get(),
    ...DEMO_PET_IDS.flatMap((petId) => {
      const petRef = db.collection("demo_pets").doc(petId);
      return [
        deleteSubcollectionDocs(petRef, "medical_history"),
        deleteSubcollectionDocs(petRef, "vaccination_card"),
      ];
    }),
  ]);

  const toDelete: admin.firestore.DocumentReference[] = [
    ...notifSnap.docs.map((d) => d.ref),
    ...qrSnap.docs.map((d) => d.ref),
    ...reservationSnap.docs.map((d) => d.ref),
    ...(subcollectionRefGroups as admin.firestore.DocumentReference[][]).flat(),
  ];

  for (let i = 0; i < toDelete.length; i += 499) {
    const batch = db.batch();
    toDelete.slice(i, i + 499).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }

  // ── 2. Ensure pet_sofia_001 exists in demo_pets ──────────────────────────
  await db.collection("demo_pets").doc("pet_sofia_001").set({
    name: "Toby",
    species: "Perro",
    breed: "Border Collie",
    age: 24,
    photoUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/18/Dog_Breeds.jpg/320px-Dog_Breeds.jpg",
    allergies: [],
    chronicConditions: ["Displasia leve de cadera"],
    ownerId: "demo_sofia_placeholder",
    ownerName: "Sofía Castro (Demo)",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // ── 3. Reset / create seed payment documents ─────────────────────────────
  const paymentBatch = db.batch();
  const seedPayments = [
    {
      id: "demo_pay_001",
      petId: "pet_carlos_001", petName: "Rocky",
      ownerId: "demo_owner_placeholder", ownerName: "Carlos Mendoza (Demo)",
      vetId: "demo_vet_placeholder",     vetName: "Dr. Alejandro Méndez (Demo)",
      services: [{ id: "demo_svc_001", name: "Consulta General", price: 450, durationMinutes: 30 }],
      totalAmount: 450,
      status: "pending",
      allowedPaymentMethods: { spei: true, cash: true, terminal: false },
      createdAt: ts(-2 * day),
    },
    {
      id: "demo_pay_002",
      petId: "pet_carlos_002", petName: "Luna",
      ownerId: "demo_owner_placeholder", ownerName: "Carlos Mendoza (Demo)",
      vetId: "demo_vet_placeholder",     vetName: "Dr. Alejandro Méndez (Demo)",
      services: [
        { id: "demo_svc_002", name: "Vacunación",      price: 250, durationMinutes: 15 },
        { id: "demo_svc_003", name: "Desparasitación", price: 180, durationMinutes: 20 },
      ],
      totalAmount: 430,
      status: "pending",
      allowedPaymentMethods: { spei: true, cash: true, terminal: false },
      createdAt: ts(-5 * day),
    },
    {
      id: "demo_pay_003",
      petId: "pet_sofia_001", petName: "Toby",
      ownerId: "demo_sofia_placeholder", ownerName: "Sofía Castro (Demo)",
      vetId: "demo_vet_placeholder",     vetName: "Dr. Alejandro Méndez (Demo)",
      services: [{ id: "demo_svc_005", name: "Análisis Clínico de Sangre", price: 650, durationMinutes: 45 }],
      totalAmount: 650,
      status: "pending",
      allowedPaymentMethods: { spei: true, cash: true, terminal: false },
      createdAt: ts(-1 * day),
    },
  ];
  for (const { id, ...data } of seedPayments) {
    paymentBatch.set(db.collection("demo_payments").doc(id), data);
  }
  await paymentBatch.commit();

  // ── 4. Seed vaccination card entries ─────────────────────────────────────
  const vacBatch = db.batch();
  const vacSeeds: Array<{ petId: string; [key: string]: unknown }> = [
    // Rocky — Antirrábica (up to date)
    { petId: "pet_carlos_001", vaccineType: "rabies", name: "Antirrábica", type: "vaccine",
      appliedAt: ts(-180 * day), nextApplicationAt: ts(185 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, lot: "LOT-2025-001", notes: "Sin reacciones adversas." },
    // Rocky — Bordetella (obligatoria para guardería canina)
    { petId: "pet_carlos_001", vaccineType: "bordetella", name: "Bordetella (Tos de las Perreras)", type: "vaccine",
      appliedAt: ts(-200 * day), nextApplicationAt: ts(165 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, lot: "LOT-2025-003", notes: "Aplicación intranasal." },
    // Rocky — Múltiple Canina (due in ~15 days — triggers 7-day reminder)
    { petId: "pet_carlos_001", vaccineType: "distemper", name: "Múltiple Canina (DHPP)", type: "vaccine",
      appliedAt: ts(-350 * day), nextApplicationAt: ts(15 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, lot: "LOT-2024-088", notes: "Refuerzo anual." },
    // Rocky — Desparasitación
    { petId: "pet_carlos_001", name: "Desparasitación Interna (Milbemax)", type: "dewormer",
      appliedAt: ts(-60 * day), nextApplicationAt: ts(120 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, notes: "Tratamiento con Milbemax." },
    // Luna — Triple Felina (obligatoria para guardería felina)
    { petId: "pet_carlos_002", vaccineType: "tripleFelineFHCP", name: "Triple Felina (HCP)", type: "vaccine",
      appliedAt: ts(-240 * day), nextApplicationAt: ts(125 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, lot: "LOT-2025-042", notes: "Refuerzo anual aplicado." },
    // Luna — Antirrábica (obligatoria por ley para todas las especies)
    { petId: "pet_carlos_002", vaccineType: "rabies", name: "Antirrábica", type: "vaccine",
      appliedAt: ts(-200 * day), nextApplicationAt: ts(165 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, lot: "LOT-2025-041", notes: "Sin reacciones adversas." },
    // Luna — Leucemia Felina (due in ~45 days)
    { petId: "pet_carlos_002", vaccineType: "felineLeukemia", name: "Leucemia Felina (FeLV)", type: "vaccine",
      appliedAt: ts(-320 * day), nextApplicationAt: ts(45 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, lot: "LOT-2024-199", notes: "Gato con contacto exterior, vacuna prioritaria." },
    // Toby — Antirrábica
    { petId: "pet_sofia_001", vaccineType: "rabies", name: "Antirrábica", type: "vaccine",
      appliedAt: ts(-90 * day), nextApplicationAt: ts(275 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, lot: "LOT-2025-077", notes: "Vacuna aplicada sin incidentes." },
    // Toby — Bordetella (obligatoria para guardería canina)
    { petId: "pet_sofia_001", vaccineType: "bordetella", name: "Bordetella (Tos de las Perreras)", type: "vaccine",
      appliedAt: ts(-85 * day), nextApplicationAt: ts(280 * day),
      appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
      verifiedByVet: true, lot: "LOT-2025-078", notes: "Aplicación intranasal, sin incidentes." },
  ];
  for (const { petId, ...entry } of vacSeeds) {
    vacBatch.set(db.collection("demo_pets").doc(petId as string).collection("vaccination_card").doc(), entry);
  }
  await vacBatch.commit();

  // ── 5. Seed medical history entries ──────────────────────────────────────
  const medBatch = db.batch();
  const medSeeds: Array<{ petId: string; [key: string]: unknown }> = [
    // Rocky — Consulta General
    { petId: "pet_carlos_001", date: ts(-30 * day), reason: "Consulta General",
      weightKg: 32.5, justification: "Chequeo de rutina semestral.",
      diagnosis: "Paciente en buen estado general. Ligero sobrepeso.",
      treatment: "Dieta balanceada para raza grande. Ejercicio 45 min/día.",
      prescription: "", vetId: "demo_vet_placeholder", vetName: "Dr. Alejandro Méndez (Demo)",
      notes: "Dueño reporta buena ingesta de agua y apetito normal.", attachments: [] },
    // Rocky — Limpieza Dental
    { petId: "pet_carlos_001", date: ts(-90 * day), reason: "Procedimiento",
      weightKg: 33.0, justification: "Sarro moderado en revisión previa.",
      diagnosis: "Sarro moderado en piezas posteriores. Sin caries.",
      treatment: "Limpieza dental ultrasónica bajo anestesia. Pulido de esmalte.",
      prescription: "Amoxicilina 250mg c/12h por 5 días (profilaxis postoperatoria).",
      vetId: "demo_vet_placeholder", vetName: "Dr. Alejandro Méndez (Demo)",
      notes: "Recuperación sin complicaciones. Cepillado semanal recomendado.", attachments: [] },
    // Luna — Consulta Alergia
    { petId: "pet_carlos_002", date: ts(-45 * day), reason: "Consulta General",
      weightKg: 4.2, justification: "Estornudos frecuentes y secreción nasal.",
      diagnosis: "Rinitis alérgica leve. Asociada a exposición a polen.",
      treatment: "Antihistamínico oral por 7 días. Evitar áreas con alta concentración de plantas.",
      prescription: "Loratadina 5mg 1/2 comprimido c/24h por 7 días.",
      vetId: "demo_vet_placeholder", vetName: "Dr. Alejandro Méndez (Demo)",
      notes: "Alergia conocida al polen, documentada en ficha del paciente.", attachments: [] },
    // Toby — Análisis Clínico
    { petId: "pet_sofia_001", date: ts(-60 * day), reason: "Análisis Clínico",
      weightKg: 18.8, justification: "Control semestral y seguimiento de displasia.",
      diagnosis: "Análisis de sangre: valores dentro del rango normal. Displasia de cadera Grado I.",
      treatment: "Suplemento de condroitina y glucosamina. Ejercicio de bajo impacto.",
      prescription: "Rimadyl 25mg c/24h en días de alta actividad.",
      vetId: "demo_vet_placeholder", vetName: "Dr. Alejandro Méndez (Demo)",
      notes: "Seguimiento en 6 meses. Radiografía de cadera adjunta en expediente.", attachments: [] },
  ];
  for (const { petId, ...record } of medSeeds) {
    medBatch.set(db.collection("demo_pets").doc(petId as string).collection("medical_history").doc(), record);
  }
  await medBatch.commit();

  // ── 6. Seed boarding reservations ────────────────────────────────────────
  const now = admin.firestore.Timestamp.now();

  const reservationBatch = db.batch();
  const seedReservations = [
    // Rocky — completada hace 2 semanas
    {
      id: "demo_res_001",
      petId: "pet_carlos_001", petName: "Rocky",
      ownerId: "demo_owner_placeholder", ownerName: "Carlos Mendoza (Demo)",
      branchId: "branch_demo_001",
      facilityRunId: "run-a1",
      checkInExpected: ts(-14 * day),
      checkOutExpected: ts(-11 * day),
      status: "completed",
      servicesIncluded: ["boarding", "bath"],
      safetySnapshot: {
        calculatedIcdScore: 82,
        riskLevelAtBooking: "green",
        compatibilityWarnings: [],
        assessmentDate: ts(-15 * day),
      },
      legalAuthorizations: {
        emergencyMedicationAllowed: { accepted: true, acceptedAt: ts(-15 * day), documentVersion: "1.0" },
        contactVetAllowed: { accepted: true, acceptedAt: ts(-15 * day), documentVersion: "1.0" },
        waterPlayAllowed: { accepted: false, acceptedAt: null, documentVersion: "1.0" },
        mediaUsageAllowed: { accepted: true, acceptedAt: ts(-15 * day), documentVersion: "1.0" },
      },
      staffNotes: "Mascota sociable. Sin incidentes.",
      createdAt: ts(-15 * day),
    },
    // Rocky — confirmada próxima semana
    {
      id: "demo_res_002",
      petId: "pet_carlos_001", petName: "Rocky",
      ownerId: "demo_owner_placeholder", ownerName: "Carlos Mendoza (Demo)",
      branchId: "branch_demo_001",
      facilityRunId: "run-a2",
      checkInExpected: ts(5 * day),
      checkOutExpected: ts(9 * day),
      status: "confirmed",
      servicesIncluded: ["boarding"],
      safetySnapshot: {
        calculatedIcdScore: 79,
        riskLevelAtBooking: "green",
        compatibilityWarnings: [],
        assessmentDate: now,
      },
      legalAuthorizations: {
        emergencyMedicationAllowed: { accepted: true, acceptedAt: now, documentVersion: "1.0" },
        contactVetAllowed: { accepted: true, acceptedAt: now, documentVersion: "1.0" },
        waterPlayAllowed: { accepted: true, acceptedAt: now, documentVersion: "1.0" },
        mediaUsageAllowed: { accepted: false, acceptedAt: null, documentVersion: "1.0" },
      },
      staffNotes: "",
      createdAt: now,
    },
    // Luna — pendiente de confirmación
    {
      id: "demo_res_003",
      petId: "pet_carlos_002", petName: "Luna",
      ownerId: "demo_owner_placeholder", ownerName: "Carlos Mendoza (Demo)",
      branchId: "branch_demo_001",
      facilityRunId: "run-gatos-1",
      checkInExpected: ts(12 * day),
      checkOutExpected: ts(15 * day),
      status: "pending",
      servicesIncluded: ["daycare"],
      safetySnapshot: {
        calculatedIcdScore: 91,
        riskLevelAtBooking: "green",
        compatibilityWarnings: [],
        assessmentDate: now,
      },
      legalAuthorizations: {
        emergencyMedicationAllowed: { accepted: true, acceptedAt: now, documentVersion: "1.0" },
        contactVetAllowed: { accepted: true, acceptedAt: now, documentVersion: "1.0" },
        waterPlayAllowed: { accepted: false, acceptedAt: null, documentVersion: "1.0" },
        mediaUsageAllowed: { accepted: true, acceptedAt: now, documentVersion: "1.0" },
      },
      staffNotes: "",
      createdAt: now,
    },
  ];

  for (const { id, ...data } of seedReservations) {
    reservationBatch.set(db.collection("demo_boarding_reservations").doc(id), data);
  }
  await reservationBatch.commit();

  console.log(`[Demo] Entorno reiniciado: ${toDelete.length} docs eliminados, datos frescos resembrados.`);
}

/**
 * CALLABLE 5: setupDemoUser
 * Invocable por cualquier usuario autenticado de la demo.
 * Asigna el rol y estado de aprobación al usuario utilizando el Admin SDK (bypasseando reglas).
 * También reasocia las mascotas y pagos del Seed a la cuenta demo real.
 */
export const setupDemoUser = onCall<SetupDemoPayload>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const uid = request.auth.uid;
  const { role, displayName } = request.data;

  if (!["owner", "vet", "admin"].includes(role)) {
    throw new HttpsError("invalid-argument", "Rol de demo no válido.");
  }

  // Reset demo environment before every session — guarantees a clean slate
  await cleanupAndReseedDemo(uid);

  const demoVetServices = role === "vet" ? [
    { id: "demo_svc_001", name: "Consulta General",          price: 450,  durationMinutes: 30 },
    { id: "demo_svc_002", name: "Vacunación",                price: 250,  durationMinutes: 15 },
    { id: "demo_svc_003", name: "Desparasitación",           price: 180,  durationMinutes: 20 },
    { id: "demo_svc_004", name: "Limpieza Dental Premium",   price: 1200, durationMinutes: 60 },
    { id: "demo_svc_005", name: "Análisis Clínico de Sangre", price: 650, durationMinutes: 45 },
    { id: "demo_svc_006", name: "Anestesia Inhalatoria",     price: 800,  durationMinutes: 60 },
  ] : undefined;

  // 1. Escribir el perfil en Firestore de forma segura (con permisos de administrador)
  const profileData: Record<string, unknown> = {
    uid,
    email: request.auth.token.email || `demo.${role}@petcarepro.com`,
    displayName,
    role,
    isApprovedVet: role === "vet" || role === "admin",
    vetStatus: role === "vet" ? "approved" : null,
    professionalLicense: role === "vet" ? "CED-4820193-DEMO" : null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (demoVetServices) {
    profileData.services = demoVetServices;
    profileData.acceptsSpei = true;
    profileData.acceptsCash = true;
    profileData.acceptsCardTerminal = false;
    profileData.clabe = "646180157000000004";
    // Demo vets always show the full trial experience
    const demoTrialEndsAt = new Date();
    demoTrialEndsAt.setMonth(demoTrialEndsAt.getMonth() + 6);
    profileData.subscriptionTier = "trial";
    profileData.trialEndsAt = admin.firestore.Timestamp.fromDate(demoTrialEndsAt);
  }
  await getCol("users", request.auth).doc(uid).set(profileData, { merge: true });

  // 2. Sincronizar Custom Claims de forma inmediata
  await admin.auth().setCustomUserClaims(uid, {
    role,
    isApprovedVet: role === "vet" || role === "admin",
  });

  // 3. Reasociar/crear mascotas y pagos si es Dueño
  if (role === "owner") {
    // Usar set() con merge para crear el documento si no existe o actualizar ownerId si ya existe.
    // Esto garantiza que los pets demo siempre estén disponibles independientemente del estado de Firestore.
    const demoPetsData = [
      {
        id: "pet_carlos_001",
        name: "Rocky",
        species: "Perro",
        breed: "Golden Retriever",
        age: 36,
        photoUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Labrador_on_Quantock_%282175262184%29.jpg/320px-Labrador_on_Quantock_%282175262184%29.jpg",
        allergies: [],
        chronicConditions: [],
      },
      {
        id: "pet_carlos_002",
        name: "Luna",
        species: "Gato",
        breed: "Siamés",
        age: 18,
        photoUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Cat_November_2010-1a.jpg/320px-Cat_November_2010-1a.jpg",
        allergies: ["Polen"],
        chronicConditions: [],
      },
    ];

    const demoPetIds = demoPetsData.map(p => p.id);

    for (const pet of demoPetsData) {
      const { id, ...fields } = pet;
      await getCol("pets", request.auth).doc(id).set({
        ...fields,
        ownerId: uid,
        ownerName: displayName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      console.log(`[Demo] Mascota ${id} (${fields.name}) actualizada/creada con ownerId ${uid}`);
    }

    const ownerPaymentsQuery = await getCol("payments", request.auth)
      .where("petId", "in", demoPetIds)
      .get();
    for (const doc of ownerPaymentsQuery.docs) {
      await doc.ref.update({
        ownerId: uid,
        ownerName: displayName,
        allowedPaymentMethods: { spei: true, cash: true, terminal: false },
      });
    }

    // Actualizar el ownerId en los documentos compuestos de QR activos para estas mascotas,
    // de modo que la sección "Accesos Veterinarios Activos" del dueño muestre los accesos correctamente.
    const qrTokensSnap = await getCol("qr_tokens", request.auth)
      .where("petId", "in", demoPetIds)
      .get();
    for (const doc of qrTokensSnap.docs) {
      if (doc.id.includes("_") && doc.data()?.status === "active") {
        await doc.ref.update({ ownerId: uid });
      }
    }
  }

  // 4. Reasociar pagos si es Veterinario
  if (role === "vet") {
    // Reasociar TODOS los pagos de mascotas demo por petId en vez de por vetId placeholder.
    const allDemoPetIds = ["pet_carlos_001", "pet_carlos_002", "pet_sofia_001"];
    const vetPaymentsQuery = await getCol("payments", request.auth)
      .where("petId", "in", allDemoPetIds)
      .get();
    for (const doc of vetPaymentsQuery.docs) {
      await doc.ref.update({
        vetId: uid,
        vetName: displayName,
        allowedPaymentMethods: { spei: true, cash: true, terminal: false },
      });
    }

    // 5. Crear arrendamientos QR para TODAS las mascotas demo (Rocky, Luna y Toby)
    // Usar tipo 'hospitalization' para que el acceso no expire en la demo.
    const hospDurationMs = 365 * 24 * 60 * 60 * 1000;
    const leaseExpiresTimestamp = admin.firestore.Timestamp.fromMillis(Date.now() + hospDurationMs);

    const leases = [
      { petId: "pet_carlos_001", petName: "Rocky", breed: "Golden Retriever", ownerName: "Carlos Mendoza" },
      { petId: "pet_carlos_002", petName: "Luna", breed: "Siamés", ownerName: "Carlos Mendoza" },
      { petId: "pet_sofia_001", petName: "Toby", breed: "Border Collie", ownerName: "Sofía Castro" },
    ];

    for (const lease of leases) {
      let petOwnerId = "owner_001";
      try {
        const petDoc = await getCol("pets", request.auth).doc(lease.petId).get();
        if (petDoc.exists) {
          petOwnerId = petDoc.data()?.ownerId || "owner_001";
        }
      } catch (e) {
        console.error(`[Demo] Error obteniendo dueño de mascota ${lease.petId}:`, e);
      }

      const compositeDocId = `${uid}_${lease.petId}`;
      await getCol("qr_tokens", request.auth).doc(compositeDocId).set({
        tokenId: `demo_token_${lease.petId}`,
        petId: lease.petId,
        ownerId: petOwnerId,
        vetId: uid,
        vetName: displayName,
        status: "active",
        durationMinutes: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        leaseExpiresAt: leaseExpiresTimestamp,
        petName: lease.petName,
        petBreed: lease.breed,
        ownerName: lease.ownerName
      });
    }
  }

  console.log(`[Demo] Configurado usuario demo ${uid} con rol ${role}`);
  return { success: true };
});


/**
 * -----------------------------------------------------------------------------
 * 6. LIMPIEZA AUTOMÁTICA DE ARRENDAMIENTOS EXPIRADOS
 * -----------------------------------------------------------------------------
 */

/**
 * SCHEDULED: cleanupExpiredLeases
 * Se ejecuta cada hora. Elimina los documentos compuestos de consulta (2h) cuyo
 * leaseExpiresAt ya pasó, manteniendo la colección qr_tokens limpia.
 */
export const cleanupExpiredLeases = onSchedule("every 60 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  let totalDeleted = 0;

  const getExpiredDocs = async (collectionName: string) => {
    const expiredLeasesQuery = await db.collection(collectionName)
      .where("status", "==", "active")
      .where("leaseExpiresAt", "<", now)
      .get();

    const expiredPendingQuery = await db.collection(collectionName)
      .where("status", "==", "pending")
      .where("expiresAt", "<", now)
      .get();

    return [...expiredLeasesQuery.docs, ...expiredPendingQuery.docs];
  };

  const [prodDocs, demoDocs] = await Promise.all([
    getExpiredDocs("qr_tokens"),
    getExpiredDocs("demo_qr_tokens")
  ]);

  const allDocs = [...prodDocs, ...demoDocs];

  if (allDocs.length === 0) {
    console.log("[Cleanup] Sin documentos expirados.");
    return;
  }

  // Firestore batch admite máximo 500 operaciones por lote
  const chunkSize = 499;
  for (let i = 0; i < allDocs.length; i += chunkSize) {
    const chunk = allDocs.slice(i, i + chunkSize);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    totalDeleted += chunk.length;
  }

  console.log(`[Cleanup] Eliminados ${totalDeleted} documento(s) expirados.`);
});


/**
 * -----------------------------------------------------------------------------
 * 7. NOTIFICACIONES AL DUEÑO CUANDO EL VET ESCANEA EL QR
 * -----------------------------------------------------------------------------
 */

/**
 * TRIGGER: onQrLeaseActivated
 * Se dispara cuando se crea un documento en qr_tokens.
 * Si el documento es un compuesto activo (status == 'active'), notifica al dueño.
 */
async function handleQrLeaseActivated(docId: string, data: any, prefix: string) {
  // Solo procesar documentos compuestos activos (vetId_petId)
  if (!data || data.status !== "active" || !docId.includes("_")) return;

  const ownerId = data.ownerId as string | undefined;
  const vetId = data.vetId as string | undefined;
  const petId = data.petId as string | undefined;
  const durationMinutes: number | null = data.durationMinutes ?? null;

  if (!ownerId || !vetId || !petId) return;

  // Obtener nombre del veterinario
  let vetName = "Un veterinario";
  try {
    const vetDoc = await db.collection(`${prefix}users`).doc(vetId).get();
    if (vetDoc.exists) {
      vetName = vetDoc.data()?.displayName ?? vetName;
    }
  } catch (e) {
    console.warn("[Notif] No se pudo obtener nombre del vet:", e);
  }

  // Obtener nombre de la mascota
  const petName = data.petName as string | undefined;
  let resolvedPetName = petName ?? "tu mascota";
  if (!petName) {
    try {
      const petDoc = await db.collection(`${prefix}pets`).doc(petId).get();
      if (petDoc.exists) {
        resolvedPetName = petDoc.data()?.name ?? resolvedPetName;
      }
    } catch (e) {
      console.warn("[Notif] No se pudo obtener nombre de mascota:", e);
    }
  }

  const isUnlimited = durationMinutes === null;
  const durationLabel = isUnlimited
    ? "acceso sin límite de tiempo"
    : durationMinutes! < 60
      ? `acceso por ${durationMinutes} minutos`
      : `acceso por ${Math.round(durationMinutes! / 60)} hora(s)`;
  const message = `${vetName} escaneó el QR de ${resolvedPetName} — ${durationLabel}.`;

  // Guardar notificación en Firestore
  await db.collection(`${prefix}users`).doc(ownerId)
    .collection("notifications")
    .add({
      type: "qr_scanned",
      message,
      petId,
      petName: resolvedPetName,
      vetId,
      vetName,
      durationMinutes,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  // Enviar FCM push notification si el dueño tiene token registrado
  try {
    const ownerDoc = await db.collection(`${prefix}users`).doc(ownerId).get();
    const fcmToken = ownerDoc.data()?.fcmToken as string | undefined;
    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Acceso QR Escaneado",
          body: message,
        },
        data: {
          petId: petId ?? "",
          vetId: vetId ?? "",
          type: "qr_scanned",
        },
        android: {
          notification: {
            channelId: "petcare_qr",
            priority: "high",
          },
        },
        apns: {
          payload: {
            aps: { sound: "default" },
          },
        },
      });
      console.log(`[FCM] Push enviado a dueño ${ownerId}`);
    }
  } catch (fcmErr) {
    console.warn("[FCM] Error enviando push notification:", fcmErr);
  }

  console.log(`[Notif] Notificación enviada a dueño ${ownerId}: ${message}`);
}

export const onQrLeaseActivated = onDocumentCreated("qr_tokens/{docId}", async (event) => {
  const docId = event.params.docId;
  const data = event.data?.data();
  await handleQrLeaseActivated(docId, data, "");
});

export const onQrLeaseActivatedDemo = onDocumentCreated("demo_qr_tokens/{docId}", async (event) => {
  const docId = event.params.docId;
  const data = event.data?.data();
  await handleQrLeaseActivated(docId, data, "demo_");
});


/**
 * -----------------------------------------------------------------------------
 * 8. RECORDATORIOS DE VACUNACIÓN Y DESPARASITACIÓN
 * -----------------------------------------------------------------------------
 */

/**
 * SCHEDULED: vaccinationReminders
 * Se ejecuta diariamente a las 9:00 AM (hora de México).
 * Detecta vacunas/desparasitaciones con nextApplicationAt en 7 días o en 1 día
 * y envía notificación push + registro en Firestore al dueño correspondiente.
 */
export const vaccinationReminders = onSchedule(
  { schedule: "every day 09:00", timeZone: "America/Mexico_City" },
  async () => {
    const nowMs = Date.now();
    const oneDayMs = 24 * 60 * 60 * 1000;

    // Ventana de 7 días: nextApplicationAt entre [now+6d, now+7d+2h]
    const sevenDayStart = admin.firestore.Timestamp.fromMillis(nowMs + 6 * oneDayMs);
    const sevenDayEnd   = admin.firestore.Timestamp.fromMillis(nowMs + 7 * oneDayMs + 2 * 3600 * 1000);

    // Ventana de 1 día: nextApplicationAt entre [now, now+1d+2h]
    const nowTs      = admin.firestore.Timestamp.fromMillis(nowMs);
    const oneDayEnd  = admin.firestore.Timestamp.fromMillis(nowMs + oneDayMs + 2 * 3600 * 1000);

    const [snap7d, snap1d] = await Promise.all([
      db.collectionGroup("vaccination_card")
        .where("nextApplicationAt", ">=", sevenDayStart)
        .where("nextApplicationAt", "<=", sevenDayEnd)
        .get(),
      db.collectionGroup("vaccination_card")
        .where("nextApplicationAt", ">=", nowTs)
        .where("nextApplicationAt", "<=", oneDayEnd)
        .get(),
    ]);

    const sendReminder = async (
      doc: admin.firestore.QueryDocumentSnapshot,
      daysUntil: number
    ) => {
      const data = doc.data();
      const petId = doc.ref.parent.parent?.id;
      if (!petId) return;

      const path = doc.ref.path;
      const isDemo = path.includes("demo_pets");
      const prefix = isDemo ? "demo_" : "";

      const vaccineName  = (data.name as string | undefined) ?? "Vacuna";
      const vaccineType  = (data.type as string | undefined) ?? "vaccine";
      const typeLabel    = vaccineType === "dewormer" ? "desparasitación" : "vacuna";

      const petDoc = await db.collection(`${prefix}pets`).doc(petId).get();
      if (!petDoc.exists) return;

      const petName = (petDoc.data()?.name as string | undefined) ?? "tu mascota";
      const ownerId = petDoc.data()?.ownerId as string | undefined;
      if (!ownerId) return;

      const message = daysUntil <= 1
        ? `La ${typeLabel} "${vaccineName}" de ${petName} vence mañana. ¡No olvides la cita!`
        : `La ${typeLabel} "${vaccineName}" de ${petName} vence en 7 días.`;

      // Registro en Firestore (centro de notificaciones del owner)
      await db.collection(`${prefix}users`).doc(ownerId)
        .collection("notifications")
        .add({
          type: "vaccination_reminder",
          message,
          petId,
          petName,
          vaccineName,
          daysUntil,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Push FCM
      const ownerDoc = await db.collection(`${prefix}users`).doc(ownerId).get();
      const fcmToken = ownerDoc.data()?.fcmToken as string | undefined;
      if (!fcmToken) return;

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: daysUntil <= 1 ? "Vacuna vence mañana" : "Recordatorio de vacuna",
          body: message,
        },
        data: { petId, type: "vaccination_reminder" },
        android: {
          notification: { channelId: "petcare_vaccines", priority: "high" },
        },
        apns: { payload: { aps: { sound: "default" } } },
      });
    };

    await Promise.allSettled([
      ...snap7d.docs.map((doc) => sendReminder(doc, 7)),
      ...snap1d.docs.map((doc) => sendReminder(doc, 1)),
    ]);

    console.log(`[VaccineReminders] 7d=${snap7d.size} 1d=${snap1d.size}`);
  }
);


/**
 * -----------------------------------------------------------------------------
 * 9. SISTEMA DE SUSCRIPCIONES — MERCADOPAGO
 * -----------------------------------------------------------------------------
 */

interface SubscriptionPayload {
  tier: "basico" | "profesional" | "premium";
}

const TIER_AMOUNTS: Record<string, number> = {
  basico: 199,
  profesional: 299,
  premium: 499,
};

/**
 * CALLABLE: createMercadoPagoSubscription
 * Crea un preapproval (checkout de suscripción) en MercadoPago y devuelve la URL de pago.
 * Requiere la variable de entorno MP_ACCESS_TOKEN configurada en Firebase Functions.
 */
export const createMercadoPagoSubscription = onCall<SubscriptionPayload>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const uid = request.auth.uid;
  const tier = request.data.tier;
  const amount = TIER_AMOUNTS[tier];

  if (!amount) {
    throw new HttpsError("invalid-argument", "Tier de suscripción inválido.");
  }

  const accessToken = process.env.MP_ACCESS_TOKEN;
  if (!accessToken) {
    throw new HttpsError(
      "failed-precondition",
      "MercadoPago no está configurado. Contacta al administrador."
    );
  }

  // Obtener email del vet para pre-llenar el checkout
  const userDoc = await getCol("users", request.auth).doc(uid).get();
  const email = (userDoc.data()?.email as string | undefined) ||
    request.auth.token.email ||
    "";

  const tierLabel = tier.charAt(0).toUpperCase() + tier.slice(1);

  const response = await fetch("https://api.mercadopago.com/preapproval", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      reason: `PetCare Pro — Plan ${tierLabel} ($${amount} MXN/mes)`,
      payer_email: email,
      external_reference: uid,
      back_url: "https://petcare-pro-62010.web.app/subscription-result",
      auto_recurring: {
        frequency: 1,
        frequency_type: "months",
        transaction_amount: amount,
        currency_id: "MXN",
      },
      status: "pending",
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    console.error("[MP] Error al crear preapproval:", errText);
    throw new HttpsError("internal", "Error al crear la suscripción en MercadoPago.");
  }

  const data = await (response.json() as Promise<any>);

  // Guardamos el ID del preapproval pendiente en el perfil del vet
  await getCol("users", request.auth).doc(uid).update({
    mpSubscriptionId: data.id,
    mpSubscriptionStatus: "pending",
  });

  console.log(`[MP] Preapproval creado ${data.id} para vet ${uid} — tier: ${tier}`);

  return {
    checkoutUrl: data.init_point as string,
    subscriptionId: data.id as string,
  };
});

/**
 * HTTP TRIGGER: mercadoPagoWebhook
 * Recibe notificaciones de MercadoPago (IPN) sobre cambios en suscripciones.
 * Actualiza el tier del veterinario en Firestore según el estado del preapproval.
 *
 * Configura la URL de este endpoint como webhook en tu dashboard de MercadoPago:
 *   https://us-central1-petcare-pro-62010.cloudfunctions.net/mercadoPagoWebhook
 */
export const mercadoPagoWebhook = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.sendStatus(405);
    return;
  }

  const accessToken = process.env.MP_ACCESS_TOKEN;
  if (!accessToken) {
    console.error("[MP Webhook] MP_ACCESS_TOKEN no configurado.");
    res.sendStatus(500);
    return;
  }

  try {
    const { type, data } = req.body as { type: string; data?: { id: string } };

    if (type === "subscription_preapproval") {
      const preapprovalId = data?.id;
      if (!preapprovalId) { res.sendStatus(400); return; }

      // Consultar estado actualizado del preapproval en MP
      const mpRes = await fetch(
        `https://api.mercadopago.com/preapproval/${preapprovalId}`,
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );
      const preapproval = await (mpRes.json() as Promise<any>);

      const uid: string = preapproval.external_reference ?? "";
      const status: string = preapproval.status ?? "cancelled";
      const amount: number = preapproval.auto_recurring?.transaction_amount ?? 0;

      if (!uid) {
        console.warn("[MP Webhook] Preapproval sin external_reference, ignorando.");
        res.sendStatus(200);
        return;
      }

      const tier =
        amount <= 199 ? "basico" : amount <= 299 ? "profesional" : "premium";
      const newTier = status === "authorized" ? tier : "free";

      const updates = {
        subscriptionTier: newTier,
        mpSubscriptionStatus: status,
        mpSubscriptionId: preapprovalId,
      };

      // Intentar actualizar en users (prod) primero, luego demo_users
      const userRef = db.collection("users").doc(uid);
      const userDoc = await userRef.get();
      if (userDoc.exists) {
        await userRef.update(updates);
      } else {
        const demoRef = db.collection("demo_users").doc(uid);
        const demoDoc = await demoRef.get();
        if (demoDoc.exists) await demoRef.update(updates);
      }

      console.log(`[MP Webhook] ${uid} → tier: ${newTier}, status: ${status}`);
    }

    res.sendStatus(200);
  } catch (error) {
    console.error("[MP Webhook] Error procesando notificación:", error);
    res.sendStatus(500);
  }
});

/**
 * SCHEDULED: checkSubscriptionExpiry
 * Se ejecuta diariamente. Baja a 'free' cualquier vet cuyo período de prueba expiró.
 */
export const checkSubscriptionExpiry = onSchedule(
  { schedule: "every 24 hours", timeZone: "America/Mexico_City" },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const [prodExpired, demoExpired] = await Promise.all([
      db.collection("users")
        .where("subscriptionTier", "==", "trial")
        .where("trialEndsAt", "<", now)
        .get(),
      db.collection("demo_users")
        .where("subscriptionTier", "==", "trial")
        .where("trialEndsAt", "<", now)
        .get(),
    ]);

    const allExpired = [...prodExpired.docs, ...demoExpired.docs];

    if (allExpired.length === 0) {
      console.log("[Subscription] Sin pruebas expiradas.");
      return;
    }

    const batch = db.batch();
    allExpired.forEach((doc) => batch.update(doc.ref, { subscriptionTier: "free" }));
    await batch.commit();

    console.log(`[Subscription] ${allExpired.length} prueba(s) expirada(s) → downgraded a free.`);
  }
);


// =============================================================================
// v1.1.0 — BOARDING / GROOMING ENGINE
// =============================================================================

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS MPT (Motor de Productividad de Tiempos) — espejo del Dart use case
// ─────────────────────────────────────────────────────────────────────────────

function mptBaseMinutes(size: string): number {
  switch (size.toUpperCase()) {
    case "TOY":    return 45;
    case "SMALL":  return 60;
    case "LARGE":  return 90;
    case "GIANT":  return 120;
    default:       return 75; // MEDIUM
  }
}

function mptCoatMultiplier(coatType: string): number {
  switch (coatType.toUpperCase()) {
    case "LONG":        return 1.5;
    case "DOUBLE_COAT": return 1.7;
    case "CURLY":       return 1.6;
    case "MEDIUM":      return 1.2;
    default:            return 1.0; // SHORT
  }
}

function mptCoatConditionPenalty(coatCondition: string): number {
  return coatCondition.toUpperCase() === "MATTED" ? 30 : 0;
}

function mptBathPenalty(sensitivity: string): number {
  switch (sensitivity) {
    case "anxious":   return 10;
    case "defensive": return 25;
    default:          return 0; // cooperative
  }
}

function mptDryingPenalty(sensitivity: string): number {
  switch (sensitivity) {
    case "medium":     return 15;
    case "highPanic":
    case "high_panic": return 45;
    default:           return 0; // low
  }
}

interface NailInfo { penalty: number; canPerform: boolean; }
function mptNailInfo(nailTrimming: string): NailInfo {
  switch (nailTrimming) {
    case "needsMuzzle":
    case "needs_muzzle":      return { penalty: 10, canPerform: true };
    case "sedationRequired":
    case "sedation_required": return { penalty: 0,  canPerform: false };
    default:                  return { penalty: 0,  canPerform: true }; // cooperative
  }
}

interface MptInput {
  sizeCategory:    string;
  coatType:        string;
  coatCondition:   string;
  riskLevel:       string;
  handlingTolerance: {
    bathSensitivity:   string;
    dryingSensitivity: string;
    nailTrimming:      string;
  } | null;
}

interface MptOutput {
  estimatedMinutes:     number;
  staffUnitsRequired:   number;
  requiresVetSupervision: boolean;
  canPerformNailTrimming: boolean;
  penaltyReasons:       string[];
}

function computeMPT(input: MptInput): MptOutput {
  const base        = mptBaseMinutes(input.sizeCategory);
  const afterCoat   = Math.round(base * mptCoatMultiplier(input.coatType));
  const afterMat    = afterCoat + mptCoatConditionPenalty(input.coatCondition);

  const ht = input.handlingTolerance;
  const bathPen  = ht ? mptBathPenalty(ht.bathSensitivity)   : 0;
  const dryPen   = ht ? mptDryingPenalty(ht.dryingSensitivity) : 0;
  const nailInfo = ht ? mptNailInfo(ht.nailTrimming) : { penalty: 0, canPerform: true };
  const total    = afterMat + bathPen + dryPen + nailInfo.penalty;

  const isGiant          = input.sizeCategory.toUpperCase() === "GIANT";
  const isHighRisk       = ["orange", "red"].includes(input.riskLevel.toLowerCase());
  const requiresVetSupervision = input.riskLevel.toLowerCase() === "red";
  let staffUnits         = isGiant ? 2 : 1;
  if (isHighRisk) staffUnits++;

  const penaltyReasons: string[] = [];
  if (input.coatType.toUpperCase() !== "SHORT") {
    penaltyReasons.push(`Pelaje ${input.coatType}: ×${mptCoatMultiplier(input.coatType)} sobre base`);
  }
  if (input.coatCondition.toUpperCase() === "MATTED") {
    penaltyReasons.push("Pelaje enmarañado: +30 min de desanudado");
  }
  if (bathPen > 0)  penaltyReasons.push(`Sensibilidad al baño (${ht!.bathSensitivity}): +${bathPen} min`);
  if (dryPen  > 0)  penaltyReasons.push(`Sensibilidad al secado (${ht!.dryingSensitivity}): +${dryPen} min`);
  if (!nailInfo.canPerform) penaltyReasons.push("Uñas: requiere coordinación clínica");
  if (requiresVetSupervision) penaltyReasons.push("Nivel de riesgo ROJO: supervisión veterinaria simultánea");

  return {
    estimatedMinutes:     total,
    staffUnitsRequired:   staffUnits,
    requiresVetSupervision,
    canPerformNailTrimming: nailInfo.canPerform,
    penaltyReasons,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: calculateServiceDuration
//
// Recibe petId + serviceType y retorna el bloque de tiempo exacto del servicio
// de estética junto con los recursos de staff necesarios.
// Requiere claim canPerformServices o canPerformMedical (solo staff).
// ─────────────────────────────────────────────────────────────────────────────

interface CalculateServiceDurationPayload {
  petId:       string;
  serviceType: "bath" | "haircut";
}

export const calculateServiceDuration = onCall<CalculateServiceDurationPayload>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const claims = request.auth.token;
  if (!claims.canPerformServices && !claims.canPerformMedical && !claims.isAdmin) {
    throw new HttpsError("permission-denied", "Solo el staff puede calcular duraciones de servicio.");
  }

  const { petId, serviceType } = request.data;

  if (!petId) {
    throw new HttpsError("invalid-argument", "El campo 'petId' es obligatorio.");
  }
  if (!["bath", "haircut"].includes(serviceType)) {
    throw new HttpsError(
      "invalid-argument",
      "El campo 'serviceType' debe ser 'bath' o 'haircut'."
    );
  }

  // ── 1. Datos físicos de la mascota ──────────────────────────────────────
  const petDoc = await getCol("pets", request.auth).doc(petId).get();
  if (!petDoc.exists) {
    throw new HttpsError("not-found", `Mascota '${petId}' no encontrada.`);
  }
  const pet = petDoc.data()!;

  // Aislamiento Multi-tenant por sucursal
  const staffBranchId = claims.branchId as string | undefined;
  const petBranchId = pet.branchId as string | undefined;
  if (staffBranchId && petBranchId && staffBranchId !== petBranchId) {
    throw new HttpsError(
      "permission-denied",
      "No tienes acceso a los datos de esta mascota (pertenece a otra sucursal)."
    );
  }

  const weightKg: number       = (pet.weightKg as number | undefined) ?? 0;
  const coatType: string       = (pet.coatType as string | undefined) ?? "SHORT";
  const coatCondition: string  = (pet.coatCondition as string | undefined) ?? "NORMAL";
  const rawSize: string | undefined = pet.sizeCategory as string | undefined;

  // Derivar sizeCategory desde peso si no está explícita en el documento
  const sizeCategory: string = rawSize ?? (() => {
    if (weightKg < 4)  return "TOY";
    if (weightKg < 10) return "SMALL";
    if (weightKg < 25) return "MEDIUM";
    if (weightKg < 45) return "LARGE";
    return "GIANT";
  })();

  // ── 2. Evaluación conductual más reciente ────────────────────────────────
  // La subcolección es confidencial; Admin SDK la lee sin restricciones de reglas.
  const assessSnap = await getCol("pets", request.auth)
    .doc(petId)
    .collection("behavioral_assessments")
    .orderBy("assessedAt", "desc")
    .limit(1)
    .get();

  let riskLevel         = "green";
  let handlingTolerance: MptInput["handlingTolerance"] | null = null;

  if (!assessSnap.empty) {
    const a = assessSnap.docs[0].data();
    riskLevel = (a.riskLevel as string | undefined) ?? "green";
    const ht  = a.handlingTolerance as Record<string, string> | undefined;
    if (ht) {
      handlingTolerance = {
        bathSensitivity:   ht.bathSensitivity   ?? "cooperative",
        dryingSensitivity: ht.dryingSensitivity ?? "low",
        nailTrimming:      ht.nailTrimming      ?? "cooperative",
      };
    }
  }

  // ── 3. Cálculo MPT ────────────────────────────────────────────────────────
  const result = computeMPT({ sizeCategory, coatType, coatCondition, riskLevel, handlingTolerance });

  console.log(`[MPT] petId=${petId} service=${serviceType} → ${result.estimatedMinutes} min, ${result.staffUnitsRequired} staff`);

  return result;
});


// ─────────────────────────────────────────────────────────────────────────────
// CALLABLE: linkPetToOwner
//
// El dueño ingresa el código PET-XXXX generado por el staff.
// Ejecuta una transacción de Firestore para:
//   1. Validar existencia y vigencia del código en /pending_links/{code}
//   2. Reemplazar el campo `ownerId` en /pets/{petId} con el UID del llamante
//   3. Marcar el código como canjeado (redeemedBy, redeemedAt) — previene doble uso
//
// La eliminación del documento es diferida; el campo `redeemed: true` actúa como
// cerrojo durante la ventana de expiración para auditoría.
// ─────────────────────────────────────────────────────────────────────────────

interface LinkPetToOwnerPayload {
  code: string; // Formato esperado: PET-XXXX (4 chars alfanuméricos en mayúsculas)
}

interface LinkPetToOwnerResult {
  petId:      string;
  petName:    string;
  newOwnerId: string;
}

const LINK_CODE_REGEX = /^PET-[A-Z0-9]{4}$/;

export const linkPetToOwner = onCall<LinkPetToOwnerPayload>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const callerUid = request.auth.uid;
  const normalized = (request.data.code ?? "").trim().toUpperCase();

  // ── 1. Validar formato del código ────────────────────────────────────────
  if (!LINK_CODE_REGEX.test(normalized)) {
    throw new HttpsError(
      "invalid-argument",
      "Formato de código inválido. Debe ser PET-XXXX (4 caracteres alfanuméricos)."
    );
  }

  const prefix = getPrefix(request.auth);

  // ── 2. Rate limiting — máx. 5 intentos por UID en la última hora ─────────
  const attemptRef = db.collection(`${prefix}link_attempts`).doc(callerUid);
  const attemptSnap = await attemptRef.get();
  const now = Date.now();
  const oneHourAgo = now - 60 * 60 * 1000;

  interface LinkAttempt { timestamps: number[] }
  const attempts: number[] = (attemptSnap.data() as LinkAttempt | undefined)?.timestamps ?? [];
  const recentAttempts = attempts.filter((t) => t > oneHourAgo);

  if (recentAttempts.length >= 5) {
    throw new HttpsError(
      "resource-exhausted",
      "Has superado el límite de 5 intentos por hora. Espera un momento e inténtalo de nuevo."
    );
  }

  // Persist this attempt (fire-and-forget; failure is non-fatal)
  attemptRef.set({ timestamps: [...recentAttempts, now] }).catch(() => undefined);

  // ── 3. Transacción atómica ────────────────────────────────────────────────
  const result = await db.runTransaction<LinkPetToOwnerResult>(async (tx) => {
    // 2a. Leer el documento del código de vinculación
    const linkRef  = db.collection(`${prefix}pending_links`).doc(normalized);
    const linkSnap = await tx.get(linkRef);

    if (!linkSnap.exists) {
      throw new HttpsError(
        "not-found",
        "Código no encontrado. Verifica que sea correcto o solicita uno nuevo al staff."
      );
    }

    const linkData = linkSnap.data()!;

    // 2b. Verificar que no haya sido canjeado previamente
    if (linkData.redeemed === true) {
      throw new HttpsError(
        "failed-precondition",
        "Este código ya fue utilizado. Solicita un nuevo código al staff."
      );
    }

    // 2c. Verificar vigencia temporal
    const expiresAt = (linkData.expiresAt as admin.firestore.Timestamp).toDate();
    if (new Date() > expiresAt) {
      throw new HttpsError(
        "deadline-exceeded",
        "El código ha expirado. Los códigos son válidos por 15 minutos. Solicita uno nuevo."
      );
    }

    // 2d. Leer la mascota asociada
    const petId  = linkData.petId as string;
    const petRef = db.collection(`${prefix}pets`).doc(petId);
    const petSnap = await tx.get(petRef);

    if (!petSnap.exists) {
      throw new HttpsError(
        "not-found",
        "La mascota asociada a este código no existe. Contacta al staff."
      );
    }

    const petData = petSnap.data()!;
    const petName = (petData.name as string | undefined) ?? "";

    const callerBranchId = request.auth?.token?.branchId as string | undefined;
    const linkBranchId = linkData.branchId as string | undefined;
    const petBranchId = petData.branchId as string | undefined;

    // Aislamiento Multi-tenant por sucursal
    if (linkBranchId && petBranchId && linkBranchId !== petBranchId) {
      throw new HttpsError(
        "failed-precondition",
        "El código de vinculación no corresponde a la sucursal de la mascota."
      );
    }

    if (callerBranchId && petBranchId && callerBranchId !== petBranchId) {
      throw new HttpsError(
        "permission-denied",
        "No tienes permiso para vincular una mascota de otra sucursal."
      );
    }

    // 2e. Escrituras transaccionales
    // Reemplaza "PENDING_LINK" (o cualquier ownerId previo) por el UID real del dueño.
    tx.update(petRef, {
      ownerId:        callerUid,
      ownerLinkedAt:  admin.firestore.FieldValue.serverTimestamp(),
    });

    // Marca el código como canjeado — previene doble uso antes del TTL de limpieza.
    tx.update(linkRef, {
      redeemed:    true,
      redeemedBy:  callerUid,
      redeemedAt:  admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`[LinkPet] Código ${normalized} canjeado. petId=${petId}, newOwner=${callerUid}`);

    return { petId, petName, newOwnerId: callerUid };
  });

  return result;
});


interface RegisterBranchStaffPayload {
  email: string;
  displayName: string;
  role: "vet" | "groomer" | "caretaker" | "receptionist";
  canPerformMedical: boolean;
  canPerformServices: boolean;
  password?: string;
}

/**
 * CALLABLE: registerBranchStaff
 * Permite a un Administrador Local de Sucursal (isAdmin === true) registrar
 * empleados para su sucursal, heredando el branchId del administrador.
 */
export const registerBranchStaff = onCall<RegisterBranchStaffPayload>(async (request) => {
  // 1. Validar autenticación
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "El usuario debe estar autenticado.");
  }

  const claims = request.auth.token;
  
  // 2. Validar privilegios de administrador local
  if (!claims.isAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Solo los administradores de sucursal pueden dar de alta personal."
    );
  }

  const branchId = claims.branchId as string | undefined;
  if (!branchId) {
    throw new HttpsError(
      "failed-precondition",
      "El administrador no cuenta con una sucursal física asignada."
    );
  }

  const { email, displayName, role, canPerformMedical, canPerformServices, password } = request.data;

  if (!email || !displayName || !role) {
    throw new HttpsError(
      "invalid-argument",
      "Los campos 'email', 'displayName' y 'role' son obligatorios."
    );
  }

  const prefix = getPrefix(request.auth);

  try {
    // 3. Crear el usuario en Firebase Authentication
    const userRecord = await auth.createUser({
      email,
      password: password || "StaffTemp2026!",
      displayName,
      emailVerified: true,
    });

    const uid = userRecord.uid;

    // 4. Configurar custom claims heredando el branchId
    const staffClaims = {
      role: role,
      branchId: branchId,
      isAdmin: false,
      canPerformMedical: canPerformMedical,
      canPerformServices: canPerformServices,
      isApprovedVet: role === "vet",
    };

    await auth.setCustomUserClaims(uid, staffClaims);
    console.log(`[Staff Service] Custom Claims asignados a ${email} (UID: ${uid}):`, staffClaims);

    // 5. Crear el perfil en Firestore de producción o demo
    await db.collection(`${prefix}users`).doc(uid).set({
      uid: uid,
      email: email,
      displayName: displayName,
      role: role,
      branchId: branchId,
      isApprovedVet: role === "vet",
      vetStatus: role === "vet" ? "approved" : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionTier: role === "vet" ? "trial" : "free",
    });

    console.log(`[Staff Service] Registro exitoso. Empleado ${displayName} asignado a sucursal ${branchId}`);

    return {
      success: true,
      uid: uid,
      displayName: displayName,
    };
  } catch (error: any) {
    console.error("[Staff Service] Error en registerBranchStaff:", error);
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Este correo electrónico ya está registrado.");
    }
    throw new HttpsError("internal", error.message || "Error al procesar el registro del staff.");
  }
});


// ─────────────────────────────────────────────────────────────────────────────
// TRIGGER: Notificaciones FCM en cambios de estado de reservas de guardería
//
// Fires when boarding_reservations/{docId} transitions to:
//   confirmed  → checked_in : "Tu mascota ha llegado a la guardería"
//   checked_in → completed  : "Tu mascota está lista para ser recogida"
// ─────────────────────────────────────────────────────────────────────────────

async function notifyBoardingStatusChange(
  prefix: string,
  beforeStatus: string,
  afterStatus: string,
  data: admin.firestore.DocumentData,
): Promise<void> {
  const ownerId = data.ownerId as string | undefined;
  const petName = data.petName as string | undefined ?? "tu mascota";
  const branchId = data.branchId as string | undefined;

  if (!ownerId) return;

  let title: string;
  let body: string;
  let notifType: string;

  if (beforeStatus === "pending" && afterStatus === "confirmed") {
    // Notify branch staff (caretakers, groomers, receptionists) of new confirmed reservation
    if (branchId) {
      const staffSnap = await db.collection(`${prefix}users`)
        .where("branchId", "==", branchId)
        .where("role", "in", ["caretaker", "groomer", "receptionist"])
        .get();

      const checkInDate = data.checkInExpected?.toDate?.();
      const dateStr = checkInDate
        ? `${checkInDate.getDate().toString().padStart(2, "0")}/${(checkInDate.getMonth() + 1).toString().padStart(2, "0")}`
        : "próximamente";

      const staffTitle = "Nueva reserva confirmada";
      const staffBody = `${petName} llegará el ${dateStr}. Revisa tu panel para los detalles.`;

      await Promise.allSettled(staffSnap.docs.map(async (staffDoc) => {
        await staffDoc.ref.collection("notifications").add({
          type: "boarding_new_confirmed",
          message: staffBody,
          petId: data.petId ?? "",
          petName,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        const fcmToken = staffDoc.data()?.fcmToken as string | undefined;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: { title: staffTitle, body: staffBody },
            data: { petId: data.petId ?? "", type: "boarding_new_confirmed" },
            android: { notification: { channelId: "petcare_boarding", priority: "default" } },
            apns: { payload: { aps: { sound: "default" } } },
          }).catch((e) => console.warn("[FCM Boarding Staff]", e));
        }
      }));
      console.log(`[FCM Boarding] Notificados ${staffSnap.size} staff de sucursal ${branchId}`);
    }
    return;
  } else if (beforeStatus === "confirmed" && afterStatus === "checked_in") {
    title = "¡Tu mascota llegó!";
    body = `${petName} ha ingresado a la guardería. Recibirás una notificación cuando esté lista.`;
    notifType = "boarding_checked_in";
  } else if (beforeStatus === "checked_in" && afterStatus === "completed") {
    title = "¡Tu mascota está lista!";
    body = `${petName} ya puede ser recogida en la guardería.`;
    notifType = "boarding_completed";
  } else {
    return;
  }

  // Persist in-app notification for owner
  await db.collection(`${prefix}users`).doc(ownerId)
    .collection("notifications")
    .add({
      type: notifType,
      message: body,
      petId: data.petId ?? "",
      petName,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  // FCM push (best-effort)
  try {
    const ownerDoc = await db.collection(`${prefix}users`).doc(ownerId).get();
    const fcmToken = ownerDoc.data()?.fcmToken as string | undefined;
    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: { petId: data.petId ?? "", type: notifType },
        android: { notification: { channelId: "petcare_boarding", priority: "high" } },
        apns: { payload: { aps: { sound: "default" } } },
      });
    }
  } catch (fcmErr) {
    console.warn("[FCM Boarding] Error enviando push:", fcmErr);
  }
}

export const onBoardingReservationUpdatedV2 = onDocumentUpdated(
  "boarding_reservations/{docId}",
  async (event) => {
    const change = event.data;
    if (!change) return;
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after || before.status === after.status) return;
    await notifyBoardingStatusChange("", before.status, after.status, after);
  }
);

export const onBoardingReservationUpdatedDemo = onDocumentUpdated(
  "demo_boarding_reservations/{docId}",
  async (event) => {
    const change = event.data;
    if (!change) return;
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after || before.status === after.status) return;
    await notifyBoardingStatusChange("demo_", before.status, after.status, after);
  }
);


// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULER: Limpieza automática de pending_links expirados
//
// Corre cada hora. Elimina en batch todos los documentos de pending_links
// donde expiresAt < now (hayan sido canjeados o no). Reduce superficie de
// exposición de petIds y libera almacenamiento.
// ─────────────────────────────────────────────────────────────────────────────

export const cleanupExpiredLinkCodes = onSchedule("every 60 minutes", async () => {
  const now = admin.firestore.Timestamp.now();

  async function purgeExpiredCodes(collection: string): Promise<number> {
    const snap = await db.collection(collection)
      .where("expiresAt", "<", now)
      .limit(400)
      .get();
    if (snap.empty) return 0;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    return snap.size;
  }

  const [prod, demo] = await Promise.all([
    purgeExpiredCodes("pending_links"),
    purgeExpiredCodes("demo_pending_links"),
  ]);
  console.log(`[Cleanup] pending_links expirados eliminados — prod: ${prod}, demo: ${demo}`);
});


// ─────────────────────────────────────────────────────────────────────────────
// SCHEDULER: Notificación al dueño cuando el código PET-XXXX está por expirar
//
// Corre cada 5 minutos. Busca códigos no canjeados que expiran en la ventana
// [ahora, ahora + 6 min]. Envía un push FCM único al dueño de la mascota para
// que entregue el código antes de que caduque.
// ─────────────────────────────────────────────────────────────────────────────

export const notifyExpiringLinkCodes = onSchedule("every 5 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const windowEnd = admin.firestore.Timestamp.fromMillis(now.toMillis() + 6 * 60 * 1000);

  async function notifyExpiring(petsCollection: string, linksCollection: string, usersCollection: string): Promise<void> {
    const snap = await db.collection(linksCollection)
      .where("redeemed", "==", false)
      .where("expiresAt", ">", now)
      .where("expiresAt", "<=", windowEnd)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      const petId = data.petId as string | undefined;
      if (!petId) continue;

      // Obtener ownerId desde la mascota
      const petDoc = await db.collection(petsCollection).doc(petId).get();
      if (!petDoc.exists) continue;
      const ownerId = petDoc.data()?.ownerId as string | undefined;
      if (!ownerId) continue;

      // Solo enviar si el dueño tiene FCM token
      const ownerDoc = await db.collection(usersCollection).doc(ownerId).get();
      const fcmToken = ownerDoc.data()?.fcmToken as string | undefined;
      if (!fcmToken) continue;

      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Código PET expirando",
            body: `Tu código ${data.code ?? doc.id} vence en menos de 6 minutos. Ingrésalo ahora para vincular tu mascota.`,
          },
          data: { type: "link_code_expiring", code: data.code ?? doc.id },
          android: { notification: { channelId: "petcare_alerts", priority: "high" } },
          apns: { payload: { aps: { sound: "default" } } },
        });
        console.log(`[FCM] Notif de expiración enviada al dueño ${ownerId} para código ${doc.id}`);
      } catch (e) {
        console.warn(`[FCM] Error notificando expiración para ${doc.id}:`, e);
      }
    }
  }

  await Promise.all([
    notifyExpiring("pets", "pending_links", "users"),
    notifyExpiring("demo_pets", "demo_pending_links", "demo_users"),
  ]);
});

