<#
.SYNOPSIS
    Wingetter - Comprehensive GUI for bulk software installation via winget
.DESCRIPTION
    A professional PowerShell GUI application for discovering, selecting, and bulk
    installing Windows software using Windows Package Manager (winget).
    Features: Dark/Light mode, app icons with caching, search filter, package groups
    (save/load/export as PS1 or JSON), 734 apps across 39 categories.
.VERSION
    5.0.0
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
    $win.Width = 520; $win.Height = 290
    $win.Topmost = $true; $win.ShowInTaskbar = $false
    $win.ResizeMode = [System.Windows.ResizeMode]::NoResize

    # Outer border with shadow
    $outer = New-Object System.Windows.Controls.Border
    $outer.Background = $bc.ConvertFromString("#0f0f23")
    $outer.CornerRadius = [System.Windows.CornerRadius]::new(18)
    $outer.BorderBrush = $bc.ConvertFromString("#2a2a4a")
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
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#5dade2"), 0)))
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#9b59b6"), 0.5)))
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#27ae60"), 1)))
    $accentLine.Background = $grad
    $grid.Children.Add($accentLine)

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
    $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#5dade2"), 0)))
    $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#a29bfe"), 1)))
    $title.Foreground = $titleGrad
    $stack.Children.Add($title)

    # Version
    $ver = New-Object System.Windows.Controls.TextBlock
    $ver.Text = "v5.0"; $ver.FontSize = 12
    $ver.Foreground = $bc.ConvertFromString("#4a4a6a")
    $ver.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $ver.Margin = [System.Windows.Thickness]::new(0, 0, 0, 24)
    $stack.Children.Add($ver)

    # Status text
    $statusTb = New-Object System.Windows.Controls.TextBlock
    $statusTb.Text = "Initializing..."
    $statusTb.FontSize = 13
    $statusTb.Foreground = $bc.ConvertFromString("#8a8aaa")
    $statusTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $statusTb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 14)
    $stack.Children.Add($statusTb)

    # Progress bar container
    $barBg = New-Object System.Windows.Controls.Border
    $barBg.Background = $bc.ConvertFromString("#1a1a2e")
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
    $barGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#5dade2"), 0)))
    $barGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#9b59b6"), 1)))
    $barFill.Background = $barGrad
    $barBg.Child = $barFill
    $stack.Children.Add($barBg)

    # Percent text
    $pctTb = New-Object System.Windows.Controls.TextBlock
    $pctTb.Text = ""; $pctTb.FontSize = 11
    $pctTb.Foreground = $bc.ConvertFromString("#4a4a6a")
    $pctTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $stack.Children.Add($pctTb)

    $grid.Children.Add($stack)
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

