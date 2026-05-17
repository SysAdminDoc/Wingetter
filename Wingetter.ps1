<#
.SYNOPSIS
    Wingetter - Comprehensive GUI for bulk software installation via winget
.DESCRIPTION
    A professional PowerShell GUI application for discovering, selecting, and bulk
    installing Windows software using Windows Package Manager (winget).
    Features: Dark/Light mode, category sidebar, collapse/expand, installed app detection,
    install/update modes, shift-click selection, per-app log panel, toast notifications,
    parallel icon loading, app icons with caching, search filter, package groups
    (save/load/export as PS1 or JSON), 765 apps across 39 categories.
.VERSION
    6.1.0
#>

#Requires -Version 5.1

# ============================================================================
# HIDE CONSOLE WINDOW
# ============================================================================
Add-Type -Name Win32 -Namespace Native -MemberDefinition @'
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
try {
    $hwnd = [Native.Win32]::GetConsoleWindow()
    if ($hwnd -ne [IntPtr]::Zero) { [Native.Win32]::ShowWindow($hwnd, 0) | Out-Null }
} catch {}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ============================================================================
# SPLASH SCREEN (pure code - no XAML FindName issues)
# ============================================================================
function Show-Splash {
    $bc = New-Object System.Windows.Media.BrushConverter

    $win = New-Object System.Windows.Window
    $win.WindowStyle = [System.Windows.WindowStyle]::None
    $win.AllowsTransparency = $true
    $win.Background = [System.Windows.Media.Brushes]::Transparent
    $win.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    $win.Width = 540; $win.Height = 300
    $win.Topmost = $true; $win.ShowInTaskbar = $false
    $win.ResizeMode = [System.Windows.ResizeMode]::NoResize

    # Outer border with shadow
    $outer = New-Object System.Windows.Controls.Border
    $outer.Background = $bc.ConvertFromString("#08131f")
    $outer.CornerRadius = [System.Windows.CornerRadius]::new(18)
    $outer.BorderBrush = $bc.ConvertFromString("#24374a")
    $outer.BorderThickness = [System.Windows.Thickness]::new(1.5, 1.5, 1.5, 1.5)
    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.BlurRadius = 30; $shadow.Opacity = 0.5; $shadow.ShadowDepth = 0
    $outer.Effect = $shadow

    $grid = New-Object System.Windows.Controls.Grid
    $outer.Child = $grid

    # Top gradient accent line
    $accentLine = New-Object System.Windows.Controls.Border
    $accentLine.Height = 3
    $accentLine.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
    $accentLine.CornerRadius = [System.Windows.CornerRadius]::new(18, 18, 0, 0)
    $grad = New-Object System.Windows.Media.LinearGradientBrush
    $grad.StartPoint = [System.Windows.Point]::new(0, 0)
    $grad.EndPoint = [System.Windows.Point]::new(1, 0)
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#3da4ff"), 0)))
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#7dd3fc"), 0.55)))
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#22c55e"), 1)))
    $accentLine.Background = $grad
    [void]$grid.Children.Add($accentLine)

    # Center stack
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $stack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

    # Title "Wingetter" with gradient
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "Wingetter"
    $title.FontSize = 46; $title.FontWeight = [System.Windows.FontWeights]::Bold
    $title.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $title.Margin = [System.Windows.Thickness]::new(0, 0, 0, 2)
    $titleGrad = New-Object System.Windows.Media.LinearGradientBrush
    $titleGrad.StartPoint = [System.Windows.Point]::new(0, 0)
    $titleGrad.EndPoint = [System.Windows.Point]::new(1, 0)
    $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#8cd2ff"), 0)))
    $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#d3f1ff"), 1)))
    $title.Foreground = $titleGrad
    [void]$stack.Children.Add($title)

    # Version
    $ver = New-Object System.Windows.Controls.TextBlock
    $ver.Text = "v6.1.0"; $ver.FontSize = 12
    $ver.Foreground = $bc.ConvertFromString("#7a90a6")
    $ver.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $ver.Margin = [System.Windows.Thickness]::new(0, 0, 0, 24)
    [void]$stack.Children.Add($ver)

    # Status text
    $statusTb = New-Object System.Windows.Controls.TextBlock
    $statusTb.Text = "Initializing..."
    $statusTb.FontSize = 13
    $statusTb.Foreground = $bc.ConvertFromString("#9db0c2")
    $statusTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $statusTb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 14)
    [void]$stack.Children.Add($statusTb)

    # Progress bar container
    $barBg = New-Object System.Windows.Controls.Border
    $barBg.Background = $bc.ConvertFromString("#132132")
    $barBg.CornerRadius = [System.Windows.CornerRadius]::new(4)
    $barBg.Height = 6; $barBg.Width = 340
    $barBg.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)

    # Progress bar fill
    $barFill = New-Object System.Windows.Controls.Border
    $barFill.CornerRadius = [System.Windows.CornerRadius]::new(4)
    $barFill.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $barFill.Width = 0; $barFill.Height = 6
    $barGrad = New-Object System.Windows.Media.LinearGradientBrush
    $barGrad.StartPoint = [System.Windows.Point]::new(0, 0)
    $barGrad.EndPoint = [System.Windows.Point]::new(1, 0)
    $barGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#3da4ff"), 0)))
    $barGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#34d399"), 1)))
    $barFill.Background = $barGrad
    $barBg.Child = $barFill
    [void]$stack.Children.Add($barBg)

    # Percent text
    $pctTb = New-Object System.Windows.Controls.TextBlock
    $pctTb.Text = ""; $pctTb.FontSize = 11
    $pctTb.Foreground = $bc.ConvertFromString("#7a90a6")
    $pctTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    [void]$stack.Children.Add($pctTb)

    [void]$grid.Children.Add($stack)
    $win.Content = $outer

    return @{
        Window  = $win
        Status  = $statusTb
        Bar     = $barFill
        Pct     = $pctTb
    }
}

function Update-Splash {
    param($Splash, [string]$Text, [int]$Percent)
    if ($null -eq $Splash -or $null -eq $Splash.Status) { return }
    $Splash.Status.Text = $Text
    $Splash.Bar.Width = [math]::Round(340 * ($Percent / 100))
    $Splash.Pct.Text = "$Percent%"
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [Action]{ }
    )
}

# ============================================================================
# ICON CACHE SETUP
# ============================================================================

$Script:IconCacheDir = "$env:TEMP\WingetterIcons"
if (!(Test-Path $Script:IconCacheDir)) { New-Item -ItemType Directory -Path $Script:IconCacheDir -Force | Out-Null }

function Get-AppIcon {
    param([string]$Url, [string]$AppName)
    
    $safeName = ($AppName -replace '[^\w]', '_') + ".png"
    $cachePath = Join-Path $Script:IconCacheDir $safeName
    
    # Return cached
    if (Test-Path $cachePath) {
        try {
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.UriSource = [Uri]::new($cachePath)
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.DecodePixelWidth = 20
            $bitmap.DecodePixelHeight = 20
            $bitmap.EndInit()
            if ($bitmap.PixelWidth -gt 0) { return $bitmap }
        } catch { }
    }
    
    # Download
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")
        $wc.DownloadFile($Url, $cachePath)
        $wc.Dispose()
        
        $fi = [System.IO.FileInfo]::new($cachePath)
        if ($fi.Length -gt 100) {
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.UriSource = [Uri]::new($cachePath)
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.DecodePixelWidth = 20
            $bitmap.DecodePixelHeight = 20
            $bitmap.EndInit()
            if ($bitmap.PixelWidth -gt 0) { return $bitmap }
        }
    } catch { }
    
    return $null
}

function New-LetterIcon {
    param([string]$Letter, [string]$ColorHex)
    
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    
    $bgBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($ColorHex)
    $dc.DrawRoundedRectangle($bgBrush, $null, [System.Windows.Rect]::new(0, 0, 20, 20), 4, 4)
    
    $ft = New-Object System.Windows.Media.FormattedText(
        $Letter.ToUpper(),
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Windows.FlowDirection]::LeftToRight,
        (New-Object System.Windows.Media.Typeface("Segoe UI")),
        11,
        [System.Windows.Media.Brushes]::White,
        1.0
    )
    
    $x = (20 - $ft.Width) / 2
    $y = (20 - $ft.Height) / 2
    $dc.DrawText($ft, (New-Object System.Windows.Point($x, $y)))
    $dc.Close()
    
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(20, 20, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    return $rtb
}

$Script:LetterColors = @("#e74c3c","#e67e22","#f1c40f","#2ecc71","#1abc9c","#3498db","#9b59b6","#e91e63","#00bcd4","#ff5722","#607d8b","#795548","#4caf50","#ff9800","#673ab7","#009688","#c0392b","#2980b9","#8e44ad","#27ae60","#d35400","#16a085","#2c3e50","#7f8c8d","#34495e","#1a237e")

function Get-LetterColor {
    param([string]$Name)
    $idx = 0
    foreach ($c in $Name.ToCharArray()) { $idx += [int]$c }
    return $Script:LetterColors[$idx % $Script:LetterColors.Count]
}

# ============================================================================
# SOFTWARE DATABASE - Each category sorted by popularity (most popular first).
# ============================================================================

$f = "https://www.google.com/s2/favicons?sz=32&domain="

function ConvertFrom-WingetterCatalogJson {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path $Path)) { return $null }

    try {
        $catalog = Get-Content -Path $Path -Raw | ConvertFrom-Json
        if ($catalog.schemaVersion -ne 1 -or !$catalog.categories) { return $null }

        $database = [ordered]@{}
        foreach ($category in @($catalog.categories)) {
            $apps = @()
            foreach ($app in @($category.apps)) {
                $icon = if ($app.iconUrl) { [string]$app.iconUrl } else { "${f}$($app.iconDomain)" }
                $apps += @{
                    Name     = [string]$app.name
                    WingetId = [string]$app.wingetId
                    Icon     = $icon
                }
            }
            if ($apps.Count -gt 0) {
                $database[[string]$category.name] = $apps
            }
        }

        if ($database.Keys.Count -gt 0) { return $database }
    } catch {
        Write-Warning "Could not load catalog from '$Path': $($_.Exception.Message). Using embedded catalog."
    }

    return $null
}

function ConvertFrom-WingetterGroupsJson {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path $Path)) { return $null }

    try {
        $groupsJson = Get-Content -Path $Path -Raw | ConvertFrom-Json
        if ($groupsJson.schemaVersion -ne 1 -or !$groupsJson.groups) { return $null }

        $groups = [ordered]@{}
        foreach ($group in @($groupsJson.groups)) {
            $packageIds = @()
            foreach ($packageId in @($group.packageIds)) {
                $packageIds += [string]$packageId
            }
            if ($packageIds.Count -gt 0) {
                $groups[[string]$group.name] = $packageIds
            }
        }

        if ($groups.Keys.Count -gt 0) { return $groups }
    } catch {
        Write-Warning "Could not load built-in groups from '$Path': $($_.Exception.Message). Using embedded groups."
    }

    return $null
}

