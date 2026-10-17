#!/usr/bin/env bash
# Demo en vivo de la Parte 1. Uso: scripts/demo.sh [todo | suite [etiqueta] | contrato | reporte | def06 | reiniciar | app | parar]
set -euo pipefail
cd "$(dirname "$0")/.."

PUERTO="${QOLQE_PUERTO:-8000}"
URL="http://localhost:$PUERTO"
PUERTO_REPORTE=9323
PY=.venv/bin/python
mkdir -p reportes

app_arriba() { curl -sf "$URL/api/salud" > /dev/null; }

app() {
  if app_arriba; then echo "app ya corriendo en $URL"; return; fi
  QOLQE_MODO_PRUEBA=1 nohup "$PY" -m uvicorn qolqe.main:app --port "$PUERTO" > reportes/uvicorn.log 2>&1 < /dev/null &
  echo $! > reportes/uvicorn.pid
  for _ in $(seq 1 30); do app_arriba && break; sleep 1; done
  app_arriba || { echo "la app no levantó, ver reportes/uvicorn.log"; exit 1; }
  echo "app corriendo en $URL (swagger: $URL/docs)"
}

# las pruebas dejan el reloj fijado: primero se vuelve a la hora real
reiniciar() {
  curl -sf -X DELETE "$URL/api/pruebas/reloj" > /dev/null
  curl -sf -X POST "$URL/api/pruebas/reiniciar" > /dev/null && echo "datos semilla restaurados, reloj en hora real"
}

# cierra el show-report anterior para que no choque el puerto 9323
reporte() {
  for pid in $(lsof -ti "tcp:$PUERTO_REPORTE" -sTCP:LISTEN 2>/dev/null); do
    if ps -o command= -p "$pid" | grep -q "show-report"; then kill "$pid"; else
      echo "el puerto $PUERTO_REPORTE lo usa otro proceso ($pid), no lo toco"; exit 1
    fi
  done
  sleep 0.5
  nohup npx playwright show-report --port "$PUERTO_REPORTE" > reportes/show-report.log 2>&1 < /dev/null &
  echo "reporte en http://localhost:$PUERTO_REPORTE (se abre en el navegador)"
}

suite() {
  app
  npx playwright test --grep "${1:-@HU-G5-02}" || true
  reiniciar
  reporte
}

# los 100 escenarios, como pide la profe en la demo
todo() {
  app
  npm test || true
  reiniciar
  reporte
}

# schemathesis contra /openapi.json; abre su reporte html
contrato() {
  app
  PATH="$PWD/.venv/bin:$PATH" npm run contrato || true
  reiniciar
  local html
  html=$(ls -td reportes/schemathesis/html-*/ 2>/dev/null | head -1)
  [ -n "$html" ] && open "${html}index.html" && echo "reporte de schemathesis: ${html}index.html"
}

def06() {
  app
  reiniciar
  local token
  token=$(curl -sf -X POST "$URL/api/auth/login" -H 'Content-Type: application/json' \
    -d '{"celular":"987654321","pin":"4826"}' | "$PY" -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
  echo "login de Ana (987654321) ok"
  echo "POST /api/transferencias -> 934567812 (Fabián, cuenta cerrada), monto 10"
  curl -s -w '\nHTTP %{http_code} (lo esperado era 422 DESTINO_INACTIVO)\n' -X POST "$URL/api/transferencias" \
    -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
    -d '{"celular_destino":"934567812","monto":10}'
  reiniciar
}

parar() {
  for p in "$PUERTO" "$PUERTO_REPORTE"; do
    pids=$(lsof -ti "tcp:$p" -sTCP:LISTEN 2>/dev/null || true)
    [ -n "$pids" ] && kill $pids && echo "detenido lo que corría en :$p"
  done
  rm -f reportes/uvicorn.pid
}

case "${1:-suite}" in
  todo) todo ;;
  suite) suite "${2:-}" ;;
  contrato) contrato ;;
  reporte) reporte ;;
  def06) def06 ;;
  reiniciar) reiniciar ;;
  app) app ;;
  parar) parar ;;
  *) echo "uso: scripts/demo.sh [todo | suite [etiqueta] | contrato | reporte | def06 | reiniciar | app | parar]"; exit 1 ;;
esac
