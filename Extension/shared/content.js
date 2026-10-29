/**
 * Edit.or.lynx — Browser Content Script
 * 
 * Features:
 *   1. YouTube On-Page Quality & Audio Selector Toolbar:
 *      Directly embeds into YouTube video pages with quality selector (4K, 1440p, 1080p, 720p)
 *      and Audio-Only button, with 1-click "Add Task" to Edit.or.lynx notch.
 *   2. General Video Downloader Button:
 *      Floats over plain HTML5 video players on any website.
 */

(() => {
  if (window.top !== window) return;

  // ===========================================================================
  // 1. YouTube On-Page Downloader Integration
  // ===========================================================================

  const isYouTube = () => location.hostname.includes("youtube.com");
  const isYouTubeWatch = () => isYouTube() && (location.pathname.startsWith("/watch") || location.pathname.startsWith("/shorts/"));

  let ytBarMounted = false;

  function injectYouTubeControls() {
    if (!isYouTubeWatch()) {
      const existing = document.getElementById("editorlynx-yt-bar");
      if (existing) existing.remove();
      ytBarMounted = false;
      return;
    }

    if (document.getElementById("editorlynx-yt-bar")) return;

    // Find YouTube actions row (below video, next to like/share buttons)
    const targetContainer = document.querySelector("ytd-watch-metadata #actions #top-level-buttons-computed") ||
      document.querySelector("#actions #top-level-buttons-computed") ||
      document.querySelector("ytd-menu-renderer #top-level-buttons-computed") ||
      document.querySelector("#actions-inner #top-level-buttons-computed") ||
      document.querySelector("#actions.ytd-watch-metadata") ||
      document.querySelector("#actions") ||
      document.querySelector("#above-the-fold") ||
      document.querySelector("#movie_player");

    if (!targetContainer) return;

    const bar = document.createElement("div");
    bar.id = "editorlynx-yt-bar";
    bar.style.cssText = [
      "display:inline-flex",
      "align-items:center",
      "gap:6px",
      "padding:4px 8px",
      "margin:4px 8px 4px 0",
      "background:rgba(22, 22, 26, 0.95)",
      "border:1px solid rgba(255, 255, 255, 0.14)",
      "border-radius:24px",
      "-webkit-backdrop-filter:blur(16px)",
      "backdrop-filter:blur(16px)",
      "box-shadow:0 4px 16px rgba(0, 0, 0, 0.35)",
      "font-family:-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
      "font-size:12px",
      "color:#fff",
      "z-index:9999",
      "transition:all 0.2s ease"
    ].join(";");

    bar.innerHTML = `
      <div style="display:flex;align-items:center;gap:5px;padding-left:4px;cursor:default;">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#30D158" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
        </svg>
        <span style="font-weight:700;font-size:11.5px;color:#fff;letter-spacing:-0.2px;">Lynx</span>
      </div>

      <div style="width:1px;height:16px;background:rgba(255,255,255,0.16);margin:0 2px;"></div>

      <select id="editorlynx-yt-quality" style="
        background:rgba(255,255,255,0.08);
        border:1px solid rgba(255,255,255,0.18);
        color:#fff;
        border-radius:14px;
        padding:3px 8px;
        font-size:11px;
        font-weight:600;
        outline:none;
        cursor:pointer;
      ">
        <option value="4k" style="background:#1a1a1f;color:#fff;">4K Ultra HD (2160p)</option>
        <option value="1440p" style="background:#1a1a1f;color:#fff;">2K Quad HD (1440p)</option>
        <option value="1080p" selected style="background:#1a1a1f;color:#fff;">1080p Full HD</option>
        <option value="720p" style="background:#1a1a1f;color:#fff;">720p HD</option>
        <option value="480p" style="background:#1a1a1f;color:#fff;">480p</option>
        <option value="audio-m4a" style="background:#1a1a1f;color:#fff;">Audio Only (M4A 320k)</option>
        <option value="audio-mp3" style="background:#1a1a1f;color:#fff;">Audio Only (MP3)</option>
      </select>

      <button id="editorlynx-yt-audio-btn" type="button" title="Download Audio (M4A / MP3)" style="
        background:rgba(255,255,255,0.08);
        border:1px solid rgba(255,255,255,0.18);
        color:#ccc;
        border-radius:14px;
        padding:3px 9px;
        font-size:11px;
        font-weight:600;
        cursor:pointer;
        display:flex;
        align-items:center;
        gap:4px;
        transition:all 0.15s ease;
      ">
        <span>🎵 Audio</span>
      </button>

      <button id="editorlynx-yt-add-btn" type="button" title="Add download task to Edit.or.lynx" style="
        background:#0A84FF;
        border:none;
        color:#fff;
        border-radius:14px;
        padding:4px 12px;
        font-size:11.5px;
        font-weight:700;
        cursor:pointer;
        display:flex;
        align-items:center;
        gap:4px;
        box-shadow:0 2px 8px rgba(10,132,255,0.4);
        transition:all 0.15s ease;
      ">
        <span>+ Add Task</span>
      </button>
    `;

    targetContainer.prepend(bar);
    ytBarMounted = true;

    const select = bar.querySelector("#editorlynx-yt-quality");
    const audioBtn = bar.querySelector("#editorlynx-yt-audio-btn");
    const addBtn = bar.querySelector("#editorlynx-yt-add-btn");

    let isAudioMode = false;

    audioBtn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      isAudioMode = !isAudioMode;
      if (isAudioMode) {
        audioBtn.style.background = "#30D158";
        audioBtn.style.color = "#000";
        select.value = "audio-m4a";
      } else {
        audioBtn.style.background = "rgba(255,255,255,0.08)";
        audioBtn.style.color = "#ccc";
        select.value = "1080p";
      }
    });

    select.addEventListener("change", () => {
      if (select.value.startsWith("audio")) {
        isAudioMode = true;
        audioBtn.style.background = "#30D158";
        audioBtn.style.color = "#000";
      } else {
        isAudioMode = false;
        audioBtn.style.background = "rgba(255,255,255,0.08)";
        audioBtn.style.color = "#ccc";
      }
    });

    addBtn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();

      const quality = select.value;
      const audioOnly = isAudioMode || quality.startsWith("audio");
      const videoURL = location.href;
      const title = document.title;

      addBtn.innerHTML = "<span>Adding…</span>";
      addBtn.style.opacity = "0.7";

      chrome.runtime.sendMessage(
        {
          type: "lynk-send",
          url: videoURL,
          title: title,
          quality: quality,
          audioOnly: audioOnly,
          action: "download"
        },
        (reply) => {
          if (reply && reply.ok) {
            addBtn.style.background = "#30D158";
            addBtn.style.color = "#000";
            addBtn.innerHTML = "<span>✓ Added to Notch</span>";
            setTimeout(() => {
              addBtn.style.background = "#0A84FF";
              addBtn.style.color = "#fff";
              addBtn.innerHTML = "<span>+ Add Task</span>";
              addBtn.style.opacity = "1";
            }, 2500);
          } else {
            addBtn.style.background = "#FF453A";
            addBtn.innerHTML = "<span>Open App First</span>";
            setTimeout(() => {
              addBtn.style.background = "#0A84FF";
              addBtn.innerHTML = "<span>+ Add Task</span>";
              addBtn.style.opacity = "1";
            }, 2500);
          }
        }
      );
    });
  }

  // Monitor YouTube navigation (SPA changes)
  if (isYouTube()) {
    window.addEventListener("yt-navigate-finish", () => {
      setTimeout(injectYouTubeControls, 600);
    });
    setInterval(injectYouTubeControls, 1200);
  }

  // ===========================================================================
  // 2. Generic HTML5 Video Downloader Button for Other Sites
  // ===========================================================================

  if (isYouTube()) return;

  const host = document.createElement("div");
  host.style.cssText = "position:fixed;z-index:2147483647;top:0;left:0;width:0;height:0;";
  const shadow = host.attachShadow({ mode: "open" });
  const button = document.createElement("button");
  button.type = "button";
  button.title = "Download with Edit.or.lynx";
  button.setAttribute("aria-label", "Download with Edit.or.lynx");
  button.style.cssText = [
    "position:fixed",
    "display:none",
    "width:32px",
    "height:32px",
    "border-radius:10px",
    "border:0.5px solid rgba(255,255,255,0.2)",
    "background:rgba(20,20,24,0.88)",
    "-webkit-backdrop-filter:blur(14px)",
    "backdrop-filter:blur(14px)",
    "box-shadow:0 4px 16px rgba(0,0,0,0.4)",
    "color:#fff",
    "cursor:pointer",
    "padding:0",
    "align-items:center",
    "justify-content:center",
    "transition:opacity 120ms ease, transform 120ms ease",
    "opacity:0"
  ].join(";");
  button.innerHTML =
    '<svg width="15" height="15" viewBox="0 0 14 14" fill="none" aria-hidden="true">' +
    '<path d="M7 1.5v7.2M7 8.7 4.2 5.9M7 8.7l2.8-2.8M2.2 10.6v1.2c0 .4.3.7.7.7h8.2c.4 0 .7-.3.7-.7v-1.2" ' +
    'stroke="currentColor" stroke-width="1.35" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  shadow.appendChild(button);
  document.documentElement.appendChild(host);

  let target = null;
  let currentUrl = "";

  function plainFile(src) {
    return /^https?:/i.test(src || "") && !/\.m3u8|\.mpd|^blob:/i.test(src);
  }

  function pickVideo() {
    let best = null;
    for (const video of document.querySelectorAll("video")) {
      const src = video.currentSrc || video.src;
      if (!plainFile(src)) continue;
      const box = video.getBoundingClientRect();
      if (box.width < 300 || box.height < 170) continue;
      const rank = (video.paused ? 0 : 1e9) + box.width * box.height;
      if (!best || rank > best.rank) best = { rank, video, src };
    }
    return best;
  }

  function place() {
    const found = pickVideo();
    if (!found) {
      target = null;
      button.style.display = "none";
      return;
    }
    if (target !== found.video || currentUrl !== found.src) {
      target = found.video;
      currentUrl = found.src;
    }
    const box = target.getBoundingClientRect();
    const visible = box.bottom > 8 && box.top < window.innerHeight - 8;
    button.style.display = visible ? "flex" : "none";
    button.style.opacity = visible ? "1" : "0";
    button.style.top = `${Math.round(box.top + 10)}px`;
    button.style.left = `${Math.round(box.right - 42)}px`;
  }

  button.addEventListener("click", (event) => {
    event.preventDefault();
    event.stopPropagation();
    if (!currentUrl) return;
    button.style.transform = "scale(0.92)";
    setTimeout(() => (button.style.transform = "scale(1)"), 120);
    try {
      chrome.runtime.sendMessage(
        { type: "lynk-send", url: currentUrl, title: document.title, action: "download" },
        (reply) => {
          button.title = reply && reply.ok ? "Sent to Edit.or.lynx" : "Edit.or.lynx isn't running";
          setTimeout(() => (button.title = "Download with Edit.or.lynx"), 2200);
        }
      );
    } catch (_) {}
  });

  window.addEventListener("scroll", place, { passive: true, capture: true });
  window.addEventListener("resize", place, { passive: true });
  setInterval(place, 900);
  place();

  // ===========================================================================
  // 3. Global Download Link Interception on Any Website
  // ===========================================================================
  const DOWNLOAD_EXTS = new Set([
    "zip", "dmg", "pkg", "iso", "tar", "gz", "7z", "rar", "bz2", "xz",
    "mp4", "m4v", "mkv", "mov", "avi", "webm", "flv",
    "mp3", "m4a", "flac", "wav", "aac", "ogg", "opus",
    "exe", "msi", "apk", "ipa", "bin",
    "pdf", "epub", "torrent"
  ]);

  function getExt(url) {
    try {
      const pathname = new URL(url, location.href).pathname;
      const clean = pathname.split(/[?#]/)[0];
      const match = clean.match(/\.([a-zA-Z0-9]{2,6})$/);
      return match ? match[1].toLowerCase() : "";
    } catch (_) {
      return "";
    }
  }

  function showNotchToast() {
    const existing = document.getElementById("editorlynx-notch-toast");
    if (existing) existing.remove();

    const toast = document.createElement("div");
    toast.id = "editorlynx-notch-toast";
    toast.style.cssText = [
      "position:fixed",
      "top:12px",
      "left:50%",
      "transform:translateX(-50%)",
      "z-index:2147483647",
      "display:inline-flex",
      "align-items:center",
      "gap:8px",
      "padding:8px 16px",
      "background:rgba(18, 18, 22, 0.94)",
      "border:1px solid rgba(48, 209, 88, 0.4)",
      "border-radius:24px",
      "-webkit-backdrop-filter:blur(18px)",
      "backdrop-filter:blur(18px)",
      "box-shadow:0 8px 32px rgba(0,0,0,0.5)",
      "font-family:-apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif",
      "font-size:12px",
      "font-weight:600",
      "color:#fff"
    ].join(";");

    toast.innerHTML = `
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#30D158" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 2v10M17 7l-5 5-5-5M2 17l.62 2.48A2 2 0 0 0 4.56 21h14.88a2 2 0 0 0 1.94-1.52L22 17"/>
      </svg>
      <span>Asking in Edit.or.lynx Notch</span>
    `;

    document.documentElement.appendChild(toast);
    setTimeout(() => {
      if (toast && toast.parentNode) toast.remove();
    }, 2800);
  }

  document.addEventListener("click", (e) => {
    const anchor = e.target.closest("a");
    if (!anchor || !anchor.href) return;
    const url = anchor.href;
    const isDownload = anchor.hasAttribute("download");
    const ext = getExt(url);

    if (isDownload || DOWNLOAD_EXTS.has(ext)) {
      e.preventDefault();
      e.stopPropagation();
      showNotchToast();
      try {
        chrome.runtime.sendMessage(
          { type: "lynk-send", url, title: anchor.download || anchor.textContent || "", action: "offer" }
        );
      } catch (_) {}
    }
  }, true);
})();
