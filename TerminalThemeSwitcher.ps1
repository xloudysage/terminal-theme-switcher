# Windows Terminal Theme Manager
# Windows PowerShell 5.1+ / Windows Terminal
# Run: powershell.exe -ExecutionPolicy Bypass -File .\TerminalThemeSwitcher.ps1

$ErrorActionPreference = 'Stop'

try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
} catch {
    Write-Host "Could not load the WPF assemblies. This tool requires Windows PowerShell 5.1 on Windows. $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

function Show-Message([string]$Text, [string]$Title = 'Terminal Theme Manager', [string]$Icon = 'Information') {
    [void][System.Windows.MessageBox]::Show($Text, $Title, 'OK', $Icon)
}

# Catches anything that escapes during startup (script scope) and reports it instead of silently closing.
trap {
    $fatal = $_.Exception.Message
    try { Show-Message "The application could not start or hit a fatal error.`n`n$fatal" 'Terminal Theme Manager' 'Error' }
    catch { Write-Host $fatal -ForegroundColor Red }
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'The LOCALAPPDATA environment variable is not set.' }

$dataDir = Join-Path $env:LOCALAPPDATA 'TerminalThemeSwitcher'
$themeFile = Join-Path $dataDir 'themes.json'
try {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
} catch {
    throw "Could not create the theme library folder '$dataDir'. $($_.Exception.Message)"
}

function Get-TerminalSettingsPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw "Windows Terminal settings.json was not found. Open Windows Terminal once and try again."
}

function New-Theme {
    param(
        [string]$Name, [string]$Background, [string]$Foreground,
        [string]$Cursor, [string]$Selection, [string]$AppTheme,
        [string[]]$Palette
    )
    [pscustomobject]@{
        Name=$Name; Background=$Background; Foreground=$Foreground
        Cursor=$Cursor; Selection=$Selection; AppTheme=$AppTheme
        Palette=@($Palette)
        BuiltIn=$true
    }
}

$builtIns = @(
    (New-Theme 'Pure White' '#FFFFFF' '#000000' '#000000' '#D9D9D9' 'light' @('#000000','#AA0000','#008000','#808000','#0000AA','#800080','#008080','#D0D0D0','#666666','#FF0000','#00A000','#A08000','#0000FF','#AA00AA','#008080','#FFFFFF')),
    (New-Theme 'One Half Light' '#FAFAFA' '#383A42' '#383A42' '#D7D7D7' 'light' @('#383A42','#E45649','#50A14F','#C18401','#0184BC','#A626A4','#0997B3','#FAFAFA','#4F525E','#DF6C75','#98C379','#E4C07A','#61AFEF','#C678DD','#56B6C2','#FFFFFF')),
    (New-Theme 'Campbell' '#0C0C0C' '#CCCCCC' '#FFFFFF' '#FFFFFF' 'dark' @('#0C0C0C','#C50F1F','#13A10E','#C19C00','#0037DA','#881798','#3A96DD','#CCCCCC','#767676','#E74856','#16C60C','#F9F1A5','#3B78FF','#B4009E','#61D6D6','#F2F2F2')),
    (New-Theme 'Tango Light' '#FFFFFF' '#2E3436' '#2E3436' '#C4C4C4' 'light' @('#2E3436','#CC0000','#4E9A06','#C4A000','#3465A4','#75507B','#06989A','#D3D7CF','#555753','#EF2929','#8AE234','#FCE94F','#729FCF','#AD7FA8','#34E2E2','#EEEEEC')),
    (New-Theme 'Vintage' '#000000' '#C0C0C0' '#FFFFFF' '#808080' 'dark' @('#000000','#800000','#008000','#808000','#000080','#800080','#008080','#C0C0C0','#808080','#FF0000','#00FF00','#FFFF00','#0000FF','#FF00FF','#00FFFF','#FFFFFF'))
)

function Test-HexColor([string]$Value) {
    return ($Value -match '^#[0-9A-Fa-f]{6}$')
}

