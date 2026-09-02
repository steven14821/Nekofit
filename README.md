# 🐱 NekoFit: Tu Despensa e Inventario Nutricional Inteligente

**NekoFit** es una aplicación móvil multiplataforma desarrollada en **Flutter** que revoluciona la gestión de la dieta y el conteo de macronutrientes. A diferencia de las aplicaciones tradicionales que dependen de bases de datos globales imprecisas o interfaces aburridas, NekoFit introduce el concepto de **Despensa Única de Inventario Híbrido** y una **Mascota IA Interactiva** (un gato —o perro— animado) que guía, analiza y da feedback personalizado al usuario basándose estrictamente en su contexto biológico y los alimentos reales de su hogar.

La aplicación funciona como un inventario inteligente que elimina la fricción del registro repetitivo: el escáner de códigos de barras y el buscador de frescos se utilizan **única y exclusivamente la primera vez que se compra un producto nuevo**. Para los mercados posteriores, el usuario reabastece su despensa en segundos reactivando productos desde su historial de "Agotados". Posteriormente, al tomar una foto a sus platos diarios, la IA identifica los componentes y descuenta las porciones de las existencias actuales.

La identidad visual sigue la dirección **"Konbini 3AM × Neko-Gym"** (tienda de conveniencia japonesa a las 3 a.m. cruzada con un gato entrenador sarcástico). Los detalles de paleta, tipografía y componentes están documentados en [ESTILO.md](./ESTILO.md).

---

## 🛠️ Stack Tecnológico

* **Frontend:** Flutter & Dart (renderizado de alta tasa de refresco a 60/120 FPS) con Riverpod para gestión de estado e inyección de dependencias.
* **Mascota:** Widget de Flutter con animaciones controladas por código (`NekoCatMascot`), estados *Espera / Pensando / Éxito / Alerta* y overlays de outfits (gato/perro).
* **Backend & Base de Datos:** Firebase — Firestore (NoSQL), Authentication (email + Google Sign-In), Cloud Storage (imágenes comprimidas), App Check e In-App Update; Cloud Functions.
* **Procesamiento de IA:** Firebase AI (Gemini `3.5-flash`) para visión de platos, extracción de macros por voz/texto, chat de la mascota y **generación de planes semanales**; ML Kit para OCR de tablas nutricionales (`google_mlkit_text_recognition`) y detección de objetos on-device (`google_mlkit_object_detection`).
* **Datos de producto:** Open Food Facts (mirror `es.openfoodfacts.org`) para códigos de barras y búsqueda por nombre.
* **Salud y actividad:** Health Connect (Android) — pasos, distancia y calorías activas — vía el paquete `health`.
* **Extras:** `speech_to_text` (registro por voz), `fl_chart` (estadísticas semanales), `flutter_local_notifications` (recordatorios de comidas), `table_calendar`, `camera`, `mobile_scanner`.
* **Internacionalización:** `flutter gen-l10n` con plantillas ARB en español e inglés (`app_es.arb` / `app_en.arb`).

---

## 📲 Estado actual y navegación

El onboarding post-registro configura el contexto completo del usuario en **3 pasos**: *Lo esencial* (género, edad, altura, peso y objetivo), *Personaliza* (% grasa, estilo de vida, entrenamiento, mascota) y *Personalización extrema* (opcional). Tras esto, la app usa una **bottom navigation** con 5 secciones:

```
 🏠 Inicio  │  📦 Despensa  │  📅 Diario  │  🐱 Mascota  │  👤 Perfil
```

1. **Inicio (`HomeDashboard`):** saludo hero, stats rápidas en grid 2×2, CTAs a las pantallas más usadas y un tip sarcástico del gato según su humor.
2. **Despensa (`PantryScreen`):** inventario único con pestañas por macro (Proteínas / Carbohidratos / Grasas / Vegetales / Lácteos-Huevos), estados *En Existencia* / *Agotados* y reposición rápida. Incluye escáner de código de barras, buscador de frescos y plan de compras.
3. **Diario (`DiaryScreen`):** timeline de comidas del día con navegación de fechas y registro desde despensa, foto, voz o receta; resumen de macros y metas.
4. **Mascota (`PetScreen`):** hambre, humor, nivel y XP de la mascota, chat con la IA (persistente) y acceso al **vestidor** de outfits.
5. **Perfil (`ProfileScreen`):** contexto biológico, metas de macros, edición, recordatorios de comidas, estadísticas y avisos de transición de fase del plan nutricional.

