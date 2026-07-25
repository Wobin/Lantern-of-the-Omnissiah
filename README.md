# Lantern of the Omnissiah

Import and export Gameslantern builds from inside Darktide.

## Import
Copy a Gameslantern build URL to your clipboard, then run `/lantern` in-game (or use the import UI) to apply it to the current preset.

## Export
Run `/lantern_export` in-game (or click the export button on the loadout screen) to copy your current build to the clipboard, then click your saved **Gameslantern Export bookmarklet** in a browser tab where you are logged in to gameslantern.com. The bookmarklet creates the build in your own session and opens the resulting page.

### Installing the export bookmarklet (once)
The bookmarklet is a `javascript:` snippet. It must be saved **as a bookmark** — you cannot paste it into the address bar.

> If you paste it into the address bar, your browser strips the `javascript:` part for security and sends the rest to your search engine, which returns *"Search query entered was too long."* That is the browser, not the mod.

1. Run `/lantern_export_bookmarklet` in-game — this copies the bookmarklet code to your clipboard. (It is also saved at `tools/export_bookmarklet.js`.)
2. In your browser, create a new bookmark: right-click the bookmarks bar → **Add page…** (or bookmark any page, then **Edit** it).
3. Name it something like `GL Export`. In the **URL / Address** field, delete whatever is there and **paste the bookmarklet code**. Pasting into the bookmark editor is safe — only the address bar strips it. Save.

### Using it
1. In-game, run `/lantern_export` or click the export button to copy your build.
2. Open a gameslantern.com tab where you are logged in.
3. Click your `GL Export` bookmark. It POSTs the build in your session and opens the new build page.
