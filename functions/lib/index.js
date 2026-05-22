"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkSubscriptionExpiry = exports.mercadoPagoWebhook = exports.createMercadoPagoSubscription = exports.vaccinationReminders = exports.onQrLeaseActivatedDemo = exports.onQrLeaseActivated = exports.cleanupExpiredLeases = exports.setupDemoUser = exports.revokeVetAccess = exports.approveComprobante = exports.validateQrLease = exports.generateQrToken = exports.onUserProfileUpdatedDemo = exports.onUserProfileUpdatedV2 = exports.onUserProfileCreatedDemo = exports.onUserProfileCreatedV2 = void 0;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
// Inicializar el SDK de Firebase Admin de forma segura
admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();
function getPrefix(auth) {
    return auth?.token?.email?.startsWith("demo.") ? "demo_" : "";
}
function getCol(colName, auth) {
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
async function syncUserClaims(uid, role, isApprovedVet) {
    const claims = {
        role: role,
        isApprovedVet: isApprovedVet || false,
    };
    await auth.setCustomUserClaims(uid, claims);
    console.log(`[RBAC] Custom Claims actualizados para ${uid}:`, claims);
}
/**
 * TRIGGER 1B (Firestore): onUserProfileCreated
 * Escucha la creación de perfiles en la colección '/users'.
 * Sincroniza los Custom Claims si el documento se creó con un rol específico.
 */
exports.onUserProfileCreatedV2 = (0, firestore_1.onDocumentCreated)("users/{userId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const uid = event.params.userId;
    const data = snapshot.data();
    const role = data?.role || "owner";
    const isApprovedVet = data?.isApprovedVet || false;
    console.log(`[Firestore Trigger] Perfil creado para ${uid}. Sincronizando rol: ${role}`);
    try {
        await syncUserClaims(uid, role, isApprovedVet);
    }
    catch (error) {
        console.error(`[Firestore Trigger] Error sincronizando claims al crear perfil de ${uid}:`, error);
    }
});
exports.onUserProfileCreatedDemo = (0, firestore_1.onDocumentCreated)("demo_users/{userId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot)
        return;
    const uid = event.params.userId;
    const data = snapshot.data();
    const role = data?.role || "owner";
    const isApprovedVet = data?.isApprovedVet || false;
    console.log(`[Firestore Trigger Demo] Perfil creado para ${uid}. Sincronizando rol: ${role}`);
    try {
        await syncUserClaims(uid, role, isApprovedVet);
    }
    catch (error) {
        console.error(`[Firestore Trigger Demo] Error sincronizando claims al crear perfil de ${uid}:`, error);
    }
});
/**
 * TRIGGER 1C (Firestore): onUserProfileUpdated
 * Escucha actualizaciones en '/users' (útil cuando el Admin aprueba a un Veterinario).
 * Sincroniza los Custom Claims reactivamente.
 */
