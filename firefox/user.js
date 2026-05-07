user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Open to DuckDuckGo on startup so Vimium runs from the first page.
user_pref("browser.startup.page", 1);
user_pref("browser.startup.homepage", "https://duckduckgo.com");

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
