import os
import sys
import shutil
import asyncio
import subprocess
from playwright.async_api import async_playwright

HTML_PATH = "file://" + os.path.abspath("/Users/sivasoft/Downloads/temp/lynk/motion/index.html")
AUDIO_PATH = "/Users/sivasoft/Downloads/temp/lynk/motion/track_120bpm.wav"
OUT_DIR = "/Users/sivasoft/Downloads/temp/lynk/motion"

TOTAL_DURATION = 14.0
TARGET_FPS = 60
SUBFRAME_FACTOR = 4  # 4 subframes per target frame
SAMPLE_FPS = TARGET_FPS * SUBFRAME_FACTOR  # 240 fps
TOTAL_SUBFRAMES = int(TOTAL_DURATION * SAMPLE_FPS)  # 3360 frames
NUM_WORKERS = 6

async def worker_render(worker_id: int, theme: str, start_frame: int, end_frame: int, frames_dir: str):
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--no-sandbox", "--disable-setuid-sandbox"])
        page = await browser.new_page(viewport={"width": 1440, "height": 1440}, device_scale_factor=1)
        url = f"{HTML_PATH}?theme={theme}"
        await page.goto(url)
        await page.evaluate("document.getElementById('hud-overlay').style.display = 'none';")
        await page.wait_for_timeout(300)

        for frame_idx in range(start_frame, end_frame):
            t = frame_idx / SAMPLE_FPS
            await page.evaluate(f"window.seek({t});")
            out_png = os.path.join(frames_dir, f"frame_{frame_idx:05d}.png")
            await page.screenshot(path=out_png)
            if frame_idx % 120 == 0:
                print(f"[Worker {worker_id}] Frame {frame_idx}/{TOTAL_SUBFRAMES} ({t:.2f}s)")

        await browser.close()

async def render_theme_video(theme: str):
    frames_dir = f"/tmp/motion_subframes_{theme}"
    if os.path.exists(frames_dir):
        shutil.rmtree(frames_dir)
    os.makedirs(frames_dir, exist_ok=True)

    print(f"\n========================================================")
    print(f"RENDERING 60FPS MOTION VIDEO WITH 4x SUBFRAME BLUR ({theme.upper()})")
    print(f"Duration: {TOTAL_DURATION}s | Subframes: {TOTAL_SUBFRAMES} at {SAMPLE_FPS} fps")
    print(f"========================================================")

    frames_per_worker = TOTAL_SUBFRAMES // NUM_WORKERS
    tasks = []

    for w in range(NUM_WORKERS):
        start = w * frames_per_worker
        end = TOTAL_SUBFRAMES if w == NUM_WORKERS - 1 else (w + 1) * frames_per_worker
        tasks.append(worker_render(w, theme, start, end, frames_dir))

    await asyncio.gather(*tasks)
    print(f"All {TOTAL_SUBFRAMES} subframes captured for {theme}!")

    # Run ffmpeg to tmix 4 frames and encode 60fps video with 120 BPM audio
    out_mp4 = os.path.join(OUT_DIR, f"motion_{theme}_60fps.mp4")
    print(f"\n==> Encoding {out_mp4} with ffmpeg tmix filter...")

    ffmpeg_cmd = [
        "ffmpeg", "-y",
        "-r", str(SAMPLE_FPS),
        "-i", f"{frames_dir}/frame_%05d.png",
        "-i", AUDIO_PATH,
        "-filter_complex", f"[0:v]tmix=frames={SUBFRAME_FACTOR}:weights='1 1 1 1',fps={TARGET_FPS}[v]",
        "-map", "[v]",
        "-map", "1:a",
        "-c:v", "libx264",
        "-preset", "medium",
        "-crf", "17",
        "-pix_fmt", "yuv420p",
        "-c:a", "aac",
        "-b:a", "320k",
        "-shortest",
        out_mp4
    ]

    res = subprocess.run(ffmpeg_cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print("FFmpeg error:", res.stderr)
        raise RuntimeError("FFmpeg encode failed")

    print(f"==> Successfully generated {out_mp4} ({os.path.getsize(out_mp4) / 1024 / 1024:.2f} MB)")
    shutil.rmtree(frames_dir)

async def main():
    theme = sys.argv[1] if len(sys.argv) > 1 else "dark"
    await render_theme_video(theme)

if __name__ == "__main__":
    asyncio.run(main())