exports.onUserProfileUpdatedV2 = (0, firestore_1.onDocumentUpdated)("users/{userId}", async (event) => {
    const change = event.data;
    if (!change)
        return;
    const uid = event.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const roleChanged = beforeData?.role !== afterData?.role;
    const approvalChanged = beforeData?.isApprovedVet !== afterData?.isApprovedVet;
    if (roleChanged || approvalChanged) {
        const newRole = afterData?.role || "owner";
        const isApprovedVet = afterData?.isApprovedVet || false;
        console.log(`[Firestore Trigger] Cambio de rol o aprobación detectado para ${uid}. Actualizando Claims.`);
        try {
            await syncUserClaims(uid, newRole, isApprovedVet);
        }
        catch (error) {
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
exports.onUserProfileUpdatedDemo = (0, firestore_1.onDocumentUpdated)("demo_users/{userId}", async (event) => {
    const change = event.data;
    if (!change)
        return;
    const uid = event.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const roleChanged = beforeData?.role !== afterData?.role;
    const approvalChanged = beforeData?.isApprovedVet !== afterData?.isApprovedVet;
    if (roleChanged || approvalChanged) {
        const newRole = afterData?.role || "owner";
        const isApprovedVet = afterData?.isApprovedVet || false;
        console.log(`[Firestore Trigger Demo] Cambio de rol o aprobación detectado para ${uid}. Actualizando Claims.`);
        try {
            await syncUserClaims(uid, newRole, isApprovedVet);
        }
        catch (error) {
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
 * CALLABLE 2: generateQrToken
 * Invocable únicamente por el Dueño ('owner') de la mascota.
 * Genera un código token de un solo uso con validez de exactamente 15 minutos.
 */
exports.generateQrToken = (0, https_1.onCall)(async (request) => {
    // 1. Validar autenticación
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "El usuario debe estar autenticado.");
    }
    const callerUid = request.auth.uid;
    const { petId, ownerId } = request.data;
    // null = sin límite; número positivo = minutos de acceso
    const durationMinutes = request.data.durationMinutes ?? null;
    if (!petId || !ownerId) {
        throw new https_1.HttpsError("invalid-argument", "Los campos 'petId' y 'ownerId' son obligatorios.");
    }
    if (durationMinutes !== null && (typeof durationMinutes !== "number" || durationMinutes <= 0)) {
        throw new https_1.HttpsError("invalid-argument", "durationMinutes debe ser un número positivo o null.");
    }
    // 2. Validar que el llamante es realmente el dueño de la mascota o un Administrador (RBAC)
    const isOwner = callerUid === ownerId;
    const isAdmin = request.auth.token.role === "admin";
    if (!isOwner && !isAdmin) {
        throw new https_1.HttpsError("permission-denied", "No tienes permisos para generar pases QR de esta mascota.");
    }
    try {
        // 3. Validar existencia de la mascota y correspondencia del dueño en Firestore
        const petDoc = await getCol("pets", request.auth).doc(petId).get();
        if (!petDoc.exists) {
            throw new https_1.HttpsError("not-found", "La mascota especificada no existe.");
        }
        const petData = petDoc.data();
        if (petData?.ownerId !== ownerId) {
            throw new https_1.HttpsError("permission-denied", "Inconsistencia de propiedad detectada.");
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
    }
    catch (error) {
        console.error("[QR Service] Error en generateQrToken:", error);
        if (error instanceof https_1.HttpsError)
            throw error;
        throw new https_1.HttpsError("internal", "Error al procesar la solicitud de generación de QR.");
    }
});
/**
 * CALLABLE 3: validateQrLease
 * Invocable únicamente por Veterinarios ('vet') aprobados.
 * Valida el código QR y otorga un arrendamiento de acceso clínico de exactamente 2 horas.
 */
exports.validateQrLease = (0, https_1.onCall)(async (request) => {
    // 1. Validar autenticación
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "El usuario debe estar autenticado.");
    }
    const callerUid = request.auth.uid;
    const callerClaims = request.auth.token;
    const { tokenId, vetId } = request.data;
    if (!tokenId || !vetId) {
        throw new https_1.HttpsError("invalid-argument", "Los campos 'tokenId' y 'vetId' son obligatorios.");
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
        }
        catch (e) {
            console.error("[QR Service] Error consultando fallback de rol en Firestore:", e);
        }
    }
    if ((!isVet || !isApproved) && !isAdmin) {
        throw new https_1.HttpsError("permission-denied", "Solo veterinarios aprobados pueden escanear QR.");
    }
    if (callerUid !== vetId && !isAdmin) {
        throw new https_1.HttpsError("permission-denied", "Inconsistencia en la identificación del veterinario.");
    }
    try {
        // 3. Buscar el token en Firestore
        const tokenRef = getCol("qr_tokens", request.auth).doc(tokenId);
        const tokenDoc = await tokenRef.get();
        if (!tokenDoc.exists) {
            throw new https_1.HttpsError("not-found", "El código QR escaneado no es válido.");
        }
        const tokenData = tokenDoc.data();
        // 4. Validaciones de expiración y estado
        if (tokenData?.status !== "pending") {
            throw new https_1.HttpsError("failed-precondition", `Este código QR ya no está disponible.`);
        }
        const now = admin.firestore.Timestamp.now();
        const expiresAt = tokenData.expiresAt;
        if (now.toMillis() > expiresAt.toMillis()) {
            // Marcar como expirado para auditoría
            await tokenRef.update({ status: "expired" });
            throw new https_1.HttpsError("deadline-exceeded", "El código QR ha expirado.");
        }
        // 5. Configurar duración del arrendamiento
        const durationMinutes = tokenData.durationMinutes ?? null;
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
    }
    catch (error) {
        console.error("[QR Service] Error en validateQrLease:", error);
        if (error instanceof https_1.HttpsError)
            throw error;
        throw new https_1.HttpsError("internal", "Error al procesar el arrendamiento clínico.");
    }
});
/**
 * CALLABLE 4: approveComprobante
 * Invocable únicamente por el Veterinario dueño del cobro.
 * Valida el comprobante SPEI y marca el pago como 'paid' vía Admin SDK,
 * lo que bypasea las Firestore Security Rules (los clientes no pueden hacer esto).
 */
exports.approveComprobante = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "El usuario debe estar autenticado.");
    }
    const callerUid = request.auth.uid;
    const callerClaims = request.auth.token;
    const { paymentId } = request.data;
    if (!paymentId) {
        throw new https_1.HttpsError("invalid-argument", "El campo 'paymentId' es obligatorio.");
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
                if (userData?.role === "vet")
                    isVet = true;
                if (userData?.isApprovedVet === true)
                    isApproved = true;
            }
        }
        catch (e) {
            console.error("[Payments] Error en fallback de rol:", e);
        }
    }
    if ((!isVet || !isApproved) && !isAdmin) {
        throw new https_1.HttpsError("permission-denied", "Solo veterinarios aprobados pueden aprobar comprobantes.");
    }
    try {
        const paymentRef = getCol("payments", request.auth).doc(paymentId);
        const paymentDoc = await paymentRef.get();
        if (!paymentDoc.exists) {
            throw new https_1.HttpsError("not-found", "El pago especificado no existe.");
        }
        const paymentData = paymentDoc.data();
        if (!isAdmin && paymentData.vetId !== callerUid) {
            throw new https_1.HttpsError("permission-denied", "Este cobro no te pertenece.");
        }
        if (paymentData.status !== "pending_review") {
            throw new https_1.HttpsError("failed-precondition", `El pago tiene estado '${paymentData.status}', se requiere 'pending_review'.`);
        }
        // Admin SDK bypasea las Security Rules: solo el backend puede marcar como 'paid'
        await paymentRef.update({
            status: "paid",
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`[Payments] Comprobante aprobado por ${callerUid} para pago ${paymentId}`);
        return { success: true };
    }
    catch (error) {
        console.error("[Payments] Error en approveComprobante:", error);
        if (error instanceof https_1.HttpsError)
            throw error;
        throw new https_1.HttpsError("internal", "Error al aprobar el comprobante.");
    }
});
/**
 * CALLABLE 4B: revokeVetAccess
 * Invocable por el Dueño ('owner') de la mascota o un Administrador.
 * Elimina el arrendamiento QR activo, revocando el acceso del veterinario al expediente clínico.
 */
