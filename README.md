# 🐾 PetCare Pro - Expediente Clínico Digital Multirrol

PetCare Pro es una plataforma móvil premium multiplataforma diseñada bajo estándares de ingeniería clínica para la gestión transparente, segura y moderna de expedientes médicos veterinarios. Utiliza un modelo de arquitectura serverless de alta disponibilidad gobernado por contratos dinámicos de acceso temporal mediante códigos QR.

---

## 🏗️ Stack Tecnológico

El ecosistema está construido utilizando tecnologías modernas y seguras:

*   **Frontend (Cliente)**:
    *   **Flutter (Dart)**: Desarrollo nativo multiplataforma en iOS y Android.
    *   **Riverpod**: Gestor de estado reactivo e inyección de dependencias robusta con validación en tiempo de compilación.
    *   **GoRouter**: Enrutador declarativo estructurado con guards de redirección basados en roles de usuario.
    *   **Mobile Scanner & QR Flutter**: Escaneo óptico en tiempo real y generación de códigos vectoriales de alta fidelidad.
*   **Backend (Serverless en Google Cloud)**:
    *   **Firebase Authentication**: Registro y control de accesos con Custom Claims de JWT.
    *   **Cloud Firestore**: Base de datos documental NoSQL de baja latencia con índices compuestos de auditoría.
    *   **Cloud Storage**: Repositorio seguro para imágenes de mascotas y reportes clínicos médicos (PDF/análisis).
    *   **Cloud Functions Gen2 (TypeScript)**: Lógica serverless de negocio, oráculos de asignación de roles y transacciones de arrendamiento dinámico de datos.

---

## 📂 Arquitectura de Directorios del Cliente (Clean Architecture)

El código de Flutter implementa una arquitectura estructurada por características funcionales (Features), divididas en tres capas de abstracción para garantizar modularidad y mantenibilidad:

```
lib/
├── core/                       # Elementos globales inmutables del sistema
│   ├── constants/              # Colores, constantes de UI, strings globales
│   ├── routing/                # Enrutador GoRouter y guards de redirección
│   ├── theme/                  # Sistema de temas e HSL tokens premium (Light/Dark)
│   └── utils/                  # Formateadores, helpers y utilidades
│
└── features/                   # Rebanadas funcionales de negocio (Slices)
    ├── auth/                   # Autenticación, registro y panel de administración
    ├── pets/                   # CRUD de mascotas y gestor de fotos en Storage
    ├── medical_history/        # Expediente clínico y adjuntos médicos sensibles
    └── qr_sharing/             # Escáner y generador de tokens de acceso QR
```

---

## 🛠️ Guía Rápida de Instalación y Ejecución

### Requisitos Previos
*   Flutter SDK v3.22 o superior
*   Node.js v20 o superior (para Backend y scripts)
*   Firebase CLI instalado globalmente (`npm install -g firebase-tools`)

### 1. Clonar el repositorio y configurar dependencias
```bash
# Instalar dependencias de Flutter
flutter pub get

# Instalar dependencias del Backend (Cloud Functions)
cd functions
npm install
```

### 2. Ejecutar los Emuladores Locales (Entorno de Desarrollo)
Si deseas trabajar en modo local con los emuladores de Firebase en lugar de la red de producción real, realiza los siguientes pasos:

1.  **Levantar el Sandbox Local de Firebase**:
    ```bash
    # Desde la raíz del proyecto
    firebase emulators:start
    ```
    *   *Auth*: Puerto `9099` | *Firestore*: Puerto `8080` | *Storage*: Puerto `9199` | *Functions*: Puerto `5001`.
    *   *Suite UI (Consola Gráfica)*: [http://localhost:4000](http://localhost:4000)

2.  **Activar los Emuladores en el Cliente**:
    Abre **[main.dart](file:///C:/Users/Admin/Documents/PetCare%20Pro/lib/main.dart)** y descomenta las líneas correspondientes al bloque de emuladores para redirigir el tráfico a los puertos locales.
    *   *Tip de red*: Configura la variable `host` en `main.dart` con la dirección IP local de tu red Wi-Fi si estás probando la app en un teléfono físico en lugar del emulador.

### 3. Ejecutar la Aplicación en Modo de Desarrollo
```bash
flutter run
```

---

## ⚡ Arquitectura de Cloud Functions Gen2 (TypeScript)

El backend expone 4 funciones serverless críticas en producción que actúan como guardianes del sistema:

1.  **`onUserProfileCreatedV2`**: Trigger reactivo en Firestore que se ejecuta tras el registro de un usuario en Auth. Crea su documento de perfil inicial e inyecta el claim del rol correspondiente.
2.  **`onUserProfileUpdatedV2`**: Trigger reactivo que detecta cambios de roles o estados de validación médica (aprobación de veterinarios por el Admin) y actualiza de inmediato sus JWT Custom Claims en caliente.
3.  **`generateQrToken`**: Callable para dueños. Valida la correspondencia de propiedad de la mascota y genera un token único en la base de datos con expiración de exactamente **15 minutos**.
4.  **`validateQrLease`**: Callable para veterinarios aprobados. Valida la vigencia del token e inicia una transacción atómica que cambia el estado a `active` y calcula un periodo de arrendamiento clínico de **2 horas** creando el indexador compuesto `${vetId}_${petId}`.

---

## 🛡️ Reglas de Seguridad Clave en Producción

El ecosistema se auto-protege mediante estrictas directrices de acceso en **`firestore.rules`**:
*   **Dueños (Owners)**: Lectura/Escritura completa sobre sus registros y los de sus mascotas.
*   **Veterinarios (Vets)**: Acceso restringido a expedientes clínicos. El sistema valida en tiempo real mediante `exists()` si el veterinario cuenta con un arrendamiento QR activo para la mascota consultada.
*   **Administradores (Admins)**: Acceso y control global para auditorías contables e infraestructura.