$Script:SoftwareDatabase = [ordered]@{

    "Web Browsers" = @(
        @{ Name = "Google Chrome"; WingetId = "Google.Chrome"; Icon = "${f}google.com"}
        @{ Name = "Mozilla Firefox"; WingetId = "Mozilla.Firefox"; Icon = "${f}mozilla.org"}
        @{ Name = "Microsoft Edge"; WingetId = "Microsoft.Edge"; Icon = "${f}microsoft.com"}
        @{ Name = "Brave"; WingetId = "Brave.Brave"; Icon = "${f}brave.com"}
        @{ Name = "Opera"; WingetId = "Opera.Opera"; Icon = "${f}opera.com"}
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
        @{ Name = "Discord"; WingetId = "Discord.Discord"; Icon = "${f}discord.com"}
        @{ Name = "Zoom"; WingetId = "Zoom.Zoom"; Icon = "${f}zoom.us"}
        @{ Name = "Microsoft Teams"; WingetId = "Microsoft.Teams"; Icon = "${f}teams.microsoft.com" }
        @{ Name = "Slack"; WingetId = "SlackTechnologies.Slack"; Icon = "${f}slack.com"}
        @{ Name = "WhatsApp"; WingetId = "WhatsApp.WhatsApp"; Icon = "${f}whatsapp.com" }
        @{ Name = "Telegram"; WingetId = "Telegram.TelegramDesktop"; Icon = "${f}telegram.org" }
        @{ Name = "Signal"; WingetId = "OpenWhisperSystems.Signal"; Icon = "${f}signal.org" }
        @{ Name = "Skype"; WingetId = "Microsoft.Skype"; Icon = "${f}skype.com"}
        @{ Name = "Thunderbird"; WingetId = "Mozilla.Thunderbird"; Icon = "${f}thunderbird.net"}
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
        @{ Name = "VLC"; WingetId = "VideoLAN.VLC"; Icon = "${f}videolan.org"}
        @{ Name = "MPC-HC"; WingetId = "clsid2.mpc-hc"; Icon = "${f}github.com"}
        @{ Name = "PotPlayer"; WingetId = "Daum.PotPlayer"; Icon = "${f}potplayer.daum.net" }
        @{ Name = "Kodi"; WingetId = "XBMCFoundation.Kodi"; Icon = "${f}kodi.tv" }
        @{ Name = "K-Lite Codec Pack"; WingetId = "CodecGuide.K-LiteCodecPack.Full"; Icon = "${f}codecguide.com"}
        @{ Name = "KMPlayer"; WingetId = "PandoraTV.KMPlayer"; Icon = "${f}kmplayer.com"}
        @{ Name = "GOM Player"; WingetId = "GOM.GOMPlayer"; Icon = "${f}gomlab.com"}
        @{ Name = "Plex"; WingetId = "Plex.Plex"; Icon = "${f}plex.tv"}
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
        @{ Name = "Spotify"; WingetId = "Spotify.Spotify"; Icon = "${f}spotify.com"}
        @{ Name = "iTunes"; WingetId = "Apple.iTunes"; Icon = "${f}apple.com"}
        @{ Name = "foobar2000"; WingetId = "PeterPawlowski.foobar2000"; Icon = "${f}foobar2000.org"}
        @{ Name = "AIMP"; WingetId = "AIMP.AIMP"; Icon = "${f}aimp.ru"}
        @{ Name = "MusicBee"; WingetId = "MusicBee.MusicBee"; Icon = "${f}getmusicbee.com" }
        @{ Name = "Audacity"; WingetId = "Audacity.Audacity"; Icon = "${f}audacityteam.org"}
        @{ Name = "Winamp"; WingetId = "Winamp.Winamp"; Icon = "${f}winamp.com"}
        @{ Name = "MediaMonkey"; WingetId = "MediaMonkey.MediaMonkey"; Icon = "${f}mediamonkey.com"}
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
        @{ Name = "HandBrake"; WingetId = "HandBrake.HandBrake"; Icon = "${f}handbrake.fr"}
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
        @{ Name = "GIMP"; WingetId = "GIMP.GIMP"; Icon = "${f}gimp.org"}
        @{ Name = "Paint.NET"; WingetId = "dotPDN.PaintDotNet"; Icon = "${f}getpaint.net"}
        @{ Name = "Krita"; WingetId = "KDE.Krita"; Icon = "${f}krita.org" }
        @{ Name = "Inkscape"; WingetId = "Inkscape.Inkscape"; Icon = "${f}inkscape.org"}
        @{ Name = "Blender"; WingetId = "BlenderFoundation.Blender"; Icon = "${f}blender.org"}
        @{ Name = "IrfanView"; WingetId = "IrfanSkiljan.IrfanView"; Icon = "${f}irfanview.com"}
        @{ Name = "XnView MP"; WingetId = "XnSoft.XnViewMP"; Icon = "${f}xnview.com"}
        @{ Name = "FastStone Viewer"; WingetId = "FastStone.Viewer"; Icon = "${f}faststone.org"}
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
    )

    "Screenshot & Recording" = @(
        @{ Name = "ShareX"; WingetId = "ShareX.ShareX"; Icon = "${f}getsharex.com"}
        @{ Name = "Greenshot"; WingetId = "Greenshot.Greenshot"; Icon = "${f}getgreenshot.org"}
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
        @{ Name = "LibreOffice"; WingetId = "TheDocumentFoundation.LibreOffice"; Icon = "${f}libreoffice.org"}
        @{ Name = "OpenOffice"; WingetId = "Apache.OpenOffice"; Icon = "${f}openoffice.org"}
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
        @{ Name = "Foxit PDF Reader"; WingetId = "Foxit.FoxitReader"; Icon = "${f}foxit.com"}
        @{ Name = "SumatraPDF"; WingetId = "SumatraPDF.SumatraPDF"; Icon = "${f}sumatrapdfreader.org"}
        @{ Name = "CutePDF Writer"; WingetId = "AcroSoftware.CutePDF.Writer"; Icon = "${f}cutepdf.com"}
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
        @{ Name = "Evernote"; WingetId = "Evernote.Evernote"; Icon = "${f}evernote.com"}
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
        @{ Name = "Google Drive"; WingetId = "Google.GoogleDrive"; Icon = "${f}drive.google.com"}
        @{ Name = "Dropbox"; WingetId = "Dropbox.Dropbox"; Icon = "${f}dropbox.com"}
        @{ Name = "OneDrive"; WingetId = "Microsoft.OneDrive"; Icon = "${f}onedrive.com"}
        @{ Name = "MEGA"; WingetId = "Mega.MEGASync"; Icon = "${f}mega.io" }
        @{ Name = "pCloud"; WingetId = "pCloud.pCloud"; Icon = "${f}pcloud.com" }
        @{ Name = "Nextcloud"; WingetId = "Nextcloud.NextcloudDesktop"; Icon = "${f}nextcloud.com" }
        @{ Name = "Syncthing"; WingetId = "Syncthing.Syncthing"; Icon = "${f}syncthing.net" }
        @{ Name = "ownCloud Desktop"; WingetId = "ownCloud.ownCloudDesktop"; Icon = "${f}owncloud.com" }
        @{ Name = "Tresorit"; WingetId = "Tresorit.Tresorit"; Icon = "${f}tresorit.com" }
    )

    "Compression" = @(
        @{ Name = "7-Zip"; WingetId = "7zip.7zip"; Icon = "${f}7-zip.org"}
        @{ Name = "WinRAR"; WingetId = "RARLab.WinRAR"; Icon = "${f}rarlab.com"}
        @{ Name = "PeaZip"; WingetId = "Giorgiotani.Peazip"; Icon = "${f}peazip.github.io"}
        @{ Name = "NanaZip"; WingetId = "M2Team.NanaZip"; Icon = "${f}github.com" }
        @{ Name = "Bandizip"; WingetId = "Bandisoft.Bandizip"; Icon = "${f}bandisoft.com" }
    )

    "File Management" = @(
        @{ Name = "Everything"; WingetId = "voidtools.Everything"; Icon = "${f}voidtools.com"}
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
        @{ Name = "Malwarebytes"; WingetId = "Malwarebytes.Malwarebytes"; Icon = "${f}malwarebytes.com"}
        @{ Name = "Avast Free"; WingetId = "Avast.AvastFreeAntivirus"; Icon = "${f}avast.com"}
        @{ Name = "AVG Free"; WingetId = "AVG.AVGFreeAntivirus"; Icon = "${f}avg.com"}
        @{ Name = "Avira Free"; WingetId = "Avira.Avira"; Icon = "${f}avira.com"}
        @{ Name = "SUPERAntiSpyware"; WingetId = "SUPERAntiSpyware.SUPERAntiSpyware"; Icon = "${f}superantispyware.com"}
        @{ Name = "AdwCleaner"; WingetId = "Malwarebytes.AdwCleaner"; Icon = "${f}malwarebytes.com" }
        @{ Name = "GlassWire"; WingetId = "GlassWire.GlassWire"; Icon = "${f}glasswire.com" }
        @{ Name = "simplewall"; WingetId = "henrypp.simplewall"; Icon = "${f}henrypp.org" }
        @{ Name = "Kaspersky Free"; WingetId = "Kaspersky.KasperskyFree"; Icon = "${f}kaspersky.com" }
        @{ Name = "Portmaster"; WingetId = "Safing.Portmaster"; Icon = "${f}safing.io" }
        @{ Name = "Windows Firewall Control"; WingetId = "BiniSoft.WindowsFirewallControl"; Icon = "${f}binisoft.org" }
        @{ Name = "Wazuh."; WingetId = "Wazuh.WazuhAgent"; Icon = "${f}wazuh.com" }
        @{ Name = "HitmanPro"; WingetId = "Sophos.HitmanPro"; Icon = "${f}hitmanpro.com" }
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
        @{ Name = "TeamViewer"; WingetId = "TeamViewer.TeamViewer"; Icon = "${f}teamviewer.com"}
        @{ Name = "AnyDesk"; WingetId = "AnyDeskSoftwareGmbH.AnyDesk"; Icon = "${f}anydesk.com" }
        @{ Name = "RustDesk"; WingetId = "RustDesk.RustDesk"; Icon = "${f}rustdesk.com" }
        @{ Name = "Parsec"; WingetId = "Parsec.Parsec"; Icon = "${f}parsec.app" }
        @{ Name = "PuTTY"; WingetId = "PuTTY.PuTTY"; Icon = "${f}putty.org"}
        @{ Name = "WinSCP"; WingetId = "WinSCP.WinSCP"; Icon = "${f}winscp.net"}
        @{ Name = "FileZilla"; WingetId = "TimKosse.FileZilla.Client"; Icon = "${f}filezilla-project.org"}
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
        @{ Name = "Notepad++"; WingetId = "Notepad++.Notepad++"; Icon = "${f}notepad-plus-plus.org"}
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
        @{ Name = "Visual Studio Code Insiders"; WingetId = "Microsoft.VisualStudioCode.Insiders" }
        @{ Name = "RubyMine"; WingetId = "JetBrains.RubyMine"; Icon = "${f}jetbrains.com" }
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
        @{ Name = "WinMerge"; WingetId = "WinMerge.WinMerge"; Icon = "${f}winmerge.org"}
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
        @{ Name = "Docker CLI"; WingetId = "Docker.DockerCLI" }
        @{ Name = "Git Butler"; WingetId = "GitButler.GitButler"; Icon = "${f}gitbutler.com" }
        @{ Name = "Gitify"; WingetId = "Gitify.Gitify"; Icon = "${f}gitify.io" }
        @{ Name = "Jetbrains Toolbox"; WingetId = "JetBrains.Toolbox"; Icon = "${f}jetbrains.com" }
        @{ Name = "HxD Hex Editor"; WingetId = "MHNexus.HxD"; Icon = "${f}mh-nexus.de" }
        @{ Name = "Code With Mu (Mu Editor)"; WingetId = "Mu.Mu"; Icon = "${f}codewith.mu" }
        @{ Name = "Sublime Merge"; WingetId = "SublimeHQ.SublimeMerge"; Icon = "${f}sublimemerge.com" }
        @{ Name = "Fiddler Everywhere"; WingetId = "Telerik.FiddlerEverywhere"; Icon = "${f}telerik.com" }
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
        @{ Name = "GNU Wget"; WingetId = "JernejSimoncic.Wget" }
        @{ Name = "cURL"; WingetId = "cURL.cURL" }
        @{ Name = "Gsudo"; WingetId = "gerardog.gsudo"; Icon = "${f}gerardog.github.io" }
        @{ Name = "Neofetch"; WingetId = "nepnep.neofetch-win"; Icon = "${f}github.com" }
        @{ Name = "gping"; WingetId = "orf.gping"; Icon = "${f}github.com" }
    )

    "Runtimes & SDKs" = @(
        @{ Name = "Python 3.13"; WingetId = "Python.Python.3.13"; Icon = "${f}python.org" }
        @{ Name = "Python 3.12"; WingetId = "Python.Python.3.12"; Icon = "${f}python.org"}
        @{ Name = "Node.js LTS"; WingetId = "OpenJS.NodeJS.LTS"; Icon = "${f}nodejs.org"}
        @{ Name = "Node.js Current"; WingetId = "OpenJS.NodeJS"; Icon = "${f}nodejs.org" }
        @{ Name = "Java 21 JRE"; WingetId = "EclipseAdoptium.Temurin.21.JRE"; Icon = "${f}adoptium.net"}
        @{ Name = "Java 21 JDK"; WingetId = "EclipseAdoptium.Temurin.21.JDK"; Icon = "${f}adoptium.net"}
        @{ Name = "Java 17 JDK"; WingetId = "EclipseAdoptium.Temurin.17.JDK"; Icon = "${f}adoptium.net" }
        @{ Name = ".NET 8 Desktop Runtime"; WingetId = "Microsoft.DotNet.DesktopRuntime.8"; Icon = "${f}dotnet.microsoft.com"}
        @{ Name = ".NET 8 SDK"; WingetId = "Microsoft.DotNet.SDK.8"; Icon = "${f}dotnet.microsoft.com"}
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
        @{ Name = "CCleaner"; WingetId = "Piriform.CCleaner"; Icon = "${f}ccleaner.com"}
        @{ Name = "Revo Uninstaller"; WingetId = "RevoUninstaller.RevoUninstaller"; Icon = "${f}revouninstaller.com"}
        @{ Name = "Bulk Crap Uninstaller"; WingetId = "Klocman.BulkCrapUninstaller"; Icon = "${f}bcuninstaller.com" }
        @{ Name = "IObit Uninstaller"; WingetId = "IObit.Uninstaller"; Icon = "${f}iobit.com" }
        @{ Name = "Glary Utilities"; WingetId = "Glarysoft.GlaryUtilities"; Icon = "${f}glarysoft.com"}
        @{ Name = "BleachBit"; WingetId = "BleachBit.BleachBit"; Icon = "${f}bleachbit.org" }
        @{ Name = "WinDirStat"; WingetId = "WinDirStat.WinDirStat"; Icon = "${f}windirstat.net"}
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
        @{ Name = "Steam"; WingetId = "Valve.Steam"; Icon = "${f}steampowered.com"}
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
    )

    "AI & LLM Tools" = @(
        @{ Name = "Ollama"; WingetId = "Ollama.Ollama"; Icon = "${f}ollama.com" }
        @{ Name = "LM Studio"; WingetId = "ElementLabs.LMStudio"; Icon = "${f}lmstudio.ai" }
        @{ Name = "Jan"; WingetId = "Homebrew.jan"; Icon = "${f}jan.ai" }
        @{ Name = "GPT4All"; WingetId = "NomicAI.GPT4All"; Icon = "${f}gpt4all.io" }
        @{ Name = "AnythingLLM"; WingetId = "MintplexLabs.AnythingLLM"; Icon = "${f}anythingllm.com" }
        @{ Name = "Open WebUI"; WingetId = "OpenWebUI.OpenWebUI"; Icon = "${f}openwebui.com" }
        @{ Name = "KoboldCPP"; WingetId = "LostRuins.KoboldCpp"; Icon = "${f}github.com" }
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
    )

    "Package Managers" = @(
        @{ Name = "UniGetUI"; WingetId = "MartiCliment.UniGetUI"; Icon = "${f}marticliment.com" }
        @{ Name = "Scoop"; WingetId = "Scoop.Scoop"; Icon = "${f}scoop.sh" }
        @{ Name = "Chocolatey"; WingetId = "Chocolatey.Chocolatey"; Icon = "${f}chocolatey.org" }
    )

    "Other" = @(
        @{ Name = "Google Earth Pro"; WingetId = "Google.EarthPro"; Icon = "${f}earth.google.com"}
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
    Write-Host "Checking for WinGet..."
    $wingetStatus = Test-WinGet
    if ($wingetStatus.Installed) { Write-Host "WinGet already installed ($($wingetStatus.Version))"; return $true }
    Write-Host "WinGet not found. Installing..."
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
        if ($wingetStatus.Installed) { Write-Host "WinGet installed! ($($wingetStatus.Version))"; return $true }
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
        return $false
    } catch { Write-Host "ERROR: $($_.Exception.Message)"; return $false }
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
        GroupName  = $GroupName
        Generated  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Generator  = "Wingetter"
        AppCount   = $PackageIds.Count
        PackageIds = $PackageIds
    }
    $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $FilePath -Encoding UTF8
}

