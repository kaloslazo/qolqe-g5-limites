/** Pasos del núcleo común (registro, sesión, cuenta, transferencias) y pasos extra de G5. */
import { expect } from '@playwright/test';
import { Given, Then, When, cuerpo } from './fixtures';

const PIN_ERRADO = '0000';

// ------------------------------------------------------------------------------------- registro
When(
  'me registro con DNI {string}, celular {string} y PIN {string}',
  async ({ sesion }, dni: string, celular: string, pin: string) => {
    sesion.respuesta = await sesion.cruda('post', '/api/usuarios', undefined, {
      dni, celular, pin, nombres: 'Lucía Fernández Rojas',
    });
  },
);

When(
  'me registro con DNI {string}, celular {string}, PIN {string} y correo {string}',
  async ({ sesion }, dni: string, celular: string, pin: string, correo: string) => {
    sesion.respuesta = await sesion.cruda('post', '/api/usuarios', undefined, {
      dni, celular, pin, correo, nombres: 'Lucía Fernández Rojas',
    });
  },
);

Then('la respuesta tiene el código HTTP {int}', async ({ sesion }, codigo: number) => {
  expect(sesion.respuesta!.status(), await sesion.respuesta!.text()).toBe(codigo);
});

Then('el celular {word} recibe un SMS que contiene {string}', async ({ request }, celular: string, texto: string) => {
  const sms = ((await (await request.get('/api/pruebas/notificaciones', { params: { celular } })).json()) as unknown[])
    .map((n) => JSON.stringify(n));
  expect(sms.some((s) => s.includes(texto)), sms.join('\n')).toBeTruthy();
});

Then(
  'al iniciar sesión con el celular {word} y el PIN {word} mi saldo es S\\/ {word}',
  async ({ sesion }, celular: string, pin: string, saldo: string) => {
    await sesion.loginCon(celular, pin);
    expect((await (await sesion.api('get', '/api/cuentas/me/saldo')).json()).saldo).toBe(saldo);
  },
);

// ------------------------------------------------------------------------------------- sesión
When('inicio sesión con el celular {word} y el PIN {word}', async ({ sesion }, celular: string, pin: string) => {
  sesion.respuesta = await sesion.cruda('post', '/api/auth/login', undefined, { celular, pin });
  if (sesion.respuesta.ok()) {
    sesion.cred = { celular, pin };
    sesion.token = (await sesion.respuesta.json()).access_token;
  }
});

Then('recibo un token válido por {int} minutos', async ({ sesion }, minutos: number) => {
  const r = sesion.respuesta!;
  expect(r.status(), await r.text()).toBe(200);
  const datos = await r.json();
  expect(datos.access_token).toBeTruthy();
  expect(datos.expires_in).toBe(minutos * 60);
});

Given('que ya fallé {int} veces el PIN del celular {word}', async ({ sesion }, veces: number, celular: string) => {
  for (let i = 0; i < veces; i++) {
    const r = await sesion.cruda('post', '/api/auth/login', undefined, { celular, pin: PIN_ERRADO });
    expect(r.status()).toBe(401);
  }
});

Given('que la cuenta del celular {word} quedó bloqueada', async ({ sesion }, celular: string) => {
  let ultima = 0;
  for (let i = 0; i < 3; i++) {
    ultima = (await sesion.cruda('post', '/api/auth/login', undefined, { celular, pin: PIN_ERRADO })).status();
  }
  expect(ultima).toBe(423);
});

When('cierro sesión', async ({ sesion }) => {
  sesion.tokens = [sesion.token!];
  expect((await sesion.cruda('post', '/api/auth/logout', sesion.token)).status()).toBe(204);
});

Then('mi token anterior responde {int}', async ({ sesion }, codigo: number) => {
  expect((await sesion.cruda('get', '/api/cuentas/me', sesion.tokens[0])).status()).toBe(codigo);
});

Given('que inicié sesión como {word} en dos equipos', async ({ sesion }, nombre: string) => {
  await sesion.login(nombre);
  const primero = sesion.token!;
  await sesion.login(nombre);
  sesion.tokens = [primero, sesion.token!];
});

When('cierro sesión en el primer equipo', async ({ sesion }) => {
  expect((await sesion.cruda('post', '/api/auth/logout', sesion.tokens[0])).status()).toBe(204);
});

Then('el segundo equipo sigue consultando mi saldo', async ({ sesion }) => {
  expect((await sesion.cruda('get', '/api/cuentas/me/saldo', sesion.tokens[1])).status()).toBe(200);
});

// ------------------------------------------------------------------------------------- cuenta
When('consulto mi saldo', async ({ sesion }) => {
  sesion.respuesta = await sesion.api('get', '/api/cuentas/me/saldo');
});

Then('la moneda es {string}', async ({ sesion }, moneda: string) => {
  expect((await sesion.respuesta!.json()).moneda).toBe(moneda);
});

