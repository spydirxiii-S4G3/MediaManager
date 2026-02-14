# Media File Renamer - User Guide

A Windows desktop app for batch renaming TV show episode files. Point it at a folder of episodes, and it renames them into a clean, consistent format like `Show Name - S01E01 - Episode Title.mp4`.

---

## Getting Started

### First Time Setup

1. **Extract the zip** — Put the `MediaRenamer` folder anywhere you like (Desktop, Documents, etc.). Keep everything inside the folder together — don't move individual files out.

2. **Run the app** — Double-click `Start.bat`. That's it. If Windows asks about permissions, click "Run anyway" — the app only renames files you point it at, nothing else.

3. **If Start.bat doesn't work** — Right-click `Start.bat` and choose "Run as Administrator". If you still get errors, double-click `Debug.bat` instead — it will show you exactly what went wrong in a console window.

4. **If you see a "scripts are disabled" error** — Open PowerShell as Admin and type:
   ```
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
   Then try `Start.bat` again.

---

## How to Rename Files (Step by Step)

### The Basic Workflow

**Step 1: Pick your show folder**

Click the **Browse** button (top right) and navigate to your show's main folder. This should be the folder that contains season subfolders.

Example folder structure:
```
D:\TV Shows\Breaking Bad\          <-- Select THIS folder
    Season 1\
        breaking.bad.s01e01.720p.mkv
        breaking.bad.s01e02.720p.mkv
    Season 2\
        breaking.bad.s02e01.720p.mkv
