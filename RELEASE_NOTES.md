# 🚀 PetCare Pro - Notas de Lanzamiento (Release Notes)
## Versión 1.0.0 - Estable & Producción

PetCare Pro es un ecosistema digital premium multirrol (Dueños, Veterinarios y Administradores) diseñado para la gestión segura y transparente de expedientes clínicos animales. Esta versión de lanzamiento oficial marca la transición completa de la plataforma fuera del entorno de sandbox local, operando con un backend serverless real en Google Cloud.

---

## 🌟 Características Clave por Rol

### 🧑‍💼 1. Módulo del Dueño de Mascota (Pet Owner)
*   **Gestión de Perfiles Clínicos**: Registro completo de mascotas con validación estricta de especie, raza, edad y carga asíncrona de imágenes de perfil directamente a Google Cloud Storage.
*   **Tokens QR Dinámicos**: Generación segura en tiempo real de pases de acceso QR válidos exactamente por **15 minutos** para autorizar consultas clínicas de forma presencial.
*   **Control Financiero**: Pasarela integrada de visualización de cobros pendientes y pagos históricos emitidos por el veterinario con simulación de transacciones bancarias.

### 🩺 2. Módulo del Veterinario (Veterinarian)
*   **Escáner QR Integrado**: Lector de cámara en vivo y simulador demo de tokens QR para obtener arrendamientos clínicos temporales y seguros.
*   **Arrendamiento Clínico Seguro**: Emisión automática de permisos temporales de lectura y escritura sobre el expediente clínico de la mascota durante exactamente **2 horas**.
*   **Historial Clínico Digital**: Formulario intuitivo de diagnóstico, recetas y justificaciones técnicas médicas con carga de archivos adjuntos (recetas en PDF, radiografías).
*   **Gestión de Servicios y Facturación**: CRUD de catálogo de servicios personalizados y emisión instantánea de cargos financieros vinculados a la consulta.

### 👑 3. Módulo del Administrador (Admin)
*   **Auditoría Financiera en Caliente**: Stream reactivo en tiempo real con monitoreo del volumen procesado total, comisiones brutas del ecosistema (5%) e historial de cobros liquidados.
*   **Gestión Centralizada de Mascotas**: Acceso completo y en tiempo real a todas las mascotas del ecosistema. Permite ver nombres, especies, razas, edades, y **modificar directamente sus datos en Firestore** mediante un dashboard altamente intuitivo.
*   **Control de Calidad Médica**: Panel de aprobación manual de veterinarios mediante validación de cédulas profesionales antes de conceder acceso al scanner clínico.

---

## 🛠️ Arquitectura de Seguridad Avanzada (QR Clínico)
El control de privacidad se rige por un **oráculo criptográfico híbrido**:
1.  El Dueño emite un token de alta entropía temporal en Firestore (`/qr_tokens`) con vigencia corta (15 min).
2.  Al escanear, la **Cloud Function Gen2** (`validateQrLease`) valida que el código sea de estado `pending` y que la firma pertenezca al dueño legítimo.
3.  Si la validación es exitosa, se genera una transacción atómica que cambia el estado a `active` y crea un **documento compuesto de acceso** indexado por `${vetId}_${petId}`.
4.  Las **Firestore Security Rules** realizan una validación existencial `exists()` en complejidad constante `O(1)` sobre dicho documento, permitiendo al veterinario leer y escribir en el expediente de forma ultra-segura sin escaneos costosos de colecciones globales.

---

## 🛡️ Resoluciones de Casos Críticos de Producción (*Edge Cases*)

Esta versión incluye tres correcciones fundamentales que garantizan estabilidad a nivel empresarial en dispositivos reales:

### 1. Fallback de JWT y Latencia de Claims
*   *Bug*: Al aprobarse un veterinario en Firestore, los *Custom Claims* del token JWT de Firebase Auth tardan en propagarse en la aplicación del cliente, provocando que la Cloud Function arrojara un error de `permission-denied` en el scanner clínico.
*   *Solución*: Implementamos un **fallback de base de datos en tiempo real** en `validateQrLease`. Si las credenciales JWT no contienen la aprobación debido a la latencia de Firebase, la función consulta instantáneamente la colección `/users/{uid}` en la base de datos Firestore, validando la autorización al segundo y eliminando cualquier retraso de experiencia de usuario.

### 2. Casteo de Tipos en Dart para Release
*   *Bug*: Al compilar la aplicación en modo Release optimizado, el casteo implícito de Dart para las llamadas HTTPS Callable (`callable.call<Map<String, dynamic>>`) arrojaba un error de casteo de tipos (`_Map<Object?, Object?> is not a subtype of Map<String, dynamic>`) crasheando el flujo de QR.
*   *Solución*: Reestructuramos la invocación para recibir un tipo dinámico nativo y deserializar el payload de forma segura a través de `Map<String, dynamic>.from(response.data as Map)`, garantizando compatibilidad total en empaquetamientos release de Android e iOS.

### 3. Índice Compuesto de Auditoría Admin
*   *Bug*: El panel del Administrador fallaba al realizar la consulta agregada de auditoría en la nube debido a la ausencia de un índice compuesto estructurado para el filtrado por estado (`status == 'paid'`) y ordenamiento cronológico descendente (`createdAt DESC`).
*   *Solución*: Diseñamos y desplegamos el índice compuesto directo en producción a través del archivo de configuración `firestore.indexes.json`.

---

## 📦 Detalles del Entregable APK
*   **Ruta local del instalador**: `build/app/outputs/flutter-apk/app-release.apk`
*   **Peso**: `68.0 MB` (Optimizado mediante tree-shaking de recursos del sistema).
*   **Firma**: Generado en modo Release para instalación directa en dispositivos reales.
