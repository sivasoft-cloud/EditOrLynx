import os
import asyncio
from playwright.async_api import async_playwright

HTML_PATH = "file://" + os.path.abspath("/Users/sivasoft/Downloads/temp/lynk/motion/index.html")
OUT_DIR = "/Users/sivasoft/Downloads/temp/lynk/motion/beat_frames"

os.makedirs(f"{OUT_DIR}/dark", exist_ok=True)
os.makedirs(f"{OUT_DIR}/light", exist_ok=True)

async def capture_beats(theme: str):
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--no-sandbox", "--disable-setuid-sandbox"])
        page = await browser.new_page(viewport={"width": 1440, "height": 1440}, device_scale_factor=1)
        url = f"{HTML_PATH}?theme={theme}"
        await page.goto(url)
        # Hide HUD for clean render
        await page.evaluate("document.getElementById('hud-overlay').style.display = 'none';")
        await page.wait_for_timeout(500) # Font settle

        print(f"--- Capturing 28 beat frames for {theme.upper()} mode ---")
        for beat in range(28):
            t = beat * 0.500
            await page.evaluate(f"window.seek({t});")
            out_file = f"{OUT_DIR}/{theme}/beat_{beat:02d}_{t:.2f}s.png"
            await page.screenshot(path=out_file)
            print(f"Beat {beat+1:02d}/28 ({t:5.2f}s): {out_file}")

        await browser.close()

async def main():
    await capture_beats("dark")
    await capture_beats("light")
    print("All beat frames successfully rendered!")

if __name__ == "__main__":
    asyncio.run(main())
