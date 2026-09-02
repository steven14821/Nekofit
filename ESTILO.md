# 🎨 Estilo Visual — NekoFit

Documento de identidad visual. Define la **esencia** de la app: la dirección estética concreta, los tokens de color, tipografía, comportamiento de componentes y las decisiones que la separan de cualquier app de fitness genérica.

> **Resumen en una frase:** NekoFit no se ve como "una app de fitness con un gato". Se ve como el sistema operativo de la tienda de tu gato personal, donde el gato es el dueño, los anaqueles están codificados por macro como en un konbini, y cada interacción con tu despensa pasa por su aprobación sarcástica.

---

## 🧭 Dirección: "Konbini 3AM × Neko-Gym"

Tienda de conveniencia japonesa a las 3 de la mañana cruzada con un gato entrenador sarcástico.

### Por qué este estilo y no otro

La app tiene **tres ADN** que no conviven bien con cualquier estética:

1. **"Neko"** = gato. Es japonés, no accidental. El nombre es un guiño directo a la cultura pop japonesa.
2. **"Fit" / mascota sarcástica que opina sobre macros** = tono muscle-bro con humor, no wellness zen.
3. **Despensa de inventario real en casa** = no es un food tracker genérico, es un konbini privado. Hay productos con sello de "AGOTADO", reposición rápida, anaqueles por categoría. Es un **punto de venta**, no una libreta.

Un estilo minimalista tipo Notion o Apple Health no soporta al gato. Un estilo kawaii puro infantiliza el lado fitness. El hueco está en la **estética de konbini japonés moderno**: denso, neón, un poco caótico, pero leíble; con el gato como el empleado que te mira por encima del mostrador y te juzga.

---

## 🎨 Paleta

| Rol | Color | Hex | Por qué |
|---|---|---|---|
| Fondo base | Indigo nocturno | `#0F0C20` | Ya lo tenías. Se queda. |
| Superficie elevada | Indigo medio con grano washi | `#1A1730` | Sutil, no plano. |
| **"En Existencia"** | Rosa neón | `#FF4D8D` | Cartel de konbini "在庫あり" |
| **"Agotado"** | Cian apagado | `#5EE2FF` | Como sello "完売" en japonés |
| Acento del gato | Mandarina | `#FFB347` | Patitas, hocico, bigotes |
| Categoría Proteínas | Rojo cereza | `#E63946` | Carnes |
| Categoría Carbohidratos | Ámbar trigo | `#F4A261` | Pan, arroz |
| Categoría Grasas | Verde matcha | `#8AB17D` | Aguacate, frutos secos |
| Categoría Vegetales | Verde brote | `#52B788` | Espinaca, brócoli |
| Categoría Lácteos/Huevos | Crema | `#F1C453` | Huevo |

Los cinco colores por macro son la **ventaja competitiva visual** — cada pestaña se siente distinta sin perder unidad. Hoy las cinco pestañas son texto blanco sobre fondo gris idéntico.

### Acento secundario

`#6C63FF` se conserva, pero **no es el color principal de marca** — es el "morado de startup SaaS" de 2018. Úsalo solo como acento secundario (indicador de selección, foco).

---

## 🔤 Tipografía (dos familias, no una)

- **Display / headers**: una display gorda con personalidad — `Boldonse`, `Bagel Fat One` o `DotGothic16` para acentos que evoquen pixel japonés.
- **UI / cuerpo**: sans geométrica limpia — `Inter`, `Manrope` o `Geist`. Los macros numéricos van en `JetBrains Mono` o `Space Mono` en tamaño gigante, como etiqueta nutricional japonesa.

---

## 🧱 Bordes y radios

- Tarjetas: `border-radius: 18` con borde de `1px` en el color de su categoría con opacidad 15% (efecto sticker).
- Chips: `10px`.
- FAB / botones flotantes: `28px`.
- Nada de bordes blancos genéricos.

Mezclar radios no es un accidente: se siente diseñado, no plantilla.

---

## 🐱 El gato en la UI

- **Burbujas de diálogo manga** para los mensajes del gato:
  - *Jagged/sharp* → "alerta sarcástica" (te excediste, tu macro está mal).
  - *Nube redonda* → "pensando/analizando" (escaneando un producto).
  - *Con corazón* → "músculo feliz" (cumpliste macros).
- **El gato no es un sticker**: aparece anclado a la esquina inferior derecha. A veces tapa parcialmente un FAB, a veces asoma desde una pestaña. Siempre con un objeto contextual (una mancuerna cuando validas, una lupa cuando escaneas, un sello rojo cuando marca "AGOTADO").
- **Estados Rive** (los cuatro del README: Idle, Pensando, Éxito, Alerta) deben ser **reconocibles sin texto**. Cola, orejas y bigotes son los indicadores.
- **Stamps / hanko**: al confirmar un reabastecimiento rápido, en lugar de un check genérico, un sello rojo circular estilo sello japonés que cae con física. Cuando es producto nuevo, evaluación detallada con tipografía de etiqueta nutricional.

---

## 🧩 Componentes clave

### Pestañas por macro
- El indicador inferior de la `TabBar` no es una línea — es una **píldora rellena con el color de la categoría**. Se siente como cambiar de anaquel.
- Las cinco categorías **no** comparten el mismo color blanco. Cada una con su color es lo que hace que abras la app y digas "ah, estoy en la zona de proteínas".

### Tarjeta de producto (layout bento)
- Foto a la izquierda (o emoji/icono).
- Nombre + gramos en la parte superior.
- Los cuatro macros (P / C / G / Cal) en una fila de **números grandes monoespaciados** en la parte inferior.
- Sin "mini chips" pequeños como en la versión actual. Los números son protagonistas: es una app de macros.

### Estado de agotado
- La tarjeta se **desatura y rota 0.5°** (efecto sello viejo), no se pone en gris plano como ahora.
- Mantiene su color de categoría, pero apagado.

### Header
- El gradiente `#1E1E30 → #0F0C20` se queda.
- El bloque de la meta calórica se convierte en una **insignia estilo emblema** con el icono del gato al lado. No un rectángulo con borde violeta genérico.

### Login / reemplazo del header
- El icono de logout en el header (estado actual) se reemplaza por un menú "despensa / cuenta" tipo tres líneas con un avatar del gato.

---

## 🚫 Lo que hay que evitar

1. **`#6C63FF` como color principal de marca** — es el morado de startup genérico. Úsalo solo como acento.
2. **Gato "lindo"** (redondo, ojos grandes, sonrosado). El gato de NekoFit es un **gato naranja sarcástico que hace sentadillas**. La ironía es la identidad.
3. **`border-radius: 12` en todo**. Mezclar radios (18 / 10 / 28) se siente diseñado.
4. **Icono de logout en el header plano**. Reemplazarlo por menú con avatar del gato.
5. **Cinco categorías en el mismo color blanco**. Cada una con su color es la firma visual.

---

## ✅ Plan de implementación

1. **Tokens de tema en `lib/core/theme.dart`** — paleta, tipografías, radios, sombras.
2. **Reimplementar `lib/screens/home_screen.dart`** con tarjetas bento, colores por categoría, layout de "anaquel" y reemplazo del header.
3. (Pendiente) Pantalla de onboarding con burbujas manga del gato desde el primer frame.
4. (Pendiente) Sistema de feedback del gato (burbujas, estados, hanko) acoplado a las acciones del usuario.
