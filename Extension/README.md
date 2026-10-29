# Edit.or.lynx browser extensions

Two ready-to-load copies of the same extension. Both send links to the
Edit.or.lynx app on this Mac over its loopback bridge, and both can take over
the downloads the browser starts.

| Folder | Browser |
| --- | --- |
| `chrome/` | Chrome, Chromium, Edge, Brave, Vivaldi, Arc |
| `firefox/` | Firefox |

`shared/` holds the sources. `chrome/` and `firefox/` are assembled from it by
`scripts/build-extensions.sh`, which also renders the icons from the app icon.
Edit the files in `shared/`, then run the script again.

## Install

The app must be running so the extension has something to talk to.

**Chrome and Chromium-based browsers**

1. Open `chrome://extensions`.
2. Turn on **Developer mode**.
3. **Load unpacked** → choose this folder's `chrome/` directory.
4. Pin **Edit.or.lynx Download** to the toolbar if you want the popup one click away.

**Firefox**

1. Open `about:debugging#/runtime/this-firefox`.
2. **Load Temporary Add-on…**
3. Choose `firefox/manifest.json`.

Firefox forgets a temporary add-on when it quits. For a permanent install the
folder has to be signed, or loaded through
[`about:config` → `xpinstall.signatures.required = false`](about:config) in a
Developer Edition build and packed as an `.xpi`:

```bash
cd Extension/firefox && zip -r ../edit-or-lynk-firefox.xpi . -x '.*'
```

## What it does

- **Popup** — shows whether the app is reachable, sends the current page, opens
  the clip editor, or sends a pasted link. The toggle decides whether the
  browser's own downloads are handed to the app.
- **Right-click menu** — *Download Link*, *Download with Edit.or.lynx* on a
  video or audio element, *Download This Page*, and *Make a Clip*.
- **Shortcut** — `⌥⇧D` (Alt+Shift+D) sends the current page.
- **Video button** — a small dark button appears over a plain `<video>` player
  (a direct `.mp4`, not a stream) and sends that file.
- **Download takeover** — when the browser starts a download larger than 500 KB
  that is not an HTML page, the extension cancels the browser's copy and sends
  the URL to the app. If the app doesn't take it, the browser gets the file
  back. Turn this off in the popup if you want the browser to keep its own
  downloads.

## How it talks to the app

A loopback-only HTTP server inside Edit.or.lynx, listening on
`127.0.0.1:47820`:

| Request | Purpose |
| --- | --- |
| `GET /status` | `{ ok, app, version, activeCount }` |
| `GET /jobs` | recent items with `state`, `progress`, `downloadedBytes` |
| `POST /job` | `{ "url": "…", "title": "…", "action": "download" \| "clip" \| "options" }` |
| `OPTIONS *` | CORS preflight |

The server binds to the loopback interface only, answers only localhost
connections, and is reachable only while the app is running. It stores nothing
and needs no token: any local program could POST a link, and the app treats it
exactly like a copied link.

## Limits

- A video page needs `yt-dlp` on the Mac to be saved as a video (`brew install
  yt-dlp ffmpeg`). Without it the app falls back to the page's own media URL, or
  saves the page.
- Streams the browser plays through MSE (`blob:`) can't be sent as a file; the
  extension sends the page instead, and the app resolves it.
- The Firefox copy is MV2 so it installs without a signing setup; everything it
  needs works there.
