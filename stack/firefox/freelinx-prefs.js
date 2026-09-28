// FreeLinX defaults for Firefox ESR.
// The desktop runs on a software framebuffer (fbdev / KMS dumb buffers, no GL),
// so rendering stays on the CPU path and nothing probes for GPU drivers.
pref("gfx.webrender.software", true);
pref("gfx.webrender.all", false);
pref("layers.acceleration.disabled", true);
pref("media.hardware-video-decoding.enabled", false);
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
