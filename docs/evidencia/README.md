# Evidencia de ejecución · Parte 1

Corrida del 17 de octubre de 2026 (hora de Lima) sobre el código de este repositorio.

| Entorno | Versión |
|---|---|
| Sistema | macOS |
| Python / FastAPI | 3.12 / 0.117.1 |
| Node.js | 24 |
| Playwright / playwright-bdd | 1.64.1 / 9.2.1 |
| Schemathesis | 4.31.1 |

Los reportes HTML se abren directo en el navegador (doble clic en `index.html`); no necesitan servidor.

```
docs/evidencia/
├── playwright/
│   ├── reporte-html/index.html     reporte HTML de los 108 escenarios
│   ├── junit-api.xml               el mismo resultado en JUnit
│   ├── salida-consola.txt          salida de npm test
│   └── log-servidor.txt            log de la app durante la corrida (incluye los 500 de DEF-09)
├── schemathesis/
│   ├── reporte-html/index.html     reporte HTML de Schemathesis
│   ├── junit.xml                   el mismo resultado en JUnit
│   └── salida-consola.txt          salida de npm run contrato
└── schemathesis-2026-10-16/        corrida anterior, usada al escribir el informe
    ├── junit.xml
    └── salida-consola.txt
```

## Pruebas de API: Playwright + playwright-bdd

Comando: `npm test`

| Resultado | Cantidad |
|---|---|
| Escenarios | 108 |
| Pasan (la app cumple la regla) | 97 |
| Fallan como se espera (`@fail`, detectan defectos) | 10 |
| Omitidos (`@rendimiento @skip`, Parte 3) | 1 |
| En pantalla | `107 passed, 1 skipped` en unos 22 s |

| Archivo | Escenarios | Defectos que detecta |
|---|---|---|
| `features/limites.feature` (G5) | 49 (8 técnicos) | DEF-01, DEF-02, DEF-03 |
| `features/nucleo_registro.feature` | 18 | DEF-05, DEF-09 |
| `features/nucleo_sesion.feature` | 10 | DEF-07, DEF-08 |
| `features/nucleo_cuenta.feature` | 11 | DEF-06 |
| `features/nucleo_transferencias.feature` | 20 | DEF-04, DEF-06 |

En el reporte HTML, los escenarios con la etiqueta `fail` son los que detectan un defecto: aparecen como *passed* porque fallan como se espera. Cada uno muestra sus pasos Given/When/Then y la respuesta de la API.

`log-servidor.txt` registra las solicitudes de toda la corrida. Ahí están los tres `500 Internal Server Error` del escenario de registros simultáneos (DEF-09), con su traza: `sqlite3.IntegrityError: UNIQUE constraint failed: usuarios.celular`.

## Contrato: Schemathesis

Comando: `npm run contrato` (`scripts/contrato.sh`: reinicia los datos y el reloj, entra con el usuario de carga 900000001 y excluye el cierre de cuenta).

| Resultado | Valor |
|---|---|
| Operaciones probadas | 13 de 69 (límites, cuentas, transferencias, login y registro) |
| Solicitudes generadas | 546, en unos 4.5 s |
| Hallazgos únicos | 14 |
| Respuestas 500 | 0 |
| Seed | `10079431427592384320946835635427730483` |

Schemathesis marca la corrida como *Failed* cuando encuentra diferencias entre el contrato OpenAPI y la app. Cada hallazgo se clasifica como defecto del código o como falta del contrato:

| Operación | Aviso | Respuesta | Lectura |
|---|---|---|---|
| `GET /api/transferencias/comision` | Rechazó una solicitud válida según el esquema | 422 `MONTO_INVALIDO` con monto 0 | Contrato: no declara que el monto sea mayor a 0 |
| `POST /api/transferencias` | Aceptó una solicitud inválida · rechazó una válida | 201 con `cci: "AAA"` en una transferencia Qolqe · 422 con monto 0 | Código, baja: ignora un `cci` de tipo incorrecto · contrato: mínimo del monto |
| `PUT /api/limites` | Rechazó una solicitud válida | 422 `SOLICITUD_INVALIDA` con un texto que no es decimal | Contrato: acepta texto sin declarar el formato decimal |
| `POST /api/limites/alertas` | Rechazó una solicitud válida | 422 `ALERTA_INVALIDA` con un umbral fuera de rango | Contrato: no declara el rango de S/ 10 a S/ 2,000 |
| `PUT /api/limites/alertas/{alerta_id}` | Rechazó una solicitud válida | 422 `SOLICITUD_INVALIDA` | Contrato: no declara el formato decimal del umbral |
| `DELETE /api/limites/alertas/{alerta_id}` (fase stateful) | Rechazó una solicitud válida | 422 con un identificador enorme | Contrato: el identificador no tiene máximo declarado |
| `POST /api/usuarios` | Rechazó una solicitud válida · aviso de esquema | 422 `PIN_INVALIDO` con PIN `0000` | Contrato: RN-03 no está en el esquema |
| `POST /api/auth/login` | Aceptó una solicitud inválida · rechazó una válida | 423 `CUENTA_BLOQUEADA` | Código, baja: no valida el patrón del PIN antes de contar el intento. El bloqueo lo provoca el mismo fuzzing |
| `OPTIONS` en 4 rutas | Cabecera `Allow` inválida | 405 sin `Allow` | Código, baja |

Recomendación: declarar en el OpenAPI `exclusiveMinimum`, `maximum`, `multipleOf` y los formatos decimales que la app ya aplica.

Para repetir exactamente la misma generación, se agrega `--seed <seed>` al comando `st run` de `scripts/contrato.sh`. Cada hallazgo de `salida-consola.txt` trae además su `curl` para reproducirlo.

## Integración continua

Cada push corre `npm test` y `npm run contrato` en GitHub Actions y sube los reportes como el artefacto `reportes`:
https://github.com/kaloslazo/qolqe-g5-limites/actions
