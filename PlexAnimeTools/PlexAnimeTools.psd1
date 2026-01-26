@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PlexAnimeTools.psm1'

    # Version number of this module.
    ModuleVersion = '2.2.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'PlexAnimeTools'

    # Company or vendor of this module
    CompanyName = 'PlexAnimeTools'

    # Copyright statement for this module
    Copyright = '(c) 2024 PlexAnimeTools. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Automated media organization for Plex Media Server with anime, TV series, and movie support. Now with ABSOLUTE EPISODE NUMBERING support for long-running series like One Piece!'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Get-AnimeInfo',
        'Invoke-AnimeOrganize',
        'Start-PlexGUI',
        'Start-SmartOrganize',
        'Start-TestingGUI',
        'Test-PlexScan'
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
            Tags = @('Plex', 'Anime', 'Media', 'Organization', 'Automation', 'AbsoluteNumbering', 'OnePiece', 'Naruto')

            # A URL to the license for this module.
            LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Version 2.2.0 - Added absolute episode numbering support for long-running series (One Piece, Naruto, etc.). Automatically maps absolute episode numbers to correct seasons via online database.'
        }
    }
}