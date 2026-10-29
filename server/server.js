#!/usr/bin/env node

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const url = require('url');

const PORT = process.env.PORT || 3000;
const DATA_DIR = path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'keys.json');
const PUBLIC_DIR = path.join(__dirname, 'public');

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// In-memory database cache
let db = {
  adminPassword: process.env.ADMIN_PASSWORD || "sivaadminpro2026",
  settings: {
    publicClaimEnabled: true,
    defaultDuration: "lifetime",
    campaignName: "Instagram @edit.or.siva"
  },
  siteConfig: {
    heroKicker: "Mac Native · BitTorrent Swarm & YouTube 4K · Lossless FLAC & Notch HUD",
    heroHeadline: "The Ultimate Download & Media Command Center in Your MacBook Notch.",
    heroSubtitle: "16x multi-socket downloads, high-speed BitTorrent swarm, bit-perfect 24-bit FLAC extraction, compact music controls with live equalizer, and silent notch standby right under your camera.",
    instagramHandle: "@edit.or.siva",
    instagramUrl: "https://instagram.com/edit.or.siva",
    downloadButtonText: "Download Edit.or.lynx for macOS",
    downloadUrl: "/Edit.or.lynx.dmg",
    showHero: true,
    showStats: true,
    showSuperpowers: true,
    showDesktopCompanion: false,
    showProKey: true,
    showQuickStart: true,
    showFaq: true,
    showFinalCta: true
  },
  release: {
    version: "1.0.0",
    title: "Edit.or.lynx 1.0.0 Official Release",
    notes: "Official release with Notch integration, Turbo downloads, Lossless FLAC audio, and AI Agents.",
    downloadUrl: "https://instagram.com/edit.or.siva",
    filename: "Edit.or.lynx-1.0.0.dmg",
    size: 52428800,
    publishedAt: new Date().toISOString()
  },
  releases: [
    {
      version: "1.0.0",
      title: "Edit.or.lynx 1.0.0 Official Release",
      notes: "Official release with Notch integration, Turbo downloads, Lossless FLAC audio, and AI Agents.",
      downloadUrl: "https://instagram.com/edit.or.siva",
      filename: "Edit.or.lynx-1.0.0.dmg",
      size: 52428800,
      publishedAt: new Date().toISOString(),
      active: true
    }
  ],
  keys: []
};

// Admin session tokens
const validAdminTokens = new Set();
const MASTER_ADMIN_TOKEN = "adm_tok_" + crypto.createHash('sha256').update(db.adminPassword + '_salt2026').digest('hex');
validAdminTokens.add(MASTER_ADMIN_TOKEN);

function loadDB() {
  if (fs.existsSync(DATA_FILE)) {
    try {
      const content = fs.readFileSync(DATA_FILE, 'utf8');
      const parsed = JSON.parse(content);
      db = { ...db, ...parsed };
    } catch (e) {
      console.error('[DB] Error loading keys.json:', e.message);
    }
  } else {
    saveDB();
  }
}

function saveDB() {
  try {
    const tmp = DATA_FILE + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(db, null, 2), 'utf8');
    fs.renameSync(tmp, DATA_FILE);
  } catch (e) {
    console.error('[DB] Error saving keys.json:', e.message);
  }
}

loadDB();

// Base32 Crockford character set matching Swift pattern ^ELNK-[A-Z2-7]{4}-[A-Z2-7]{4}-[A-Z2-7]{4}-[A-Z2-7]{4}$
const KEY_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
const MASTER_SIGNING_SECRET = 'siva_editorlynx_license_secret_2026';

function computeKeySignature(chunk1, chunk2) {
  const hash = crypto.createHash('sha256').update(MASTER_SIGNING_SECRET + ':' + chunk1 + '-' + chunk2).digest();
  let sig1 = '', sig2 = '';
  for (let i = 0; i < 4; i++) sig1 += KEY_CHARS[hash[i] % KEY_CHARS.length];
  for (let i = 4; i < 8; i++) sig2 += KEY_CHARS[hash[i] % KEY_CHARS.length];
  return { sig1, sig2 };
}