# Checks a theme loaded from disk so one malformed entry cannot break the whole library.
function Test-ThemeShape($Theme) {
    if ($null -eq $Theme) { return $false }
    $name = [string]$Theme.Name
    if ([string]::IsNullOrWhiteSpace($name)) { return $false }
    if ($builtIns.Name -contains $name) { return $false }
    foreach ($field in @('Background','Foreground','Cursor','Selection')) {
        if (-not (Test-HexColor ([string]$Theme.$field))) { return $false }
    }
    $palette = @($Theme.Palette)
    if ($palette.Count -ne 16) { return $false }
    foreach ($c in $palette) { if (-not (Test-HexColor ([string]$c))) { return $false } }
    return $true
}

function Read-CustomThemes {
    if (-not (Test-Path -LiteralPath $themeFile)) { return @() }
    $parsed = $null
    try {
        $raw = Get-Content -LiteralPath $themeFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        $parsed = @($raw | ConvertFrom-Json)
    } catch {
        $reason = $_.Exception.Message
        $corrupt = "$themeFile.corrupt-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        try {
            Move-Item -LiteralPath $themeFile -Destination $corrupt -Force
            $note = "`n`nThe unreadable file was kept as:`n$corrupt"
        } catch {
            $note = "`n`nThe file could not be moved aside and may be overwritten the next time you save."
        }
        Show-Message "Could not read saved custom themes. The file may contain invalid JSON.`n`n$reason$note" 'Theme library error' 'Warning'
        return @()
    }

    $valid = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $skipped = 0
    foreach ($t in $parsed) {
        if ((Test-ThemeShape $t) -and -not $seen.ContainsKey([string]$t.Name)) {
            $seen[[string]$t.Name] = $true
            $valid.Add([pscustomobject]@{
                Name=[string]$t.Name
                Background=([string]$t.Background).ToUpperInvariant()
                Foreground=([string]$t.Foreground).ToUpperInvariant()
                Cursor=([string]$t.Cursor).ToUpperInvariant()
                Selection=([string]$t.Selection).ToUpperInvariant()
                AppTheme=$(if ([string]$t.AppTheme -eq 'dark') { 'dark' } else { 'light' })
                Palette=@($t.Palette | ForEach-Object { ([string]$_).ToUpperInvariant() })
                BuiltIn=$false
            })
        } else { $skipped++ }
    }
    if ($skipped -gt 0) {
        Show-Message "$skipped saved custom theme(s) were invalid or duplicated and were skipped." 'Theme library' 'Warning'
    }
    return $valid.ToArray()
}

