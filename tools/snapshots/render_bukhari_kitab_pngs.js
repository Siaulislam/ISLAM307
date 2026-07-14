#!/usr/bin/env node
/**
 * Render full-page PNG snapshots for a Bukhari kitab HTML folder.
 * Usage: node tools/snapshots/render_bukhari_kitab_pngs.js bukhari-wudu
 */
const fs = require("fs");
const path = require("path");
const puppeteer = require("/tmp/snap-tools/node_modules/puppeteer");

const ROOT = path.resolve(__dirname, "../..");
const slug = process.argv[2];
if (!slug) {
  console.error("Usage: node render_bukhari_kitab_pngs.js <slug>");
  process.exit(1);
}
const OUT = path.join(ROOT, "preview/snapshots", slug);
const HTML_DIR = path.join(OUT, "html");
const PNG_DIR = path.join(OUT, "png");

async function main() {
  fs.mkdirSync(PNG_DIR, { recursive: true });
  const files = fs
    .readdirSync(HTML_DIR)
    .filter((f) => f.endsWith(".html"))
    .sort();
  const browser = await puppeteer.launch({
    headless: true,
    executablePath: "/usr/bin/google-chrome-stable",
    args: ["--no-sandbox", "--disable-setuid-sandbox", "--font-render-hinting=none"],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1080, height: 900, deviceScaleFactor: 2 });

  for (const file of files) {
    const htmlPath = path.join(HTML_DIR, file);
    const pngPath = path.join(PNG_DIR, file.replace(/\.html$/, ".png"));
    await page.goto("file://" + htmlPath, { waitUntil: "networkidle0", timeout: 60000 });
    await page.evaluateHandle("document.fonts.ready");
    await new Promise((r) => setTimeout(r, 150));
    const el = await page.$("#shot");
    if (!el) throw new Error("missing #shot in " + file);
    await el.screenshot({ path: pngPath, type: "png" });
    console.log("png", path.basename(pngPath));
  }
  await browser.close();
  console.log(`Done ${files.length} PNGs → ${PNG_DIR}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
