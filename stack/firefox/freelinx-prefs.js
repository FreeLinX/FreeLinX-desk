// FreeLinX defaults for Firefox ESR.
// Rendering: Mesa (iris/crocus/radeonsi/nouveau/r600/virgl, llvmpipe as the
// CPU fallback) provides GL; Firefox's own glxtest picks WebRender on the GPU
// and software WebRender elsewhere, so nothing is forced.
// Video: VA-API through libva (Intel: intel-media-driver / i965, AMD and
// NVIDIA: Mesa).  Firefox probes it per GPU and decodes on the CPU when the
// driver cannot do a codec.
pref("media.hardware-video-decoding.enabled", true);
pref("media.ffmpeg.vaapi.enabled", true);
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
