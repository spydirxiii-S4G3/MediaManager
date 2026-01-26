# Series Movies Detection & Organization Guide

## Overview
PlexAnimeTools now fully supports detecting and organizing movies that are part of TV series according to **Plex naming standards**.

According to Plex standards, movies/specials that belong to a series should go in **Season 00** (Specials folder).

---

## Detected Movie Patterns

### 1. **Root-Level Movie Files**
Files in the series root folder with movie indicators in the name:

**Examples:**
```
Demon Slayer/
  Demon Slayer - Mugen Train (Movie).mkv          ✅ Detected
  Demon Slayer Movie: Mugen Train.mkv             ✅ Detected  
  Demon Slayer Film - Mugen Train.mkv             ✅ Detected
  Demon Slayer - Season 01/                       (episodes)
  Demon Slayer - Season 02/                       (episodes)
```

**Keywords Detected:**
- `movie`
- `movies`
- `film`
- `films`
- `theatrical`
- `ova` (when standalone)
- `special` (when standalone)

---

### 2. **Movie Folders**
Folders named with movie indicators:

**Examples:**
```
Naruto/
  Season 01/                                       (episodes)
  Season 02/                                       (episodes)
  Movie/                                           ✅ Detected
    Naruto Movie - Road to Ninja.mkv
  Movies/                                          ✅ Detected
    Naruto Movie 1.mkv
    Naruto Movie 2.mkv
```

**Folder Names Detected:**
- `Movie`
- `Movies`
- `Film`
- `Films`
- Any folder with "Movie" or "Film" in the name

---

### 3. **Named Movie Folders**
Folders with specific movie titles:

**Examples:**
```
One Piece/
  Season 01/                                       (episodes)
  Stampede/                                        ✅ Detected (movie title)
    One Piece Stampede.mkv
  Film Gold/                                       ✅ Detected (movie title)
    One Piece Film Gold.mkv
```

**Detection Logic:**
- Folder doesn't match season pattern (`Season ##`, `S##`)
- Contains 1-3 video files (typical for movies + extras)
- Not a season folder

---

## Output Format (Plex Standard)

All detected movies are renamed and placed in **Season 00**:

### Format:
```
Show Title - S00E## - Movie Name.ext
```

Where:
- `S00` = Season 00 (Specials/Movies)
- `E##` = Movie number (01, 02, 03...)
- Movie names are extracted from filenames or folder names

### Examples:

**Input:**
```
Demon Slayer/
  Demon Slayer - Mugen Train (Movie).mkv
  Season 01/
    episodes...
```

**Output:**
```
Demon Slayer/
  Season 00/
    Demon Slayer - S00E01 - Mugen Train.mkv  ✅
  Season 01/
    episodes...
```

---

**Input:**
```
Naruto/
  Movies/
    Naruto Movie - Road to Ninja.mkv
    Naruto Movie - Blood Prison.mkv
  Season 01/
    episodes...
```

**Output:**
```
Naruto/
  Season 00/
    Naruto - S00E01 - Road to Ninja.mkv     ✅
    Naruto - S00E02 - Blood Prison.mkv      ✅
  Season 01/
    episodes...
```

---

## Usage Examples

### 1. Analyze Structure (See What's Detected)

```powershell
# Get folder structure info
$structure = Get-FolderStructureType -FolderPath "D:\Anime\Demon Slayer"

# Check for movies
if ($structure.Movies.Count -gt 0) {
    Write-Host "Found $($structure.Movies.Count) movie(s):"
    foreach ($movie in $structure.Movies) {
        Write-Host "  - Type: $($movie.Type)"
        Write-Host "    Path: $($movie.Path)"
        Write-Host "    Folder: $($movie.Folder)"
    }
}
```

**Output:**
```
Found 1 movie(s):
  - Type: RootMovie
    Path: D:\Anime\Demon Slayer\Demon Slayer - Mugen Train (Movie).mkv
    Folder: 
```

---

### 2. Get Series Movie Information

```powershell
# Get detailed movie info
$movies = Get-SeriesMovieInfo -FolderPath "D:\Anime\Demon Slayer"

foreach ($movie in $movies) {
    Write-Host "Movie Name: $($movie.MovieName)"
    Write-Host "Source: $($movie.SourceName)"
    Write-Host "Type: $($movie.Type)"
}
```

**Output:**
```
Movie Name: Mugen Train
Source: Demon Slayer - Mugen Train (Movie).mkv
Type: RootMovie
```

---