exports.revokeVetAccess = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "El usuario debe estar autenticado.");
    }
    const callerUid = request.auth.uid;
    const { petId, vetId } = request.data;
    if (!petId || !vetId) {
        throw new https_1.HttpsError("invalid-argument", "Los campos 'petId' y 'vetId' son obligatorios.");
    }
    // Validar que el caller es el dueño de la mascota o un Admin
    const petDoc = await getCol("pets", request.auth).doc(petId).get();
    if (!petDoc.exists) {
        throw new https_1.HttpsError("not-found", "Mascota no encontrada.");
    }
    const isOwner = petDoc.data()?.ownerId === callerUid;
    const isAdmin = request.auth.token.role === "admin";
    if (!isOwner && !isAdmin) {
        throw new https_1.HttpsError("permission-denied", "Solo el dueño de la mascota puede revocar accesos.");
    }
    // Eliminar el documento índice compuesto que habilita el acceso en Firestore rules
    const compositeDocId = `${vetId}_${petId}`;
    await getCol("qr_tokens", request.auth).doc(compositeDocId).delete();
    console.log(`[QR Service] Acceso revocado. Vet ${vetId} ya no puede acceder a mascota ${petId}`);
    return { success: true };
});
const DEMO_PET_IDS = ["pet_carlos_001", "pet_carlos_002", "pet_sofia_001"];
/**
 * Deletes all documents in a subcollection (used for cleanup).
 */
async function deleteSubcollectionDocs(parentRef, subcollection) {
    const snap = await parentRef.collection(subcollection).get();
    return snap.docs.map((d) => d.ref);
}
/**
 * Resets the demo environment to a clean, richly-seeded state on every demo login.
 * Deletes all user-generated data (medical records, vaccination entries, QR tokens,
 * notifications) and replaces them with fresh seed data.
 */
