---
name: working-buffer
description: Protocolo de seguridad contra compactación de contexto. Activa un buffer de emergencia cuando la ventana está llena y permite recovery completo después de compactación.
triggers:
  - Cuando el usuario dice /danger-zone o /working-buffer
  - Cuando el agente detecta que fue compactado (mensaje empieza con <summary> o hay un bloque de resumen automático)
  - Cuando el usuario dice "dónde estábamos", "qué estábamos haciendo", "continúa", "me perdí"
  - Cuando el contexto supera el 60% de la ventana disponible
dependencies: WORKING_STATE.md, .product/memory/SESSION-STATE.md, .product/memory/working-buffer.md
---

## Cuándo activar este skill

### Señales de compactación:
- El mensaje de sistema empieza con `<summary>` o contiene un bloque de resumen automático
- El usuario pregunta "¿qué estábamos haciendo?" o "continúa"
- Hay un gap inexplicable en la conversación
- El agente no recuerda algo que claramente se discutió

### Señales de zona de peligro (pre-compactación):
- El contexto se siente "pesado" (respuestas lentas, muchos archivos cargados)
- El usuario menciona que hay mucho contexto
- La sesión lleva más de 2-3 horas activas

---

## MODO 1: Activar Buffer (zona de peligro, antes de compactación)

### Paso 1 — Limpiar y reiniciar buffer
Crear/sobrescribir `.product/memory/working-buffer.md` con encabezado vacío:

```markdown
# Working Buffer — Zona de Peligro
> Iniciado: [timestamp]
> Propósito: Capturar intercambios críticos antes de posible compactación
```

### Paso 2 — Registrar estado actual
Añadir al buffer el estado actual resumido:

```markdown
## Estado al activar buffer
- Tarea en curso: [descripción]
- Archivos modificados: [lista]
- Decisiones pendientes: [lista]
- Próximo paso: [acción concreta]
```

### Paso 3 — Modo captura
A partir de este momento, **después de cada respuesta**, añadir entrada al buffer:

```markdown
## [HH:MM] Usuario
[Resumen de 1 línea del mensaje del usuario]

## [HH:MM] Agente
[1-2 frases: qué se hizo + detalles clave (números, nombres, decisiones)]
```

**Regla crítica:** Si el mensaje del usuario tiene correcciones, nombres propios, o decisiones → capturar ANTES de responder.

---

## MODO 2: Recovery post-compactación

Ejecutar en este orden estricto:

### Paso 1 — Leer working-buffer.md
```
.product/memory/working-buffer.md
```
Este archivo tiene los intercambios más recientes antes de la compactación. Es la fuente más fresca.

### Paso 2 — Leer SESSION-STATE.md
```
.product/memory/SESSION-STATE.md
```
Contiene decisiones, correcciones y valores específicos del trabajo activo.

### Paso 3 — Leer WORKING_STATE.md
```
WORKING_STATE.md
```
Estado general: qué está en progreso, qué sigue, qué bloquea.

### Paso 4 — Leer daily log de hoy
```
.product/memory/[YYYY-MM-DD].md
```
Log crudo de la sesión actual si existe.

### Paso 5 — Reportar recovery
Presentar al usuario:

```
## Recovery post-compactación

**Fuente:** working-buffer.md + SESSION-STATE.md
**Última tarea:** [tarea exacta que se estaba haciendo]
**Último punto:** [dónde quedó exactamente]
**Decisiones activas:** [lista de decisiones en vigor]
**Archivos en juego:** [lista]

¿Continuamos desde aquí?
```

**NO preguntar "¿qué estábamos haciendo?"** — el buffer literalmente tiene la respuesta.

---

## SESSION-STATE.md — WAL Protocol (Write-Ahead Log)

Este archivo es la RAM activa del proyecto. Se actualiza ANTES de responder cuando el usuario dice algo con:

- ✏️ **Correcciones** — "No, es X no Y" / "Espera, quiero que..."
- 📍 **Nombres propios** — nombres de archivos, funciones, personas, servicios
- 🎨 **Preferencias** — "prefiero así", "no me gusta eso"
- 📋 **Decisiones** — "vamos con X", "descarta Y"
- 🔢 **Valores específicos** — números, rutas, URLs, IDs

### Formato de SESSION-STATE.md:
```markdown
# SESSION-STATE — Estado Activo

## Tarea actual
[descripción exacta]

## Decisiones de esta sesión
- [fecha HH:MM] Decisión: [descripción]

## Correcciones recibidas
- [fecha HH:MM] "[lo que dijo el usuario]" → [cómo cambia el comportamiento]

## Valores clave
- [nombre]: [valor]

## Última actualización
[timestamp]
```

---

## Reglas

1. **El buffer se limpia** al inicio de cada sesión nueva (cuando NO hay compactación)
2. **Solo en zona de peligro** — no activar si el contexto está holgado
3. **Recovery primero** — siempre leer buffer antes de preguntar al usuario
4. **SESSION-STATE es WAL** — escribir antes de responder, no después
