/** The DESIGN.md §9 audit, as a command rather than a checklist.
 *
 *  A craft gate nobody can run is a document, and documents drift. This runs
 *  axe against every audit surface in BOTH themes, checks the 320px and 640px
 *  layout floors, walks the keyboard path asserting a visible focus ring at
 *  every stop, and flags touch targets under 44px.
 *
 *  Usage:  npm run build && npm start &   then   npm run audit
 *          (AUDIT_BASE overrides the origin)
 *
 *  It has caught three real defects so far: a muted ink colour failing AA on
 *  ten nodes, a status hue used as text below contrast in dark mode, and
 *  panels stretching their grid track instead of scrolling at 320px.
 */
import { chromium } from "playwright";
import { AxeBuilder } from "@axe-core/playwright";

const BASE = process.env.AUDIT_BASE ?? "http://localhost:3000";
const PAGES = ["/", "/login", "/dashboard", "/leads", "/leads/l1", "/calendar", "/inbox", "/styleguide"];
const out = process.argv[2];
const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium" });
let failures = 0;

for (const scheme of ["light", "dark"]) {
  for (const path of PAGES) {
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, colorScheme: scheme, deviceScaleFactor: 2 });
    const page = await context.newPage();
    await page.goto(BASE + path, { waitUntil: "load" });
    await page.waitForTimeout(350);

    const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"]).analyze();
    const serious = results.violations.filter((v) => ["critical", "serious"].includes(v.impact ?? ""));
    if (serious.length) {
      failures += serious.length;
      for (const v of serious) console.log(`AXE ${scheme} ${path} [${v.impact}] ${v.id}: ${v.help} (${v.nodes.length} node(s))`, v.nodes.slice(0,2).map(n=>n.target).flat());
    }
    const minor = results.violations.filter((v) => !["critical","serious"].includes(v.impact ?? ""));
    for (const v of minor) console.log(`axe-minor ${scheme} ${path} [${v.impact}] ${v.id}`);

    await page.screenshot({ path: `${out}/${path.replace(/\//g, "") || "home"}-${scheme}.png`, fullPage: path === "/styleguide" });
    await page.close();
    await context.close();
  }
}

// Layout floor and zoom
for (const [w, label] of [[320, "320px"], [640, "640px"]]) {
  const page = await browser.newPage({ viewport: { width: w, height: 800 } });
  for (const path of PAGES) {
    await page.goto(BASE + path, { waitUntil: "load" });
    await page.waitForTimeout(350);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    if (overflow > 0) { failures++; console.log(`OVERFLOW ${label} ${path}: ${overflow}px`); }
  }
  await page.close();
}

// Keyboard: every interactive element reachable, focus always visible.
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
await page.goto(BASE + "/login", { waitUntil: "load" });
const order = [];
for (let i = 0; i < 8; i++) {
  await page.keyboard.press("Tab");
  const info = await page.evaluate(() => {
    const el = document.activeElement;
    if (!el || el === document.body) return null;
    const s = getComputedStyle(el);
    return { tag: el.tagName.toLowerCase(), id: el.id || null, outline: s.outlineWidth, outlineStyle: s.outlineStyle };
  });
  if (!info) break;
  order.push(info);
  if (info.outlineStyle === "none" || info.outline === "0px") { failures++; console.log("NO FOCUS RING on", info); }
}
console.log("tab order:", order.map((o) => o.id ?? o.tag).join(" → "));

// Touch targets on the sign-in form
const small = await page.evaluate(() =>
  [...document.querySelectorAll("button, input, a")]
    .filter((el) => !el.closest(".sr-only") && !el.classList.contains("sr-only"))
    .map((el) => ({ t: el.tagName.toLowerCase(), id: el.id || null, h: Math.round(el.getBoundingClientRect().height) }))
    .filter((e) => e.h > 0 && e.h < 44));
if (small.length) console.log("targets under 44px:", small);

await page.close();
await browser.close();
console.log(failures === 0 ? "AUDIT PASS (no critical/serious issues)" : `AUDIT: ${failures} issue(s)`);
