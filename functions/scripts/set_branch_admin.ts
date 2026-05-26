import * as admin from 'firebase-admin';
import * as path from 'path';

// Ruta absoluta a la clave de cuenta de servicio del proyecto
const serviceAccountPath = path.join(__dirname, '..', '..', 'petcare-pro-62010-firebase-adminsdk-fbsvc-b4905546a2.json');

console.log(`🔍 Cargando credenciales de cuenta de servicio desde: ${serviceAccountPath}`);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccountPath),
  projectId: 'petcare-pro-62010',
});

const auth = admin.auth();
const db = admin.firestore();

interface UpdateUserParams {
  email: string;
  role: 'admin' | 'vet' | 'staff';
  branchId: string;
  isAdmin: boolean;
  canPerformMedical: boolean;
  canPerformServices: boolean;
}

async function configureUserAccess(params: UpdateUserParams) {
  console.log(`\n🚀 Configurando permisos para el correo: ${params.email}...`);

  try {
    // 1. Buscar al usuario por correo en Firebase Auth
    const userRecord = await auth.getUserByEmail(params.email);
    const uid = userRecord.uid;
    console.log(`✅ Usuario encontrado en Auth. UID: ${uid}`);

    // 2. Definir e inyectar Custom Claims
    const claims = {
      role: params.role,
      branchId: params.branchId,
      isAdmin: params.isAdmin,
      canPerformMedical: params.canPerformMedical,
      canPerformServices: params.canPerformServices,
      isApprovedVet: params.role === 'vet' || params.role === 'admin',
    };

    await auth.setCustomUserClaims(uid, claims);
    console.log(`✅ Custom User Claims asignados criptográficamente:`, claims);

    // 3. Crear o actualizar el perfil en la colección de producción `/users` de Firestore
    const userDocRef = db.collection('users').doc(uid);
    await userDocRef.set({
      uid: uid,
      email: params.email,
      displayName: userRecord.displayName || 'Administrador Local',
      role: params.role,
      branchId: params.branchId,
      isApprovedVet: params.role === 'vet' || params.role === 'admin',
      vetStatus: (params.role === 'vet' || params.role === 'admin') ? 'approved' : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionTier: 'trial', // Habilitar periodo de prueba ilimitado para testing
    }, { merge: true });

    console.log(`✅ Perfil registrado/actualizado de forma segura en Firestore (/users/${uid})`);
    console.log(`🎉 ¡Configuración completada con éxito para ${params.email}!`);
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.error(`❌ Error: El usuario con el correo "${params.email}" no existe en Firebase Authentication.`);
      console.error(`Asegúrate de que el usuario ya se haya registrado en la app antes de ejecutar este script.`);
    } else {
      console.error(`❌ Error inesperado al configurar al usuario ${params.email}:`, error);
    }
  }
}

async function main() {
  console.log('════════════════════════════════════════════════════════════════');
  console.log('🛡️  PETCARE PRO: GESTIÓN DE ROLES Y PRIVILEGIOS DE SUCURSAL  🛡️');
  console.log('════════════════════════════════════════════════════════════════');

  // 1. Configurar a Helen como Administradora Principal de su negocio "Petit Resort"
  await configureUserAccess({
    email: 'helen@petitresort.com',
    role: 'admin',
    branchId: 'petit_resort', // El tenant/sucursal de su negocio
    isAdmin: true,            // Es la administradora local
    canPerformMedical: true,  // Tiene accesos clínicos
    canPerformServices: true, // Tiene accesos de estética/guardería
  });

  // 2. PLANTILLA PARA SUBORDINADOS (Descomenta y edita para agregar otros usuarios de prueba de Helen):
  /*
  await configureUserAccess({
    email: 'vet.helen@petitresort.com', // Correo del veterinario subordinado
    role: 'vet',
    branchId: 'petit_resort',           // Debe pertenecer a la misma sucursal
    isAdmin: false,                     // No es administrador, es subordinado
    canPerformMedical: true,            // Habilitar acceso a expedientes clínicos
    canPerformServices: false,
  });

  await configureUserAccess({
    email: 'staff.helen@petitresort.com', // Correo del staff de guardería/estética
    role: 'staff',
    branchId: 'petit_resort',
    isAdmin: false,
    canPerformMedical: false,
    canPerformServices: true,           // Habilitar acceso a MPT/estética/guardería
  });
  */

  console.log('\n════════════════════════════════════════════════════════════════');
}

main().catch(console.error);