# Pre-built groups
$Script:BuiltInGroups = [ordered]@{
    "Essential PC Setup" = @(
        "Google.Chrome","Mozilla.Firefox","7zip.7zip","VideoLAN.VLC","Notepad++.Notepad++",
        "voidtools.Everything","Adobe.Acrobat.Reader.64-bit","GIMP.GIMP","dotPDN.PaintDotNet",
        "Microsoft.PowerToys","ShareX.ShareX"
    )
    "Web Developer" = @(
        "Microsoft.VisualStudioCode","Git.Git","OpenJS.NodeJS.LTS","Docker.DockerDesktop",
        "Postman.Postman","Mozilla.Firefox","Google.Chrome","GitHub.GitHubDesktop","GitHub.cli",
        "Microsoft.WindowsTerminal","Starship.Starship","ajeetdsouza.zoxide"
    )
    "Python Developer" = @(
        "Microsoft.VisualStudioCode","Git.Git","Python.Python.3.13","Anaconda.Miniconda3",
        "Docker.DockerDesktop","Postman.Postman","JetBrains.PyCharm.Community",
        "Microsoft.WindowsTerminal","DBeaver.DBeaver"
    )
    "Creative Suite" = @(
        "GIMP.GIMP","KDE.Krita","Inkscape.Inkscape","BlenderFoundation.Blender","OBSProject.OBSStudio",
        "HandBrake.HandBrake","Audacity.Audacity","Kdenlive.Kdenlive","Shotcut.Shotcut",
        "ShareX.ShareX","BlackmagicDesign.DaVinciResolve"
    )
    "Gaming PC" = @(
        "Valve.Steam","EpicGames.EpicGamesLauncher","GOG.Galaxy","Discord.Discord",
        "Playnite.Playnite","MoonlightGameStreamingProject.Moonlight","LizardByte.Sunshine",
        "7zip.7zip","Guru3D.Afterburner","TechPowerUp.NVCleanstall"
    )
    "Privacy & Security" = @(
        "Mozilla.Firefox","MullvadVPN.MullvadBrowser","Bitwarden.Bitwarden","ProtonTechnologies.ProtonVPN",
        "LibreWolf.LibreWolf","signalapp.signal","VeraCrypt.VeraCrypt","Cryptomator.Cryptomator",
        "Henry++.simplewall","Mullvad.MullvadVPN"
    )
    "System Admin" = @(
        "PuTTY.PuTTY","WinSCP.WinSCP","Mobatek.MobaXterm","WiresharkFoundation.Wireshark",
        "Nmap.Nmap","Microsoft.WindowsTerminal","Microsoft.PowerShell",
        "voidtools.Everything","Notepad++.Notepad++","mRemoteNG.mRemoteNG",
        "AngryIPScanner.AngryIPScanner","Microsoft.Sysinternals.ProcessExplorer"
    )
    "Streaming Setup" = @(
        "OBSProject.OBSStudio","Streamlabs.Streamlabs","VB-Audio.Voicemeeter.Banana",
        "VB-Audio.VBVirtualCable","Discord.Discord","ShareX.ShareX",
        "HandBrake.HandBrake","Gyan.FFmpeg","File-New-Project.EarTrumpet"
    )
    "Office & Productivity" = @(
        "TheDocumentFoundation.LibreOffice","Mozilla.Thunderbird","Bitwarden.Bitwarden",
        "Doist.Todoist","Obsidian.Obsidian","7zip.7zip","Adobe.Acrobat.Reader.64-bit",
        "geek.PDF24Creator","Notion.Notion","VideoLAN.VLC"
    )
    "3D Printing Workshop" = @(
        "UltiMaker.Cura","Prusa3D.PrusaSlicer","Bambulab.Bambustudio","SoftFever.OrcaSlicer",
        "FreeCAD.FreeCAD","OpenSCAD.OpenSCAD","BlenderFoundation.Blender"
    )
}

