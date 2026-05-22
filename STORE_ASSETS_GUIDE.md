# 🎨 Guía de Activos y Lanzamiento en Google Play Store
## PetCare Pro - Preparación para Producción

Esta guía contiene la lista de verificación (checklist) exhaustiva de recursos gráficos, textos legales y requisitos técnicos necesarios para publicar la aplicación de **PetCare Pro** en la Google Play Console de forma exitosa.

---

## 📐 1. Requisitos de Recursos Gráficos (Play Store Specs)

Google Play Console exige especificaciones de píxeles y formatos sumamente rigurosas para los elementos de marca. Asegúrate de diseñar los siguientes elementos respetando sus dimensiones:

### A. Ícono de la Aplicación (App Icon)
El icono debe ser representativo de la marca (estética moderna de cuidado de mascotas con nuestro acento verde jade/morado).
*   **Dimensión**: `512 x 512 píxeles`
*   **Formato**: PNG de 32 bits (transparente o con fondo).
*   **Peso máximo**: `1 MB`
*   **Nota**: Google aplica esquinas redondeadas y sombras de forma automática al renderizar. Sube un diseño cuadrado limpio.

### B. Gráfico de Funciones (Feature Graphic)
Es el banner promocional que aparece en la parte superior de la ficha de Play Store en dispositivos móviles.
*   **Dimensión**: `1024 x 500 píxeles`
*   **Formato**: PNG o JPEG (sin transparencia).
*   **Composición**: Coloca los elementos principales (logotipo de PetCare Pro y mockups) al centro del lienzo para evitar cortes en pantallas recortadas.

### C. Capturas de Pantalla (Screenshots) por Rol
Debes subir al menos 4 capturas de pantalla de alta fidelidad. Es sumamente recomendable usar maquetas de teléfonos reales y agregar textos descriptivos premium.

#### Requisitos de Tamaño de Pantalla:
1.  **Teléfonos Inteligentes (Smartphone)**: Relación de aspecto `16:9` o `18:9` (mínimo `1080 x 1920 píxeles`). Sube entre 4 y 8 capturas.
2.  **Tablets de 7 y 10 pulgadas** (Opcional pero recomendado): Mínimo `1080 x 1920 píxeles`.

#### Capturas Recomendadas por Rol (Demostración de Valor):
*   **Captura 1 (Dueño)**: Dashboard principal con Rocky y Luna (Muestra el listado dinámico premium de mascotas).
*   **Captura 2 (Dueño)**: Pantalla de código QR con el temporizador visual activo (Muestra la generación segura de tokens de acceso).
*   **Captura 3 (Veterinario)**: Interfaz de escaneo QR y listado de pacientes autorizados (Muestra la conexión clínica al instante).
*   **Captura 4 (Veterinario)**: Expediente de diagnóstico y tratamiento médico con recetas asociadas.
*   **Captura 5 (Administrador/Finanzas)**: Panel financiero global con el volumen total procesado y comisiones del 5% netas.

---

## ✍️ 2. Ficha de Play Store (Ficha de la App)

Prepara los siguientes copys y textos en español para completar los campos obligatorios:

*   **Nombre de la Aplicación**: `PetCare Pro` (Máximo 30 caracteres).
*   **Descripción Corta**: `Tu expediente veterinario móvil premium con accesos QR ultra-seguros.` (Máximo 80 caracteres).
*   **Descripción Completa** (Máximo 4000 caracteres):
    *   *Detalla las características principales*: Registro de mascotas, expedientes clínicos dinámicos por arrendamiento de 2 horas mediante QR, catálogo de servicios clínicos, cargos en caliente con simulación de pasarela, panel de comisiones brutos del 5% para auditoría de administradores y un diseño premium en Modo Oscuro con glassmorphism.

---

## 🔒 3. Requisitos de la Política de Privacidad

Debido a que **PetCare Pro** recopila datos sensibles (información médica veterinaria, datos de geolocalización, fotos de mascotas a través de la cámara y galería), Google exige una URL de Política de Privacidad activa.

### Puntos Obligatorios a Declarar en tu Política:
1.  **Uso de la Cámara**: Declarar que el permiso de cámara se solicita única y exclusivamente para leer códigos QR de vinculación temporal e imágenes de mascotas para el expediente.
2.  **Almacenamiento de Datos Médicos**: Indicar que los historiales clínicos son de carácter privado, administrados de forma serverless en Firestore y encriptados en reposo y en tránsito.
3.  **Procesamiento de Pagos**: Declarar que la facturación de servicios es simulada para fines informativos y de auditoría contable interna del centro veterinario (o describir el procesador final de Stripe/Mercado Pago si decides implementarlo).
4.  **Uso de Fotos e Imágenes**: Indicar que la subida de imágenes a Google Cloud Storage requiere consentimiento explícito del dueño y no se comparte con terceros.

---

## 🛠️ 4. Lista de Verificación de Configuración Técnica (Google Play Console)

Antes de presionar "Subir", asegúrate de tener configurado lo siguiente:

- [ ] **Firma de la Aplicación**: Flutter compila el APK release firmado con la clave por defecto si estás en depuración, pero para Google Play debes configurar tu almacén de claves (`keystore`) en Android para firmar tu App Bundle (`.aab`).
- [ ] **Generar Android App Bundle (AAB)**: Para Play Store, compila con `flutter build appbundle --release` (Genera un archivo más ligero que optimiza las descargas del usuario).
- [ ] **Declaración de Privacidad de Contenido de la App**: Completar los formularios obligatorios en la consola de Google:
    *   Declaración de anuncios (Nuestra app es 100% libre de anuncios).
    *   Clasificación de contenido (Apto para todo público).
    *   Acceso de la aplicación (Declarar que requiere inicio de sesión y proporcionar un usuario de prueba para los revisores de Google, ej. `carlos.mendoza@gmail.com`).
- [ ] **Políticas del SDK de Firebase**: Declarar el uso del SDK de Firebase para el análisis de crashes (Crashlytics) y autenticación.
