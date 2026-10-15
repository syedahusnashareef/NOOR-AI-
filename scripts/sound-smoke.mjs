import { chromium } from "playwright";

const siteUrl = process.env.SITE_URL;
if (!siteUrl) throw new Error("SITE_URL is required");

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
const consoleErrors = [];
page.on("console", message => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", error => consoleErrors.push(error.message));

try {
  const response = await page.goto(siteUrl, { waitUntil: "domcontentloaded", timeout: 60000 });
  if (!response || !response.ok()) throw new Error(`Live page HTTP status: ${response?.status() ?? "no response"}`);

  await page.waitForSelector("#noorSoundQuickControl", { state: "visible", timeout: 20000 });
  await page.waitForFunction(() => !!window.NOOR_SOUND?.playSound, { timeout: 20000 });

  // The first genuine user gesture unlocks browser audio.
  await page.locator("#noorSoundQuickTest").click();
  await page.waitForFunction(() => {
    const statuses = window.NOOR_SOUND?.getAssetStatuses?.();
    return statuses && Object.keys(statuses).length > 0 &&
      Object.values(statuses).every(item => item.state === "loaded");
  }, { timeout: 30000 });

  const diagnostics = await page.evaluate(() => {
    const api = window.NOOR_SOUND;
    const statuses = api.getAssetStatuses();
    const names = api.getMappedSoundNames();
    const results = names.map(name => ({ name, resolves: api.playSound(name, { force: true, noVoice: true }) }));
    const failedAssets = Object.entries(statuses)
      .filter(([, item]) => item.state !== "loaded")
      .map(([key, item]) => ({ key, ...item }));
    return {
      title: document.title,
      buttonVisible: !!document.querySelector("#noorSoundQuickControl") &&
        getComputedStyle(document.querySelector("#noorSoundQuickControl")).display !== "none",
      mappedSoundCount: names.length,
      assetCount: Object.keys(statuses).length,
      failedAssets,
      failedNames: results.filter(item => !item.resolves).map(item => item.name),
      soundMap: names
    };
  });

  if (!diagnostics.buttonVisible) throw new Error("Sound quick-control is not visible on the deployed page");
  if (diagnostics.mappedSoundCount !== 40) throw new Error(`Expected 40 mapped sounds, got ${diagnostics.mappedSoundCount}`);
  if (diagnostics.failedAssets.length) throw new Error(`Audio assets not loaded: ${JSON.stringify(diagnostics.failedAssets)}`);
  if (diagnostics.failedNames.length) throw new Error(`playSound failed for: ${diagnostics.failedNames.join(", ")}`);

  const muteResult = await page.evaluate(() => {
    const api = window.NOOR_SOUND;
    api.setPreferences({ masterSound: false });
    return {
      preference: api.getPreferences().masterSound,
      soundPlayed: api.playSound("ding", { noVoice: true })
    };
  });
  if (muteResult.preference !== false || muteResult.soundPlayed !== false) {
    throw new Error("Mute check failed");
  }

  await page.reload({ waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForFunction(() => !!window.NOOR_SOUND?.getPreferences, { timeout: 20000 });
  const persisted = await page.evaluate(() => window.NOOR_SOUND.getPreferences().masterSound);
  if (persisted !== false) throw new Error("Sound preference did not persist after refresh");

  // Restore default ON in this test context before final checks.
  await page.evaluate(() => window.NOOR_SOUND.setPreferences({ masterSound: true }));
  if (consoleErrors.length) throw new Error(`Browser console errors: ${consoleErrors.join(" | ")}`);

  console.log(JSON.stringify({
    result: "PASS",
    liveUrl: siteUrl,
    title: diagnostics.title,
    buttonVisible: diagnostics.buttonVisible,
    mappedSoundCount: diagnostics.mappedSoundCount,
    audioAssetsLoaded: diagnostics.assetCount,
    everyMappedSoundResolves: true,
    muteWorks: true,
    preferencePersistsAfterRefresh: true,
    consoleErrors: consoleErrors.length
  }, null, 2));
} finally {
  await browser.close();
}
