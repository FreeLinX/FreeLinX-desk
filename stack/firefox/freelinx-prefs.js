// FreeLinX defaults for Firefox ESR.
// Rendering: Mesa (iris/crocus/nouveau/r600/virgl) provides GL where the GPU
// has a driver; Firefox's own glxtest picks WebRender on the GPU there and
// falls back to software WebRender everywhere else, so nothing is forced.
// There is no VA-API stack, so video decoding stays on the CPU.
pref("media.hardware-video-decoding.enabled", false);
pref("media.ffmpeg.vaapi.enabled", false);
pref("webgl.disabled", false);
// No system integration FreeLinX does not ship.
pref("browser.shell.checkDefaultBrowser", false);
pref("app.update.enabled", false);
// Privacy: no telemetry or studies from a distribution build.
pref("datareporting.healthreport.uploadEnabled", false);
pref("datareporting.policy.dataSubmissionEnabled", false);
pref("toolkit.telemetry.enabled", false);
pref("toolkit.telemetry.unified", false);
pref("app.shield.optoutstudies.enabled", false);
pref("browser.discovery.enabled", false);
// Sensible first run.
pref("browser.aboutwelcome.enabled", false);
pref("intl.locale.requested", "");
