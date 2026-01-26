# Smart Organize - Universal Media Processor

## The "Just Works" System 🎯

Drop **ANY** media content into PlexAnimeTools and it automatically:
- ✅ Figures out what it is
- ✅ Finds the correct show/movie
- ✅ Detects episodes and seasons
- ✅ Creates proper Plex structure
- ✅ Renames everything correctly
- ✅ Downloads artwork
- ✅ Handles movies in series (Season 00)

---

## Usage - It's This Simple:

```powershell
Start-SmartOrganize -InputPath "ANYTHING" -OutputPath "D:\Plex\Anime"
```

That's it. Seriously.

---

## What Can You Throw At It?

### ✅ Single File
```powershell
Start-SmartOrganize -InputPath "D:\Downloads\[SubsPlease] Attack on Titan - 15.mkv" `
                     -OutputPath "D:\Plex\Anime"
```

**It will:**
1. Extract show name: "Attack on Titan"
2. Detect episode: 15
3. Search Jikan API
4. Create: `D:\Plex\Anime\Attack on Titan\Season 01\Attack on Titan - S01E15.mkv`

---

### ✅ Messy Folder
```powershell
Start-SmartOrganize -InputPath "D:\Downloads\Messy Anime Stuff" `
                     -OutputPath "D:\Plex\Anime"
```

**Input:**
```
Messy Anime Stuff/
  [SubsPlease] One Punch Man - 01.mkv
  [SubsPlease] One Punch Man - 02.mkv
  Demon Slayer - Mugen Train (Movie).mkv
  some random file.txt
  Naruto Ep 1.mkv
  Naruto Ep 2.mkv
```

**It will:**
1. Group files by show name
2. Detect episodes
3. Separate movies from episodes
4. Create proper structure for each

**Output:**
```
D:\Plex\Anime\
  One Punch Man\
    Season 01\
      One Punch Man - S01E01.mkv
      One Punch Man - S01E02.mkv
  Demon Slayer\
    Season 00\
      Demon Slayer - S00E01 - Mugen Train.mkv
  Naruto\
    Season 01\
      Naruto - S01E01.mkv
      Naruto - S01E02.mkv
```

---

### ✅ Organized Folder
```powershell
Start-SmartOrganize -InputPath "D:\Downloads\One Punch Man Season 01" `
                     -OutputPath "D:\Plex\Anime"
```

**Input:**
```
One Punch Man Season 01/
  [SubsPlease] One Punch Man - 01.mkv
  [SubsPlease] One Punch Man - 02.mkv
  [SubsPlease] One Punch Man - 03.mkv
```

**It will:**
1. Detect it's a single season
2. Search for show
3. Organize properly

**Output:**
```
D:\Plex\Anime\
  One Punch Man\
    Season 01\
      One Punch Man - S01E01.mkv
      One Punch Man - S01E02.mkv
      One Punch Man - S01E03.mkv
```

---

### ✅ Multiple Shows
```powershell
Start-SmartOrganize -InputPath "D:\Downloads\Anime Batch" `
                     -OutputPath "D:\Plex\Anime"
```

**Input:**
```
Anime Batch/
  Attack on Titan/
    episodes...
  Demon Slayer/
    episodes...
  Naruto/
    episodes...
```

**It will:**
Process each show separately and organize all of them.

---

### ✅ Existing Plex Structure (Needs Fixing)
```powershell
Start-SmartOrganize -InputPath "I:\Anime\One Punch Man" `
                     -OutputPath "D:\Plex\Anime"
```

**Input:**
```
One Punch Man/
  One Punch Man Season 00/
    movies...
  One Punch Man Season 01/
    episodes...
  One Punch Man Season 02/
    episodes...
```

**It will:**
1. Detect prefixed season structure
2. Convert to standard Plex format
3. Rename episodes
4. Move movies to Season 00

**Output:**
```
D:\Plex\Anime\
  One Punch Man\
    Season 00\
      One Punch Man - S00E01 - Movie Name.mkv
    Season 01\
      One Punch Man - S01E01 - Episode Title.mkv
    Season 02\
      One Punch Man - S02E01 - Episode Title.mkv
```

---

### ✅ Complex Nested Mess
```powershell
Start-SmartOrganize -InputPath "D:\Anime\Random Stuff" `
                     -OutputPath "D:\Plex\Anime"
```

**Input:**
```
Random Stuff/
  Folder1/
    Subfolder/
      [Group] Show1 - 01.mkv
      [Group] Show1 - 02.mkv
  Folder2/
    [Group] Show2 - 01.mkv
  root file 1.mkv
  root file 2.mkv
  More/
    Nested/
      Stuff/
        file.mkv
```

**It will:**
1. Scan everything recursively
2. Group files by show name
3. Process each group
4. Create proper structure

---

## Features

