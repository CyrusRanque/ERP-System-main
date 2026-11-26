/**
 * Smoke-test every GET route the Flutter app uses (after login).
 * Run: npm run verify-mobile-api
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const base = `http://127.0.0.1:${process.env.PORT || 8000}/api/mobile`;

const GET_ROUTES = [
  '/health',
  '/auth/me',
  '/settings',
  '/dashboard/stats',
  '/setup/companies',
  '/setup/branches',
  '/setup/customers',
  '/setup/suppliers',
  '/setup/items',
  '/setup/projects',
  '/quotations',
  '/purchase-orders',
  '/receivings',
  '/outslips',
  '/delivery-receipts',
  '/billings',
  '/accomplishments',
  '/ar-contracts',
];

async function main() {
  const health = await fetch(`${base}/health`);
  if (!health.ok) {
    console.error('API not running. Start with: npm start');
    process.exit(1);
  }

  const loginRes = await fetch(`${base}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ login: 'admin', password: 'p@ssw0rd' }),
  });
  const loginBody = await loginRes.json();
  if (!loginBody.token) {
    console.error('Login failed:', loginBody.message || loginBody);
    process.exit(1);
  }

  const headers = {
    Authorization: `Bearer ${loginBody.token}`,
    Accept: 'application/json',
  };

  let failed = 0;
  for (const path of GET_ROUTES) {
    const url = path.startsWith('/health') ? `${base}${path}` : `${base}${path}`;
    const reqHeaders = path === '/health' ? { Accept: 'application/json' } : headers;
    try {
      const res = await fetch(url, { headers: reqHeaders });
      const body = await res.json().catch(() => ({}));
      if (!res.ok) {
        failed += 1;
        console.error(`FAIL ${path} → ${res.status} ${body.message || ''}`);
      } else {
        const count = Array.isArray(body.data) ? body.data.length : body.data ? 1 : 0;
        console.log(`OK   ${path}${Array.isArray(body.data) ? ` (${count} rows)` : ''}`);
      }
    } catch (err) {
      failed += 1;
      console.error(`FAIL ${path} → ${err.message}`);
    }
  }

  if (failed > 0) {
    console.error(`\n${failed} route(s) failed. Fix schema or controllers before using the mobile app.`);
    process.exit(1);
  }
  console.log('\nMobile API smoke test passed.');
}

main();
