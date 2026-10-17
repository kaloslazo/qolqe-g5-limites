/**
 * Pasos Given / When / Then que enlazan los .feature con la API de Qolqe.
 * Expresiones de Cucumber: {word} = un token sin espacios, {string} = texto entre comillas, {int} = entero.
 * La barra de "S/" se escapa ("S\\/") porque en Cucumber "/" significa alternativa.
 */
import { expect } from '@playwright/test';
import { CCI, Given, Then, When, cuerpo as leer } from './fixtures';

// ------------------------------------------------------------------------------------- Given
Given('que los datos de prueba están restaurados', async ({ request }) => {
  expect((await request.post('/api/pruebas/reiniciar')).ok()).toBeTruthy();
});

Given('que la fecha de la app es {string}', async ({ request }, fecha: string) => {
  expect((await request.put('/api/pruebas/reloj', { data: { ahora: fecha } })).ok()).toBeTruthy();
});

Given('que inicié sesión como {word}', async ({ sesion }, nombre: string) => {
  await sesion.login(nombre);
});

Given('que ya transferí S\\/ {word} hoy al celular {word}', async ({ sesion }, monto: string, celular: string) => {
  const r = await sesion.api('post', '/api/transferencias', { celular_destino: celular, monto });
  expect(r.status(), await r.text()).toBe(201);
});

Given('que ya transferí S\\/ {word} hoy a otro banco', async ({ sesion }, monto: string) => {
  const r = await sesion.api('post', '/api/transferencias', { tipo: 'INTERBANCARIA', cci: CCI, monto });
  expect(r.status(), await r.text()).toBe(201);
});

Given('que solicité aumentar mi límite diario a S\\/ {word}', async ({ sesion }, limite: string) => {
  const r = await sesion.api('put', '/api/limites', { limite_diario: limite });
  expect((await r.json()).aplicacion).toBe('PROGRAMADA');
});

Given('que mi límite diario es S\\/ {word}', async ({ sesion }, limite: string) => {
  expect((await sesion.api('put', '/api/limites', { limite_diario: limite })).ok()).toBeTruthy();
});

Given('que tengo {int} alertas', async ({ sesion }, n: number) => {
  const actuales = (await (await sesion.api('get', '/api/limites/alertas')).json()).length;
  for (let i = 0; i < n - actuales; i++) {
    const r = await sesion.api('post', '/api/limites/alertas', { tipo: 'RECARGAS', umbral: 10 * (i + 1) });
    expect(r.status(), await r.text()).toBe(201);
  }
});

Given('que pausé la alerta de {word} con umbral S\\/ {word}', async ({ sesion }, tipo: string, umbral: string) => {
  const a = await sesion.alerta(tipo, umbral);
  expect((await sesion.api('put', `/api/limites/alertas/${a.id}`, { estado: 'PAUSADA' })).ok()).toBeTruthy();
});

// ------------------------------------------------------------------------------------- When
When('consulto mis límites', async ({ sesion }) => {
  sesion.respuesta = await sesion.api('get', '/api/limites');
});

When('cambio mi límite diario a S\\/ {word}', async ({ sesion }, limite: string) => {
  sesion.respuesta = await sesion.api('put', '/api/limites', { limite_diario: limite });
});

When('pasan {int} minutos', async ({ request }, minutos: number) => {
  expect((await request.put('/api/pruebas/reloj', { data: { avanzar_minutos: minutos } })).ok()).toBeTruthy();
});

When('transfiero S\\/ {word} al celular {word}', async ({ sesion }, monto: string, celular: string) => {
  sesion.respuesta = await sesion.api('post', '/api/transferencias', { celular_destino: celular, monto });
});

When('transfiero S\\/ {word} a otro banco', async ({ sesion }, monto: string) => {
  sesion.respuesta = await sesion.api('post', '/api/transferencias', { tipo: 'INTERBANCARIA', cci: CCI, monto });
});

When('creo una alerta de {word} con umbral S\\/ {word}', async ({ sesion }, tipo: string, umbral: string) => {
  sesion.respuesta = await sesion.api('post', '/api/limites/alertas', { tipo, umbral });
});

When('reanudo la alerta de {word} con umbral S\\/ {word}', async ({ sesion }, tipo: string, umbral: string) => {
  const a = await sesion.alerta(tipo, umbral);
  sesion.respuesta = await sesion.api('put', `/api/limites/alertas/${a.id}`, { estado: 'ACTIVA' });
});

// ------------------------------------------------------------------------------------- Then
Then('el resultado es {string}', async ({ sesion }, resultado: string) => {
  const r = sesion.respuesta!;
  const cuerpo = await leer(r);
  const detalle = `${r.status()} ${JSON.stringify(cuerpo)}`;
  if (resultado === 'exitosa') {
    expect(r.ok(), detalle).toBeTruthy();
  } else if (resultado === 'INMEDIATA' || resultado === 'PROGRAMADA') {
    expect(r.status(), detalle).toBe(200);
    expect(cuerpo.aplicacion, detalle).toBe(resultado);
  } else if (resultado === 'ACTIVA' || resultado === 'PAUSADA') {
    expect(r.ok(), detalle).toBeTruthy();
    expect(cuerpo.estado, detalle).toBe(resultado);
  } else {
    // código de error de negocio
    expect(r.status(), detalle).toBeGreaterThanOrEqual(400);
    expect(cuerpo.codigo, detalle).toBe(resultado);
  }
});

Then('el límite por operación es S\\/ {word}', async ({ sesion }, monto: string) => {
  expect((await sesion.limites()).limite_por_operacion).toBe(monto);
});

Then('mi límite diario vigente es S\\/ {word}', async ({ sesion }, monto: string) => {
  expect((await sesion.limites()).limite_diario).toBe(monto);
});

Then('lo usado hoy es S\\/ {word}', async ({ sesion }, monto: string) => {
  expect((await sesion.limites()).usado_hoy).toBe(monto);
});

Then('lo disponible hoy es S\\/ {word}', async ({ sesion }, monto: string) => {
  expect((await sesion.limites()).disponible_hoy).toBe(monto);
});

Then('tengo un aumento pendiente de S\\/ {word}', async ({ sesion }, monto: string) => {
  expect((await sesion.limites()).limite_pendiente).toBe(monto);
});

Then('no tengo un aumento pendiente', async ({ sesion }) => {
  expect((await sesion.limites()).limite_pendiente).toBeNull();
});

Then('recibo un SMS que contiene {string}', async ({ sesion }, texto: string) => {
  const sms = await sesion.sms();
  expect(sms.some((s) => s.includes(texto)), sms.join('\n')).toBeTruthy();
});

Then('recibo {int} SMS de alerta de consumo', async ({ sesion }, n: number) => {
  const sms = await sesion.sms();
  expect(sms.filter((s) => s.includes('Alerta Qolqe'))).toHaveLength(n);
});

Then('la alerta de {word} con umbral S\\/ {word} está {word}', async ({ sesion }, tipo: string, umbral: string, estado: string) => {
  expect((await sesion.alerta(tipo, umbral)).estado).toBe(estado);
});

Then('mi saldo es S\\/ {word}', async ({ sesion }, saldo: string) => {
  expect((await (await sesion.api('get', '/api/cuentas/me/saldo')).json()).saldo).toBe(saldo);
});