async function cleanupAndReseedDemo(uid) {
    const nowMs = Date.now();
    const day = 24 * 60 * 60 * 1000;
    const ts = (offsetMs) => admin.firestore.Timestamp.fromMillis(nowMs + offsetMs);
    // ── 1. Collect all refs to delete ────────────────────────────────────────
    const [notifSnap, qrSnap, ...subcollectionRefGroups] = await Promise.all([
        db.collection("demo_users").doc(uid).collection("notifications").get(),
        db.collection("demo_qr_tokens").where("petId", "in", [...DEMO_PET_IDS]).get(),
        ...DEMO_PET_IDS.flatMap((petId) => {
            const petRef = db.collection("demo_pets").doc(petId);
            return [
                deleteSubcollectionDocs(petRef, "medical_history"),
                deleteSubcollectionDocs(petRef, "vaccination_card"),
            ];
        }),
    ]);
    const toDelete = [
        ...notifSnap.docs.map((d) => d.ref),
        ...qrSnap.docs.map((d) => d.ref),
        ...subcollectionRefGroups.flat(),
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
            vetId: "demo_vet_placeholder", vetName: "Dr. Alejandro Méndez (Demo)",
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
            vetId: "demo_vet_placeholder", vetName: "Dr. Alejandro Méndez (Demo)",
            services: [
                { id: "demo_svc_002", name: "Vacunación", price: 250, durationMinutes: 15 },
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
            vetId: "demo_vet_placeholder", vetName: "Dr. Alejandro Méndez (Demo)",
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
    const vacSeeds = [
        // Rocky — Antirrábica (up to date)
        { petId: "pet_carlos_001", name: "Antirrábica", type: "vaccine",
            appliedAt: ts(-180 * day), nextApplicationAt: ts(185 * day),
            appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
            verifiedByVet: true, lot: "LOT-2025-001", notes: "Sin reacciones adversas." },
        // Rocky — Múltiple Canina (due in ~15 days — triggers 7-day reminder)
        { petId: "pet_carlos_001", name: "Múltiple Canina (DHPP)", type: "vaccine",
            appliedAt: ts(-350 * day), nextApplicationAt: ts(15 * day),
            appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
            verifiedByVet: true, lot: "LOT-2024-088", notes: "Refuerzo anual." },
        // Rocky — Desparasitación
        { petId: "pet_carlos_001", name: "Desparasitación Interna (Milbemax)", type: "dewormer",
            appliedAt: ts(-60 * day), nextApplicationAt: ts(120 * day),
            appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
            verifiedByVet: true, notes: "Tratamiento con Milbemax." },
        // Luna — Triple Felina
        { petId: "pet_carlos_002", name: "Triple Felina (HCP)", type: "vaccine",
            appliedAt: ts(-240 * day), nextApplicationAt: ts(125 * day),
            appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
            verifiedByVet: true, lot: "LOT-2025-042", notes: "Refuerzo anual aplicado." },
        // Luna — Leucemia Felina (due in ~45 days)
        { petId: "pet_carlos_002", name: "Leucemia Felina (FeLV)", type: "vaccine",
            appliedAt: ts(-320 * day), nextApplicationAt: ts(45 * day),
            appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
            verifiedByVet: true, lot: "LOT-2024-199", notes: "Gato con contacto exterior, vacuna prioritaria." },
        // Toby — Antirrábica
        { petId: "pet_sofia_001", name: "Antirrábica", type: "vaccine",
            appliedAt: ts(-90 * day), nextApplicationAt: ts(275 * day),
            appliedByVetId: "demo_vet_placeholder", appliedByVetName: "Dr. Alejandro Méndez (Demo)",
            verifiedByVet: true, lot: "LOT-2025-077", notes: "Vacuna aplicada sin incidentes." },
    ];
    for (const { petId, ...entry } of vacSeeds) {
        vacBatch.set(db.collection("demo_pets").doc(petId).collection("vaccination_card").doc(), entry);
    }
    await vacBatch.commit();
    // ── 5. Seed medical history entries ──────────────────────────────────────
    const medBatch = db.batch();
    const medSeeds = [
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
        medBatch.set(db.collection("demo_pets").doc(petId).collection("medical_history").doc(), record);
    }
    await medBatch.commit();
    console.log(`[Demo] Entorno reiniciado: ${toDelete.length} docs eliminados, datos frescos resembrados.`);
}
/**
 * CALLABLE 5: setupDemoUser
 * Invocable por cualquier usuario autenticado de la demo.
 * Asigna el rol y estado de aprobación al usuario utilizando el Admin SDK (bypasseando reglas).
 * También reasocia las mascotas y pagos del Seed a la cuenta demo real.
 */
exports.setupDemoUser = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "El usuario debe estar autenticado.");
    }
    const uid = request.auth.uid;
    const { role, displayName } = request.data;
    if (!["owner", "vet", "admin"].includes(role)) {
        throw new https_1.HttpsError("invalid-argument", "Rol de demo no válido.");
    }
    // Reset demo environment before every session — guarantees a clean slate
    await cleanupAndReseedDemo(uid);
    const demoVetServices = role === "vet" ? [
        { id: "demo_svc_001", name: "Consulta General", price: 450, durationMinutes: 30 },
        { id: "demo_svc_002", name: "Vacunación", price: 250, durationMinutes: 15 },
        { id: "demo_svc_003", name: "Desparasitación", price: 180, durationMinutes: 20 },
        { id: "demo_svc_004", name: "Limpieza Dental Premium", price: 1200, durationMinutes: 60 },
        { id: "demo_svc_005", name: "Análisis Clínico de Sangre", price: 650, durationMinutes: 45 },
        { id: "demo_svc_006", name: "Anestesia Inhalatoria", price: 800, durationMinutes: 60 },
    ] : undefined;
    // 1. Escribir el perfil en Firestore de forma segura (con permisos de administrador)
    const profileData = {
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
            }
            catch (e) {
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
exports.cleanupExpiredLeases = (0, scheduler_1.onSchedule)("every 60 minutes", async () => {
    const now = admin.firestore.Timestamp.now();
    let totalDeleted = 0;
    const getExpiredDocs = async (collectionName) => {
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
async function handleQrLeaseActivated(docId, data, prefix) {
    // Solo procesar documentos compuestos activos (vetId_petId)
    if (!data || data.status !== "active" || !docId.includes("_"))
        return;
    const ownerId = data.ownerId;
    const vetId = data.vetId;
    const petId = data.petId;
    const durationMinutes = data.durationMinutes ?? null;
    if (!ownerId || !vetId || !petId)
        return;
    // Obtener nombre del veterinario
    let vetName = "Un veterinario";
    try {
        const vetDoc = await db.collection(`${prefix}users`).doc(vetId).get();
        if (vetDoc.exists) {
            vetName = vetDoc.data()?.displayName ?? vetName;
        }
    }
    catch (e) {
        console.warn("[Notif] No se pudo obtener nombre del vet:", e);
    }
    // Obtener nombre de la mascota
    const petName = data.petName;
    let resolvedPetName = petName ?? "tu mascota";
    if (!petName) {
        try {
            const petDoc = await db.collection(`${prefix}pets`).doc(petId).get();
            if (petDoc.exists) {
                resolvedPetName = petDoc.data()?.name ?? resolvedPetName;
            }
        }
        catch (e) {
            console.warn("[Notif] No se pudo obtener nombre de mascota:", e);
        }
    }
    const isUnlimited = durationMinutes === null;
    const durationLabel = isUnlimited
        ? "acceso sin límite de tiempo"
        : durationMinutes < 60
            ? `acceso por ${durationMinutes} minutos`
            : `acceso por ${Math.round(durationMinutes / 60)} hora(s)`;
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
        const fcmToken = ownerDoc.data()?.fcmToken;
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
    }
    catch (fcmErr) {
        console.warn("[FCM] Error enviando push notification:", fcmErr);
    }
    console.log(`[Notif] Notificación enviada a dueño ${ownerId}: ${message}`);
}
exports.onQrLeaseActivated = (0, firestore_1.onDocumentCreated)("qr_tokens/{docId}", async (event) => {
    const docId = event.params.docId;
    const data = event.data?.data();
    await handleQrLeaseActivated(docId, data, "");
});
exports.onQrLeaseActivatedDemo = (0, firestore_1.onDocumentCreated)("demo_qr_tokens/{docId}", async (event) => {
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
exports.vaccinationReminders = (0, scheduler_1.onSchedule)({ schedule: "every day 09:00", timeZone: "America/Mexico_City" }, async () => {
    const nowMs = Date.now();
    const oneDayMs = 24 * 60 * 60 * 1000;
    // Ventana de 7 días: nextApplicationAt entre [now+6d, now+7d+2h]
    const sevenDayStart = admin.firestore.Timestamp.fromMillis(nowMs + 6 * oneDayMs);
    const sevenDayEnd = admin.firestore.Timestamp.fromMillis(nowMs + 7 * oneDayMs + 2 * 3600 * 1000);
    // Ventana de 1 día: nextApplicationAt entre [now, now+1d+2h]
    const nowTs = admin.firestore.Timestamp.fromMillis(nowMs);
    const oneDayEnd = admin.firestore.Timestamp.fromMillis(nowMs + oneDayMs + 2 * 3600 * 1000);
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
    const sendReminder = async (doc, daysUntil) => {
        const data = doc.data();
        const petId = doc.ref.parent.parent?.id;
        if (!petId)
            return;
        const path = doc.ref.path;
        const isDemo = path.includes("demo_pets");
        const prefix = isDemo ? "demo_" : "";
        const vaccineName = data.name ?? "Vacuna";
        const vaccineType = data.type ?? "vaccine";
        const typeLabel = vaccineType === "dewormer" ? "desparasitación" : "vacuna";
        const petDoc = await db.collection(`${prefix}pets`).doc(petId).get();
        if (!petDoc.exists)
            return;
        const petName = petDoc.data()?.name ?? "tu mascota";
        const ownerId = petDoc.data()?.ownerId;
        if (!ownerId)
            return;
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
        const fcmToken = ownerDoc.data()?.fcmToken;
        if (!fcmToken)
            return;
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
});
const TIER_AMOUNTS = {
    basico: 199,
    profesional: 299,
    premium: 499,
};
/**
 * CALLABLE: createMercadoPagoSubscription
 * Crea un preapproval (checkout de suscripción) en MercadoPago y devuelve la URL de pago.
 * Requiere la variable de entorno MP_ACCESS_TOKEN configurada en Firebase Functions.
 */
exports.createMercadoPagoSubscription = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "El usuario debe estar autenticado.");
    }
    const uid = request.auth.uid;
    const tier = request.data.tier;
    const amount = TIER_AMOUNTS[tier];
    if (!amount) {
        throw new https_1.HttpsError("invalid-argument", "Tier de suscripción inválido.");
    }
    const accessToken = process.env.MP_ACCESS_TOKEN;
    if (!accessToken) {
        throw new https_1.HttpsError("failed-precondition", "MercadoPago no está configurado. Contacta al administrador.");
    }
    // Obtener email del vet para pre-llenar el checkout
    const userDoc = await getCol("users", request.auth).doc(uid).get();
    const email = userDoc.data()?.email ||
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
        throw new https_1.HttpsError("internal", "Error al crear la suscripción en MercadoPago.");
    }
    const data = await response.json();
    // Guardamos el ID del preapproval pendiente en el perfil del vet
    await getCol("users", request.auth).doc(uid).update({
        mpSubscriptionId: data.id,
        mpSubscriptionStatus: "pending",
    });
    console.log(`[MP] Preapproval creado ${data.id} para vet ${uid} — tier: ${tier}`);
    return {
        checkoutUrl: data.init_point,
        subscriptionId: data.id,
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
exports.mercadoPagoWebhook = (0, https_1.onRequest)(async (req, res) => {
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
        const { type, data } = req.body;
        if (type === "subscription_preapproval") {
            const preapprovalId = data?.id;
            if (!preapprovalId) {
                res.sendStatus(400);
                return;
            }
            // Consultar estado actualizado del preapproval en MP
            const mpRes = await fetch(`https://api.mercadopago.com/preapproval/${preapprovalId}`, { headers: { Authorization: `Bearer ${accessToken}` } });
            const preapproval = await mpRes.json();
            const uid = preapproval.external_reference ?? "";
            const status = preapproval.status ?? "cancelled";
            const amount = preapproval.auto_recurring?.transaction_amount ?? 0;
            if (!uid) {
                console.warn("[MP Webhook] Preapproval sin external_reference, ignorando.");
                res.sendStatus(200);
                return;
            }
            const tier = amount <= 199 ? "basico" : amount <= 299 ? "profesional" : "premium";
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
            }
            else {
                const demoRef = db.collection("demo_users").doc(uid);
                const demoDoc = await demoRef.get();
                if (demoDoc.exists)
                    await demoRef.update(updates);
            }
            console.log(`[MP Webhook] ${uid} → tier: ${newTier}, status: ${status}`);
        }
        res.sendStatus(200);
    }
    catch (error) {
        console.error("[MP Webhook] Error procesando notificación:", error);
        res.sendStatus(500);
    }
});
/**
 * SCHEDULED: checkSubscriptionExpiry
 * Se ejecuta diariamente. Baja a 'free' cualquier vet cuyo período de prueba expiró.
 */
exports.checkSubscriptionExpiry = (0, scheduler_1.onSchedule)({ schedule: "every 24 hours", timeZone: "America/Mexico_City" }, async () => {
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
});
//# sourceMappingURL=index.js.map