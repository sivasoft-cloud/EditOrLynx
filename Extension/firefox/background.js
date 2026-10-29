/**
 * Edit.or.lynx — browser bridge.
 *
 * Hands links to the Edit.or.lynx app on this Mac over its loopback door
 * (127.0.0.1:47820). Works in Chrome, Edge, Brave and Firefox from one file.
 *
 * What it does:
 *   • the toolbar popup sends the page, or a pasted link
 *   • the right-click menu sends links, videos and pages
 *   • a small button over plain <video> players sends the file itself
 *   • downloads the browser starts are cancelled and handed to the app instead
 */

const APP_PORT = 47820;
const APP = `http://127.0.0.1:${APP_PORT}`;
const SMALL_FILE = 500000;

function getStorage(keys) {
  return new Promise((resolve) => {
    try {
      chrome.storage.local.get(keys, (value) => resolve(value || {}));
    } catch (_) {
      resolve({});
    }
  });
}

function setStorage(value) {
  return new Promise((resolve) => {
    try {
      chrome.storage.local.set(value, resolve);
    } catch (_) {
      resolve();
    }
  });
}

async function appStatus(timeout = 1500) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  try {
    const response = await fetch(`${APP}/status`, { signal: controller.signal, cache: "no-store" });
    if (!response.ok) return null;
    return await response.json();
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

function cleanTitle(title) {
  return String(title || "")
    .replace(/^\s*\(\d+\)\s*/, "")
    .replace(/\s+[-–|]\s+(YouTube|Vimeo|TikTok|Instagram|X|Twitter|Twitch|Dailymotion|Facebook)$/i, "")
    .trim();
}

async function send(url, title, action = "download", quality = null, audioOnly = false) {
  if (!/^https?:/i.test(url || "")) {
    return { ok: false, error: "This page can't be downloaded." };
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const payload = { url, title: cleanTitle(title), action };
    if (quality) payload.quality = quality;
    if (audioOnly) payload.audioOnly = true;

    const response = await fetch(`${APP}/job`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal
    });
    const json = await response.json().catch(() => ({}));
    if (!response.ok || json.ok === false) {
      return { ok: false, error: json.error || `Edit.or.lynx answered ${response.status}` };
    }
    return json;
  } catch (_) {
    return { ok: false, error: "Edit.or.lynx isn't running on this Mac." };
  } finally {
    clearTimeout(timer);
  }
}

function setBadge(text, color) {
  try {
    if (!text) {
      chrome.action ? chrome.action.setBadgeText({ text: "" }) : chrome.browserAction.setBadgeText({ text: "" });
      return;
    }
    if (chrome.action) {
      chrome.action.setBadgeBackgroundColor({ color: color || "#30D158" });
      chrome.action.setBadgeText({ text });
    } else if (chrome.browserAction) {
      chrome.browserAction.setBadgeBackgroundColor({ color: color || "#30D158" });
      chrome.browserAction.setBadgeText({ text });
    }
  } catch (_) {
    /* some browsers have no badge */
  }
}

// --- Menus -------------------------------------------------------------------

function buildMenus() {
  try {
    chrome.contextMenus.removeAll(() => {
      chrome.contextMenus.create({ id: "lynk-link", title: "Download Link with Edit.or.lynx", contexts: ["link"] });
      chrome.contextMenus.create({ id: "lynk-media", title: "Download with Edit.or.lynx", contexts: ["video", "audio", "image"] });
      chrome.contextMenus.create({ id: "lynk-page", title: "Download This Page with Edit.or.lynx", contexts: ["page", "frame"] });
      chrome.contextMenus.create({ id: "lynk-clip", title: "Make a Clip with Edit.or.lynx…", contexts: ["page", "frame", "video"] });
    });
  } catch (_) {
    /* no menus in this browser */
  }
}