function Save-CustomThemes($Themes) {
    $list = @($Themes)
    if ($list.Count -eq 0) { $json = '[]' } else { $json = ConvertTo-Json -InputObject $list -Depth 10 }
    $tmp = "$themeFile.tmp"
    try {
        [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $tmp -Destination $themeFile -Force
    } catch {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        throw "Could not save the theme library to '$themeFile'. $($_.Exception.Message)"
    }
}

function Set-JsonProperty($Object, [string]$Name, $Value) {
    if ($null -eq $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    } else {
        $Object.$Name = $Value
    }
}

# Windows Terminal's settings.json allows // and /* */ comments and trailing commas, which
# ConvertFrom-Json rejects. This strips them without touching text inside strings.
function ConvertTo-StrictJson([string]$Text) {
    $Text = $Text.TrimStart([char]0xFEFF)
    $n = $Text.Length

    # Pass 1: remove comments
    $sb = New-Object System.Text.StringBuilder
    $inStr = $false; $esc = $false; $i = 0
    while ($i -lt $n) {
        $c = $Text[$i]
        if ($inStr) {
            [void]$sb.Append($c)
            if ($esc) { $esc = $false } elseif ($c -eq '\') { $esc = $true } elseif ($c -eq '"') { $inStr = $false }
            $i++; continue
        }
        if ($c -eq '"') { $inStr = $true; [void]$sb.Append($c); $i++; continue }
        if ($c -eq '/' -and ($i + 1) -lt $n) {
            $next = $Text[$i + 1]
            if ($next -eq '/') {
                while ($i -lt $n -and $Text[$i] -ne "`n") { $i++ }
                continue
            }
            if ($next -eq '*') {
                $end = $Text.IndexOf('*/', $i + 2)
                if ($end -lt 0) { throw 'Unterminated /* comment in settings.json.' }
                $i = $end + 2
                continue
            }
        }
        [void]$sb.Append($c); $i++
    }

    # Pass 2: remove trailing commas before } or ]
    $noComments = $sb.ToString()
    $n = $noComments.Length
    $out = New-Object System.Text.StringBuilder
    $inStr = $false; $esc = $false; $i = 0
    while ($i -lt $n) {
        $c = $noComments[$i]
        if ($inStr) {
            [void]$out.Append($c)
            if ($esc) { $esc = $false } elseif ($c -eq '\') { $esc = $true } elseif ($c -eq '"') { $inStr = $false }
            $i++; continue
        }
        if ($c -eq '"') { $inStr = $true; [void]$out.Append($c); $i++; continue }
        if ($c -eq ',') {
            $j = $i + 1
            while ($j -lt $n -and [char]::IsWhiteSpace($noComments[$j])) { $j++ }
            if ($j -lt $n -and ($noComments[$j] -eq '}' -or $noComments[$j] -eq ']')) { $i++; continue }
        }
        [void]$out.Append($c); $i++
    }
    return $out.ToString()
}

function Apply-TerminalTheme($Theme) {
    if ([string]::IsNullOrWhiteSpace([string]$Theme.Name)) { throw 'Enter a theme name before applying.' }
    foreach ($field in @('Background','Foreground','Cursor','Selection')) {
        if (-not (Test-HexColor ([string]$Theme.$field))) { throw "$field must be a six-digit HEX color, such as #FFFFFF." }
    }
    if (@($Theme.Palette).Count -ne 16) { throw 'A theme must contain exactly 16 ANSI palette colors.' }
    foreach ($color in $Theme.Palette) {
        if (-not (Test-HexColor ([string]$color))) { throw "Invalid ANSI palette color: $color" }
    }

    $settingsPath = Get-TerminalSettingsPath

    # Read and parse first; nothing is modified if this fails.
    try { $raw = [System.IO.File]::ReadAllText($settingsPath) }
    catch { throw "Could not read settings.json. $($_.Exception.Message)" }
    if ([string]::IsNullOrWhiteSpace($raw)) { throw 'settings.json is empty, so it was left unchanged.' }

    $notes = New-Object System.Collections.Generic.List[string]
    try {
        $clean = ConvertTo-StrictJson $raw
        $json = $clean | ConvertFrom-Json
    } catch {
        throw "settings.json could not be parsed, so it was left unchanged.`n`n$($_.Exception.Message)"
    }
    if ($null -eq $json -or $json -isnot [System.Management.Automation.PSCustomObject]) {
        throw 'settings.json does not contain a JSON object, so it was left unchanged.'
    }
    if ($clean -ne $raw.TrimStart([char]0xFEFF)) { $notes.Add('Comments in settings.json are not preserved (the backup keeps them).') }
    if ($null -ne $json.profiles -and $json.profiles -is [array]) {
        throw 'This settings.json uses an old profile format (profiles is a list). Update Windows Terminal and try again.'
    }

    $backupPath = "$settingsPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    try { Copy-Item -LiteralPath $settingsPath -Destination $backupPath -Force }
    catch { throw "Could not create a backup, so nothing was changed. $($_.Exception.Message)" }

    try {
        $scheme = [ordered]@{
            name=$Theme.Name
            background=$Theme.Background
            foreground=$Theme.Foreground
            cursorColor=$Theme.Cursor
            selectionBackground=$Theme.Selection
            black=$Theme.Palette[0]; red=$Theme.Palette[1]; green=$Theme.Palette[2]; yellow=$Theme.Palette[3]
            blue=$Theme.Palette[4]; purple=$Theme.Palette[5]; cyan=$Theme.Palette[6]; white=$Theme.Palette[7]
            brightBlack=$Theme.Palette[8]; brightRed=$Theme.Palette[9]; brightGreen=$Theme.Palette[10]; brightYellow=$Theme.Palette[11]
            brightBlue=$Theme.Palette[12]; brightPurple=$Theme.Palette[13]; brightCyan=$Theme.Palette[14]; brightWhite=$Theme.Palette[15]
        }

        $schemes = @($json.schemes | Where-Object { $_ -and $_.name -ne $Theme.Name })
        Set-JsonProperty $json 'schemes' (@($schemes) + @([pscustomobject]$scheme))
        if ($null -eq $json.profiles) { Set-JsonProperty $json 'profiles' ([pscustomobject]@{}) }
        if ($null -eq $json.profiles.defaults) { Set-JsonProperty $json.profiles 'defaults' ([pscustomobject]@{}) }
        Set-JsonProperty $json.profiles.defaults 'colorScheme' $Theme.Name
        Set-JsonProperty $json 'theme' $Theme.AppTheme

        $overrides = @(@($json.profiles.list) | Where-Object { $_ -and $_.PSObject.Properties['colorScheme'] -and $_.colorScheme -ne $Theme.Name })
        if ($overrides.Count -gt 0) { $notes.Add("$($overrides.Count) profile(s) set their own colorScheme and will not use this theme.") }

        # Serialize and re-parse before touching the real file.
        $output = $json | ConvertTo-Json -Depth 100
        [void]($output | ConvertFrom-Json)
        [System.IO.File]::WriteAllText($settingsPath, $output, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        $reason = $_.Exception.Message
        $restored = $false
        try {
            Copy-Item -LiteralPath $backupPath -Destination $settingsPath -Force
            $restored = $true
        } catch { }
        if ($restored) {
            throw "Could not update settings.json. Your original was restored.`n`n$reason"
        } else {
            throw "Could not update settings.json and restoring it failed. Restore manually from:`n$backupPath`n`n$reason"
        }
    }

    # Keep only the 10 newest backups.
    try {
        Get-ChildItem -LiteralPath (Split-Path -Parent $settingsPath) -Filter 'settings.json.backup-*' |
            Sort-Object LastWriteTime -Descending | Select-Object -Skip 10 |
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch { }

    return [pscustomobject]@{ Backup=$backupPath; Notes=@($notes) }
}

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows Terminal Theme Manager" Height="760" Width="820"
        MinHeight="700" MinWidth="760" WindowStartupLocation="CenterScreen"
        Background="#F3F4F6" FontFamily="Segoe UI">
  <Grid Margin="22">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0">
      <TextBlock Text="Terminal Theme Manager" FontSize="25" FontWeight="SemiBold" Foreground="#171717"/>
      <TextBlock Text="Switch built-in themes or create, edit and save your own." FontSize="13" Foreground="#666666" Margin="0,5,0,0"/>
    </StackPanel>
    <Grid Grid.Row="1" Margin="0,18,0,14">
      <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <Button x:Name="ChooseMode" Grid.Column="0" Content="Choose existing theme" Padding="14,9" Margin="0,0,8,0" Background="#2563EB" Foreground="White" FontWeight="SemiBold"/>
      <Button x:Name="CreateMode" Grid.Column="1" Content="Create a new theme" Padding="14,9" Margin="0,0,12,0"/>
      <ComboBox x:Name="ThemePicker" Grid.Column="2" Height="36" FontSize="14" Padding="7"/>
      <Button x:Name="DeleteTheme" Grid.Column="3" Content="Delete custom" Padding="13,7" Margin="8,0,0,0"/>
    </Grid>
    <Grid Grid.Row="2">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="1.1*"/>
        <ColumnDefinition Width="14"/>
        <ColumnDefinition Width="1*"/>
      </Grid.ColumnDefinitions>
      <Border Grid.Column="0" Background="White" BorderBrush="#D1D5DB" BorderThickness="1" CornerRadius="9" Padding="15">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel>
            <TextBlock Text="THEME EDITOR" FontWeight="Bold" FontSize="11" Foreground="#737373" Margin="0,0,0,12"/>
            <TextBlock Text="Theme name" FontSize="12" Foreground="#555"/>
            <TextBox x:Name="NameBox" Height="31" Padding="7" Margin="0,4,0,10"/>
            <TextBlock Text="Application appearance" FontSize="12" Foreground="#555"/>
            <ComboBox x:Name="AppThemeBox" Height="31" Margin="0,4,0,10" Padding="6">
              <ComboBoxItem Content="Light" Tag="light"/>
              <ComboBoxItem Content="Dark" Tag="dark"/>
            </ComboBox>
            <TextBlock Text="Core colors (HEX)" FontWeight="SemiBold" FontSize="12" Margin="0,0,0,7"/>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
              <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,8,8"><TextBlock Text="Background" FontSize="11"/><TextBox x:Name="BackgroundBox" Height="29" Padding="6"/></StackPanel>
              <StackPanel Grid.Row="0" Grid.Column="1" Margin="0,0,0,8"><TextBlock Text="Foreground / text" FontSize="11"/><TextBox x:Name="ForegroundBox" Height="29" Padding="6"/></StackPanel>
              <StackPanel Grid.Row="1" Grid.Column="0" Margin="0,0,8,8"><TextBlock Text="Cursor" FontSize="11"/><TextBox x:Name="CursorBox" Height="29" Padding="6"/></StackPanel>
              <StackPanel Grid.Row="1" Grid.Column="1" Margin="0,0,0,8"><TextBlock Text="Selection" FontSize="11"/><TextBox x:Name="SelectionBox" Height="29" Padding="6"/></StackPanel>
            </Grid>
            <TextBlock Text="ANSI palette (16 HEX colors)" FontWeight="SemiBold" FontSize="12" Margin="0,3,0,7"/>
            <UniformGrid x:Name="PaletteGrid" Columns="2"/>
            <TextBlock Text="Order: black, red, green, yellow, blue, purple, cyan, white, then the eight bright variants." TextWrapping="Wrap" FontSize="10" Foreground="#777" Margin="0,8,0,0"/>
          </StackPanel>
        </ScrollViewer>
      </Border>
      <Border Grid.Column="2" Background="White" BorderBrush="#D1D5DB" BorderThickness="1" CornerRadius="9" Padding="15">
        <StackPanel>
          <TextBlock Text="LIVE PREVIEW" FontWeight="Bold" FontSize="11" Foreground="#737373" Margin="0,0,0,10"/>
          <Border x:Name="Preview" CornerRadius="7" Padding="13" Height="205">
            <StackPanel>
              <TextBlock x:Name="PreviewTitle" Text="PowerShell" FontFamily="Consolas" FontSize="12" FontWeight="Bold"/>
              <TextBlock x:Name="PreviewCommand" Text="PS C:\Users\User&gt; Get-ChildItem" FontFamily="Consolas" FontSize="12" Margin="0,14,0,0"/>
              <TextBlock x:Name="PreviewDirectory" Text="Directory: C:\Users\User" FontFamily="Consolas" FontSize="12" Margin="0,8,0,0"/>
              <TextBlock x:Name="PreviewFiles" Text="Mode       LastWriteTime       Name" FontFamily="Consolas" FontSize="11" Margin="0,8,0,0"/>
              <TextBlock x:Name="PreviewFile" Text="d----      11/07/2026          Projects" FontFamily="Consolas" FontSize="11" Margin="0,3,0,0"/>
              <TextBlock x:Name="PreviewPrompt" Text="PS C:\Users\User&gt;" FontFamily="Consolas" FontSize="12" Margin="0,12,0,0"/>
            </StackPanel>
          </Border>
          <TextBlock Text="Preview updates as you edit the HEX values. Invalid values get a red border." TextWrapping="Wrap" FontSize="11" Foreground="#666" Margin="0,10,0,0"/>
          <TextBlock Text="HOW IT WORKS" FontWeight="Bold" FontSize="11" Foreground="#737373" Margin="0,24,0,8"/>
          <TextBlock Text="• Custom themes are saved in your user profile.&#10;• Applying a theme backs up settings.json.&#10;• The selected theme becomes the default profile scheme.&#10;• Restart Windows Terminal to see the full change." TextWrapping="Wrap" FontSize="12" Foreground="#555" LineHeight="20"/>
          <TextBlock x:Name="Status" Text="Ready." TextWrapping="Wrap" FontSize="11" Foreground="#555" Margin="0,18,0,0"/>
        </StackPanel>
      </Border>
    </Grid>
    <DockPanel Grid.Row="3" Margin="0,14,0,0">
      <Button x:Name="OpenSettings" Content="Open settings.json" Height="37" Padding="12,0" DockPanel.Dock="Left"/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="SaveTheme" Content="Save custom theme" Height="37" Padding="14,0" Margin="0,0,8,0"/>
        <Button x:Name="ApplyTheme" Content="Apply to Terminal" Height="37" Padding="16,0" Background="#2563EB" Foreground="White" FontWeight="SemiBold"/>
      </StackPanel>
    </DockPanel>
  </Grid>
</Window>
'@

try {
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    throw "The window could not be created. $($_.Exception.Message)"
}

$controls = @{}
$controlNames = @('ThemePicker','ChooseMode','CreateMode','DeleteTheme','NameBox','AppThemeBox','BackgroundBox','ForegroundBox','CursorBox','SelectionBox','PaletteGrid','Preview','PreviewTitle','PreviewCommand','PreviewDirectory','PreviewFiles','PreviewFile','PreviewPrompt','Status','OpenSettings','SaveTheme','ApplyTheme')
foreach ($controlName in $controlNames) {
    $found = $window.FindName($controlName)
    if ($null -eq $found) { throw "Internal error: control '$controlName' was not found in the window." }
    $controls[$controlName] = $found
}

# Last-resort handler so an unexpected error in any event shows a message instead of closing the app.
$window.Dispatcher.Add_UnhandledException({
    param($sender, $e)
    try { Show-Message "An unexpected error occurred:`n`n$($e.Exception.Message)" 'Terminal Theme Manager' 'Error' } catch { }
    $e.Handled = $true
})

$picker=$controls.ThemePicker; $nameBox=$controls.NameBox; $appBox=$controls.AppThemeBox
$script:mode = 'existing'
$bgBox=$controls.BackgroundBox; $fgBox=$controls.ForegroundBox; $cursorBox=$controls.CursorBox; $selectionBox=$controls.SelectionBox
$paletteBoxes = New-Object System.Collections.Generic.List[System.Windows.Controls.TextBox]
$paletteLabels = @('Black','Red','Green','Yellow','Blue','Purple','Cyan','White','Bright black','Bright red','Bright green','Bright yellow','Bright blue','Bright purple','Bright cyan','Bright white')
for ($i=0; $i -lt 16; $i++) {
    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Margin = '0,0,8,7'
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $paletteLabels[$i]; $label.FontSize = 10
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Height = 27; $tb.Padding = '6'
    [void]$paletteBoxes.Add($tb)
    [void]$panel.Children.Add($label); [void]$panel.Children.Add($tb)
    [void]$controls.PaletteGrid.Children.Add($panel)
}
$hexBoxes = @($bgBox, $fgBox, $cursorBox, $selectionBox) + @($paletteBoxes)

# These must be $script: scoped. Event handlers run in child scopes, so a plain assignment
# inside a handler would create a local copy and leave the picker with a stale list.
$script:customThemes = @(Read-CustomThemes)
$script:allThemes = @($builtIns) + @($script:customThemes)
$script:currentThemeName = $null
$script:loading = $false

function Get-SelectedTheme {
    $selectedName = [string]$picker.SelectedItem
    if ([string]::IsNullOrEmpty($selectedName)) { return $null }
    return $script:allThemes | Where-Object { $_.Name -eq $selectedName } | Select-Object -First 1
}

function Refresh-ThemeList([string]$SelectName) {
    $picker.Items.Clear()
    foreach ($theme in $script:allThemes) { [void]$picker.Items.Add($theme.Name) }
    if ($SelectName -and $picker.Items.Contains($SelectName)) { $picker.SelectedItem = $SelectName }
    elseif ($picker.Items.Count -gt 0) { $picker.SelectedIndex = 0 }
}

function Read-EditorTheme {
    $palette = @($paletteBoxes | ForEach-Object { $_.Text.Trim().ToUpperInvariant() })
    $appItem = $appBox.SelectedItem
    if ($null -eq $appItem) { $app = 'light' } else { $app = [string]$appItem.Tag }
    return [pscustomobject]@{
        Name=$nameBox.Text.Trim()
        Background=$bgBox.Text.Trim().ToUpperInvariant()
        Foreground=$fgBox.Text.Trim().ToUpperInvariant()
        Cursor=$cursorBox.Text.Trim().ToUpperInvariant()
        Selection=$selectionBox.Text.Trim().ToUpperInvariant()
        AppTheme=$app
        Palette=$palette
        BuiltIn=$false
    }
}

function Update-Preview {
    foreach ($box in $hexBoxes) {
        if (Test-HexColor $box.Text.Trim()) { $box.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty) }
        else { $box.BorderBrush = [Windows.Media.Brushes]::Red }
    }
    $bg=$bgBox.Text.Trim(); $fg=$fgBox.Text.Trim()
    if ((Test-HexColor $bg) -and (Test-HexColor $fg)) {
        try {
            $converter = New-Object Windows.Media.BrushConverter
            $controls.Preview.Background = $converter.ConvertFromString($bg)
            $brush = $converter.ConvertFromString($fg)
            foreach ($key in @('PreviewTitle','PreviewCommand','PreviewDirectory','PreviewFiles','PreviewFile','PreviewPrompt')) { $controls[$key].Foreground=$brush }
        } catch {
            $controls.Status.Text = "Preview could not be drawn: $($_.Exception.Message)"
        }
    }
}

function Load-ThemeIntoEditor($Theme) {
    if ($null -eq $Theme) { return }
    $script:loading = $true
    try {
        $nameBox.Text=[string]$Theme.Name
        $bgBox.Text=[string]$Theme.Background
        $fgBox.Text=[string]$Theme.Foreground
        $cursorBox.Text=[string]$Theme.Cursor
        $selectionBox.Text=[string]$Theme.Selection
        if ([string]$Theme.AppTheme -eq 'dark') { $appBox.SelectedIndex=1 } else { $appBox.SelectedIndex=0 }
        $palette = @($Theme.Palette)
        for ($i=0; $i -lt 16; $i++) {
            if ($palette.Count -gt $i) { $paletteBoxes[$i].Text=[string]$palette[$i] }
            else { $paletteBoxes[$i].Text='#000000' }
        }
        $script:currentThemeName=[string]$Theme.Name
        $controls.DeleteTheme.IsEnabled = -not [bool]$Theme.BuiltIn
        if ($Theme.BuiltIn) { $controls.Status.Text = 'Built-in theme. Use Save custom theme to save your edited version under a new name.' }
        else { $controls.Status.Text = 'Custom theme. Edit it and save to update it.' }
    } finally {
        $script:loading = $false
    }
    Update-Preview
}

$picker.Add_SelectionChanged({
    try {
        if (-not $script:loading -and $script:mode -eq 'existing') { Load-ThemeIntoEditor (Get-SelectedTheme) }
    } catch {
        $controls.Status.Text = "Could not load theme: $($_.Exception.Message)"
    }
})
foreach ($tb in $hexBoxes) {
    $tb.Add_TextChanged({
        try { if (-not $script:loading) { Update-Preview } }
        catch { $controls.Status.Text = "Preview error: $($_.Exception.Message)" }
    })
}

$controls.CreateMode.Add_Click({
    try {
        $script:mode = 'new'
        $converter = New-Object Windows.Media.BrushConverter
        $controls.CreateMode.Background = $converter.ConvertFromString('#2563EB')
        $controls.CreateMode.Foreground = $converter.ConvertFromString('#FFFFFF')
        $controls.ChooseMode.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
        $controls.ChooseMode.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
        $picker.IsEnabled = $false
        $controls.DeleteTheme.IsEnabled = $false
        $script:loading = $true
        try {
            $nameBox.Text='My New Theme'; $bgBox.Text='#FFFFFF'; $fgBox.Text='#000000'; $cursorBox.Text='#000000'; $selectionBox.Text='#D9D9D9'; $appBox.SelectedIndex=0
            $defaultPalette=@('#000000','#AA0000','#008000','#808000','#0000AA','#800080','#008080','#D0D0D0','#666666','#FF0000','#00A000','#A08000','#0000FF','#AA00AA','#008080','#FFFFFF')
            for ($i=0; $i -lt 16; $i++) { $paletteBoxes[$i].Text=$defaultPalette[$i] }
            $script:currentThemeName=$null
            $controls.Status.Text='New theme mode. Customize the colors, then click Save custom theme.'
        } finally {
            $script:loading=$false
        }
        Update-Preview
    } catch {
        Show-Message $_.Exception.Message 'Could not switch mode' 'Error'
    }
})
$controls.ChooseMode.Add_Click({
    try {
        $script:mode = 'existing'
        $converter = New-Object Windows.Media.BrushConverter
        $controls.ChooseMode.Background = $converter.ConvertFromString('#2563EB')
        $controls.ChooseMode.Foreground = $converter.ConvertFromString('#FFFFFF')
        $controls.CreateMode.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
        $controls.CreateMode.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
        $picker.IsEnabled = $true
        if ($null -eq $picker.SelectedItem -and $picker.Items.Count -gt 0) { $picker.SelectedIndex = 0 }
        Load-ThemeIntoEditor (Get-SelectedTheme)
    } catch {
        Show-Message $_.Exception.Message 'Could not switch mode' 'Error'
    }
})

$controls.SaveTheme.Add_Click({
    try {
        $theme=Read-EditorTheme
        if ([string]::IsNullOrWhiteSpace($theme.Name)) { throw 'Enter a theme name.' }
        if ($theme.Name -match '[\\/:*?"<>|]') { throw 'Theme names cannot contain \ / : * ? " < > or |.' }
        foreach ($field in @('Background','Foreground','Cursor','Selection')) {
            if (-not (Test-HexColor ([string]$theme.$field))) { throw "$field must be a HEX color like #FFFFFF." }
        }
        if ($theme.Palette.Count -ne 16) { throw 'Enter all 16 ANSI palette colors.' }
        foreach ($color in $theme.Palette) { if (-not (Test-HexColor $color)) { throw "Invalid palette color: $color" } }
        if ($builtIns.Name -contains $theme.Name) { throw 'That name belongs to a built-in theme. Choose another name.' }

        $latest = @(Read-CustomThemes)
        $updated = @($latest | Where-Object { $_.Name -ne $theme.Name }) + @($theme)
        Save-CustomThemes $updated

        # Only update in-memory state after the file was written successfully.
        $script:customThemes = $updated
        $script:allThemes = @($builtIns) + @($script:customThemes)
        $script:mode = 'existing'
        $picker.IsEnabled = $true
        Refresh-ThemeList $theme.Name
        Load-ThemeIntoEditor $theme
        $controls.Status.Text="Saved '$($theme.Name)' to your local theme library."
    } catch {
        Show-Message $_.Exception.Message 'Cannot save theme' 'Warning'
    }
})
$controls.DeleteTheme.Add_Click({
    try {
        $theme=Get-SelectedTheme
        if ($null -eq $theme -or $theme.BuiltIn) { return }
        $answer=[System.Windows.MessageBox]::Show("Delete custom theme '$($theme.Name)'?",'Delete theme','YesNo','Warning')
        if ($answer -eq 'Yes') {
            $remaining=@((Read-CustomThemes) | Where-Object { $_.Name -ne $theme.Name })
            Save-CustomThemes $remaining
            $script:customThemes = $remaining
            $script:allThemes=@($builtIns)+@($script:customThemes)
            Refresh-ThemeList 'Pure White'
            $controls.Status.Text="Deleted '$($theme.Name)'."
        }
    } catch {
        Show-Message $_.Exception.Message 'Could not delete theme' 'Error'
    }
})
$controls.ApplyTheme.Add_Click({
    try {
        $theme=Read-EditorTheme
        $result=Apply-TerminalTheme $theme
        $extra = ''
        if ($result.Notes.Count -gt 0) { $extra = "`n`nNote:`n- " + ($result.Notes -join "`n- ") }
        $controls.Status.Text="Applied '$($theme.Name)'. Restart Windows Terminal. Backup: $($result.Backup)$extra"
        Show-Message "Theme applied.`n`nClose and reopen Windows Terminal to see the changes.`n`nBackup created at:`n$($result.Backup)$extra" 'Theme applied' 'Information'
    } catch {
        Show-Message $_.Exception.Message 'Could not apply theme' 'Error'
    }
})
$controls.OpenSettings.Add_Click({
    try {
        $path = Get-TerminalSettingsPath
        Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $path)
    } catch {
        Show-Message $_.Exception.Message 'Settings not found' 'Error'
    }
})

$converter = New-Object Windows.Media.BrushConverter
$controls.ChooseMode.Background = $converter.ConvertFromString('#2563EB')
$controls.ChooseMode.Foreground = $converter.ConvertFromString('#FFFFFF')
$picker.IsEnabled = $true
Refresh-ThemeList 'Pure White'
Load-ThemeIntoEditor (Get-SelectedTheme)
[void]$window.ShowDialog()