$Script:SoftwareDatabase = [ordered]@{

    "Web Browsers" = @(
        @{ Name = "Google Chrome"; WingetId = "Google.Chrome"; Icon = "${f}google.com" }
        @{ Name = "Mozilla Firefox"; WingetId = "Mozilla.Firefox"; Icon = "${f}mozilla.org" }
        @{ Name = "Microsoft Edge"; WingetId = "Microsoft.Edge"; Icon = "${f}microsoft.com" }
        @{ Name = "Brave"; WingetId = "Brave.Brave"; Icon = "${f}brave.com" }
        @{ Name = "Opera"; WingetId = "Opera.Opera"; Icon = "${f}opera.com" }
        @{ Name = "Opera GX"; WingetId = "Opera.OperaGX"; Icon = "${f}opera.com" }
        @{ Name = "Vivaldi"; WingetId = "Vivaldi.Vivaldi"; Icon = "${f}vivaldi.com" }
        @{ Name = "Tor Browser"; WingetId = "TorProject.TorBrowser"; Icon = "${f}torproject.org" }
        @{ Name = "LibreWolf"; WingetId = "LibreWolf.LibreWolf"; Icon = "${f}librewolf.net" }
        @{ Name = "Waterfox"; WingetId = "Waterfox.Waterfox"; Icon = "${f}waterfox.net" }
        @{ Name = "Arc"; WingetId = "TheBrowserCompany.Arc"; Icon = "${f}arc.net" }
        @{ Name = "Zen Browser"; WingetId = "Zen-Team.Zen-Browser"; Icon = "${f}zen-browser.app" }
        @{ Name = "Floorp"; WingetId = "Ablaze.Floorp"; Icon = "${f}floorp.app" }
        @{ Name = "Mullvad Browser"; WingetId = "MullvadVPN.MullvadBrowser"; Icon = "${f}mullvad.net" }
        @{ Name = "Chromium"; WingetId = "Hibbiki.Chromium"; Icon = "${f}chromium.org" }
        @{ Name = "Ungoogled Chromium"; WingetId = "eloston.ungoogled-chromium"; Icon = "${f}chromium.org" }
        @{ Name = "Pale Moon"; WingetId = "MoonchildProductions.PaleMoon"; Icon = "${f}palemoon.org" }
        @{ Name = "Thorium Browser AVX2"; WingetId = "Alex313031.Thorium.AVX2"; Icon = "${f}thorium.rocks" }
        @{ Name = "Firefox ESR"; WingetId = "Mozilla.Firefox.ESR"; Icon = "${f}mozilla.org" }
        @{ Name = "Falkon"; WingetId = "KDE.Falkon"; Icon = "${f}falkon.org" }
    )

    "Messaging & Email" = @(
        @{ Name = "Discord"; WingetId = "Discord.Discord"; Icon = "${f}discord.com" }
        @{ Name = "Zoom"; WingetId = "Zoom.Zoom"; Icon = "${f}zoom.us" }
        @{ Name = "Microsoft Teams"; WingetId = "Microsoft.Teams"; Icon = "${f}teams.microsoft.com" }
        @{ Name = "Slack"; WingetId = "SlackTechnologies.Slack"; Icon = "${f}slack.com" }
        @{ Name = "WhatsApp"; WingetId = "WhatsApp.WhatsApp"; Icon = "${f}whatsapp.com" }
        @{ Name = "Telegram"; WingetId = "Telegram.TelegramDesktop"; Icon = "${f}telegram.org" }
        @{ Name = "Signal"; WingetId = "OpenWhisperSystems.Signal"; Icon = "${f}signal.org" }
        @{ Name = "Skype"; WingetId = "Microsoft.Skype"; Icon = "${f}skype.com" }
        @{ Name = "Thunderbird"; WingetId = "Mozilla.Thunderbird"; Icon = "${f}thunderbird.net" }
        @{ Name = "Viber"; WingetId = "Viber.Viber"; Icon = "${f}viber.com" }
        @{ Name = "Element"; WingetId = "Element.Element"; Icon = "${f}element.io" }
        @{ Name = "Guilded"; WingetId = "Guilded.Guilded"; Icon = "${f}guilded.gg" }
        @{ Name = "Ferdium"; WingetId = "Ferdium.Ferdium"; Icon = "${f}ferdium.org" }
        @{ Name = "TeamSpeak"; WingetId = "TeamSpeakSystems.TeamSpeakClient"; Icon = "${f}teamspeak.com" }
        @{ Name = "Mumble"; WingetId = "Mumble.Mumble"; Icon = "${f}mumble.info" }
        @{ Name = "Wire"; WingetId = "Wire.Wire"; Icon = "${f}wire.com" }
        @{ Name = "eM Client"; WingetId = "eMClient.eMClient"; Icon = "${f}emclient.com" }
        @{ Name = "Mailspring"; WingetId = "Foundry376.Mailspring"; Icon = "${f}getmailspring.com" }
        @{ Name = "Betterbird"; WingetId = "Betterbird.Betterbird"; Icon = "${f}betterbird.eu" }
        @{ Name = "Mattermost"; WingetId = "Mattermost.MattermostDesktop"; Icon = "${f}mattermost.com" }
        @{ Name = "Session"; WingetId = "Oxen.Session"; Icon = "${f}getsession.org" }
        @{ Name = "Rocket.Chat"; WingetId = "RocketChat.RocketChat"; Icon = "${f}rocket.chat" }
        @{ Name = "Franz"; WingetId = "MeetFranz.Franz"; Icon = "${f}meetfranz.com" }
        @{ Name = "Rambox"; WingetId = "Rambox.Rambox"; Icon = "${f}rambox.app" }
        @{ Name = "Pidgin"; WingetId = "Pidgin.Pidgin"; Icon = "${f}pidgin.im" }
        @{ Name = "HexChat"; WingetId = "HexChat.HexChat"; Icon = "${f}hexchat.github.io" }
        @{ Name = "Vesktop"; WingetId = "Vencord.Vesktop"; Icon = "${f}vencord.dev" }
        @{ Name = "ArmCord"; WingetId = "ArmCord.ArmCord"; Icon = "${f}armcord.app" }
        @{ Name = "BlueMail"; WingetId = "BlueMail.BlueMail"; Icon = "${f}bluemail.me" }
        @{ Name = "Mailbird"; WingetId = "Mailbird.Mailbird"; Icon = "${f}getmailbird.com" }
        @{ Name = "Tutanota"; WingetId = "Tutanota.Tutanota"; Icon = "${f}tutanota.com" }
        @{ Name = "Linphone"; WingetId = "BelledonneCommunications.Linphone"; Icon = "${f}linphone.org" }
        @{ Name = "Chatterino"; WingetId = "ChatterinoTeam.Chatterino"; Icon = "${f}chatterino.com" }
        @{ Name = "Revolt"; WingetId = "Revolt.RevoltDesktop"; Icon = "${f}revolt.chat" }
        @{ Name = "Jami"; WingetId = "SFLinux.Jami"; Icon = "${f}jami.net" }
        @{ Name = "Unigram"; WingetId = "Telegram.Unigram"; Icon = "${f}unigramdev.github.io" }
        @{ Name = "QTox"; WingetId = "Tox.qTox"; Icon = "${f}qtox.github.io" }
        @{ Name = "Zulip"; WingetId = "Zulip.Zulip"; Icon = "${f}zulipchat.com" }
        @{ Name = "ProtonMail Bridge"; WingetId = "Proton.ProtonMailBridge"; Icon = "${f}proton.me" }
    )

    "Media Players" = @(
        @{ Name = "VLC"; WingetId = "VideoLAN.VLC"; Icon = "${f}videolan.org" }
        @{ Name = "MPC-HC"; WingetId = "clsid2.mpc-hc"; Icon = "${f}github.com" }
        @{ Name = "PotPlayer"; WingetId = "Daum.PotPlayer"; Icon = "${f}potplayer.daum.net" }
        @{ Name = "Kodi"; WingetId = "XBMCFoundation.Kodi"; Icon = "${f}kodi.tv" }
        @{ Name = "K-Lite Codec Pack"; WingetId = "CodecGuide.K-LiteCodecPack.Full"; Icon = "${f}codecguide.com" }
        @{ Name = "KMPlayer"; WingetId = "PandoraTV.KMPlayer"; Icon = "${f}kmplayer.com" }
        @{ Name = "GOM Player"; WingetId = "GOM.GOMPlayer"; Icon = "${f}gomlab.com" }
        @{ Name = "Plex"; WingetId = "Plex.Plex"; Icon = "${f}plex.tv" }
        @{ Name = "Stremio"; WingetId = "Stremio.Stremio"; Icon = "${f}stremio.com" }
        @{ Name = "Jellyfin Media Player"; WingetId = "Jellyfin.JellyfinMediaPlayer"; Icon = "${f}jellyfin.org" }
        @{ Name = "SMPlayer"; WingetId = "SMPlayer.SMPlayer"; Icon = "${f}smplayer.info" }
        @{ Name = "MPV.net"; WingetId = "stax76.mpv.net"; Icon = "${f}github.com" }
        @{ Name = "Plexamp"; WingetId = "Plex.Plexamp"; Icon = "${f}plexamp.com" }
        @{ Name = "Harmonoid"; WingetId = "Harmonoid.Harmonoid"; Icon = "${f}harmonoid.com" }
        @{ Name = "Jellyfin Server"; WingetId = "Jellyfin.Server"; Icon = "${f}jellyfin.org" }
        @{ Name = "Plex Media Server"; WingetId = "Plex.PlexMediaServer"; Icon = "${f}plex.tv" }
        @{ Name = "ImageGlass"; WingetId = "DuongDieuPhap.ImageGlass"; Icon = "${f}imageglass.org" }
    )

    "Music & Audio" = @(
        @{ Name = "Spotify"; WingetId = "Spotify.Spotify"; Icon = "${f}spotify.com" }
        @{ Name = "iTunes"; WingetId = "Apple.iTunes"; Icon = "${f}apple.com" }
        @{ Name = "foobar2000"; WingetId = "PeterPawlowski.foobar2000"; Icon = "${f}foobar2000.org" }
        @{ Name = "AIMP"; WingetId = "AIMP.AIMP"; Icon = "${f}aimp.ru" }
        @{ Name = "MusicBee"; WingetId = "MusicBee.MusicBee"; Icon = "${f}getmusicbee.com" }
        @{ Name = "Audacity"; WingetId = "Audacity.Audacity"; Icon = "${f}audacityteam.org" }
        @{ Name = "Winamp"; WingetId = "Winamp.Winamp"; Icon = "${f}winamp.com" }
        @{ Name = "MediaMonkey"; WingetId = "MediaMonkey.MediaMonkey"; Icon = "${f}mediamonkey.com" }
        @{ Name = "Tidal"; WingetId = "Tidal.Tidal"; Icon = "${f}tidal.com" }
        @{ Name = "Amazon Music"; WingetId = "Amazon.Music"; Icon = "${f}music.amazon.com" }
        @{ Name = "Deezer"; WingetId = "Deezer.Deezer"; Icon = "${f}deezer.com" }
        @{ Name = "Clementine"; WingetId = "Clementine.Clementine"; Icon = "${f}clementine-player.org" }
        @{ Name = "LMMS"; WingetId = "LMMS.LMMS"; Icon = "${f}lmms.io" }
        @{ Name = "MuseScore"; WingetId = "MuseScore.MuseScore"; Icon = "${f}musescore.org" }
        @{ Name = "Strawberry Music Player"; WingetId = "StrawberryMusicPlayer.Strawberry"; Icon = "${f}strawberrymusicplayer.org" }
        @{ Name = "MusicBrainz Picard"; WingetId = "MusicBrainz.Picard"; Icon = "${f}picard.musicbrainz.org" }
        @{ Name = "Ocenaudio"; WingetId = "Ocenaudio.Ocenaudio"; Icon = "${f}ocenaudio.com" }
        @{ Name = "Cider"; WingetId = "CiderCollective.Cider"; Icon = "${f}cider.sh" }
    )

    "Video Tools" = @(
        @{ Name = "HandBrake"; WingetId = "HandBrake.HandBrake"; Icon = "${f}handbrake.fr" }
        @{ Name = "OBS Studio"; WingetId = "OBSProject.OBSStudio"; Icon = "${f}obsproject.com" }
        @{ Name = "Shotcut"; WingetId = "Meltytech.Shotcut"; Icon = "${f}shotcut.org" }
        @{ Name = "Kdenlive"; WingetId = "KDE.Kdenlive"; Icon = "${f}kdenlive.org" }
        @{ Name = "OpenShot"; WingetId = "OpenShot.OpenShot"; Icon = "${f}openshot.org" }
        @{ Name = "FFmpeg"; WingetId = "Gyan.FFmpeg"; Icon = "${f}ffmpeg.org" }
        @{ Name = "MKVToolNix"; WingetId = "MoritzBunkus.MKVToolNix"; Icon = "${f}mkvtoolnix.download" }
        @{ Name = "VidCoder"; WingetId = "RandomEngy.VidCoder"; Icon = "${f}vidcoder.net" }
        @{ Name = "Streamlabs"; WingetId = "Streamlabs.Streamlabs"; Icon = "${f}streamlabs.com" }
        @{ Name = "MediaInfo"; WingetId = "MediaArea.MediaInfo"; Icon = "${f}mediaarea.net" }
        @{ Name = "DaVinci Resolve"; WingetId = "BlackmagicDesign.DaVinciResolve"; Icon = "${f}blackmagicdesign.com" }
        @{ Name = "Avidemux"; WingetId = "Avidemux.Avidemux"; Icon = "${f}avidemux.sourceforge.net" }
        @{ Name = "LosslessCut"; WingetId = "MifiAS.LosslessCut"; Icon = "${f}github.com" }
        @{ Name = "yt-dlp"; WingetId = "yt-dlp.yt-dlp"; Icon = "${f}github.com" }
        @{ Name = "Natron"; WingetId = "NatronGitHub.Natron"; Icon = "${f}natrongithub.github.io" }
        @{ Name = "StaxRip"; WingetId = "StaxRip.StaxRip"; Icon = "${f}github.com" }
        @{ Name = "MediaInfo GUI"; WingetId = "MediaArea.MediaInfo.GUI"; Icon = "${f}mediaarea.net" }
        @{ Name = "Subtitle Edit"; WingetId = "NikolajLykke.SubtitleEdit"; Icon = "${f}nikse.dk" }
        @{ Name = "Aegisub"; WingetId = "Aegisub.Aegisub"; Icon = "${f}github.com" }
        @{ Name = "Videomass"; WingetId = "GianlucaPernigotto.Videomass"; Icon = "${f}jeanslack.github.io" }
        @{ Name = "ImgBurn"; WingetId = "LIGHTNINGUK.ImgBurn"; Icon = "${f}imgburn.com" }
        @{ Name = "NDI Tools"; WingetId = "NDI.NDITools"; Icon = "${f}ndi.video" }
        @{ Name = "Shutter Encoder"; WingetId = "PaulPacifico.ShutterEncoder"; Icon = "${f}shutterencoder.com" }
    )

    "Imaging & Design" = @(
        @{ Name = "GIMP"; WingetId = "GIMP.GIMP"; Icon = "${f}gimp.org" }
        @{ Name = "Paint.NET"; WingetId = "dotPDN.PaintDotNet"; Icon = "${f}getpaint.net" }
        @{ Name = "Krita"; WingetId = "KDE.Krita"; Icon = "${f}krita.org" }
        @{ Name = "Inkscape"; WingetId = "Inkscape.Inkscape"; Icon = "${f}inkscape.org" }
        @{ Name = "Blender"; WingetId = "BlenderFoundation.Blender"; Icon = "${f}blender.org" }
        @{ Name = "IrfanView"; WingetId = "IrfanSkiljan.IrfanView"; Icon = "${f}irfanview.com" }
        @{ Name = "XnView MP"; WingetId = "XnSoft.XnViewMP"; Icon = "${f}xnview.com" }
        @{ Name = "FastStone Viewer"; WingetId = "FastStone.Viewer"; Icon = "${f}faststone.org" }
        @{ Name = "Figma"; WingetId = "Figma.Figma"; Icon = "${f}figma.com" }
        @{ Name = "darktable"; WingetId = "darktable.darktable"; Icon = "${f}darktable.org" }
        @{ Name = "RawTherapee"; WingetId = "RawTherapee.RawTherapee"; Icon = "${f}rawtherapee.com" }
        @{ Name = "DigiKam"; WingetId = "KDE.digiKam"; Icon = "${f}digikam.org" }
        @{ Name = "Pinta"; WingetId = "PintaProject.Pinta"; Icon = "${f}pinta-project.com" }
        @{ Name = "ImageMagick"; WingetId = "ImageMagick.ImageMagick"; Icon = "${f}imagemagick.org" }
        @{ Name = "Scribus"; WingetId = "Scribus.Scribus"; Icon = "${f}scribus.net" }
        @{ Name = "Upscayl"; WingetId = "Upscayl.Upscayl"; Icon = "${f}upscayl.org" }
        @{ Name = "nomacs"; WingetId = "nomacs.nomacs"; Icon = "${f}nomacs.org" }
        @{ Name = "SageThumbs"; WingetId = "CherubicSoftware.SageThumbs"; Icon = "${f}sagethumbs.en.lo4d.com" }
        @{ Name = "Fire Alpaca"; WingetId = "FireAlpaca.FireAlpaca"; Icon = "${f}firealpaca.com" }
        @{ Name = "JPEG View"; WingetId = "sylikc.JPEGView"; Icon = "${f}github.com" }
        @{ Name = "Lunacy"; WingetId = "Icons8.Lunacy"; Icon = "${f}icons8.com" }
        @{ Name = "Affinity Suite"; WingetId = "Canva.Affinity"; Icon = "${f}affinity.serif.com" }
    )

    "Screenshot & Recording" = @(
        @{ Name = "ShareX"; WingetId = "ShareX.ShareX"; Icon = "${f}getsharex.com" }
        @{ Name = "Greenshot"; WingetId = "Greenshot.Greenshot"; Icon = "${f}getgreenshot.org" }
        @{ Name = "Flameshot"; WingetId = "Flameshot.Flameshot"; Icon = "${f}flameshot.org" }
        @{ Name = "ScreenToGif"; WingetId = "NickeManarin.ScreenToGif"; Icon = "${f}screentogif.com" }
        @{ Name = "LightShot"; WingetId = "Skillbrains.Lightshot"; Icon = "${f}app.prntscr.com" }
        @{ Name = "PicPick"; WingetId = "NGWIN.PicPick"; Icon = "${f}picpick.app" }
        @{ Name = "Snagit"; WingetId = "TechSmith.Snagit"; Icon = "${f}techsmith.com" }
        @{ Name = "Camtasia"; WingetId = "TechSmith.Camtasia"; Icon = "${f}techsmith.com" }
        @{ Name = "Gyazo"; WingetId = "Nota.Gyazo"; Icon = "${f}gyazo.com" }
        @{ Name = "LICEcap"; WingetId = "Cockos.LICEcap"; Icon = "${f}cockos.com" }
    )

    "Documents & Office" = @(
        @{ Name = "LibreOffice"; WingetId = "TheDocumentFoundation.LibreOffice"; Icon = "${f}libreoffice.org" }
        @{ Name = "OpenOffice"; WingetId = "Apache.OpenOffice"; Icon = "${f}openoffice.org" }
        @{ Name = "OnlyOffice"; WingetId = "ONLYOFFICE.DesktopEditors"; Icon = "${f}onlyoffice.com" }
        @{ Name = "WPS Office"; WingetId = "Kingsoft.WPSOffice"; Icon = "${f}wps.com" }
        @{ Name = "FreeOffice"; WingetId = "SoftMaker.FreeOffice"; Icon = "${f}freeoffice.com" }
        @{ Name = "MiKTeX (LaTeX)"; WingetId = "MiKTeX.MiKTeX"; Icon = "${f}miktex.org" }
        @{ Name = "Markdown Monster"; WingetId = "WestWind.MarkdownMonster"; Icon = "${f}markdownmonster.west-wind.com" }
        @{ Name = "GhostWriter"; WingetId = "KDE.GhostWriter"; Icon = "${f}ghostwriter.kde.org" }
        @{ Name = "TeXstudio"; WingetId = "TeXstudio.TeXstudio"; Icon = "${f}texstudio.org" }
        @{ Name = "LyX"; WingetId = "LyX.LyX"; Icon = "${f}lyx.org" }
        @{ Name = "CherryTree"; WingetId = "Giuspen.CherryTree"; Icon = "${f}giuspen.com" }
        @{ Name = "Notepad3"; WingetId = "Rizonesoft.Notepad3"; Icon = "${f}rizonesoft.com" }
        @{ Name = "FocusWriter"; WingetId = "GottCode.FocusWriter"; Icon = "${f}gottcode.org" }
    )

    "PDF & E-Books" = @(
        @{ Name = "Adobe Acrobat Reader"; WingetId = "Adobe.Acrobat.Reader.64-bit"; Icon = "${f}adobe.com" }
        @{ Name = "Foxit PDF Reader"; WingetId = "Foxit.FoxitReader"; Icon = "${f}foxit.com" }
        @{ Name = "SumatraPDF"; WingetId = "SumatraPDF.SumatraPDF"; Icon = "${f}sumatrapdfreader.org" }
        @{ Name = "CutePDF Writer"; WingetId = "AcroSoftware.CutePDF.Writer"; Icon = "${f}cutepdf.com" }
        @{ Name = "Calibre"; WingetId = "calibre.calibre"; Icon = "${f}calibre-ebook.com" }
        @{ Name = "Okular"; WingetId = "KDE.Okular"; Icon = "${f}okular.kde.org" }
        @{ Name = "PDFsam Basic"; WingetId = "PDFsam.PDFsamBasic"; Icon = "${f}pdfsam.org" }
        @{ Name = "PDF24 Creator"; WingetId = "geek.PDF24Creator"; Icon = "${f}pdf24.org" }
        @{ Name = "Ghostscript"; WingetId = "ArtifexSoftware.GhostScript"; Icon = "${f}ghostscript.com" }
        @{ Name = "PDFCreator"; WingetId = "pdfforge.PDFCreator"; Icon = "${f}pdfforge.org" }
        @{ Name = "NAPS2"; WingetId = "NAPS2.NAPS2"; Icon = "${f}naps2.com" }
        @{ Name = "Foxit PDF Editor"; WingetId = "Foxit.PhantomPDF"; Icon = "${f}foxit.com" }
        @{ Name = "PDFgear"; WingetId = "PDFgear.PDFgear"; Icon = "${f}pdfgear.com" }
        @{ Name = "Sigil"; WingetId = "Sigil-Ebook.Sigil"; Icon = "${f}sigil-ebook.com" }
    )

    "Note-Taking" = @(
        @{ Name = "Notion"; WingetId = "Notion.Notion"; Icon = "${f}notion.so" }
        @{ Name = "Obsidian"; WingetId = "Obsidian.Obsidian"; Icon = "${f}obsidian.md" }
        @{ Name = "Evernote"; WingetId = "Evernote.Evernote"; Icon = "${f}evernote.com" }
        @{ Name = "Joplin"; WingetId = "Joplin.Joplin"; Icon = "${f}joplinapp.org" }
        @{ Name = "Logseq"; WingetId = "Logseq.Logseq"; Icon = "${f}logseq.com" }
        @{ Name = "Standard Notes"; WingetId = "StandardNotes.StandardNotes"; Icon = "${f}standardnotes.com" }
        @{ Name = "Simplenote"; WingetId = "Automattic.Simplenote"; Icon = "${f}simplenote.com" }
        @{ Name = "Typora"; WingetId = "Typora.Typora"; Icon = "${f}typora.io" }
        @{ Name = "Zettlr"; WingetId = "Zettlr.Zettlr"; Icon = "${f}zettlr.com" }
        @{ Name = "Anytype"; WingetId = "Anytype.Anytype"; Icon = "${f}anytype.io" }
        @{ Name = "AppFlowy"; WingetId = "AppFlowy.AppFlowy"; Icon = "${f}appflowy.io" }
        @{ Name = "Notesnook"; WingetId = "Streetwriters.Notesnook"; Icon = "${f}notesnook.com" }
        @{ Name = "SiYuan"; WingetId = "B3log.SiYuan"; Icon = "${f}b3log.org" }
        @{ Name = "Trilium"; WingetId = "zadam.TriliumNext"; Icon = "${f}github.com" }
        @{ Name = "AFFiNE"; WingetId = "ToEverything.AFFiNE"; Icon = "${f}affine.pro" }
        @{ Name = "Xournal++"; WingetId = "Xournal++.Xournal++"; Icon = "${f}xournalpp.github.io" }
        @{ Name = "Zim Desktop Wiki"; WingetId = "Zimwiki.Zim"; Icon = "${f}zim-wiki.org" }
        @{ Name = "Znote"; WingetId = "alagrede.znote"; Icon = "${f}znote.io" }
        @{ Name = "massCode (Snippet Manager)"; WingetId = "antonreshetov.massCode"; Icon = "${f}masscode.io" }
        @{ Name = "Heynote"; WingetId = "heyman.heynote"; Icon = "${f}heynote.com" }
    )

    "Cloud Storage" = @(
        @{ Name = "Google Drive"; WingetId = "Google.GoogleDrive"; Icon = "${f}drive.google.com" }
        @{ Name = "Dropbox"; WingetId = "Dropbox.Dropbox"; Icon = "${f}dropbox.com" }
        @{ Name = "OneDrive"; WingetId = "Microsoft.OneDrive"; Icon = "${f}onedrive.com" }
        @{ Name = "MEGA"; WingetId = "Mega.MEGASync"; Icon = "${f}mega.io" }
        @{ Name = "pCloud"; WingetId = "pCloud.pCloud"; Icon = "${f}pcloud.com" }
        @{ Name = "Nextcloud"; WingetId = "Nextcloud.NextcloudDesktop"; Icon = "${f}nextcloud.com" }
        @{ Name = "Syncthing"; WingetId = "Syncthing.Syncthing"; Icon = "${f}syncthing.net" }
        @{ Name = "ownCloud Desktop"; WingetId = "ownCloud.ownCloudDesktop"; Icon = "${f}owncloud.com" }
        @{ Name = "Tresorit"; WingetId = "Tresorit.Tresorit"; Icon = "${f}tresorit.com" }
        @{ Name = "Box"; WingetId = "Box.Box"; Icon = "${f}box.com" }
        @{ Name = "iCloud"; WingetId = "Apple.iCloud"; Icon = "${f}apple.com" }
    )

    "Compression" = @(
        @{ Name = "7-Zip"; WingetId = "7zip.7zip"; Icon = "${f}7-zip.org" }
        @{ Name = "WinRAR"; WingetId = "RARLab.WinRAR"; Icon = "${f}rarlab.com" }
        @{ Name = "PeaZip"; WingetId = "Giorgiotani.Peazip"; Icon = "${f}peazip.github.io" }
        @{ Name = "NanaZip"; WingetId = "M2Team.NanaZip"; Icon = "${f}github.com" }
        @{ Name = "Bandizip"; WingetId = "Bandisoft.Bandizip"; Icon = "${f}bandisoft.com" }
    )

    "File Management" = @(
        @{ Name = "Everything"; WingetId = "voidtools.Everything"; Icon = "${f}voidtools.com" }
        @{ Name = "TeraCopy"; WingetId = "CodeSector.TeraCopy"; Icon = "${f}codesector.com" }
        @{ Name = "Total Commander"; WingetId = "Ghisler.TotalCommander"; Icon = "${f}ghisler.com" }
        @{ Name = "Double Commander"; WingetId = "doublecmd.doublecmd"; Icon = "${f}doublecmd.sourceforge.io" }
        @{ Name = "FreeFileSync"; WingetId = "FreeFileSync.FreeFileSync"; Icon = "${f}freefilesync.org" }
        @{ Name = "FastCopy"; WingetId = "FastCopy.FastCopy"; Icon = "${f}fastcopy.jp" }
        @{ Name = "qBittorrent"; WingetId = "qBittorrent.qBittorrent"; Icon = "${f}qbittorrent.org" }
        @{ Name = "Transmission"; WingetId = "Transmission.Transmission"; Icon = "${f}transmissionbt.com" }
        @{ Name = "Deluge"; WingetId = "DelugeTeam.Deluge"; Icon = "${f}deluge-torrent.org" }
        @{ Name = "Free Download Manager"; WingetId = "SoftDeluxe.FreeDownloadManager"; Icon = "${f}freedownloadmanager.org" }
        @{ Name = "JDownloader"; WingetId = "AppWork.JDownloader"; Icon = "${f}jdownloader.org" }
        @{ Name = "Motrix"; WingetId = "AginetLtd.Motrix"; Icon = "${f}motrix.app" }
        @{ Name = "aria2"; WingetId = "aria2.aria2"; Icon = "${f}aria2.github.io" }
        @{ Name = "Bulk Rename Utility"; WingetId = "TGRMNSoftware.BulkRenameUtility"; Icon = "${f}bulkrenameutility.co.uk" }
        @{ Name = "CopyQ"; WingetId = "hluk.CopyQ"; Icon = "${f}hluk.github.io" }
        @{ Name = "Listary"; WingetId = "Listary.Listary"; Icon = "${f}listary.com" }
        @{ Name = "One Commander"; WingetId = "OneCommander.OneCommander"; Icon = "${f}onecommander.com" }
        @{ Name = "MultiCommander"; WingetId = "MultiCommander.MultiCommander"; Icon = "${f}multicommander.com" }
        @{ Name = "Directory Opus"; WingetId = "GPSoftware.DirectoryOpus"; Icon = "${f}gpsoft.com.au" }
        @{ Name = "FileSeek"; WingetId = "BinaryFortress.FileSeek"; Icon = "${f}binary-fortress.com" }
        @{ Name = "SearchMyFiles"; WingetId = "NirSoft.SearchMyFiles"; Icon = "${f}nirsoft.net" }
        @{ Name = "File-Converter"; WingetId = "AdrienAllard.FileConverter"; Icon = "${f}file-converter.io" }
        @{ Name = "WizFile"; WingetId = "AntibodySoftware.WizFile"; Icon = "${f}antibody-software.com" }
        @{ Name = "LockHunter"; WingetId = "CrystalRich.LockHunter"; Icon = "${f}lockhunter.com" }
        @{ Name = "Link Shell extension"; WingetId = "HermannSchinagl.LinkShellExtension"; Icon = "${f}schinagl.priv.at" }
        @{ Name = "Advanced Renamer"; WingetId = "HulubuluSoftware.AdvancedRenamer"; Icon = "${f}advancedrenamer.com" }
        @{ Name = "SpaceSniffer"; WingetId = "UderzoSoftware.SpaceSniffer"; Icon = "${f}uderzo.it" }
        @{ Name = "OpenHashTab"; WingetId = "namazso.OpenHashTab"; Icon = "${f}github.com" }
        @{ Name = "Spacedrive File Manager"; WingetId = "spacedrive.Spacedrive"; Icon = "${f}spacedrive.com" }
        @{ Name = "ExifCleaner"; WingetId = "szTheory.exifcleaner"; Icon = "${f}github.com" }
        @{ Name = "NirSoft HashMyFiles"; WingetId = "NirSoft.HashMyFiles"; Icon = "${f}nirsoft.net" }
    )

    "Security" = @(
        @{ Name = "Malwarebytes"; WingetId = "Malwarebytes.Malwarebytes"; Icon = "${f}malwarebytes.com" }
        @{ Name = "Avast Free"; WingetId = "Avast.AvastFreeAntivirus"; Icon = "${f}avast.com" }
        @{ Name = "AVG Free"; WingetId = "AVG.AVGFreeAntivirus"; Icon = "${f}avg.com" }
        @{ Name = "Avira Free"; WingetId = "Avira.Avira"; Icon = "${f}avira.com" }
        @{ Name = "SUPERAntiSpyware"; WingetId = "SUPERAntiSpyware.SUPERAntiSpyware"; Icon = "${f}superantispyware.com" }
        @{ Name = "AdwCleaner"; WingetId = "Malwarebytes.AdwCleaner"; Icon = "${f}malwarebytes.com" }
        @{ Name = "GlassWire"; WingetId = "GlassWire.GlassWire"; Icon = "${f}glasswire.com" }
        @{ Name = "simplewall"; WingetId = "henrypp.simplewall"; Icon = "${f}henrypp.org" }
        @{ Name = "Kaspersky Free"; WingetId = "Kaspersky.KasperskyFree"; Icon = "${f}kaspersky.com" }
        @{ Name = "Portmaster"; WingetId = "Safing.Portmaster"; Icon = "${f}safing.io" }
        @{ Name = "Windows Firewall Control"; WingetId = "BiniSoft.WindowsFirewallControl"; Icon = "${f}binisoft.org" }
        @{ Name = "Wazuh."; WingetId = "Wazuh.WazuhAgent"; Icon = "${f}wazuh.com" }
        @{ Name = "HitmanPro"; WingetId = "Sophos.HitmanPro"; Icon = "${f}hitmanpro.com" }
        @{ Name = "Bitdefender"; WingetId = "Bitdefender.Bitdefender"; Icon = "${f}bitdefender.com" }
        @{ Name = "ESET Security"; WingetId = "ESET.Security"; Icon = "${f}eset.com" }
        @{ Name = "Spybot Anti-Beacon"; WingetId = "SaferNetworking.SpybotAntiBeacon"; Icon = "${f}safer-networking.org" }
    )

    "Passwords & Encryption" = @(
        @{ Name = "Bitwarden"; WingetId = "Bitwarden.Bitwarden"; Icon = "${f}bitwarden.com" }
        @{ Name = "KeePassXC"; WingetId = "KeePassXCTeam.KeePassXC"; Icon = "${f}keepassxc.org" }
        @{ Name = "KeePass"; WingetId = "DominikReichl.KeePass"; Icon = "${f}keepass.info" }
        @{ Name = "1Password"; WingetId = "AgileBits.1Password"; Icon = "${f}1password.com" }
        @{ Name = "LastPass"; WingetId = "LogMeIn.LastPass"; Icon = "${f}lastpass.com" }
        @{ Name = "NordPass"; WingetId = "NordSecurity.NordPass"; Icon = "${f}nordpass.com" }
        @{ Name = "Dashlane"; WingetId = "Dashlane.Dashlane"; Icon = "${f}dashlane.com" }
        @{ Name = "VeraCrypt"; WingetId = "IDRIX.VeraCrypt"; Icon = "${f}veracrypt.fr" }
        @{ Name = "Cryptomator"; WingetId = "Cryptomator.Cryptomator"; Icon = "${f}cryptomator.org" }
        @{ Name = "GPG4Win"; WingetId = "GnuPG.Gpg4win"; Icon = "${f}gpg4win.org" }
        @{ Name = "Enpass"; WingetId = "Enpass.Enpass"; Icon = "${f}enpass.io" }
        @{ Name = "ProtonPass"; WingetId = "Proton.ProtonPass"; Icon = "${f}proton.me" }
        @{ Name = "AuthMe"; WingetId = "Levminer.Authme"; Icon = "${f}authme.levminer.com" }
    )

    "VPN & Privacy" = @(
        @{ Name = "NordVPN"; WingetId = "NordVPN.NordVPN"; Icon = "${f}nordvpn.com" }
        @{ Name = "ExpressVPN"; WingetId = "ExpressVPN.ExpressVPN"; Icon = "${f}expressvpn.com" }
        @{ Name = "ProtonVPN"; WingetId = "ProtonTechnologies.ProtonVPN"; Icon = "${f}protonvpn.com" }
        @{ Name = "Windscribe"; WingetId = "Windscribe.Windscribe"; Icon = "${f}windscribe.com" }
        @{ Name = "Mullvad VPN"; WingetId = "MullvadVPN.MullvadVPN"; Icon = "${f}mullvad.net" }
        @{ Name = "WireGuard"; WingetId = "WireGuard.WireGuard"; Icon = "${f}wireguard.com" }
        @{ Name = "Tailscale"; WingetId = "tailscale.tailscale"; Icon = "${f}tailscale.com" }
        @{ Name = "Cloudflare WARP"; WingetId = "Cloudflare.Warp"; Icon = "${f}cloudflare.com" }
        @{ Name = "Private Internet Access"; WingetId = "PrivateInternetAccess.PrivateInternetAccess"; Icon = "${f}privateinternetaccess.com" }
        @{ Name = "Surfshark"; WingetId = "Surfshark.Surfshark"; Icon = "${f}surfshark.com" }
        @{ Name = "IVPN"; WingetId = "IVPN.IVPN"; Icon = "${f}ivpn.net" }
        @{ Name = "CyberGhost"; WingetId = "CyberGhostSA.CyberGhostVPN"; Icon = "${f}cyberghostvpn.com" }
        @{ Name = "TunnelBear"; WingetId = "TunnelBear.TunnelBear"; Icon = "${f}tunnelbear.com" }
        @{ Name = "Hide.me"; WingetId = "eVenture.HideMe"; Icon = "${f}hide.me" }
    )

    "Networking & Remote" = @(
        @{ Name = "TeamViewer"; WingetId = "TeamViewer.TeamViewer"; Icon = "${f}teamviewer.com" }
        @{ Name = "AnyDesk"; WingetId = "AnyDeskSoftwareGmbH.AnyDesk"; Icon = "${f}anydesk.com" }
        @{ Name = "RustDesk"; WingetId = "RustDesk.RustDesk"; Icon = "${f}rustdesk.com" }
        @{ Name = "Parsec"; WingetId = "Parsec.Parsec"; Icon = "${f}parsec.app" }
        @{ Name = "PuTTY"; WingetId = "PuTTY.PuTTY"; Icon = "${f}putty.org" }
        @{ Name = "WinSCP"; WingetId = "WinSCP.WinSCP"; Icon = "${f}winscp.net" }
        @{ Name = "FileZilla"; WingetId = "TimKosse.FileZilla.Client"; Icon = "${f}filezilla-project.org" }
        @{ Name = "Wireshark"; WingetId = "WiresharkFoundation.Wireshark"; Icon = "${f}wireshark.org" }
        @{ Name = "Advanced IP Scanner"; WingetId = "Famatech.AdvancedIPScanner"; Icon = "${f}advanced-ip-scanner.com" }
        @{ Name = "Angry IP Scanner"; WingetId = "angryip.ipscan"; Icon = "${f}angryip.org" }
        @{ Name = "mRemoteNG"; WingetId = "mRemoteNG.mRemoteNG"; Icon = "${f}mremoteng.org" }
        @{ Name = "Nmap"; WingetId = "Insecure.Nmap"; Icon = "${f}nmap.org" }
        @{ Name = "NetBird"; WingetId = "netbird.netbird"; Icon = "${f}netbird.io" }
        @{ Name = "MobaXterm"; WingetId = "Mobatek.MobaXterm"; Icon = "${f}mobaxterm.mobatek.net" }
        @{ Name = "OpenVPN Connect"; WingetId = "OpenVPNTechnologies.OpenVPNConnect"; Icon = "${f}openvpn.net" }
        @{ Name = "ZeroTier One"; WingetId = "ZeroTier.ZeroTierOne"; Icon = "${f}zerotier.com" }
        @{ Name = "Termius"; WingetId = "Termius.Termius"; Icon = "${f}termius.com" }
        @{ Name = "RealVNC Viewer"; WingetId = "RealVNC.VNCViewer"; Icon = "${f}realvnc.com" }
        @{ Name = "TightVNC"; WingetId = "GlavSoft.TightVNC"; Icon = "${f}tightvnc.com" }
        @{ Name = "Proxifier"; WingetId = "Initex.Proxifier"; Icon = "${f}proxifier.com" }
        @{ Name = "NetSetMan"; WingetId = "NetSetMan.NetSetMan"; Icon = "${f}netsetman.com" }
        @{ Name = "SmartFTP"; WingetId = "SmartSoft.SmartFTP"; Icon = "${f}smartftp.com" }
        @{ Name = "Cyberduck"; WingetId = "Cyberduck.Cyberduck"; Icon = "${f}cyberduck.io" }
        @{ Name = "Royal TS"; WingetId = "code4ward.RoyalTS"; Icon = "${f}royalapps.com" }
        @{ Name = "Remote Desktop Manager"; WingetId = "Devolutions.RemoteDesktopManager"; Icon = "${f}devolutions.net" }
        @{ Name = "KDE Connect"; WingetId = "KDE.KDEConnect"; Icon = "${f}community.kde.org" }
        @{ Name = "LocalSend"; WingetId = "LocalSend.LocalSend"; Icon = "${f}localsend.org" }
        @{ Name = "RDCMan"; WingetId = "Microsoft.Sysinternals.RDCMan"; Icon = "${f}learn.microsoft.com" }
        @{ Name = "Magic Wormhole"; WingetId = "magic-wormhole.magic-wormhole"; Icon = "${f}github.com" }
        @{ Name = "croc"; WingetId = "schollz.croc"; Icon = "${f}github.com" }
        @{ Name = "UltraVNC"; WingetId = "uvncbvba.UltraVnc"; Icon = "${f}uvnc.com" }
        @{ Name = "XPipe"; WingetId = "xpipe-io.xpipe"; Icon = "${f}xpipe.io" }
        @{ Name = "Insecure Ncat"; WingetId = "Insecure.Npcap"; Icon = "${f}npcap.com" }
    )

    "Code Editors & IDEs" = @(
        @{ Name = "VS Code"; WingetId = "Microsoft.VisualStudioCode"; Icon = "${f}code.visualstudio.com" }
        @{ Name = "Cursor"; WingetId = "Anysphere.Cursor"; Icon = "${f}cursor.com" }
        @{ Name = "Sublime Text 4"; WingetId = "SublimeHQ.SublimeText.4"; Icon = "${f}sublimetext.com" }
        @{ Name = "Notepad++"; WingetId = "Notepad++.Notepad++"; Icon = "${f}notepad-plus-plus.org" }
        @{ Name = "Visual Studio 2022 Community"; WingetId = "Microsoft.VisualStudio.2022.Community"; Icon = "${f}visualstudio.microsoft.com" }
        @{ Name = "JetBrains IntelliJ IDEA CE"; WingetId = "JetBrains.IntelliJIDEA.Community"; Icon = "${f}jetbrains.com" }
        @{ Name = "JetBrains PyCharm CE"; WingetId = "JetBrains.PyCharm.Community"; Icon = "${f}jetbrains.com" }
        @{ Name = "JetBrains WebStorm"; WingetId = "JetBrains.WebStorm"; Icon = "${f}jetbrains.com" }
        @{ Name = "JetBrains Rider"; WingetId = "JetBrains.Rider"; Icon = "${f}jetbrains.com" }
        @{ Name = "JetBrains GoLand"; WingetId = "JetBrains.GoLand"; Icon = "${f}jetbrains.com" }
        @{ Name = "JetBrains CLion"; WingetId = "JetBrains.CLion"; Icon = "${f}jetbrains.com" }
        @{ Name = "Android Studio"; WingetId = "Google.AndroidStudio"; Icon = "${f}developer.android.com" }
        @{ Name = "Vim"; WingetId = "vim.vim"; Icon = "${f}vim.org" }
        @{ Name = "Neovim"; WingetId = "Neovim.Neovim"; Icon = "${f}neovim.io" }
        @{ Name = "Zed"; WingetId = "Zed.Zed"; Icon = "${f}zed.dev" }
        @{ Name = "Kate"; WingetId = "KDE.Kate"; Icon = "${f}kate-editor.org" }
        @{ Name = "Emacs"; WingetId = "GNU.Emacs"; Icon = "${f}gnu.org" }
        @{ Name = "Eclipse IDE"; WingetId = "EclipseFoundation.Eclipse.Java"; Icon = "${f}eclipse.org" }
        @{ Name = "Apache NetBeans"; WingetId = "Apache.NetBeans"; Icon = "${f}netbeans.apache.org" }
        @{ Name = "Pulsar Edit"; WingetId = "Pulsar-Edit.Pulsar"; Icon = "${f}pulsar-edit.dev" }
        @{ Name = "VSCodium"; WingetId = "VSCodium.VSCodium"; Icon = "${f}vscodium.com" }
        @{ Name = "Lapce"; WingetId = "Lapce.Lapce"; Icon = "${f}lapce.dev" }
        @{ Name = "CodeBlocks"; WingetId = "CodeBlocks.CodeBlocks"; Icon = "${f}codeblocks.org" }
        @{ Name = "Geany"; WingetId = "Geany.Geany"; Icon = "${f}geany.org" }
        @{ Name = "BlueJ"; WingetId = "BlueJ.BlueJ"; Icon = "${f}bluej.org" }
        @{ Name = "Thonny"; WingetId = "AivarAnnamaa.Thonny"; Icon = "${f}thonny.org" }
        @{ Name = "RustRover"; WingetId = "JetBrains.RustRover"; Icon = "${f}jetbrains.com" }
        @{ Name = "Writerside"; WingetId = "JetBrains.Writerside"; Icon = "${f}jetbrains.com" }
        @{ Name = "Fleet"; WingetId = "JetBrains.Fleet"; Icon = "${f}jetbrains.com" }
        @{ Name = "Eclipse C/C++"; WingetId = "EclipseFoundation.Eclipse.CPP"; Icon = "${f}eclipse.org" }
        @{ Name = "PhpStorm"; WingetId = "JetBrains.PhpStorm"; Icon = "${f}jetbrains.com" }
        @{ Name = "Helix"; WingetId = "Helix.Helix"; Icon = "${f}helix-editor.com" }
        @{ Name = "Visual Studio Code Insiders"; WingetId = "Microsoft.VisualStudioCode.Insiders"; Icon = "${f}code.visualstudio.com" }
        @{ Name = "RubyMine"; WingetId = "JetBrains.RubyMine"; Icon = "${f}jetbrains.com" }
        @{ Name = "Windsurf"; WingetId = "Codeium.Windsurf"; Icon = "${f}codeium.com" }
        @{ Name = "VS 2022 Build Tools"; WingetId = "Microsoft.VisualStudio.2022.BuildTools"; Icon = "${f}visualstudio.microsoft.com" }
    )

    "Developer Tools" = @(
        @{ Name = "Git"; WingetId = "Git.Git"; Icon = "${f}git-scm.com" }
        @{ Name = "GitHub Desktop"; WingetId = "GitHub.GitHubDesktop"; Icon = "${f}github.com" }
        @{ Name = "GitHub CLI"; WingetId = "GitHub.cli"; Icon = "${f}cli.github.com" }
        @{ Name = "Docker Desktop"; WingetId = "Docker.DockerDesktop"; Icon = "${f}docker.com" }
        @{ Name = "Postman"; WingetId = "Postman.Postman"; Icon = "${f}postman.com" }
        @{ Name = "Insomnia"; WingetId = "Kong.Insomnia"; Icon = "${f}insomnia.rest" }
        @{ Name = "Bruno"; WingetId = "Bruno.Bruno"; Icon = "${f}usebruno.com" }
        @{ Name = "DBeaver"; WingetId = "dbeaver.dbeaver"; Icon = "${f}dbeaver.io" }
        @{ Name = "HeidiSQL"; WingetId = "HeidiSQL.HeidiSQL"; Icon = "${f}heidisql.com" }
        @{ Name = "Azure Data Studio"; WingetId = "Microsoft.AzureDataStudio"; Icon = "${f}azure.microsoft.com" }
        @{ Name = "WinMerge"; WingetId = "WinMerge.WinMerge"; Icon = "${f}winmerge.org" }
        @{ Name = "Beyond Compare"; WingetId = "ScooterSoftware.BeyondCompare4"; Icon = "${f}scootersoftware.com" }
        @{ Name = "Sourcetree"; WingetId = "Atlassian.Sourcetree"; Icon = "${f}sourcetreeapp.com" }
        @{ Name = "GitKraken"; WingetId = "Axosoft.GitKraken"; Icon = "${f}gitkraken.com" }
        @{ Name = "Fork"; WingetId = "Fork.Fork"; Icon = "${f}git-fork.com" }
        @{ Name = "ngrok"; WingetId = "ngrok.ngrok"; Icon = "${f}ngrok.com" }
        @{ Name = "Fiddler Classic"; WingetId = "Telerik.Fiddler.Classic"; Icon = "${f}telerik.com" }
        @{ Name = "Git Extensions"; WingetId = "GitExtensionsTeam.GitExtensions"; Icon = "${f}gitextensions.github.io" }
        @{ Name = "HTTPie Desktop"; WingetId = "HTTPie.HTTPie"; Icon = "${f}httpie.io" }
        @{ Name = "Lazarus IDE"; WingetId = "Lazarus.Lazarus"; Icon = "${f}lazarus-ide.org" }
        @{ Name = "LINQPad"; WingetId = "LINQPad.LINQPad.8"; Icon = "${f}linqpad.net" }
        @{ Name = "WinDbg"; WingetId = "Microsoft.WinDbg"; Icon = "${f}microsoft.com" }
        @{ Name = "Carnac"; WingetId = "code52.Carnac"; Icon = "${f}carnackeys.com" }
        @{ Name = "Meld"; WingetId = "Meld.Meld"; Icon = "${f}meldmerge.org" }
        @{ Name = "KDiff3"; WingetId = "KDE.KDiff3"; Icon = "${f}kdiff3.sourceforge.net" }
        @{ Name = "DaxStudio"; WingetId = "DaxStudio.DaxStudio"; Icon = "${f}daxstudio.org" }
        @{ Name = "DevToys"; WingetId = "DevToys-app.DevToys"; Icon = "${f}devtoys.app" }
        @{ Name = "Docker CLI"; WingetId = "Docker.DockerCLI"; Icon = "${f}docker.com" }
        @{ Name = "Git Butler"; WingetId = "GitButler.GitButler"; Icon = "${f}gitbutler.com" }
        @{ Name = "Gitify"; WingetId = "Gitify.Gitify"; Icon = "${f}gitify.io" }
        @{ Name = "Jetbrains Toolbox"; WingetId = "JetBrains.Toolbox"; Icon = "${f}jetbrains.com" }
        @{ Name = "HxD Hex Editor"; WingetId = "MHNexus.HxD"; Icon = "${f}mh-nexus.de" }
        @{ Name = "Code With Mu (Mu Editor)"; WingetId = "Mu.Mu"; Icon = "${f}codewith.mu" }
        @{ Name = "Sublime Merge"; WingetId = "SublimeHQ.SublimeMerge"; Icon = "${f}sublimemerge.com" }
        @{ Name = "Fiddler Everywhere"; WingetId = "Telerik.FiddlerEverywhere"; Icon = "${f}telerik.com" }
        @{ Name = "TablePlus"; WingetId = "TablePlus.TablePlus"; Icon = "${f}tableplus.com" }
        @{ Name = "GitHub Copilot"; WingetId = "GitHub.Copilot"; Icon = "${f}github.com" }
    )

    "Cloud & DevOps" = @(
        @{ Name = "AWS CLI"; WingetId = "Amazon.AWSCLI"; Icon = "${f}aws.amazon.com" }
        @{ Name = "Azure CLI"; WingetId = "Microsoft.AzureCLI"; Icon = "${f}azure.microsoft.com" }
        @{ Name = "Google Cloud SDK"; WingetId = "Google.CloudSDK"; Icon = "${f}cloud.google.com" }
        @{ Name = "Terraform"; WingetId = "Hashicorp.Terraform"; Icon = "${f}terraform.io" }
        @{ Name = "Kubernetes CLI"; WingetId = "Kubernetes.kubectl"; Icon = "${f}kubernetes.io" }
        @{ Name = "Helm"; WingetId = "Helm.Helm"; Icon = "${f}helm.sh" }
        @{ Name = "Podman"; WingetId = "RedHat.Podman"; Icon = "${f}podman.io" }
        @{ Name = "Lens"; WingetId = "Mirantis.Lens"; Icon = "${f}k8slens.dev" }
        @{ Name = "Vagrant"; WingetId = "Hashicorp.Vagrant"; Icon = "${f}vagrantup.com" }
        @{ Name = "Pulumi"; WingetId = "Pulumi.Pulumi"; Icon = "${f}pulumi.com" }
        @{ Name = "Packer"; WingetId = "Hashicorp.Packer"; Icon = "${f}packer.io" }
        @{ Name = "Consul"; WingetId = "Hashicorp.Consul"; Icon = "${f}consul.io" }
        @{ Name = "Vault"; WingetId = "Hashicorp.Vault"; Icon = "${f}vaultproject.io" }
        @{ Name = "Nomad"; WingetId = "Hashicorp.Nomad"; Icon = "${f}nomadproject.io" }
        @{ Name = "Grafana"; WingetId = "GrafanaLabs.Grafana"; Icon = "${f}grafana.com" }
        @{ Name = "K9s"; WingetId = "derailed.k9s"; Icon = "${f}k9scli.io" }
    )

    "Terminals & Shells" = @(
        @{ Name = "Windows Terminal"; WingetId = "Microsoft.WindowsTerminal"; Icon = "${f}github.com" }
        @{ Name = "PowerShell 7"; WingetId = "Microsoft.PowerShell"; Icon = "${f}github.com" }
        @{ Name = "Tabby"; WingetId = "Eugeny.Tabby"; Icon = "${f}tabby.sh" }
        @{ Name = "Hyper"; WingetId = "Vercel.Hyper"; Icon = "${f}hyper.is" }
        @{ Name = "Alacritty"; WingetId = "Alacritty.Alacritty"; Icon = "${f}alacritty.org" }
        @{ Name = "WezTerm"; WingetId = "wez.wezterm"; Icon = "${f}wezfurlong.org" }
        @{ Name = "ConEmu"; WingetId = "Maximus5.ConEmu"; Icon = "${f}conemu.github.io" }
        @{ Name = "Oh My Posh"; WingetId = "JanDeDobbeleer.OhMyPosh"; Icon = "${f}ohmyposh.dev" }
        @{ Name = "Nushell"; WingetId = "Nushell.Nushell"; Icon = "${f}nushell.sh" }
        @{ Name = "Cmder"; WingetId = "Cmder.Cmder"; Icon = "${f}cmder.app" }
    )

    "CLI Tools" = @(
        @{ Name = "ripgrep"; WingetId = "BurntSushi.ripgrep.MSVC"; Icon = "${f}github.com" }
        @{ Name = "fd"; WingetId = "sharkdp.fd"; Icon = "${f}github.com" }
        @{ Name = "bat"; WingetId = "sharkdp.bat"; Icon = "${f}github.com" }
        @{ Name = "fzf"; WingetId = "junegunn.fzf"; Icon = "${f}github.com" }
        @{ Name = "jq"; WingetId = "jqlang.jq"; Icon = "${f}jqlang.github.io" }
        @{ Name = "delta"; WingetId = "dandavison.delta"; Icon = "${f}github.com" }
        @{ Name = "eza"; WingetId = "eza-community.eza"; Icon = "${f}github.com" }
        @{ Name = "lazygit"; WingetId = "JesseDuffield.lazygit"; Icon = "${f}github.com" }
        @{ Name = "Clink"; WingetId = "chrisant996.Clink"; Icon = "${f}github.com" }
        @{ Name = "zoxide"; WingetId = "ajeetdsouza.zoxide"; Icon = "${f}github.com" }
        @{ Name = "hyperfine"; WingetId = "sharkdp.hyperfine"; Icon = "${f}github.com" }
        @{ Name = "dust"; WingetId = "bootandy.dust"; Icon = "${f}github.com" }
        @{ Name = "bottom"; WingetId = "ClementTsang.bottom"; Icon = "${f}github.com" }
        @{ Name = "tokei"; WingetId = "XAMPPRocky.tokei"; Icon = "${f}github.com" }
        @{ Name = "Starship Prompt"; WingetId = "Starship.Starship"; Icon = "${f}starship.rs" }
        @{ Name = "tealdeer"; WingetId = "dbrgn.tealdeer"; Icon = "${f}github.com" }
        @{ Name = "glow"; WingetId = "charmbracelet.glow"; Icon = "${f}github.com" }
        @{ Name = "just"; WingetId = "Casey.Just"; Icon = "${f}just.systems" }
        @{ Name = "watchexec"; WingetId = "Watchexec.Watchexec"; Icon = "${f}watchexec.github.io" }
        @{ Name = "gitui"; WingetId = "extrawurst.gitui"; Icon = "${f}github.com" }
        @{ Name = "difftastic"; WingetId = "Wilfred.difftastic"; Icon = "${f}github.com" }
        @{ Name = "lsd"; WingetId = "lsd-rs.lsd"; Icon = "${f}github.com" }
        @{ Name = "xh"; WingetId = "ducaale.xh"; Icon = "${f}github.com" }
        @{ Name = "sd"; WingetId = "chmln.sd"; Icon = "${f}github.com" }
        @{ Name = "procs"; WingetId = "dalance.procs"; Icon = "${f}github.com" }
        @{ Name = "broot"; WingetId = "Canop.broot"; Icon = "${f}dystroy.org" }
        @{ Name = "navi"; WingetId = "denisidoro.navi"; Icon = "${f}github.com" }
        @{ Name = "hurl"; WingetId = "Orange-OpenSource.hurl"; Icon = "${f}hurl.dev" }
        @{ Name = "bandwhich"; WingetId = "imsnif.bandwhich"; Icon = "${f}github.com" }
        @{ Name = "oha"; WingetId = "hatoo.oha"; Icon = "${f}github.com" }
        @{ Name = "duf"; WingetId = "muesli.duf"; Icon = "${f}github.com" }
        @{ Name = "Fastfetch"; WingetId = "Fastfetch-cli.Fastfetch"; Icon = "${f}github.com" }
        @{ Name = "GNU Wget"; WingetId = "JernejSimoncic.Wget"; Icon = "${f}gnu.org" }
        @{ Name = "cURL"; WingetId = "cURL.cURL"; Icon = "${f}curl.se" }
        @{ Name = "Gsudo"; WingetId = "gerardog.gsudo"; Icon = "${f}gerardog.github.io" }
        @{ Name = "Neofetch"; WingetId = "nepnep.neofetch-win"; Icon = "${f}github.com" }
        @{ Name = "gping"; WingetId = "orf.gping"; Icon = "${f}github.com" }
    )

    "Runtimes & SDKs" = @(
        @{ Name = "Python 3.13"; WingetId = "Python.Python.3.13"; Icon = "${f}python.org" }
        @{ Name = "Python 3.12"; WingetId = "Python.Python.3.12"; Icon = "${f}python.org" }
        @{ Name = "Node.js LTS"; WingetId = "OpenJS.NodeJS.LTS"; Icon = "${f}nodejs.org" }
        @{ Name = "Node.js Current"; WingetId = "OpenJS.NodeJS"; Icon = "${f}nodejs.org" }
        @{ Name = "Java 21 JRE"; WingetId = "EclipseAdoptium.Temurin.21.JRE"; Icon = "${f}adoptium.net" }
        @{ Name = "Java 21 JDK"; WingetId = "EclipseAdoptium.Temurin.21.JDK"; Icon = "${f}adoptium.net" }
        @{ Name = "Java 17 JDK"; WingetId = "EclipseAdoptium.Temurin.17.JDK"; Icon = "${f}adoptium.net" }
        @{ Name = ".NET 8 Desktop Runtime"; WingetId = "Microsoft.DotNet.DesktopRuntime.8"; Icon = "${f}dotnet.microsoft.com" }
        @{ Name = ".NET 8 SDK"; WingetId = "Microsoft.DotNet.SDK.8"; Icon = "${f}dotnet.microsoft.com" }
        @{ Name = ".NET 9 Desktop Runtime"; WingetId = "Microsoft.DotNet.DesktopRuntime.9"; Icon = "${f}dotnet.microsoft.com" }
        @{ Name = ".NET 9 SDK"; WingetId = "Microsoft.DotNet.SDK.9"; Icon = "${f}dotnet.microsoft.com" }
        @{ Name = "Go"; WingetId = "GoLang.Go"; Icon = "${f}go.dev" }
        @{ Name = "Rustup"; WingetId = "Rustlang.Rustup"; Icon = "${f}rust-lang.org" }
        @{ Name = "Ruby"; WingetId = "RubyInstallerTeam.RubyWithDevKit.3.2"; Icon = "${f}rubyinstaller.org" }
        @{ Name = "Bun"; WingetId = "Oven-sh.Bun"; Icon = "${f}bun.sh" }
        @{ Name = "Deno"; WingetId = "DenoLand.Deno"; Icon = "${f}deno.com" }
        @{ Name = "Yarn"; WingetId = "Yarn.Yarn"; Icon = "${f}yarnpkg.com" }
        @{ Name = "pnpm"; WingetId = "pnpm.pnpm"; Icon = "${f}pnpm.io" }
        @{ Name = "Anaconda"; WingetId = "Anaconda.Anaconda3"; Icon = "${f}anaconda.com" }
        @{ Name = "Zig"; WingetId = "zig.zig"; Icon = "${f}ziglang.org" }
        @{ Name = "Miniconda"; WingetId = "Anaconda.Miniconda3"; Icon = "${f}anaconda.com" }
        @{ Name = "Strawberry Perl"; WingetId = "StrawberryPerl.StrawberryPerl"; Icon = "${f}strawberryperl.com" }
        @{ Name = "Gradle"; WingetId = "Gradle.Gradle"; Icon = "${f}gradle.org" }
        @{ Name = "Maven"; WingetId = "Apache.Maven"; Icon = "${f}maven.apache.org" }
        @{ Name = "PHP"; WingetId = "PHP.PHP"; Icon = "${f}php.net" }
        @{ Name = "Dart SDK"; WingetId = "Google.DartSDK"; Icon = "${f}dart.dev" }
        @{ Name = "Flutter"; WingetId = "Google.Flutter"; Icon = "${f}flutter.dev" }
        @{ Name = "Kotlin"; WingetId = "JetBrains.Kotlin.Compiler"; Icon = "${f}kotlinlang.org" }
        @{ Name = "Scala"; WingetId = "Scala.Scala.3"; Icon = "${f}scala-lang.org" }
        @{ Name = "Elixir"; WingetId = "ElixirLang.Elixir"; Icon = "${f}elixir-lang.org" }
        @{ Name = "CMake"; WingetId = "Kitware.CMake"; Icon = "${f}cmake.org" }
        @{ Name = "LLVM"; WingetId = "LLVM.LLVM"; Icon = "${f}llvm.org" }
        @{ Name = "MSYS2"; WingetId = "MSYS2.MSYS2"; Icon = "${f}msys2.org" }
        @{ Name = "Amazon Corretto 21"; WingetId = "Amazon.Corretto.21"; Icon = "${f}corretto.aws" }
        @{ Name = "Amazon Corretto 11 (LTS)"; WingetId = "Amazon.Corretto.11.JDK"; Icon = "${f}aws.amazon.com" }
        @{ Name = "Amazon Corretto 17 (LTS)"; WingetId = "Amazon.Corretto.17.JDK"; Icon = "${f}aws.amazon.com" }
        @{ Name = "Amazon Corretto 21 (LTS)"; WingetId = "Amazon.Corretto.21.JDK"; Icon = "${f}aws.amazon.com" }
        @{ Name = "Amazon Corretto 8 (LTS)"; WingetId = "Amazon.Corretto.8.JDK"; Icon = "${f}aws.amazon.com" }
        @{ Name = "Node Version Manager"; WingetId = "CoreyButler.NVMforWindows"; Icon = "${f}github.com" }
        @{ Name = ".NET Desktop Runtime 3.1"; WingetId = "Microsoft.DotNet.DesktopRuntime.3_1"; Icon = "${f}dotnet.microsoft.com" }
        @{ Name = ".NET Desktop Runtime 5"; WingetId = "Microsoft.DotNet.DesktopRuntime.5"; Icon = "${f}dotnet.microsoft.com" }
        @{ Name = ".NET Desktop Runtime 6"; WingetId = "Microsoft.DotNet.DesktopRuntime.6"; Icon = "${f}dotnet.microsoft.com" }
        @{ Name = ".NET Desktop Runtime 7"; WingetId = "Microsoft.DotNet.DesktopRuntime.7"; Icon = "${f}dotnet.microsoft.com" }
        @{ Name = "NuGet"; WingetId = "Microsoft.NuGet"; Icon = "${f}nuget.org" }
        @{ Name = "Rust"; WingetId = "Rustlang.Rust.MSVC"; Icon = "${f}rust-lang.org" }
        @{ Name = "Fast Node Manager"; WingetId = "Schniz.fnm"; Icon = "${f}github.com" }
        @{ Name = "Swift toolchain"; WingetId = "Swift.Toolchain"; Icon = "${f}swift.org" }
        @{ Name = "Pixi"; WingetId = "prefix-dev.pixi"; Icon = "${f}pixi.sh" }
        @{ Name = "Adoptium JRE 17"; WingetId = "EclipseAdoptium.Temurin.17.JRE"; Icon = "${f}adoptium.net" }
        @{ Name = "WSL"; WingetId = "Microsoft.WSL"; Icon = "${f}learn.microsoft.com" }
        @{ Name = "DirectX Runtime"; WingetId = "Microsoft.DirectX"; Icon = "${f}microsoft.com" }
        @{ Name = "XNA Framework"; WingetId = "Microsoft.XNARedist"; Icon = "${f}microsoft.com" }
    )

    "VC++ Redistributables" = @(
        @{ Name = "VC++ 2015-2022 x64"; WingetId = "Microsoft.VCRedist.2015+.x64"; Icon = "${f}visualstudio.microsoft.com" }
        @{ Name = "VC++ 2015-2022 x86"; WingetId = "Microsoft.VCRedist.2015+.x86"; Icon = "${f}visualstudio.microsoft.com" }
        @{ Name = "VC++ 2013 x64"; WingetId = "Microsoft.VCRedist.2013.x64"; Icon = "${f}visualstudio.microsoft.com" }
        @{ Name = "VC++ 2013 x86"; WingetId = "Microsoft.VCRedist.2013.x86"; Icon = "${f}visualstudio.microsoft.com" }
        @{ Name = "VC++ 2012 x64"; WingetId = "Microsoft.VCRedist.2012.x64"; Icon = "${f}visualstudio.microsoft.com" }
        @{ Name = "VC++ 2012 x86"; WingetId = "Microsoft.VCRedist.2012.x86"; Icon = "${f}visualstudio.microsoft.com" }
        @{ Name = "VC++ 2010 x64"; WingetId = "Microsoft.VCRedist.2010.x64"; Icon = "${f}visualstudio.microsoft.com" }
        @{ Name = "VC++ 2010 x86"; WingetId = "Microsoft.VCRedist.2010.x86"; Icon = "${f}visualstudio.microsoft.com" }
    )

    "System Utilities" = @(
        @{ Name = "PowerToys"; WingetId = "Microsoft.PowerToys"; Icon = "${f}learn.microsoft.com" }
        @{ Name = "CCleaner"; WingetId = "Piriform.CCleaner"; Icon = "${f}ccleaner.com" }
        @{ Name = "Revo Uninstaller"; WingetId = "RevoUninstaller.RevoUninstaller"; Icon = "${f}revouninstaller.com" }
        @{ Name = "Bulk Crap Uninstaller"; WingetId = "Klocman.BulkCrapUninstaller"; Icon = "${f}bcuninstaller.com" }
        @{ Name = "IObit Uninstaller"; WingetId = "IObit.Uninstaller"; Icon = "${f}iobit.com" }
        @{ Name = "Glary Utilities"; WingetId = "Glarysoft.GlaryUtilities"; Icon = "${f}glarysoft.com" }
        @{ Name = "BleachBit"; WingetId = "BleachBit.BleachBit"; Icon = "${f}bleachbit.org" }
        @{ Name = "WinDirStat"; WingetId = "WinDirStat.WinDirStat"; Icon = "${f}windirstat.net" }
        @{ Name = "WizTree"; WingetId = "AntibodySoftware.WizTree"; Icon = "${f}diskanalyzer.com" }
        @{ Name = "TreeSize Free"; WingetId = "JAMSoftware.TreeSize.Free"; Icon = "${f}jam-software.com" }
        @{ Name = "AutoHotkey"; WingetId = "AutoHotkey.AutoHotkey"; Icon = "${f}autohotkey.com" }
        @{ Name = "Autoruns"; WingetId = "Microsoft.Sysinternals.Autoruns"; Icon = "${f}learn.microsoft.com" }
        @{ Name = "Process Explorer"; WingetId = "Microsoft.Sysinternals.ProcessExplorer"; Icon = "${f}learn.microsoft.com" }
        @{ Name = "Open-Shell Menu"; WingetId = "Open-Shell.Open-Shell-Menu"; Icon = "${f}open-shell.github.io" }
        @{ Name = "Rufus"; WingetId = "Rufus.Rufus"; Icon = "${f}rufus.ie" }
        @{ Name = "Etcher"; WingetId = "Balena.Etcher"; Icon = "${f}balena.io" }
        @{ Name = "Ventoy"; WingetId = "Ventoy.Ventoy"; Icon = "${f}ventoy.net" }
        @{ Name = "Ditto Clipboard"; WingetId = "Ditto.Ditto"; Icon = "${f}ditto-cp.sourceforge.io" }
        @{ Name = "Recuva"; WingetId = "Piriform.Recuva"; Icon = "${f}ccleaner.com" }
        @{ Name = "Fan Control"; WingetId = "Rem0o.FanControl"; Icon = "${f}github.com" }
        @{ Name = "Winaero Tweaker"; WingetId = "Winaero.Tweaker"; Icon = "${f}winaero.com" }
        @{ Name = "O&O ShutUp10++"; WingetId = "OO-Software.ShutUp10"; Icon = "${f}oo-software.com" }
        @{ Name = "Barrier"; WingetId = "DebaucheeOpenSourceGroup.Barrier"; Icon = "${f}github.com" }
        @{ Name = "GlazeWM"; WingetId = "glzr-io.glazewm"; Icon = "${f}glzr.io" }
        @{ Name = "AltSnap"; WingetId = "AltSnap.AltSnap"; Icon = "${f}github.com" }
        @{ Name = "NirCmd"; WingetId = "NirSoft.NirCmd"; Icon = "${f}nirsoft.net" }
        @{ Name = "NirLauncher"; WingetId = "NirSoft.NirLauncher"; Icon = "${f}nirsoft.net" }
        @{ Name = "TCPView"; WingetId = "Microsoft.Sysinternals.TCPView"; Icon = "${f}microsoft.com" }
        @{ Name = "BGInfo"; WingetId = "Microsoft.Sysinternals.BGInfo"; Icon = "${f}microsoft.com" }
        @{ Name = "Junction"; WingetId = "Microsoft.Sysinternals.Junction"; Icon = "${f}microsoft.com" }
        @{ Name = "Strings"; WingetId = "Microsoft.Sysinternals.Strings"; Icon = "${f}microsoft.com" }
        @{ Name = "ShellMenuView"; WingetId = "NirSoft.ShellMenuView"; Icon = "${f}nirsoft.net" }
        @{ Name = "ShellExView"; WingetId = "NirSoft.ShellExView"; Icon = "${f}nirsoft.net" }
        @{ Name = "PatchMyPC"; WingetId = "PatchMyPC.PatchMyPC"; Icon = "${f}patchmypc.com" }
        @{ Name = "Sysinternals Suite"; WingetId = "Microsoft.Sysinternals.Suite"; Icon = "${f}microsoft.com" }
        @{ Name = "Disk2VHD"; WingetId = "Microsoft.Sysinternals.Disk2vhd"; Icon = "${f}microsoft.com" }
        @{ Name = "Desktops"; WingetId = "Microsoft.Sysinternals.Desktops"; Icon = "${f}microsoft.com" }
        @{ Name = "Process Lasso"; WingetId = "BitSum.ProcessLasso"; Icon = "${f}bitsum.com" }
        @{ Name = "DISMTools"; WingetId = "CodingWondersSoftware.DISMTools.Stable"; Icon = "${f}github.com" }
        @{ Name = "EFI Boot Editor"; WingetId = "EFIBootEditor.EFIBootEditor"; Icon = "${f}easyuefi.com" }
        @{ Name = "Dual Monitor Tools"; WingetId = "GNE.DualMonitorTools"; Icon = "${f}dualmonitortool.sourceforge.net" }
        @{ Name = "Snappy Driver Installer Origin"; WingetId = "GlennDelahoy.SnappyDriverInstallerOrigin"; Icon = "${f}glenn.delahoy.com" }
        @{ Name = "Compact GUI"; WingetId = "IridiumIO.CompactGUI"; Icon = "${f}github.com" }
        @{ Name = "JoyToKey"; WingetId = "JTKsoftware.JoyToKey"; Icon = "${f}joytokey.net" }
        @{ Name = "ZoomIt"; WingetId = "Microsoft.Sysinternals.ZoomIt"; Icon = "${f}learn.microsoft.com" }
        @{ Name = "Windows PC Health Check"; WingetId = "Microsoft.WindowsPCHealthCheck"; Icon = "${f}support.microsoft.com" }
        @{ Name = "NTLite"; WingetId = "Nlitesoft.NTLite"; Icon = "${f}ntlite.com" }
        @{ Name = "OPAutoClicker"; WingetId = "OPAutoClicker.OPAutoClicker"; Icon = "${f}opautoclicker.com" }
        @{ Name = "SuperF4"; WingetId = "StefanSundin.Superf4"; Icon = "${f}stefansundin.github.io" }
        @{ Name = "Display Driver Uninstaller"; WingetId = "Wagnardsoft.DisplayDriverUninstaller"; Icon = "${f}wagnardsoft.com" }
        @{ Name = "Wise Program Uninstaller (WiseCleaner)"; WingetId = "WiseCleaner.WiseProgramUninstaller"; Icon = "${f}wisecleaner.com" }
        @{ Name = "WiseToys"; WingetId = "WiseCleaner.WiseToys"; Icon = "${f}toys.wisecleaner.com" }
        @{ Name = "Handle"; WingetId = "Microsoft.Sysinternals.Handle"; Icon = "${f}microsoft.com" }
        @{ Name = "Samsung DeX"; WingetId = "Samsung.DeX"; Icon = "${f}samsung.com" }
    )

    "Hardware & Diagnostics" = @(
        @{ Name = "HWiNFO"; WingetId = "REALiX.HWiNFO"; Icon = "${f}hwinfo.com" }
        @{ Name = "CPU-Z"; WingetId = "CPUID.CPU-Z"; Icon = "${f}cpuid.com" }
        @{ Name = "GPU-Z"; WingetId = "TechPowerUp.GPU-Z"; Icon = "${f}techpowerup.com" }
        @{ Name = "HWMonitor"; WingetId = "CPUID.HWMonitor"; Icon = "${f}cpuid.com" }
        @{ Name = "CrystalDiskInfo"; WingetId = "CrystalDewWorld.CrystalDiskInfo"; Icon = "${f}crystalmark.info" }
        @{ Name = "CrystalDiskMark"; WingetId = "CrystalDewWorld.CrystalDiskMark"; Icon = "${f}crystalmark.info" }
        @{ Name = "Speccy"; WingetId = "Piriform.Speccy"; Icon = "${f}ccleaner.com" }
        @{ Name = "Core Temp"; WingetId = "ALCPU.CoreTemp"; Icon = "${f}alcpu.com" }
        @{ Name = "FurMark"; WingetId = "Geeks3D.FurMark"; Icon = "${f}geeks3d.com" }
        @{ Name = "OCCT"; WingetId = "OCBASE.OCCT"; Icon = "${f}ocbase.com" }
        @{ Name = "NVCleanstall"; WingetId = "TechPowerUp.NVCleanstall"; Icon = "${f}techpowerup.com" }
        @{ Name = "Process Monitor"; WingetId = "Microsoft.Sysinternals.ProcessMonitor"; Icon = "${f}learn.microsoft.com" }
        @{ Name = "MSI Afterburner"; WingetId = "Guru3D.Afterburner"; Icon = "${f}msi.com" }
        @{ Name = "ThrottleStop"; WingetId = "TechPowerUp.ThrottleStop"; Icon = "${f}techpowerup.com" }
        @{ Name = "AIDA64 Extreme"; WingetId = "FinalWire.AIDA64.Extreme"; Icon = "${f}aida64.com" }
        @{ Name = "BlueScreenView"; WingetId = "NirSoft.BlueScreenView"; Icon = "${f}nirsoft.net" }
        @{ Name = "BatteryInfoView"; WingetId = "NirSoft.BatteryInfoView"; Icon = "${f}nirsoft.net" }
        @{ Name = "Lenovo Legion Toolkit"; WingetId = "BartoszCichecki.LenovoLegionToolkit"; Icon = "${f}github.com" }
        @{ Name = "CapFrameX"; WingetId = "CXWorld.CapFrameX"; Icon = "${f}capframex.com" }
        @{ Name = "Intel-PresentMon"; WingetId = "Intel.PresentMon.Beta"; Icon = "${f}game.intel.com" }
        @{ Name = "OpenRGB"; WingetId = "OpenRGB.OpenRGB"; Icon = "${f}openrgb.org" }
        @{ Name = "SignalRGB"; WingetId = "WhirlwindFX.SignalRgb"; Icon = "${f}signalrgb.com" }
        @{ Name = "Monitorian"; WingetId = "emoacht.Monitorian"; Icon = "${f}github.com" }
        @{ Name = "WirelessNetView"; WingetId = "NirSoft.WirelessNetView"; Icon = "${f}nirsoft.net" }
        @{ Name = "Logitech G HUB"; WingetId = "Logitech.GHUB"; Icon = "${f}logitechg.com" }
        @{ Name = "Logitech Options+"; WingetId = "Logitech.OptionsPlus"; Icon = "${f}logitech.com" }
        @{ Name = "Corsair iCUE"; WingetId = "Corsair.iCUE.4"; Icon = "${f}corsair.com" }
        @{ Name = "Razer Synapse 3"; WingetId = "RazerInc.RazerInstaller.Synapse3"; Icon = "${f}razer.com" }
        @{ Name = "SteelSeries GG"; WingetId = "SteelSeries.GG"; Icon = "${f}steelseries.com" }
        @{ Name = "Elgato Stream Deck"; WingetId = "Elgato.StreamDeck"; Icon = "${f}elgato.com" }
        @{ Name = "Elgato Wave Link"; WingetId = "Elgato.WaveLink"; Icon = "${f}elgato.com" }
        @{ Name = "Elgato Camera Hub"; WingetId = "Elgato.CameraHub"; Icon = "${f}elgato.com" }
    )

    "Virtualization" = @(
        @{ Name = "VirtualBox"; WingetId = "Oracle.VirtualBox"; Icon = "${f}virtualbox.org" }
        @{ Name = "VMware Workstation Player"; WingetId = "VMware.WorkstationPlayer"; Icon = "${f}vmware.com" }
        @{ Name = "Multipass"; WingetId = "Canonical.Multipass"; Icon = "${f}multipass.run" }
        @{ Name = "QEMU"; WingetId = "SoftwareFreedomConservancy.QEMU"; Icon = "${f}qemu.org" }
        @{ Name = "Sandboxie-Plus"; WingetId = "Sandboxie.Plus"; Icon = "${f}sandboxie-plus.com" }
        @{ Name = "VMware Workstation Pro"; WingetId = "VMware.WorkstationPro"; Icon = "${f}vmware.com" }
        @{ Name = "Open Hardware Monitor"; WingetId = "OpenHardwareMonitor.OpenHardwareMonitor"; Icon = "${f}openhardwaremonitor.org" }
    )

    "Gaming" = @(
        @{ Name = "Steam"; WingetId = "Valve.Steam"; Icon = "${f}steampowered.com" }
        @{ Name = "Epic Games Launcher"; WingetId = "EpicGames.EpicGamesLauncher"; Icon = "${f}epicgames.com" }
        @{ Name = "GOG Galaxy"; WingetId = "GOG.Galaxy"; Icon = "${f}gog.com" }
        @{ Name = "EA App"; WingetId = "ElectronicArts.EADesktop"; Icon = "${f}ea.com" }
        @{ Name = "Ubisoft Connect"; WingetId = "Ubisoft.Connect"; Icon = "${f}ubisoft.com" }
        @{ Name = "Battle.net"; WingetId = "Blizzard.BattleNet"; Icon = "${f}blizzard.com" }
        @{ Name = "Playnite"; WingetId = "Playnite.Playnite"; Icon = "${f}playnite.link" }
        @{ Name = "Heroic Games Launcher"; WingetId = "HeroicGamesLauncher.HeroicGamesLauncher"; Icon = "${f}heroicgameslauncher.com" }
        @{ Name = "RetroArch"; WingetId = "Libretro.RetroArch"; Icon = "${f}retroarch.com" }
        @{ Name = "Amazon Games"; WingetId = "Amazon.Games"; Icon = "${f}gaming.amazon.com" }
        @{ Name = "Prism Launcher"; WingetId = "PrismLauncher.PrismLauncher"; Icon = "${f}prismlauncher.org" }
        @{ Name = "DS4Windows"; WingetId = "Ryochan7.DS4Windows"; Icon = "${f}ds4-windows.com" }
        @{ Name = "Moonlight"; WingetId = "MoonlightGameStreamingProject.Moonlight"; Icon = "${f}moonlight-stream.org" }
        @{ Name = "Sunshine"; WingetId = "LizardByte.Sunshine"; Icon = "${f}github.com" }
        @{ Name = "itch.io"; WingetId = "ItchIo.itch"; Icon = "${f}itch.io" }
        @{ Name = "ScummVM"; WingetId = "ScummVM.ScummVM"; Icon = "${f}scummvm.org" }
        @{ Name = "RPCS3"; WingetId = "RPCS3.RPCS3"; Icon = "${f}rpcs3.net" }
        @{ Name = "OpenMW"; WingetId = "OpenMW.OpenMW"; Icon = "${f}openmw.org" }
        @{ Name = "Clone Hero"; WingetId = "CloneHeroTeam.CloneHero"; Icon = "${f}clonehero.net" }
        @{ Name = "GeForce NOW"; WingetId = "Nvidia.GeForceNow"; Icon = "${f}nvidia.com" }
        @{ Name = "PS Remote Play"; WingetId = "PlayStation.PSRemotePlay"; Icon = "${f}remoteplay.dl.playstation.net" }
        @{ Name = "SideQuestVR"; WingetId = "SideQuestVR.SideQuest"; Icon = "${f}sidequestvr.com" }
        @{ Name = "TCNO Account Switcher"; WingetId = "TechNobo.TcNoAccountSwitcher"; Icon = "${f}github.com" }
        @{ Name = "Virtual Desktop Streamer"; WingetId = "VirtualDesktop.Streamer"; Icon = "${f}vrdesktop.net" }
        @{ Name = "Legendary"; WingetId = "derrod.legendary"; Icon = "${f}github.com" }
        @{ Name = "Minecraft Launcher"; WingetId = "Mojang.MinecraftLauncher"; Icon = "${f}minecraft.net" }
        @{ Name = "Rockstar Games Launcher"; WingetId = "RockstarGames.Launcher"; Icon = "${f}rockstargames.com" }
        @{ Name = "CurseForge"; WingetId = "Overwolf.CurseForge"; Icon = "${f}curseforge.com" }
    )

    "AI & LLM Tools" = @(
        @{ Name = "Ollama"; WingetId = "Ollama.Ollama"; Icon = "${f}ollama.com" }
        @{ Name = "LM Studio"; WingetId = "ElementLabs.LMStudio"; Icon = "${f}lmstudio.ai" }
        @{ Name = "Jan"; WingetId = "Homebrew.jan"; Icon = "${f}jan.ai" }
        @{ Name = "GPT4All"; WingetId = "NomicAI.GPT4All"; Icon = "${f}gpt4all.io" }
        @{ Name = "AnythingLLM"; WingetId = "MintplexLabs.AnythingLLM"; Icon = "${f}anythingllm.com" }
        @{ Name = "Open WebUI"; WingetId = "OpenWebUI.OpenWebUI"; Icon = "${f}openwebui.com" }
        @{ Name = "KoboldCPP"; WingetId = "LostRuins.KoboldCpp"; Icon = "${f}github.com" }
        @{ Name = "Claude Desktop"; WingetId = "Anthropic.Claude"; Icon = "${f}claude.ai" }
        @{ Name = "Claude Code"; WingetId = "Anthropic.ClaudeCode"; Icon = "${f}claude.ai" }
        @{ Name = "Msty"; WingetId = "CloudStack.Msty"; Icon = "${f}msty.app" }
        @{ Name = "Chatbox"; WingetId = "Bin-Huang.Chatbox"; Icon = "${f}chatboxai.app" }
    )

    "Audio Production" = @(
        @{ Name = "REAPER"; WingetId = "Cockos.REAPER"; Icon = "${f}reaper.fm" }
        @{ Name = "VoiceMeeter"; WingetId = "VB-Audio.Voicemeeter"; Icon = "${f}vb-audio.com" }
        @{ Name = "VoiceMeeter Banana"; WingetId = "VB-Audio.Voicemeeter.Banana"; Icon = "${f}vb-audio.com" }
        @{ Name = "VoiceMeeter Potato"; WingetId = "VB-Audio.Voicemeeter.Potato"; Icon = "${f}vb-audio.com" }
        @{ Name = "VB-Cable Virtual Audio"; WingetId = "VB-Audio.VBVirtualCable"; Icon = "${f}vb-audio.com" }
        @{ Name = "Mixxx"; WingetId = "Mixxx.Mixxx"; Icon = "${f}mixxx.org" }
        @{ Name = "Tenacity"; WingetId = "Tenacity.Tenacity"; Icon = "${f}tenacityaudio.org" }
        @{ Name = "FxSound"; WingetId = "FxSound.FxSound"; Icon = "${f}fxsound.com" }
        @{ Name = "Mp3tag (Metadata Audio Editor)"; WingetId = "Mp3tag.Mp3tag"; Icon = "${f}mp3tag.de" }
        @{ Name = "TagScanner (Tag Scanner)"; WingetId = "SergeySerkov.TagScanner"; Icon = "${f}xdlab.ru" }
        @{ Name = "Equalizer APO"; WingetId = "PeterStiworthy.EqualizerAPO"; Icon = "${f}sourceforge.net" }
    )

    "3D Printing & CAD" = @(
        @{ Name = "UltiMaker Cura"; WingetId = "UltiMaker.Cura"; Icon = "${f}ultimaker.com" }
        @{ Name = "PrusaSlicer"; WingetId = "Prusa3D.PrusaSlicer"; Icon = "${f}prusa3d.com" }
        @{ Name = "Bambu Studio"; WingetId = "Bambulab.Bambustudio"; Icon = "${f}bambulab.com" }
        @{ Name = "OrcaSlicer"; WingetId = "SoftFever.OrcaSlicer"; Icon = "${f}github.com" }
        @{ Name = "FreeCAD"; WingetId = "FreeCAD.FreeCAD"; Icon = "${f}freecad.org" }
        @{ Name = "OpenSCAD"; WingetId = "OpenSCAD.OpenSCAD"; Icon = "${f}openscad.org" }
        @{ Name = "KiCad"; WingetId = "KiCad.KiCad"; Icon = "${f}kicad.org" }
        @{ Name = "LibreCAD"; WingetId = "LibreCAD.LibreCAD"; Icon = "${f}librecad.org" }
        @{ Name = "Sweet Home 3D"; WingetId = "eTeks.SweetHome3D"; Icon = "${f}sweethome3d.com" }
        @{ Name = "MeshLab"; WingetId = "ISTI-CNR.MeshLab"; Icon = "${f}meshlab.net" }
    )

    "Desktop Customization" = @(
        @{ Name = "Rainmeter"; WingetId = "Rainmeter.Rainmeter"; Icon = "${f}rainmeter.net" }
        @{ Name = "TranslucentTB"; WingetId = "CharlesMilette.TranslucentTB"; Icon = "${f}github.com" }
        @{ Name = "Lively Wallpaper"; WingetId = "rocksdanister.LivelyWallpaper"; Icon = "${f}livelywallpaper.net" }
        @{ Name = "EarTrumpet"; WingetId = "File-New-Project.EarTrumpet"; Icon = "${f}eartrumpet.app" }
        @{ Name = "Flow Launcher"; WingetId = "Flow-Launcher.Flow-Launcher"; Icon = "${f}flowlauncher.com" }
        @{ Name = "ModernFlyouts"; WingetId = "ModernFlyouts-Community.ModernFlyouts"; Icon = "${f}github.com" }
        @{ Name = "Twinkle Tray"; WingetId = "xanderfrangos.twinkletray"; Icon = "${f}twinkletray.com" }
        @{ Name = "f.lux"; WingetId = "flux.flux"; Icon = "${f}justgetflux.com" }
        @{ Name = "QuickLook"; WingetId = "QL-Win.QuickLook"; Icon = "${f}github.com" }
        @{ Name = "WinDynamicDesktop"; WingetId = "t1m0thyj.WinDynamicDesktop"; Icon = "${f}github.com" }
        @{ Name = "ExplorerPatcher"; WingetId = "valinet.ExplorerPatcher"; Icon = "${f}github.com" }
        @{ Name = "Windhawk"; WingetId = "RamenSoftware.Windhawk"; Icon = "${f}windhawk.net" }
        @{ Name = "Files App"; WingetId = "Files-community.Files"; Icon = "${f}files.community" }
        @{ Name = "StartAllBack"; WingetId = "StartIsBack.StartAllBack"; Icon = "${f}startallback.com" }
        @{ Name = "TaskbarX"; WingetId = "ChrisAndriessen.TaskbarX"; Icon = "${f}github.com" }
        @{ Name = "SoundSwitch"; WingetId = "AntoineAflworker.SoundSwitch"; Icon = "${f}soundswitch.aaflalo.me" }
        @{ Name = "WinPaletter"; WingetId = "Abdelrhman-AK.WinPaletter"; Icon = "${f}github.com" }
        @{ Name = "Windows Auto Dark Mode"; WingetId = "Armin2208.WindowsAutoNightMode"; Icon = "${f}github.com" }
        @{ Name = "Borderless Gaming"; WingetId = "Codeusa.BorderlessGaming"; Icon = "${f}github.com" }
        @{ Name = "Nilesoft Shell"; WingetId = "Nilesoft.Shell"; Icon = "${f}nilesoft.org" }
        @{ Name = "MSEdgeRedirect"; WingetId = "rcmaehl.MSEdgeRedirect"; Icon = "${f}github.com" }
        @{ Name = "OFGB (Oh Frick Go Back)"; WingetId = "xM4ddy.OFGB"; Icon = "${f}github.com" }
        @{ Name = "Komorebi"; WingetId = "LGUG2Z.komorebi"; Icon = "${f}github.com" }
    )

    "Backup & Sync" = @(
        @{ Name = "AOMEI Backupper"; WingetId = "AOMEITechnology.AOMEIBackupper"; Icon = "${f}aomei.com" }
        @{ Name = "Restic"; WingetId = "restic.restic"; Icon = "${f}restic.net" }
        @{ Name = "Rclone"; WingetId = "Rclone.Rclone"; Icon = "${f}rclone.org" }
        @{ Name = "Kopia"; WingetId = "KopiaUI.KopiaUI"; Icon = "${f}kopia.io" }
        @{ Name = "SyncBack Free"; WingetId = "2BrightSparks.SyncBackFree"; Icon = "${f}2brightsparks.com" }
        @{ Name = "Resilio Sync"; WingetId = "ResilioInc.ResilioSync"; Icon = "${f}resilio.com" }
        @{ Name = "Syncthingtray"; WingetId = "Martchus.syncthingtray"; Icon = "${f}github.com" }
        @{ Name = "SyncTrayzor"; WingetId = "SyncTrayzor.SyncTrayzor"; Icon = "${f}github.com" }
        @{ Name = "Duplicati"; WingetId = "Duplicati.Duplicati"; Icon = "${f}duplicati.com" }
    )

    "Database Tools" = @(
        @{ Name = "SSMS"; WingetId = "Microsoft.SQLServerManagementStudio"; Icon = "${f}microsoft.com" }
        @{ Name = "pgAdmin 4"; WingetId = "PostgreSQL.pgAdmin"; Icon = "${f}pgadmin.org" }
        @{ Name = "DB Browser for SQLite"; WingetId = "DBBrowserForSQLite.DBBrowserForSQLite"; Icon = "${f}sqlitebrowser.org" }
        @{ Name = "MongoDB Compass"; WingetId = "MongoDB.Compass.Full"; Icon = "${f}mongodb.com" }
        @{ Name = "JetBrains DataGrip"; WingetId = "JetBrains.DataGrip"; Icon = "${f}jetbrains.com" }
        @{ Name = "MySQL Workbench"; WingetId = "Oracle.MySQLWorkbench"; Icon = "${f}mysql.com" }
        @{ Name = "Beekeeper Studio"; WingetId = "baborosch.beekeeperstudio"; Icon = "${f}beekeeperstudio.io" }
        @{ Name = "RedisInsight"; WingetId = "Redis.RedisInsight"; Icon = "${f}redis.io" }
    )

    "Emulators" = @(
        @{ Name = "PCSX2"; WingetId = "PCSX2Team.PCSX2"; Icon = "${f}pcsx2.net" }
        @{ Name = "PPSSPP"; WingetId = "PPSSPPTeam.PPSSPP"; Icon = "${f}ppsspp.org" }
        @{ Name = "DuckStation"; WingetId = "stenzek.DuckStation"; Icon = "${f}github.com" }
        @{ Name = "Cemu"; WingetId = "Cemu.Cemu"; Icon = "${f}cemu.info" }
        @{ Name = "Dolphin Emulator"; WingetId = "DolphinEmulator.DolphinBeta"; Icon = "${f}dolphin-emu.org" }
        @{ Name = "MAME"; WingetId = "MAME.MAME"; Icon = "${f}mamedev.org" }
        @{ Name = "Ryujinx"; WingetId = "Ryujinx.Ryujinx"; Icon = "${f}ryujinx.org" }
        @{ Name = "xemu"; WingetId = "xemu-project.xemu"; Icon = "${f}xemu.app" }
        @{ Name = "Project64"; WingetId = "Project64.Project64"; Icon = "${f}pj64-emu.com" }
        @{ Name = "melonDS"; WingetId = "melonDS.melonDS"; Icon = "${f}melonds.kuribo64.net" }
        @{ Name = "mGBA"; WingetId = "mGBA.mGBA"; Icon = "${f}mgba.io" }
        @{ Name = "Emulation Station"; WingetId = "Emulationstation.Emulationstation"; Icon = "${f}emulationstation.org" }
    )

    "Science & Education" = @(
        @{ Name = "GNU Octave"; WingetId = "GNU.Octave"; Icon = "${f}octave.org" }
        @{ Name = "R"; WingetId = "RProject.R"; Icon = "${f}r-project.org" }
        @{ Name = "RStudio Desktop"; WingetId = "Posit.RStudio"; Icon = "${f}posit.co" }
        @{ Name = "Zotero"; WingetId = "DigitalScholar.Zotero"; Icon = "${f}zotero.org" }
        @{ Name = "Julia"; WingetId = "Julialang.Julia"; Icon = "${f}julialang.org" }
        @{ Name = "GeoGebra"; WingetId = "GeoGebra.Classic"; Icon = "${f}geogebra.org" }
        @{ Name = "Mendeley Desktop"; WingetId = "Elsevier.MendeleyDesktop"; Icon = "${f}mendeley.com" }
        @{ Name = "JupyterLab Desktop"; WingetId = "JupyterLab.JupyterLabDesktop"; Icon = "${f}jupyter.org" }
        @{ Name = "Gephi"; WingetId = "Gephi.Gephi"; Icon = "${f}gephi.org" }
        @{ Name = "QGIS"; WingetId = "OSGeo.QGIS"; Icon = "${f}qgis.org" }
        @{ Name = "Scilab"; WingetId = "Scilab.Scilab"; Icon = "${f}scilab.org" }
        @{ Name = "GnuPlot"; WingetId = "gnuplot.gnuplot"; Icon = "${f}gnuplot.info" }
        @{ Name = "Maxima"; WingetId = "Maxima.Maxima"; Icon = "${f}maxima.sourceforge.io" }
        @{ Name = "Celestia"; WingetId = "CelestiaProject.Celestia"; Icon = "${f}celestiaproject.space" }
        @{ Name = "KStars"; WingetId = "KDE.KStars"; Icon = "${f}kstars.kde.org" }
    )

    "Productivity" = @(
        @{ Name = "Todoist"; WingetId = "Doist.Todoist"; Icon = "${f}todoist.com" }
        @{ Name = "TickTick"; WingetId = "Appest.TickTick"; Icon = "${f}ticktick.com" }
        @{ Name = "Camo"; WingetId = "Reincubate.Camo"; Icon = "${f}reincubate.com" }
        @{ Name = "Clockify"; WingetId = "Clockify.Clockify"; Icon = "${f}clockify.me" }
        @{ Name = "Toggl Track"; WingetId = "Toggl.TogglTrack"; Icon = "${f}toggl.com" }
        @{ Name = "Espanso"; WingetId = "Espanso.Espanso"; Icon = "${f}espanso.org" }
        @{ Name = "Raycast"; WingetId = "Raycast.Raycast"; Icon = "${f}raycast.com" }
        @{ Name = "Stretchly"; WingetId = "hovancik.Stretchly"; Icon = "${f}hovancik.net" }
        @{ Name = "Notion Calendar"; WingetId = "Notion.NotionCalendar"; Icon = "${f}notion.so" }
        @{ Name = "Power Automate"; WingetId = "Microsoft.PowerAutomateDesktop"; Icon = "${f}microsoft.com" }
        @{ Name = "Power BI"; WingetId = "Microsoft.PowerBI"; Icon = "${f}microsoft.com" }
        @{ Name = "Fritzing"; WingetId = "Fritzing.Fritzing"; Icon = "${f}fritzing.org" }
        @{ Name = "Grammarly"; WingetId = "Grammarly.Grammarly"; Icon = "${f}grammarly.com" }
        @{ Name = "Canva"; WingetId = "Canva.Canva"; Icon = "${f}canva.com" }
    )

    "Package Managers" = @(
        @{ Name = "UniGetUI"; WingetId = "MartiCliment.UniGetUI"; Icon = "${f}marticliment.com" }
        @{ Name = "Scoop"; WingetId = "Scoop.Scoop"; Icon = "${f}scoop.sh" }
        @{ Name = "Chocolatey"; WingetId = "Chocolatey.Chocolatey"; Icon = "${f}chocolatey.org" }
    )

    "Other" = @(
        @{ Name = "Google Earth Pro"; WingetId = "Google.EarthPro"; Icon = "${f}earth.google.com" }
        @{ Name = "Raspberry Pi Imager"; WingetId = "RaspberryPiFoundation.RaspberryPiImager"; Icon = "${f}raspberrypi.com" }
        @{ Name = "Arduino IDE"; WingetId = "ArduinoSA.IDE.stable"; Icon = "${f}arduino.cc" }
        @{ Name = "Unity Hub"; WingetId = "Unity.UnityHub"; Icon = "${f}unity.com" }
        @{ Name = "Godot Engine"; WingetId = "GodotEngine.GodotEngine"; Icon = "${f}godotengine.org" }
        @{ Name = "Stellarium"; WingetId = "Stellarium.Stellarium"; Icon = "${f}stellarium.org" }
        @{ Name = "Anki"; WingetId = "Anki.Anki"; Icon = "${f}apps.ankiweb.net" }
        @{ Name = "KeeWeb"; WingetId = "AntellePtyLtd.KeeWeb"; Icon = "${f}keeweb.info" }
        @{ Name = "GnuCash"; WingetId = "GnuCash.GnuCash"; Icon = "${f}gnucash.org" }
        @{ Name = "FontForge"; WingetId = "FontForge.FontForge"; Icon = "${f}fontforge.org" }
        @{ Name = "KMyMoney"; WingetId = "KDE.KMyMoney"; Icon = "${f}kmymoney.org" }
        @{ Name = "Marble"; WingetId = "KDE.Marble"; Icon = "${f}marble.kde.org" }
        @{ Name = "Xtreme Download Manager"; WingetId = "subhra74.XtremeDownloadManager"; Icon = "${f}xtremedownloadmanager.com" }
    )
}
if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $catalogPath = Join-Path $PSScriptRoot "catalog\winget.json"
    $externalCatalog = ConvertFrom-WingetterCatalogJson -Path $catalogPath
    if ($externalCatalog) {
        $Script:SoftwareDatabase = $externalCatalog
    }
}