### 3. Format Movie Name (Plex Standard)

```powershell
# Generate Plex-compliant name
$name = Format-SeriesMovieName -ShowTitle "Demon Slayer" `
                                -MovieName "Mugen Train" `
                                -Extension ".mkv" `
                                -MovieNumber 1

Write-Host $name
```

**Output:**
```
Demon Slayer - S00E01 - Mugen Train.mkv
```

---

### 4. Convert Structure (Organize Movies)

```powershell
# Preview conversion
ConvertTo-StandardPlexStructure -SourcePath "D:\Downloads\Demon Slayer" `
                                 -DestinationPath "D:\Plex\Anime" `
                                 -WhatIf
```

**Output:**
```
Converting structure type: PrefixedSeasons
Source: D:\Downloads\Demon Slayer
Destination: D:\Plex\Anime\Demon Slayer
Found 1 series movie(s)
Series movie: Mugen Train -> Season 00 E01

=== WHATIF: Planned Operations ===
[WHATIF] SeriesMovie: D:\Downloads\Demon Slayer\Mugen Train (Movie).mkv 
                   -> D:\Plex\Anime\Demon Slayer\Season 00\Demon Slayer - S00E01 - Mugen Train.mkv
[WHATIF] RenameAndMove: D:\Downloads\Demon Slayer\Demon Slayer Season 01 
                     -> D:\Plex\Anime\Demon Slayer\Season 01
```

---

## Complex Examples

### Example 1: Multiple Movies + Multiple Seasons

**Input Structure:**
```
One Piece/
  One Piece Season 01/
    episodes...
  One Piece Season 02/
    episodes...
  Movies/
    One Piece Film Z.mkv
    One Piece Film Gold.mkv
  Stampede/
    One Piece Stampede.mkv
```

**After Conversion:**
```
One Piece/
  Season 00/
    One Piece - S00E01 - Film Z.mkv
    One Piece - S00E02 - Film Gold.mkv
    One Piece - S00E03 - Stampede.mkv
  Season 01/
    episodes...
  Season 02/
    episodes...
```

---

### Example 2: Mixed Root Files

**Input Structure:**
```
Naruto/
  Naruto - 01.mkv
  Naruto - 02.mkv
  Naruto Movie - Road to Ninja.mkv
  Naruto - 03.mkv
```

**Detection:**
- Episodes: `Naruto - 01.mkv`, `Naruto - 02.mkv`, `Naruto - 03.mkv`
- Movies: `Naruto Movie - Road to Ninja.mkv` (has "Movie" keyword)

**After Conversion:**
```
Naruto/
  Season 00/
    Naruto - S00E01 - Road to Ninja.mkv
  Season 01/
    Naruto - S01E01.mkv
    Naruto - S01E02.mkv
    Naruto - S01E03.mkv
```

---

### Example 3: Movie Folder with Multiple Files

**Input Structure:**
```
Attack on Titan/
  Season 01/
    episodes...
  Movie/
    Attack on Titan - Chronicle (Movie) [1080p].mkv
    Attack on Titan - Chronicle (Movie) [720p].mkv
```

**After Conversion:**
```
Attack on Titan/
  Season 00/
    Attack on Titan - S00E01 - Chronicle [1080p].mkv
    Attack on Titan - S00E02 - Chronicle [720p].mkv
  Season 01/
    episodes...
```

---

## Test Plex Compatibility

The updated `Test-PlexScan` function now detects movies:

```powershell
$result = Test-PlexScan -Path "D:\Plex\Anime\Demon Slayer" -Detailed
```

**Output:**
```
Testing: D:\Plex\Anime\Demon Slayer
  [OK] Poster found
  [OK] Found 2 season folder(s) - Pattern: Season ##
  [OK] Found 1 series movie(s) in Season 00
  [OK] All files properly named (25/25)
  [PASS] PASSED (100% - Excellent)

Structure Type: StandardPlex
Pattern: Season ##
Movies Detected: 1
```

---

## Movie Detection Criteria

### What Gets Detected as a Movie:

✅ **File in root with keywords:**
- Contains: `movie`, `film`, `theatrical`, `ova`, `special`
- Example: `Show - Movie Name (Movie).mkv`

✅ **Folder named with keywords:**
- Matches: `Movie`, `Movies`, `Film`, `Films`
- Contains: `movie` or `film` anywhere in name

✅ **Non-season folder with few files:**
- Doesn't match season patterns
- Contains 1-3 video files
- Example: `Mugen Train/` folder with 1 movie file

### What Does NOT Get Detected:

❌ Regular episode files (without movie keywords)
❌ Season folders (`Season 01`, `S01`, etc.)
❌ Folders with many files (>3 videos = likely episodes)

---

## Plex Naming Reference

According to **Plex naming standards**:

### TV Series Structure:
```
Show Name/
  Season 01/
    Show Name - S01E01 - Episode Title.ext
    Show Name - S01E02 - Episode Title.ext
  Season 02/
    Show Name - S02E01 - Episode Title.ext
