// Firefox pref overrides, applied at every browser start.
//
// Fingerprinting protection on, with the real timezone. The three prefs came
// over from LibreWolf on 2026-11-07, when the profile moved whole. There they
// turned LibreWolf's resistFingerprinting OFF: that pref spoofs the timezone
// to UTC for every website, and any site that shows times in browser-local
// time then showed them 5 or 6 hours late for US/Central. Acadly showed a
// 2:00 PM class as 7:00 PM. Google Calendar, Canvas, and Zoom had the same
// failure. The granular pref privacy.fingerprintingProtection.overrides does
// not help while resistFingerprinting is on. Tests confirmed that
// resistFingerprinting wins and the timezone stays UTC.
//
// Firefox ships resistFingerprinting off and fingerprintingProtection off
// outside private windows. So here the first line restates a default, and
// the other two add protection: every fingerprinting target except the
// timezone one. That keeps what the LibreWolf setup had.
//
// Measured result of this trade (measured on LibreWolf 152.0, 8-core machine):
//   timezone            Atlantic/Reykjavik -> America/Chicago   (fixed)
//   getTimezoneOffset   0                  -> 300               (fixed)
//   hardwareConcurrency 4                  -> 4     (still spoofed, real 8)
//   navigator.language  en-US              -> en-US (unchanged)
//   userAgent           generic            -> generic (unchanged)
//   screen              1200x600           -> 1200x600 (unchanged)
//
// Only the timezone changed. The other protections stay on.
//
// To check the current state, open about:config and read the three prefs
// below. To see what a website gets, open the browser console and run
// Intl.DateTimeFormat().resolvedOptions().timeZone

user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.fingerprintingProtection.overrides", "+AllTargets,-JSDateTimeUTC");