# ============================================================================
# WINGET DETECTION AND INSTALLATION
# ============================================================================

function Test-WinGet {
    try {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            $version = (winget --version) 2>$null
            return @{ Installed = $true; Version = $version; Path = $wingetPath.Source }
        }
    } catch { }
    return @{ Installed = $false; Version = $null; Path = $null }
}

function Install-WinGet {
    $wingetStatus = Test-WinGet
    if ($wingetStatus.Installed) { return $true }
    try {
        $tempDir = "$env:TEMP\WinGetInstall"
        if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
        $vcLibsPath = "$tempDir\VCLibs.appx"
        $uiXamlPath = "$tempDir\UIXaml.appx"
        Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile $vcLibsPath -UseBasicParsing
        Invoke-WebRequest -Uri "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx" -OutFile $uiXamlPath -UseBasicParsing
        $headers = @{ "User-Agent" = "PowerShell" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -Headers $headers -ErrorAction Stop
        $wingetUrl = ($release.assets | Where-Object { $_.name -match "\.msixbundle$" }).browser_download_url
        $licenseUrl = ($release.assets | Where-Object { $_.name -match "License.*\.xml$" }).browser_download_url
        $wingetPath = "$tempDir\WinGet.msixbundle"
        $licensePath = "$tempDir\License.xml"
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPath -UseBasicParsing
        if ($licenseUrl) { Invoke-WebRequest -Uri $licenseUrl -OutFile $licensePath -UseBasicParsing }
        Add-AppxPackage -Path $vcLibsPath -ErrorAction SilentlyContinue
        Add-AppxPackage -Path $uiXamlPath -ErrorAction SilentlyContinue
        if (Test-Path $licensePath) {
            Add-AppxProvisionedPackage -Online -PackagePath $wingetPath -LicensePath $licensePath -ErrorAction Stop | Out-Null
        } else { Add-AppxPackage -Path $wingetPath -ErrorAction Stop }
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Start-Sleep -Seconds 3
        $wingetStatus = Test-WinGet
        if ($wingetStatus.Installed) { return $true }
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
        return $false
    } catch { return $false }
}

# ============================================================================
# PACKAGE GROUPS SYSTEM
# ============================================================================

$Script:GroupsDir = "$env:APPDATA\Wingetter"
$Script:GroupsFile = "$Script:GroupsDir\groups.json"
if (!(Test-Path $Script:GroupsDir)) { New-Item -ItemType Directory -Path $Script:GroupsDir -Force | Out-Null }

function Get-SavedGroups {
    if (Test-Path $Script:GroupsFile) {
        try { return (Get-Content $Script:GroupsFile -Raw | ConvertFrom-Json) }
        catch { return [PSCustomObject]@{} }
    }
    return [PSCustomObject]@{}
}

function Save-GroupToFile {
    param([string]$Name, [string[]]$PackageIds)
    $groups = Get-SavedGroups
    $ht = @{}
    foreach ($prop in $groups.PSObject.Properties) { $ht[$prop.Name] = @($prop.Value) }
    $ht[$Name] = $PackageIds
    $ht | ConvertTo-Json -Depth 5 | Set-Content -Path $Script:GroupsFile -Encoding UTF8
}

function Remove-GroupFromFile {
    param([string]$Name)
    $groups = Get-SavedGroups
    $ht = @{}
    foreach ($prop in $groups.PSObject.Properties) { if ($prop.Name -ne $Name) { $ht[$prop.Name] = @($prop.Value) } }
    $ht | ConvertTo-Json -Depth 5 | Set-Content -Path $Script:GroupsFile -Encoding UTF8
}

function Export-GroupAsPS1 {
    param([string]$GroupName, [string[]]$PackageIds, [string]$FilePath, [bool]$Silent = $true, [bool]$AcceptAgreements = $true)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("<#")
    [void]$sb.AppendLine(".SYNOPSIS")
    [void]$sb.AppendLine("    WinGet Package Group Installer - $GroupName")
    [void]$sb.AppendLine(".DESCRIPTION")
    [void]$sb.AppendLine("    Auto-generated by Wingetter")
    [void]$sb.AppendLine("    Installs $($PackageIds.Count) packages via winget")
    [void]$sb.AppendLine("    Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("#>")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('Write-Host "====================================" -ForegroundColor Cyan')
    [void]$sb.AppendLine("Write-Host `" WinGet Package Group: $GroupName`" -ForegroundColor Cyan")
    [void]$sb.AppendLine("Write-Host `" $($PackageIds.Count) packages to install`" -ForegroundColor Cyan")
    [void]$sb.AppendLine('Write-Host "====================================" -ForegroundColor Cyan')
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('# Check for winget')
    [void]$sb.AppendLine('if (!(Get-Command winget -ErrorAction SilentlyContinue)) {')
    [void]$sb.AppendLine('    Write-Host "ERROR: winget not found. Install it from the Microsoft Store." -ForegroundColor Red')
    [void]$sb.AppendLine('    exit 1')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('$total = ' + $PackageIds.Count)
    [void]$sb.AppendLine('$current = 0; $ok = 0; $fail = 0; $skip = 0')
    [void]$sb.AppendLine("")

    $flags = ""
    if ($Silent) { $flags += " --silent" }
    if ($AcceptAgreements) { $flags += " --accept-package-agreements --accept-source-agreements" }

    [void]$sb.AppendLine('$packages = @(')
    foreach ($id in $PackageIds) {
        [void]$sb.AppendLine("    `"$id`"")
    }
    [void]$sb.AppendLine(')')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('foreach ($pkg in $packages) {')
    [void]$sb.AppendLine('    $current++')
    [void]$sb.AppendLine('    $pct = [math]::Round(($current / $total) * 100)')
    [void]$sb.AppendLine('    Write-Host "[$current/$total] ($pct%) Installing $pkg..." -ForegroundColor Yellow')
    [void]$sb.AppendLine("    `$result = winget install --id `$pkg --exact$flags 2>&1 | Out-String")
    [void]$sb.AppendLine('    if ($LASTEXITCODE -eq 0) {')
    [void]$sb.AppendLine('        Write-Host "  OK" -ForegroundColor Green; $ok++')
    [void]$sb.AppendLine('    } elseif ($result -match "already installed|No available upgrade") {')
    [void]$sb.AppendLine('        Write-Host "  Already installed" -ForegroundColor DarkGray; $skip++')
    [void]$sb.AppendLine('    } else {')
    [void]$sb.AppendLine('        Write-Host "  FAILED" -ForegroundColor Red; $fail++')
    [void]$sb.AppendLine('    }')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('Write-Host ""')
    [void]$sb.AppendLine('Write-Host "====================================" -ForegroundColor Cyan')
    [void]$sb.AppendLine('Write-Host " Results: $ok installed, $skip already present, $fail failed" -ForegroundColor Cyan')
    [void]$sb.AppendLine('Write-Host "====================================" -ForegroundColor Cyan')
    [void]$sb.AppendLine('Read-Host "Press Enter to exit"')

    $sb.ToString() | Set-Content -Path $FilePath -Encoding UTF8
}

function Export-GroupAsJSON {
    param([string]$GroupName, [string[]]$PackageIds, [string]$FilePath)
    $obj = @{
        Schema     = "Wingetter.Group.v1"
        GroupName  = $GroupName
        Generated  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Generator  = "Wingetter"
        AppCount   = $PackageIds.Count
        PackageIds = $PackageIds
    }
    $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $FilePath -Encoding UTF8
}

function Export-GroupAsWinGetJSON {
    param([string]$GroupName, [string[]]$PackageIds, [string]$FilePath)

    $wingetVersion = try { (winget --version 2>$null) } catch { $null }
    $packages = @($PackageIds | ForEach-Object {
        [ordered]@{ PackageIdentifier = $_ }
    })

    $obj = [ordered]@{
        '$schema'     = "https://aka.ms/winget-packages.schema.2.0.json"
        CreationDate  = (Get-Date).ToUniversalTime().ToString("o")
        Sources       = @(
            [ordered]@{
                Packages      = $packages
                SourceDetails = [ordered]@{
                    Argument   = "https://cdn.winget.microsoft.com/cache"
                    Identifier = "Microsoft.Winget.Source_8wekyb3d8bbwe"
                    Name       = "winget"
                    Type       = "Microsoft.PreIndexed.Package"
                }
            }
        )
    }
    if ($wingetVersion) { $obj["WinGetVersion"] = [string]$wingetVersion }

    $obj | ConvertTo-Json -Depth 8 | Set-Content -Path $FilePath -Encoding UTF8
}

function Get-JsonPropertyValue {
    param([object]$InputObject, [string]$PropertyName)
    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($property) { return $property.Value }
    return $null
}

function Import-PackageIdsFromJSON {
    param([object]$Content, [string]$FallbackGroupName = "Imported Group")

    $ids = [System.Collections.ArrayList]::new()
    $sourceNames = [System.Collections.ArrayList]::new()
    $warnings = [System.Collections.ArrayList]::new()
    $groupName = $FallbackGroupName
    $format = "Unknown"

    $packageIds = Get-JsonPropertyValue -InputObject $Content -PropertyName "PackageIds"
    $wingetSources = Get-JsonPropertyValue -InputObject $Content -PropertyName "Sources"
    $flatPackages = Get-JsonPropertyValue -InputObject $Content -PropertyName "Packages"

    if ($packageIds) {
        $format = "Wingetter group JSON"
        $name = Get-JsonPropertyValue -InputObject $Content -PropertyName "GroupName"
        if ($name) { $groupName = [string]$name }
        foreach ($id in @($packageIds)) {
            if (![string]::IsNullOrWhiteSpace([string]$id)) { [void]$ids.Add([string]$id) }
        }
    } elseif ($wingetSources) {
        $format = "WinGet import JSON"
        foreach ($source in @($wingetSources)) {
            $sourceDetails = Get-JsonPropertyValue -InputObject $source -PropertyName "SourceDetails"
            $sourceName = Get-JsonPropertyValue -InputObject $sourceDetails -PropertyName "Name"
            if (!$sourceName) { $sourceName = Get-JsonPropertyValue -InputObject $source -PropertyName "Name" }
            if ($sourceName) {
                [void]$sourceNames.Add([string]$sourceName)
            } else {
                [void]$warnings.Add("A WinGet source entry is missing SourceDetails.Name.")
            }

            $sourcePackages = Get-JsonPropertyValue -InputObject $source -PropertyName "Packages"
            foreach ($package in @($sourcePackages)) {
                $id = Get-JsonPropertyValue -InputObject $package -PropertyName "PackageIdentifier"
                if ($id) {
                    [void]$ids.Add([string]$id)
                } else {
                    [void]$warnings.Add("A WinGet package entry is missing PackageIdentifier.")
                }
            }
        }
    } elseif ($flatPackages) {
        $format = "WinGet package list JSON"
        foreach ($package in @($flatPackages)) {
            $id = Get-JsonPropertyValue -InputObject $package -PropertyName "PackageIdentifier"
            if ($id) { [void]$ids.Add([string]$id) }
        }
    } elseif ($Content -is [System.Array]) {
        $format = "Package ID array JSON"
        foreach ($id in @($Content)) {
            if (![string]::IsNullOrWhiteSpace([string]$id)) { [void]$ids.Add([string]$id) }
        }
    } else {
        throw "Unrecognized JSON format"
    }

    $seen = @{}
    $uniqueIds = [System.Collections.ArrayList]::new()
    foreach ($id in $ids) {
        if (!$seen.ContainsKey($id)) {
            $seen[$id] = $true
            [void]$uniqueIds.Add($id)
        }
    }

    [PSCustomObject]@{
        GroupName   = $groupName
        Format      = $format
        PackageIds  = [string[]]$uniqueIds.ToArray([string])
        SourceNames = [string[]]$sourceNames.ToArray([string])
        Warnings    = [string[]]$warnings.ToArray([string])
    }
}

# Pre-built groups
$Script:BuiltInGroups = [ordered]@{
    "Essential PC Setup" = @(
        "Google.Chrome","Mozilla.Firefox","7zip.7zip","VideoLAN.VLC","Notepad++.Notepad++",
        "voidtools.Everything","Adobe.Acrobat.Reader.64-bit","GIMP.GIMP","dotPDN.PaintDotNet","Microsoft.PowerToys",
        "ShareX.ShareX"
    )
    "Web Developer" = @(
        "Microsoft.VisualStudioCode","Git.Git","OpenJS.NodeJS.LTS","Docker.DockerDesktop","Postman.Postman",
        "Mozilla.Firefox","Google.Chrome","GitHub.GitHubDesktop","GitHub.cli","Microsoft.WindowsTerminal",
        "Starship.Starship","ajeetdsouza.zoxide"
    )
    "Python Developer" = @(
        "Microsoft.VisualStudioCode","Git.Git","Python.Python.3.13","Anaconda.Miniconda3","Docker.DockerDesktop",
        "Postman.Postman","JetBrains.PyCharm.Community","Microsoft.WindowsTerminal","DBeaver.DBeaver"
    )
    "Creative Suite" = @(
        "GIMP.GIMP","KDE.Krita","Inkscape.Inkscape","BlenderFoundation.Blender","OBSProject.OBSStudio",
        "HandBrake.HandBrake","Audacity.Audacity","KDE.Kdenlive","Meltytech.Shotcut","ShareX.ShareX",
        "BlackmagicDesign.DaVinciResolve"
    )
    "Gaming PC" = @(
        "Valve.Steam","EpicGames.EpicGamesLauncher","GOG.Galaxy","Discord.Discord","Playnite.Playnite",
        "MoonlightGameStreamingProject.Moonlight","LizardByte.Sunshine","7zip.7zip","Guru3D.Afterburner","TechPowerUp.NVCleanstall"
    )
    "Privacy & Security" = @(
        "Mozilla.Firefox","MullvadVPN.MullvadBrowser","Bitwarden.Bitwarden","ProtonTechnologies.ProtonVPN","LibreWolf.LibreWolf",
        "OpenWhisperSystems.Signal","IDRIX.VeraCrypt","Cryptomator.Cryptomator","henrypp.simplewall","MullvadVPN.MullvadVPN"
    )
    "System Admin" = @(
        "PuTTY.PuTTY","WinSCP.WinSCP","Mobatek.MobaXterm","WiresharkFoundation.Wireshark","Insecure.Nmap",
        "Microsoft.WindowsTerminal","Microsoft.PowerShell","voidtools.Everything","Notepad++.Notepad++","mRemoteNG.mRemoteNG",
        "angryip.ipscan","Microsoft.Sysinternals.ProcessExplorer"
    )
    "Streaming Setup" = @(
        "OBSProject.OBSStudio","Streamlabs.Streamlabs","VB-Audio.Voicemeeter.Banana","VB-Audio.VBVirtualCable","Discord.Discord",
        "ShareX.ShareX","HandBrake.HandBrake","Gyan.FFmpeg","File-New-Project.EarTrumpet"
    )
    "Office & Productivity" = @(
        "TheDocumentFoundation.LibreOffice","Mozilla.Thunderbird","Bitwarden.Bitwarden","Doist.Todoist","Obsidian.Obsidian",
        "7zip.7zip","Adobe.Acrobat.Reader.64-bit","geek.PDF24Creator","Notion.Notion","VideoLAN.VLC"
    )
    "3D Printing Workshop" = @(
        "UltiMaker.Cura","Prusa3D.PrusaSlicer","Bambulab.Bambustudio","SoftFever.OrcaSlicer","FreeCAD.FreeCAD",
        "OpenSCAD.OpenSCAD","BlenderFoundation.Blender"
    )
}
if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $groupsPath = Join-Path $PSScriptRoot "catalog\groups.json"
    $externalGroups = ConvertFrom-WingetterGroupsJson -Path $groupsPath
    if ($externalGroups) {
        $Script:BuiltInGroups = $externalGroups
    }
}

# ============================================================================
# THEME DEFINITIONS
# ============================================================================

$Script:Themes = @{
    Light = @{
        WindowBg = "#f3f6fb"; HeaderBg = "#0f2740"; HeaderText = "#ffffff"; HeaderSubText = "#d6e2ee"
        ToolbarBg = "#ffffff"; ToolbarBorder = "#dbe6f0"
        CategoryCardBg = "#ffffff"; CategoryCardBorder = "#d7e2ed"
        CategoryHeaderBg = "#f7fafe"; CategoryHeaderBorder = "#dbe6f0"
        CategoryTitle = "#0f5fb8"; CategoryAllText = "#5f7487"
        AppText = "#17293b"; AppSubtleText = "#6a7f91"; AppHoverBg = "#f2f7fc"; AppSelectedBg = "#e6f2ff"
        FooterBg = "#ffffff"; FooterBorder = "#dbe6f0"; FooterText = "#54697c"
        StatusPillBg = "#eef4fa"; StatusPillText = "#294053"; StatusPillBorder = "#d0dde8"
        AccentGreen = "#198754"; AccentGreenHover = "#157347"
        ProgressBg = "#e4ecf4"; ProgressText = "#1c3246"
        SecBtnBg = "#f6f9fc"; SecBtnBorder = "#d2dde8"; SecBtnText = "#22384d"
        CheckboxText = "#22384d"
        SearchBg = "#ffffff"; SearchBorder = "#c7d6e3"; SearchText = "#0f2438"; SearchPlaceholder = "#77899b"; SearchFocus = "#0f6fd6"
        CountBg = "#eef4fa"; CountText = "#1c3246"
        GroupBtnBg = "#eef4fa"; GroupBtnBorder = "#d2dde8"; GroupBtnText = "#22384d"
        ComboBg = "#ffffff"; ComboBorder = "#c7d6e3"; ComboPopupBg = "#ffffff"; ComboArrow = "#77899b"
        ComboItemHover = "#f2f7fc"; ComboItemText = "#17293b"; ComboDisabledText = "#9cb0c1"
        ScrollThumbBg = "#c2d3e2"; ScrollThumbHover = "#9eb8cc"
        DividerColor = "#dbe6f0"; CountBadgeBg = "#eef4fa"; CountBadgeText = "#60778b"
        ChkBorder = "#94abc0"; ChkBorderHover = "#0f6fd6"; ChkMark = "#0f6fd6"; ChkText = "#22384d"
        SearchIcon = "#8094a8"; VersionText = "#d6e2ee"
        SidebarBg = "#f8fbff"; SidebarText = "#304658"; SidebarHover = "#edf5fd"; SidebarActive = "#dbeeff"
        SidebarBorder = "#dbe6f0"; SidebarCountText = "#7a8ea0"; SidebarSubtitle = "#7a8ea0"
        LogBg = "#f8fbff"; LogBorder = "#dbe6f0"; LogSuccess = "#198754"; LogFail = "#dc3545"; LogSkip = "#b7791f"; LogText = "#1f3447"; LogEntryBg = "#ffffff"
        InstalledDot = "#1aa56b"; InstalledBadgeBg = "#e7f8ef"; InstalledBadgeText = "#167d53"
        UpdateBtnBg = "#dd8b21"; UpdateBtnHover = "#c77611"
        CollapseArrow = "#6e8296"
        EmptyStateBg = "#ffffff"; EmptyStateBorder = "#dbe6f0"; EmptyStateTitle = "#12263a"; EmptyStateText = "#60778b"
    }
    Dark = @{
        WindowBg = "#071018"; HeaderBg = "#08131f"; HeaderText = "#f8fafc"; HeaderSubText = "#8ca0b7"
        ToolbarBg = "#0b1725"; ToolbarBorder = "#1d2a3a"
        CategoryCardBg = "#0d1b2b"; CategoryCardBorder = "#1f3145"
        CategoryHeaderBg = "#0f2133"; CategoryHeaderBorder = "#21354a"
        CategoryTitle = "#8cd2ff"; CategoryAllText = "#8ca0b7"
        AppText = "#e5edf5"; AppSubtleText = "#95a7bb"; AppHoverBg = "#11263a"; AppSelectedBg = "#15334b"
        FooterBg = "#0b1725"; FooterBorder = "#1d2a3a"; FooterText = "#94a7bc"
        StatusPillBg = "#0d1f30"; StatusPillText = "#c4d2df"; StatusPillBorder = "#22405a"
        AccentGreen = "#1fb879"; AccentGreenHover = "#32c98a"
        ProgressBg = "#132132"; ProgressText = "#c8d8e8"
        SecBtnBg = "#102133"; SecBtnBorder = "#23374c"; SecBtnText = "#dbe7f1"
        CheckboxText = "#dbe7f1"
        SearchBg = "#08131f"; SearchBorder = "#24374a"; SearchText = "#eff6fb"; SearchPlaceholder = "#70859b"; SearchFocus = "#5ab0ff"
        CountBg = "#102133"; CountText = "#dce8f3"
        GroupBtnBg = "#102133"; GroupBtnBorder = "#23374c"; GroupBtnText = "#dbe7f1"
        ComboBg = "#08131f"; ComboBorder = "#24374a"; ComboPopupBg = "#0b1725"; ComboArrow = "#7a90a6"
        ComboItemHover = "#102133"; ComboItemText = "#dbe7f1"; ComboDisabledText = "#5f7489"
        ScrollThumbBg = "#27405a"; ScrollThumbHover = "#3b5d7f"
        DividerColor = "#223247"; CountBadgeBg = "#102133"; CountBadgeText = "#8ca0b7"
        ChkBorder = "#36506a"; ChkBorderHover = "#63b7ff"; ChkMark = "#63b7ff"; ChkText = "#dbe7f1"
        SearchIcon = "#7a90a6"; VersionText = "#7a90a6"
        SidebarBg = "#08131f"; SidebarText = "#acc0d4"; SidebarHover = "#0f2438"; SidebarActive = "#15314a"
        SidebarBorder = "#1d2a3a"; SidebarCountText = "#6e859a"; SidebarSubtitle = "#8196aa"
        LogBg = "#071019"; LogBorder = "#1d2a3a"; LogSuccess = "#2dd58f"; LogFail = "#ff6b6b"; LogSkip = "#ffbf69"; LogText = "#dbe7f2"; LogEntryBg = "#0d1825"
        InstalledDot = "#1fd389"; InstalledBadgeBg = "#103526"; InstalledBadgeText = "#78ddb1"
        UpdateBtnBg = "#d97706"; UpdateBtnHover = "#f59e0b"
        CollapseArrow = "#6f879e"
        EmptyStateBg = "#0b1724"; EmptyStateBorder = "#1f3145"; EmptyStateTitle = "#f0f6fb"; EmptyStateText = "#90a4b8"
    }
}

# ============================================================================
# MAIN GUI
# ============================================================================

function Show-WinGetInstallerGUI {
    # Shared mutable state - local hashtable captured by closures
    $ui = @{
        AllCheckboxes = @{}
        Cancelled     = $false
        IsDark        = $true
        HoverBg       = "#2a2a4a"
        SelectedBg    = "#1a3a5c"
        Themes        = $Script:Themes
        Categories    = [System.Collections.ArrayList]::new()
        IconQueue     = [System.Collections.ArrayList]::new()
        Elements      = @{
            CategoryCards   = [System.Collections.ArrayList]::new()
            CategoryHeaders = [System.Collections.ArrayList]::new()
            CategoryTitles  = [System.Collections.ArrayList]::new()
            CategoryAlls    = [System.Collections.ArrayList]::new()
            CountBadges     = [System.Collections.ArrayList]::new()
            CountTexts      = [System.Collections.ArrayList]::new()
            AppBorders      = [System.Collections.ArrayList]::new()
            AppLabels       = [System.Collections.ArrayList]::new()
            AppStatusBadges = [System.Collections.ArrayList]::new()
            AppStatusTexts  = [System.Collections.ArrayList]::new()
            SecButtons      = [System.Collections.ArrayList]::new()
            FooterChecks    = [System.Collections.ArrayList]::new()
            CollapseArrows  = [System.Collections.ArrayList]::new()
            InstalledDots   = [System.Collections.ArrayList]::new()
            SidebarButtons  = [System.Collections.ArrayList]::new()
            SidebarCounts   = [System.Collections.ArrayList]::new()
            SidebarRows     = [System.Collections.ArrayList]::new()
        }
    }

    $XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Wingetter v6.1.0 - Curated Windows App Installs and Updates"
        Height="920" Width="1450" MinHeight="720" MinWidth="1080"
        WindowStartupLocation="CenterScreen" Background="#071018"
        FontFamily="Segoe UI" SnapsToDevicePixels="True" UseLayoutRounding="True"
        TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
    <Window.Resources>
        <!-- Theme brush resources (updated dynamically by ApplyTheme) -->
        <SolidColorBrush x:Key="ComboBg" Color="#08131f"/>
        <SolidColorBrush x:Key="ComboBorder" Color="#24374a"/>
        <SolidColorBrush x:Key="ComboPopupBg" Color="#0b1725"/>
        <SolidColorBrush x:Key="ComboArrow" Color="#7a90a6"/>
        <SolidColorBrush x:Key="ComboItemHover" Color="#102133"/>
        <SolidColorBrush x:Key="ComboItemText" Color="#dbe7f1"/>
        <SolidColorBrush x:Key="ComboDisabledText" Color="#5f7489"/>
        <SolidColorBrush x:Key="ScrollThumbBg" Color="#27405a"/>
        <SolidColorBrush x:Key="ScrollThumbHover" Color="#3b5d7f"/>
        <SolidColorBrush x:Key="DividerBrush" Color="#223247"/>
        <SolidColorBrush x:Key="ChkBorder" Color="#36506a"/>
        <SolidColorBrush x:Key="ChkBorderHover" Color="#63b7ff"/>
        <SolidColorBrush x:Key="ChkMark" Color="#63b7ff"/>
        <SolidColorBrush x:Key="ChkText" Color="#dbe7f1"/>
        <!-- Toolbar / secondary button style -->
        <Style x:Key="ToolBtn" TargetType="Button">
            <Setter Property="Background" Value="#102133"/>
            <Setter Property="Foreground" Value="#dbe7f1"/>
            <Setter Property="BorderBrush" Value="#23374c"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="MinHeight" Value="34"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid>
                            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <Border x:Name="hover" Background="White" Opacity="0" CornerRadius="10" IsHitTestVisible="False"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="hover" Property="Opacity" Value="0.06"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#63b7ff"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="hover" Property="Opacity" Value="0.12"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="bd" Property="BorderBrush" Value="#63b7ff"/>
                                <Setter TargetName="bd" Property="BorderThickness" Value="1.5"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Opacity" Value="0.38"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- ComboBox ToggleButton template -->
        <ControlTemplate x:Key="ComboToggle" TargetType="ToggleButton">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition/>
                    <ColumnDefinition Width="26"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="bd" Grid.ColumnSpan="2" Background="{DynamicResource ComboBg}" BorderBrush="{DynamicResource ComboBorder}" BorderThickness="1" CornerRadius="10"/>
                <Border x:Name="hv" Grid.ColumnSpan="2" Background="White" Opacity="0" CornerRadius="10" IsHitTestVisible="False"/>
                <Path x:Name="arrow" Grid.Column="1" Fill="{DynamicResource ComboArrow}" HorizontalAlignment="Center" VerticalAlignment="Center" Data="M0,0 L4,4 L8,0 Z"/>
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="hv" Property="Opacity" Value="0.05"/>
                    <Setter TargetName="bd" Property="BorderBrush" Value="#63b7ff"/>
                </Trigger>
                <Trigger Property="IsKeyboardFocused" Value="True">
                    <Setter TargetName="bd" Property="BorderBrush" Value="#63b7ff"/>
                    <Setter TargetName="bd" Property="BorderThickness" Value="1.5"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>
        <!-- Full ComboBox ControlTemplate (dark mode safe - popup + togglebutton + items) -->
        <Style TargetType="ComboBox">
            <Setter Property="Foreground" Value="{DynamicResource ComboItemText}"/>
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="Height" Value="36"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleButton" Template="{StaticResource ComboToggle}" Focusable="False" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press"/>
                            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" Margin="12,5,28,5" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                                <Grid x:Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <Border Background="{DynamicResource ComboPopupBg}" BorderBrush="{DynamicResource ComboBorder}" BorderThickness="1" CornerRadius="10" Margin="0,4,0,0" Padding="4">
                                        <ScrollViewer SnapsToDevicePixels="True">
                                            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                                        </ScrollViewer>
                                    </Border>
                                </Grid>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- ComboBoxItem -->
        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="{DynamicResource ComboItemText}"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Bd" Background="Transparent" Padding="{TemplateBinding Padding}" CornerRadius="8">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ComboItemHover}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="{DynamicResource ComboDisabledText}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- Vertical ScrollBar -->
        <Style x:Key="SlimThumb" TargetType="Thumb">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Thumb">
                        <Border x:Name="tb" Background="{DynamicResource ScrollThumbBg}" CornerRadius="6" Margin="2"/>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="tb" Property="Background" Value="{DynamicResource ScrollThumbHover}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="Transparent"/>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Vertical">
                    <Setter Property="Width" Value="12"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ScrollBar">
                                <Track x:Name="PART_Track" IsDirectionReversed="True">
                                    <Track.Thumb>
                                        <Thumb Style="{StaticResource SlimThumb}"/>
                                    </Track.Thumb>
                                </Track>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Height" Value="12"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ScrollBar">
                                <Track x:Name="PART_Track" IsDirectionReversed="False">
                                    <Track.Thumb>
                                        <Thumb Style="{StaticResource SlimThumb}"/>
                                    </Track.Thumb>
                                </Track>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
            </Style.Triggers>
        </Style>
        <!-- Rounded ProgressBar -->
        <Style TargetType="ProgressBar">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border x:Name="PART_Track" Background="{TemplateBinding Background}" CornerRadius="999"/>
                            <Border x:Name="PART_Indicator" HorizontalAlignment="Left" CornerRadius="999">
                                <Border.Background>
                                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                        <GradientStop Color="#1fb879" Offset="0"/>
                                        <GradientStop Color="#34d399" Offset="1"/>
                                    </LinearGradientBrush>
                                </Border.Background>
                            </Border>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- Dark CheckBox -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{DynamicResource ChkText}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Border x:Name="box" Width="18" Height="18" Background="Transparent" BorderBrush="{DynamicResource ChkBorder}" BorderThickness="1.5" CornerRadius="5" VerticalAlignment="Center">
                                <Path x:Name="mark" Data="M3,8 L7,12 L14,4" Stroke="{DynamicResource ChkMark}" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Visibility="Collapsed"/>
                            </Border>
                            <ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="mark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="box" Property="BorderBrush" Value="{DynamicResource ChkBorderHover}"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="box" Property="BorderBrush" Value="{DynamicResource ChkBorderHover}"/>
                                <Setter TargetName="box" Property="BorderThickness" Value="2"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <!-- Top gradient accent bar -->
        <Border Grid.Row="0" Height="4">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Color="#3da4ff" Offset="0"/>
                    <GradientStop Color="#7dd3fc" Offset="0.58"/>
                    <GradientStop Color="#22c55e" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
        </Border>
        <Border x:Name="HeaderBorder" Grid.Row="1" Background="#08131f" Padding="28,20,28,18">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock x:Name="HeaderTitle" Text="Wingetter" FontSize="30" FontWeight="Bold">
                            <TextBlock.Foreground>
                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                    <GradientStop Color="#8cd2ff" Offset="0"/>
                                    <GradientStop Color="#d3f1ff" Offset="1"/>
                                </LinearGradientBrush>
                            </TextBlock.Foreground>
                        </TextBlock>
                        <Border Margin="10,0,0,2" Padding="8,3" CornerRadius="999" Background="#102133" BorderBrush="#24374a" BorderThickness="1">
                            <TextBlock x:Name="HeaderVersion" Text="v6.1.0" FontSize="11" FontWeight="SemiBold" Foreground="#7a90a6"/>
                        </Border>
                    </StackPanel>
                    <TextBlock x:Name="HeaderSubtitle" Text="Curated winget installs, reusable package groups, and cleaner Windows setup flows." FontSize="13" Foreground="#8ca0b7" Margin="0,8,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Top">
                    <Border x:Name="CountPill" Background="#0d1f30" BorderBrush="#22405a" BorderThickness="1" CornerRadius="14" Padding="14,9" Margin="0,0,10,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="CountLabel1" Text="Selected" Foreground="#c4d2df" FontSize="12" Margin="0,0,7,0"/>
                            <TextBlock x:Name="SelectedCount" Text="0" Foreground="#2bd28f" FontSize="14" FontWeight="Bold"/>
                        </StackPanel>
                    </Border>
                    <Border x:Name="StatusPill" Background="#0d1f30" BorderBrush="#22405a" BorderThickness="1" CornerRadius="14" Padding="14,9" Margin="0,0,10,0">
                        <StackPanel Orientation="Horizontal">
                            <Ellipse x:Name="WinGetDot" Width="10" Height="10" Fill="#ff9d2f" Margin="0,0,8,0" VerticalAlignment="Center"/>
                            <TextBlock x:Name="WinGetStatus" Text="Checking WinGet..." Foreground="#c4d2df" FontSize="12.5" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                    <Button x:Name="ModeBtn" Width="44" Height="44" Cursor="Hand" ToolTip="Switch between dark and light mode">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="modeBorder" Background="#102133" BorderBrush="#24374a" BorderThickness="1" CornerRadius="14">
                                    <TextBlock Text="◐" FontSize="17" Foreground="#dbe7f1" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="modeBorder" Property="BorderBrush" Value="#63b7ff"/>
                                    </Trigger>
                                    <Trigger Property="IsKeyboardFocused" Value="True">
                                        <Setter TargetName="modeBorder" Property="BorderBrush" Value="#63b7ff"/>
                                        <Setter TargetName="modeBorder" Property="BorderThickness" Value="1.5"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </StackPanel>
            </Grid>
        </Border>
        <Border x:Name="ToolbarBorder" Grid.Row="2" Background="#0b1725" BorderBrush="#1d2a3a" BorderThickness="0,0,0,1" Padding="28,16">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border x:Name="SearchBorder" Grid.Column="0" Background="#08131f" BorderBrush="#24374a" BorderThickness="1" CornerRadius="14" Padding="12,0" Margin="0,0,12,0" Width="380" Height="42">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="SearchIcon" Grid.Column="0" Text="⌕" FontSize="17" Foreground="#7a90a6" VerticalAlignment="Center" Margin="1,0,8,0" IsHitTestVisible="False"/>
                            <TextBlock x:Name="SearchPlaceholder" Grid.Column="1" Text="Search apps or Winget IDs" Foreground="#70859b" FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False"/>
                            <TextBox x:Name="SearchBox" Grid.Column="1" Background="Transparent" BorderThickness="0" FontSize="13" VerticalAlignment="Center" Foreground="#eff6fb" Padding="0,8,0,8"/>
                            <Button x:Name="ClearSearchBtn" Grid.Column="2" Style="{StaticResource ToolBtn}" Content="Clear" Padding="10,5" Margin="8,0,0,0" FontSize="11" Cursor="Hand" Visibility="Collapsed"/>
                        </Grid>
                    </Border>
                    <Border x:Name="VisibleCountBorder" Grid.Column="1" Background="#102133" BorderBrush="#223247" BorderThickness="1" CornerRadius="12" Padding="12,9" VerticalAlignment="Center" Margin="0,0,12,0">
                        <TextBlock x:Name="VisibleCountText" Text="765 apps available" FontSize="12" FontWeight="SemiBold" Foreground="#dce8f3"/>
                    </Border>
                    <Border x:Name="ToolbarHintBorder" Grid.Column="3" Background="#102133" BorderBrush="#223247" BorderThickness="1" CornerRadius="12" Padding="12,9" VerticalAlignment="Center">
                        <TextBlock x:Name="ToolbarHintText" Text="Tip: Shift+Click selects a range." FontSize="11.5" Foreground="#94a7bc"/>
                    </Border>
                </Grid>
                <Grid Grid.Row="1" Margin="0,14,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Orientation="Horizontal">
                        <Button x:Name="SelectAllBtn" Style="{StaticResource ToolBtn}" Content="Select Visible" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                        <Button x:Name="DeselectAllBtn" Style="{StaticResource ToolBtn}" Content="Clear Visible" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2" Orientation="Horizontal">
                        <ComboBox x:Name="GroupCombo" Width="220" FontSize="11.5" Margin="0,0,8,0" VerticalAlignment="Center"/>
                        <Button x:Name="LoadGroupBtn" Style="{StaticResource ToolBtn}" Content="Apply Group" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                        <Button x:Name="SaveGroupBtn" Style="{StaticResource ToolBtn}" Content="Save Group" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                        <Button x:Name="DeleteGroupBtn" Style="{StaticResource ToolBtn}" Content="Delete" Margin="0,0,12,0" FontSize="11.5" Cursor="Hand" ToolTip="Delete the selected saved group"/>
                        <Border x:Name="Divider1" Background="{DynamicResource DividerBrush}" Width="1" Margin="0,2,12,2"/>
                        <Button x:Name="ExportBtn" Style="{StaticResource ToolBtn}" Content="Export Selection" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand" ToolTip="Export the current selection as JSON or a PowerShell install script"/>
                        <Button x:Name="ImportBtn" Style="{StaticResource ToolBtn}" Content="Import Group" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                        <Button x:Name="CopyCommandBtn" Style="{StaticResource ToolBtn}" Content="Copy Commands" FontSize="11.5" Cursor="Hand"/>
                        <Border x:Name="Divider2" Visibility="Collapsed" Width="0"/>
                    </StackPanel>
                </Grid>
            </Grid>
        </Border>
        <!-- Main content: Sidebar + Categories -->
        <Grid Grid.Row="3">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="215"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <!-- Category Sidebar -->
            <Border x:Name="SidebarBorder" Grid.Column="0" Background="#08131f" BorderBrush="#1d2a3a" BorderThickness="0,0,1,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Border Grid.Row="0" Padding="16,14" BorderBrush="#1d2a3a" BorderThickness="0,0,0,1">
                        <StackPanel>
                            <TextBlock x:Name="SidebarTitle" Text="Browse categories" FontSize="12.5" FontWeight="SemiBold" Foreground="#8cd2ff"/>
                            <TextBlock x:Name="SidebarSubtitle" Text="Jump into the software collection." FontSize="11.5" Foreground="#8196aa" Margin="0,4,0,0"/>
                        </StackPanel>
                    </Border>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,8,0,8">
                        <StackPanel x:Name="SidebarPanel" Margin="0,4,0,4"/>
                    </ScrollViewer>
                </Grid>
            </Border>
            <!-- App Cards Area -->
            <Grid Grid.Column="1">
                <ScrollViewer x:Name="MainScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="18,16,18,22">
                    <WrapPanel x:Name="CategoriesPanel" Orientation="Horizontal"/>
                </ScrollViewer>
                <Border x:Name="EmptyStateBorder" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="430" Padding="28,26" CornerRadius="20" Background="#0b1724" BorderBrush="#1f3145" BorderThickness="1">
                    <StackPanel>
                        <TextBlock x:Name="EmptyStateEyebrow" Text="Nothing to show" FontSize="11.5" FontWeight="SemiBold" Foreground="#8cd2ff" HorizontalAlignment="Center"/>
                        <TextBlock x:Name="EmptyStateTitle" Text="No apps match your current filters." FontSize="20" FontWeight="Bold" Foreground="#f0f6fb" Margin="0,10,0,0" TextAlignment="Center" TextWrapping="Wrap"/>
                        <TextBlock x:Name="EmptyStateBody" Text="Try another search, clear the filter, or switch back from update mode to browse the full catalog." FontSize="12.5" Foreground="#90a4b8" Margin="0,10,0,0" TextAlignment="Center" TextWrapping="Wrap"/>
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,18,0,0">
                            <Button x:Name="EmptyStateClearBtn" Style="{StaticResource ToolBtn}" Content="Clear Search" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                            <Button x:Name="EmptyStateResetModeBtn" Style="{StaticResource ToolBtn}" Content="Back to Browse" FontSize="11.5" Cursor="Hand" Visibility="Collapsed"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
            </Grid>
        </Grid>
        <!-- Log Panel (shown during install) -->
        <Border x:Name="LogPanelBorder" Grid.Row="4" Background="#071019" BorderBrush="#1d2a3a" BorderThickness="0,1,0,0" Visibility="Collapsed" MaxHeight="210">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="16,10,16,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="LogTitle" Text="Activity" FontSize="12" FontWeight="SemiBold" Foreground="#8cd2ff"/>
                        <TextBlock x:Name="LogSubtitle" Text="Install and update results appear here in real time." FontSize="11" Foreground="#94a7bc" Margin="0,3,0,0"/>
                    </StackPanel>
                    <Button x:Name="LogToggleBtn" Grid.Column="1" Style="{StaticResource ToolBtn}" Content="Hide" Padding="10,5" FontSize="10.5" Cursor="Hand"/>
                </Grid>
                <ScrollViewer x:Name="LogScrollViewer" Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="16,0,16,12">
                    <StackPanel x:Name="LogEntriesPanel"/>
                </ScrollViewer>
            </Grid>
        </Border>
        <Border x:Name="FooterBorder" Grid.Row="5" Background="#0b1725" BorderBrush="#1d2a3a" BorderThickness="0,1,0,0" Padding="28,16">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,12">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="ProgressText" Text="Choose apps to install or load a saved group to get started." Foreground="#94a7bc" FontSize="12.5"/>
                        <ProgressBar x:Name="ProgressBar" Height="8" Value="0" Maximum="100" Background="#132132" Foreground="#1fb879" BorderThickness="0" Margin="0,8,0,0"/>
                    </StackPanel>
                    <TextBlock x:Name="ProgressPercent" Grid.Column="1" Text="" Foreground="#c8d8e8" FontSize="14" FontWeight="Bold" VerticalAlignment="Center" Margin="20,0,0,0"/>
                </Grid>
                <Grid Grid.Row="1">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <CheckBox x:Name="SilentCheck" Content="Use silent install where available" IsChecked="True" FontSize="12.5" Margin="0,0,20,0" VerticalAlignment="Center"/>
                        <CheckBox x:Name="AcceptCheck" Content="Accept package and source agreements" IsChecked="True" FontSize="12.5" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="InstallWinGetBtn" Style="{StaticResource ToolBtn}" Content="Install WinGet" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand" Visibility="Collapsed"/>
                        <Button x:Name="UpdateAllBtn" Content="Review Updates" FontSize="11.5" FontWeight="SemiBold" Padding="14,8" Margin="0,0,8,0" Cursor="Hand" Foreground="White" ToolTip="Show installed apps from this catalog so you can choose what to update.">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Border x:Name="updateAllBorder" CornerRadius="10" Padding="{TemplateBinding Padding}" Background="#d97706">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="updateAllBorder" Property="Background" Value="#f59e0b"/>
                                        </Trigger>
                                        <Trigger Property="IsKeyboardFocused" Value="True">
                                            <Setter TargetName="updateAllBorder" Property="Background" Value="#f59e0b"/>
                                        </Trigger>
                                        <Trigger Property="IsEnabled" Value="False">
                                            <Setter TargetName="updateAllBorder" Property="Background" Value="#445265"/>
                                            <Setter TargetName="updateAllBorder" Property="Opacity" Value="0.7"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Button.Template>
                        </Button>
                        <Button x:Name="CancelBtn" Style="{StaticResource ToolBtn}" Content="Stop" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand" IsEnabled="False"/>
                        <Button x:Name="InstallBtn" Content="Install Selected" FontSize="14" FontWeight="SemiBold" Padding="24,11" Cursor="Hand" Foreground="White" IsEnabled="False">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Grid>
                                        <Border x:Name="installBorder" CornerRadius="12" Padding="{TemplateBinding Padding}">
                                            <Border.Background>
                                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                                    <GradientStop Color="#1fb879" Offset="0"/>
                                                    <GradientStop Color="#34d399" Offset="1"/>
                                                </LinearGradientBrush>
                                            </Border.Background>
                                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <Border x:Name="installGlow" CornerRadius="12" Background="White" Opacity="0" IsHitTestVisible="False"/>
                                    </Grid>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="installGlow" Property="Opacity" Value="0.08"/>
                                        </Trigger>
                                        <Trigger Property="IsPressed" Value="True">
                                            <Setter TargetName="installGlow" Property="Opacity" Value="0.16"/>
                                        </Trigger>
                                        <Trigger Property="IsKeyboardFocused" Value="True">
                                            <Setter TargetName="installGlow" Property="Opacity" Value="0.12"/>
                                        </Trigger>
                                        <Trigger Property="IsEnabled" Value="False">
                                            <Setter TargetName="installBorder" Property="Background" Value="#445265"/>
                                            <Setter TargetName="installBorder" Property="Opacity" Value="0.72"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Button.Template>
                        </Button>
                    </StackPanel>
                </Grid>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($XAML))
    $Window = [Windows.Markup.XamlReader]::Load($reader)

# codex-branding:start
                try {
                    $brandingIconPath = Join-Path $PSScriptRoot 'icon.ico'
                    if (Test-Path $brandingIconPath) {
                        $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object System.Uri($brandingIconPath)))
                    }
                } catch {
                }
                # codex-branding:end
    # Named controls
    $CategoriesPanel  = $Window.FindName("CategoriesPanel")
    $SelectedCount    = $Window.FindName("SelectedCount")
    $WinGetStatus     = $Window.FindName("WinGetStatus")
    $WinGetDot        = $Window.FindName("WinGetDot")
    $ProgressBar      = $Window.FindName("ProgressBar")
    $ProgressText     = $Window.FindName("ProgressText")
    $ProgressPercent  = $Window.FindName("ProgressPercent")
    $InstallBtn       = $Window.FindName("InstallBtn")
    $CancelBtn        = $Window.FindName("CancelBtn")
    $UpdateAllBtn     = $Window.FindName("UpdateAllBtn")
    $SelectAllBtn     = $Window.FindName("SelectAllBtn")
    $DeselectAllBtn   = $Window.FindName("DeselectAllBtn")
    $ExportBtn        = $Window.FindName("ExportBtn")
    $ImportBtn        = $Window.FindName("ImportBtn")
    $CopyCommandBtn   = $Window.FindName("CopyCommandBtn")
    $InstallWinGetBtn = $Window.FindName("InstallWinGetBtn")
    $GroupCombo       = $Window.FindName("GroupCombo")
    $LoadGroupBtn     = $Window.FindName("LoadGroupBtn")
    $SaveGroupBtn     = $Window.FindName("SaveGroupBtn")
    $DeleteGroupBtn   = $Window.FindName("DeleteGroupBtn")
    $SilentCheck      = $Window.FindName("SilentCheck")
    $AcceptCheck      = $Window.FindName("AcceptCheck")
    $ModeBtn          = $Window.FindName("ModeBtn")

    $MainScroll       = $Window.FindName("MainScroll")
    $SearchBox        = $Window.FindName("SearchBox")
    $ClearSearchBtn   = $Window.FindName("ClearSearchBtn")
    $SearchPlaceholder= $Window.FindName("SearchPlaceholder")
    $VisibleCountText = $Window.FindName("VisibleCountText")
    $SidebarPanel     = $Window.FindName("SidebarPanel")
    $Divider1         = $Window.FindName("Divider1")
    $Divider2         = $Window.FindName("Divider2")
    $LogPanelBorder   = $Window.FindName("LogPanelBorder")
    $LogEntriesPanel  = $Window.FindName("LogEntriesPanel")
    $LogScrollViewer  = $Window.FindName("LogScrollViewer")
    $LogToggleBtn     = $Window.FindName("LogToggleBtn")
    $LogTitle         = $Window.FindName("LogTitle")
    $EmptyStateBorder = $Window.FindName("EmptyStateBorder")
    $EmptyStateTitle  = $Window.FindName("EmptyStateTitle")
    $EmptyStateBody   = $Window.FindName("EmptyStateBody")
    $EmptyStateClearBtn = $Window.FindName("EmptyStateClearBtn")
    $EmptyStateResetModeBtn = $Window.FindName("EmptyStateResetModeBtn")

    # Store in $ui for closure access
    $ui["Window"]          = $Window
    $ui["HeaderBorder"]    = $Window.FindName("HeaderBorder")
    $ui["HeaderTitle"]     = $Window.FindName("HeaderTitle")
    $ui["HeaderSubtitle"]  = $Window.FindName("HeaderSubtitle")
    $ui["HeaderVersion"]   = $Window.FindName("HeaderVersion")
    $ui["SearchIcon"]      = $Window.FindName("SearchIcon")
    $ui["ToolbarBorder"]   = $Window.FindName("ToolbarBorder")
    $ui["StatusPill"]      = $Window.FindName("StatusPill")
    $ui["CountPill"]       = $Window.FindName("CountPill")
    $ui["CountLabel1"]     = $Window.FindName("CountLabel1")
    $ui["FooterBorder"]    = $Window.FindName("FooterBorder")
    $ui["ProgressTextCtl"] = $ProgressText
    $ui["ProgressBarCtl"]  = $ProgressBar
    $ui["ProgressPctCtl"]  = $ProgressPercent
    $ui["WinGetStatusCtl"] = $WinGetStatus
    $ui["ModeBtn"]         = $ModeBtn
    $ui["SearchBorder"]    = $Window.FindName("SearchBorder")
    $ui["SearchBox"]       = $SearchBox
    $ui["SearchPlaceholder"] = $SearchPlaceholder
    $ui["VisibleCountBorder"] = $Window.FindName("VisibleCountBorder")
    $ui["VisibleCountText"]   = $VisibleCountText
    $ui["GroupCombo"]          = $GroupCombo
    $ui["SidebarPanel"]        = $SidebarPanel
    $ui["SidebarBorder"]       = $Window.FindName("SidebarBorder")
    $ui["SidebarTitle"]        = $Window.FindName("SidebarTitle")
    $ui["SidebarSubtitle"]     = $Window.FindName("SidebarSubtitle")
    $ui["LogPanelBorder"]      = $LogPanelBorder
    $ui["LogEntriesPanel"]     = $LogEntriesPanel
    $ui["LogScrollViewer"]     = $LogScrollViewer
    $ui["LogToggleBtn"]        = $LogToggleBtn
    $ui["LogTitle"]            = $LogTitle
    $ui["LogSubtitle"]         = $Window.FindName("LogSubtitle")
    $ui["MainScroll"]          = $MainScroll
    $ui["ToolbarHintBorder"]   = $Window.FindName("ToolbarHintBorder")
    $ui["ToolbarHintText"]     = $Window.FindName("ToolbarHintText")
    $ui["ClearSearchBtn"]      = $ClearSearchBtn
    $ui["EmptyStateBorder"]    = $EmptyStateBorder
    $ui["EmptyStateTitle"]     = $EmptyStateTitle
    $ui["EmptyStateBody"]      = $EmptyStateBody
    $ui["EmptyStateClearBtn"]  = $EmptyStateClearBtn
    $ui["EmptyStateResetModeBtn"] = $EmptyStateResetModeBtn

    $ui["IsUpdateMode"]        = $false
    $ui["LastClickedIndex"]    = -1
    $ui["InstalledIds"]        = @{}
    $ui["SidebarButtons"]      = [System.Collections.ArrayList]::new()
    $ui["CategoryAppsStacks"]  = [System.Collections.ArrayList]::new()
    $ui["BuiltInGroups"]       = $Script:BuiltInGroups

    foreach ($btn in @($SelectAllBtn, $DeselectAllBtn, $CopyCommandBtn, $ExportBtn, $ImportBtn, $InstallWinGetBtn, $CancelBtn, $LoadGroupBtn, $SaveGroupBtn, $DeleteGroupBtn)) {
        [void]$ui["Elements"]["SecButtons"].Add($btn)
    }
    foreach ($chk in @($SilentCheck, $AcceptCheck)) {
        [void]$ui["Elements"]["FooterChecks"].Add($chk)
    }

    # Total app count for display
    $totalApps = 0
    foreach ($cat in $Script:SoftwareDatabase.Keys) { $totalApps += $Script:SoftwareDatabase[$cat].Count }
    $ui["TotalApps"] = $totalApps
    $ui["SidebarSubtitle"].Text = "$($Script:SoftwareDatabase.Keys.Count) categories ready to browse."

    $CountPill = $Window.FindName("CountPill")
    $UpdateGroupActionState = {
        $selected = $GroupCombo.SelectedItem
        $hasGroup = ($null -ne $selected) -and ($null -ne $selected.Tag)
        $isUserGroup = $hasGroup -and ($selected.Tag["Type"] -eq "user")
        $LoadGroupBtn.IsEnabled = $hasGroup
        $DeleteGroupBtn.IsEnabled = $isUserGroup
    }
    $UpdateCardLayout = {
        if ($ui["IsUpdateMode"]) { return }
        $available = $ui["MainScroll"].ViewportWidth
        if ($available -le 0) { $available = $ui["MainScroll"].ActualWidth }
        if ($available -le 0) { return }

        $gap = 16
        $minWidth = 252
        $maxWidth = 340
        $columns = [math]::Max(1, [math]::Min(4, [math]::Floor(($available + $gap) / ($minWidth + $gap))))
        $targetWidth = [math]::Floor(($available - (($columns + 1) * 8)) / $columns)
        $targetWidth = [math]::Max($minWidth, [math]::Min($maxWidth, $targetWidth))

        foreach ($card in $ui["Elements"]["CategoryCards"]) {
            $card.Width = $targetWidth
        }
    }
    $UpdateEmptyState = {
        $hasVisibleContent = $false
        foreach ($cat in $ui["Categories"]) {
            if ($cat["Card"].Visibility -eq [System.Windows.Visibility]::Visible) {
                $hasVisibleContent = $true
                break
            }
        }

        if ($hasVisibleContent) {
            $ui["EmptyStateBorder"].Visibility = [System.Windows.Visibility]::Collapsed
        } else {
            $ui["EmptyStateBorder"].Visibility = [System.Windows.Visibility]::Visible
            if ($ui["IsUpdateMode"]) {
                $ui["EmptyStateTitle"].Text = "No installed apps match the current view."
                $ui["EmptyStateBody"].Text = "Try a different search, or switch back to the full catalog to browse everything Wingetter can install."
                $ui["EmptyStateResetModeBtn"].Visibility = [System.Windows.Visibility]::Visible
            } else {
                $ui["EmptyStateTitle"].Text = "No apps match your current filters."
                $ui["EmptyStateBody"].Text = "Try another search term, or clear the filter to browse the full catalog."
                $ui["EmptyStateResetModeBtn"].Visibility = [System.Windows.Visibility]::Collapsed
            }
        }
    }
    $UpdateSelectedCount = {
        $count = 0
        foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked -eq $true) { $count++ } }
        $SelectedCount.Text = $count.ToString()
        $theme = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        $accentBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($theme["AccentGreen"])
        if ($count -gt 0) {
            $CountPill.BorderBrush = $accentBrush
            $CountPill.BorderThickness = [System.Windows.Thickness]::new(1)
            $SelectedCount.Foreground = $accentBrush
        } else {
            $CountPill.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($theme["StatusPillBorder"])
            $CountPill.BorderThickness = [System.Windows.Thickness]::new(1)
            $SelectedCount.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($theme["StatusPillText"])
        }

        $InstallBtn.IsEnabled = ($count -gt 0)
        $SaveGroupBtn.IsEnabled = ($count -gt 0)
        $ExportBtn.IsEnabled = ($count -gt 0)
        $CopyCommandBtn.IsEnabled = ($count -gt 0)
        $InstallBtn.Content = if ($count -gt 0) {
            if ($ui["IsUpdateMode"]) { "Update Selected ($count)" } else { "Install Selected ($count)" }
        } else {
            if ($ui["IsUpdateMode"]) { "Update Selected" } else { "Install Selected" }
        }
    }

    # ========================================================
    # FILTER LOGIC - search
    # ========================================================
    $ApplyFilter = {
        $searchText = $SearchBox.Text.Trim().ToLower()
        $visCount = 0
        $inUpdateMode = $ui["IsUpdateMode"]

        foreach ($cat in $ui["Categories"]) {
            $catVisible = 0
            foreach ($appEntry in $cat["Apps"]) {
                $nameMatch = ($searchText -eq "") -or ($appEntry["Name"].ToLower().Contains($searchText)) -or ($appEntry["WingetId"].ToLower().Contains($searchText))
                # In update mode, also require the app to be installed
                if ($inUpdateMode -and -not $ui["InstalledIds"].ContainsKey($appEntry["WingetId"])) { $nameMatch = $false }
                if ($nameMatch) {
                    $appEntry["Border"].Visibility = [System.Windows.Visibility]::Visible
                    $catVisible++
                    $visCount++
                } else {
                    $appEntry["Border"].Visibility = [System.Windows.Visibility]::Collapsed
                }
            }
            if ($inUpdateMode) {
                # In update mode, cards are always visible (flat layout), visibility driven by apps
                $cat["Card"].Visibility = if ($catVisible -gt 0) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            } else {
                $cat["Card"].Visibility = if ($catVisible -gt 0) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
        }

        $total = if ($inUpdateMode) { $ui["InstalledIds"].Count } else { $ui["TotalApps"] }
        $VisibleCountText.Text = if ($searchText -ne "") {
            if ($visCount -eq 1) { "1 match" } else { "$visCount matches" }
        } elseif ($inUpdateMode) {
            if ($total -eq 1) { "1 installed app ready" } else { "$total installed apps ready" }
        } else {
            "$total apps available"
        }
        $ClearSearchBtn.Visibility = if ($searchText -ne "") { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        & $UpdateEmptyState
        & $UpdateCardLayout
    }

    # ========================================================
    # APPLY THEME
    # ========================================================
    $ApplyTheme = {
        $themeName = if ($ui["IsDark"]) { "Dark" } else { "Light" }
        $t = $ui["Themes"][$themeName]
        $bc = [System.Windows.Media.BrushConverter]::new()

        $ui["HoverBg"]    = $t["AppHoverBg"]
        $ui["SelectedBg"] = $t["AppSelectedBg"]

        $ui["Window"].Background              = $bc.ConvertFromString($t["WindowBg"])
        $ui["HeaderBorder"].Background        = $bc.ConvertFromString($t["HeaderBg"])
        # Header title gradient (matches splash screen)
        $titleGrad = New-Object System.Windows.Media.LinearGradientBrush
        $titleGrad.StartPoint = [System.Windows.Point]::new(0, 0)
        $titleGrad.EndPoint = [System.Windows.Point]::new(1, 0)
        if ($ui["IsDark"]) {
            $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#8cd2ff"), 0)))
            $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#d3f1ff"), 1)))
        } else {
            $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#ffffff"), 0)))
            $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#d6e2ee"), 1)))
        }
        $ui["HeaderTitle"].Foreground         = $titleGrad
        $ui["HeaderSubtitle"].Foreground      = $bc.ConvertFromString($t["HeaderSubText"])
        $ui["ToolbarBorder"].Background       = $bc.ConvertFromString($t["ToolbarBg"])
        $ui["ToolbarBorder"].BorderBrush      = $bc.ConvertFromString($t["ToolbarBorder"])
        $ui["StatusPill"].Background          = $bc.ConvertFromString($t["StatusPillBg"])
        $ui["StatusPill"].BorderBrush         = $bc.ConvertFromString($t["StatusPillBorder"])
        $ui["WinGetStatusCtl"].Foreground     = $bc.ConvertFromString($t["StatusPillText"])
        $ui["CountPill"].Background           = $bc.ConvertFromString($t["StatusPillBg"])
        $ui["CountPill"].BorderBrush          = $bc.ConvertFromString($t["StatusPillBorder"])
        $ui["CountLabel1"].Foreground         = $bc.ConvertFromString($t["StatusPillText"])
        $ui["FooterBorder"].Background        = $bc.ConvertFromString($t["FooterBg"])
        $ui["FooterBorder"].BorderBrush       = $bc.ConvertFromString($t["FooterBorder"])
        $ui["ProgressTextCtl"].Foreground     = $bc.ConvertFromString($t["FooterText"])
        $ui["ProgressBarCtl"].Background      = $bc.ConvertFromString($t["ProgressBg"])
        $ui["ProgressPctCtl"].Foreground      = $bc.ConvertFromString($t["ProgressText"])

        # Search bar
        $ui["SearchBorder"].Background  = $bc.ConvertFromString($t["SearchBg"])
        $ui["SearchBorder"].BorderBrush = $bc.ConvertFromString($t["SearchBorder"])
        $ui["SearchBox"].Foreground     = $bc.ConvertFromString($t["SearchText"])
        $ui["SearchPlaceholder"].Foreground = $bc.ConvertFromString($t["SearchPlaceholder"])

        # Visible count
        $ui["VisibleCountBorder"].Background = $bc.ConvertFromString($t["CountBg"])
        $ui["VisibleCountBorder"].BorderBrush = $bc.ConvertFromString($t["SecBtnBorder"])
        $ui["VisibleCountText"].Foreground   = $bc.ConvertFromString($t["CountText"])
        $ui["ToolbarHintBorder"].Background  = $bc.ConvertFromString($t["CountBg"])
        $ui["ToolbarHintBorder"].BorderBrush = $bc.ConvertFromString($t["SecBtnBorder"])
        $ui["ToolbarHintText"].Foreground    = $bc.ConvertFromString($t["FooterText"])

        # DynamicResource brush updates (ComboBox, ScrollBar, Dividers, CheckBox)
        $res = $ui["Window"].Resources
        $toColor = { param([string]$hex) [System.Windows.Media.ColorConverter]::ConvertFromString($hex) }
        $res["ComboBg"]          = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboBg"]))
        $res["ComboBorder"]      = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboBorder"]))
        $res["ComboPopupBg"]     = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboPopupBg"]))
        $res["ComboArrow"]       = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboArrow"]))
        $res["ComboItemHover"]   = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboItemHover"]))
        $res["ComboItemText"]    = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboItemText"]))
        $res["ComboDisabledText"]= [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboDisabledText"]))
        $res["ScrollThumbBg"]    = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ScrollThumbBg"]))
        $res["ScrollThumbHover"] = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ScrollThumbHover"]))
        $res["DividerBrush"]     = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["DividerColor"]))
        $res["ChkBorder"]        = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ChkBorder"]))
        $res["ChkBorderHover"]   = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ChkBorderHover"]))
        $res["ChkMark"]          = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ChkMark"]))
        $res["ChkText"]          = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ChkText"]))

        # Search icon
        $ui["SearchIcon"].Foreground = $bc.ConvertFromString($t["SearchIcon"])

        # Version text
        $ui["HeaderVersion"].Foreground = $bc.ConvertFromString($t["VersionText"])

        $el = $ui["Elements"]
        for ($i = 0; $i -lt $el["CategoryCards"].Count; $i++) {
            $el["CategoryCards"][$i].Background  = $bc.ConvertFromString($t["CategoryCardBg"])
            $el["CategoryCards"][$i].BorderBrush = $bc.ConvertFromString($t["CategoryCardBorder"])
        }
        for ($i = 0; $i -lt $el["CategoryHeaders"].Count; $i++) {
            $el["CategoryHeaders"][$i].Background  = $bc.ConvertFromString($t["CategoryHeaderBg"])
            $el["CategoryHeaders"][$i].BorderBrush = $bc.ConvertFromString($t["CategoryHeaderBorder"])
        }
        for ($i = 0; $i -lt $el["CategoryTitles"].Count; $i++) {
            $el["CategoryTitles"][$i].Foreground = $bc.ConvertFromString($t["CategoryTitle"])
        }
        for ($i = 0; $i -lt $el["CategoryAlls"].Count; $i++) {
            $el["CategoryAlls"][$i].Foreground = $bc.ConvertFromString($t["CategoryAllText"])
        }
        for ($i = 0; $i -lt $el["CountBadges"].Count; $i++) {
            $el["CountBadges"][$i].Background = $bc.ConvertFromString($t["CountBadgeBg"])
        }
        for ($i = 0; $i -lt $el["CountTexts"].Count; $i++) {
            $el["CountTexts"][$i].Foreground = $bc.ConvertFromString($t["CountBadgeText"])
        }
        for ($i = 0; $i -lt $el["AppLabels"].Count; $i++) {
            $labelColor = if (($i -lt $el["InstalledDots"].Count) -and ($el["InstalledDots"][$i].Visibility -eq [System.Windows.Visibility]::Visible) -and (-not $ui["IsUpdateMode"])) {
                $t["AppSubtleText"]
            } else {
                $t["AppText"]
            }
            $el["AppLabels"][$i].Foreground = $bc.ConvertFromString($labelColor)
        }
        for ($i = 0; $i -lt $el["AppStatusBadges"].Count; $i++) {
            $el["AppStatusBadges"][$i].Background = $bc.ConvertFromString($t["InstalledBadgeBg"])
            $el["AppStatusBadges"][$i].BorderBrush = $bc.ConvertFromString($t["InstalledBadgeBg"])
        }
        for ($i = 0; $i -lt $el["AppStatusTexts"].Count; $i++) {
            $el["AppStatusTexts"][$i].Foreground = $bc.ConvertFromString($t["InstalledBadgeText"])
        }
        for ($i = 0; $i -lt $el["AppBorders"].Count; $i++) {
            $ab = $el["AppBorders"][$i]
            $cb = $ab.Child.Children[0]
            if ($cb.IsChecked) { $ab.Background = $bc.ConvertFromString($t["AppSelectedBg"]) }
            else { $ab.Background = [System.Windows.Media.Brushes]::Transparent }
        }
        foreach ($btn in $el["SecButtons"]) {
            $btn.Background  = $bc.ConvertFromString($t["SecBtnBg"])
            $btn.BorderBrush = $bc.ConvertFromString($t["SecBtnBorder"])
            $btn.Foreground  = $bc.ConvertFromString($t["SecBtnText"])
        }
        foreach ($chk in $el["FooterChecks"]) { $chk.Foreground = $bc.ConvertFromString($t["CheckboxText"]) }
        try {
            $ModeBtn.ApplyTemplate()
            $modeBorder = [System.Windows.Media.VisualTreeHelper]::GetChild($ModeBtn, 0)
            if ($modeBorder) {
                $modeBorder.Background = $bc.ConvertFromString($t["SecBtnBg"])
                $modeBorder.BorderBrush = $bc.ConvertFromString($t["SecBtnBorder"])
                $iconTb = $modeBorder.Child
                if ($iconTb) { $iconTb.Text = if ($ui["IsDark"]) { [char]0x2600 } else { [char]0x263E } }
            }
        } catch {}

        # Sidebar theming
        try {
            $ui["SidebarBorder"].Background = $bc.ConvertFromString($t["SidebarBg"])
            $ui["SidebarBorder"].BorderBrush = $bc.ConvertFromString($t["SidebarBorder"])
            $ui["SidebarTitle"].Foreground = $bc.ConvertFromString($t["CategoryTitle"])
            $ui["SidebarSubtitle"].Foreground = $bc.ConvertFromString($t["SidebarSubtitle"])
            foreach ($sbBtn in $ui["Elements"]["SidebarButtons"]) {
                $sbBtn.Foreground = $bc.ConvertFromString($t["SidebarText"])
            }
            foreach ($sbCount in $ui["Elements"]["SidebarCounts"]) {
                $sbCount.Foreground = $bc.ConvertFromString($t["SidebarCountText"])
            }
            foreach ($sbRow in $ui["Elements"]["SidebarRows"]) {
                if ($ui["ActiveSidebarRow"] -eq $sbRow) {
                    $sbRow.Background = $bc.ConvertFromString($t["SidebarActive"])
                } else {
                    $sbRow.Background = [System.Windows.Media.Brushes]::Transparent
                }
            }
        } catch {}

        # Log panel theming
        try {
            $ui["LogPanelBorder"].Background = $bc.ConvertFromString($t["LogBg"])
            $ui["LogPanelBorder"].BorderBrush = $bc.ConvertFromString($t["LogBorder"])
            $ui["LogTitle"].Foreground = $bc.ConvertFromString($t["CategoryTitle"])
            $ui["LogSubtitle"].Foreground = $bc.ConvertFromString($t["FooterText"])
        } catch {}

        try {
            $ui["EmptyStateBorder"].Background = $bc.ConvertFromString($t["EmptyStateBg"])
            $ui["EmptyStateBorder"].BorderBrush = $bc.ConvertFromString($t["EmptyStateBorder"])
            $ui["EmptyStateTitle"].Foreground = $bc.ConvertFromString($t["EmptyStateTitle"])
            $ui["EmptyStateBody"].Foreground = $bc.ConvertFromString($t["EmptyStateText"])
        } catch {}

        # Collapse arrow theming
        foreach ($arrow in $ui["Elements"]["CollapseArrows"]) {
            $arrow.Foreground = $bc.ConvertFromString($t["CollapseArrow"])
        }
    }

    # ========================================================
    # BUILD CATEGORIES (instant - icons lazy-loaded after open)
    # ========================================================
    $splash = Show-Splash
    $splash.Window.Show()
    Update-Splash $splash "Building interface..." 50

    $toBrush = { param([string]$hex) [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex) }
    $appNum = 0

    foreach ($category in $Script:SoftwareDatabase.Keys) {
        $catData = @{ Card = $null; Apps = [System.Collections.ArrayList]::new() }

        $categoryBorder = New-Object System.Windows.Controls.Border
        $categoryBorder.Background = (& $toBrush "#0d1b2b")
        $categoryBorder.BorderBrush = (& $toBrush "#1f3145")
        $categoryBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        $categoryBorder.CornerRadius = [System.Windows.CornerRadius]::new(14)
        $categoryBorder.Margin = [System.Windows.Thickness]::new(6, 6, 6, 6)
        $categoryBorder.Width = 252
        $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadow.BlurRadius = 16; $shadow.Opacity = 0.18; $shadow.ShadowDepth = 2
        $shadow.Color = [System.Windows.Media.Colors]::Black
        $categoryBorder.Effect = $shadow
        [void]$ui["Elements"]["CategoryCards"].Add($categoryBorder)
        $catData["Card"] = $categoryBorder

        $categoryStack = New-Object System.Windows.Controls.StackPanel

        $headerBorder = New-Object System.Windows.Controls.Border
        $headerBorder.Background = (& $toBrush "#0f2133")
        $headerBorder.CornerRadius = [System.Windows.CornerRadius]::new(14, 14, 0, 0)
        $headerBorder.Padding = [System.Windows.Thickness]::new(12, 10, 12, 10)
        $headerBorder.BorderBrush = (& $toBrush "#21354a")
        $headerBorder.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
        [void]$ui["Elements"]["CategoryHeaders"].Add($headerBorder)

        $headerGrid = New-Object System.Windows.Controls.Grid
        $col0 = New-Object System.Windows.Controls.ColumnDefinition; $col0.Width = [System.Windows.GridLength]::Auto
        $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = [System.Windows.GridLength]::Auto
        $col3 = New-Object System.Windows.Controls.ColumnDefinition; $col3.Width = [System.Windows.GridLength]::Auto
        $headerGrid.ColumnDefinitions.Add($col0); $headerGrid.ColumnDefinitions.Add($col1); $headerGrid.ColumnDefinitions.Add($col2); $headerGrid.ColumnDefinitions.Add($col3)

        # Collapse/expand arrow
        $collapseArrow = New-Object System.Windows.Controls.TextBlock
        $collapseArrow.Text = [string][char]0x25BC
        $collapseArrow.FontSize = 9
        $collapseArrow.Foreground = (& $toBrush "#6f879e")
        $collapseArrow.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $collapseArrow.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
        [System.Windows.Controls.Grid]::SetColumn($collapseArrow, 0)
        [void]$ui["Elements"]["CollapseArrows"].Add($collapseArrow)

        $categoryTitle = New-Object System.Windows.Controls.TextBlock
        $categoryTitle.Text = $category
        $categoryTitle.FontSize = 12
        $categoryTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
        $categoryTitle.Foreground = (& $toBrush "#8cd2ff")
        $categoryTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($categoryTitle, 1)
        [void]$ui["Elements"]["CategoryTitles"].Add($categoryTitle)

        $catCount = $Script:SoftwareDatabase[$category].Count
        $countBadge = New-Object System.Windows.Controls.Border
        $countBadge.Background = (& $toBrush "#102133")
        $countBadge.CornerRadius = [System.Windows.CornerRadius]::new(999)
        $countBadge.Padding = [System.Windows.Thickness]::new(8, 3, 8, 3)
        $countBadge.Margin = [System.Windows.Thickness]::new(6, 0, 6, 0)
        $countBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $countText = New-Object System.Windows.Controls.TextBlock
        $countText.Text = $catCount.ToString()
        $countText.FontSize = 9.5
        $countText.FontWeight = [System.Windows.FontWeights]::SemiBold
        $countText.Foreground = (& $toBrush "#8ca0b7")
        $countText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $countBadge.Child = $countText
        [System.Windows.Controls.Grid]::SetColumn($countBadge, 2)
        [void]$ui["Elements"]["CountBadges"].Add($countBadge)
        [void]$ui["Elements"]["CountTexts"].Add($countText)

        $catSelectAll = New-Object System.Windows.Controls.CheckBox
        $catSelectAll.Content = "All"
        $catSelectAll.Foreground = (& $toBrush "#8ca0b7")
        $catSelectAll.FontSize = 10.5
        $catSelectAll.Cursor = [System.Windows.Input.Cursors]::Hand
        $catSelectAll.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($catSelectAll, 3)
        [void]$ui["Elements"]["CategoryAlls"].Add($catSelectAll)

        [void]$headerGrid.Children.Add($collapseArrow); [void]$headerGrid.Children.Add($categoryTitle); [void]$headerGrid.Children.Add($countBadge); [void]$headerGrid.Children.Add($catSelectAll)
        $headerBorder.Child = $headerGrid
        $headerBorder.Cursor = [System.Windows.Input.Cursors]::Hand
        [void]$categoryStack.Children.Add($headerBorder)

        $appsStack = New-Object System.Windows.Controls.StackPanel
        $appsStack.Margin = [System.Windows.Thickness]::new(8, 6, 8, 8)
        $categoryCheckboxList = [System.Collections.ArrayList]::new()

        foreach ($app in $Script:SoftwareDatabase[$category]) {
            $appNum++

            $appBorder = New-Object System.Windows.Controls.Border
            $appBorder.CornerRadius = [System.Windows.CornerRadius]::new(10)
            $appBorder.Padding = [System.Windows.Thickness]::new(8, 6, 8, 6)
            $appBorder.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
            $appBorder.Cursor = [System.Windows.Input.Cursors]::Hand
            [void]$ui["Elements"]["AppBorders"].Add($appBorder)

            $appStack = New-Object System.Windows.Controls.Grid
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))

            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $checkbox.Tag = $app
            [System.Windows.Controls.Grid]::SetColumn($checkbox, 0)

            $iconImage = New-Object System.Windows.Controls.Image
            $iconImage.Width = 18; $iconImage.Height = 18
            $iconImage.Margin = [System.Windows.Thickness]::new(10, 0, 8, 0)
            $iconImage.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            [System.Windows.Controls.Grid]::SetColumn($iconImage, 2)

            # Instant letter-icon placeholder; real icons load async after window opens
            $iconImage.Source = New-LetterIcon -Letter $app.Name[0] -ColorHex (Get-LetterColor $app.Name)
            [void]$ui["IconQueue"].Add(@{ Image = $iconImage; Url = $app.Icon; Name = $app.Name })

            $appLabel = New-Object System.Windows.Controls.TextBlock
            $appLabel.Text = $app.Name
            $appLabel.FontSize = 11.5
            $appLabel.Foreground = (& $toBrush "#e5edf5")
            $appLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $appLabel.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
            [System.Windows.Controls.Grid]::SetColumn($appLabel, 3)
            [void]$ui["Elements"]["AppLabels"].Add($appLabel)

            $installedBadge = New-Object System.Windows.Controls.Border
            $installedBadge.Background = (& $toBrush "#103526")
            $installedBadge.BorderBrush = (& $toBrush "#103526")
            $installedBadge.BorderThickness = [System.Windows.Thickness]::new(1)
            $installedBadge.CornerRadius = [System.Windows.CornerRadius]::new(999)
            $installedBadge.Padding = [System.Windows.Thickness]::new(7, 2, 7, 2)
            $installedBadge.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
            $installedBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $installedBadge.Visibility = [System.Windows.Visibility]::Collapsed
            $installedBadge.ToolTip = "Already installed"
            [System.Windows.Controls.Grid]::SetColumn($installedBadge, 4)

            $installedText = New-Object System.Windows.Controls.TextBlock
            $installedText.Text = "Installed"
            $installedText.FontSize = 9.5
            $installedText.FontWeight = [System.Windows.FontWeights]::SemiBold
            $installedText.Foreground = (& $toBrush "#78ddb1")
            $installedBadge.Child = $installedText
            [void]$ui["Elements"]["InstalledDots"].Add($installedBadge)
            [void]$ui["Elements"]["AppStatusBadges"].Add($installedBadge)
            [void]$ui["Elements"]["AppStatusTexts"].Add($installedText)

            [void]$appStack.Children.Add($checkbox)
            [void]$appStack.Children.Add($iconImage)
            [void]$appStack.Children.Add($appLabel)
            [void]$appStack.Children.Add($installedBadge)

            $appBorder.Child = $appStack

            # Enhanced tooltip with WingetId
            $tipStack = New-Object System.Windows.Controls.StackPanel
            $tipName = New-Object System.Windows.Controls.TextBlock
            $tipName.Text = $app.Name; $tipName.FontWeight = [System.Windows.FontWeights]::SemiBold; $tipName.FontSize = 12
            $tipId = New-Object System.Windows.Controls.TextBlock
            $tipId.Text = $app.WingetId; $tipId.Foreground = (& $toBrush "#6c7a89"); $tipId.FontSize = 11
            [void]$tipStack.Children.Add($tipName); [void]$tipStack.Children.Add($tipId)
            $appBorder.ToolTip = $tipStack

            # Shift-click support: track app index for range selection
            $localAppNum = $appNum
            $appBorder.Add_MouseLeftButtonDown({
                param($s,$e)
                $cb = $s.Child.Children[0]
                $shiftHeld = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
                if ($shiftHeld -and $ui["LastClickedIndex"] -ge 0) {
                    $startIdx = [math]::Min($ui["LastClickedIndex"], $localAppNum)
                    $endIdx = [math]::Max($ui["LastClickedIndex"], $localAppNum)
                    $newState = -not $cb.IsChecked
                    $idx = 0
                    foreach ($cat in $ui["Categories"]) {
                        foreach ($appEntry in $cat["Apps"]) {
                            $idx++
                            if ($idx -ge $startIdx -and $idx -le $endIdx) {
                                $ui["AllCheckboxes"][$appEntry["WingetId"]].IsChecked = $newState
                            }
                        }
                    }
                } else {
                    $cb.IsChecked = -not $cb.IsChecked
                }
                $ui["LastClickedIndex"] = $localAppNum
                $e.Handled = $true
            }.GetNewClosure())
            $appBorder.Add_MouseEnter({ param($s,$e); $hc=$ui["HoverBg"]; if($hc){ $s.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($hc) } }.GetNewClosure())
            $appBorder.Add_MouseLeave({ param($s,$e); $cb=$s.Child.Children[0]; if($cb.IsChecked){ $sc=$ui["SelectedBg"]; if($sc){$s.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($sc)}}else{$s.Background=[System.Windows.Media.Brushes]::Transparent} }.GetNewClosure())
            $checkbox.Add_Checked({ param($sender,$e); $sc=$ui["SelectedBg"]; if($sc){$sender.Parent.Parent.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($sc)}; & $UpdateSelectedCount }.GetNewClosure())
            $checkbox.Add_Unchecked({ param($sender,$e); $sender.Parent.Parent.Background=[System.Windows.Media.Brushes]::Transparent; & $UpdateSelectedCount }.GetNewClosure())

            [void]$appsStack.Children.Add($appBorder)
            $ui["AllCheckboxes"][$app.WingetId] = $checkbox
            [void]$categoryCheckboxList.Add($checkbox)

            # Track for filtering
            [void]$catData["Apps"].Add(@{
                Border = $appBorder; Name = $app.Name; WingetId = $app.WingetId
            })
        }

        $catCbList = $categoryCheckboxList.ToArray()
        $catSelectAll.Add_Click({ param($sender,$e); $isChecked=$sender.IsChecked; foreach($cb in $catCbList){if($cb.Parent.Parent.Visibility -eq 'Visible'){$cb.IsChecked=$isChecked}} }.GetNewClosure())

        # Collapse/expand on header click
        $localAppsStack = $appsStack
        $localArrow = $collapseArrow
        $headerBorder.Add_MouseLeftButtonDown({
            param($s, $e)
            if ($localAppsStack.Visibility -eq [System.Windows.Visibility]::Visible) {
                $localAppsStack.Visibility = [System.Windows.Visibility]::Collapsed
                $localArrow.Text = [string][char]0x25B6
            } else {
                $localAppsStack.Visibility = [System.Windows.Visibility]::Visible
                $localArrow.Text = [string][char]0x25BC
            }
            $e.Handled = $true
        }.GetNewClosure())

        [void]$categoryStack.Children.Add($appsStack)
        [void]$ui["CategoryAppsStacks"].Add($appsStack)
        $categoryBorder.Child = $categoryStack
        [void]$CategoriesPanel.Children.Add($categoryBorder)
        [void]$ui["Categories"].Add($catData)
    }

    # ========================================================
    # POPULATE SIDEBAR
    # ========================================================
    $catIdx = 0
    foreach ($category in $Script:SoftwareDatabase.Keys) {
        $catCount = $Script:SoftwareDatabase[$category].Count
        $localIdx = $catIdx
        $localCard = $ui["Categories"][$catIdx]["Card"]

        $sideBtn = New-Object System.Windows.Controls.Border
        $sideBtn.Padding = [System.Windows.Thickness]::new(12, 8, 12, 8)
        $sideBtn.Margin = [System.Windows.Thickness]::new(6, 2, 6, 2)
        $sideBtn.CornerRadius = [System.Windows.CornerRadius]::new(10)
        $sideBtn.Cursor = [System.Windows.Input.Cursors]::Hand
        $sideBtn.Background = [System.Windows.Media.Brushes]::Transparent

        $sideBtnGrid = New-Object System.Windows.Controls.Grid
        $sCol1 = New-Object System.Windows.Controls.ColumnDefinition; $sCol1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $sCol2 = New-Object System.Windows.Controls.ColumnDefinition; $sCol2.Width = [System.Windows.GridLength]::Auto
        $sideBtnGrid.ColumnDefinitions.Add($sCol1); $sideBtnGrid.ColumnDefinitions.Add($sCol2)

        $sideBtnText = New-Object System.Windows.Controls.TextBlock
        $sideBtnText.Text = $category
        $sideBtnText.FontSize = 11
        $sideBtnText.Foreground = (& $toBrush "#acc0d4")
        $sideBtnText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $sideBtnText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
        [System.Windows.Controls.Grid]::SetColumn($sideBtnText, 0)

        $sideBtnCount = New-Object System.Windows.Controls.TextBlock
        $sideBtnCount.Text = $catCount.ToString()
        $sideBtnCount.FontSize = 9.5
        $sideBtnCount.Foreground = (& $toBrush "#6e859a")
        $sideBtnCount.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $sideBtnCount.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
        [System.Windows.Controls.Grid]::SetColumn($sideBtnCount, 1)

        [void]$sideBtnGrid.Children.Add($sideBtnText); [void]$sideBtnGrid.Children.Add($sideBtnCount)
        $sideBtn.Child = $sideBtnGrid

        $sideBtn.Add_MouseEnter({
            param($s,$e)
            if ($ui["ActiveSidebarRow"] -ne $s) {
                $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
                $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($t["SidebarHover"])
            }
        }.GetNewClosure())
        $sideBtn.Add_MouseLeave({
            param($s,$e)
            if ($ui["ActiveSidebarRow"] -ne $s) {
                $s.Background = [System.Windows.Media.Brushes]::Transparent
            }
        }.GetNewClosure())
        $sideBtn.Add_MouseLeftButtonDown({
            param($s,$e)
            # Expand the category if collapsed
            $stack = $ui["CategoryAppsStacks"][$localIdx]
            if ($stack.Visibility -eq [System.Windows.Visibility]::Collapsed) {
                $stack.Visibility = [System.Windows.Visibility]::Visible
                $ui["Elements"]["CollapseArrows"][$localIdx].Text = [string][char]0x25BC
            }
            if ($ui["ActiveSidebarRow"] -and $ui["ActiveSidebarRow"] -ne $s) {
                $ui["ActiveSidebarRow"].Background = [System.Windows.Media.Brushes]::Transparent
            }
            $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
            $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($t["SidebarActive"])
            $ui["ActiveSidebarRow"] = $s
            $localCard.BringIntoView()
            $e.Handled = $true
        }.GetNewClosure())

        [void]$SidebarPanel.Children.Add($sideBtn)
        [void]$ui["SidebarButtons"].Add($sideBtnText)
        [void]$ui["Elements"]["SidebarButtons"].Add($sideBtnText)
        [void]$ui["Elements"]["SidebarCounts"].Add($sideBtnCount)
        [void]$ui["Elements"]["SidebarRows"].Add($sideBtn)
        $catIdx++
    }

    # Apps ready, icons loading in background

    # ========================================================
    # GROUPS COMBO POPULATION
    # ========================================================
    $RefreshGroupCombo = {
        $GroupCombo.Items.Clear()
        # Placeholder
        $placeholder = New-Object System.Windows.Controls.ComboBoxItem
        $placeholder.Content = "Saved and starter groups"
        $placeholder.IsEnabled = $false
        $GroupCombo.Items.Add($placeholder) | Out-Null

        # Built-in groups header
        $biHeader = New-Object System.Windows.Controls.ComboBoxItem
        $biHeader.Content = "--- Built-in Groups ---"
        $biHeader.IsEnabled = $false
        $biHeader.FontWeight = [System.Windows.FontWeights]::Bold
        $biHeader.FontSize = 10
        $GroupCombo.Items.Add($biHeader) | Out-Null

        foreach ($gName in $ui["BuiltInGroups"].Keys) {
            $count = $ui["BuiltInGroups"][$gName].Count
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = "$gName ($count)"
            $item.Tag = @{ Name = $gName; Type = "builtin" }
            $GroupCombo.Items.Add($item) | Out-Null
        }

        # User saved groups
        $saved = Get-SavedGroups
        $userProps = @($saved.PSObject.Properties)
        if ($userProps.Count -gt 0) {
            $usrHeader = New-Object System.Windows.Controls.ComboBoxItem
            $usrHeader.Content = "--- My Saved Groups ---"
            $usrHeader.IsEnabled = $false
            $usrHeader.FontWeight = [System.Windows.FontWeights]::Bold
            $usrHeader.FontSize = 10
            $GroupCombo.Items.Add($usrHeader) | Out-Null

            foreach ($prop in $userProps) {
                $count = @($prop.Value).Count
                $item = New-Object System.Windows.Controls.ComboBoxItem
                $item.Content = "$($prop.Name) ($count)"
                $item.Tag = @{ Name = $prop.Name; Type = "user" }
                $GroupCombo.Items.Add($item) | Out-Null
            }
        }

        $GroupCombo.SelectedIndex = 0
        & $UpdateGroupActionState
    }
    & $RefreshGroupCombo

    # ========================================================
    # WINGET CHECK
    # ========================================================
    $checkWinGet = {
        $status = Test-WinGet
        if ($status.Installed) {
            $WinGetStatus.Text = "WinGet $($status.Version)"
            $WinGetDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1fb879")
            $InstallWinGetBtn.Visibility = [System.Windows.Visibility]::Collapsed
        } else {
            $WinGetStatus.Text = "WinGet required"
            $WinGetDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#dc3545")
            $InstallWinGetBtn.Visibility = [System.Windows.Visibility]::Visible
        }
    }
    & $checkWinGet

    # ========================================================
    # EVENT HANDLERS
    # ========================================================

    # Search
    $SearchBorder = $Window.FindName("SearchBorder")
    $SearchBox.Add_GotFocus({
        $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        $SearchBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($t["SearchFocus"])
        $SearchBorder.BorderThickness = [System.Windows.Thickness]::new(1.5)
    }.GetNewClosure())
    $SearchBox.Add_LostFocus({
        $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        $SearchBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($t["SearchBorder"])
        $SearchBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    }.GetNewClosure())
    $SearchBox.Add_TextChanged({
        $SearchPlaceholder.Visibility = if ($SearchBox.Text.Length -gt 0) { "Collapsed" } else { "Visible" }
        & $ApplyFilter
    }.GetNewClosure())
    $ClearSearchBtn.Add_Click({ $SearchBox.Clear(); $SearchBox.Focus() | Out-Null }.GetNewClosure())
    $EmptyStateClearBtn.Add_Click({ $SearchBox.Clear(); $SearchBox.Focus() | Out-Null }.GetNewClosure())
    $EmptyStateResetModeBtn.Add_Click({ & $ExitUpdateView }.GetNewClosure())
    $MainScroll.Add_SizeChanged({ & $UpdateCardLayout }.GetNewClosure())
    $Window.Add_SizeChanged({ & $UpdateCardLayout }.GetNewClosure())
    $GroupCombo.Add_SelectionChanged({ & $UpdateGroupActionState }.GetNewClosure())

    # Dark mode
    $ModeBtn.Add_Click({ $ui["IsDark"] = -not $ui["IsDark"]; & $ApplyTheme; & $UpdateSelectedCount }.GetNewClosure())

    # Log panel toggle
    $LogToggleBtn.Add_Click({
        if ($LogPanelBorder.Visibility -eq [System.Windows.Visibility]::Visible) {
            $LogPanelBorder.Visibility = [System.Windows.Visibility]::Collapsed
            $LogToggleBtn.Content = "Show"
        } else {
            $LogPanelBorder.Visibility = [System.Windows.Visibility]::Visible
            $LogToggleBtn.Content = "Hide"
        }
    }.GetNewClosure())

    # Select/deselect only visible apps
    $SelectAllBtn.Add_Click({
        foreach ($cat in $ui["Categories"]) {
            foreach ($appEntry in $cat["Apps"]) {
                if ($appEntry["Border"].Visibility -eq 'Visible') {
                    $ui["AllCheckboxes"][$appEntry["WingetId"]].IsChecked = $true
                }
            }
        }
    }.GetNewClosure())

    $DeselectAllBtn.Add_Click({
        foreach ($cat in $ui["Categories"]) {
            foreach ($appEntry in $cat["Apps"]) {
                if ($appEntry["Border"].Visibility -eq 'Visible') {
                    $ui["AllCheckboxes"][$appEntry["WingetId"]].IsChecked = $false
                }
            }
        }
    }.GetNewClosure())

    $InstallWinGetBtn.Add_Click({ $ProgressText.Text = "Installing WinGet..."; $null = Install-WinGet; & $checkWinGet; $ProgressText.Text = "WinGet check complete." }.GetNewClosure())

    # ========================================================
    # GROUP HANDLERS
    # ========================================================

    # Helper to get selected package IDs
    $GetSelectedIds = {
        $sel = [System.Collections.ArrayList]::new()
        foreach ($cb in $ui["AllCheckboxes"].Values) {
            if ($cb.IsChecked -eq $true) { [void]$sel.Add($cb.Tag.WingetId) }
        }
        return $sel.ToArray()
    }

    # Helper to apply a list of package IDs as checked
    $ApplyPackageList = {
        param([string[]]$ids)
        foreach ($cb in $ui["AllCheckboxes"].Values) { $cb.IsChecked = $false }
        $loaded = 0
        foreach ($id in $ids) {
            if ($ui["AllCheckboxes"].ContainsKey($id)) {
                $ui["AllCheckboxes"][$id].IsChecked = $true
                $loaded++
            }
        }
        return $loaded
    }

    $LoadGroupBtn.Add_Click({
        $selected = $GroupCombo.SelectedItem
        if ($null -eq $selected -or $null -eq $selected.Tag) {
            $ProgressText.Text = "Choose a starter group or saved group first."
            return
        }
        $gName = $selected.Tag["Name"]
        $gType = $selected.Tag["Type"]

        if ($gType -eq "builtin") {
            $ids = $ui["BuiltInGroups"][$gName]
        } else {
            $saved = Get-SavedGroups
            $ids = @($saved.$gName)
        }

        $loaded = & $ApplyPackageList $ids
        $ProgressText.Text = "Applied '$gName' and selected $loaded of $($ids.Count) apps."
    }.GetNewClosure())

    $SaveGroupBtn.Add_Click({
        $sel = & $GetSelectedIds
        if ($sel.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Select at least one app before saving a group.", "No Apps Selected", "OK", "Information")
            return
        }

        # Input dialog for group name
        $inputXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Save Package Group" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" Background="#071018" MinWidth="420">
    <StackPanel Margin="26,22,26,22">
        <TextBlock Text="Save the current selection as a reusable group" Foreground="#f0f6fb" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
        <TextBlock Text="Wingetter will keep the exact package IDs so you can reload this setup later." Foreground="#90a4b8" FontSize="12" Margin="0,0,0,14" TextWrapping="Wrap" MaxWidth="340"/>
        <TextBlock Text="Group name" Foreground="#c4d2df" FontSize="12" Margin="0,0,0,6"/>
        <TextBox x:Name="GroupNameBox" FontSize="13" Padding="10,8" Background="#08131f" Foreground="#eff6fb" BorderBrush="#24374a" BorderThickness="1"/>
        <TextBlock Text="$($sel.Count) selected apps will be included." Foreground="#7a90a6" FontSize="11.5" Margin="0,10,0,0"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
            <Button x:Name="OkBtn" Content="Save Group" Padding="20,7" Margin="0,0,8,0" FontSize="12" IsDefault="True" Background="#1fb879" Foreground="White" BorderThickness="0" Cursor="Hand"/>
            <Button x:Name="CancelDlgBtn" Content="Cancel" Padding="18,7" FontSize="12" IsCancel="True" Background="#102133" Foreground="#dbe7f1" BorderBrush="#24374a" BorderThickness="1" Cursor="Hand"/>
        </StackPanel>
    </StackPanel>
</Window>
"@
        $inputReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($inputXaml))
        $inputWin = [Windows.Markup.XamlReader]::Load($inputReader)
        $inputWin.Owner = $ui["Window"]
        $nameBox = $inputWin.FindName("GroupNameBox")
        $okBtn = $inputWin.FindName("OkBtn")
        $cancelDlgBtn = $inputWin.FindName("CancelDlgBtn")

        $okBtn.Add_Click({ $inputWin.DialogResult = $true; $inputWin.Close() }.GetNewClosure())
        $cancelDlgBtn.Add_Click({ $inputWin.DialogResult = $false; $inputWin.Close() }.GetNewClosure())

        $nameBox.Focus() | Out-Null
        if ($inputWin.ShowDialog() -eq $true) {
            $gName = $nameBox.Text.Trim()
            if ($gName -ne "") {
                Save-GroupToFile -Name $gName -PackageIds $sel
                & $RefreshGroupCombo
                $ProgressText.Text = "Saved '$gName' with $($sel.Count) selected apps."
            }
        }
    }.GetNewClosure())

    $DeleteGroupBtn.Add_Click({
        $selected = $GroupCombo.SelectedItem
        if ($null -eq $selected -or $null -eq $selected.Tag) {
            $ProgressText.Text = "Choose a saved group to delete."
            return
        }
        if ($selected.Tag["Type"] -eq "builtin") {
            $ProgressText.Text = "Built-in groups can't be deleted."
            return
        }
        $gName = $selected.Tag["Name"]
        $confirm = [System.Windows.MessageBox]::Show("Delete the saved group '$gName'? This can't be undone.", "Delete Saved Group", "YesNo", "Warning")
        if ($confirm -ne "Yes") {
            $ProgressText.Text = "Delete cancelled."
            return
        }
        Remove-GroupFromFile -Name $gName
        & $RefreshGroupCombo
        $ProgressText.Text = "Deleted '$gName'."
    }.GetNewClosure())

    # ========================================================
    # EXPORT (WinGet JSON, Wingetter JSON, or PS1 script)
    # ========================================================
    $ExportBtn.Add_Click({
        $sel = & $GetSelectedIds
        if ($sel.Count -eq 0) { $ProgressText.Text = "Select at least one app before exporting."; return }

        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "WinGet Import JSON (*.json)|*.json|Wingetter Group JSON (*.wingetter.json)|*.wingetter.json|PowerShell Script (*.ps1)|*.ps1"
        $dlg.FileName = "WinGetPackages.json"

        if ($dlg.ShowDialog() -eq $true) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)

            switch ($dlg.FilterIndex) {
                1 {
                    Export-GroupAsWinGetJSON -GroupName $baseName -PackageIds $sel -FilePath $dlg.FileName
                    $ProgressText.Text = "Exported $($sel.Count) apps as official WinGet import JSON."
                }
                2 {
                    Export-GroupAsJSON -GroupName $baseName -PackageIds $sel -FilePath $dlg.FileName
                    $ProgressText.Text = "Exported $($sel.Count) apps as a Wingetter group JSON profile."
                }
                3 {
                    Export-GroupAsPS1 -GroupName $baseName -PackageIds $sel -FilePath $dlg.FileName -Silent $SilentCheck.IsChecked -AcceptAgreements $AcceptCheck.IsChecked
                    $ProgressText.Text = "Exported $($sel.Count) apps as a PowerShell installer."
                }
            }
        }
    }.GetNewClosure())

    # ========================================================
    # IMPORT (WinGet JSON, Wingetter JSON, or simple package ID arrays)
    # ========================================================
    $ImportBtn.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = "JSON Config (*.json;*.wingetter.json)|*.json;*.wingetter.json|All Files (*.*)|*.*"
        if ($dlg.ShowDialog() -eq $true) {
            try {
                $content = Get-Content $dlg.FileName -Raw | ConvertFrom-Json
                $fallbackName = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
                $import = Import-PackageIdsFromJSON -Content $content -FallbackGroupName $fallbackName
                $ids = @($import.PackageIds)
                if ($ids.Count -eq 0) { throw "No package IDs were found in the selected JSON file." }
                if ($import.Warnings.Count -gt 0) {
                    $ProgressText.Text = "Import warning: $($import.Warnings[0])"
                }

                $loaded = & $ApplyPackageList $ids
                $missing = $ids.Count - $loaded
                $sourceSuffix = if ($import.SourceNames.Count -gt 0) { " Sources: $(@($import.SourceNames | Select-Object -Unique) -join ', ')." } else { "" }
                if ($missing -gt 0) {
                    $ProgressText.Text = "Imported '$($import.GroupName)' ($($import.Format)) and selected $loaded of $($ids.Count) apps; $missing are not in the Wingetter catalog.$sourceSuffix"
                } else {
                    $ProgressText.Text = "Imported '$($import.GroupName)' ($($import.Format)) and selected all $loaded apps.$sourceSuffix"
                }

                # Offer to save as group
                $save = [System.Windows.MessageBox]::Show("Save '$($import.GroupName)' as a reusable Wingetter group for later?", "Save Imported Group", "YesNo", "Question")
                if ($save -eq "Yes") {
                    Save-GroupToFile -Name $import.GroupName -PackageIds $ids
                    & $RefreshGroupCombo
                    $ProgressText.Text = "Imported and saved '$($import.GroupName)' ($loaded matched apps)."
                }
            } catch {
                $ProgressText.Text = "Import failed: $($_.Exception.Message)"
            }
        }
    }.GetNewClosure())

    $CopyCommandBtn.Add_Click({
        $sel = @(); foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked) { $sel += $cb.Tag.WingetId } }
        if ($sel.Count -eq 0) { $ProgressText.Text = "Select at least one app before copying commands."; return }
        $s = if ($SilentCheck.IsChecked) { " --silent" } else { "" }
        $a = if ($AcceptCheck.IsChecked) { " --accept-package-agreements --accept-source-agreements" } else { "" }
        $cmds = $sel | ForEach-Object { "winget install --id $_ --exact$s$a" }
        [System.Windows.Clipboard]::SetText(($cmds -join "`n")); $ProgressText.Text = "Copied $($sel.Count) winget commands to the clipboard."
    }.GetNewClosure())

    $CancelBtn.Add_Click({ $ui["Cancelled"] = $true; $ProgressText.Text = "Stopping after the current package..." }.GetNewClosure())

    # Helper: add log entry to log panel
    $AddLogEntry = {
        param([string]$AppName, [string]$Status, [string]$Color)
        $statusBg = if ($ui["IsDark"]) {
            switch ($Status) {
                "SUCCESS" { "#183a2c" }
                "UP TO DATE" { "#3d3119" }
                "FAILED" { "#3d2024" }
                "ERROR" { "#3d2024" }
                "CANCELLED" { "#3d3119" }
                default { "#132132" }
            }
        } else {
            switch ($Status) {
                "SUCCESS" { "#ecfaf2" }
                "UP TO DATE" { "#fff8ea" }
                "FAILED" { "#fdf0f2" }
                "ERROR" { "#fdf0f2" }
                "CANCELLED" { "#fff8ea" }
                default { "#f4f7fb" }
            }
        }
        $entry = New-Object System.Windows.Controls.Border
        $entry.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)
        $entry.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
        $entry.CornerRadius = [System.Windows.CornerRadius]::new(10)
        $entry.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($statusBg)
        $entryGrid = New-Object System.Windows.Controls.Grid
        $eCol1 = New-Object System.Windows.Controls.ColumnDefinition; $eCol1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $eCol2 = New-Object System.Windows.Controls.ColumnDefinition; $eCol2.Width = [System.Windows.GridLength]::Auto
        $entryGrid.ColumnDefinitions.Add($eCol1); $entryGrid.ColumnDefinitions.Add($eCol2)
        $nameText = New-Object System.Windows.Controls.TextBlock
        $nameText.Text = $AppName; $nameText.FontSize = 11.5
        $theme = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        $nameText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($theme["LogText"])
        [System.Windows.Controls.Grid]::SetColumn($nameText, 0)
        $statusBadge = New-Object System.Windows.Controls.Border
        $statusBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString((if ($ui["IsDark"]) { "#132132" } else { "#ffffff" }))
        $statusBadge.CornerRadius = [System.Windows.CornerRadius]::new(999)
        $statusBadge.Padding = [System.Windows.Thickness]::new(8, 3, 8, 3)
        [System.Windows.Controls.Grid]::SetColumn($statusBadge, 1)
        $statusText = New-Object System.Windows.Controls.TextBlock
        $statusText.Text = $Status; $statusText.FontSize = 10; $statusText.FontWeight = [System.Windows.FontWeights]::SemiBold
        $statusText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
        $statusBadge.Child = $statusText
        [void]$entryGrid.Children.Add($nameText); [void]$entryGrid.Children.Add($statusBadge)
        $entry.Child = $entryGrid
        [void]$LogEntriesPanel.Children.Add($entry)
        $LogScrollViewer.ScrollToEnd()
    }

    # Install / Update handler
    $InstallBtn.Add_Click({
        $status = Test-WinGet
        if (-not $status.Installed) { [System.Windows.MessageBox]::Show("WinGet is required before Wingetter can install packages. Use 'Install WinGet' and try again.", "WinGet Required", "OK", "Warning"); return }
        $selected = @()
        foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked) { $selected += @{ Name = $cb.Tag.Name; WingetId = $cb.Tag.WingetId } } }
        if ($selected.Count -eq 0) { [System.Windows.MessageBox]::Show("Select at least one app before continuing.", "No Apps Selected", "OK", "Information"); return }

        $InstallBtn.IsEnabled = $false; $CancelBtn.IsEnabled = $true; $SelectAllBtn.IsEnabled = $false; $DeselectAllBtn.IsEnabled = $false
        foreach ($ctl in @($CopyCommandBtn, $ExportBtn, $ImportBtn, $LoadGroupBtn, $SaveGroupBtn, $DeleteGroupBtn, $GroupCombo, $UpdateAllBtn, $SearchBox, $ClearSearchBtn, $InstallWinGetBtn)) {
            $ctl.IsEnabled = $false
        }
        $ui["Cancelled"] = $false

        # Show log panel and clear previous entries
        $LogEntriesPanel.Children.Clear()
        $LogPanelBorder.Visibility = [System.Windows.Visibility]::Visible
        $LogToggleBtn.Content = "Hide"

        $isUpdate = $ui["IsUpdateMode"]
        $actionVerb = if ($isUpdate) { "Updating" } else { "Installing" }
        $total = $selected.Count; $current = 0; $ok = 0; $fail = 0; $skip = 0

        foreach ($app in $selected) {
            if ($ui["Cancelled"]) { $ProgressText.Text = "Stopped before completing the full list."; & $AddLogEntry $app.Name "CANCELLED" "#f39c12"; break }
            $current++; $pct = [math]::Round(($current / $total) * 100)
            $ProgressBar.Value = $pct; $ProgressPercent.Text = "$pct%"
            $ProgressText.Text = "$actionVerb $($app.Name) ($current of $total)..."
            [System.Windows.Forms.Application]::DoEvents()

            $wargs = if ($isUpdate) { @("upgrade", "--id", $app.WingetId, "--exact") } else { @("install", "--id", $app.WingetId, "--exact") }
            if ($SilentCheck.IsChecked) { $wargs += "--silent" }
            if ($AcceptCheck.IsChecked) { $wargs += "--accept-package-agreements"; $wargs += "--accept-source-agreements" }
            try {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "winget"; $psi.Arguments = $wargs -join " "
                $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
                $proc = [System.Diagnostics.Process]::Start($psi)
                # Read stdout/stderr asynchronously to prevent buffer deadlock
                $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
                $null = $proc.StandardError.ReadToEndAsync()
                while (-not $proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100; if ($ui["Cancelled"]) { try { $proc.Kill() } catch {}; break } }
                if (-not $ui["Cancelled"]) {
                    $out = $stdoutTask.GetAwaiter().GetResult()
                    if ($out -match "already installed|No available upgrade|No newer package|No applicable update") {
                        $skip++; & $AddLogEntry $app.Name "UP TO DATE" "#f39c12"
                    } elseif ($out -match "Successfully installed|Successfully updated") {
                        $ok++; & $AddLogEntry $app.Name "SUCCESS" "#2ecc71"
                    } elseif ($proc.ExitCode -eq 0) {
                        $ok++; & $AddLogEntry $app.Name "SUCCESS" "#2ecc71"
                    } else {
                        $fail++; & $AddLogEntry $app.Name "FAILED" "#e74c3c"
                    }
                }
            } catch { $fail++; & $AddLogEntry $app.Name "ERROR" "#e74c3c" }
            [System.Windows.Forms.Application]::DoEvents()
        }

        $InstallBtn.IsEnabled = $true; $CancelBtn.IsEnabled = $false; $SelectAllBtn.IsEnabled = $true; $DeselectAllBtn.IsEnabled = $true
        foreach ($ctl in @($ImportBtn, $GroupCombo, $UpdateAllBtn, $SearchBox, $ClearSearchBtn, $InstallWinGetBtn)) {
            $ctl.IsEnabled = $true
        }
        & $UpdateGroupActionState
        & $UpdateSelectedCount
        $doneVerb = if ($isUpdate) { "updated" } else { "installed" }
        if (-not $ui["Cancelled"]) {
            $ProgressBar.Value = 100; $ProgressPercent.Text = "100%"
            $ProgressText.Text = "Finished: $ok $doneVerb, $skip already current, $fail failed."

            # Windows Toast notification
            try {
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
                [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
                $toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
                $toastXml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>Wingetter Complete</text><text>$ok $doneVerb, $skip skipped, $fail failed (of $total)</text></binding></visual></toast>")
                $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
                [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Wingetter").Show($toast)
            } catch {}

            # Auto-restore install view after update completes
            if ($isUpdate) {
                $doneMsg = $ProgressText.Text
                & $ExitUpdateView
                $ProgressText.Text = $doneMsg
            }
        }
    }.GetNewClosure())

    # ========================================================
    # UPDATE VIEW - show only installed apps in single column
    # ========================================================
    $EnterUpdateView = {
        $ui["IsUpdateMode"] = $true
        $bc = [System.Windows.Media.BrushConverter]::new()

        # Hide sidebar
        $SidebarBorder.Visibility = [System.Windows.Visibility]::Collapsed

        # Hide irrelevant toolbar buttons (groups, export, import, copy)
        $GroupCombo.Visibility = [System.Windows.Visibility]::Collapsed
        $LoadGroupBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $SaveGroupBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $DeleteGroupBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $ExportBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $ImportBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $CopyCommandBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $Divider1.Visibility = [System.Windows.Visibility]::Collapsed
        $Divider2.Visibility = [System.Windows.Visibility]::Collapsed

        # Change CategoriesPanel to single column vertical layout
        $CategoriesPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical

        # Show only installed apps, hide everything else
        $appIdx = 0; $installedCount = 0; $catIdx2 = 0
        $activeTheme = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        foreach ($catName in $Script:SoftwareDatabase.Keys) {
            $card = $ui["Elements"]["CategoryCards"][$catIdx2]
            $apps = $Script:SoftwareDatabase[$catName]
            $catHasInstalled = $false

            # Hide category header elements
            try { $ui["Elements"]["CategoryHeaders"][$catIdx2].Visibility = [System.Windows.Visibility]::Collapsed } catch {}

            foreach ($app in $apps) {
                $isInstalled = $ui["InstalledIds"].ContainsKey($app.WingetId)
                $border = $ui["Elements"]["AppBorders"][$appIdx]

                if ($isInstalled) {
                    $border.Visibility = [System.Windows.Visibility]::Visible
                    $border.Opacity = 1.0
                    $ui["Elements"]["AppLabels"][$appIdx].Foreground = $bc.ConvertFromString($activeTheme["AppText"])
                    $ui["AllCheckboxes"][$app.WingetId].IsChecked = $true
                    $installedCount++
                    $catHasInstalled = $true
                } else {
                    $border.Visibility = [System.Windows.Visibility]::Collapsed
                }
                $appIdx++
            }

            if ($catHasInstalled) {
                # Show card but without header - just the app list
                $card.Visibility = [System.Windows.Visibility]::Visible
                $card.Width = [double]::NaN
                $card.Margin = [System.Windows.Thickness]::new(0)
                $card.BorderThickness = [System.Windows.Thickness]::new(0)
                $card.Background = [System.Windows.Media.Brushes]::Transparent
                try { $card.Effect = $null } catch {}
            } else {
                $card.Visibility = [System.Windows.Visibility]::Collapsed
            }

            # Expand apps stack (in case collapsed)
            try { $ui["CategoryAppsStacks"][$catIdx2].Visibility = [System.Windows.Visibility]::Visible } catch {}
            $catIdx2++
        }

        # Update button states - repurpose UpdateAllBtn as "Back to Browse"
        $UpdateAllBtn.Content = "Back to Browse"
        $UpdateAllBtn.ToolTip = "Return to the full install catalog."
        $ProgressText.Text = "$installedCount installed apps are ready to review. Uncheck anything you want to skip."
        $ToolbarHintText.Text = "Review mode shows only apps already detected on this PC."

        $SelectAllBtn.Content = "Select Visible"
        $DeselectAllBtn.Content = "Clear Visible"
        & $UpdateSelectedCount
        & $ApplyFilter
    }

    $ExitUpdateView = {
        $ui["IsUpdateMode"] = $false
        $bc = [System.Windows.Media.BrushConverter]::new()

        # Restore sidebar
        $SidebarBorder.Visibility = [System.Windows.Visibility]::Visible

        # Restore toolbar buttons
        $GroupCombo.Visibility = [System.Windows.Visibility]::Visible
        $LoadGroupBtn.Visibility = [System.Windows.Visibility]::Visible
        $SaveGroupBtn.Visibility = [System.Windows.Visibility]::Visible
        $DeleteGroupBtn.Visibility = [System.Windows.Visibility]::Visible
        $ExportBtn.Visibility = [System.Windows.Visibility]::Visible
        $ImportBtn.Visibility = [System.Windows.Visibility]::Visible
        $CopyCommandBtn.Visibility = [System.Windows.Visibility]::Visible
        $Divider1.Visibility = [System.Windows.Visibility]::Visible
        $Divider2.Visibility = [System.Windows.Visibility]::Visible

        # Restore horizontal wrap layout
        $CategoriesPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal

        # Clear search when leaving update mode
        $SearchBox.Text = ""

        # Show all apps, restore installed dimming and card styling
        $appIdx = 0; $catIdx2 = 0
        foreach ($catName in $Script:SoftwareDatabase.Keys) {
            $card = $ui["Elements"]["CategoryCards"][$catIdx2]
            $card.Visibility = [System.Windows.Visibility]::Visible
            $card.Width = 252
            $card.Margin = [System.Windows.Thickness]::new(6, 6, 6, 6)
            $card.BorderThickness = [System.Windows.Thickness]::new(1)
            $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
            $card.Background = $bc.ConvertFromString($t["CategoryCardBg"])
            $card.BorderBrush = $bc.ConvertFromString($t["CategoryCardBorder"])
            $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
            $shadow.BlurRadius = 16; $shadow.Opacity = 0.18; $shadow.ShadowDepth = 2
            $shadow.Color = [System.Windows.Media.Colors]::Black
            $card.Effect = $shadow

            # Restore category headers
            try { $ui["Elements"]["CategoryHeaders"][$catIdx2].Visibility = [System.Windows.Visibility]::Visible } catch {}

            $apps = $Script:SoftwareDatabase[$catName]
            foreach ($app in $apps) {
                $border = $ui["Elements"]["AppBorders"][$appIdx]
                $border.Visibility = [System.Windows.Visibility]::Visible
                $ui["AllCheckboxes"][$app.WingetId].IsChecked = $false

                if ($ui["InstalledIds"].ContainsKey($app.WingetId)) {
                    $border.Opacity = 0.55
                    $ui["Elements"]["AppLabels"][$appIdx].Foreground = $bc.ConvertFromString($t["AppSubtleText"])
                } else {
                    $border.Opacity = 1.0
                    $ui["Elements"]["AppLabels"][$appIdx].Foreground = $bc.ConvertFromString($t["AppText"])
                }
                $appIdx++
            }
            $catIdx2++
        }

        $UpdateAllBtn.Content = "Review Updates"
        $UpdateAllBtn.ToolTip = "Show installed apps from this catalog so you can choose what to update."
        $SelectAllBtn.Content = "Select Visible"
        $DeselectAllBtn.Content = "Clear Visible"
        $ToolbarHintText.Text = "Tip: Shift+Click selects a range."
        $ProgressText.Text = "Choose apps to install or load a saved group to get started."
        $ProgressBar.Value = 0; $ProgressPercent.Text = ""
        & $UpdateSelectedCount
        & $ApplyFilter
        & $UpdateCardLayout
    }

    $UpdateAllBtn.Add_Click({
        if ($ui["IsUpdateMode"]) {
            & $ExitUpdateView
            return
        }
        if ($ui["InstalledIds"].Count -eq 0) {
            [System.Windows.MessageBox]::Show("Wingetter has not detected any installed apps from its catalog yet. Please wait for the background scan to finish and try again.", "Updates Not Ready", "OK", "Information")
            return
        }
        & $EnterUpdateView
    }.GetNewClosure())

    & $ApplyTheme
    & $UpdateSelectedCount
    & $UpdateCardLayout
    & $ApplyFilter

    Update-Splash $splash "Ready!" 100
    $splash.Window.Close()

    # ==============================================================
    # ASYNC INSTALLED APP DETECTION - background winget list scan
    # ==============================================================
    $installedQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $installedRunspace = [runspacefactory]::CreateRunspace()
    $installedRunspace.Open()
    $installedPs = [PowerShell]::Create()
    $installedPs.Runspace = $installedRunspace
    [void]$installedPs.AddScript({
        param($queue)
        try {
            $output = & winget list --source winget 2>$null
            foreach ($line in $output) {
                if ($line -match '^\s*\S+.*?\s+(\S+\.\S+)\s+') {
                    $queue.Enqueue($Matches[1])
                }
            }
        } catch {}
        $queue.Enqueue("__DONE__")
    })
    [void]$installedPs.AddArgument($installedQueue)
    $installedHandle = $installedPs.BeginInvoke()

    # Build lookup: WingetId -> index in InstalledDots list
    $installedDotMap = @{}
    $dotIdx = 0
    foreach ($cat in $Script:SoftwareDatabase.Keys) {
        foreach ($app in $Script:SoftwareDatabase[$cat]) {
            $installedDotMap[$app.WingetId] = $dotIdx
            $dotIdx++
        }
    }

    $installedTimer = New-Object System.Windows.Threading.DispatcherTimer
    $installedTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    $installedTimer.Add_Tick({
        $id = $null
        $batch = 0
        while ($batch -lt 50 -and $installedQueue.TryDequeue([ref]$id)) {
            if ($id -eq "__DONE__") {
                $installedTimer.Stop()
                try { $installedPs.EndInvoke($installedHandle) } catch {}
                $installedPs.Dispose(); $installedRunspace.Close()
                $count = $ui["InstalledIds"].Count
                $baselineText = "Choose apps to install or load a saved group to get started."
                if (($ProgressText.Text -eq $baselineText) -or ($ProgressText.Text -eq "Installed-app scan complete.")) {
                    if ($count -gt 0) {
                        $ProgressText.Text = "$count installed apps detected from the Wingetter catalog. Use Review Updates to focus on them."
                    } else {
                        $ProgressText.Text = "Installed-app scan complete."
                    }
                }
                break
            }
                if ($installedDotMap.ContainsKey($id)) {
                    $ui["InstalledIds"][$id] = $true
                    $idx = $installedDotMap[$id]
                    try {
                        $ui["Elements"]["InstalledDots"][$idx].Visibility = [System.Windows.Visibility]::Visible
                        $lbl = $ui["Elements"]["AppLabels"][$idx]
                        $themeName = if ($ui["IsDark"]) { "Dark" } else { "Light" }
                        $theme = $ui["Themes"][$themeName]
                        $lbl.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($theme["AppSubtleText"])
                        $ui["Elements"]["AppBorders"][$idx].Opacity = 0.55
                    } catch {}
                }
            $batch++
        }
    }.GetNewClosure())
    $installedTimer.Start()

    # ==============================================================
    # PARALLEL ICON LOADER - 4 concurrent runspaces via RunspacePool
    # ==============================================================
    $iconWork = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $ui["IconQueue"].Count; $i++) {
        $entry = $ui["IconQueue"][$i]
        $safeName = ($entry.Name -replace '[^\w]', '_') + ".png"
        $cachePath = Join-Path $Script:IconCacheDir $safeName
        [void]$iconWork.Add(@{ Index = $i; Url = $entry.Url; CachePath = $cachePath; Name = $entry.Name })
    }

    $doneQueue = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
    $iconWorkCount = $iconWork.Count
    $iconDoneCount = [System.Collections.Concurrent.ConcurrentDictionary[string,int]]::new()
    [void]$iconDoneCount.TryAdd("count", 0)

    # Split work across 4 chunks for parallel download
    $chunkCount = 4
    $chunkSize = [math]::Ceiling($iconWorkCount / $chunkCount)
    $iconPool = [runspacefactory]::CreateRunspacePool(1, $chunkCount)
    $iconPool.Open()
    $iconJobs = [System.Collections.ArrayList]::new()

    $iconScript = {
        param($chunk, $done, $counter)
        foreach ($item in $chunk) {
            $path = $item.CachePath
            if ((Test-Path $path) -and ([System.IO.FileInfo]::new($path)).Length -gt 100) {
                $done.Enqueue(@{ Index = $item.Index; Path = $path })
                [void]$counter.AddOrUpdate("count", 1, [Func[string,int,int]]{ param($k,$v) $v + 1 })
                continue
            }
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0")
                $wc.DownloadFile($item.Url, $path)
                $wc.Dispose()
                if ((Test-Path $path) -and ([System.IO.FileInfo]::new($path)).Length -gt 100) {
                    $done.Enqueue(@{ Index = $item.Index; Path = $path })
                }
            } catch {}
            [void]$counter.AddOrUpdate("count", 1, [Func[string,int,int]]{ param($k,$v) $v + 1 })
        }
    }

    for ($c = 0; $c -lt $chunkCount; $c++) {
        $start = $c * $chunkSize
        $end = [math]::Min($start + $chunkSize, $iconWorkCount) - 1
        if ($start -gt $end) { continue }
        $chunk = $iconWork[$start..$end]
        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $iconPool
        [void]$ps.AddScript($iconScript)
        [void]$ps.AddArgument($chunk)
        [void]$ps.AddArgument($doneQueue)
        [void]$ps.AddArgument($iconDoneCount)
        [void]$iconJobs.Add(@{ PS = $ps; Handle = $ps.BeginInvoke() })
    }

    # DispatcherTimer polls doneQueue and updates Image controls on UI thread
    $iconTimer = New-Object System.Windows.Threading.DispatcherTimer
    $iconTimer.Interval = [TimeSpan]::FromMilliseconds(60)
    $iconTimer.Add_Tick({
        $batch = 0
        $result = $null
        while ($batch -lt 30 -and $doneQueue.TryDequeue([ref]$result)) {
            try {
                $entry = $ui["IconQueue"][$result.Index]
                $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
                $bitmap.BeginInit()
                $bitmap.UriSource = [Uri]::new($result.Path)
                $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bitmap.DecodePixelWidth = 20
                $bitmap.DecodePixelHeight = 20
                $bitmap.EndInit()
                if ($bitmap.PixelWidth -gt 0) { $entry.Image.Source = $bitmap }
            } catch {}
            $batch++
        }
        # Check if all workers are done
        $processed = 0; try { $processed = $iconDoneCount["count"] } catch {}
        if ($processed -ge $iconWorkCount) {
            $allDone = $true
            foreach ($j in $iconJobs) { if (-not $j.Handle.IsCompleted) { $allDone = $false; break } }
            if ($allDone) {
                $iconTimer.Stop()
                foreach ($j in $iconJobs) { try { $j.PS.EndInvoke($j.Handle) } catch {}; $j.PS.Dispose() }
                $iconPool.Close()
            }
        }
    }.GetNewClosure())
    $iconTimer.Start()

    $Window.ShowDialog() | Out-Null

    # Cleanup if window closed before icons finished
    try { $iconTimer.Stop() } catch {}
    try { foreach ($j in $iconJobs) { try { if (-not $j.Handle.IsCompleted) { $j.PS.Stop() }; $j.PS.Dispose() } catch {} }; $iconPool.Close() } catch {}
    try { $installedTimer.Stop() } catch {}
    try { if (-not $installedHandle.IsCompleted) { $installedPs.Stop() }; $installedPs.Dispose(); $installedRunspace.Close() } catch {}
}

# ============================================================================
# ENTRY POINT - redirect all output to suppress ps2exe -NoConsole popups
# ============================================================================

Show-WinGetInstallerGUI *> $null
