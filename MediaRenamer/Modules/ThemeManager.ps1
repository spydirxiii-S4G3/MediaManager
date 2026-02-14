# ===============================================================================
# ThemeManager.ps1 - Dark / Light Mode with Windows System Theme Detection
# ===============================================================================

$script:CurrentTheme = "Light"

$script:Themes = @{
    Dark = @{
        FormBack        = [System.Drawing.Color]::FromArgb(30, 30, 30)
        FormFore        = [System.Drawing.Color]::FromArgb(230, 230, 230)
        ControlBack     = [System.Drawing.Color]::FromArgb(45, 45, 45)
        ControlFore     = [System.Drawing.Color]::FromArgb(230, 230, 230)
        ListBack        = [System.Drawing.Color]::FromArgb(37, 37, 37)
        ListFore        = [System.Drawing.Color]::FromArgb(220, 220, 220)
        GroupBoxFore    = [System.Drawing.Color]::FromArgb(180, 180, 180)
        ButtonPrimary   = [System.Drawing.Color]::FromArgb(0, 103, 192)
        ButtonSuccess   = [System.Drawing.Color]::FromArgb(16, 110, 16)
        ButtonNeutral   = [System.Drawing.Color]::FromArgb(80, 80, 80)
        ButtonFore      = [System.Drawing.Color]::White
        AccentColor     = [System.Drawing.Color]::FromArgb(0, 120, 212)
        RowAlt          = [System.Drawing.Color]::FromArgb(42, 42, 42)
        RowHighlight    = [System.Drawing.Color]::FromArgb(50, 70, 50)
        RowWarning      = [System.Drawing.Color]::FromArgb(70, 60, 30)
        RowError        = [System.Drawing.Color]::FromArgb(70, 35, 35)
        RowSuccess      = [System.Drawing.Color]::FromArgb(35, 65, 35)
        StatusBack      = [System.Drawing.Color]::FromArgb(25, 25, 25)
        StatusFore      = [System.Drawing.Color]::FromArgb(180, 180, 180)
        TabBack         = [System.Drawing.Color]::FromArgb(40, 40, 40)
        BorderColor     = [System.Drawing.Color]::FromArgb(60, 60, 60)
        DisabledFore    = [System.Drawing.Color]::FromArgb(100, 100, 100)
        TooltipBack     = [System.Drawing.Color]::FromArgb(50, 50, 50)
        TooltipFore     = [System.Drawing.Color]::FromArgb(220, 220, 220)
    }
    Light = @{
        FormBack        = [System.Drawing.Color]::FromArgb(245, 245, 245)
        FormFore        = [System.Drawing.Color]::FromArgb(30, 30, 30)
        ControlBack     = [System.Drawing.Color]::White
        ControlFore     = [System.Drawing.Color]::FromArgb(30, 30, 30)
        ListBack        = [System.Drawing.Color]::White
        ListFore        = [System.Drawing.Color]::FromArgb(30, 30, 30)
        GroupBoxFore    = [System.Drawing.Color]::FromArgb(60, 60, 60)
        ButtonPrimary   = [System.Drawing.Color]::FromArgb(0, 120, 212)
        ButtonSuccess   = [System.Drawing.Color]::FromArgb(16, 124, 16)
        ButtonNeutral   = [System.Drawing.Color]::FromArgb(100, 100, 100)
        ButtonFore      = [System.Drawing.Color]::White
        AccentColor     = [System.Drawing.Color]::FromArgb(0, 120, 212)
        RowAlt          = [System.Drawing.Color]::FromArgb(248, 248, 248)
        RowHighlight    = [System.Drawing.Color]::FromArgb(232, 255, 232)
        RowWarning      = [System.Drawing.Color]::FromArgb(255, 255, 200)
        RowError        = [System.Drawing.Color]::FromArgb(255, 210, 210)
        RowSuccess      = [System.Drawing.Color]::FromArgb(200, 240, 200)
        StatusBack      = [System.Drawing.Color]::FromArgb(240, 240, 240)
        StatusFore      = [System.Drawing.Color]::FromArgb(80, 80, 80)
        TabBack         = [System.Drawing.Color]::FromArgb(250, 250, 250)
        BorderColor     = [System.Drawing.Color]::FromArgb(200, 200, 200)
        DisabledFore    = [System.Drawing.Color]::FromArgb(160, 160, 160)
        TooltipBack     = [System.Drawing.Color]::FromArgb(255, 255, 225)
        TooltipFore     = [System.Drawing.Color]::FromArgb(30, 30, 30)
    }
}

