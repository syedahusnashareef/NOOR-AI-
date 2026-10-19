import {chromium} from 'playwright';

(async()=>{const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1440,height:1100}});let errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(new URL('preview/principal-dashboard-preview.html',process.env.SITE_URL||'http://127.0.0.1:8060/').href);await page.waitForSelector('.pd-subject-bar');await page.waitForTimeout(400);
const assert=(v,m)=>{if(!v)throw Error(m)};
assert(await page.locator('.pd-subject-bar').count()===5,'subjects');
await page.click('#pd-notices');assert(await page.locator('#pd-drawer').evaluate(e=>e.classList.contains('open')),'drawer');await page.keyboard.press('Escape');
await page.click('#pd-theme');await page.waitForTimeout(100);assert(await page.locator('#noor-principal').evaluate(e=>e.classList.contains('pd-dark')),'dark persists');await page.click('#pd-theme');
await page.click('#pd-range');assert(await page.locator('.pd-bar').count()===4,'monthly data');await page.click('#pd-range');
await page.click('#pd-notices');await page.check('[data-done="Tasks0"]');await page.click('#pd-close');await page.reload();await page.click('#pd-notices');assert(await page.isChecked('[data-done="Tasks0"]'),'done persists');await page.click('#pd-close');
await page.screenshot({path:'/tmp/noor-desktop.png',fullPage:true});
await page.setViewportSize({width:390,height:844});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=390),'mobile overflow');await page.screenshot({path:'/tmp/noor-mobile.png',fullPage:true});
await page.evaluate(()=>{window.NOOR_AI_APP.profile.role='student';window.NOOR_PRINCIPAL_STUDIO.render()});assert(await page.locator('#noor-principal').count()===0,'role guard');
assert(errors.length===0,errors.join('\n'));console.log('PASS: charts, drawer, theme, range data, saved task state, 390px layout, role guard; no JS errors');await browser.close()})();