When('consulto mi perfil', async ({ sesion }) => {
  sesion.respuesta = await sesion.api('get', '/api/cuentas/me');
});

Then('el DNI se muestra con solo los últimos 4 dígitos', async ({ sesion }) => {
  expect((await sesion.respuesta!.json()).dni).toMatch(/^\*{4}\d{4}$/);
});

When('consulto el saldo sin token', async ({ sesion }) => {
  sesion.respuesta = await sesion.cruda('get', '/api/cuentas/me/saldo');
});

When('cambio mi correo a {string}', async ({ sesion }, correo: string) => {
  sesion.respuesta = await sesion.api('put', '/api/cuentas/me', { correo });
});

When('intento cambiar mi celular a {string}', async ({ sesion }, celular: string) => {
  sesion.respuesta = await sesion.api('put', '/api/cuentas/me', { celular });
});

Then('mi perfil sigue con el celular {word}', async ({ sesion }, celular: string) => {
  expect((await (await sesion.api('get', '/api/cuentas/me')).json()).celular).toBe(celular);
});

Given('que mi saldo es S\\/ {word}', async ({ sesion }, saldo: string) => {
  const r = await sesion.request.put('/api/pruebas/saldo', { data: { celular: sesion.celular, saldo } });
  expect(r.ok(), await r.text()).toBeTruthy();
});

When('cierro mi cuenta con el PIN {word}', async ({ sesion }, pin: string) => {
  sesion.respuesta = await sesion.api('post', '/api/cuentas/me/cierre', { pin });
});

Given('que cerré mi cuenta con el PIN {word}', async ({ sesion }, pin: string) => {
  const r = await sesion.api('post', '/api/cuentas/me/cierre', { pin });
  expect(r.status(), await r.text()).toBe(204);
});

// ------------------------------------------------------------------------------------- transferencias
Then('la transferencia tiene un código de operación', async ({ sesion }) => {
  expect((await cuerpo(sesion.respuesta!)).codigo_operacion).toBeTruthy();
});

When('transfiero S\\/ {word} al CCI {word}', async ({ sesion }, monto: string, cci: string) => {
  sesion.respuesta = await sesion.api('post', '/api/transferencias', { tipo: 'INTERBANCARIA', cci, monto });
});

When('simulo la comisión de S\\/ {word} a otro banco', async ({ sesion }, monto: string) => {
  sesion.respuesta = await sesion.api('get', `/api/transferencias/comision?monto=${monto}&tipo=INTERBANCARIA`);
});

Then('la comisión es S\\/ {word} y el total S\\/ {word}', async ({ sesion }, comision: string, total: string) => {
  const datos = await sesion.respuesta!.json();
  expect(datos.comision).toBe(comision);
  expect(datos.total).toBe(total);
});

When(
  'envío {int} transferencias simultáneas de S\\/ {word} al celular {word}',
  async ({ sesion }, n: number, monto: string, celular: string) => {
    await Promise.all(
      Array.from({ length: n }, () => sesion.api('post', '/api/transferencias', { celular_destino: celular, monto })),
    );
  },
);

Then('lo usado hoy no supera S\\/ {word}', async ({ sesion }, tope: string) => {
  expect(Number((await sesion.limites()).usado_hoy)).toBeLessThanOrEqual(Number(tope));
});

// ------------------------------------------------------------------------------------- G5 extra
When('consulto mis alertas', async ({ sesion }) => {
  sesion.respuesta = await sesion.api('get', '/api/limites/alertas');
});

Then(
  'la alerta de {word} con umbral S\\/ {word} tiene un gasto de hoy de S\\/ {word}',
  async ({ sesion }, tipo: string, umbral: string, gasto: string) => {
    expect((await sesion.alerta(tipo, umbral)).gasto_hoy).toBe(gasto);
  },
);

Given('que eliminé la alerta de {word} con umbral S\\/ {word}', async ({ sesion }, tipo: string, umbral: string) => {
  const a = await sesion.alerta(tipo, umbral);
  expect((await sesion.api('delete', `/api/limites/alertas/${a.id}`)).status()).toBe(204);
});

// ------------------------------------------------------------------------------------- concurrencia
let simultaneas: number[] = [];

When('{int} visitantes se registran a la vez con el celular {string}', async ({ sesion }, n: number, celular: string) => {
  const respuestas = await Promise.all(
    Array.from({ length: n }, () =>
      sesion.cruda('post', '/api/usuarios', undefined, { dni: '45678912', celular, pin: '4826', nombres: 'Lucía Fernández' }),
    ),
  );
  simultaneas = respuestas.map((r) => r.status()).sort();
});

Then('una respuesta es 201 y las demás son 409 con {string}', async ({}, _codigo: string) => {
  expect(simultaneas).toEqual([201, ...Array(simultaneas.length - 1).fill(409)]);
});