function Get-SystemTheme {
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $val = Get-ItemPropertyValue -Path $regPath -Name "AppsUseLightTheme" -ErrorAction Stop
        if ($val -eq 0) { return "Dark" } else { return "Light" }
    } catch {
        return "Light"
    }
}

function Get-Theme {
    return $script:Themes[$script:CurrentTheme]
}

function Get-ThemeName {
    return $script:CurrentTheme
}

function Set-Theme {
    param([string]$ThemeName)
    if ($script:Themes.ContainsKey($ThemeName)) {
        $script:CurrentTheme = $ThemeName
    }
}

function Initialize-Theme {
    param([string]$Preference = "System") # "System", "Dark", "Light"
    if ($Preference -eq "System") {
        $script:CurrentTheme = Get-SystemTheme
    } else {
        $script:CurrentTheme = $Preference
    }
}

function Toggle-Theme {
    if ($script:CurrentTheme -eq "Dark") {
        $script:CurrentTheme = "Light"
    } else {
        $script:CurrentTheme = "Dark"
    }
    return $script:CurrentTheme
}

function Apply-ThemeToForm {
    param($Form)
    $t = Get-Theme
    $Form.BackColor = $t.FormBack
    $Form.ForeColor = $t.FormFore
    Apply-ThemeToControls -Controls $Form.Controls
}

function Apply-ThemeToControls {
    param($Controls)
    $t = Get-Theme
    foreach ($ctrl in $Controls) {
        switch ($ctrl.GetType().Name) {
            "Label" {
                $ctrl.ForeColor = $t.FormFore
            }
            "TextBox" {
                $ctrl.BackColor = $t.ControlBack
                $ctrl.ForeColor = $t.ControlFore
            }
            "ComboBox" {
                $ctrl.BackColor = $t.ControlBack
                $ctrl.ForeColor = $t.ControlFore
            }
            "Button" {
                $ctrl.ForeColor = $t.ButtonFore
                # Keep original BackColor for styled buttons
            }
            "CheckBox" {
                $ctrl.ForeColor = $t.FormFore
            }
            "RadioButton" {
                $ctrl.ForeColor = $t.FormFore
            }
            "ListView" {
                $ctrl.BackColor = $t.ListBack
                $ctrl.ForeColor = $t.ListFore
            }
            "DataGridView" {
                $ctrl.BackgroundColor = $t.ListBack
                $ctrl.GridColor = $t.BorderColor
                $ctrl.DefaultCellStyle.BackColor = $t.ListBack
                $ctrl.DefaultCellStyle.ForeColor = $t.ListFore
                $ctrl.DefaultCellStyle.SelectionBackColor = $t.AccentColor
                $ctrl.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
                $ctrl.ColumnHeadersDefaultCellStyle.BackColor = $t.ControlBack
                $ctrl.ColumnHeadersDefaultCellStyle.ForeColor = $t.ControlFore
                $ctrl.AlternatingRowsDefaultCellStyle.BackColor = $t.RowAlt
            }
            "GroupBox" {
                $ctrl.ForeColor = $t.GroupBoxFore
                Apply-ThemeToControls -Controls $ctrl.Controls
            }
            "TabControl" {
                Apply-ThemeToControls -Controls $ctrl.Controls
            }
            "TabPage" {
                $ctrl.BackColor = $t.TabBack
                $ctrl.ForeColor = $t.FormFore
                Apply-ThemeToControls -Controls $ctrl.Controls
            }
            "Panel" {
                $ctrl.BackColor = $t.FormBack
                Apply-ThemeToControls -Controls $ctrl.Controls
            }
            "StatusStrip" {
                $ctrl.BackColor = $t.StatusBack
                foreach ($item in $ctrl.Items) {
                    $item.ForeColor = $t.StatusFore
                }
            }
            "ProgressBar" {
                $ctrl.BackColor = $t.ControlBack
            }
            "NumericUpDown" {
                $ctrl.BackColor = $t.ControlBack
                $ctrl.ForeColor = $t.ControlFore
            }
            "TreeView" {
                $ctrl.BackColor = $t.ListBack
                $ctrl.ForeColor = $t.ListFore
            }
            "SplitContainer" {
                $ctrl.BackColor = $t.FormBack
                Apply-ThemeToControls -Controls $ctrl.Panel1.Controls
                Apply-ThemeToControls -Controls $ctrl.Panel2.Controls
            }
            default {
                if ($ctrl.Controls.Count -gt 0) {
                    Apply-ThemeToControls -Controls $ctrl.Controls
                }
            }
        }
    }
}
