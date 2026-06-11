user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Open to the arXiv physics.hist-ph listing — daily-rotating preprints
// in philosophy of physics, which doubles as a research-current morning
// page. Real page content also dodges the Vimium focus race that
// about:blank trips (the URL bar holds focus when there's no page
// content, so `o` lands in the URL bar instead of opening Vimium's
// prompt).
user_pref("browser.startup.page", 1);
user_pref("browser.startup.homepage", "https://arxiv.org/list/physics.hist-ph/recent");

// New tabs land on about:blank (Vimium-enabled) instead of about:newtab,
// which is a privileged page where Vimium can't run. Flow: Ctrl+T →
// blank → `o` to type a URL.
user_pref("browser.newtabpage.enabled", false);

// Use the revamped sidebar with vertical tabs (Firefox 136+). Tabs
// live in #sidebar-main on the side; the top tab strip is empty and
// hidden along with the rest of #navigator-toolbox via Ctrl+;.
//
// sidebar.visibility = "always-show" keeps the tab panel expanded on
// launch. The other values ("hide-sidebar", "expand-on-hover") leave
// only the launcher icon visible until clicked. Width itself is not
// a pref — Firefox persists it in xulstore.json after you drag the
// sidebar edge once.
user_pref("sidebar.revamp", true);
user_pref("sidebar.verticalTabs", true);
user_pref("sidebar.visibility", "always-show");

// On a search-engine results page, show the actual URL in the address
// bar, not a copy of the search query — otherwise the URL bar (when
// revealed via Ctrl+L) just duplicates the query already visible in
// the page's own search box.
user_pref("browser.urlbar.showSearchTerms.enabled", false);

// Stop Firefox from interpreting a middle-click on empty page space
// as "load the URL currently in the X11 primary selection" — a
// surprising legacy behavior that hijacks middle-click from its
// expected role of "open link in new tab" in odd contexts.
user_pref("middlemouse.contentLoadURL", false);

// In F11 fullscreen, don't auto-hide the toolbox. Firefox's built-in
// fullscreen toolbar-hiding overrides our [chrome-hidden] toggle, so
// Ctrl+; can't summon the URL bar back once fullscreen has eaten it.
// Setting this false lets the Ctrl+; toggle remain the single source
// of truth for top-chrome visibility in both windowed and fullscreen.
user_pref("browser.fullscreen.autohide", false);
