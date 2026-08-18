// LibreWolf pref overrides, applied at every browser start.
//
// Why this file exists: LibreWolf sets privacy.resistFingerprinting to true in
// /usr/lib/librewolf/librewolf.cfg. That pref spoofs the timezone to UTC for
// every website. Any site that shows times in browser-local time then shows
// them 5 or 6 hours late for US/Central. Acadly showed a 2:00 PM class as
// 7:00 PM. Google Calendar, Canvas, and Zoom have the same failure.
//
// The granular pref privacy.fingerprintingProtection.overrides does not help
// while resistFingerprinting is on. Tests confirm that resistFingerprinting
// wins and the timezone stays UTC. So this file turns resistFingerprinting off
// and turns on fingerprintingProtection with every target except the timezone
// one.
//
// Measured result of this trade (LibreWolf 152.0, 8-core machine):
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
