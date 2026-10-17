# Informe del proyecto – Grupo 5 · Límites

## 1. Datos generales y alcance

| Campo | Valor |
|---|---|
| Integrantes | Kalos · Gianpier |
| Módulo | G5 · Límites y alertas de consumo |
| Herramienta de API | Playwright (API testing) + playwright-bdd |
| Herramienta web | Playwright (Parte 2) |
| Herramienta de rendimiento | (Parte 3) |

**Alcance y nivel de prueba**

| HU | Prioridad | Nivel | Justificación |
|---|---|---|---|
| HU-N-01 a HU-N-09 (núcleo) | Alta / Media | API | Reglas de dinero, credenciales y sesión: observables en la API; la concurrencia de HU-N-07 CA5 va a rendimiento |
| HU-G5-01 Ver mis límites | Media | API | El cálculo de usado/disponible se verifica en el JSON |
| HU-G5-02 Cambiar límite diario | Alta | API | Rango, múltiplos y vigencia a 24 h; requiere controlar el reloj (`/api/pruebas/reloj`) |
| HU-G5-03 Respetar el límite al transferir | Alta | API (+ rendimiento para CA2) | Afecta dinero; la concurrencia se prueba en la Parte 3 |
| HU-G5-04 Crear alerta | Media | API | Particiones y valores límite del umbral |
| HU-G5-05 Ver alertas | Baja | API (+ web en Parte 2) | Gasto de hoy por tipo, verificable en JSON |
| HU-G5-06 Editar/pausar/reanudar | Media | API (+ web) | Regla de reanudación frente al límite |
| HU-G5-07 Eliminar alerta | Baja | API (+ web) | Una alerta eliminada deja de notificar |
| HU-G5-08 Notificación de alerta | Alta | API | Actor Sistema; se observa en `/api/pruebas/notificaciones` |

Criterios: prioridad (riesgo), si la regla es observable en la API sin UI y si requiere control del reloj o de los datos.

**Cobertura de Gherkin:** 5 archivos `.feature` (`limites`, `nucleo_registro`, `nucleo_sesion`, `nucleo_cuenta`, `nucleo_transferencias`), con todas las HU del núcleo y del módulo. Cada escenario lleva la etiqueta de su HU y su nivel (`@HU-G5-02 @api`).

**Casos funcionales y técnicos:** los funcionales verifican las reglas de negocio (R-G5-01 a R-G5-05, RN-01 a RN-09) con particiones y valores límite. Los técnicos (`@tecnico`) verifican la interfaz del módulo G5: autenticación (sin token o con un token inválido → 401 `NO_AUTENTICADO`), cuerpo vacío o con un tipo inválido (422 `SOLICITUD_INVALIDA` que indica el campo), ausencia de efecto tras un rechazo (el límite vigente no cambia) y propiedad de los datos (la alerta de otro usuario responde 404 `ALERTA_NO_ENCONTRADA` y no se modifica).

## 2. Pruebas de API

**Herramienta:** Playwright Test (cliente `request` / `APIRequestContext`) + playwright-bdd. Los escenarios de `features/*.feature` se enlazan con pasos en TypeScript (`tests/api-playwright/pasos.ts`, `pasos_nucleo.ts`); `bddgen` los convierte en specs de Playwright.

**Enfoque:** BDD. El `.feature` es el caso de prueba legible por negocio; cada paso es una función que llama a la API. La API de soporte (`/api/pruebas/*`) reinicia la semilla antes de cada escenario, fija el reloj y expone los SMS.

**Instalación y ejecución**
```bash
python -m venv .venv && source .venv/bin/activate && pip install -r requirements-pruebas.txt
npm install
npm test                                   # bddgen + playwright test (levanta uvicorn solo)
npx playwright test --grep @HU-G5-02       # solo una HU
npx playwright test --grep @DEF            # solo los escenarios que detectan defectos
npm run report                             # reporte HTML
```

**Defectos conocidos:** los escenarios con `@DEF-xx @fail` usan `test.fail()`: pasan mientras el defecto exista y se ponen en rojo cuando lo corrijan (aviso para retirar la etiqueta).

**Ventajas:** API y web con el mismo runner; levanta la app con `webServer`; trazas y reporte HTML y JUnit; TypeScript con autocompletado.
**Limitaciones:** los escenarios comparten BD y reloj, así que corren en serie (`workers: 1`); playwright-bdd agrega un paso de generación (`bddgen`); no valida contratos OpenAPI (para eso Schemathesis); requiere Node además de Python.
**Capacidades de IA:** test agents Planner, Generator y Healer (`npx playwright init-agents`, desde v1.56); servidor MCP `@playwright/mcp`; depurador y análisis de trazas por CLI (v1.59). Riesgo: el Healer puede "arreglar" una aserción que en realidad detecta un defecto; el oráculo sigue siendo el requisito.

**Resultados:** 108 escenarios (8 técnicos): 97 pasan, 10 fallan como se espera porque detectan 9 defectos (DEF-06 tiene dos escenarios) y 1 queda para la Parte 3 (`@rendimiento @skip`).

**Contrato (Schemathesis 4.31)** — `npm run contrato` (`scripts/contrato.sh`): reinicia la semilla, usa el usuario de carga 900000001 y excluye el cierre de cuenta para no romper el token.

| Hallazgo de Schemathesis | Lectura |
|---|---|
| 500 en `POST /api/usuarios` (fase stateful) | Defecto real → **DEF-09** |
| "API rejected schema-compliant request" (8–10) | Reglas de negocio que el esquema no declara (múltiplos de 50, saldo, duplicados). Recomendación: documentar `multipleOf`, mínimos y máximos en el OpenAPI |
| "API accepted schema-violating request" (2) | `cci` con tipo incorrecto se ignora en transferencias QOLQE; `pin` fuera de patrón se procesa en login. Baja severidad |
| "Invalid Allow header" (4) | Respuestas 405 a `OPTIONS` sin cabecera `Allow`. Baja severidad |

Evidencia: `docs/evidencia/schemathesis-junit.xml` y `docs/evidencia/schemathesis-salida.txt` (cada corrida nueva queda en `reportes/`).

## 5. Defectos encontrados

| ID | Título | Regla | Severidad | Estado |
|---|---|---|---|---|
| DEF-02 | Las transferencias interbancarias no cuentan para el límite diario | RN-06 · HU-G5-03 | Crítica | Abierto |
| DEF-04 | Una transferencia interbancaria deja el saldo en negativo | RN-08 | Crítica | Abierto |
| DEF-06 | Se puede transferir a una cuenta cerrada | RN-07 | Crítica | Abierto |
| DEF-01 | Una reducción del límite no cancela el aumento pendiente | R-G5-02 | Alta | Abierto |
| DEF-07 | Cerrar sesión no invalida el token | HU-N-03 | Alta | Abierto |
| DEF-03 | Una alerta notifica más de una vez por día | HU-G5-08 | Media | Abierto |
| DEF-05 | El registro acepta un PIN en secuencia descendente | RN-03 | Media | Abierto |
| DEF-08 | Un ingreso exitoso no reinicia el conteo de intentos | RN-04 | Media | Abierto |
| DEF-09 | Registros simultáneos con el mismo celular responden 500 | HU-N-01 | Media | Abierto |

Detalle, pasos y evidencia en `docs/defectos.md`. Cada defecto tiene un escenario etiquetado `@DEF-xx` que lo detecta.