### 🔍 Intelligent Detection
- **Show Names**: Extracts from any naming convention
- **Episode Numbers**: Finds them anywhere in filename
- **Season Numbers**: Detects from folder/file names
- **Content Type**: Auto-detects anime vs TV vs movie
- **Movies in Series**: Identifies movies and places in Season 00

### 🎯 Name Extraction
Handles all these patterns:
```
[SubsPlease] Show Name - 01.mkv
Show Name S01E01.mkv
Show Name - Episode 01.mkv
Show.Name.01.mkv
Show Name Ep 1.mkv
[Group] Show Name - 001.mkv
Show Name (2023) - 01.mkv
```

### 🧹 Tag Removal
Automatically strips:
- Release group tags: `[SubsPlease]`, `[HorribleSubs]`, etc.
- Quality markers: `1080p`, `720p`, `x264`, `HEVC`
- Encoding info: `AAC`, `AC3`, `FLAC`
- Container info: `BD`, `BluRay`, `WEB-DL`

### 📊 Structure Detection
Handles:
- Flat: All files in one folder
- Organized: Season folders already exist
- Prefixed: "Show Name Season 01" format
- Mixed: Files and folders together
- Nested: Deep folder structures

### 🎬 Movie Handling
Automatically detects movies and places in Season 00:
- Files with "Movie" in name
- Folders named "Movie" or "Movies"
- Named movie folders (e.g., "Mugen Train")

---

## Advanced Examples

### Example 1: Download Folder Cleanup
```powershell
# Process entire download folder
Start-SmartOrganize -InputPath "D:\Downloads" `
                     -OutputPath "D:\Plex\Anime"
```

Handles whatever's in there - single files, folders, mixed content, everything.

---

### Example 2: Preview Before Processing
```powershell
# See what will happen
Start-SmartOrganize -InputPath "D:\Downloads\Messy Folder" `
                     -OutputPath "D:\Plex\Anime" `
                     -WhatIf
```

Shows you exactly what it will do before doing it.

---

### Example 3: Batch Process Multiple Sources
```powershell
# Process multiple input locations
$sources = @(
    "D:\Downloads\Anime"
    "D:\Downloads\TV Shows"
    "D:\Torrents\Complete"
    "E:\Backup\Media"
)

foreach ($source in $sources) {
    Start-SmartOrganize -InputPath $source -OutputPath "D:\Plex\Anime"
}
```

---

### Example 4: Fix Existing Library
```powershell
# Fix badly organized existing library
Start-SmartOrganize -InputPath "I:\OldAnimeLibrary" `
                     -OutputPath "D:\Plex\Anime"
```

Reorganizes everything to proper Plex standards.

---

## How It Works (Behind the Scenes)

### Step 1: Analysis
```
Input: ANY path
↓
Analyze: What is this?
  - Single file?
  - Single show folder?
  - Multiple shows?
  - Mixed files + folders?
  - Complex nested mess?
↓
Strategy: Choose processing method
```

### Step 2: Grouping (if needed)
```
For messy/mixed content:
  - Group files by show name
  - Separate movies from episodes
  - Identify seasons
```

### Step 3: API Lookup
```
For each show:
  - Search Jikan (anime) or TMDb (TV/movies)
  - Get correct title
  - Get episode names (if available)
  - Get artwork
```

### Step 4: Organization
```
For each file:
  - Determine final location
  - Generate Plex-compliant name
  - Create folder structure
  - Move/rename file
  - Download artwork
```

### Step 5: Verification
```
- Check for errors
- Log all actions
- Report results
- Provide Plex scan suggestions
```

---

## File Naming Intelligence

### Episode Number Detection
Finds episode numbers in these patterns:
```
Show - 01.mkv           → Episode 1
Show - E01.mkv          → Episode 1
Show S01E01.mkv         → Season 1, Episode 1
Show - Episode 1.mkv    → Episode 1
Show Ep1.mkv            → Episode 1
Show [01].mkv           → Episode 1
Show_001.mkv            → Episode 1
```

### Season Number Detection
```
Show Season 1/          → Season 1
Show S01/               → Season 1
Show - Season 01/       → Season 1
Show.S01.E01.mkv        → Season 1
```

### Movie Detection
```
Show - Movie.mkv            → Movie
Show (Movie).mkv            → Movie
Show Film.mkv               → Movie
Show Theatrical.mkv         → Movie
Movies/Show Movie 1.mkv     → Movie
```

---

## Error Handling

Smart Organize handles errors gracefully:

### No API Results Found
```
Show: "Random Show XYZ"
→ Searches Jikan
→ No results
→ Searches TMDb
→ Still no results
→ Logs warning
→ Skips file
→ Continues processing others
```

### Malformed Filenames
```
File: "asdfghjkl.mkv"
→ Can't extract show name
→ Uses parent folder name
→ Still processes
```

### Missing Episode Numbers
```
File: "Show Name.mkv"
→ No episode number found
→ Assumes Episode 1
→ Logs warning
→ Processes anyway
```