### ⚡ Personalización extrema (planes nutricionales con contexto)

NekoFit genera planes nutricionales con **plazo definido (4 / 8 / 12 semanas)** y contexto real del usuario:

* **Fases:** *déficit* (perder peso), *mantenimiento*, *superávit* (ganar músculo) y *recomposición*.
* **Calorías dinámicas:** el déficit/superávit escala según la duración (4 s → −500/+350 kcal · 8 s → −400/+300 · 12 s → −300/+250) con un suelo mínimo calórico de 1200 kcal.
* **Ritmo diario:** 3, 4 o 5 comidas al día y **ayuno intermitente** opcional (16:8 / 18:6) — ambos dan forma al plan semanal IA.
* **Contexto de salud y alimentos:** condiciones médicas (insulino-resistencia, hipertensión, hipotiroidismo…), preferencias/restricciones (vegana, keto, sin gluten…), alimentos *imprescindibles* y *aversiones* de todo lo cual se **inyecta en el prompt de Gemini** cada semana.
* **Ciclo de vida:** al vencer el plan, el perfil muestra la **fase de transición recomendada** y solo recalcula macros cuando el usuario la **aprueba**.
* **Persistencia:** subcolección `users/{uid}/plans/{id}`, protegida por las reglas de Firestore.

---

## 📌 Requerimientos del Sistema

### Requerimientos Funcionales (RF)

| ID | Requerimiento | Estado |
|---|---|---|
| RF-1 | Autenticación y contexto de usuario (edad, peso, altura, actividad, metas de macros). | ✅ Implementado |
| RF-2 | Escáner de código de barras para productos nuevos (cámara + Open Food Facts + OCR a tabla nutricional). | ✅ Implementado |
| RF-3 | Despensa única con filtro por pestañas según rol nutricional. | ✅ Implementado |
| RF-4 | Sistema de inventario por estados (`isAvailable`: Existencia vs. Agotados). | ✅ Implementado |
| RF-5 | Reposición rápida con fricción cero (un toque desde "Agotados", operación atómica). | ✅ Implementado |
| RF-6 | Buscador de frescos con foto opcional. | ✅ Implementado |
| RF-7 | Registro de comidas por foto (IA): reconocimiento de plato + gramaje estimado + sliders de porciones. | ✅ Implementado |
| RF-8 | Feedback dinámico de la IA: opinión macro-nutricional para productos nuevos y mensajes cortos para reposiciones. | ✅ Implementado (chat + mensajes híbridos) |
| RF-9 | Estimador predictivo de agotamiento basado en el historial de consumo (30 días). | ✅ Implementado (servicio de estimación + crítico/aviso) |
| RF-10 | Plan nutricional con plazo definido y contexto (fases, nº de comidas, ayuno, condiciones médicas y preferencias) que alimenta al plan semanal IA. | ✅ Implementado |
| RF-11 | Internacionalización completo (ES/EN) de pantallas y flujos mediante `AppLocalizations`. | ✅ Implementado |

### Requerimientos No Funcionales (RNF)

| ID | Requerimiento | Estado |
|---|---|---|
| RNF-1 | Rendimiento gráfico fluido (60 FPS) en animaciones de la mascota y transiciones. | ✅ Implementado |
| RNF-2 | Imágenes <100KB comprimidas localmente y subidas a Storage; purga de imágenes del diario a los 30 días. | ✅ Implementado (compresión en bucle vía `flutter_image_compress`) |
| RNF-3 | Operaciones de estado atómicas y sin duplicación en Firestore (update/transaction). | ✅ Implementado |
| RNF-4 | Suite de pruebas automatizadas (modelos, providers y cálculo de macros/planes) ejecutada con `flutter test`. | ✅ Implementado |

---

## 📅 Plan de Trabajo: Metodología SCRUM

El proyecto se divide en **4 Sprints** de dos semanas cada uno, enfocados en construir un Producto Mínimo Viable (MVP) completamente funcional.

[Sprint 1: Base & UI] ➔ [Sprint 2: Motor del Inventario] ➔ [Sprint 3: Visión IA & Foto] ➔ [Sprint 4: Gamificación & Pulido]

