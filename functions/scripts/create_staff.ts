import * as admin from 'firebase-admin';

// Instrucciones de uso en tu terminal local:
// 1. Descarga la clave JSON de tu cuenta de servicio desde la consola de Firebase:
//    Configuración del Proyecto > Cuentas de servicio > Generar nueva clave privada.
// 2. Establece la variable de entorno en PowerShell apuntando al archivo descargado:
//    $env:GOOGLE_APPLICATION_CREDENTIALS="C:\ruta\completa\a\tu-clave.json"
// 3. Ejecuta este script desde la carpeta 'functions' utilizando ts-node:
//    npx ts-node scripts/create_staff.ts

const projectId = 'petcare-pro-62010';

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.log("⚠️ ADVERTENCIA: La variable de entorno GOOGLE_APPLICATION_CREDENTIALS no está establecida.");
  console.log("Se intentará realizar la conexión utilizando la sesión local de Firebase CLI / gcloud.");
}

admin.initializeApp({
  projectId: projectId,
});

const auth = admin.auth();
const db = admin.firestore();

interface CreateStaffParams {
  email: string;
  password?: string;
  displayName: string;
  role: 'vet' | 'admin';
  branchId: string;
  canPerformMedical: boolean;
  canPerformServices: boolean;
  isAdmin: boolean;
  professionalLicense?: string;
}

async function createStaffUser(params: CreateStaffParams) {
  console.log(`🚀 Iniciando la creación del usuario de staff: ${params.email}...`);

  try {
    // a) Crear el usuario en Firebase Authentication
    const userRecord = await auth.createUser({
      email: params.email,
      password: params.password || 'TempPassword2026!', // Contraseña temporal por defecto
      displayName: params.displayName,
      emailVerified: true,
    });

    console.log(`✅ Usuario creado exitosamente en Auth con UID: ${userRecord.uid}`);

    // b) Asignar Custom User Claims mediante auth.setCustomUserClaims
    const claims = {
      role: params.role,
      branchId: params.branchId,
      canPerformMedical: params.canPerformMedical,
      canPerformServices: params.canPerformServices,
      isAdmin: params.isAdmin,
      isApprovedVet: params.role === 'vet', // Los veterinarios de staff se auto-aprueban
    };

    await auth.setCustomUserClaims(userRecord.uid, claims);
    console.log(`✅ Custom User Claims asignados exitosamente:`, claims);

    // c) Registrar el perfil en la colección /users de Firestore
    const userDocRef = db.collection('users').doc(userRecord.uid);
    await userDocRef.set({
      uid: userRecord.uid,
      email: params.email,
      displayName: params.displayName,
      role: params.role,
      branchId: params.branchId,
      isApprovedVet: params.role === 'vet',
      vetStatus: params.role === 'vet' ? 'approved' : null,
      professionalLicense: params.professionalLicense || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionTier: params.role === 'vet' ? 'trial' : 'free',
      trialEndsAt: params.role === 'vet' ? (() => {
        const d = new Date();
        d.setMonth(d.getMonth() + 6);
        return admin.firestore.Timestamp.fromDate(d);
      })() : null,
    });

    console.log(`✅ Perfil de usuario registrado exitosamente en Firestore (/users/${userRecord.uid})`);
    console.log(`\n🎉 ¡Staff creado con éxito!`);
  } catch (error) {
    console.error("❌ Error grave al crear el usuario de staff:", error);
  }
}

// =============================================================================
// PLANTILLA DE CONFIGURACIÓN - Modifica estos valores según la sucursal y rol:
// =============================================================================
const newStaffMember: CreateStaffParams = {
  email: 'staff.sucursal.a@petcarepro.com',
  displayName: 'Dra. María Fernández',
  password: 'StaffSecurePassword123!',
  role: 'vet',
  branchId: 'branch_sucursal_a', // <-- ID de la sucursal para el aislamiento multi-tenant
  canPerformMedical: true,        // <-- Permiso médico
  canPerformServices: true,       // <-- Permiso para servicios de estética/guardería
  isAdmin: false,                 // <-- ¿Es Administrador de la sucursal?
  professionalLicense: 'CED-8372649',
};

createStaffUser(newStaffMember);