chrome.runtime.onInstalled.addListener(buildMenus);
chrome.runtime.onStartup.addListener(buildMenus);
buildMenus();

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  const pageUrl = info.frameUrl || info.pageUrl || tab?.url;
  const isVideoUrl = (u) => /youtube\.com|youtu\.be|vimeo\.com|dailymotion\.com|twitch\.tv|tiktok\.com/i.test(u || "");
  switch (info.menuItemId) {
    case "lynk-link":
      await send(info.linkUrl, info.selectionText || tab?.title, isVideoUrl(info.linkUrl) ? "options" : "download");
      break;
    case "lynk-media": {
      const src = info.srcUrl || pageUrl;
      const target = src.startsWith("blob:") ? pageUrl : src;
      await send(target, tab?.title, isVideoUrl(target) ? "options" : "download");
      break;
    }
    case "lynk-page":
      await send(pageUrl, tab?.title, isVideoUrl(pageUrl) ? "options" : "download");
      break;
    case "lynk-clip":
      await send(pageUrl, tab?.title, "clip");
      break;
  }
});

// --- Keyboard shortcut ---------------------------------------------------------

if (chrome.commands && chrome.commands.onCommand) {
  chrome.commands.onCommand.addListener(async (command) => {
    if (command !== "send-page") return;
    const tabs = await new Promise((resolve) => chrome.tabs.query({ active: true, currentWindow: true }, resolve));
    const tab = tabs && tabs[0];
    if (tab && tab.url) await send(tab.url, tab.title);
  });
}

// --- Messages from the popup and the page ------------------------------------

chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (!message || typeof message !== "object") return false;

  if (message.type === "lynk-status") {
    appStatus().then((status) => reply({ ok: !!status, status }));
    return true;
  }

  if (message.type === "lynk-send") {
    send(message.url, message.title || sender?.tab?.title, message.action || "download", message.quality, message.audioOnly)
      .then((result) => {
        if (!result.ok) setBadge("!", "#FF453A");
        reply(result);
      });
    return true;
  }

  if (message.type === "lynk-settings") {
    getStorage(["lynkCatch"]).then((stored) => reply({ catchDownloads: stored.lynkCatch !== false }));
    return true;
  }

  if (message.type === "lynk-set-catch") {
    setStorage({ lynkCatch: !!message.value }).then(() => reply({ catchDownloads: !!message.value }));
    return true;
  }

  return false;
});

// --- Taking over the browser's downloads -------------------------------------

let catchDownloads = true;
getStorage(["lynkCatch"]).then((stored) => {
  catchDownloads = stored.lynkCatch !== false;
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.lynkCatch) {
    catchDownloads = changes.lynkCatch.newValue !== false;
  }
});

const handedOff = new Set();

async function handleBrowserDownload(item) {
  if (!catchDownloads) return;
  if (!item || item.incognito) return;
  if (item.byExtensionId === chrome.runtime.id) return;
  const url = item.finalUrl || item.url;
  if (!/^https?:/i.test(url || "")) return;
  if (/^(text\/html|application\/xhtml)/i.test(item.mime || "")) return;
  if (handedOff.has(item.id)) return;
  handedOff.add(item.id);
  setTimeout(() => handedOff.delete(item.id), 30000);

  // 1. Hand off to Edit.or.lynx app to offer download in Notch HUD
  const filename = item.filename ? item.filename.split(/[\\/]/).pop() : "";
  send(url, filename, "offer").then((result) => {
    if (result && result.ok) {
      setBadge("✓", "#30D158");
      setTimeout(() => setBadge(""), 2500);
      // 2. Immediately cancel and erase from browser ("browser in-download don't")
      try {
        chrome.downloads.cancel(item.id, () => {
          try { chrome.downloads.erase({ id: item.id }, () => {}); } catch (_) {}
        });
      } catch (_) {}
    } else {
      setBadge("!", "#FF453A");
    }
  }).catch(() => {});
}

if (chrome.downloads) {
  if (chrome.downloads.onDeterminingFilename) {
    chrome.downloads.onDeterminingFilename.addListener((item, suggest) => {
      handleBrowserDownload(item);
      try { suggest(); } catch (_) {}
      return false;
    });
  } else if (chrome.downloads.onCreated) {
    chrome.downloads.onCreated.addListener(handleBrowserDownload);
  }
}
