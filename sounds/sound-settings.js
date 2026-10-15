/* Sound & Feel controls; uses only the central window.NOOR_SOUND API. */
(() => {
  "use strict";
  const esc = value => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  function markup() {
    const cats = window.NOOR_SOUND_MAP?.categories || [];
    return `
      <section class="panel sound-feel-panel" id="soundFeelPanel" aria-labelledby="soundFeelTitle">
        <div class="sound-feel-head">
          <div><div class="eyebrow">Personal experience</div><h2 id="soundFeelTitle">Sound &amp; Feel</h2>
          <p>Soft, warm feedback for learning. Your choices belong to your account and apply across NOOR AI panels.</p></div>
          <span class="sound-sync-pill" data-sound-sync-status role="status">Loading sound preferences…</span>
        </div>
        <div class="sound-master-row">
          <div class="sound-control-copy"><b>Master sound</b><small>Switch every app sound off instantly, without changing your other preferences.</small></div>
          <label class="sound-switch" aria-label="Master Sound ON/OFF"><input type="checkbox" id="soundMasterToggle"><span></span></label>
        </div>
        <div class="sound-volume-row">
          <div class="sound-control-copy"><b>Volume</b><small>Gentle maximum: 50% of device output</small></div>
          <div class="sound-volume-control"><input id="soundVolumeSlider" type="range" min="0" max="0.5" step="0.01" aria-label="Sound volume"><output id="soundVolumeValue" for="soundVolumeSlider">32%</output></div>
        </div>
        <div class="sound-toggle-grid">
          <div class="sound-minor-row"><div class="sound-control-copy"><b>Voice cheers</b><small>Short cheers only for badges, results and milestones.</small></div><label class="sound-switch" aria-label="Voice Cheers ON/OFF"><input type="checkbox" id="soundVoiceToggle"><span></span></label></div>
          <div class="sound-minor-row"><div class="sound-control-copy"><b>Haptic feedback</b><small>Very short vibration on key actions, if your device supports it.</small></div><label class="sound-switch" aria-label="Haptic ON/OFF"><input type="checkbox" id="soundHapticToggle"><span></span></label></div>
        </div>
        <div class="sound-preview-head"><div><h3>Sound categories</h3><p>Preview each family. Preview buttons never play more than one sound at a time.</p></div></div>
        <div class="sound-category-grid">
          ${cats.map(cat => `<article class="sound-category-card"><div class="sound-category-icon" aria-hidden="true">${({interaction:"✧",navigation:"↗",learning:"✎",assessment:"✓",achievement:"✦",messages:"◇",voice:"♫",haptics:"⌁"})[cat.id] || "♫"}</div><div class="sound-category-copy"><b>${esc(cat.title)}</b><small>${esc(cat.description)}</small></div><button type="button" class="btn soft sound-preview-btn" data-sound-preview="${esc(cat.preview)}">Preview</button></article>`).join("")}
        </div>
        <p class="sound-note">Sounds stay muted if Master Sound is OFF. Browser or device audio restrictions are handled quietly; the rest of the workspace continues normally.</p>
      </section>`;
  }
  function mount(root) {
    if (!root || root.dataset.mounted === "true") return;
    root.innerHTML = markup();
    root.dataset.mounted = "true";
    const master = root.querySelector("#soundMasterToggle");
    const volume = root.querySelector("#soundVolumeSlider");
    const volumeLabel = root.querySelector("#soundVolumeValue");
    const voice = root.querySelector("#soundVoiceToggle");
    const haptic = root.querySelector("#soundHapticToggle");
    const syncStatus = root.querySelector("[data-sound-sync-status]");
    const manager = () => window.NOOR_SOUND;
    const reflect = values => {
      if (!values) return;
      if (document.activeElement !== master) master.checked = values.masterSound;
      if (document.activeElement !== volume) volume.value = String(values.volume);
      volumeLabel.value = Math.round(values.volume * 100) + "%";
      volumeLabel.textContent = volumeLabel.value;
      if (document.activeElement !== voice) voice.checked = values.voiceCheers;
      if (document.activeElement !== haptic) haptic.checked = values.haptics;
      const status = manager()?.getStatus?.() || {};
      syncStatus.textContent = status.sync === "connected" ? "Account sync ready" : "Saved on this device";
      syncStatus.classList.toggle("is-local", status.sync !== "connected");
    };
    reflect(manager()?.getPreferences?.() || {});
    master.addEventListener("change", () => manager()?.setPreferences({ masterSound: master.checked }));
    volume.addEventListener("input", () => {
      const value = Math.min(0.5, Math.max(0, Number(volume.value) || 0));
      volumeLabel.value = Math.round(value * 100) + "%";
      volumeLabel.textContent = volumeLabel.value;
      manager()?.setVolume(value);
    });
    voice.addEventListener("change", () => manager()?.setPreferences({ voiceCheers: voice.checked }));
    haptic.addEventListener("change", () => manager()?.setPreferences({ haptics: haptic.checked }));
    root.querySelectorAll("[data-sound-preview]").forEach(button => button.addEventListener("click", () => {
      const key = button.dataset.soundPreview;
      if (key === "voice") {
        if (!manager()?.getPreferences?.().masterSound) return;
        manager()?.previewVoice?.();
      } else if (key === "haptic" || key === "haptics") {
        manager()?.vibrate?.([12, 22, 12]);
        if (manager()?.getPreferences?.().masterSound) manager()?.playSound?.("bubble-pop");
      } else {
        manager()?.playSound?.(key);
      }
    }));
    manager()?.onPreferencesChange?.(reflect);
  }
  function mountQuickControl() {
    if (document.getElementById("noorSoundQuickControl")) return;
    const style = document.createElement("style");
    style.id = "noorSoundQuickControlStyle";
    style.textContent = `
      #noorSoundQuickControl{position:fixed;right:16px;bottom:16px;z-index:9999;display:flex;gap:7px;align-items:center;padding:7px;background:rgba(48,25,38,.96);border:1px solid #d6b174;border-radius:999px;box-shadow:0 8px 28px #24101d35;backdrop-filter:blur(12px)}
      #noorSoundQuickControl button{border:1px solid #ffffff28;border-radius:999px;padding:10px 13px;background:#ffffff12;color:#fff8f5;font:700 12px/1.1 system-ui,sans-serif;cursor:pointer;white-space:nowrap}
      #noorSoundQuickControl button:focus-visible{outline:2px solid #f0d39f;outline-offset:2px}
      #noorSoundQuickControl #noorSoundQuickTest{background:#f0d39f;color:#321323;border-color:#f0d39f}
      @media(max-width:480px){#noorSoundQuickControl{right:10px;bottom:10px;padding:5px;gap:5px}#noorSoundQuickControl button{padding:10px 11px;font-size:11px}}
    `;
    document.head.appendChild(style);
    const wrap = document.createElement("div");
    wrap.id = "noorSoundQuickControl";
    wrap.setAttribute("aria-label", "NOOR AI sound controls");
    wrap.innerHTML = '<button type="button" id="noorSoundQuickToggle" aria-pressed="true">🔊 Sound ON</button><button type="button" id="noorSoundQuickTest">Test sound</button>';
    document.body.appendChild(wrap);
    const toggle = wrap.querySelector("#noorSoundQuickToggle");
    const test = wrap.querySelector("#noorSoundQuickTest");
    const api = () => window.NOOR_SOUND;
    const reflectQuick = values => {
      const enabled = values?.masterSound !== false;
      toggle.textContent = enabled ? "🔊 Sound ON" : "🔇 Sound OFF";
      toggle.setAttribute("aria-pressed", String(enabled));
    };
    reflectQuick(api()?.getPreferences?.() || {masterSound:true});
    toggle.addEventListener("click", () => {
      const current = api()?.getPreferences?.() || {masterSound:true};
      const next = !current.masterSound;
      api()?.setPreferences?.({masterSound:next});
      if (next) api()?.playSound?.("soft-chime", {force:true,noVoice:true});
    });
    test.addEventListener("click", () => {
      const current = api()?.getPreferences?.() || {masterSound:true};
      if (!current.masterSound) api()?.setPreferences?.({masterSound:true});
      api()?.playSound?.("ding", {force:true,noVoice:true});
    });
    api()?.onPreferencesChange?.(reflectQuick);
    window.addEventListener("noor:sound-preferences", event => reflectQuick(event.detail));
  }
  window.NOOR_SOUND_SETTINGS = { markup, mount, mountQuickControl };
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mountQuickControl, {once:true});
  } else {
    mountQuickControl();
  }
})();