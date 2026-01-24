# =============================================================================
# Module Manifest for PlexAnimeTools
# Generated: 2024
# =============================================================================

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'PlexAnimeTools.psm1'
    
    # Version number of this module
    ModuleVersion = '2.0.0'
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Author of this module
    Author = 'Plex Anime Tools Team'
    
    # Company or vendor of this module
    CompanyName = 'Community'
    
    # Copyright statement for this module
    Copyright = '(c) 2024. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Complete Plex media organization tool with Jikan/TMDb API integration, automatic content detection, episode renaming, and artwork download for anime, TV shows, cartoons, and movies.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @(
        'System.Windows.Forms',
        'System.Drawing',
        'System.Web'
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-AnimeOrganize',
        'Test-PlexScan',
        'Get-AnimeInfo',
        'Start-PlexGUI'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @(
                'Plex',
                'Anime',
                'Media',
                'Organization',
                'Renaming',
                'TMDb',
                'Jikan',
                'MyAnimeList',
                'Automation',
                'GUI'
            )
            
            # A URL to the license for this module
            LicenseUri = 'https://github.com/yourname/PlexAnimeTools/blob/main/LICENSE'
            
            # A URL to the main website for this project
            ProjectUri = 'https://github.com/yourname/PlexAnimeTools'
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
v2.0.0 - Complete Rewrite
- Professional PowerShell module structure
- Multiple configuration profiles
- CLI and GUI modes
- TMDb and Jikan API integration
- Automatic content type detection
- Episode title fetching
- Artwork download
- Multi-season support
- WhatIf support for safe previews
- Comprehensive error logging
- Pipeline support
- Plex-compatible naming
'@
        }
    }
}
