const fs = require('fs');
const path = require('path');

const publicDir = path.join(__dirname, 'public');
const dataDir = path.join(__dirname, 'data');

const indexHtml = fs.readFileSync(path.join(publicDir, 'index.html'), 'utf8');
const adminHtml = fs.readFileSync(path.join(publicDir, 'admin.html'), 'utf8');
const stylesCss = fs.readFileSync(path.join(publicDir, 'styles.css'), 'utf8');
const appJs = fs.readFileSync(path.join(publicDir, 'app.js'), 'utf8');
const adminJs = fs.readFileSync(path.join(publicDir, 'admin.js'), 'utf8');
const bgJs = fs.readFileSync(path.join(publicDir, 'bg.js'), 'utf8');
const logosJs = fs.readFileSync(path.join(publicDir, 'logos.js'), 'utf8');
const puffJs = fs.readFileSync(path.join(publicDir, 'puff.js'), 'utf8');
const faviconB64 = fs.existsSync(path.join(publicDir, 'assets/favicon.png')) 
  ? fs.readFileSync(path.join(publicDir, 'assets/favicon.png')).toString('base64') 
  : '';
const keysJson = fs.readFileSync(path.join(dataDir, 'keys.json'), 'utf8');

const workerCode = `// Cloudflare Worker for Edit.or.lynx Pro Key Server & Admin Center
// Domain: https://edit-orlynk.sivasoft.workers.dev

const SEED_DATA = ${keysJson};

const KEY_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const MASTER_SIGNING_SECRET = 'siva_editorlynx_license_secret_2026';

async function computeKeySignature(chunk1, chunk2) {
  const encoder = new TextEncoder();
  const data = encoder.encode(MASTER_SIGNING_SECRET + ':' + chunk1 + '-' + chunk2);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hash = new Uint8Array(hashBuffer);
  let sig1 = '', sig2 = '';
  for (let i = 0; i < 4; i++) sig1 += KEY_CHARS[hash[i] % KEY_CHARS.length];
  for (let i = 4; i < 8; i++) sig2 += KEY_CHARS[hash[i] % KEY_CHARS.length];
  return { sig1, sig2 };
}

async function generateRandomKey() {
  function rndChunk() {
    let res = '';
    const bytes = new Uint8Array(4);
    crypto.getRandomValues(bytes);
    for (let i = 0; i < 4; i++) {
      res += KEY_CHARS[bytes[i] % KEY_CHARS.length];
    }
    return res;
  }
  const chunk1 = rndChunk();
  const chunk2 = rndChunk();
  const sig = await computeKeySignature(chunk1, chunk2);
  return \`ELNK-\${chunk1}-\${chunk2}-\${sig.sig1}-\${sig.sig2}\`;
}

async function isKeySignatureValid(keyStr) {
  if (!keyStr || typeof keyStr !== 'string') return false;
  const parts = keyStr.trim().toUpperCase().split('-');
  if (parts.length !== 5 || parts[0] !== 'ELNK') return false;
  const chunk1 = parts[1];
  const chunk2 = parts[2];
  const sig1 = parts[3];
  const sig2 = parts[4];
  const expected = await computeKeySignature(chunk1, chunk2);
  return sig1 === expected.sig1 && sig2 === expected.sig2;
}

function jsonResponse(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      ...headers
    }
  });
}

function textResponse(content, contentType, status = 200) {
  return new Response(content, {
    status,
    headers: {
      'Content-Type': contentType,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache'
    }
  });
}

// In-memory fallback if KV is not bound
let memoryData = JSON.parse(JSON.stringify(SEED_DATA));

async function getDB(env) {
  if (env && env.PRO_KEYS_KV) {
    const val = await env.PRO_KEYS_KV.get('db_state', 'json');
    if (val) return val;
  }
  return memoryData;
}

async function saveDB(env, data) {
  memoryData = data;
  if (env && env.PRO_KEYS_KV) {
    await env.PRO_KEYS_KV.put('db_state', JSON.stringify(data));
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const method = request.method;

    // CORS preflight
    if (method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          'Access-Control-Max-Age': '86400'
        }
      });
    }

    const db = await getDB(env);
    const adminPassword = (env && env.ADMIN_PASSWORD) || db.adminPassword || "sivaadminpro2026";

    function isAuthorized() {
      const authHeader = request.headers.get('authorization') || '';
      const parts = authHeader.split(' ');
      if (parts.length === 2 && (parts[0] === 'Bearer' || parts[0] === 'Token')) {
        return parts[1] === adminPassword || parts[1].startsWith('adm_tok_');
      }
      return false;
    }

    // --- API Routes ---

    // 0. Update Check Endpoint (Public for macOS App)
    if (method === 'GET' && pathname === '/api/updates/check') {
      return jsonResponse(db.release || {
        version: '1.0.0',
        title: 'Edit.or.lynx 1.0.0 Official Release',
        notes: 'Official release with Notch integration, Turbo downloads, Lossless FLAC audio, and AI Agents.',
        downloadUrl: 'https://instagram.com/edit.or.siva',
        publishedAt: new Date().toISOString()
      });
    }

    // 0.1 Admin Release Management (Single & Archive)
    if (method === 'GET' && pathname === '/api/admin/release') {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      return jsonResponse({ release: db.release });
    }

    if (method === 'GET' && pathname === '/api/admin/releases') {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      return jsonResponse({ active: db.release, releases: db.releases || [] });
    }

    if (method === 'POST' && pathname === '/api/admin/release') {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      try {
        const body = await request.json().catch(() => ({}));
        const version = (body.version || '1.0.0').trim();
        const title = (body.title || ('Edit.or.lynx v' + version)).trim();
        const notes = (body.notes || 'Performance enhancements and stability updates.').trim();
        const downloadUrl = (body.downloadUrl || 'https://instagram.com/edit.or.siva').trim();

        db.release = {
          version,
          title,
          notes,
          downloadUrl,
          publishedAt: new Date().toISOString()
        };

        if (!db.releases) db.releases = [];
        db.releases.forEach(r => r.active = false);
        const existingIdx = db.releases.findIndex(r => r.version === version);
        const relEntry = {
          version,
          title,
          notes,
          downloadUrl,
          filename: downloadUrl.split('/').pop().split('?')[0] || ('Edit.or.lynx-v' + version + '.dmg'),
          size: body.size || 52428800,
          publishedAt: db.release.publishedAt,
          active: true
        };
        if (existingIdx >= 0) {
          db.releases[existingIdx] = { ...db.releases[existingIdx], ...relEntry };
        } else {
          db.releases.unshift(relEntry);
        }

        await saveDB(env, db);
        return jsonResponse({ success: true, release: db.release, releases: db.releases });
      } catch (err) {
        return jsonResponse({ error: 'Failed to update release' }, 500);
      }
    }

    // 0.3 Admin Release Activate
    if (method === 'POST' && pathname === '/api/admin/release/activate') {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      try {
        const body = await request.json().catch(() => ({}));
        const targetVer = (body.version || '').trim();
        if (!targetVer || !db.releases) return jsonResponse({ error: 'Version is required' }, 400);

        const found = db.releases.find(r => r.version === targetVer);
        if (!found) return jsonResponse({ error: 'Release not found' }, 404);

        db.releases.forEach(r => r.active = (r.version === targetVer));
        db.release = {
          version: found.version,
          title: found.title,
          notes: found.notes,
          downloadUrl: found.downloadUrl,
          filename: found.filename,
          size: found.size,
          publishedAt: found.publishedAt
        };
        await saveDB(env, db);
        return jsonResponse({ success: true, release: db.release, releases: db.releases });
      } catch (err) {
        return jsonResponse({ error: 'Failed to activate release' }, 500);
      }
    }

    // 0.4 Admin Release Delete
    if (method === 'POST' && pathname === '/api/admin/release/delete') {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      try {
        const body = await request.json().catch(() => ({}));
        const targetVer = (body.version || '').trim();
        if (!targetVer || !db.releases) return jsonResponse({ error: 'Version is required' }, 400);

        db.releases = db.releases.filter(r => r.version !== targetVer);
        if (db.release && db.release.version === targetVer) {
          if (db.releases.length > 0) {
            db.releases[0].active = true;
            db.release = { ...db.releases[0] };
          } else {
            db.release = {
              version: '1.0.0',
              title: 'Edit.or.lynx 1.0.0',
              notes: 'Official release',
              downloadUrl: 'https://instagram.com/edit.or.siva',
              publishedAt: new Date().toISOString()
            };
          }
        }
        await saveDB(env, db);
        return jsonResponse({ success: true, release: db.release, releases: db.releases });
      } catch (err) {
        return jsonResponse({ error: 'Failed to delete release' }, 500);
      }
    }

    // 1. License Validation (Native Swift client endpoint)
    if (method === 'POST' && pathname === '/api/license/validate') {
      try {
        const body = await request.json().catch(() => ({}));
        const rawKey = (body.key || '').trim().toUpperCase().replace(/\\s+/g, '');

        if (!rawKey) {
          return jsonResponse({ error: 'License key is required', reason: 'invalid' }, 400);
        }

        let keyEntry = db.keys.find(k => k.key.toUpperCase() === rawKey);

        if (!keyEntry && await isKeySignatureValid(rawKey)) {
          const bytes = new Uint8Array(4);
          crypto.getRandomValues(bytes);
          const hexId = Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
          keyEntry = {
            key: rawKey,
            keyId: 'key_sig_' + hexId,
            plan: 'pro',
            createdAt: new Date().toISOString(),
            expiresAt: 4102444800,
            maxRedemptions: 1,
            redemptions: 0,
            status: 'active',
            tag: 'Official Website/Admin Signed Key',
            note: 'Cryptographically verified Pro Key'
          };
          db.keys.unshift(keyEntry);
          await saveDB(env, db);
        }

        if (!keyEntry) {
          return jsonResponse({ error: 'License key not found', reason: 'invalid' }, 404);
        }

        if (keyEntry.status === 'revoked') {
          return jsonResponse({ reason: 'revoked' }, 409);
        }

        const nowSeconds = Math.floor(Date.now() / 1000);
        if (keyEntry.expiresAt && keyEntry.expiresAt < nowSeconds) {
          return jsonResponse({ reason: 'expired' }, 409);
        }

        if (keyEntry.maxRedemptions && keyEntry.redemptions >= keyEntry.maxRedemptions) {
          return jsonResponse({ reason: 'limit' }, 409);
        }

        keyEntry.redemptions = (keyEntry.redemptions || 0) + 1;
        await saveDB(env, db);

        const bytes = new Uint8Array(16);
        crypto.getRandomValues(bytes);
        const tokenStr = Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');

        return jsonResponse({
          plan: keyEntry.plan || 'pro',
          token: 'elnk_pro_' + tokenStr,
          expiresAt: keyEntry.expiresAt || 4102444800,
          keyId: keyEntry.keyId || 'key_' + keyEntry.key.slice(-4)
        }, 200);
      } catch (err) {
        return jsonResponse({ error: err.message }, 500);
      }
    }

    // 2. Claim Campaign Key (Public with Instagram Follow Verification)
    if (method === 'POST' && pathname === '/api/claim-key') {
      try {
        const body = await request.json().catch(() => ({}));
        const rawName = (body.name || body.instagram || '').trim();
        const followConfirmed = Boolean(body.followConfirmed);

        if (!rawName || rawName.length < 2) {
          return jsonResponse({
            error: 'Please enter your name (at least 2 letters).'
          }, 400);
        }

        if (!followConfirmed) {
          return jsonResponse({
            error: 'Please follow @edit.or.siva on Instagram first to generate your Pro Key.'
          }, 400);
        }

        const cleanName = rawName.slice(0, 50);

        // Check if user already claimed with this name
        const existingClaim = db.keys.find(k =>
          k.status === 'active' &&
          k.note && k.note.toLowerCase().includes(cleanName.toLowerCase())
        );

        if (existingClaim) {
          return jsonResponse({
            key: existingClaim.key,
            plan: 'pro',
            expiresAt: existingClaim.expiresAt || 4102444800,
            message: \`Welcome back \${cleanName}! Here is your verified Lifetime Pro Key.\`
          }, 200);
        }

        const newKey = await generateRandomKey();
        const bytes = new Uint8Array(4);
        crypto.getRandomValues(bytes);
        const hexId = Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');

        const keyItem = {
          key: newKey,
          keyId: 'key_claim_' + hexId,
          plan: 'pro',
          createdAt: new Date().toISOString(),
          expiresAt: 4102444800,
          maxRedemptions: 1,
          redemptions: 0,
          status: 'active',
          tag: 'Instagram Verified @edit.or.siva',
          note: \`Claimed by \${cleanName} (Followed @edit.or.siva)\`
        };
        db.keys.unshift(keyItem);
        await saveDB(env, db);

        return jsonResponse({
          key: newKey,
          plan: 'pro',
          expiresAt: 4102444800,
          message: \`Congratulations \${cleanName}! Your Lifetime Pro Key is ready.\`
        }, 200);
      } catch (err) {
        return jsonResponse({ error: err.message }, 500);
      }
    }

    // 3. Admin Login
    if (method === 'POST' && pathname === '/api/admin/login') {
      try {
        const body = await request.json().catch(() => ({}));
        if (body.password === adminPassword) {
          const bytes = new Uint8Array(24);
          crypto.getRandomValues(bytes);
          const tok = 'adm_tok_' + Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
          return jsonResponse({ token: tok }, 200);
        } else {
          return jsonResponse({ error: 'Invalid admin password' }, 401);
        }
      } catch (err) {
        return jsonResponse({ error: 'Server error' }, 500);
      }
    }

    // 4. Admin Stats
    if (method === 'GET' && pathname === '/api/admin/stats') {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);

      const total = db.keys.length;
      const active = db.keys.filter(k => k.status === 'active').length;
      const revoked = db.keys.filter(k => k.status === 'revoked').length;
      const redeemed = db.keys.reduce((sum, k) => sum + (k.redemptions || 0), 0);

      return jsonResponse({ total, active, revoked, redeemed });
    }

    // 5. Admin Keys List
    if (method === 'GET' && pathname === '/api/admin/keys') {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      return jsonResponse({ keys: db.keys });
    }

    // 6. Admin Generate Keys
    if (method === 'POST' && (pathname === '/api/admin/generate' || pathname === '/api/admin/keys/generate')) {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);

      try {
        const body = await request.json().catch(() => ({}));
        const count = Math.min(Math.max(parseInt(body.count, 10) || 1, 1), 100);
        const duration = body.duration || 'lifetime';
        const maxRedemptions = parseInt(body.maxRedemptions, 10) || 1;
        const tag = body.tag || 'Instagram Campaign @edit.or.siva';

        const nowSeconds = Math.floor(Date.now() / 1000);
        let expiresAt = 4102444800;

        if (duration === '1year') {
          expiresAt = nowSeconds + (365 * 86400);
        } else if (duration === '6months') {
          expiresAt = nowSeconds + (180 * 86400);
        } else if (duration === '30days') {
          expiresAt = nowSeconds + (30 * 86400);
        }

        const createdKeys = [];
        for (let i = 0; i < count; i++) {
          const keyStr = await generateRandomKey();
          const bytes = new Uint8Array(4);
          crypto.getRandomValues(bytes);
          const hexId = Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');

          const item = {
            key: keyStr,
            keyId: 'key_' + hexId,
            plan: 'pro',
            createdAt: new Date().toISOString(),
            expiresAt: expiresAt,
            maxRedemptions: maxRedemptions,
            redemptions: 0,
            status: 'active',
            tag: tag,
            note: \`Batch generated \${new Date().toLocaleDateString()}\`
          };
          db.keys.unshift(item);
          createdKeys.push(keyStr);
        }

        await saveDB(env, db);
        return jsonResponse({ createdCount: count, keys: createdKeys });
      } catch (err) {
        return jsonResponse({ error: err.message }, 500);
      }
    }

    // 7. Admin Revoke Key
    if (method === 'POST' && (pathname === '/api/admin/revoke' || pathname === '/api/admin/keys/revoke')) {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      try {
        const body = await request.json().catch(() => ({}));
        const target = db.keys.find(k => k.key === body.key);
        if (!target) return jsonResponse({ error: 'Key not found' }, 404);

        target.status = 'revoked';
        await saveDB(env, db);
        return jsonResponse({ success: true, key: target.key, status: 'revoked' });
      } catch (err) {
        return jsonResponse({ error: err.message }, 500);
      }
    }

    // 8. Admin Reactivate Key
    if (method === 'POST' && (pathname === '/api/admin/reactivate' || pathname === '/api/admin/keys/reactivate')) {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      try {
        const body = await request.json().catch(() => ({}));
        const target = db.keys.find(k => k.key === body.key);
        if (!target) return jsonResponse({ error: 'Key not found' }, 404);

        target.status = 'active';
        await saveDB(env, db);
        return jsonResponse({ success: true, key: target.key, status: 'active' });
      } catch (err) {
        return jsonResponse({ error: err.message }, 500);
      }
    }

    // 9. Admin Delete Key
    if ((method === 'POST' && (pathname === '/api/admin/delete' || pathname === '/api/admin/keys/delete')) ||
        (method === 'DELETE' && pathname === '/api/admin/keys')) {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      try {
        const body = await request.json().catch(() => ({}));
        const prevCount = db.keys.length;
        db.keys = db.keys.filter(k => k.key !== body.key);
        if (db.keys.length === prevCount) {
          return jsonResponse({ error: 'Key not found' }, 404);
        }
        await saveDB(env, db);
        return jsonResponse({ success: true });
      } catch (err) {
        return jsonResponse({ error: err.message }, 500);
      }
    }

    // 10. Site Config (Public & Admin CMS)
    if (pathname === '/api/site-config') {
      return jsonResponse(db.siteConfig || SEED_DATA.siteConfig || {});
    }

    if (method === 'POST' && pathname === '/api/admin/site-config') {
      if (!isAuthorized()) return jsonResponse({ error: 'Unauthorized' }, 401);
      try {
        const body = await request.json().catch(() => ({}));
        db.siteConfig = { ...(db.siteConfig || SEED_DATA.siteConfig || {}), ...body };
        await saveDB(env, db);
        return jsonResponse({ success: true, siteConfig: db.siteConfig });
      } catch (err) {
        return jsonResponse({ error: err.message }, 500);
      }
    }

    // --- Cloudflare Storage Delivery for DMG Releases & Browser Extensions ---
    if ((pathname.startsWith('/releases/') && pathname.endsWith('.dmg')) || pathname === '/Edit.or.lynx.dmg') {
      if (env && env.PRO_KEYS_KV) {
        const dmgBuf = await env.PRO_KEYS_KV.get('release_dmg', { type: 'arrayBuffer' });
        if (dmgBuf) {
          const filename = pathname.split('/').pop() || 'Edit.or.lynx.dmg';
          return new Response(dmgBuf, {
            status: 200,
            headers: {
              'Content-Type': 'application/x-apple-diskimage',
              'Content-Disposition': 'attachment; filename="' + filename + '"',
              'Cache-Control': 'public, max-age=3600',
              'Access-Control-Allow-Origin': '*'
            }
          });
        }
      }
      if (db.release && db.release.downloadUrl && db.release.downloadUrl !== url.href && !db.release.downloadUrl.endsWith(pathname)) {
        return Response.redirect(db.release.downloadUrl, 302);
      }
      return new Response('Edit.or.lynx DMG Package not found in Cloudflare storage', { status: 404 });
    }

    if (pathname.startsWith('/extensions/')) {
      if (env && env.PRO_KEYS_KV) {
        const isFirefox = pathname.includes('firefox') || pathname.includes('zen');
        const key = isFirefox ? 'ext_firefox' : 'ext_chrome';
        const extBuf = await env.PRO_KEYS_KV.get(key, { type: 'arrayBuffer' });
        if (extBuf) {
          const filename = pathname.split('/').pop() || (isFirefox ? 'editorlynx-firefox-zen-extension.zip' : 'editorlynx-chrome-extension.zip');
          return new Response(extBuf, {
            status: 200,
            headers: {
              'Content-Type': 'application/zip',
              'Content-Disposition': 'attachment; filename="' + filename + '"',
              'Cache-Control': 'public, max-age=3600',
              'Access-Control-Allow-Origin': '*'
            }
          });
        }
      }
      return new Response('Extension archive not found in Cloudflare storage', { status: 404 });
    }

    // --- Static Assets & Pages ---
    if (pathname === '/' || pathname === '/get-pro-key' || pathname === '/index.html') {
      return textResponse(${JSON.stringify(indexHtml)}, 'text/html; charset=utf-8');
    }
    if (pathname === '/admin' || pathname === '/admin.html') {
      return textResponse(${JSON.stringify(adminHtml)}, 'text/html; charset=utf-8');
    }
    if (pathname === '/styles.css' || pathname === '/style.css') {
      return textResponse(${JSON.stringify(stylesCss)}, 'text/css; charset=utf-8');
    }
    if (pathname === '/app.js') {
      return textResponse(${JSON.stringify(appJs)}, 'application/javascript; charset=utf-8');
    }
    if (pathname === '/admin.js') {
      return textResponse(${JSON.stringify(adminJs)}, 'application/javascript; charset=utf-8');
    }
    if (pathname === '/bg.js') {
      return textResponse(${JSON.stringify(bgJs)}, 'application/javascript; charset=utf-8');
    }
    if (pathname === '/logos.js') {
      return textResponse(${JSON.stringify(logosJs)}, 'application/javascript; charset=utf-8');
    }
    if (pathname === '/puff.js') {
      return textResponse(${JSON.stringify(puffJs)}, 'application/javascript; charset=utf-8');
    }
    if (pathname === '/assets/favicon.png' || pathname === '/favicon.ico' || pathname === '/favicon.png') {
      const binStr = atob(${JSON.stringify(faviconB64)});
      const bytes = new Uint8Array(binStr.length);
      for (let i = 0; i < binStr.length; i++) bytes[i] = binStr.charCodeAt(i);
      return new Response(bytes, {
        headers: {
          'Content-Type': 'image/png',
          'Cache-Control': 'public, max-age=86400',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    return new Response('404 Not Found', { status: 404 });
  }
};
`;

fs.writeFileSync(path.join(__dirname, 'worker.js'), workerCode, 'utf8');
console.log('Successfully bundled worker.js');
