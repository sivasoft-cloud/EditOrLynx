const statusEl = document.getElementById("status");
const dot = document.getElementById("dot");
const pageButton = document.getElementById("page");
const clipButton = document.getElementById("clip");
const urlInput = document.getElementById("url");
const sendButton = document.getElementById("send");
const catchInput = document.getElementById("catch");
const hint = document.getElementById("hint");

let tab = null;

function say(text, tone) {
  hint.textContent = text;
  hint.classList.toggle("error", tone === "error");
}

function ask(message) {
  return new Promise((resolve) => {
    chrome.runtime.sendMessage(message, (reply) => resolve(reply || {}));
  });
}

async function loadTab() {
  if (chrome.tabs && chrome.tabs.query) {
    const tabs = await new Promise((resolve) => chrome.tabs.query({ active: true, currentWindow: true }, resolve));
    tab = tabs && tabs[0];
  }
  if (!tab || !/^https?:/i.test(tab.url || "")) {
    pageButton.disabled = true;
    clipButton.disabled = true;
    say("Open a web page to send it to Edit.or.lynx.");
  }
}

async function refreshStatus() {
  const reply = await ask({ type: "lynk-status" });
  if (reply.ok) {
    dot.classList.add("on");
    const active = reply.status && reply.status.activeCount;
    statusEl.textContent = active ? `Connected · ${active} downloading` : "Connected";
    pageButton.disabled = false;
  } else {
    dot.classList.add("off");
    statusEl.textContent = "Open Edit.or.lynx to connect";
  }
}

async function send(url, action) {
  say("Sending…");
  const reply = await ask({ type: "lynk-send", url, title: tab && tab.title, action: action || "download" });
  if (reply.ok) {
    say("Sent to Edit.or.lynx.");
    setTimeout(() => window.close(), 650);
  } else {
    say(reply.error || "Couldn't reach Edit.or.lynx.", "error");
  }
}

pageButton.addEventListener("click", () => {
  if (!tab || !tab.url) return;
  const isVideo = /youtube\.com|youtu\.be|vimeo\.com|dailymotion\.com|twitch\.tv|tiktok\.com/i.test(tab.url);
  send(tab.url, isVideo ? "options" : "download");
});

clipButton.addEventListener("click", () => {
  if (!tab || !tab.url) return;
  send(tab.url, "clip");
});

sendButton.addEventListener("click", () => {
  const value = urlInput.value.trim();
  if (!/^https?:/i.test(value)) {
    say("Paste a link that starts with http.", "error");
    return;
  }
  const isVideo = /youtube\.com|youtu\.be|vimeo\.com|dailymotion\.com|twitch\.tv|tiktok\.com/i.test(value);
  send(value, isVideo ? "options" : "download");
});

urlInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") sendButton.click();
});

catchInput.addEventListener("change", async () => {
  const reply = await ask({ type: "lynk-set-catch", value: catchInput.checked });
  say(reply.catchDownloads ? "Browser downloads go to Edit.or.lynx." : "Browser downloads stay in the browser.");
});

(async () => {
  const settings = await ask({ type: "lynk-settings" });
  catchInput.checked = settings.catchDownloads !== false;
  await loadTab();
  await refreshStatus();
  urlInput.focus();
})();
