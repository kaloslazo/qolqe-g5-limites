# Reporte de defectos – Grupo 5 · Límites

## DEF-01: Una reducción del límite diario no cancela el aumento pendiente

| Campo | Valor |
|---|---|
| Módulo / regla | G5 · HU-G5-02 · R-G5-02 |
| Severidad | Alta |
| Prioridad | Alta |
| Entorno | Qolqe Wallet (cjudihtroj/qolqe-wallet), Playwright 1.64, API REST |
| Prueba que lo detecta | `features/limites.feature` → escenario "Una reducción cancela el aumento pendiente" (`@DEF-01`) |

**Pasos para reproducir**
1. `POST /api/pruebas/reiniciar` y `PUT /api/pruebas/reloj` con `{"ahora": "2026-11-10T10:00:00"}`.
2. Iniciar sesión como Diego (998877665 / 3604; límite S/ 1,000).
3. `PUT /api/limites` con `{"limite_diario": 1500}` → `aplicacion: PROGRAMADA`.
4. `PUT /api/limites` con `{"limite_diario": 500}`.
5. `PUT /api/pruebas/reloj` con `{"avanzar_minutos": 1500}` y luego `GET /api/limites`.

**Resultado esperado:** tras el paso 4, `limite_pendiente` es `null`; tras el paso 5, el límite vigente sigue en S/ 500.00.

**Resultado obtenido:** tras el paso 4 la respuesta conserva `limite_pendiente: "1500.00"`; tras el paso 5 el límite vigente sube a S/ 1,500.00.

**Evidencia:**
```json
{"limite_diario": "500.00", "limite_pendiente": "1500.00", "pendiente_desde": "2026-11-11T10:00:00", "aplicacion": "INMEDIATA"}
```

## DEF-02: Las transferencias interbancarias no cuentan para el límite diario

| Campo | Valor |
|---|---|
| Módulo / regla | Núcleo / G5 · RN-06 · HU-G5-03 CA1 · HU-G5-01 CA1 |
| Severidad | Crítica |
| Prioridad | Alta |
| Entorno | Qolqe Wallet, API REST |
| Prueba que lo detecta | `features/limites.feature` → escenario "Las transferencias interbancarias también cuentan para el límite diario" (`@DEF-02`) |

**Pasos para reproducir**
1. Reiniciar datos y fijar el reloj.
2. Iniciar sesión como Diego (límite S/ 1,000).
3. Tres veces `POST /api/transferencias` con `{"tipo": "INTERBANCARIA", "cci": "00219300123456789012", "monto": 500}`.
4. `GET /api/limites`.

**Resultado esperado:** la tercera transferencia responde 422 `LIMITE_DIARIO_EXCEDIDO`; `usado_hoy` refleja lo transferido.

**Resultado obtenido:** las tres responden 201 (S/ 1,500 en el día con límite de S/ 1,000) y `usado_hoy` es `"0.00"`.

**Evidencia:** 201 ×3 y `{"usado_hoy": "0.00", "disponible_hoy": "1000.00"}`.

## DEF-03: Una alerta de consumo notifica más de una vez por día

| Campo | Valor |
|---|---|
| Módulo / regla | G5 · HU-G5-08 CA2 |
| Severidad | Media |
| Prioridad | Media |
| Entorno | Qolqe Wallet, API REST |
| Prueba que lo detecta | `features/limites.feature` → escenario "Cada alerta notifica como máximo una vez por día" (`@DEF-03`) |

**Pasos para reproducir**
1. Reiniciar datos y fijar el reloj.
2. Iniciar sesión como Ana (tiene una alerta TRANSFERENCIAS con umbral S/ 300).
3. Transferir S/ 300.00 y luego S/ 10.00 al 912345678.
4. `GET /api/pruebas/notificaciones?celular=987654321`.

**Resultado esperado:** 1 SMS "Alerta Qolqe".

**Resultado obtenido:** un SMS de alerta por cada transferencia que sigue sobre el umbral (2 en este caso; 3 con una tercera).

**Evidencia:** lista de notificaciones con SMS de alerta repetidos el mismo día.

## DEF-04: Una transferencia interbancaria deja el saldo en negativo

| Campo | Valor |
|---|---|
| Módulo / regla | Núcleo · RN-08 · HU-N-08 CA2 |
| Severidad | Crítica |
| Prioridad | Alta |
| Entorno | Qolqe Wallet, API REST |
| Prueba que lo detecta | `features/nucleo_transferencias.feature` → escenario "El saldo debe cubrir el monto más la comisión interbancaria" (`@DEF-04`) |

**Pasos para reproducir**
1. Reiniciar datos y fijar el reloj.
2. Iniciar sesión como Carla (956781234 / 5917; saldo S/ 50.00).
3. `POST /api/transferencias` con `{"tipo": "INTERBANCARIA", "cci": "00219300123456789012", "monto": 50}`.

**Resultado esperado:** 422 `SALDO_INSUFICIENTE` (50.00 + comisión 1.00 = 51.00 > 50.00).

**Resultado obtenido:** 201 con `"saldo": "-1.00"`.

**Evidencia:**
```json
{"tipo": "INTERBANCARIA", "monto": "50.00", "comision": "1.00", "total": "51.00", "saldo": "-1.00"}
```

## DEF-05: El registro acepta un PIN en secuencia descendente

| Campo | Valor |
|---|---|
| Módulo / regla | Núcleo · RN-03 · HU-N-01 CA4 |
| Severidad | Media |
| Prioridad | Media |
| Entorno | Qolqe Wallet, Playwright 1.64, API REST |
| Prueba que lo detecta | `features/nucleo_registro.feature` → "Un PIN en secuencia descendente se rechaza (RN-03)" (`@DEF-05`) |