```

### Series Movies (Specials):
```
Show Name/
  Season 00/
    Show Name - S00E01 - Movie Title.ext
    Show Name - S00E02 - OVA Title.ext
    Show Name - S00E03 - Special Title.ext
```

**Note:** Season 00 is for:
- Movies related to the series
- OVAs (Original Video Animations)
- Specials
- Pilots
- Extras

---

## Functions Reference

### Get-FolderStructureType
Analyzes folder and detects movies automatically.

**Returns:**
- `Movies` array with all detected movies
- `SpecialsFolder` if "Season 00" or "Specials" exists

### Get-SeriesMovieInfo
Gets detailed information about movies in a series.

**Returns array of:**
```powershell
@{
    Type = 'RootMovie' or 'FolderMovie'
    SourcePath = Full path to video file
    MovieName = Extracted movie name
    Extension = File extension
}
```

### Format-SeriesMovieName
Formats movie name according to Plex S00E## standard.

**Parameters:**
- `ShowTitle` - Series name
- `MovieName` - Movie title
- `Extension` - File extension (.mkv, .mp4, etc.)
- `MovieNumber` - Movie sequence number (1, 2, 3...)

**Returns:**
- Plex-formatted filename: `Show - S00E01 - Movie.ext`

### ConvertTo-StandardPlexStructure
Converts any structure to Plex standard, handling movies automatically.

**Features:**
- Detects all movies
- Places them in Season 00
- Renames with S00E## format
- Preserves movie names from filenames/folders

---

## Best Practices

1. **Always preview first:**
   ```powershell
   ConvertTo-StandardPlexStructure -SourcePath "..." -DestinationPath "..." -WhatIf
   ```

2. **Use descriptive movie filenames:**
   - Good: `Demon Slayer - Mugen Train (Movie).mkv`
   - Good: `Naruto Movie - Road to Ninja.mkv`
   - Bad: `Movie1.mkv` (generic name)

3. **Organize movies in folders:**
   ```
   Show Name/
     Movies/          ← Good: Clear organization
       Movie1.mkv
       Movie2.mkv
   ```

4. **Use Season 00 for all specials:**
   - Movies
   - OVAs
   - Specials
   - Pilots

5. **Test before mass conversion:**
   ```powershell
   # Test one show first
   $result = Test-PlexScan -Path "D:\Plex\Anime\Show Name" -Detailed
   
   # Check score
   if ($result.Score -ge 90) {
       Write-Host "Excellent! Ready for Plex" -ForegroundColor Green
   }
   ```

---

## Troubleshooting

### Movies Not Detected?

**Check filename:**
```powershell
# Must contain movie keywords
"Demon Slayer - Mugen Train (Movie).mkv"  ✅
"Demon Slayer - Mugen Train.mkv"          ❌ (no keyword)
```

**Add keyword:**
- Add `(Movie)` to filename
- Or place in folder named `Movie` or `Movies`

---

### Movies Going to Wrong Season?

Movies should ALWAYS go to Season 00, not Season 01+.

**Verify detection:**
```powershell
$structure = Get-FolderStructureType -FolderPath "path"
$structure.Movies  # Should show detected movies
```

---

### Multiple Movies Numbered Wrong?

Movies are numbered in the order they're found:
1. Root-level movie files (alphabetical)
2. Movie folder contents (alphabetical)

**To control order:**
- Rename files: `Movie 1 - Name.mkv`, `Movie 2 - Name.mkv`
- Or use separate folders

---

## Summary

✅ **Detects movies** in root files, movie folders, and named folders
✅ **Places in Season 00** (Plex standard for specials/movies)
✅ **Formats correctly** as `Show - S00E## - Movie Name.ext`
✅ **Handles multiple movies** with sequential numbering
✅ **Preserves movie names** from filenames and folder names
✅ **Works with all structure types** (prefixed, flat, standard, etc.)

Your anime series movies will now be perfectly organized for Plex! 🎬