```

You can also drag and drop a folder from Windows Explorer directly onto the app.

**Step 2: Look at the Season Tree (left panel)**

After you browse to a folder, the left panel shows every subfolder with a count of how many video files are inside. Click on any season to see its files in the grid on the right.

If your files are directly in the folder (no season subfolders), the app will ask you what season number to use.

**Step 3: Check the preview**

When you click a season, the app automatically generates new filenames and shows them in the **New Name** column. Compare the **Original Name** and **New Name** columns to make sure everything looks right.

**Step 4: Click "Rename X Files"**

The green button shows exactly how many files will be renamed. Click it, confirm in the popup (which shows you examples of the changes), and the files get renamed. Done!

**Step 5: Made a mistake?**

Click **Undo** immediately after renaming. It reverses everything back to the original filenames. This only works for the most recent rename — once you close the app or rename something else, the undo history is gone.

---

## Understanding the Screen

### Top Controls (Row by Row)

**Row 1 — Folder**
The path to the show folder you selected. Click Browse to change it.

**Row 2 — Show Name and Season Number**
- **Show** — The name that appears in renamed files. Auto-detected from your folder name. If it gets it wrong, uncheck "From folder" and type the correct name.
- **Season** — The season number (S01, S02, etc.). Auto-detected when you click a season in the tree. Uncheck "Auto-detect" to set it manually.

**Row 3 — Episode Numbering and Sorting**
- **Start Ep** — What episode number to start from. Usually 1, but change it if your files don't start at episode 1.
- **Sort by** — How files are ordered before numbering. "Name" is usually correct. Use "Date Modified" if your files aren't named in order but were downloaded in order.
- **Descending** — Reverses the sort order.
- **Action** — What to do with the files:
  - **Rename** — Changes the filename in place (most common)
  - **Copy** — Makes a renamed copy in a folder you choose, keeps originals
  - **Move** — Renames and moves to a new folder

**Row 4 — File Types and Episode Titles**
- **Extensions** — Which file types to show. Default is `.mp4, .avi, .mkv, .mov`. Add more if needed (like `.ts, .wmv, .flv`).
- **Titles** — Where to get episode titles from:
  - **None** — No titles, just episode numbers
  - **Parse from file** — Tries to extract titles from existing filenames
  - **Manual edit** — You type titles yourself in the grid
  - **TMDB Lookup** — Downloads titles from The Movie Database (free, needs API key)
  - **TVDB Lookup** — Downloads titles from TheTVDB (free, needs API key)
- **Lang** — Language for downloaded titles (only shows when TMDB/TVDB is selected)
- **Fetch Titles** — Click to download episode titles from the selected source

**Row 5 — Filter and Presets**
- **Filter** — Type to instantly search/filter files by name. Useful with 100+ episodes.
- **Preset** — Save or load a group of settings (template, sort order, extensions, etc.) so you don't have to reconfigure for different shows.

**Row 6 — Preview**
Shows a sample of what the first renamed file will look like with current settings.

---

### The Season Tree (Left Panel)

This shows all the subfolders inside your show folder.

- **Click** a season to load its files in the grid
- **Checkboxes** control which seasons are included in batch rename
- **Check the show name** (top node) to select/deselect all seasons at once
- Folders like "Specials", "OVA", "Movies", or any other subfolders will appear here too
- The number after each folder name shows how many video files are inside

**Tip:** You can drag the divider between the tree and the grid to resize the panels.

---

### The File Grid (Right Panel)

Each row is one video file. The columns are:

| Column | What It Shows |
|--------|--------------|
| ☑ | Checkbox — uncheck to skip this file during rename |
| # | Row number |
| Original Name | Current filename |
| New Name | What it will be renamed to (after preview) |
| Episode Title | Episode title (editable — double-click or press F2) |
| Size | File size |
| Duration | Video length (if available) |
| Status | Current state of the file |

**Row Colors:**
- **Blue/highlight** — Will be renamed
- **Green** — Successfully renamed
- **Yellow** — Warning (possible duplicate or skipped)
- **Red** — Error occurred during rename
- **No color** — No change needed (already named correctly)

A color legend bar at the bottom of the grid shows what each color means.

**Right-click menu:**
- Edit Episode Title — Change the title for this episode
- Exclude/Include — Toggle whether this file gets renamed
- Move Up/Move Down — Change the order (affects episode numbering)

---

### Button Bar

| Button | What It Does |
|--------|-------------|
| **Preview** | Generates new filenames and shows them in the grid. No files are changed. |
| **Rename X Files** | Actually renames the files. Shows a confirmation first with examples. The number updates to show exactly how many files will change. |
| **Test Run** | Same as Preview but also shows a summary popup. Good for double-checking before you commit. No files are changed. |
| **Undo** | Reverses the last rename operation. Only available right after renaming. |
| **Export Log** | Saves a record of all renames to a .txt or .csv file. |
| **Reset** | Clears everything and goes back to the start screen. |
| **Refresh** | Rescans the current season folder for changes. Hold **Shift + click** to rescan ALL seasons. |
| **Dark/Light** | Switches between dark and light theme. |

**Note:** Buttons are grayed out when they can't do anything yet. For example, "Rename" is gray until you've previewed changes, and "Undo" is gray until you've renamed something.

---

## Settings Tab

### Naming Template

This controls the format of renamed files. The default is:
```
{show} - S{season}E{episode}
```
Which produces filenames like: `Breaking Bad - S01E01.mkv`

**Available variables:**

| Variable | What It Becomes | Example |
|----------|----------------|---------|
| `{show}` | Show name | Breaking Bad |
| `{season}` | Season number (zero-padded) | 01 |
| `{episode}` | Episode number (zero-padded) | 05 |
| `{ep_range}` | Episode range for multi-part | E05-E06 |
| `{title}` | Episode title (if available) | Pilot |
| `{total}` | Total number of episodes | 13 |
| `{original}` | Original filename (without extension) | breaking.bad.s01e01 |
| `{ext}` | File extension | .mkv |

**Common templates:**
```
{show} - S{season}E{episode}                    -> Breaking Bad - S01E01.mkv
{show} - S{season}E{episode} - {title}          -> Breaking Bad - S01E01 - Pilot.mkv
S{season}E{episode} - {show}                    -> S01E01 - Breaking Bad.mkv
{show} S{season}E{episode}                      -> Breaking Bad S01E01.mkv
```

Click **Save Template** to keep your template between sessions.

### API Keys

To download episode titles automatically, you need a free API key from one of these services:

**TMDB (The Movie Database) — Recommended:**
1. Go to https://www.themoviedb.org/ and create a free account
2. Go to Settings → API → Request an API Key
3. Copy the "API Key" (not the "API Read Access Token")
4. Paste it into the TMDB API Key field
5. Click **Save API Keys**

**TVDB (TheTVDB):**
1. Go to https://thetvdb.com/ and create a free account
2. Go to API Access under your account
3. Generate an API key
4. Paste it into the TVDB API Key field
5. Click **Save API Keys**

You only need one — TMDB is recommended because it's easier to set up and has good coverage.

### General

- **Preset folder** — Where your saved presets are stored. Leave blank to use the default location (inside the MediaRenamer folder).

### Help Button

Click **Open User Guide** at the bottom to open this document.

---

## Common Tasks

### "I have one season of files to rename"

1. Click Browse → select the season folder (or the show folder containing it)
2. Check that Show name and Season number are correct
3. Look at the New Name column — does it look right?
4. Click the green "Rename X Files" button
5. Confirm in the popup → Done!

### "I have an entire show with multiple seasons"

1. Click Browse → select the show's root folder
2. All seasons appear in the tree on the left
3. Check the boxes next to every season you want to rename (or check the show name to select all)
4. Click one season at a time to verify the preview looks good
5. Click "Rename X Files" — it will process all checked seasons automatically

### "I want episode titles in the filenames"

1. Go to the **Settings** tab
2. Change the template to include `{title}`:
   ```
   {show} - S{season}E{episode} - {title}
   ```
3. Click **Save Template**
4. Go back to the **Rename** tab
5. Select **TMDB Lookup** (or TVDB) from the Titles dropdown
6. Pick your language
7. Click **Fetch Titles**
8. Episode titles appear in the grid — check they look right
9. Rename as normal

### "Some episode titles are wrong or missing"

- **Double-click** the Episode Title cell in the grid to edit it directly
- Or press **F2** with a row selected
- Or right-click → Edit Episode Title
- Your edits are kept even if you switch seasons and come back

### "I accidentally renamed something wrong"

Click **Undo** immediately. This only works for the very last rename operation. If you've already closed the app, you'll need to rename them back manually.

### "The episode order is wrong"

The app numbers episodes based on the sort order. Try:
- Change **Sort by** to "Date Modified" or "Date Created"
- Check/uncheck **Descending**
- Right-click files in the grid and use **Move Up** / **Move Down** to adjust individual files

### "I want to rename files but keep the originals"

Change **Action** from "Rename" to "Copy". This creates renamed copies in a folder you choose and leaves the originals untouched.

### "I have files in the root folder, not in season subfolders"

That's fine — the app will detect them and ask what season number to use.

### "Some of my files shouldn't be renamed"

Uncheck the checkbox (☑) in the first column for any file you want to skip. Or click the checkbox in the column header to select/deselect all files at once.

### "I want to see what would happen without actually renaming"

Click **Test Run**. It shows you a full summary of what would change without touching any files.

---

## Troubleshooting

**"The app won't start"**
- Make sure you extracted the full zip — all files need to be in the same folder
- Try `Debug.bat` to see the actual error message
- Run the `Set-ExecutionPolicy` command mentioned in First Time Setup

**"My files aren't showing up"**
- Check the **Extensions** field — your file types need to be listed there
- Make sure you browsed to the right folder
- Click **Refresh** to rescan

**"The show name is wrong"**
- Uncheck "From folder" next to the Show field
- Type the correct name

**"Episode titles from TMDB/TVDB are in the wrong language"**
- Change the **Lang** dropdown before clicking Fetch Titles

**"The season number is wrong"**
- Uncheck "Auto-detect" next to the Season field
- Set it manually with the up/down arrows

**"Some files got renamed wrong"**
- Click **Undo** immediately to reverse the rename
- Check your sort order and start episode number
- Use **Test Run** before renaming to verify

**"I need a log of what was renamed"**
- Click **Export Log** after renaming
- Choose .txt for a human-readable log or .csv for a spreadsheet

---

## Tips & Tricks

- **Hover over any control** to see a tooltip explaining what it does
- **Drag and drop** a folder from Windows Explorer onto the app to load it
- **Settings are saved automatically** when you close the app (window position, theme, API keys, template, last folder)
- **Presets** let you save different configurations for different shows or naming styles
- **Shift + Refresh** rescans all seasons at once (normal Refresh only rescans the current one)
- The **filter box** is great when you have hundreds of episodes and need to find specific ones
- Files that are already named correctly show "No Change" and won't be touched

---

## File Structure
```
MediaRenamer/
    Start.bat            Double-click this to run the app
    Debug.bat            Use this if Start.bat has problems
    Launch.ps1           App loader (don't edit)
    MainForm.ps1         Main interface (don't edit)
    README.md            This file
    settings.json        Your saved settings (auto-created)
    Presets/              Your saved presets (auto-created)
    Modules/              App code (don't edit)
```

---

*Media File Renamer is a portable app — no installation needed. Just extract, run, and rename.*
