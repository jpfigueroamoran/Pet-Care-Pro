import * as admin from 'firebase-admin';

// Instrucciones de uso en tu terminal local:
// 1. Descarga la clave JSON de tu cuenta de servicio desde la consola de Firebase:
//    Configuración del Proyecto > Cuentas de servicio > Generar nueva clave privada.
// 2. Establece la variable de entorno en PowerShell apuntando al archivo descargado:
//    $env:GOOGLE_APPLICATION_CREDENTIALS="C:\ruta\completa\a\tu-clave.json"
// 3. Ejecuta este script desde la carpeta 'functions' utilizando ts-node:
//    npx ts-node scripts/seed_data.ts

const projectId = 'petcare-pro-62010';

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.log("⚠️ ADVERTENCIA: La variable de entorno GOOGLE_APPLICATION_CREDENTIALS no está establecida.");
  console.log("Se intentará realizar la conexión utilizando la sesión local de Firebase CLI / gcloud.");
}

admin.initializeApp({
  projectId: projectId,
});

const db = admin.firestore();

async function seedData() {
  console.log("🚀 Iniciando la inyección de datos de prueba (Seed) en producción...");

  // 1. Veterinarios
  const vets = [
    {
      uid: "vet_001",
      email: "dr.alejandro.gomez@petcarepro.com",
      displayName: "Dr. Alejandro Gómez",
      role: "vet",
      professionalLicense: "CED-4820193",
      isApprovedVet: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      uid: "vet_002",
      email: "dra.patricia.ortiz@petcarepro.com",
      displayName: "Dra. Patricia Ortiz",
      role: "vet",
      professionalLicense: "CED-9482715",
      isApprovedVet: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  ];

  for (const vet of vets) {
    await db.collection('users').doc(vet.uid).set(vet);
    console.log(`✅ Veterinario guardado: ${vet.displayName} (${vet.uid})`);
  }

  // 2. Dueños de Mascotas (Owners)
  const owners = [
    {
      uid: "owner_001",
      email: "carlos.mendoza@gmail.com",
      displayName: "Carlos Mendoza",
      role: "owner",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      uid: "owner_002",
      email: "sofia.castro@outlook.com",
      displayName: "Sofía Castro",
      role: "owner",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  ];

  for (const owner of owners) {
    await db.collection('users').doc(owner.uid).set(owner);
    console.log(`✅ Dueño guardado: ${owner.displayName} (${owner.uid})`);
  }

  // 3. Mascotas (Pets)
  function ageInMonths(birthDate: Date): number {
    return Math.floor((Date.now() - birthDate.getTime()) / (30 * 24 * 60 * 60 * 1000));
  }

  const rockyBirth = new Date(2023, 4, 15);  // Mayo 2023
  const lunaBirth  = new Date(2025, 2, 20);  // Marzo 2025
  const tobyBirth  = new Date(2024, 8, 10);  // Septiembre 2024

  const pets = [
    {
      petId: "pet_carlos_001",
      ownerId: "owner_001",
      name: "Rocky",
      species: "Perro",
      breed: "Golden Retriever",
      birthDate: admin.firestore.Timestamp.fromDate(rockyBirth),
      age: ageInMonths(rockyBirth),
      photoUrl: "https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&q=80&w=300",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      petId: "pet_carlos_002",
      ownerId: "owner_001",
      name: "Luna",
      species: "Gato",
      breed: "Siamés",
      birthDate: admin.firestore.Timestamp.fromDate(lunaBirth),
      age: ageInMonths(lunaBirth),
      photoUrl: "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&q=80&w=300",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      petId: "pet_sofia_001",
      ownerId: "owner_002",
      name: "Toby",
      species: "Perro",
      breed: "Border Collie",
      birthDate: admin.firestore.Timestamp.fromDate(tobyBirth),
      age: ageInMonths(tobyBirth),
      photoUrl: "https://images.unsplash.com/photo-1507146426996-ef05306b995a?auto=format&fit=crop&q=80&w=300",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  ];

  for (const pet of pets) {
    await db.collection('pets').doc(pet.petId).set(pet);
    console.log(`✅ Mascota guardada: ${pet.name} (ID: ${pet.petId})`);
  }

  // 3b. Historial Clínico y Vacunación para demostración
  console.log("💉 Creando historial médico y cartilla de inmunización para demostración...");
  
  // Rocky
  await db.collection('pets').doc('pet_carlos_001').collection('medical_history').doc('rec_rocky_001').set({
    id: "rec_rocky_001",
    date: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)),
    reason: "Consulta",
    weightKg: 30.5,
    justification: "Revisión anual y refuerzo preventivo contra parásitos y virus.",
    diagnosis: "Mascota clínicamente sana. Peso óptimo y pelaje brillante.",
    treatment: "Aplicación de vacuna séxtuple de refuerzo anual y desparasitación externa.",
    prescription: "NexGard Spectra 1 tableta masticable cada 30 días.",
    vetId: "vet_001",
    vetName: "Dr. Alejandro Gómez",
    notes: "Propietario reporta excelente apetito y nivel de energía alto.",
    attachments: []
  });
  await db.collection('pets').doc('pet_carlos_001').collection('vaccination_card').doc('vac_rocky_001').set({
    id: "vac_rocky_001",
    type: "vaccine",
    name: "Vacuna Múltiple",
    appliedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)),
    nextApplicationAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 335 * 24 * 60 * 60 * 1000)),
    appliedByVetId: "vet_001",
    appliedByVetName: "Dr. Alejandro Gómez",
    notes: "Aplicado durante consulta de rutina anual."
  });

  // Luna
  await db.collection('pets').doc('pet_carlos_002').collection('medical_history').doc('rec_luna_001').set({
    id: "rec_luna_001",
    date: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 150 * 24 * 60 * 60 * 1000)),
    reason: "Consulta",
    weightKg: 3.2,
    justification: "Control semestral de desparasitación interna para felinos domésticos.",
    diagnosis: "Paciente sin signos clínicos patológicos aparentes. Mucosas rosadas y sanas.",
    treatment: "Aplicación tópica de desparasitante interno Profender.",
    prescription: "Mantener observación por 24 horas. Evitar bañar en 3 días.",
    vetId: "vet_001",
    vetName: "Dr. Alejandro Gómez",
    notes: "Mascota de interiores (indoor).",
    attachments: []
  });
  await db.collection('pets').doc('pet_carlos_002').collection('vaccination_card').doc('vac_luna_001').set({
    id: "vac_luna_001",
    type: "dewormer",
    name: "Desparasitante Interno",
    appliedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 150 * 24 * 60 * 60 * 1000)),
    nextApplicationAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)),
    appliedByVetId: "vet_001",
    appliedByVetName: "Dr. Alejandro Gómez",
    notes: "Desparasitante de amplio espectro Profender."
  });

  // Toby
  await db.collection('pets').doc('pet_sofia_001').collection('medical_history').doc('rec_toby_001').set({
    id: "rec_toby_001",
    date: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 395 * 24 * 60 * 60 * 1000)),
    reason: "Cirugía",
    weightKg: 18.2,
    justification: "Limpieza dental por acumulación de sarro severa en premolares y molares.",
    diagnosis: "Enfermedad periodontal grado II. Gingivitis leve.",
    treatment: "Profilaxis ultrasónica, pulido con pasta de fluoruro, y terapia antibacteriana oral.",
    prescription: "Clorhexidina gel dental cada 12 horas por 7 días. Clindamicina 150mg 1 tableta cada 24 horas por 5 días.",
    vetId: "vet_001",
    vetName: "Dr. Alejandro Gómez",
    notes: "Recomendar cambio a croquetas de control de sarro.",
    attachments: []
  });
  await db.collection('pets').doc('pet_sofia_001').collection('vaccination_card').doc('vac_toby_001').set({
    id: "vac_toby_001",
    type: "vaccine",
    name: "Vacuna de Rabia",
    appliedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 395 * 24 * 60 * 60 * 1000)),
    nextApplicationAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)),
    appliedByVetId: "vet_001",
    appliedByVetName: "Dr. Alejandro Gómez",
    notes: "Refuerzo anual obligatorio."
  });
  console.log("✅ Historiales y Cartilla de vacunación creados para las mascotas.");

  // 4. Cobros Realizados e Historial de Transacciones (Payments)
  const payments = [
    {
      id: "pay_001",
      ownerId: "owner_001",
      ownerName: "Carlos Mendoza",
      vetId: "vet_001",
      vetName: "Dr. Alejandro Gómez",
      petId: "pet_carlos_001",
      petName: "Rocky",
      services: [
        { name: "Consulta General", price: 450.0 },
        { name: "Vacunación Rábica", price: 250.0 }
      ],
      totalAmount: 700.0,
      status: "paid",
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)), // Hace 2 días
      paidAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)),
    },
    {
      id: "pay_002",
      ownerId: "owner_001",
      ownerName: "Carlos Mendoza",
      vetId: "vet_001",
      vetName: "Dr. Alejandro Gómez",
      petId: "pet_carlos_002",
      petName: "Luna",
      services: [
        { name: "Desparasitación Gatos", price: 180.0 }
      ],
      totalAmount: 180.0,
      status: "paid",
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)), // Hace 1 día
      paidAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 24 * 60 * 60 * 1000)),
    },
    {
      id: "pay_003",
      ownerId: "owner_002",
      ownerName: "Sofía Castro",
      vetId: "vet_001",
      vetName: "Dr. Alejandro Gómez",
      petId: "pet_sofia_001",
      petName: "Toby",
      services: [
        { name: "Limpieza Dental Premium", price: 1200.0 },
        { name: "Anestesia Inhalatoria", price: 800.0 }
      ],
      totalAmount: 2000.0,
      status: "paid",
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)), // Hace 3 días
      paidAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)),
    },
    {
      id: "pay_004",
      ownerId: "owner_002",
      ownerName: "Sofía Castro",
      vetId: "vet_001",
      vetName: "Dr. Alejandro Gómez",
      petId: "pet_sofia_001",
      petName: "Toby",
      services: [
        { name: "Corte de Pelo & Baño", price: 350.0 }
      ],
      totalAmount: 350.0,
      status: "paid",
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 60 * 60 * 1000)), // Hace 5 horas
      paidAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 5 * 60 * 60 * 1000)),
    },
    {
      id: "pay_005",
      ownerId: "owner_001",
      ownerName: "Carlos Mendoza",
      vetId: "vet_001",
      vetName: "Dr. Alejandro Gómez",
      petId: "pet_carlos_001",
      petName: "Rocky",
      services: [
        { name: "Análisis Clínico de Sangre", price: 650.0 }
      ],
      totalAmount: 650.0,
      status: "paid",
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 4 * 24 * 60 * 60 * 1000)), // Hace 4 días
      paidAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 4 * 24 * 60 * 60 * 1000)),
    }
  ];

  for (const payment of payments) {
    await db.collection('payments').doc(payment.id).set(payment);
    console.log(`✅ Transacción registrada: ID ${payment.id} (\$${payment.totalAmount} MXN) - Mascota: ${payment.petName}`);
  }

  console.log("\n🔥 Inyección completada exitosamente. Tu base de datos de producción ya está lista para deslumbrar en la demostración visual. 🐕✨");
  process.exit(0);
}

seedData().catch((error) => {
  console.error("❌ Error grave durante la inyección de datos (Seed):", error);
  process.exit(1);
});
