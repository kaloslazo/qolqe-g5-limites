#!/usr/bin/env bash
# Prueba de contrato con Schemathesis contra la app levantada en $QOLQE_URL (por defecto http://localhost:8000).
# Usa un usuario de carga para no tocar a los usuarios de los escenarios y excluye el cierre de cuenta.
set -euo pipefail
URL="${QOLQE_URL:-http://localhost:8000}"
curl -sf -X POST "$URL/api/pruebas/reiniciar" > /dev/null
TOKEN=$(curl -sf -X POST "$URL/api/auth/login" -H 'Content-Type: application/json' \
  -d '{"celular":"900000001","pin":"2580"}' | python -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
mkdir -p reportes/schemathesis
st run "$URL/openapi.json" \
  -H "Authorization: Bearer $TOKEN" \
  --checks all --max-examples 20 \
  --include-path-regex '^/api/(limites|cuentas|transferencias|auth/login|usuarios)' \
  --exclude-path '/api/cuentas/me/cierre' \
  --report junit,html --report-dir reportes/schemathesis
