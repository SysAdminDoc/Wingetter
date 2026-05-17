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

function ConvertTo-WingetterSearchText {
    param([string[]]$Values)

    $joined = (@($Values) | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) }) -join " "
    return (($joined.ToLowerInvariant() -replace '[^a-z0-9]+', ' ') -replace '\s+', ' ').Trim()
}

function Get-WingetterSearchScore {
    param(
        [string]$Query,
        [string]$Name,
        [string]$WingetId,
        [string]$Category = "",
        [string[]]$Groups = @(),
        [string]$Source = "",
        [string]$Scope = "",
        [bool]$IsInstalled = $false,
        [bool]$IsPinned = $false,
        [bool]$IsUpdateAvailable = $false
    )

    if ([string]::IsNullOrWhiteSpace($Query)) { return 1 }

    $tokens = @((ConvertTo-WingetterSearchText -Values @($Query)) -split '\s+' | Where-Object { $_ })
    if ($tokens.Count -eq 0) { return 1 }

    $publisher = ""
    if ($WingetId -match '^(?<publisher>[^.]+)\.') { $publisher = $matches.publisher }
    $stateTerms = @()
    if ($IsInstalled) { $stateTerms += "installed" }
    if ($IsPinned) { $stateTerms += "pinned pin" }
    if ($IsUpdateAvailable) { $stateTerms += "update available upgrade" }

    $nameText = ConvertTo-WingetterSearchText -Values @($Name)
    $idText = ConvertTo-WingetterSearchText -Values @($WingetId, ($WingetId -replace '[.\-_]', ' '))
    $categoryText = ConvertTo-WingetterSearchText -Values @($Category)
    $groupText = ConvertTo-WingetterSearchText -Values $Groups
    $publisherText = ConvertTo-WingetterSearchText -Values @($publisher)
    $stateText = ConvertTo-WingetterSearchText -Values @($Source, $Scope, $stateTerms)
    $allText = ConvertTo-WingetterSearchText -Values @($nameText, $idText, $categoryText, $groupText, $publisherText, $stateText)

    $score = 0
    foreach ($token in $tokens) {
        if (!$allText.Contains($token)) { return 0 }
        if ($nameText -eq $token) { $score += 90; continue }
        if ($nameText.StartsWith($token)) { $score += 70; continue }
        if ($nameText.Contains($token)) { $score += 50; continue }
        if ($idText.Contains($token)) { $score += 42; continue }
        if ($publisherText.Contains($token)) { $score += 34; continue }
        if ($categoryText.Contains($token)) { $score += 28; continue }
        if ($groupText.Contains($token)) { $score += 24; continue }
        if ($stateText.Contains($token)) { $score += 16; continue }
        $score += 5
    }

    return $score
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
$wingetterRoot = Get-WingetterRootPath
if (![string]::IsNullOrWhiteSpace($wingetterRoot)) {
    $catalogPath = Join-Path $wingetterRoot "catalog\winget.json"
    $externalCatalog = ConvertFrom-WingetterCatalogJson -Path $catalogPath
    if ($externalCatalog) {
        $Script:SoftwareDatabase = $externalCatalog
    }
}