# ============================================================================
# THEME DEFINITIONS
# ============================================================================

$Script:Themes = @{
    Light = @{
        WindowBg = "#f5f5f5"; HeaderBg = "#2c3e50"; HeaderText = "#ffffff"; HeaderSubText = "#bdc3c7"
        ToolbarBg = "#ffffff"; ToolbarBorder = "#ecf0f1"
        CategoryCardBg = "#ffffff"; CategoryCardBorder = "#e0e0e0"
        CategoryHeaderBg = "#f8f9fa"; CategoryHeaderBorder = "#e0e0e0"
        CategoryTitle = "#3498db"; CategoryAllText = "#7f8c8d"
        AppText = "#2c3e50"; AppHoverBg = "#f0f0f0"; AppSelectedBg = "#e8f4fc"
        FooterBg = "#ffffff"; FooterBorder = "#ecf0f1"; FooterText = "#7f8c8d"
        StatusPillBg = "#34495e"; StatusPillText = "#bdc3c7"
        AccentGreen = "#27ae60"; AccentGreenHover = "#2ecc71"
        ProgressBg = "#ecf0f1"; ProgressText = "#2c3e50"
        SecBtnBg = "#ecf0f1"; SecBtnBorder = "#bdc3c7"; SecBtnText = "#2c3e50"
        CheckboxText = "#2c3e50"
        SearchBg = "#ffffff"; SearchBorder = "#dcdcdc"; SearchText = "#2c3e50"; SearchPlaceholder = "#bdc3c7"
        CountBg = "#f0f0f0"; CountText = "#2c3e50"
        GroupBtnBg = "#f0e6ff"; GroupBtnBorder = "#9b59b6"; GroupBtnText = "#9b59b6"
    }
    Dark = @{
        WindowBg = "#1a1a2e"; HeaderBg = "#0f0f23"; HeaderText = "#e0e0e0"; HeaderSubText = "#6c7a89"
        ToolbarBg = "#16213e"; ToolbarBorder = "#2a2a4a"
        CategoryCardBg = "#16213e"; CategoryCardBorder = "#2a2a4a"
        CategoryHeaderBg = "#1a1a3e"; CategoryHeaderBorder = "#2a2a4a"
        CategoryTitle = "#5dade2"; CategoryAllText = "#6c7a89"
        AppText = "#d0d0d0"; AppHoverBg = "#2a2a4a"; AppSelectedBg = "#1a3a5c"
        FooterBg = "#16213e"; FooterBorder = "#2a2a4a"; FooterText = "#6c7a89"
        StatusPillBg = "#0f0f23"; StatusPillText = "#6c7a89"
        AccentGreen = "#27ae60"; AccentGreenHover = "#2ecc71"
        ProgressBg = "#2a2a4a"; ProgressText = "#e0e0e0"
        SecBtnBg = "#2a2a4a"; SecBtnBorder = "#3a3a5a"; SecBtnText = "#d0d0d0"
        CheckboxText = "#d0d0d0"
        SearchBg = "#0f0f23"; SearchBorder = "#3a3a5a"; SearchText = "#e0e0e0"; SearchPlaceholder = "#6c7a89"
        CountBg = "#2a2a4a"; CountText = "#d0d0d0"
        GroupBtnBg = "#2a1a3e"; GroupBtnBorder = "#bb86fc"; GroupBtnText = "#bb86fc"
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
        Elements      = @{
            CategoryCards   = [System.Collections.ArrayList]::new()
            CategoryHeaders = [System.Collections.ArrayList]::new()
            CategoryTitles  = [System.Collections.ArrayList]::new()
            CategoryAlls    = [System.Collections.ArrayList]::new()
            AppBorders      = [System.Collections.ArrayList]::new()
            AppLabels       = [System.Collections.ArrayList]::new()
            SecButtons      = [System.Collections.ArrayList]::new()
            FooterChecks    = [System.Collections.ArrayList]::new()
        }
    }

    $XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Wingetter - 734 Apps | Install or Update Multiple Apps at Once"
        Height="900" Width="1350" MinHeight="700" MinWidth="1000"
        WindowStartupLocation="CenterScreen" Background="#1a1a2e">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Border x:Name="HeaderBorder" Grid.Row="0" Background="#0f0f23" Padding="24,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock x:Name="HeaderTitle" Text="Wingetter" FontSize="26" FontWeight="Bold" Foreground="White"/>
                    <TextBlock x:Name="HeaderSubtitle" Text="734 apps  |  Search and select  |  Install in bulk with winget" FontSize="12" Foreground="#bdc3c7" Margin="0,3,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border x:Name="CountPill" Background="#34495e" CornerRadius="4" Padding="14,7" Margin="0,0,8,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="CountLabel1" Text="Selected: " Foreground="#bdc3c7" FontSize="13"/>
                            <TextBlock x:Name="SelectedCount" Text="0" Foreground="#2ecc71" FontSize="13" FontWeight="Bold"/>
                        </StackPanel>
                    </Border>
                    <Border x:Name="StatusPill" Background="#34495e" CornerRadius="4" Padding="14,7" Margin="0,0,8,0">
                        <StackPanel Orientation="Horizontal">
                            <Ellipse x:Name="WinGetDot" Width="9" Height="9" Fill="#f39c12" Margin="0,0,7,0" VerticalAlignment="Center"/>
                            <TextBlock x:Name="WinGetStatus" Text="Checking..." Foreground="#bdc3c7" FontSize="13" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                    <Button x:Name="ModeBtn" Width="36" Height="36" Cursor="Hand" ToolTip="Toggle Dark/Light Mode">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="modeBorder" Background="#34495e" CornerRadius="4">
                                    <TextBlock Text="&#x1F319;" FontSize="16" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="modeBorder" Property="Background" Value="#4a6278"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </StackPanel>
            </Grid>
        </Border>
        <Border x:Name="ToolbarBorder" Grid.Row="1" Background="#16213e" BorderBrush="#2a2a4a" BorderThickness="0,0,0,1" Padding="24,8">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="SearchBorder" Grid.Column="0" Background="#0f0f23" BorderBrush="#3a3a5a" BorderThickness="1" CornerRadius="4" Padding="8,0" Margin="0,0,8,0" Width="260">
                    <Grid>
                        <TextBlock x:Name="SearchPlaceholder" Text="Search 734 apps..." Foreground="#6c7a89" FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False" Margin="2,0,0,0"/>
                        <TextBox x:Name="SearchBox" Background="Transparent" BorderThickness="0" FontSize="13" VerticalAlignment="Center" Foreground="#e0e0e0" Padding="2,4"/>
                    </Grid>
                </Border>
                <Border x:Name="VisibleCountBorder" Grid.Column="2" Background="#2a2a4a" CornerRadius="4" Padding="10,5" VerticalAlignment="Center">
                    <TextBlock x:Name="VisibleCountText" Text="Showing 734 of 734" FontSize="11" Foreground="#6c7a89"/>
                </Border>
                <StackPanel Grid.Column="4" Orientation="Horizontal">
                    <Button x:Name="SelectAllBtn" Content="Select All" Padding="12,5" Margin="0,0,4,0" FontSize="11" Cursor="Hand"/>
                    <Button x:Name="DeselectAllBtn" Content="Deselect All" Padding="12,5" Margin="0,0,4,0" FontSize="11" Cursor="Hand"/>
                    <Border Background="#e0e0e0" Width="1" Margin="4,2,8,2"/>
                    <ComboBox x:Name="GroupCombo" Width="170" FontSize="11" Margin="0,0,4,0" VerticalAlignment="Center"/>
                    <Button x:Name="LoadGroupBtn" Content="Load" Padding="10,5" Margin="0,0,4,0" FontSize="11" Cursor="Hand"/>
                    <Button x:Name="SaveGroupBtn" Content="Save Group" Padding="10,5" Margin="0,0,4,0" FontSize="11" Cursor="Hand"/>
                    <Button x:Name="DeleteGroupBtn" Content="Del" Padding="8,5" Margin="0,0,4,0" FontSize="11" Cursor="Hand" ToolTip="Delete selected group"/>
                    <Border Background="#e0e0e0" Width="1" Margin="4,2,8,2"/>
                    <Button x:Name="ExportBtn" Content="Export" Padding="10,5" Margin="0,0,4,0" FontSize="11" Cursor="Hand" ToolTip="Export selection as JSON config or PS1 script"/>
                    <Button x:Name="ImportBtn" Content="Import" Padding="10,5" Margin="0,0,4,0" FontSize="11" Cursor="Hand"/>
                    <Button x:Name="CopyCommandBtn" Content="Copy Cmds" Padding="10,5" FontSize="11" Cursor="Hand"/>
                </StackPanel>
            </Grid>
        </Border>
        <ScrollViewer x:Name="MainScroll" Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="14,8">
            <WrapPanel x:Name="CategoriesPanel" Orientation="Horizontal"/>
        </ScrollViewer>
        <Border x:Name="FooterBorder" Grid.Row="3" Background="#16213e" BorderBrush="#2a2a4a" BorderThickness="0,1,0,0" Padding="24,12">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="ProgressText" Text="Ready - Select apps and click 'Get Your Apps'" Foreground="#7f8c8d" FontSize="12"/>
                        <ProgressBar x:Name="ProgressBar" Height="6" Value="0" Maximum="100" Background="#ecf0f1" Foreground="#27ae60" BorderThickness="0" Margin="0,6,0,0"/>
                    </StackPanel>
                    <TextBlock x:Name="ProgressPercent" Grid.Column="1" Text="" Foreground="#2c3e50" FontSize="14" FontWeight="Bold" VerticalAlignment="Center" Margin="18,0,0,0"/>
                </Grid>
                <Grid Grid.Row="1">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <CheckBox x:Name="SilentCheck" Content="Silent Install" IsChecked="True" Foreground="#2c3e50" FontSize="12" Margin="0,0,16,0" VerticalAlignment="Center"/>
                        <CheckBox x:Name="AcceptCheck" Content="Auto-accept Agreements" IsChecked="True" Foreground="#2c3e50" FontSize="12" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal">
                        <Button x:Name="InstallWinGetBtn" Content="Install WinGet" Padding="12,6" Margin="0,0,6,0" FontSize="11" Cursor="Hand" Visibility="Collapsed"/>
                        <Button x:Name="CancelBtn" Content="Cancel" Padding="12,6" Margin="0,0,6,0" FontSize="11" Cursor="Hand" IsEnabled="False"/>
                        <Button x:Name="InstallBtn" Content="Get Your Apps" FontSize="14" FontWeight="SemiBold" Padding="28,10" Cursor="Hand" Foreground="White">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Border x:Name="installBorder" Background="#27ae60" CornerRadius="4" Padding="{TemplateBinding Padding}">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="installBorder" Property="Background" Value="#2ecc71"/>
                                        </Trigger>
                                        <Trigger Property="IsEnabled" Value="False">
                                            <Setter TargetName="installBorder" Property="Background" Value="#bdc3c7"/>
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
    $SearchBox        = $Window.FindName("SearchBox")
    $SearchPlaceholder= $Window.FindName("SearchPlaceholder")
    $VisibleCountText = $Window.FindName("VisibleCountText")

    # Store in $ui for closure access
    $ui["Window"]          = $Window
    $ui["HeaderBorder"]    = $Window.FindName("HeaderBorder")
    $ui["HeaderTitle"]     = $Window.FindName("HeaderTitle")
    $ui["HeaderSubtitle"]  = $Window.FindName("HeaderSubtitle")
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

    $UpdateSelectedCount = {
        $count = 0
        foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked -eq $true) { $count++ } }
        $SelectedCount.Text = $count.ToString()
    }

    # ========================================================
    # FILTER LOGIC - search
    # ========================================================
    $ApplyFilter = {
        $searchText = $SearchBox.Text.Trim().ToLower()
        $visCount = 0

        foreach ($cat in $ui["Categories"]) {
            $catVisible = 0
            foreach ($appEntry in $cat["Apps"]) {
                $nameMatch = ($searchText -eq "") -or ($appEntry["Name"].ToLower().Contains($searchText)) -or ($appEntry["WingetId"].ToLower().Contains($searchText))
                if ($nameMatch) {
                    $appEntry["Border"].Visibility = [System.Windows.Visibility]::Visible
                    $catVisible++
                    $visCount++
                } else {
                    $appEntry["Border"].Visibility = [System.Windows.Visibility]::Collapsed
                }
            }
            $cat["Card"].Visibility = if ($catVisible -gt 0) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }

        $total = $ui["TotalApps"]
        $VisibleCountText.Text = "Showing $visCount of $total"
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
        $ui["HeaderTitle"].Foreground         = $bc.ConvertFromString($t["HeaderText"])
        $ui["HeaderSubtitle"].Foreground      = $bc.ConvertFromString($t["HeaderSubText"])
        $ui["ToolbarBorder"].Background       = $bc.ConvertFromString($t["ToolbarBg"])
        $ui["ToolbarBorder"].BorderBrush      = $bc.ConvertFromString($t["ToolbarBorder"])
        $ui["StatusPill"].Background          = $bc.ConvertFromString($t["StatusPillBg"])
        $ui["WinGetStatusCtl"].Foreground     = $bc.ConvertFromString($t["StatusPillText"])
        $ui["CountPill"].Background           = $bc.ConvertFromString($t["StatusPillBg"])
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
        $ui["VisibleCountText"].Foreground   = $bc.ConvertFromString($t["FooterText"])

        # Group combo
        $ui["GroupCombo"].Background  = $bc.ConvertFromString($t["SearchBg"])
        $ui["GroupCombo"].Foreground  = $bc.ConvertFromString($t["SearchText"])
        $ui["GroupCombo"].BorderBrush = $bc.ConvertFromString($t["SearchBorder"])

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
        for ($i = 0; $i -lt $el["AppLabels"].Count; $i++) {
            $el["AppLabels"][$i].Foreground = $bc.ConvertFromString($t["AppText"])
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
                $modeBorder.Background = $bc.ConvertFromString($t["StatusPillBg"])
                $iconTb = $modeBorder.Child
                if ($iconTb) { $iconTb.Text = if ($ui["IsDark"]) { [char]0x2600 } else { [char]0x1F319 } }
            }
        } catch {}
    }

    # ========================================================
    # BUILD CATEGORIES (with splash screen)
    # ========================================================
    $splash = Show-Splash
    $splash.Window.Show()
    Update-Splash $splash "Loading $totalApps apps..." 0

    Write-Host "Loading $totalApps apps across $($Script:SoftwareDatabase.Keys.Count) categories..."
    $toBrush = { param([string]$hex) [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex) }
    $appNum = 0

    foreach ($category in $Script:SoftwareDatabase.Keys) {
        $catData = @{ Card = $null; Apps = [System.Collections.ArrayList]::new() }

        $categoryBorder = New-Object System.Windows.Controls.Border
        $categoryBorder.Background = (& $toBrush "#16213e")
        $categoryBorder.BorderBrush = (& $toBrush "#2a2a4a")
        $categoryBorder.BorderThickness = [System.Windows.Thickness]::new(1, 1, 1, 1)
        $categoryBorder.CornerRadius = [System.Windows.CornerRadius]::new(6)
        $categoryBorder.Margin = [System.Windows.Thickness]::new(4, 4, 4, 4)
        $categoryBorder.Width = 210
        [void]$ui["Elements"]["CategoryCards"].Add($categoryBorder)
        $catData["Card"] = $categoryBorder

        $categoryStack = New-Object System.Windows.Controls.StackPanel

        $headerBorder = New-Object System.Windows.Controls.Border
        $headerBorder.Background = (& $toBrush "#1a1a3e")
        $headerBorder.CornerRadius = [System.Windows.CornerRadius]::new(6, 6, 0, 0)
        $headerBorder.Padding = [System.Windows.Thickness]::new(10, 7, 10, 7)
        $headerBorder.BorderBrush = (& $toBrush "#2a2a4a")
        $headerBorder.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
        [void]$ui["Elements"]["CategoryHeaders"].Add($headerBorder)

        $headerGrid = New-Object System.Windows.Controls.Grid
        $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = [System.Windows.GridLength]::Auto
        $headerGrid.ColumnDefinitions.Add($col1); $headerGrid.ColumnDefinitions.Add($col2)

        $categoryTitle = New-Object System.Windows.Controls.TextBlock
        $categoryTitle.Text = $category
        $categoryTitle.FontSize = 11
        $categoryTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
        $categoryTitle.Foreground = (& $toBrush "#5dade2")
        $categoryTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($categoryTitle, 0)
        [void]$ui["Elements"]["CategoryTitles"].Add($categoryTitle)

        $catSelectAll = New-Object System.Windows.Controls.CheckBox
        $catSelectAll.Content = "All"
        $catSelectAll.Foreground = (& $toBrush "#6c7a89")
        $catSelectAll.FontSize = 10
        $catSelectAll.Cursor = [System.Windows.Input.Cursors]::Hand
        $catSelectAll.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($catSelectAll, 1)
        [void]$ui["Elements"]["CategoryAlls"].Add($catSelectAll)

        $headerGrid.Children.Add($categoryTitle); $headerGrid.Children.Add($catSelectAll)
        $headerBorder.Child = $headerGrid
        $categoryStack.Children.Add($headerBorder)

        $appsStack = New-Object System.Windows.Controls.StackPanel
        $appsStack.Margin = [System.Windows.Thickness]::new(5, 3, 5, 5)
        $categoryCheckboxList = [System.Collections.ArrayList]::new()

        foreach ($app in $Script:SoftwareDatabase[$category]) {
            $appNum++
            if ($appNum % 25 -eq 0) {
                $pct = [math]::Round(($appNum / $totalApps) * 90)
                Update-Splash $splash "Loading apps... ($appNum / $totalApps)" $pct
            }

            $appBorder = New-Object System.Windows.Controls.Border
            $appBorder.CornerRadius = [System.Windows.CornerRadius]::new(3)
            $appBorder.Padding = [System.Windows.Thickness]::new(3, 2, 3, 2)
            $appBorder.Margin = [System.Windows.Thickness]::new(0, 1, 0, 1)
            $appBorder.Cursor = [System.Windows.Input.Cursors]::Hand
            [void]$ui["Elements"]["AppBorders"].Add($appBorder)

            $appStack = New-Object System.Windows.Controls.StackPanel
            $appStack.Orientation = [System.Windows.Controls.Orientation]::Horizontal

            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $checkbox.Tag = $app

            $iconImage = New-Object System.Windows.Controls.Image
            $iconImage.Width = 16; $iconImage.Height = 16
            $iconImage.Margin = [System.Windows.Thickness]::new(5, 0, 5, 0)
            $iconImage.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

            $bmp = Get-AppIcon -Url $app.Icon -AppName $app.Name
            if ($bmp) { $iconImage.Source = $bmp }
            else { $iconImage.Source = New-LetterIcon -Letter $app.Name[0] -ColorHex (Get-LetterColor $app.Name) }

            $appLabel = New-Object System.Windows.Controls.TextBlock
            $appLabel.Text = $app.Name
            $appLabel.FontSize = 11
            $appLabel.Foreground = (& $toBrush "#d0d0d0")
            $appLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $appLabel.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
            [void]$ui["Elements"]["AppLabels"].Add($appLabel)

            $appStack.Children.Add($checkbox)
            $appStack.Children.Add($iconImage)
            $appStack.Children.Add($appLabel)

            $appBorder.Child = $appStack
            $appBorder.ToolTip = $app.WingetId

            $appBorder.Add_MouseLeftButtonDown({ param($s,$e); $cb=$s.Child.Children[0]; $cb.IsChecked=-not $cb.IsChecked; $e.Handled=$true }.GetNewClosure())
            $appBorder.Add_MouseEnter({ param($s,$e); $hc=$ui["HoverBg"]; if($hc){ $s.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($hc) } }.GetNewClosure())
            $appBorder.Add_MouseLeave({ param($s,$e); $cb=$s.Child.Children[0]; if($cb.IsChecked){ $sc=$ui["SelectedBg"]; if($sc){$s.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($sc)}}else{$s.Background=[System.Windows.Media.Brushes]::Transparent} }.GetNewClosure())
            $checkbox.Add_Checked({ param($sender,$e); $sc=$ui["SelectedBg"]; if($sc){$sender.Parent.Parent.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($sc)}; & $UpdateSelectedCount }.GetNewClosure())
            $checkbox.Add_Unchecked({ param($sender,$e); $sender.Parent.Parent.Background=[System.Windows.Media.Brushes]::Transparent; & $UpdateSelectedCount }.GetNewClosure())

            $appsStack.Children.Add($appBorder)
            $ui["AllCheckboxes"][$app.WingetId] = $checkbox
            [void]$categoryCheckboxList.Add($checkbox)

            # Track for filtering
            [void]$catData["Apps"].Add(@{
                Border = $appBorder; Name = $app.Name; WingetId = $app.WingetId
            })
        }

        $catCbList = $categoryCheckboxList.ToArray()
        $catSelectAll.Add_Click({ param($sender,$e); $isChecked=$sender.IsChecked; foreach($cb in $catCbList){if($cb.Parent.Parent.Visibility -eq 'Visible'){$cb.IsChecked=$isChecked}} }.GetNewClosure())

        $categoryStack.Children.Add($appsStack)
        $categoryBorder.Child = $categoryStack
        $CategoriesPanel.Children.Add($categoryBorder)
        [void]$ui["Categories"].Add($catData)
    }

    Write-Host "All $totalApps apps loaded."

    # ========================================================
    # GROUPS COMBO POPULATION
    # ========================================================
    $RefreshGroupCombo = {
        $GroupCombo.Items.Clear()
        # Placeholder
        $placeholder = New-Object System.Windows.Controls.ComboBoxItem
        $placeholder.Content = "-- Select Group --"
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
    }
    & $RefreshGroupCombo

    # ========================================================
    # WINGET CHECK
    # ========================================================
    $checkWinGet = {
        $status = Test-WinGet
        if ($status.Installed) {
            $WinGetStatus.Text = "WinGet $($status.Version)"
            $WinGetDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#27ae60")
            $InstallWinGetBtn.Visibility = [System.Windows.Visibility]::Collapsed
        } else {
            $WinGetStatus.Text = "WinGet Not Found"
            $WinGetDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#e74c3c")
            $InstallWinGetBtn.Visibility = [System.Windows.Visibility]::Visible
        }
    }
    & $checkWinGet

    # ========================================================
    # EVENT HANDLERS
    # ========================================================

    # Search
    $SearchBox.Add_TextChanged({
        $SearchPlaceholder.Visibility = if ($SearchBox.Text.Length -gt 0) { "Collapsed" } else { "Visible" }
        & $ApplyFilter
    }.GetNewClosure())

    # Dark mode
    $ModeBtn.Add_Click({ $ui["IsDark"] = -not $ui["IsDark"]; & $ApplyTheme }.GetNewClosure())

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
        foreach ($cb in $ui["AllCheckboxes"].Values) { $cb.IsChecked = $false }
    }.GetNewClosure())

    $InstallWinGetBtn.Add_Click({ $ProgressText.Text = "Installing WinGet..."; Install-WinGet; & $checkWinGet; $ProgressText.Text = "Ready" }.GetNewClosure())

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
            $ProgressText.Text = "Select a group from the dropdown first"
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
        $ProgressText.Text = "Loaded group '$gName': $loaded of $($ids.Count) apps selected"
    }.GetNewClosure())

    $SaveGroupBtn.Add_Click({
        $sel = & $GetSelectedIds
        if ($sel.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Select at least one app before saving a group.", "No Selection", "OK", "Information")
            return
        }

        # Input dialog for group name
        $inputXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Save Package Group" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" Background="#1a1a2e" MinWidth="380">
    <StackPanel Margin="24,18,24,18">
        <TextBlock Text="Save current selection as a package group" Foreground="#d0d0d0" FontSize="13" Margin="0,0,0,12"/>
        <TextBlock Text="Group Name:" Foreground="#bdc3c7" FontSize="12" Margin="0,0,0,4"/>
        <TextBox x:Name="GroupNameBox" FontSize="13" Padding="8,6" Background="#0f0f23" Foreground="#e0e0e0" BorderBrush="#3a3a5a" BorderThickness="1"/>
        <TextBlock Text="$($sel.Count) apps will be saved" Foreground="#6c7a89" FontSize="11" Margin="0,8,0,0"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
            <Button x:Name="OkBtn" Content="Save" Padding="20,6" Margin="0,0,8,0" FontSize="12" IsDefault="True" Background="#27ae60" Foreground="White" BorderThickness="0" Cursor="Hand"/>
            <Button x:Name="CancelDlgBtn" Content="Cancel" Padding="20,6" FontSize="12" IsCancel="True" Background="#2a2a4a" Foreground="#d0d0d0" BorderBrush="#3a3a5a" BorderThickness="1" Cursor="Hand"/>
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
                $ProgressText.Text = "Saved group '$gName' with $($sel.Count) apps"
            }
        }
    }.GetNewClosure())

    $DeleteGroupBtn.Add_Click({
        $selected = $GroupCombo.SelectedItem
        if ($null -eq $selected -or $null -eq $selected.Tag) {
            $ProgressText.Text = "Select a group to delete"
            return
        }
        if ($selected.Tag["Type"] -eq "builtin") {
            [System.Windows.MessageBox]::Show("Built-in groups cannot be deleted.", "Info", "OK", "Information")
            return
        }
        $gName = $selected.Tag["Name"]
        $confirm = [System.Windows.MessageBox]::Show("Delete group '$gName'?", "Confirm Delete", "YesNo", "Question")
        if ($confirm -eq "Yes") {
            Remove-GroupFromFile -Name $gName
            & $RefreshGroupCombo
            $ProgressText.Text = "Deleted group '$gName'"
        }
    }.GetNewClosure())

    # ========================================================
    # EXPORT (Enhanced - JSON config or PS1 script)
    # ========================================================
    $ExportBtn.Add_Click({
        $sel = & $GetSelectedIds
        if ($sel.Count -eq 0) { $ProgressText.Text = "No apps selected to export"; return }

        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "PowerShell Script (*.ps1)|*.ps1|JSON Config (*.json)|*.json"
        $dlg.FileName = "WinGetGroup"

        if ($dlg.ShowDialog() -eq $true) {
            $ext = [System.IO.Path]::GetExtension($dlg.FileName).ToLower()
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)

            if ($ext -eq ".ps1") {
                Export-GroupAsPS1 -GroupName $baseName -PackageIds $sel -FilePath $dlg.FileName -Silent $SilentCheck.IsChecked -AcceptAgreements $AcceptCheck.IsChecked
                $ProgressText.Text = "Exported $($sel.Count) apps as PowerShell script"
            } else {
                Export-GroupAsJSON -GroupName $baseName -PackageIds $sel -FilePath $dlg.FileName
                $ProgressText.Text = "Exported $($sel.Count) apps as JSON config"
            }
        }
    }.GetNewClosure())

    # ========================================================
    # IMPORT (Enhanced - supports both JSON formats)
    # ========================================================
    $ImportBtn.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = "JSON Config (*.json)|*.json|All Files (*.*)|*.*"
        if ($dlg.ShowDialog() -eq $true) {
            try {
                $content = Get-Content $dlg.FileName -Raw | ConvertFrom-Json

                # Detect format: group config (has PackageIds) vs simple array
                if ($content.PackageIds) {
                    $ids = @($content.PackageIds)
                    $gName = if ($content.GroupName) { $content.GroupName } else { "Imported" }
                } elseif ($content -is [System.Array]) {
                    $ids = @($content)
                    $gName = "Imported"
                } else {
                    throw "Unrecognized JSON format"
                }

                $loaded = & $ApplyPackageList $ids
                $ProgressText.Text = "Imported '$gName': $loaded of $($ids.Count) apps selected"

                # Offer to save as group
                $save = [System.Windows.MessageBox]::Show("Save as a named group for future use?", "Save Imported Group", "YesNo", "Question")
                if ($save -eq "Yes") {
                    Save-GroupToFile -Name $gName -PackageIds $ids
                    & $RefreshGroupCombo
                    $ProgressText.Text = "Imported and saved group '$gName' ($loaded apps)"
                }
            } catch {
                $ProgressText.Text = "Import failed: $($_.Exception.Message)"
            }
        }
    }.GetNewClosure())

    $CopyCommandBtn.Add_Click({
        $sel = @(); foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked) { $sel += $cb.Tag.WingetId } }
        if ($sel.Count -eq 0) { $ProgressText.Text = "No apps selected"; return }
        $s = if ($SilentCheck.IsChecked) { " --silent" } else { "" }
        $a = if ($AcceptCheck.IsChecked) { " --accept-package-agreements --accept-source-agreements" } else { "" }
        $cmds = $sel | ForEach-Object { "winget install --id $_ --exact$s$a" }
        [System.Windows.Clipboard]::SetText(($cmds -join "`n")); $ProgressText.Text = "Copied $($sel.Count) commands"
    }.GetNewClosure())

    $CancelBtn.Add_Click({ $ui["Cancelled"] = $true; $ProgressText.Text = "Cancelling..." }.GetNewClosure())

    # Install
    $InstallBtn.Add_Click({
        $status = Test-WinGet
        if (-not $status.Installed) { [System.Windows.MessageBox]::Show("WinGet not installed. Click 'Install WinGet' first.", "WinGet Required", "OK", "Warning"); return }
        $selected = @()
        foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked) { $selected += @{ Name = $cb.Tag.Name; WingetId = $cb.Tag.WingetId } } }
        if ($selected.Count -eq 0) { [System.Windows.MessageBox]::Show("Select at least one app.", "No Selection", "OK", "Information"); return }

        $InstallBtn.IsEnabled = $false; $CancelBtn.IsEnabled = $true; $SelectAllBtn.IsEnabled = $false; $DeselectAllBtn.IsEnabled = $false
        $ui["Cancelled"] = $false
        $total = $selected.Count; $current = 0; $ok = 0; $fail = 0; $skip = 0

        foreach ($app in $selected) {
            if ($ui["Cancelled"]) { $ProgressText.Text = "Cancelled"; break }
            $current++; $pct = [math]::Round(($current / $total) * 100)
            $ProgressBar.Value = $pct; $ProgressPercent.Text = "$pct%"
            $ProgressText.Text = "Installing $($app.Name) ($current/$total)..."
            [System.Windows.Forms.Application]::DoEvents()

            $wargs = @("install", "--id", $app.WingetId, "--exact")
            if ($SilentCheck.IsChecked) { $wargs += "--silent" }
            if ($AcceptCheck.IsChecked) { $wargs += "--accept-package-agreements"; $wargs += "--accept-source-agreements" }
            try {
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "winget"; $psi.Arguments = $wargs -join " "
                $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
                $proc = [System.Diagnostics.Process]::Start($psi)
                while (-not $proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 100; if ($ui["Cancelled"]) { $proc.Kill(); break } }
                if (-not $ui["Cancelled"]) {
                    $out = $proc.StandardOutput.ReadToEnd()
                    if ($proc.ExitCode -eq 0) { $ok++ } elseif ($out -match "already installed|No available upgrade") { $skip++ } else { $fail++ }
                }
            } catch { $fail++ }
            [System.Windows.Forms.Application]::DoEvents()
        }

        $InstallBtn.IsEnabled = $true; $CancelBtn.IsEnabled = $false; $SelectAllBtn.IsEnabled = $true; $DeselectAllBtn.IsEnabled = $true
        if (-not $ui["Cancelled"]) {
            $ProgressBar.Value = 100; $ProgressPercent.Text = "100%"
            $ProgressText.Text = "Done: $ok installed, $skip already present, $fail failed"
            $icon = if ($fail -gt 0) { "Warning" } else { "Information" }
            [System.Windows.MessageBox]::Show("Installed: $ok`nAlready present: $skip`nFailed: $fail`nTotal: $total", "Complete", "OK", $icon)
        }
    }.GetNewClosure())

    & $ApplyTheme
    $VisibleCountText.Text = "Showing $totalApps of $totalApps"

    Update-Splash $splash "Ready!" 100
    Start-Sleep -Milliseconds 300
    $splash.Window.Close()

    $Window.ShowDialog() | Out-Null
}

# ============================================================================
# ENTRY POINT
# ============================================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "Note: Running without admin. Some installs may need elevation." -ForegroundColor Yellow }

Show-WinGetInstallerGUI