**Pasos para reproducir**
1. `POST /api/pruebas/reiniciar`.
2. `POST /api/usuarios` con `{"dni": "45678912", "nombres": "Lucía Fernández Rojas", "celular": "987000111", "pin": "4321"}`.

**Resultado esperado:** 422 `PIN_INVALIDO` (RN-03 prohíbe secuencias ascendentes **y descendentes**).

**Resultado obtenido:** 201: la cuenta se crea con PIN `4321`. `1234` sí se rechaza.

**Evidencia:** respuesta 201 con el usuario creado. La regla solo compara contra la cadena `0123456789`.

## DEF-06: Se puede transferir a una cuenta cerrada

| Campo | Valor |
|---|---|
| Módulo / regla | Núcleo · RN-07 · HU-N-07 CA2 · HU-N-06 CA4 |
| Severidad | Crítica |
| Prioridad | Alta |
| Entorno | Qolqe Wallet, Playwright 1.64, API REST |
| Prueba que lo detecta | `features/nucleo_transferencias.feature` → "Destinos no permitidos (RN-07)", Examples «Cuenta cerrada» y `features/nucleo_cuenta.feature` → "Tras cerrar la cuenta nadie puede transferirme" (`@DEF-06`) |

**Pasos para reproducir**
1. Reiniciar datos.
2. Iniciar sesión como Ana (987654321 / 4826).
3. `POST /api/transferencias` con `{"celular_destino": "934567812", "monto": 10}` (Fabián, cuenta **cerrada** en la semilla).

**Resultado esperado:** 422 `DESTINO_INACTIVO`; el saldo de Ana no cambia.

**Resultado obtenido:** 201; Ana queda con S/ 1,490.00 y el dinero se acredita a una cuenta cerrada.

**Evidencia:**
```json
{"codigo_operacion": "TRF26111010000000001", "tipo": "QOLQE", "monto": "10.00", "destinatario": {"nombre": "Fabián R.", "celular": "934567812"}, "saldo": "1490.00"}
```

## DEF-07: Cerrar sesión no invalida el token

| Campo | Valor |
|---|---|
| Módulo / regla | Núcleo · HU-N-03 CA1 |
| Severidad | Alta |
| Prioridad | Alta |
| Entorno | Qolqe Wallet, Playwright 1.64, API REST |
| Prueba que lo detecta | `features/nucleo_sesion.feature` → "Al cerrar sesión el token deja de ser válido" (`@DEF-07`) |

**Pasos para reproducir**
1. Iniciar sesión como Ana y guardar el `access_token`.
2. `POST /api/auth/logout` con ese token → 204.
3. `GET /api/cuentas/me` con el mismo token.

**Resultado esperado:** 401 `NO_AUTENTICADO`.

**Resultado obtenido:** 200 con el perfil de Ana: el token sigue vivo hasta que vence a los 30 minutos.

**Evidencia:** 204 en el logout y 200 en la consulta posterior con el mismo `Authorization`.

## DEF-08: Un ingreso exitoso no reinicia el conteo de intentos fallidos

| Campo | Valor |
|---|---|
| Módulo / regla | Núcleo · RN-04 · HU-N-02 CA3 |
| Severidad | Media |
| Prioridad | Media |
| Entorno | Qolqe Wallet, Playwright 1.64, API REST |
| Prueba que lo detecta | `features/nucleo_sesion.feature` → "Un ingreso exitoso reinicia el conteo de intentos" (`@DEF-08`) |

**Pasos para reproducir**
1. Reiniciar datos.
2. Dos `POST /api/auth/login` de Bruno (912345678) con PIN `0000` → 401, 401.
3. Un `POST /api/auth/login` de Bruno con su PIN `7391` → 200.
4. Un `POST /api/auth/login` de Bruno con PIN `0000`.

**Resultado esperado:** 401 `CREDENCIALES_INVALIDAS` (el conteo volvió a 0 en el paso 3).

**Resultado obtenido:** 423 `CUENTA_BLOQUEADA`: el fallo del paso 4 se suma a los dos anteriores.

**Evidencia:** `{"codigo": "CUENTA_BLOQUEADA", "detail": "Superaste los intentos permitidos. Tu cuenta está bloqueada hasta las 10:15."}`

## DEF-09: Registros simultáneos con el mismo celular responden 500

| Campo | Valor |
|---|---|
| Módulo / regla | Núcleo · HU-N-01 CA3 · convención de errores |
| Severidad | Media |
| Prioridad | Media |
| Entorno | Qolqe Wallet, Playwright 1.64, Schemathesis 4.31, API REST |
| Prueba que lo detecta | `features/nucleo_registro.feature` → "Dos registros simultáneos…" (`@DEF-09`); hallado primero por Schemathesis (fase stateful) |

**Pasos para reproducir**
1. Reiniciar datos.
2. Enviar a la vez 4 `POST /api/usuarios` con `{"dni": "45678912", "nombres": "Lucía Fernández", "celular": "987000111", "pin": "4826"}`.

**Resultado esperado:** uno 201 y los demás 409 `CELULAR_REGISTRADO`.

**Resultado obtenido:** uno 201 y los demás **500 Internal Server Error** sin `codigo` (5 de 5 intentos).

**Evidencia:** log del servidor: `sqlite3.IntegrityError: UNIQUE constraint failed: usuarios.celular` (tres veces en `docs/evidencia/playwright/log-servidor.txt`, durante el escenario `@DEF-09`).