### Duplicate Files
```
Destination already exists
→ Logs warning
→ Skips file
→ Continues processing
```

---

## Configuration

Uses your existing PlexAnimeTools config:
- API keys (TMDb, MAL)
- Naming formats
- Video extensions
- Search settings
- Rate limits

```powershell
# Uses default config
Start-SmartOrganize -InputPath "..." -OutputPath "..."

# Or specify different profile
$env:PLEXANIMETOOLS_PROFILE = "plex-strict"
Start-SmartOrganize -InputPath "..." -OutputPath "..."
```

---

## Output Examples

### Success Output
```
========================================
Smart Organize - Universal Media Processor
========================================
Input: D:\Downloads\Anime
Output: D:\Plex\Anime

Step 1: Analyzing input...
Input Type: MultipleShows
Content Type: Mixed
Items Found: 3

Processing show folder: Attack on Titan
Found 12 episode(s)
API: Found Attack on Titan (MAL ID: 16498)
Created: D:\Plex\Anime\Attack on Titan\Season 01
Renamed: 12 file(s)

Processing show folder: Demon Slayer
Found 26 episode(s) + 1 movie
API: Found Demon Slayer (MAL ID: 38000)
Created: D:\Plex\Anime\Demon Slayer\Season 01
Created: D:\Plex\Anime\Demon Slayer\Season 00
Renamed: 27 file(s)

Processing show folder: One Punch Man
Found 12 episode(s)
API: Found One Punch Man (MAL ID: 30276)
Created: D:\Plex\Anime\One Punch Man\Season 01
Renamed: 12 file(s)

========================================
Processing Complete
Success: 51 | Failed: 0 | Skipped: 0
========================================
```

---

## Tips & Best Practices

### 1. Always Preview First
```powershell
Start-SmartOrganize -InputPath "..." -OutputPath "..." -WhatIf
```

### 2. Process in Batches
Don't try to process 10,000 files at once. Break it up:
```powershell
# Process A-M
Start-SmartOrganize -InputPath "D:\Anime\A-M" -OutputPath "D:\Plex\Anime"

# Process N-Z
Start-SmartOrganize -InputPath "D:\Anime\N-Z" -OutputPath "D:\Plex\Anime"
```

### 3. Check Logs
```powershell
Show-LatestLog -Type Main
Show-LatestLog -Type Processing
```

### 4. Verify with Plex Scan
```powershell
Test-PlexScan -Path "D:\Plex\Anime\Show Name" -Detailed
```

### 5. Use Descriptive Filenames
The more info in the filename, the better:
- Good: `[SubsPlease] Attack on Titan - Season 4 - 15 [1080p].mkv`
- Okay: `Attack on Titan - 15.mkv`
- Bad: `file.mkv`

---

## Comparison: Old vs New Way

### Old Way (Manual):
```powershell
# 1. Analyze structure manually
Get-FolderStructureType -FolderPath "..."

# 2. Decide what to do
if (structure is X) {
    do Y
} elseif (structure is Z) {
    do A
}

# 3. Search API manually
Search-JikanAPI -Query "..."

# 4. Process files manually
Invoke-AnimeOrganize -Path "..." -OutputPath "..."

# 5. Handle movies separately
Get-SeriesMovieInfo -FolderPath "..."
Format-SeriesMovieName ...

# 6. Fix structure issues
ConvertTo-StandardPlexStructure ...

# Takes 10+ commands
```

### New Way (Smart):
```powershell
Start-SmartOrganize -InputPath "ANYTHING" -OutputPath "D:\Plex\Anime"

# Done. One command.
```

---

## Limitations

### Won't Process:
- ❌ Non-video files (txt, jpg, etc.)
- ❌ Corrupt video files
- ❌ Files with DRM/encryption

### May Have Trouble With:
- ⚠️ Extremely generic filenames (`1.mkv`, `video.mkv`)
- ⚠️ Shows with very similar names
- ⚠️ Content not in Jikan or TMDb databases

### Solutions:
- Rename generic files to include show name
- Use `-Force` parameter to process despite warnings
- Add show to database first, then process
- Use manual `Invoke-AnimeOrganize` for edge cases

---

## Summary

**One command. Any input. Plex-ready output.**

```powershell
Start-SmartOrganize -InputPath "ANYTHING" -OutputPath "D:\Plex\Anime"
```

That's the goal. That's what it does.

### What It Handles:
✅ Single files
✅ Single shows
✅ Multiple shows
✅ Mixed content
✅ Nested structures
✅ Any naming convention
✅ Movies in series
✅ Existing Plex structures needing fixing
✅ Complete chaos

### What You Get:
✅ Proper Plex folder structure
✅ S##E## naming
✅ Season folders
✅ Movies in Season 00
✅ Downloaded artwork
✅ Comprehensive logs
✅ Error handling

**Drop it in, let it work, import to Plex. Done.** 🎉