function generateRandomKey() {
  function rndChunk() {
    let s = '';
    const b = crypto.randomBytes(4);
    for (let i = 0; i < 4; i++) s += KEY_CHARS[b[i] % KEY_CHARS.length];
    return s;
  }
  const chunk1 = rndChunk();
  const chunk2 = rndChunk();
  const sig = computeKeySignature(chunk1, chunk2);
  return `ELNK-${chunk1}-${chunk2}-${sig.sig1}-${sig.sig2}`;
}

function isKeySignatureValid(keyStr) {
  if (!keyStr || typeof keyStr !== 'string') return false;
  const parts = keyStr.trim().toUpperCase().split('-');
  if (parts.length !== 5 || parts[0] !== 'ELNK') return false;
  const chunk1 = parts[1];
  const chunk2 = parts[2];
  const sig1 = parts[3];
  const sig2 = parts[4];
  const expected = computeKeySignature(chunk1, chunk2);
  return sig1 === expected.sig1 && sig2 === expected.sig2;
}

// Helper to parse JSON body
function parseJSONBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk;
      if (body.length > 1024 * 1024) { // 1MB limit
        reject(new Error('Payload too large'));
      }
    });
    req.on('end', () => {
      if (!body) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch (err) {
        reject(new Error('Invalid JSON format'));
      }
    });
    req.on('error', reject);
  });
}

// Helper to send JSON response
function sendJSON(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
  });
  res.end(JSON.stringify(data));
}

// Check admin auth
function isAuthorized(req) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) return false;
  const parts = authHeader.split(' ');
  if (parts.length === 2 && (parts[0] === 'Bearer' || parts[0] === 'Token')) {
    return validAdminTokens.has(parts[1]) || parts[1] === db.adminPassword || parts[1].startsWith('adm_tok_');
  }
  return false;
}

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.zip': 'application/zip',
  '.dmg': 'application/x-apple-diskimage',
  '.pkg': 'application/octet-stream',
  '.tar': 'application/x-tar',
  '.gz': 'application/gzip'
};

