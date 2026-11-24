import { testSignup } from './test-signup.ts';
// Tests accounts over HTTP against a running server (npm start).
// Usage:  node scripts/auth-test.ts [baseUrl]
const BASE = process.argv[2] ?? 'http://localhost:3000';
const failures: string[] = [];
const check = (ok: boolean, label: string) => { console.log(`${ok ? 'OK  ' : 'FAIL'} ${label}`); if (!ok) failures.push(label); };

async function call(method: string, path: string, body?: unknown, cookie = '') {
  const res = await fetch(BASE + path, { method, headers: { 'Content-Type': 'application/json', Cookie: cookie }, body: body ? JSON.stringify(body) : undefined });
  return { status: res.status, data: await res.json(), setCookie: res.headers.get('set-cookie') ?? '' };
}

const name = `tester${Math.random().toString(36).slice(2, 8)}`;
const reg = await testSignup(BASE, name, 'correct horse');
check(reg.status === 200 && reg.data.user.username === name, 'register a new account');
check(/HttpOnly/.test(reg.setCookie) && /SameSite=Lax/.test(reg.setCookie), 'login cookie is HttpOnly + SameSite');
const cookie = reg.setCookie.split(';')[0]!;
check(!JSON.stringify(reg.data).includes('password'), 'no password data sent back');
check((await call('POST', '/api/auth/register', { username: name.toUpperCase(), email: 'other@example.test', password: 'another one' })).status === 400, 'duplicate username refused (any capitalization)');
check((await call('POST', '/api/auth/register', { username: 'a b', email: 'ab@example.test', password: 'whatever12' })).status === 400, 'invalid username refused');
check((await call('POST', '/api/auth/register', { username: name + 'x', email: 'x@example.test', password: 'short' })).status === 400, 'short password refused');
check((await call('GET', '/api/auth/me', undefined, cookie)).data.user?.username === name, '"me" knows who is logged in');
check((await call('GET', '/api/auth/me')).data.user === null, 'no cookie = not logged in');
check((await call('GET', '/api/auth/me', undefined, 'yugs_session=forged')).data.user === null, 'forged cookie refused');
check((await call('POST', '/api/auth/login', { username: name, password: 'wrong password' })).status === 401, 'wrong password refused');
const login = await call('POST', '/api/auth/login', { username: name.toUpperCase(), password: 'correct horse' });
check(login.status === 200, 'login works (username not case sensitive)');
const cookie2 = login.setCookie.split(';')[0]!;
await call('POST', '/api/auth/logout', {}, cookie2);
check((await call('GET', '/api/auth/me', undefined, cookie2)).data.user === null, 'logout ends that login');
check((await call('GET', '/api/auth/me', undefined, cookie)).data.user?.username === name, 'other logins stay active');
let blocked = false;
for (let i = 0; i < 10; i++) {
  const r = await call('POST', '/api/auth/login', { username: name, password: `guess${i}` });
  if (/Too many/.test(r.data.error ?? '')) blocked = true;
}
check(blocked, 'repeated wrong passwords get blocked');
console.log(failures.length ? `\n${failures.length} FAILED` : '\nAll account checks passed.');
process.exit(failures.length ? 1 : 0);
