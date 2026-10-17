import { expect, type APIRequestContext, type APIResponse } from '@playwright/test';
import { test as base, createBdd } from 'playwright-bdd';

export const USUARIOS: Record<string, { celular: string; pin: string }> = {
  Ana: { celular: '987654321', pin: '4826' },
  Bruno: { celular: '912345678', pin: '7391' },
  Carla: { celular: '956781234', pin: '5917' },
  Diego: { celular: '998877665', pin: '3604' },
};
export const CCI = '00219300123456789012';

/** Estado de un escenario: quién inició sesión y la última respuesta. */
export class Sesion {
  usuario?: string;
  cred?: { celular: string; pin: string };
  token?: string;
  respuesta?: APIResponse;
  tokens: string[] = [];

  constructor(readonly request: APIRequestContext) {}

  get celular(): string {
    return this.cred!.celular;
  }

  async login(nombre: string) {
    this.usuario = nombre;
    await this.loginCon(USUARIOS[nombre].celular, USUARIOS[nombre].pin);
  }

  /** Inicia sesión con un celular y PIN cualesquiera (debe funcionar). */
  async loginCon(celular: string, pin: string) {
    this.cred = { celular, pin };
    const r = await this.request.post('/api/auth/login', { data: this.cred });
    expect(r.status(), await r.text()).toBe(200);
    this.token = (await r.json()).access_token;
    return this.token!;
  }

  /** Petición sin re-login automático (para probar 401). */
  async cruda(metodo: 'get' | 'post' | 'put' | 'delete', ruta: string, token?: string, data?: unknown) {
    const headers: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {};
    return this.request[metodo](ruta, { data, headers });
  }

  /** Llama a la API con el token; si venció (el reloj de la app avanzó), vuelve a iniciar sesión. */
  async api(metodo: 'get' | 'post' | 'put' | 'delete', ruta: string, data?: unknown): Promise<APIResponse> {
    const enviar = () =>
      this.request[metodo](ruta, { data, headers: { Authorization: `Bearer ${this.token}` } });
    let r = await enviar();
    if (r.status() === 401 && this.cred) {
      await this.loginCon(this.cred.celular, this.cred.pin);
      r = await enviar();
    }
    return r;
  }

  async limites() {
    return (await this.api('get', '/api/limites')).json();
  }

  async alerta(tipo: string, umbral: string) {
    const alertas: any[] = await (await this.api('get', '/api/limites/alertas')).json();
    const a = alertas.find((x) => x.tipo === tipo && Number(x.umbral) === Number(umbral));
    expect(a, `No existe la alerta ${tipo} ${umbral}`).toBeTruthy();
    return a;
  }

  async sms(): Promise<string[]> {
    const r = await this.request.get('/api/pruebas/notificaciones', { params: { celular: this.celular } });
    return ((await r.json()) as unknown[]).map((n) => JSON.stringify(n));
  }
}

/** Cuerpo JSON de una respuesta, o {} si no tiene (204). */
export async function cuerpo(r: APIResponse): Promise<any> {
  const texto = await r.text();
  return texto ? JSON.parse(texto) : {};
}

export const test = base.extend<{ sesion: Sesion }>({
  sesion: async ({ request }, use) => use(new Sesion(request)),
});

export const { Given, When, Then } = createBdd(test);