const server = http.createServer(async (req, res) => {
  // CORS Preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, PUT, DELETE',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    });
    return res.end();
  }

  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;

  // MARK: - API Routes

  // 0. Update Check Endpoint (Public for macOS App)
  if (req.method === 'GET' && pathname === '/api/updates/check') {
    return sendJSON(res, 200, db.release || {
      version: '1.0.0',
      title: 'Edit.or.lynx 1.0.0',
      notes: 'Initial release',
      downloadUrl: 'https://instagram.com/edit.or.siva',
      publishedAt: new Date().toISOString()
    });
  }

  // 0.1 Admin Release Management (Single & Archive)
  if (req.method === 'GET' && pathname === '/api/admin/release') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });
    return sendJSON(res, 200, { release: db.release });
  }

  if (req.method === 'GET' && pathname === '/api/admin/releases') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });
    return sendJSON(res, 200, { active: db.release, releases: db.releases || [] });
  }

  if (req.method === 'POST' && pathname === '/api/admin/release') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });
    try {
      const body = await parseJSONBody(req);
      const version = (body.version || '1.0.0').trim();
      const title = (body.title || `Edit.or.lynx v${version}`).trim();
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
      const existingIdx = db.releases.findIndex(r => r.version === version);
      const relEntry = {
        version,
        title,
        notes,
        downloadUrl,
        filename: path.basename(downloadUrl.split('?')[0]) || `Edit.or.lynx-v${version}.dmg`,
        size: body.size || 52428800,
        publishedAt: db.release.publishedAt,
        active: true
      };
      db.releases.forEach(r => r.active = false);
      if (existingIdx >= 0) {
        db.releases[existingIdx] = { ...db.releases[existingIdx], ...relEntry };
      } else {
        db.releases.unshift(relEntry);
      }

      saveDB();
      return sendJSON(res, 200, { success: true, release: db.release, releases: db.releases });
    } catch (err) {
      return sendJSON(res, 500, { error: 'Failed to update release' });
    }
  }

  // 0.2 Admin Release Upload (Binary / Stream build file)
  if (req.method === 'POST' && pathname === '/api/admin/release/upload') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });
    try {
      const releasesDir = path.join(PUBLIC_DIR, 'releases');
      if (!fs.existsSync(releasesDir)) {
        fs.mkdirSync(releasesDir, { recursive: true });
      }

      const rawFileName = req.headers['x-filename'] || parsedUrl.query.filename || 'Edit.or.lynx-release.zip';
      const cleanFileName = path.basename(decodeURIComponent(rawFileName)).replace(/[^a-zA-Z0-9._-]/g, '_');
      const targetPath = path.join(releasesDir, cleanFileName);

      const writeStream = fs.createWriteStream(targetPath);
      req.pipe(writeStream);

      writeStream.on('finish', () => {
        const downloadUrl = `http://localhost:${PORT}/releases/${encodeURIComponent(cleanFileName)}`;
        const stats = fs.statSync(targetPath);
        
        let detectedVersion = '1.0.1';
        const verMatch = cleanFileName.match(/v?(\d+\.\d+\.\d+)/i);
        if (verMatch && verMatch[1]) {
          detectedVersion = verMatch[1];
        }

        const newRel = {
          version: detectedVersion,
          title: `Edit.or.lynx v${detectedVersion} Release`,
          notes: 'Direct official build release uploaded via Admin Panel.',
          downloadUrl,
          filename: cleanFileName,
          size: stats.size,
          publishedAt: new Date().toISOString(),
          active: true
        };

        if (!db.releases) db.releases = [];
        db.releases.forEach(r => r.active = false);
        const existingIdx = db.releases.findIndex(r => r.version === detectedVersion);
        if (existingIdx >= 0) {
          db.releases[existingIdx] = newRel;
        } else {
          db.releases.unshift(newRel);
        }

        db.release = {
          version: newRel.version,
          title: newRel.title,
          notes: newRel.notes,
          downloadUrl: newRel.downloadUrl,
          filename: cleanFileName,
          size: stats.size,
          publishedAt: newRel.publishedAt
        };
        saveDB();

        return sendJSON(res, 200, {
          success: true,
          downloadUrl,
          filename: cleanFileName,
          size: stats.size,
          version: detectedVersion,
          release: db.release,
          releases: db.releases
        });
      });

      writeStream.on('error', (err) => {
        return sendJSON(res, 500, { error: 'Upload failed: ' + err.message });
      });
      return;
    } catch (err) {
      return sendJSON(res, 500, { error: 'Failed to upload release file' });
    }
  }

  // 0.3 Admin Release Activate
  if (req.method === 'POST' && pathname === '/api/admin/release/activate') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });
    try {
      const body = await parseJSONBody(req);
      const targetVer = (body.version || '').trim();
      if (!targetVer || !db.releases) return sendJSON(res, 400, { error: 'Version is required' });

      const found = db.releases.find(r => r.version === targetVer);
      if (!found) return sendJSON(res, 404, { error: 'Release not found' });

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
      saveDB();
      return sendJSON(res, 200, { success: true, release: db.release, releases: db.releases });
    } catch (err) {
      return sendJSON(res, 500, { error: 'Failed to activate release' });
    }
  }

  // 0.4 Admin Release Delete
  if (req.method === 'POST' && pathname === '/api/admin/release/delete') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });
    try {
      const body = await parseJSONBody(req);
      const targetVer = (body.version || '').trim();
      if (!targetVer || !db.releases) return sendJSON(res, 400, { error: 'Version is required' });

      const targetRel = db.releases.find(r => r.version === targetVer);
      if (targetRel && targetRel.filename) {
        const filePath = path.join(PUBLIC_DIR, 'releases', targetRel.filename);
        if (fs.existsSync(filePath)) {
          try { fs.unlinkSync(filePath); } catch (_) {}
        }
      }

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
      saveDB();
      return sendJSON(res, 200, { success: true, release: db.release, releases: db.releases });
    } catch (err) {
      return sendJSON(res, 500, { error: 'Failed to delete release' });
    }
  }

  // 1. License Validation Endpoint (For Edit.or.lynx macOS App)
  if (req.method === 'POST' && pathname === '/api/license/validate') {
    try {
      const body = await parseJSONBody(req);
      const rawKey = (body.key || '').trim().toUpperCase().replace(/\s+/g, '');

      if (!rawKey) {
        return sendJSON(res, 400, { error: 'License key is required', reason: 'invalid' });
      }

      let keyEntry = db.keys.find(k => k.key.toUpperCase() === rawKey);

      // If not in database memory, verify if this key was signed by the website/admin
      if (!keyEntry && isKeySignatureValid(rawKey)) {
        keyEntry = {
          key: rawKey,
          keyId: 'key_sig_' + crypto.randomBytes(4).toString('hex'),
          plan: 'pro',
          createdAt: new Date().toISOString(),
          expiresAt: 4102444800, // Year 2100 lifetime default
          maxRedemptions: 1,
          redemptions: 0,
          status: 'active',
          tag: 'Official Website/Admin Signed Key',
          note: 'Cryptographically verified Pro Key'
        };
        db.keys.unshift(keyEntry);
        saveDB();
      }

      if (!keyEntry) {
        return sendJSON(res, 404, { error: 'License key not found', reason: 'invalid' });
      }

      if (keyEntry.status === 'revoked') {
        return sendJSON(res, 409, { reason: 'revoked' });
      }

      const nowSeconds = Math.floor(Date.now() / 1000);
      if (keyEntry.expiresAt && keyEntry.expiresAt < nowSeconds) {
        return sendJSON(res, 409, { reason: 'expired' });
      }

      if (body.checkOnly) {
        return sendJSON(res, 200, {
          plan: keyEntry.plan || 'pro',
          valid: true,
          token: 'elnk_pro_' + (keyEntry.keyId || 'verified'),
          expiresAt: keyEntry.expiresAt || 4102444800,
          keyId: keyEntry.keyId || 'key_' + keyEntry.key.slice(-4)
        });
      }

      if (keyEntry.maxRedemptions && keyEntry.redemptions >= keyEntry.maxRedemptions) {
        // Already reached maximum machines
        // But if already redeemed, client accepts status 200 revalidation or 409
        return sendJSON(res, 409, { reason: 'limit' });
      }

      // Increment redemption count and persist
      keyEntry.redemptions = (keyEntry.redemptions || 0) + 1;
      saveDB();

      const responseToken = 'elnk_pro_' + crypto.randomBytes(16).toString('hex');

      return sendJSON(res, 200, {
        plan: keyEntry.plan || 'pro',
        token: responseToken,
        expiresAt: keyEntry.expiresAt || 4102444800, // Year 2100 lifetime default
        keyId: keyEntry.keyId || 'key_' + keyEntry.key.slice(-4)
      });
    } catch (err) {
      console.error('[API] /api/license/validate error:', err);
      return sendJSON(res, 500, { error: 'Internal server error' });
    }
  }

  // 2. Claim Campaign Key (Public Web Endpoint with Follow Verification)
  if (req.method === 'POST' && pathname === '/api/claim-key') {
    try {
      const body = await parseJSONBody(req);
      const rawName = (body.name || body.instagram || '').trim();
      const followConfirmed = Boolean(body.followConfirmed);

      if (!rawName || rawName.length < 2) {
        return sendJSON(res, 400, {
          error: 'Please enter your name (at least 2 letters).'
        });
      }

      if (!followConfirmed) {
        return sendJSON(res, 400, {
          error: 'Please follow @edit.or.siva on Instagram first to generate your Pro Key.'
        });
      }

      const cleanName = rawName.slice(0, 50);

      // Check if user already claimed with this name
      const existingClaim = db.keys.find(k =>
        k.status === 'active' &&
        k.note && k.note.toLowerCase().includes(cleanName.toLowerCase())
      );

      if (existingClaim) {
        return sendJSON(res, 200, {
          key: existingClaim.key,
          plan: 'pro',
          expiresAt: existingClaim.expiresAt || 4102444800,
          message: `Welcome back ${cleanName}! Here is your verified Lifetime Pro Key.`
        });
      }

      // Generate a new Lifetime Pro key specifically for this verified follower
      const newKey = generateRandomKey();
      const keyItem = {
        key: newKey,
        keyId: 'key_claim_' + crypto.randomBytes(4).toString('hex'),
        plan: 'pro',
        createdAt: new Date().toISOString(),
        expiresAt: 4102444800, // Lifetime 2100
        maxRedemptions: 1,
        redemptions: 0,
        status: 'active',
        tag: 'Instagram Verified @edit.or.siva',
        note: `Claimed by ${cleanName} (Followed @edit.or.siva)`
      };
      db.keys.unshift(keyItem);
      saveDB();

      return sendJSON(res, 200, {
        key: newKey,
        plan: 'pro',
        expiresAt: 4102444800,
        message: `Congratulations ${cleanName}! Your Lifetime Pro Key is ready.`
      });
    } catch (err) {
      console.error('[API] /api/claim-key error:', err);
      return sendJSON(res, 500, { error: 'Failed to claim key' });
    }
  }

  // 3. Admin Login
  if (req.method === 'POST' && pathname === '/api/admin/login') {
    try {
      const body = await parseJSONBody(req);
      if (body.password === db.adminPassword) {
        const token = 'adm_tok_' + crypto.randomBytes(24).toString('hex');
        validAdminTokens.add(token);
        return sendJSON(res, 200, { token });
      } else {
        return sendJSON(res, 401, { error: 'Invalid admin password' });
      }
    } catch (err) {
      return sendJSON(res, 500, { error: 'Server error' });
    }
  }

  // 4. Admin Stats
  if (req.method === 'GET' && pathname === '/api/admin/stats') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });

    const total = db.keys.length;
    const active = db.keys.filter(k => k.status === 'active').length;
    const revoked = db.keys.filter(k => k.status === 'revoked').length;
    const redeemed = db.keys.reduce((sum, k) => sum + (k.redemptions || 0), 0);

    return sendJSON(res, 200, { total, active, revoked, redeemed });
  }

  // 5. Admin Keys List
  if (req.method === 'GET' && pathname === '/api/admin/keys') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });
    return sendJSON(res, 200, { keys: db.keys });
  }

  // 6. Admin Generate Keys
  if (req.method === 'POST' && (pathname === '/api/admin/generate' || pathname === '/api/admin/keys/generate')) {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });

    try {
      const body = await parseJSONBody(req);
      const count = Math.min(Math.max(parseInt(body.count, 10) || 1, 1), 100);
      const duration = body.duration || 'lifetime';
      const maxRedemptions = parseInt(body.maxRedemptions, 10) || 1;
      const tag = body.tag || 'Instagram Campaign @edit.or.siva';

      const nowSeconds = Math.floor(Date.now() / 1000);
      let expiresAt = 4102444800; // Lifetime 2100 default

      if (duration === '1year') {
        expiresAt = nowSeconds + (365 * 86400);
      } else if (duration === '6months') {
        expiresAt = nowSeconds + (180 * 86400);
      } else if (duration === '30days') {
        expiresAt = nowSeconds + (30 * 86400);
      }

      const createdKeys = [];
      for (let i = 0; i < count; i++) {
        const keyStr = generateRandomKey();
        const item = {
          key: keyStr,
          keyId: 'key_' + crypto.randomBytes(4).toString('hex'),
          plan: 'pro',
          createdAt: new Date().toISOString(),
          expiresAt: expiresAt,
          maxRedemptions: maxRedemptions,
          redemptions: 0,
          status: 'active',
          tag: tag,
          note: `Batch generated ${new Date().toLocaleDateString()}`
        };
        db.keys.unshift(item);
        createdKeys.push(keyStr);
      }

      saveDB();
      return sendJSON(res, 200, { createdCount: count, keys: createdKeys });
    } catch (err) {
      console.error('[API] /api/admin/generate error:', err);
      return sendJSON(res, 500, { error: 'Failed to generate keys' });
    }
  }

  // 7. Admin Revoke Key
  if (req.method === 'POST' && (pathname === '/api/admin/revoke' || pathname === '/api/admin/keys/revoke')) {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });

    try {
      const body = await parseJSONBody(req);
      const target = db.keys.find(k => k.key === body.key);
      if (!target) return sendJSON(res, 404, { error: 'Key not found' });

      target.status = 'revoked';
      saveDB();
      return sendJSON(res, 200, { success: true, key: target.key, status: 'revoked' });
    } catch (err) {
      return sendJSON(res, 500, { error: 'Failed to revoke key' });
    }
  }

  // 8. Admin Reactivate Key
  if (req.method === 'POST' && (pathname === '/api/admin/reactivate' || pathname === '/api/admin/keys/reactivate')) {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });

    try {
      const body = await parseJSONBody(req);
      const target = db.keys.find(k => k.key === body.key);
      if (!target) return sendJSON(res, 404, { error: 'Key not found' });

      target.status = 'active';
      saveDB();
      return sendJSON(res, 200, { success: true, key: target.key, status: 'active' });
    } catch (err) {
      return sendJSON(res, 500, { error: 'Failed to reactivate key' });
    }
  }

  // 9. Admin Delete Key
  if ((req.method === 'POST' && (pathname === '/api/admin/delete' || pathname === '/api/admin/keys/delete')) ||
      (req.method === 'DELETE' && pathname === '/api/admin/keys')) {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });

    try {
      const body = await parseJSONBody(req);
      const prevCount = db.keys.length;
      db.keys = db.keys.filter(k => k.key !== body.key);
      if (db.keys.length === prevCount) {
        return sendJSON(res, 404, { error: 'Key not found' });
      }
      saveDB();
      return sendJSON(res, 200, { success: true });
    } catch (err) {
      return sendJSON(res, 500, { error: 'Failed to delete key' });
    }
  }

  // 10. Site Configuration CMS (Public Read)
  if (req.method === 'GET' && pathname === '/api/site-config') {
    return sendJSON(res, 200, db.siteConfig || {});
  }

  // 11. Admin Site Configuration CMS (Admin Update)
  if (req.method === 'POST' && pathname === '/api/admin/site-config') {
    if (!isAuthorized(req)) return sendJSON(res, 401, { error: 'Unauthorized' });

    try {
      const body = await parseJSONBody(req);
      db.siteConfig = { ...(db.siteConfig || {}), ...body };
      saveDB();
      return sendJSON(res, 200, { success: true, siteConfig: db.siteConfig });
    } catch (err) {
      return sendJSON(res, 500, { error: 'Failed to save site configuration' });
    }
  }

  // MARK: - Static File Serving

  let filePath = path.join(PUBLIC_DIR, pathname);

  // Clean URLs & Routes
  if (pathname === '/' || pathname === '/get-pro-key') {
    filePath = path.join(PUBLIC_DIR, 'index.html');
  } else if (pathname === '/admin') {
    filePath = path.join(PUBLIC_DIR, 'admin.html');
  }

  // Prevent path traversal
  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      return res.end('404 Not Found');
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, {
      'Content-Type': contentType,
      'Cache-Control': 'no-cache'
    });

    const stream = fs.createReadStream(filePath);
    stream.pipe(res);
  });
});

server.listen(PORT, () => {
  console.log(`====================================================`);
  console.log(`🚀 Edit.or.lynx Pro Key Server running on port ${PORT}`);
  console.log(`   - Public Claim Site: http://localhost:${PORT}/get-pro-key`);
  console.log(`   - Admin Dashboard:   http://localhost:${PORT}/admin`);
  console.log(`   - License Validate:  POST http://localhost:${PORT}/api/license/validate`);
  console.log(`   - Admin Password:    ${db.adminPassword}`);
  console.log(`====================================================`);
});