### Sprint 1: Arquitectura Base, Contexto y Diseño de Interfaz (Semanas 1-2) ✅ Completado
* **Objetivo:** Establecer los cimientos del proyecto y el diseño visual de la app en Flutter.
* **Tareas (Backlog):**
    * [x] Configuración del repositorio y entorno de Flutter con soporte para Móvil (Android/iOS).
    * [x] Vinculación inicial con Firebase (Auth, Firestore, Storage, App Check).
    * [x] Login, registro (email + Google) y formulario de Contexto de Usuario (metas de macros).
    * [x] Maquetación de la Despensa Única con pestañas superiores y separación de activos/agotados.
    * [x] Navegación principal con bottom nav (Inicio, Despensa, Diario, Mascota, Perfil) y dashboard de resumen.

### Sprint 2: Lógica de Estados del Inventario, Escáner y Reposición Rápida (Semanas 3-4) ✅ Completado
* **Objetivo:** Implementar la lógica del inventario para evitar el re-escaneo repetitivo de productos.
* **Tareas (Backlog):**
    * [x] Integración de la librería de cámara y lectura de códigos de barras (EAN-13) exclusivo para productos nuevos.
    * [x] Conexión con la API de Open Food Facts priorizando el mirror en español (`es.openfoodfacts.org`) para mejor cobertura de productos colombianos; si el mirror global tiene el producto también se acepta.
    * [x] Módulo OCR para tablas nutricionales nuevas (Google ML Kit Text Recognition, parser heurístico en español para "calorías/proteínas/carbohidratos/grasas").
    * [x] Buscador de alimentos frescos con la función de añadir fotografía opcional del usuario.
    * [x] **Flujo de Reposición:** botón de un solo toque en la pestaña de "Agotados" para reactivar alimentos actualizando el timestamp de compra, con feedback visual (SnackBar) y operación atómica.
    * [x] **Fallback por nombre** en el escáner: si el EAN no existe en OFF (común con marcas locales colombianas), el usuario puede buscar por nombre y reutilizar los macros del primer resultado coincidente.
    * [ ] ~~Adivinanza automática cuando el barcode existe en OFF pero la entrada está vacía~~ — **Eliminada**: causaba resultados imprecisos. Ahora el usuario busca manualmente.
    * [x] Inferencia de categoría (pestaña de la despensa) con heurística de palabras clave colombianas (plátano, yuca, ahuyama, arepa, lulo, etc.) compartida entre el escáner y el buscador.
    * [x] **Unidad base g/ml** resuelta desde `nutrition_data_per` de OFF, mostrada explícitamente en el sheet y persistida en Firestore.
    * [x] **Cantidad en gramos** configurable al guardar, requerida cuando el producto fue adivinado/buscado por nombre.
    * [x] **Imagen del producto**: descarga automática desde OFF cuando hay `image_front_url`, subida comprimida (<100KB JPEG) a Firebase Storage (`users/{uid}/pantry/{id}.jpg`).
    * [x] **Pantalla de edición de producto** (tap o long-press en la tarjeta) para cambiar foto, nombre, cantidad, categoría y macros.

### Sprint 3: Reconocimiento de Platos con IA y Diario Alimentario (Semanas 5-6) ✅ Completado
* **Objetivo:** Desarrollar el core tecnológico de la aplicación: el procesamiento fotográfico del plato cruzado con las existencias.
* **Tareas (Backlog):**
    * [x] Interfaz del Diario Alimentario diario con timeline por tipo de comida y navegación de fechas.
    * [x] Algoritmo de compresión local de imágenes (<100KB) para optimizar Storage.
    * [x] Integración con Gemini (Firebase AI) para identificar componentes del plato filtrando sobre los productos "En Existencia" del usuario.
    * [x] Sistema de estimación de porciones visuales mediante sliders interactivos.
    * [x] Detección de objetos on-device con ML Kit para dibujar bounding boxes sobre la foto capturada.
    * [x] Registro por **voz o texto** (`speech_to_text` + Gemini) cuando no hay foto.
    * [x] **Recetario rápido:** construir una comida a partir de varios ingredientes de la despensa.
    * [x] Alimentar a la mascota y actualizar la racha (streak) al guardar comidas.

