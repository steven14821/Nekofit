# Sprint 3 — Ideas de Navegación para el Diario Alimentario

> Documento de exploración de diseño. Guardado para referencia futura.

---

## Contexto

Actualmente NekoFit tiene la **Despensa** como centro único de navegación. El header tiene íconos para escanear (QR), buscar (lupa) y un menú (PopupMenuButton con solo "Cerrar sesión"). No hay bottom nav, drawer ni tabs de secciones principales.

Para el Sprint 3 (Diario Alimentario) se exploraron 3 enfoques de navegación:

---

## 🔷 Opción 1: Bottom Navigation con 2-3 tabs (la más práctica)

Agregar una `BottomNavigationBar` con 2-3 pestañas:

```
 ┌─────────────┬──────────────┬──────────────┐
 │   🐱       │    📋        │    ⚙️        │
 │  Despensa   │  Diario      │  Perfil      │
 └─────────────┴──────────────┴──────────────┘
```

**Diario** es la pestaña nueva: un timeline vertical con las comidas del día (desayuno, almuerzo, comida, cena, snacks). Al tocar un día específico, ves qué alimentos registraste y sus macros totales.

### ✅ Pros
- Súper intuitivo, estándar de mobile
- Fácil de implementar con `BottomNavigationBar` + `IndexedStack`
- La despensa y el diario conviven sin conflicto

### ❌ Contras
- La despensa deja de ser "el centro" — ahora comparte atención
- Si solo hay 2 tabs se ve medio vacío; con 3 (perfil) se siente más completo

---

## 🔷 Opción 2: Menú lateral tipo "Konbini Ticket" ✅ ELEGIDA

Usar un **Drawer** lateral estilo recibo de konbini que se despliega desde la izquierda. El ícono de menú en el header abre este cajón.

```
 ╔══════════════════════════╗
 ║    ┌──────────────┐      ║
 ║    │   🐱 NekoFit  │      ║
 ║    │   konbini     │      ║
 ║    └──────────────┘      ║
 ║  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌  ║
 ║  SECCIONES               ║
 ║                          ║
 ║  📦  Despensa            ║
 ║  📋  Diario Alimentario  ║
 ║  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌  ║
 ║  CUENTA                  ║
 ║                          ║
 ║  👤  Mi Perfil           ║
 ║  🚪  Cerrar sesión      ║
 ║  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌  ║
 ║  Gracias por usar        ║
 ║  NekoFit ♥               ║
 ╚══════════════════════════╝
```

### ✅ Pros
- Sigue la estética "Konbini 3AM" que ya existe
- No ocupa espacio permanente en pantalla
- Se pueden agregar más secciones después (progreso, recetas, etc.)
- El drawer puede tener estilo recibo de konbini (monoespaciado, bordes duros)

### ❌ Contras
- Menos visible que bottom nav — la gente descubre menos las features
- El drawer actual solo tiene logout, hay que rediseñarlo completo

---

## 🔷 Opción 3: Swipeable tabs con "Día" como unidad (la más ambiciosa)

Rediseñar la home como un **tab switcher horizontal**:

```
 ┌─────────────────────────────┐
 │  ←  Hoy 13 │  Mañana 14 →  │
 ├─────────────────────────────┤
 │         (contenido)         │
 │   🥣 Desayuno    420 kcal   │
 │   🍚 Almuerzo    650 kcal   │
 │   🥗 Comida      380 kcal   │
 │   🍿 Snack       180 kcal   │
 │   🍽️ Cena        520 kcal   │
 │                             │
 │   Total:          2150 kcal │
 └─────────────────────────────┘
```

**Fase 1:** Un tab "Hoy" que muestra el timeline vertical del día, y para agregar comida usas los mismos flujos existentes (escanear/buscar) con la opción de "Agregar al diario de hoy".

**Fase 2:** Sliders de porciones, cámara de platos, swipe de fechas, integración con visión artificial.

### ✅ Pros
- Más integrado — diario y despensa son dos caras de la misma app
- Experiencia fluida: swipar entre días se siente natural
- Muestra progreso del día siempre visible

### ❌ Contras
- Requiere más refactor de la home actual
- Mayor complejidad técnica
- Puede abrumar si el usuario solo quiere gestionar la despensa

---

## Decisión

**Elegida: Opción 2** — Menú lateral tipo Konbini Ticket.

Razones:
1. Preserva la despensa como pantalla principal sin compartir atención
2. Refuerza la identidad visual "Konbini 3AM" que ya tiene la app
3. Bajo costo de implementación: reemplazar `PopupMenuButton` por `Drawer`
4. Escalable: se pueden agregar más secciones sin cambiar la navegación
5. El "riesgo estético" vale la pena: un drawer con estilo de recibo de konbini no se parece a ninguna otra app de nutrición
