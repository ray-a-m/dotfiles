// /usr/lib/firefox/defaults/pref/autoconfig.js
//
// Bootstraps Firefox's autoconfig mechanism. Points the chrome runtime
// at /usr/lib/firefox/firefox.cfg, where the chrome-toggle JS lives.
//
// Stable assumptions: the autoconfig API is part of Firefox's
// enterprise-deployment toolkit and has been API-stable since the late
// 2000s. Sandbox=false is required so firefox.cfg can use
// Components.utils.import.
//
// This file gets wiped whenever pacman upgrades the `firefox` package
// (everything under /usr/lib/firefox/ is package-managed). The pacman
// hook at /etc/pacman.d/hooks/firefox-userchrome.hook redeploys it
// automatically after each upgrade. install.sh deploys it on first run.
pref("general.config.filename", "firefox.cfg");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);