### Sprint 4: Personalidad de la Mascota IA, Lógica Híbrida de Opinión y Lanzamiento (Semanas 7-8) ✅ Completado
* **Objetivo:** Darle "vida" a la aplicación mediante animaciones, gamificación y reglas de predicción.
* **Tareas (Backlog):**
    * [x] Widget de mascota animada (`NekoCatMascot`) con 4 estados (*Espera, Pensando, Éxito, Alerta*), sistema de outfits y variantes gato/perro.
    * [x] Estructuración del *System Prompt* de la IA para adoptar la personalidad fitness de la mascota (chat persistente en `chat_history`).
    * [x] Lógica híbrida de opinión: opinión macro-nutricional para escaneos nuevos y mensajes cortos/dinámicos para reposiciones.
    * [x] Estimador predictivo de agotamiento basado en el historial de consumo del diario (últimos 30 días).
    * [x] Reglas de seguridad en Firestore (acceso por usuario) e índice compuesto de `meals.createdAt`.
    * [x] Integración con **Health Connect** (pasos, distancia y calorías activas) y sección de pasos en el dashboard.
    * [x] **Estadísticas semanales** con `fl_chart` (calorías, macros y comidas recientes vs. metas).
    * [x] **Recordatorios de comidas** con notificaciones locales configurables desde el perfil.

### 💎 Personalización Extrema (Planes Nutricionales Contextuales) ✅ Completado
* **Objetivo:** llevar la planificación nutricional más allá de metas estáticas, con planos con plazo, ritmo y contexto reales integrados con el plan semanal IA.
* **Tareas (Backlog):**
    * [x] Modelo `NutritionPlan` (fases `cut`/`maintenance`/`lean_gain`/`recomposition`), `MealSchedule` (3/4/5 comidas + ayuno) y `NutritionContext` (condiciones médicas, preferencias/restricciones, imprescindibles y aversiones).
    * [x] Ajuste calórico escalado por duración (4/8/12 semanas) con suelo mínimo de 1200 kcal en `CalorieCalculator`.
    * [x] Servicio `NutritionPlanService` con persistencia en `users/{uid}/plans/{id}` y cálculo de macros desde el TDEE + fase.
    * [x] Integración del contexto en el prompt de Gemini del `WeeklyPlanService` (nº de comidas, ventana de ayuno, condiciones, aversiones e imprescindibles) + fallback determinístico con ritmo/ayuno.
    * [x] **Paso 3 opcional** en el onboarding (`ProfileSetupScreen`) y aviso de **transición de fase** con aprobación del usuario en el perfil.
    * [x] Regla `plans` en `firestore.rules` y claves i18n (ES/EN) para todos los flujos nuevos.
    * [x] Suite de pruebas para modelos, `caloricAdjustment`, `mealPartitioning` y `feedingWindowSlots`.

---

## 🔒 Seguridad y Reglas

* **Firestore:** cada usuario solo puede leer/escribir su propio documento y subcolecciones (`request.auth.uid == userId`), incluidas `meals`, `pantry`, `recipes`, `chat_history`, `plans` y `pet` — ver [`firestore.rules`](./firestore.rules). Las subcolecciones sensibles exigen perfil completo (`isProfileComplete()`).
* **App Check** activado para proteger las llamadas a Firebase.
* **Firebase AI** (Gemini) se consume mediante la capa `firebase_ai` (claves administradas por Firebase).
* **Archivos sensibles excluidos del repo:** `android/app/google-services.json` y keystores de firma no se suben; regenera `google-services.json` desde Firebase Console para compilar Android en otra máquina.

---

## 🚀 Comenzar / Ejecutar

```bash
# 1. Dependencias
flutter pub get

# 2. Generar localizaciones (fuente ARB en lib/l10n)
flutter gen-l10n

# 3. Configurar Firebase (Auth, Firestore, Storage, App Check, AI)
#    - Coloca android/app/google-services.json (regenerable desde Firebase Console)
#    - Ajusta cualquier archivo de configuración de iOS si corresponde

# 4. Verificación de calidad
flutter analyze        # debe reportar 0 issues
flutter test           # suite de pruebas (modelos, providers, Cálculos y planes)

# 5. Ejecutar
flutter run
```

Las reglas de Firestore se despliegan con:
```bash
firebase deploy --only firestore:rules
```
