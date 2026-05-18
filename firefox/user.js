user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Open to a local start.html that grabs focus on load so Vimium attaches
// immediately. about:blank by itself doesn't work — Firefox leaves the URL
// bar focused on launch (nothing on the page to focus), so `o` lands in
// the URL bar instead of triggering Vimium's open prompt. The HTML page
// calls document.body.focus() in `load` + a 100ms setTimeout to pull focus
// onto the page across Firefox's startup focus race.
user_pref("browser.startup.page", 1);
user_pref("browser.startup.homepage", "file:///home/raymond/code/dotfiles/firefox/start.html");

// New tabs land on about:blank (Vimium-enabled) instead of about:newtab
// (privileged, Vimium can't run). With the tab strip hidden, this means
// Ctrl+T → blank → `o` to type a URL.
user_pref("browser.newtabpage.enabled", false);

// Disable the new vertical-icon sidebar (bookmarks/history/synced tabs).
// CSS in userChrome.css also collapses it as backup.
user_pref("sidebar.revamp", false);

// On a search-engine results page, show the actual URL in the address
// bar, not a copy of the search query — otherwise the URL bar (when
// revealed via Ctrl+L) just duplicates the query already visible in
// the page's own search box.
user_pref("browser.urlbar.showSearchTerms.enabled", false);
