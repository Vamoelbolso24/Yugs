// Test scripts: make an account in one go (sign up + email code).
// Start the test server with  YUGS_TEST_CODES=1 YUGS_CONFIG=none  so it sends no emails and returns the code.
export async function testSignup(base: string, username: string, password: string): Promise<{ status: number; data: any; setCookie: string; cookie: string }> {
  const post = (path: string, body: unknown) => fetch(base + path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const reg = await post('/api/auth/register', { username, email: `${username.toLowerCase()}@example.test`, password });
  const regData: any = await reg.json();
  if (reg.status !== 200) return { status: reg.status, data: regData, setCookie: '', cookie: '' };
  if (!regData.testCode) throw new Error('Start the test server with YUGS_TEST_CODES=1 YUGS_CONFIG=none to run the tests.');
  const res = await post('/api/auth/verify', { username, code: regData.testCode });
  const setCookie = res.headers.get('set-cookie') ?? '';
  return { status: res.status, data: await res.json(), setCookie, cookie: setCookie.split(';')[0] ?? '' };
}
