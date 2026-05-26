# PetCare Pro — Registro de Avances y Características

> **Versión actual:** 1.1.0  
> **Plataforma:** Flutter (Android / iOS) + Firebase  
> **Última actualización:** 2026-05-26

---

## Índice

1. [Visión General](#1-visión-general)
2. [Stack Tecnológico](#2-stack-tecnológico)
3. [Arquitectura](#3-arquitectura)
4. [Módulos Implementados](#4-módulos-implementados)
   - 4.1 [Autenticación y Roles (RBAC)](#41-autenticación-y-roles-rbac)
   - 4.2 [Panel del Dueño de Mascotas](#42-panel-del-dueño-de-mascotas)
   - 4.3 [Gestión de Mascotas](#43-gestión-de-mascotas)
   - 4.4 [Historial Clínico](#44-historial-clínico)
   - 4.5 [Compartir Expediente por QR](#45-compartir-expediente-por-qr)
   - 4.6 [Panel del Veterinario](#46-panel-del-veterinario)
   - 4.7 [Módulo de Pagos](#47-módulo-de-pagos)
   - 4.8 [Suscripciones y Feature Gates](#48-suscripciones-y-feature-gates)
   - 4.9 [Directorio de Veterinarios](#49-directorio-de-veterinarios)
   - 4.10 [Módulo de Guardería / Boarding](#410-módulo-de-guardería--boarding)
   - 4.11 [Dashboards de Staff Operativo](#411-dashboards-de-staff-operativo)
   - 4.12 [Panel de Administrador](#412-panel-de-administrador)
   - 4.13 [Wizard de Configuración Inicial](#413-wizard-de-configuración-inicial)
5. [Backend — Cloud Functions](#5-backend--cloud-functions)
6. [Seguridad — Firestore Rules](#6-seguridad--firestore-rules)
7. [Notificaciones Push (FCM)](#7-notificaciones-push-fcm)
8. [Sistema Multi-Tenant](#8-sistema-multi-tenant)
9. [Demo Accounts](#9-demo-accounts)
10. [Historial de Cambios por Versión](#10-historial-de-cambios-por-versión)

---

## 1. Visión General

PetCare Pro es una plataforma SaaS para la gestión integral del cuidado de mascotas. Conecta a dueños de mascotas, veterinarios, y el staff operativo de clínicas / guarderías en una sola aplicación móvil.

**Flujo principal:**
- El **dueño** registra a su mascota y comparte su expediente médico vía QR con el veterinario de su elección.
- El **veterinario** accede al expediente, registra consultas, vacunas y genera cobros.
- El **administrador** gestiona la clínica/guardería: aprueba vets, gestiona staff, monitorea KPIs y reservas.
- El **staff operativo** (groomer, caretaker, receptionist) tiene dashboards específicos para su rol dentro de la sucursal.

---

## 2. Stack Tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter 3.x (Dart) |
| State Management | Riverpod 2.x |
| Routing | GoRouter 14.x |
| Backend | Firebase (Auth, Firestore, Functions, Storage, FCM) |
| Cloud Functions | Node.js 18 + TypeScript |
| Mapas | Google Maps Flutter |
| QR | qr_flutter + mobile_scanner |
| PDF | pdf + printing |
| Pagos | SPEI (transferencia bancaria) + MercadoPago (external checkout) |

### Dependencias principales (`pubspec.yaml`)

```
firebase_core, firebase_auth, cloud_firestore, firebase_storage,
cloud_functions, firebase_messaging, flutter_riverpod, go_router,
qr_flutter, mobile_scanner, google_fonts, flutter_svg, image_picker,
cached_network_image, flutter_animate, fl_chart, pdf, printing,
share_plus, url_launcher, google_maps_flutter, geolocator
```

---

## 3. Arquitectura

El proyecto sigue **Feature-First Clean Architecture**:

```
lib/
├── core/
│   ├── routing/          ← GoRouter con RBAC guards
│   ├── theme/            ← AppTheme (colores, tipografía)
│   └── utils/            ← FirestoreExtension (demoCollection)
└── features/
    ├── auth/             ← Login, Register, perfiles, RBAC
    ├── pets/             ← CRUD de mascotas, dashboard dueño
    ├── medical_history/  ← Historial clínico, vacunaciones
    ├── qr_sharing/       ← Generación y escaneo de QR
    ├── payments/         ← Cobros, SPEI, reportes
    ├── subscriptions/    ← Tiers y feature gates
    ├── vet_directory/    ← Directorio + ubicación geolocalizada
    ├── boarding/         ← Guardería: reservas, triage, dashboards
    └── setup_wizard/     ← Onboarding de nueva sucursal
```

Cada feature sigue la estructura: `domain/` → `data/` → `presentation/`.

---

## 4. Módulos Implementados

### 4.1 Autenticación y Roles (RBAC)

**Archivo clave:** `lib/features/auth/`

#### Roles disponibles

| Rol | Ruta dashboard | Descripción |
|---|---|---|
| `owner` | `/owner-dashboard` | Dueño de mascotas |
| `vet` | `/vet-dashboard` | Veterinario independiente o de clínica |
| `admin` | `/admin-dashboard` | Administrador de sucursal |
| `groomer` | `/groomer-dashboard` | Lavador / Estilista |
| `caretaker` | `/caretaker-dashboard` | Cuidador de guardería |
| `receptionist` | `/receptionist-dashboard` | Recepcionista |

#### RBAC en GoRouter

El router implementa un `redirect` centralizado que:
1. Redirige usuarios no autenticados a `/login`.
2. Redirige usuarios ya autenticados que intenten ir a login/register hacia su dashboard.
3. Protege cada ruta por rol con guards individuales.
4. Redirige admins sin `branchId` al wizard de configuración.

#### Custom Claims JWT

Los claims granulares son sincronizados por Cloud Function al crear/modificar el perfil de usuario:

| Claim | Descripción |
|---|---|
| `role` | Rol del usuario |
| `isApprovedVet` | Si el vet fue aprobado por el admin |
| `canPerformMedical` | Acceso a historial clínico (vet aprobado + admin) |
| `canPerformServices` | Acceso a datos de estética/guardería (groomer, caretaker, admin, vet aprobado) |
| `isAdmin` | Acceso total de administración |
| `branchId` | ID de sucursal (multi-tenant) |

#### Invitación automática de staff

Cuando un admin registra a un miembro del staff desde el wizard, se crea un documento en `staff_invitations`. Al registrarse el usuario con ese email, el trigger `onUserProfileCreated` detecta la invitación, aplica el rol y `branchId` automáticamente, y marca la invitación como `accepted`.

#### Recuperación de contraseña

Implementada con `FirebaseAuth.sendPasswordResetEmail`. El botón "¿Olvidaste tu contraseña?" en la pantalla de login abre un diálogo que solicita el email y envía el enlace de restablecimiento.

---

### 4.2 Panel del Dueño de Mascotas

**Archivo:** `lib/features/pets/presentation/screens/owner_dashboard_screen.dart`

- Lista de mascotas registradas con foto y resumen de estado.
- **Sección de recordatorios de vacunas:** muestra vacunas próximas (≤ 30 días) o vencidas de todas las mascotas, con enlace directo a la cartilla.
- Acceso rápido a: Compartir QR, Ver historial, Ver pagos, Mis reservas de guardería.

---

### 4.3 Gestión de Mascotas

**Archivos:** `lib/features/pets/`

- Registro de mascotas con: nombre, especie, raza, edad, foto, alergias, condiciones crónicas.
- `PetEntity` con campos de seguridad ICD integrados.
- Stream en tiempo real desde Firestore vía `ownerPetsStreamProvider`.
- Soporte multi-tenant: `demoCollection()` para cuentas demo.

---

### 4.4 Historial Clínico

**Archivos:** `lib/features/medical_history/`

- Historial de consultas con fecha, diagnóstico, tratamiento, notas internas.
- **Cartilla de vacunación** (pestaña 2):
  - El **dueño** auto-reporta vacunas (`verifiedByVet: false`).
  - El **veterinario** registra y certifica vacunas (`verifiedByVet: true`).
  - Indicador visual: chip verde "Verificada por Vet" / amarillo "Auto-reportada".
- `AddMedicalRecordScreen` con validación de rol.
- Stream reactivo desde Firestore.

---

### 4.5 Compartir Expediente por QR

**Archivos:** `lib/features/qr_sharing/`

- El dueño genera un **token QR** desde `ShareQRScreen`.
- El veterinario **escanea** el QR con `ScanQRScreen` (mobile_scanner).
- Al escanear exitosamente se activa un **lease** temporal en Firestore (`qr_leases`).
- El lease da al vet acceso de solo lectura al expediente durante la sesión.
- El dueño puede revocar el acceso en cualquier momento.
- Al activarse el lease, el dueño recibe una **notificación push FCM**: "El Dr. [nombre] ha accedido al expediente de [mascota]".

---

### 4.6 Panel del Veterinario

**Archivos:** `lib/features/qr_sharing/presentation/screens/vet_dashboard_screen.dart`

- Lista de mascotas con acceso activo (leases vigentes).
- Acceso al expediente completo: historial clínico + cartilla de vacunas.
- Generar cobros directamente desde el panel.
- Acceso a Servicios del Vet, Reportes de Pagos, Configuración de cobros.
- Vista de subscripción activa con días restantes de trial.

---

### 4.7 Módulo de Pagos

**Archivos:** `lib/features/payments/`

#### Para el veterinario

- `CreateChargeScreen`: genera cobros con servicios personalizables, precio y duración.
- `VetPaymentSettingsScreen`: configura métodos de pago aceptados (SPEI, efectivo, terminal).
- `VetPaymentReviewScreen`: revisa comprobantes de pago enviados por dueños.
- `VetMonthlyReportScreen`: reporte mensual de ingresos con gráficas (fl_chart).

#### Para el dueño

- `OwnerPaymentsScreen`: lista de pagos pendientes y completados.
- `SpeiPaymentScreen`: instrucciones de transferencia SPEI con CLABE y referencia.
- Subida de comprobante de pago (imagen) via Firebase Storage.

#### Flujo de pago

```
Vet genera cobro → Dueño ve en "Mis Pagos" → 
Dueño sube comprobante SPEI → Vet aprueba → Estado: "paid"
```

---

### 4.8 Suscripciones y Feature Gates

**Archivos:** `lib/features/subscriptions/`

#### Tiers disponibles

| Tier | Descripción |
|---|---|
| `free` | Funciones básicas limitadas |
| `trial` | 6 meses completos al ser aprobado como vet |
| `basic` | Plan de pago básico |
| `premium` | Plan de pago completo |

- Al aprobar un veterinario por primera vez, se asigna automáticamente un trial de 6 meses.
- `SubscriptionProvider` expone el tier activo con fecha de expiración.
- Feature gates bloquean pantallas premium (reportes, configuración avanzada) para usuarios `free` sin trial.
- `VetSubscriptionScreen` muestra el estado actual y opciones de upgrade.

---

### 4.9 Directorio de Veterinarios

**Archivos:** `lib/features/vet_directory/`

- `VetDirectoryScreen`: listado de vets aprobados registrados en la plataforma.
- `VetLocationScreen`: mapa (Google Maps) con la ubicación registrada del vet.
- Filtrado por nombre o especialidad.

---

### 4.10 Módulo de Guardería / Boarding

**Archivos:** `lib/features/boarding/`  
**Versión del módulo:** v1.1.0

Este es el módulo más complejo de la plataforma. Gestiona el ciclo de vida completo de una reserva de estancia o servicios de estética.

#### Entidades principales

| Entidad | Descripción |
|---|---|
| `BoardingReservationEntity` | Reserva completa con fechas, servicios, estado, snapshot de seguridad |
| `BehavioralAssessmentEntity` | Evaluación conductual de la mascota |
| `VaccinationEntryEntity` | Entrada de cartilla de vacunas |

#### Servicios disponibles

```dart
enum ServiceType { boarding, daycare, bath, haircut }
```

#### Estados de reserva

```
pending → confirmed → checkedIn → completed
                   ↘ cancelled
```

#### Flujo de reserva

1. **Recepcionista / Admin** abre `ServiceBookingScreen` para una mascota.
2. Se seleccionan servicios, fechas y habitación/run.
3. Se ejecuta el **Triage Obligatorio**: `MedicalAndBehavioralTriageScreen` captura:
   - Evaluación conductual (agresividad, comportamiento social, nivel de estrés).
   - Verificación sanitaria: vacunas requeridas, salud visible.
   - Autorizaciones legales del dueño.
4. Se calcula el **ICD (Índice de Compatibilidad con la Guardería)** — score 0–100.
5. Se calcula el **nivel de riesgo** (green / yellow / orange / red).
6. La reserva se crea en Firestore con el `safetySnapshot` capturado en el momento.

#### Flujo de check-in

- El caretaker hace check-in desde su dashboard.
- Si falta completar el triage, se muestra `CheckInMandatoryOverlay` bloqueando el acceso.
- Al hacer check-in, el dueño recibe notificación push.

#### Cancelación de reservas

- Disponible para reservas en estado `pending` o `confirmed`.
- El dueño puede cancelar desde `OwnerReservationsScreen`.
- El recepcionista puede cancelar desde su dashboard.
- Confirmación obligatoria antes de ejecutar.

#### Reagendamiento

- El dueño puede reagendar reservas `confirmed` desde `OwnerReservationsScreen`.
- Validación de solapamiento con otras reservas de la misma mascota.

#### Vinculación de mascotas a sucursal

- `GeneratePetLinkCodeUseCase`: genera código `PET-XXXXXX` con expiración de 15 minutos.
- `LinkPetToOwnerUseCase`: redime el código y asocia la mascota a la sucursal.

---

### 4.11 Dashboards de Staff Operativo

Cada rol tiene su panel específico con información relevante a su función.

#### Panel de Estética — Groomer (`/groomer-dashboard`)

**Archivo:** `groomer_dashboard_screen.dart`

- Filtra reservas con `includesGrooming` (baño o corte).
- KPIs: En Servicio | Programados | Completados hoy.
- Secciones: "En Servicio Ahora" / "Próximas Citas de Estética" / "Completados Hoy".
- Cada tarjeta muestra: mascota, dueño, badge de riesgo, servicios, horario.
- Botones de acción: **Ver expediente** + **Cobrar** (navega a `/pet/:petId/charge`).

#### Panel de Guardería — Caretaker (`/caretaker-dashboard`)

**Archivo:** `caretaker_dashboard_screen.dart`

- KPIs: Hospedadas | Llegadas hoy | Salidas hoy | Alertas de seguridad.
- Lista de mascotas en estancia con:
  - Indicador de autorizaciones legales incompletas.
  - Notas del staff.
  - Botones **Check-In** y **Check-Out** con actualización directa a Firestore.
- Solo visible reservas del branch del caretaker autenticado.

#### Panel de Recepción — Receptionist (`/receptionist-dashboard`)

**Archivo:** `receptionist_dashboard_screen.dart`

- KPIs: Pendientes | Agenda hoy | Esta semana | Hospedadas actualmente.
- Acciones rápidas: Nueva Reserva, Buscar Dueño, Mascotas de Sucursal.
- Lista de agenda con columna de horario, mascota, dueño, servicios y estado.
- Acciones inline por reserva: **Ver expediente** + **Cancelar** (con confirmación).

---

### 4.12 Panel de Administrador

**Archivo:** `lib/features/auth/presentation/screens/admin_dashboard_screen.dart`

#### KPIs de sucursal

6 tarjetas de métricas en tiempo real:
- Volumen total de pagos
- Ganancia del periodo
- Número de transacciones
- Vets en espera de aprobación
- Mascotas registradas
- Veterinarios aprobados

#### Registro de Staff

El admin puede registrar staff desde el dashboard seleccionando rol:
- Veterinario → se envía a aprobación (claim `isApprovedVet: false`)
- Lavador / Estilista → claim `canPerformServices: true`
- Cuidador de Guardería → claim `canPerformServices: true`
- Recepcionista

Las invitaciones se guardan en `staff_invitations`. Al registrarse el staff con el email invitado, el rol se auto-asigna.

#### Aprobación de Veterinarios

- `_VetValidationCard`: muestra vets pendientes con nombre, email y licencia.
- Botones Aprobar / Rechazar.
- Al aprobar: se sincroniza el claim `isApprovedVet: true` + se asigna trial de 6 meses.

#### Lista de Staff de Sucursal

- `_BranchStaffCard`: muestra cada miembro con badge de rol con color específico:
  - Veterinario → dorado
  - Lavador / Estilista → verde menta
  - Cuidador → azul cielo
  - Recepcionista → naranja
- Toggle de activación/desactivación de cuentas de staff.

---

### 4.13 Wizard de Configuración Inicial

**Archivos:** `lib/features/setup_wizard/`

Flujo guiado de 4 pasos para nuevos administradores:

| Paso | Descripción |
|---|---|
| 0 | Nombre del negocio y dirección |
| 1 | Perfil del admin (foto, nombre, teléfono) |
| 2 | Configuración de habitaciones/runs disponibles |
| 3 | Invitación de primer staff |

**Persistencia:** El progreso se guarda en Firestore después de cada paso. Si el usuario cierra la app, el wizard retoma desde donde lo dejó (sincronización `PageController` ↔ estado Firestore con `addPostFrameCallback`).

**Guard de router:** Si el admin no tiene `branchId`, el router siempre redirige a `/setup-wizard`, sin posibilidad de saltar el flujo.

---

## 5. Backend — Cloud Functions

**Archivo:** `functions/src/index.ts`

| Función | Tipo | Descripción |
|---|---|---|
| `syncUserClaims` | Helper | Sincroniza custom claims JWT según rol + estado de aprobación |
| `onUserProfileCreatedV2` | Firestore Trigger | Al crear `/users/{uid}`: auto-link de invitación + sync de claims |
| `onUserProfileCreatedDemo` | Firestore Trigger | Igual para `/demo_users/{uid}` |
| `onUserProfileUpdatedV2` | Firestore Trigger | Al actualizar `/users/{uid}`: re-sync de claims, asigna trial al aprobar vet |
| `onUserProfileUpdatedDemo` | Firestore Trigger | Igual para `/demo_users/{uid}` |
| `generateQrToken` | Callable | Genera token QR de un solo uso (15 min) para compartir expediente |
| `scanAndActivateLease` | Callable | Redime un token QR, activa lease y notifica al dueño |
| `revokeVetAccess` | Callable | El dueño revoca el acceso del vet al expediente |
| `registerBranchStaff` | Callable | Admin registra staff: crea Auth user + Firestore doc + invitación |
| `approveComprobante` | Callable | Vet / Admin aprueba comprobante SPEI, pone pago en estado `paid` |
| `onBoardingReservationUpdatedV2` | Firestore Trigger | Notifica al dueño (FCM) en check-in y completado. Notifica a staff al confirmar reserva |
| `onBoardingReservationUpdatedDemo` | Firestore Trigger | Igual para colecciones demo |
| `setupDemoUser` | Callable | Siembra datos de demostración para las cuentas de inversores |
| `cleanupExpiredLinkCodes` | Scheduler (1h) | Elimina `pending_links` vencidos para reducir superficie de exposición |

### Auto-link de invitaciones de staff

Al crearse un nuevo perfil de usuario, el trigger busca en `staff_invitations` una invitación pendiente con el mismo email. Si existe:
1. Actualiza el documento del usuario con el rol y `branchId` de la invitación.
2. Marca la invitación como `accepted`.
3. Sincroniza los custom claims con el rol real (no `owner`).

---

## 6. Seguridad — Firestore Rules

**Archivo:** `firestore.rules`

Modelo de seguridad basado en **custom claims JWT**:

- `canPerformMedical` → lectura/escritura de historial clínico y vacunas.
- `canPerformServices` → lectura/escritura de reservas de guardería, actualización de estado.
- `isAdmin` → acceso de escritura a configuración de sucursal, staff, aprobaciones.
- `branchId` claim → aislamiento multi-tenant: solo se ven documentos del mismo `branchId`.
- Las reglas Firestore validan el claim JWT directamente, sin consultas adicionales.

---

## 7. Notificaciones Push (FCM)

**Integración:** `firebase_messaging: ^15.1.3`

### Configuración

- Token FCM guardado en `users/{uid}.fcmToken` en cada login.
- Canal Android `petcare_qr` para notificaciones de QR.
- Canal Android `petcare_boarding` para notificaciones de guardería.

### Notificaciones implementadas

| Evento | Destinatario | Mensaje |
|---|---|---|
| Vet escanea QR | Dueño | "El Dr. [nombre] ha accedido al expediente de [mascota]" |
| Reserva pending → confirmed | Staff de sucursal (caretakers, groomers, receptionists) | "Nueva reserva confirmada para [mascota] el [fecha]" |
| Reserva confirmed → checkedIn | Dueño | "[mascota] ha ingresado a la guardería" |
| Reserva checkedIn → completed | Dueño | "[mascota] ya puede ser recogida" |

Todas las notificaciones también persisten como documentos in-app en `users/{uid}/notifications`.

---

## 8. Sistema Multi-Tenant

La plataforma soporta múltiples clínicas/guarderías en producción y un ambiente demo aislado.

### Separación demo / producción

La utilidad `demoCollection()` en `FirestoreExtension` detecta si el email del usuario empieza con `demo.` y prefija automáticamente todas las colecciones con `demo_`.

```dart
// Uso transparente en toda la app:
FirebaseFirestore.instance.demoCollection('pets').doc(petId)
// → produce: 'demo_pets' o 'pets' según el tipo de cuenta
```

### Separación por sucursal

El claim `branchId` en el JWT aísla los datos entre sucursales. Los providers de Riverpod usan el `branchId` del usuario autenticado como clave de filtro en todas las queries relevantes.

---

## 9. Demo Accounts

Para presentaciones a inversores y pruebas de producto:

| Rol | Email | Contraseña |
|---|---|---|
| Dueño | `demo.owner@petcarepro.com` | `investor2026` |
| Veterinario | `demo.vet@petcarepro.com` | `investor2026` |
| Administrador | `demo.admin@petcarepro.com` | `investor2026` |

- Los datos demo se siembran con la Cloud Function `setupDemoUser`.
- Las cuentas demo operan sobre colecciones `demo_*` completamente aisladas.
- El scheduler de limpieza no afecta colecciones demo.

---

## 10. Historial de Cambios por Versión

### v1.1.0 — 2026-05-26 (en desarrollo / sin publicar)

#### Nuevo: Módulo de Guardería completo

- Entidad `BoardingReservationEntity` con snapshot de seguridad (`safetySnapshot`).
- Enums de dominio: `ReservationStatus`, `ServiceType`, `RiskLevel`, `AggressivenessLevel`, etc.
- Flujo de registro de reserva: `BoardingRegistrationFlow` (4 pasos).
- Triage médico y conductual obligatorio: `MedicalAndBehavioralTriageScreen`.
- `CheckInMandatoryOverlay`: bloqueo de check-in si el triage está incompleto.
- Cálculo de ICD (score de compatibilidad) y nivel de riesgo en tiempo de reserva.
- `ServiceBookingScreen`: reserva rápida para recepción.
- `OwnerReservationsScreen`: historial de reservas del dueño con reagendamiento y cancelación.
- `BoardingRepository` con: `createReservation`, `updateReservationStatus`, `updateReservationDates`, `cancelReservation`, `getActiveReservationsForDate`, `watchReservationsForPet`.

#### Nuevo: Roles de staff operativo

- 3 nuevos valores en el enum `UserRole`: `groomer`, `caretaker`, `receptionist`.
- Dashboards específicos para cada rol (ver §4.11).
- Router actualizado con rutas protegidas por rol para cada dashboard.
- `UnauthorizedScreen` cubre todos los roles en su botón "volver al panel".
- Admin puede registrar staff con estos roles; se asignan permisos automáticamente.

#### Nuevo: Wizard de configuración inicial

- `SetupWizardScreen` con 4 pasos persistidos en Firestore.
- Fix de sincronización `PageController` con progreso guardado (cold-start).
- Guard de router: admin sin `branchId` siempre redirige al wizard.

#### Mejoras: Cloud Functions

- `syncUserClaims` añade `canPerformServices` para groomer y caretaker.
- `registerBranchStaff` acepta los 4 roles de staff y crea invitación en `staff_invitations`.
- `onUserProfileCreated` auto-linkea invitaciones de staff al registrarse.
- `onBoardingReservationUpdated`: notifica a staff al confirmar, al dueño en check-in y completado.

#### Mejoras: Panel de Administrador

- Dropdown de registro de staff con 4 roles operativos.
- `_BranchStaffCard` muestra rol real con badge de color específico.
- Auto-asignación de `canPerformServices` según rol.

#### Correcciones

- Eliminado botón "Configurar más tarde" del wizard (causaba bucle infinito de redirect).
- Fix sincronización de controllers de texto en paso de perfil del wizard (race condition con carga de Firestore).
- Reemplazado uso de `package:intl` (no instalado) por helpers `padLeft` manuales en los 3 nuevos dashboards.
- Corregido `CollapseMode.parallax` (valor de enum correcto).
- Corregido nombre del método `logout()` en `AuthNotifier`.

---

### v1.0.0 — Commit inicial

#### Módulos entregados

- Autenticación completa (login, registro, recuperación de contraseña).
- Gestión de mascotas (CRUD con foto).
- Historial clínico con cartilla de vacunación dual (dueño + vet).
- Compartir expediente por QR con leases temporales.
- Panel del veterinario con acceso a expedientes escaneados.
- Módulo de pagos: cobros, SPEI, comprobantes, reporte mensual.
- Suscripciones con trial de 6 meses + feature gates.
- Directorio de veterinarios con mapa.
- Notificaciones FCM (QR activado).
- Admin dashboard con KPIs y aprobación de vets.
- Sistema multi-tenant con cuentas demo para inversores.
- Cloud Functions: RBAC, QR, pagos, subscripciones, limpieza de tokens.
- Firestore Security Rules con validación por custom claims.
- Firestore Indexes para queries compuestas.

---

*Documento generado automáticamente a partir del estado del repositorio — 2026-05-26*
