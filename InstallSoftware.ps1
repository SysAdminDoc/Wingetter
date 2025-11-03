Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ----------------------------------------
# --- Define Categorized Software List ---
# --- (Unified list from ALL user inputs) ---
# ----------------------------------------

# Format: @{ CategoryName = @{ DisplayName = 'Command' } }

$CategorizedSoftware = @{
    # Original PowerShell Module Installs (Prerequisites)
    "⚙️ Prerequisites & Infrastructure" = @{
        "Microsoft.WinGet.Client Module" = 'cmd.exe /C powershell.exe Install-Module -Name Microsoft.WinGet.Client -Confirm:$false -Force -Scope CurrentUser'
        "PSWindowsUpdate Module" = 'cmd.exe /C powershell.exe Install-Module -Name PSWindowsUpdate -Confirm:$false -Force -Scope CurrentUser'
        "PowerShellGet Resource" = 'cmd.exe /C pwsh.exe Install-PSResource -Name PowerShellGet -Confirm:$false -TrustRepository -AcceptLicense -Scope CurrentUser'
        "Windows Terminal" = 'cmd.exe /C winget install Microsoft.WindowsTerminal --accept-package-agreements --silent --force'
        "Microsoft PowerShell" = 'cmd.exe /C winget install Microsoft.PowerShell --accept-package-agreements --silent --force'
        "Cmder (Terminal Emulator)" = 'cmd.exe /C winget install Cmder.Cmder --accept-package-agreements --silent --force'
        "Alacritty Terminal" = 'cmd.exe /C winget install Alacritty.Alacritty --accept-package-agreements --silent --force'
        "WezTerm" = 'cmd.exe /C winget install WezTerm.WezTerm --accept-package-agreements --silent --force'
        "Hyper (Terminal)" = 'cmd.exe /C winget install Hyper.Hyper --accept-package-agreements --silent --force'
        "Fluent Terminal" = 'cmd.exe /C winget install FluentTerminal.FluentTerminal --accept-package-agreements --silent --force'
        "Vesktop" = 'cmd.exe /C winget.exe install --id "Vencord.Vesktop" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Windows PC Health Check" = 'cmd.exe /C winget.exe install --id "Microsoft.WindowsPCHealthCheck" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "🧰 System Utilities & Optimization" = @{
        "7-Zip" = 'cmd.exe /C winget install 7zip.7zip --accept-package-agreements --silent --force'
        "WinRAR" = 'cmd.exe /C winget install WinRAR.WinRAR --accept-package-agreements --silent --force'
        "Everything Search" = 'cmd.exe /C winget install voidtools.Everything --accept-package-agreements --silent --force'
        "CrystalDiskInfo" = 'cmd.exe /C winget install CrystalDewWorld.CrystalDiskInfo --accept-package-agreements --silent --force'
        "CrystalDiskMark" = 'cmd.exe /C winget install CrystalDewWorld.CrystalDiskMark --accept-package-agreements --silent --force'
        "Rufus Imager" = 'cmd.exe /C winget install Rufus.Rufus --accept-package-agreements --silent --force'
        "Balena Etcher" = 'cmd.exe /C winget install Balena.Etcher --accept-package-agreements --silent --force'
        "TeraCopy" = 'cmd.exe /C winget install TeraCopy.TeraCopy --accept-package-agreements --silent --force'
        "NirLauncher" = 'cmd.exe /C winget install NirSoft.NirLauncher --accept-package-agreements --silent --force'
        "Geek Uninstaller" = 'cmd.exe /C winget install GeekUninstaller.GeekUninstaller --accept-package-agreements --silent --force'
        "IObit Uninstaller" = 'cmd.exe /C winget install IObit.Uninstaller --accept-package-agreements --silent --force'
        "Sysinternals Suite" = 'cmd.exe /C winget install SysinternalsSuite.SysinternalsSuite --accept-package-agreements --silent --force'
        "WizTree" = 'cmd.exe /C winget install WizTree.WizTree --accept-package-agreements --silent --force'
        "Winaero Tweaker" = 'cmd.exe /C winget install Winaero.Tweaker --accept-package-agreements --silent --force'
        "Autoruns" = 'cmd.exe /C winget install Autoruns.Sysinternals --accept-package-agreements --silent --force'
        "Process Explorer" = 'cmd.exe /C winget install ProcessExplorer.Sysinternals --accept-package-agreements --silent --force'
        "CPU-Z" = 'cmd.exe /C winget install CPU-Z.CPU-Z --accept-package-agreements --silent --force'
        "GPU-Z" = 'cmd.exe /C winget install GPU-Z.GPU-Z --accept-package-agreements --silent --force'
        "Speccy" = 'cmd.exe /C winget install Speccy.Speccy --accept-package-agreements --silent --force'
        "Advanced Renamer" = 'cmd.exe /C winget.exe install --id "HulubuluSoftware.AdvancedRenamer" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "AnyDesk" = 'cmd.exe /C winget.exe install --id "AnyDesk.AnyDesk" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "AutoHotkey" = 'cmd.exe /C winget.exe install --id "AutoHotkey.AutoHotkey" --accept-package-agreements --silent --force'
        "Barrier (KVM)" = 'cmd.exe /C winget.exe install --id "DebaucheeOpenSourceGroup.Barrier" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Bat (Cat Clone)" = 'cmd.exe /C winget.exe install --id "sharkdp.bat" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "BleachBit" = 'cmd.exe /C winget.exe install --id "BleachBit.BleachBit" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Bulk Crap Uninstaller" = 'cmd.exe /C winget.exe install --id "Klocman.BulkCrapUninstaller" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Bulk Rename Utility" = 'cmd.exe /C winget.exe install --id "TGRMNSoftware.BulkRenameUtility" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Carnac (Keystroke Viz.)" = 'cmd.exe /C winget.exe install --id "code52.Carnac" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Compact GUI" = 'cmd.exe /C winget.exe install --id "IridiumIO.CompactGUI" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "CopyQ (Clipboard Manager)" = 'cmd.exe /C winget.exe install --id "hluk.CopyQ" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "croc (File Transfer)" = 'cmd.exe /C winget.exe install --id "schollz.croc" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "DevToys" = 'cmd.exe /C winget.exe install --id "DevToys-app.DevToys" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Ditto (Clipboard Manager)" = 'cmd.exe /C winget.exe install --id "Ditto.Ditto" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Dual Monitor Tools" = 'cmd.exe /C winget.exe install --id "GNE.DualMonitorTools" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Espanso (Text Expander)" = 'cmd.exe /C winget.exe install --id "Espanso.Espanso" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "ExifCleaner" = 'cmd.exe /C winget.exe install --id "szTheory.exifcleaner" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "F.lux" = 'cmd.exe /C winget.exe install --id "flux.flux" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "FanControl" = 'cmd.exe /C winget.exe install --id "Rem0o.FanControl" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Fastfetch" = 'cmd.exe /C winget.exe install --id "Fastfetch-cli.Fastfetch" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "File-Converter" = 'cmd.exe /C winget.exe install --id "AdrienAllard.FileConverter" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Flow launcher" = 'cmd.exe /C winget.exe install --id "Flow-Launcher.Flow-Launcher" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Fzf (Fuzzy Finder)" = 'cmd.exe /C winget.exe install --id "junegunn.fzf" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Glary Utilities" = 'cmd.exe /C winget.exe install --id "Glarysoft.GlaryUtilities" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "GlazeWM (Tiling Manager)" = 'cmd.exe /C winget.exe install --id "glzr-io.glazewm" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Gsudo" = 'cmd.exe /C winget.exe install --id "gerardog.gsudo" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "HWiNFO" = 'cmd.exe /C winget.exe install --id "REALiX.HWiNFO" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "HWMonitor" = 'cmd.exe /C winget.exe install --id "CPUID.HWMonitor" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "HxD Hex Editor" = 'cmd.exe /C winget.exe install --id "MHNexus.HxD" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Intel-PresentMon" = 'cmd.exe /C winget.exe install --id "Intel.PresentMon.Beta" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "JDownloader" = 'cmd.exe /C winget.exe install --id "AppWork.JDownloader" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "KDE Connect" = 'cmd.exe /C winget.exe install --id "KDE.KDEConnect" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Lenovo Legion Toolkit" = 'cmd.exe /C winget.exe install --id "BartoszCichecki.LenovoLegionToolkit" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Link Shell extension" = 'cmd.exe /C winget.exe install --id "HermannSchinagl.LinkShellExtension" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Lively Wallpaper" = 'cmd.exe /C winget.exe install --id "rocksdanister.LivelyWallpaper" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "LocalSend" = 'cmd.exe /C winget.exe install --id "LocalSend.LocalSend" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "LockHunter" = 'cmd.exe /C winget.exe install --id "CrystalRich.LockHunter" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Magic Wormhole" = 'cmd.exe /C winget.exe install --id "magic-wormhole.magic-wormhole" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Meld" = 'cmd.exe /C winget.exe install --id "Meld.Meld" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Miniconda" = 'cmd.exe /C winget.exe install --id "Anaconda.Miniconda3" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Monitorian" = 'cmd.exe /C winget.exe install --id "emoacht.Monitorian" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Motrix Download Manager" = 'cmd.exe /C winget.exe install --id "agalwood.Motrix" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "MSEdgeRedirect" = 'cmd.exe /C winget.exe install --id "rcmaehl.MSEdgeRedirect" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "NanaZip" = 'cmd.exe /C winget.exe install --id "M2Team.NanaZip" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Neofetch" = 'cmd.exe /C winget.exe install --id "nepnep.neofetch-win" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Nextcloud Desktop" = 'cmd.exe /C winget.exe install --id "Nextcloud.NextcloudDesktop" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "nGlide (3dfx compatibility)" = 'cmd.exe /C winget.exe install --id "ZeusSoftware.nGlide" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Nilesoft Shell" = 'cmd.exe /C winget.exe install --id "Nilesoft.Shell" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "NTLite" = 'cmd.exe /C winget.exe install --id "Nlitesoft.NTLite" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Nushell" = 'cmd.exe /C winget.exe install --id "Nushell.Nushell" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "NVCleanstall" = 'cmd.exe /C winget.exe install --id "TechPowerUp.NVCleanstall" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "OFGB (Oh Frick Go Back)" = 'cmd.exe /C winget.exe install --id "xM4ddy.OFGB" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Open HashTab" = 'cmd.exe /C winget.exe install --id "namazso.OpenHashTab" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Open Shell (Start Menu)" = 'cmd.exe /C winget.exe install --id "Open-Shell.Open-Shell-Menu" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "OPAutoClicker" = 'cmd.exe /C winget.exe install --id "OPAutoClicker.OPAutoClicker" --accept-package-agreements --silent --force'
        "Oracle VirtualBox" = 'cmd.exe /C winget.exe install --id "Oracle.VirtualBox" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "ownCloud Desktop" = 'cmd.exe /C winget.exe install --id "ownCloud.ownCloudDesktop" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "PeaZip" = 'cmd.exe /C winget.exe install --id "Giorgiotani.Peazip" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Quicklook" = 'cmd.exe /C winget.exe install --id "QL-Win.QuickLook" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Rainmeter" = 'cmd.exe /C winget.exe install --id "Rainmeter.Rainmeter" --accept-package-agreements --silent --force'
        "Raspberry Pi Imager" = 'cmd.exe /C winget.exe install --id "RaspberryPiFoundation.RaspberryPiImager" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Revo Uninstaller" = 'cmd.exe /C winget.exe install --id "RevoUninstaller.RevoUninstaller" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Ripgrep" = 'cmd.exe /C winget.exe install --id "BurntSushi.ripgrep.MSVC" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "SageThumbs" = 'cmd.exe /C winget.exe install --id "CherubicSoftware.SageThumbs" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Sandboxie Plus" = 'cmd.exe /C winget.exe install --id "Sandboxie.Plus" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Snappy Driver Installer Origin" = 'cmd.exe /C winget install Snappy.SnappyDriverInstallerOrigin --accept-package-agreements --silent --force'
        "SpaceSniffer" = 'cmd.exe /C winget.exe install --id "UderzoSoftware.SpaceSniffer" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Spacedrive File Manager" = 'cmd.exe /C winget.exe install --id "spacedrive.Spacedrive" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "SuperF4" = 'cmd.exe /C winget.exe install --id "StefanSundin.Superf4" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "SyncTrayzor" = 'cmd.exe /C winget.exe install --id "SyncTrayzor.SyncTrayzor" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Syncthingtray" = 'cmd.exe /C winget.exe install --id "Martchus.syncthingtray" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "SysInternals Process Monitor" = 'cmd.exe /C winget.exe install --id "Microsoft.Sysinternals.ProcessMonitor" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "SysInternals TCPView" = 'cmd.exe /C winget.exe install --id "Microsoft.Sysinternals.TCPView" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "TeamViewer" = 'cmd.exe /C winget install TeamViewer.TeamViewer --accept-package-agreements --silent --force'
        "TightVNC" = 'cmd.exe /C winget install TightVNC.TightVNC --accept-package-agreements --silent --force'
        "Total Commander" = 'cmd.exe /C winget.exe install --id "Ghisler.TotalCommander" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "TreeSize Free" = 'cmd.exe /C winget.exe install --id "JAMSoftware.TreeSize.Free" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Twinkle Tray" = 'cmd.exe /C winget.exe install --id "xanderfrangos.twinkletray" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "UltraVNC" = 'cmd.exe /C winget install UltraVNC.UltraVNC --accept-package-agreements --silent --force'
        "UniGetUI (GUI for winget/choco)" = 'cmd.exe /C winget install WinGetUI.WinGetUI --accept-package-agreements --silent --force'
        "VistaSwitcher" = 'cmd.exe /C winget.exe install --id "ntwind.VistaSwitcher" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Windows Auto Dark Mode" = 'cmd.exe /C winget.exe install --id "Armin2208.WindowsAutoNightMode" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Windows Firewall Control" = 'cmd.exe /C winget.exe install --id "BiniSoft.WindowsFirewallControl" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Windhawk" = 'cmd.exe /C winget install Windhawk.Windhawk --accept-package-agreements --silent --force'
        "WindowGrid" = 'cmd.exe /C winget.exe install --id "na" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Wise Program Uninstaller" = 'cmd.exe /C winget.exe install --id "WiseCleaner.WiseProgramUninstaller" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "WiseToys" = 'cmd.exe /C winget.exe install --id "WiseCleaner.WiseToys" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "WizFile" = 'cmd.exe /C winget.exe install --id "AntibodySoftware.WizFile" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Xtreme Download Manager" = 'cmd.exe /C winget.exe install --id "subhra74.XtremeDownloadManager" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "ZoomIt" = 'cmd.exe /C winget.exe install --id "Microsoft.Sysinternals.ZoomIt" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "🧠 Developer Tools & Programming" = @{
        "VS Code" = 'cmd.exe /C winget install Microsoft.VisualStudioCode --accept-package-agreements --silent --force'
        "Git" = 'cmd.exe /C winget install Git.Git --accept-package-agreements --silent --force'
        "GitHub Desktop" = 'cmd.exe /C winget install GitHub.GitHubDesktop --accept-package-agreements --silent --force'
        "Docker Desktop" = 'cmd.exe /C winget install Docker.DockerDesktop --accept-package-agreements --silent --force'
        "JetBrains Toolbox" = 'cmd.exe /C winget install JetBrains.Toolbox --accept-package-agreements --silent --force'
        "NodeJS" = 'cmd.exe /C winget install NodeJS.NodeJS --accept-package-agreements --silent --force'
        "Python 3.12" = 'cmd.exe /C winget install Python.Python.3.12 --accept-package-agreements --silent --force'
        "OpenJDK Temurin 21" = 'cmd.exe /C winget install OpenJDK.Temurin.21 --accept-package-agreements --silent --force'
        "GoLang" = 'cmd.exe /C winget install GoLang.Go --accept-package-agreements --silent --force'
        "Rustup" = 'cmd.exe /C winget install Rustlang.Rustup --accept-package-agreements --silent --force'
        "PostgreSQL" = 'cmd.exe /C winget install PostgreSQL.PostgreSQL --accept-package-agreements --silent --force'
        "MySQL Server" = 'cmd.exe /C winget install MySQL.MySQLServer --accept-package-agreements --silent --force'
        "Redis" = 'cmd.exe /C winget install Redis.Redis --accept-package-agreements --silent --force'
        "MongoDB Server" = 'cmd.exe /C winget install MongoDB.Server --accept-package-agreements --silent --force'
        "MongoDB Compass" = 'cmd.exe /C winget install MongoDB.Compass --accept-package-agreements --silent --force'
        "SQL Server Mgmt Studio (SSMS)" = 'cmd.exe /C winget install Microsoft.SQLServerManagementStudio --accept-package-agreements --silent --force'
        "Notepad++" = 'cmd.exe /C winget install Notepad++.Notepad++ --accept-package-agreements --silent --force'
        "Sublime Text" = 'cmd.exe /C winget install SublimeText.SublimeText --accept-package-agreements --silent --force'
        "Vim" = 'cmd.exe /C winget install Vim.Vim --accept-package-agreements --silent --force'
        "NeoVim" = 'cmd.exe /C winget install NeoVim.Neovim --accept-package-agreements --silent --force'
        "Anaconda" = 'cmd.exe /C winget.exe install --id "Anaconda.Anaconda3" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Azure Data Studio" = 'cmd.exe /C winget.exe install --id "Microsoft.AzureDataStudio" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Clink (CMD Enhancer)" = 'cmd.exe /C winget.exe install --id "chrisant996.Clink" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "CMake" = 'cmd.exe /C winget.exe install --id "Kitware.CMake" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Code With Mu (Python Editor)" = 'cmd.exe /C winget.exe install --id "Mu.Mu" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "DAXStudio" = 'cmd.exe /C winget.exe install --id "DaxStudio.DaxStudio" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Fast Node Manager (fnm)" = 'cmd.exe /C winget.exe install --id "Schniz.fnm" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Fork (Git Client)" = 'cmd.exe /C winget.exe install --id "Fork.Fork" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Git Butler" = 'cmd.exe /C winget.exe install --id "GitButler.GitButler" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Git Extensions" = 'cmd.exe /C winget.exe install --id "GitExtensionsTeam.GitExtensions" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "GitKraken Client" = 'cmd.exe /C winget.exe install --id "Axosoft.GitKraken" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Gitify" = 'cmd.exe /C winget.exe install --id "Gitify.Gitify" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "GitHub CLI" = 'cmd.exe /C winget.exe install --id "GitHub.cli" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Helix (Editor)" = 'cmd.exe /C winget.exe install --id "Helix.Helix" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Lazygit" = 'cmd.exe /C winget.exe install --id "JesseDuffield.lazygit" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Node Version Manager (NVM)" = 'cmd.exe /C winget.exe install --id "CoreyButler.NVMforWindows" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "NodeJS LTS" = 'cmd.exe /C winget.exe install --id "OpenJS.NodeJS.LTS" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "NuGet" = 'cmd.exe /C winget.exe install --id "Microsoft.NuGet" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Oh My Posh (Prompt)" = 'cmd.exe /C winget.exe install --id "JanDeDobbeleer.OhMyPosh" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Pixi (Conda Pkg Mgr)" = 'cmd.exe /C winget.exe install --id "prefix-dev.pixi" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Python Launcher" = 'cmd.exe /C winget install Python.Launcher --accept-package-agreements --silent --force'
        "Python Version Manager (pyenv-win)" = 'cmd.exe /C winget.exe install --id "na" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Starship (Shell Prompt)" = 'cmd.exe /C winget.exe install --id "starship" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Sublime Merge" = 'cmd.exe /C winget.exe install --id "SublimeHQ.SublimeMerge" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Swift toolchain" = 'cmd.exe /C winget.exe install --id "Swift.Toolchain" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Thonny Python IDE" = 'cmd.exe /C winget.exe install --id "AivarAnnamaa.Thonny" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Unity Game Engine" = 'cmd.exe /C winget.exe install --id "Unity.UnityHub" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Vagrant" = 'cmd.exe /C winget.exe install --id "Hashicorp.Vagrant" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Visual Studio 2022" = 'cmd.exe /C winget.exe install --id "Microsoft.VisualStudio.2022.Community" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "VS Codium" = 'cmd.exe /C winget.exe install --id "VSCodium.VSCodium" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "XPipe" = 'cmd.exe /C winget.exe install --id "xpipe-io.xpipe" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Yarn" = 'cmd.exe /C winget.exe install --id "Yarn.Yarn" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "🌐 Browsers" = @{
        "Google Chrome" = 'cmd.exe /C winget install Google.Chrome --accept-package-agreements --silent --force'
        "Mozilla Firefox" = 'cmd.exe /C winget install Mozilla.Firefox --accept-package-agreements --silent --force'
        "Microsoft Edge" = 'cmd.exe /C winget install Microsoft.Edge --accept-package-agreements --silent --force'
        "Brave" = 'cmd.exe /C winget install Brave.Brave --accept-package-agreements --silent --force'
        "Opera" = 'cmd.exe /C winget install Opera.Opera --accept-package-agreements --silent --force'
        "Opera GX" = 'cmd.exe /C winget install OperaGX.OperaGX --accept-package-agreements --silent --force'
        "Vivaldi" = 'cmd.exe /C winget install Vivaldi.Vivaldi --accept-package-agreements --silent --force'
        "Tor Browser" = 'cmd.exe /C winget install TorProject.TorBrowser --accept-package-agreements --silent --force'
        "Waterfox" = 'cmd.exe /C winget install Waterfox.Waterfox --accept-package-agreements --silent --force'
        "Ungoogled Chromium" = 'cmd.exe /C winget install UngoogledChromium.UngoogledChromium --accept-package-agreements --silent --force'
        "Chromium" = 'cmd.exe /C winget.exe install --id "Hibbiki.Chromium" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Falkon" = 'cmd.exe /C winget.exe install --id "KDE.Falkon" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Firefox ESR" = 'cmd.exe /C winget.exe install --id "Mozilla.Firefox.ESR" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Floorp" = 'cmd.exe /C winget.exe install --id "Ablaze.Floorp" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "LibreWolf" = 'cmd.exe /C winget.exe install --id "LibreWolf.LibreWolf" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Mullvad Browser" = 'cmd.exe /C winget.exe install --id "MullvadVPN.MullvadBrowser" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "PaleMoon" = 'cmd.exe /C winget.exe install --id "MoonchildProductions.PaleMoon" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Thorium Browser AVX2" = 'cmd.exe /C winget.exe install --id "Alex313031.Thorium.AVX2" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Zen Browser" = 'cmd.exe /C winget.exe install --id "Zen-Team.Zen-Browser" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "💻 Productivity & Document Tools" = @{
        "LibreOffice" = 'cmd.exe /C winget install LibreOffice.LibreOffice --accept-package-agreements --silent --force'
        "OnlyOffice Desktop" = 'cmd.exe /C winget install OnlyOffice.DesktopEditors --accept-package-agreements --silent --force'
        "PDFsam Basic" = 'cmd.exe /C winget install PDFsam.PDFsam --accept-package-agreements --silent --force'
        "Sumatra PDF" = 'cmd.exe /C winget install SumatraPDF.SumatraPDF --accept-package-agreements --silent --force'
        "Foxit Reader" = 'cmd.exe /C winget install Foxit.FoxitReader --accept-package-agreements --silent --force'
        "Adobe Acrobat Reader" = 'cmd.exe /C winget install Adobe.Acrobat.Reader.64-bit --accept-package-agreements --silent --force'
        "AFFiNE (Notion Alternative)" = 'cmd.exe /C winget.exe install --id "ToEverything.AFFiNE" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Anki (Flashcards)" = 'cmd.exe /C winget.exe install --id "Anki.Anki" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Calibre (E-Book Manager)" = 'cmd.exe /C winget.exe install --id "calibre.calibre" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Foxit PDF Editor" = 'cmd.exe /C winget.exe install --id "Foxit.PhantomPDF" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Joplin (FOSS Notes)" = 'cmd.exe /C winget.exe install --id "Joplin.Joplin" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Logseq (Knowledge Graph)" = 'cmd.exe /C winget.exe install --id "Logseq.Logseq" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "massCode (Snippet Manager)" = 'cmd.exe /C winget.exe install --id "antonreshetov.massCode" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "NAPS2 (Document Scanner)" = 'cmd.exe /C winget.exe install --id "Cyanfish.NAPS2" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Obsidian" = 'cmd.exe /C winget.exe install --id "Obsidian.Obsidian" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Okular (Document Viewer)" = 'cmd.exe /C winget.exe install --id "KDE.Okular" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "PDF24 creator" = 'cmd.exe /C winget.exe install --id "geeksoftwareGmbH.PDF24Creator" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "PDFgear" = 'cmd.exe /C winget.exe install --id "PDFgear.PDFgear" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "simplenote" = 'cmd.exe /C winget.exe install --id "Automattic.Simplenote" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "WinMerge" = 'cmd.exe /C winget.exe install --id "WinMerge.WinMerge" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Xournal++ (Notetaking)" = 'cmd.exe /C winget.exe install --id "Xournal++.Xournal++" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Zim Desktop Wiki" = 'cmd.exe /C winget.exe install --id "Zimwiki.Zim" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Znote" = 'cmd.exe /C winget.exe install --id "alagrede.znote" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Zotero (Reference Mgr)" = 'cmd.exe /C winget.exe install --id "DigitalScholar.Zotero" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "💬 Communication & Social" = @{
        "Microsoft Teams" = 'cmd.exe /C winget install Microsoft.Teams --accept-package-agreements --silent --force'
        "Slack" = 'cmd.exe /C winget install SlackTechnologies.Slack --accept-package-agreements --silent --force'
        "Zoom" = 'cmd.exe /C winget install Zoom.Zoom --accept-package-agreements --silent --force'
        "Discord" = 'cmd.exe /C winget install Discord.Discord --accept-package-agreements --silent --force'
        "Telegram" = 'cmd.exe /C winget install Telegram.TelegramDesktop --accept-package-agreements --silent --force'
        "Signal" = 'cmd.exe /C winget install Signal.Signal --accept-package-agreements --silent --force'
        "Betterbird (Email Client)" = 'cmd.exe /C winget.exe install --id "Betterbird.Betterbird" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Chatterino (Twitch Client)" = 'cmd.exe /C winget.exe install --id "ChatterinoTeam.Chatterino" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Element (Matrix)" = 'cmd.exe /C winget.exe install --id "Element.Element" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Ferdium (Messaging Hub)" = 'cmd.exe /C winget.exe install --id "Ferdium.Ferdium" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Guilded" = 'cmd.exe /C winget.exe install --id "Guilded.Guilded" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Hexchat (IRC)" = 'cmd.exe /C winget.exe install --id "HexChat.HexChat" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Jami" = 'cmd.exe /C winget.exe install --id "SFLinux.Jami" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Linphone (VoIP)" = 'cmd.exe /C winget.exe install --id "BelledonneCommunications.Linphone" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "QTox" = 'cmd.exe /C winget.exe install --id "Tox.qTox" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Revolt" = 'cmd.exe /C winget.exe install --id "Revolt.RevoltDesktop" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Session" = 'cmd.exe /C winget.exe install --id "Session.Session" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Thunderbird (Email Client)" = 'cmd.exe /C winget.exe install --id "Mozilla.Thunderbird" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Unigram (Telegram Client)" = 'cmd.exe /C winget.exe install --id "Telegram.Unigram" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Viber" = 'cmd.exe /C winget.exe install --id "Rakuten.Viber" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Zulip" = 'cmd.exe /C winget.exe install --id "Zulip.Zulip" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "🎨 Design & Creative Tools" = @{
        "GIMP (Image Editor)" = 'cmd.exe /C winget install GIMP.GIMP --accept-package-agreements --silent --force'
        "Inkscape (Vector Editor)" = 'cmd.exe /C winget install Inkscape.Inkscape --accept-package-agreements --silent --force'
        "Blender (3D)" = 'cmd.exe /C winget install BlenderFoundation.Blender --accept-package-agreements --silent --force'
        "Krita (Painting)" = 'cmd.exe /C winget install Krita.Krita --accept-package-agreements --silent --force'
        "Paint.NET" = 'cmd.exe /C winget install Paint.NET.Paint.NET --accept-package-agreements --silent --force'
        "Darktable (Photo Editor)" = 'cmd.exe /C winget install Darktable.Darktable --accept-package-agreements --silent --force'
        "RawTherapee" = 'cmd.exe /C winget install RawTherapee.RawTherapee --accept-package-agreements --silent --force'
        "ImageMagick" = 'cmd.exe /C winget install ImageMagick.ImageMagick --accept-package-agreements --silent --force'
        "digiKam (Photo Manager)" = 'cmd.exe /C winget.exe install --id "KDE.digikam" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Fire Alpaca" = 'cmd.exe /C winget.exe install --id "FireAlpaca.FireAlpaca" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "FreeCAD" = 'cmd.exe /C winget.exe install --id "FreeCAD.FreeCAD" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "KiCad" = 'cmd.exe /C winget.exe install --id "KiCad.KiCad" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "OpenSCAD" = 'cmd.exe /C winget.exe install --id "OpenSCAD.OpenSCAD" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "QGIS" = 'cmd.exe /C winget.exe install --id "OSGeo.QGIS" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "🎬 Media Production & Viewing" = @{
        "Audacity (Audio Editor)" = 'cmd.exe /C winget install Audacity.Audacity --accept-package-agreements --silent --force'
        "HandBrake (Video Transcoder)" = 'cmd.exe /C winget install HandBrake.HandBrake --accept-package-agreements --silent --force'
        "Shotcut (Video Editor)" = 'cmd.exe /C winget install Shotcut.Shotcut --accept-package-agreements --silent --force'
        "DaVinci Resolve" = 'cmd.exe /C winget install DaVinciResolve.DaVinciResolve --accept-package-agreements --silent --force'
        "Lightworks" = 'cmd.exe /C winget install Lightworks.Lightworks --accept-package-agreements --silent --force'
        "FFmpeg" = 'cmd.exe /C winget install FFmpeg.FFmpeg --accept-package-agreements --silent --force'
        "VLC Media Player" = 'cmd.exe /C winget install VLC.VLC --accept-package-agreements --silent --force'
        "Spotify" = 'cmd.exe /C winget install Spotify.Spotify --accept-package-agreements --silent --force'
        "Winamp" = 'cmd.exe /C winget install Winamp.Winamp --accept-package-agreements --silent --force'
        "MPC-HC" = 'cmd.exe /C winget install MPC-HC.MPC-HC --accept-package-agreements --silent --force'
        "PotPlayer" = 'cmd.exe /C winget install PotPlayer.PotPlayer --accept-package-agreements --silent --force'
        "OBS Studio" = 'cmd.exe /C winget install OBSProject.OBSStudio --accept-package-agreements --silent --force'
        "ShareX (Screenshots)" = 'cmd.exe /C winget install ShareX.ShareX --accept-package-agreements --silent --force'
        "Greenshot (Screenshots)" = 'cmd.exe /C winget install Greenshot.Greenshot --accept-package-agreements --silent --force'
        "Aegisub (Subtitles)" = 'cmd.exe /C winget.exe install --id "Aegisub.Aegisub" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "AIMP (Music Player)" = 'cmd.exe /C winget.exe install --id "AIMP.AIMP" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Clementine (Music Player)" = 'cmd.exe /C winget.exe install --id "Clementine.Clementine" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "EarTrumpet (Audio Mixer)" = 'cmd.exe /C winget.exe install --id "File-New-Project.EarTrumpet" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Equalizer APO" = 'cmd.exe /C winget.exe install --id "na" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "foobar2000 (Music Player)" = 'cmd.exe /C winget.exe install --id "PeterPawlowski.foobar2000" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "FxSound" = 'cmd.exe /C winget.exe install --id "FxSound.FxSound" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Harmonoid (Music Player)" = 'cmd.exe /C winget.exe install --id "Harmonoid.Harmonoid" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "ImageGlass (Image Viewer)" = 'cmd.exe /C winget.exe install --id "DuongDieuPhap.ImageGlass" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "ImgBurn" = 'cmd.exe /C winget.exe install --id "LIGHTNINGUK.ImgBurn" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "iTunes" = 'cmd.exe /C winget.exe install --id "Apple.iTunes" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Jellyfin Media Player" = 'cmd.exe /C winget.exe install --id "Jellyfin.JellyfinMediaPlayer" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Jellyfin Server" = 'cmd.exe /C winget.exe install --id "Jellyfin.Server" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "JPEG View" = 'cmd.exe /C winget.exe install --id "sylikc.JPEGView" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "K-Lite Codec Standard" = 'cmd.exe /C winget.exe install --id "CodecGuide.K-LiteCodecPack.Standard" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Kdenlive (Video Editor)" = 'cmd.exe /C winget.exe install --id "KDE.Kdenlive" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Kodi Media Center" = 'cmd.exe /C winget.exe install --id "XBMCFoundation.Kodi" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Modern Flyouts" = 'cmd.exe /C winget.exe install --id "ModernFlyouts.ModernFlyouts" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Mp3tag (Metadata Editor)" = 'cmd.exe /C winget.exe install --id "Mp3tag.Mp3tag" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "MuseScore" = 'cmd.exe /C winget.exe install --id "Musescore.Musescore" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "MusicBee (Music Player)" = 'cmd.exe /C winget.exe install --id "MusicBee.MusicBee" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "NDI Tools" = 'cmd.exe /C winget.exe install --id "NDI.NDITools" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Nomacs (Image Viewer)" = 'cmd.exe /C winget.exe install --id "nomacs.nomacs" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "SMPlayer" = 'cmd.exe /C winget.exe install --id "SMPlayer.SMPlayer" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Strawberry (Music Player)" = 'cmd.exe /C winget.exe install --id "StrawberryMusicPlayer.Strawberry" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Stremio" = 'cmd.exe /C winget.exe install --id "Stremio.Stremio" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Subtitle Edit" = 'cmd.exe /C winget.exe install --id "Nikse.SubtitleEdit" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "TagScanner (Tag Scanner)" = 'cmd.exe /C winget.exe install --id "SergeySerkov.TagScanner" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Tidal" = 'cmd.exe /C winget.exe install --id "9NNCB5BS59PH" --exact --source msstore --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Videomass" = 'cmd.exe /C winget.exe install --id "GianlucaPernigotto.Videomass" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Voicemeeter (Audio Mixer)" = 'cmd.exe /C winget.exe install --id "VB-Audio.Voicemeeter" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Voicemeeter Potato" = 'cmd.exe /C winget.exe install --id "VB-Audio.Voicemeeter.Potato" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "XnView classic" = 'cmd.exe /C winget.exe install --id "XnSoft.XnView.Classic" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Yt-dlp" = 'cmd.exe /C winget.exe install --id "yt-dlp.yt-dlp" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "🧑‍💻 Networking & Cloud Tools" = @{
        "PuTTY (SSH/Telnet)" = 'cmd.exe /C winget install PuTTY.PuTTY --accept-package-agreements --silent --force'
        "WinSCP (SFTP/FTP)" = 'cmd.exe /C winget install WinSCP.WinSCP --accept-package-agreements --silent --force'
        "FileZilla (FTP Client)" = 'cmd.exe /C winget install FileZilla.FileZilla --accept-package-agreements --silent --force'
        "OpenSSH" = 'cmd.exe /C winget install OpenSSH.OpenSSH --accept-package-agreements --silent --force'
        "Termius" = 'cmd.exe /C winget install Termius.Termius --accept-package-agreements --silent --force'
        "MobaXterm" = 'cmd.exe /C winget install MobaXterm.MobaXterm --accept-package-agreements --silent --force'
        "Wireshark (Network Analyzer)" = 'cmd.exe /C winget install Wireshark.Wireshark --accept-package-agreements --silent --force'
        "Nmap (Network Scanner)" = 'cmd.exe /C winget install Nmap.Nmap --accept-package-agreements --silent --force'
        "Angry IP Scanner" = 'cmd.exe /C winget install AngryIPScanner.AngryIPScanner --accept-package-agreements --silent --force'
        "OpenVPN" = 'cmd.exe /C winget install OpenVPNTechnologies.OpenVPN --accept-package-agreements --silent --force'
        "WireGuard VPN" = 'cmd.exe /C winget install WireGuard.WireGuard --accept-package-agreements --silent --force'
        "Cisco Packet Tracer" = 'cmd.exe /C winget install Cisco.PacketTracer --accept-package-agreements --silent --force'
        "Microsoft Azure CLI" = 'cmd.exe /C winget install Microsoft.AzureCLI --accept-package-agreements --silent --force'
        "Amazon AWS CLI" = 'cmd.exe /C winget install Amazon.AWSCLI --accept-package-agreements --silent --force'
        "Google Cloud SDK" = 'cmd.exe /C winget install Google.CloudSDK --accept-package-agreements --silent --force'
        "Terraform" = 'cmd.exe /C winget install Terraform.Terraform --accept-package-agreements --silent --force'
        "Postman (API Testing)" = 'cmd.exe /C winget install Postman.Postman --accept-package-agreements --silent --force'
        "Insomnia (API Testing)" = 'cmd.exe /C winget install Insomnia.Insomnia --accept-package-agreements --silent --force'
        "curl" = 'cmd.exe /C winget install curl.curl --accept-package-agreements --silent --force'
        "wget" = 'cmd.exe /C winget install wget.wget --accept-package-agreements --silent --force'
        "Advanced IP Scanner" = 'cmd.exe /C winget.exe install --id "Famatech.AdvancedIPScanner" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "mRemoteNG" = 'cmd.exe /C winget.exe install --id "mRemoteNG.mRemoteNG" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "NetBird" = 'cmd.exe /C winget.exe install --id "netbird" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "RDCMan" = 'cmd.exe /C winget.exe install --id "Microsoft.Sysinternals.RDCMan" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "RustDesk" = 'cmd.exe /C winget.exe install --id "RustDesk.RustDesk" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "🕹️ Gaming & Entertainment" = @{
        "Steam" = 'cmd.exe /C winget install Steam.Steam --accept-package-agreements --silent --force'
        "Epic Games Launcher" = 'cmd.exe /C winget install EpicGames.EpicGamesLauncher --accept-package-agreements --silent --force'
        "EA Desktop" = 'cmd.exe /C winget install EA.EADesktop --accept-package-agreements --silent --force'
        "Ubisoft Connect" = 'cmd.exe /C winget install Ubisoft.Connect --accept-package-agreements --silent --force'
        "GOG Galaxy" = 'cmd.exe /C winget install GOG.Galaxy --accept-package-agreements --silent --force'
        "Xbox App" = 'cmd.exe /C winget install Xbox.XboxApp --accept-package-agreements --silent --force'
        "MSI Afterburner" = 'cmd.exe /C winget install MSI.Afterburner --accept-package-agreements --silent --force'
        "Razer Synapse" = 'cmd.exe /C winget install Razer.Synapse --accept-package-agreements --silent --force'
        "Logitech G Hub" = 'cmd.exe /C winget install Logitech.GHub --accept-package-agreements --silent --force'
        "Playnite (Library Manager)" = 'cmd.exe /C winget install Playnite.Playnite --accept-package-agreements --silent --force'
        "Lutris" = 'cmd.exe /C winget install Lutris.Lutris --accept-package-agreements --silent --force'
        "Parsec (Remote Gaming)" = 'cmd.exe /C winget install Parsec.Parsec --accept-package-agreements --silent --force'
        "Moonlight GameStream Client" = 'cmd.exe /C winget install Moonlight.GameStream --accept-package-agreements --silent --force'
        "NVIDIA GeForce Experience" = 'cmd.exe /C winget install GeForceExperience.NVIDIA --accept-package-agreements --silent --force'
        "AMD Radeon Software" = 'cmd.exe /C winget install AMD.RadeonSoftware --accept-package-agreements --silent --force'
        "OpenRGB" = 'cmd.exe /C winget install OpenRGB.OpenRGB --accept-package-agreements --silent --force'
        "DS4Windows" = 'cmd.exe /C winget install DS4Windows.DS4Windows --accept-package-agreements --silent --force'
        "RetroArch" = 'cmd.exe /C winget install RetroArch.RetroArch --accept-package-agreements --silent --force'
        "Ambie White Noise" = 'cmd.exe /C winget.exe install --id "9P07XNM5CHP0" --exact --source msstore --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Borderless Gaming" = 'cmd.exe /C winget.exe install --id "Codeusa.BorderlessGaming" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "CapFrameX" = 'cmd.exe /C winget.exe install --id "CXWorld.CapFrameX" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Cemu (Wii U Emulator)" = 'cmd.exe /C winget.exe install --id "Cemu.Cemu" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Clone Hero" = 'cmd.exe /C winget.exe install --id "CloneHeroTeam.CloneHero" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "EA App" = 'cmd.exe /C winget.exe install --id "ElectronicArts.EADesktop" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Emulation Station" = 'cmd.exe /C winget.exe install --id "Emulationstation.Emulationstation" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "GeForce NOW" = 'cmd.exe /C winget.exe install --id "Nvidia.GeForceNow" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Heroic Games Launcher" = 'cmd.exe /C winget.exe install --id "HeroicGamesLauncher.HeroicGamesLauncher" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Itch.io" = 'cmd.exe /C winget.exe install --id "ItchIo.Itch" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "JoyToKey" = 'cmd.exe /C winget.exe install --id "JTKsoftware.JoyToKey" --accept-package-agreements --silent --force'
        "PS Remote Play" = 'cmd.exe /C winget.exe install --id "PlayStation.PSRemotePlay" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Prism Launcher (Minecraft)" = 'cmd.exe /C winget.exe install --id "PrismLauncher.PrismLauncher" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Sunshine/GameStream Server" = 'cmd.exe /C winget.exe install --id "LizardByte.Sunshine" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "TCNO Account Switcher" = 'cmd.exe /C winget.exe install --id "TechNobo.TcNoAccountSwitcher" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Virtual Desktop Streamer" = 'cmd.exe /C winget.exe install --id "VirtualDesktop.Streamer" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "XEMU (Xbox Emulator)" = 'cmd.exe /C winget.exe install --id "xemu-project.xemu" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "🔐 Security & Privacy Tools" = @{
        "1Password" = 'cmd.exe /C winget install 1Password.1Password --accept-package-agreements --silent --force'
        "Bitwarden" = 'cmd.exe /C winget install Bitwarden.Bitwarden --accept-package-agreements --silent --force'
        "KeePassXC" = 'cmd.exe /C winget install KeePassXC.KeePassXC --accept-package-agreements --silent --force'
        "LastPass" = 'cmd.exe /C winget install LastPass.LastPass --accept-package-agreements --silent --force'
        "Malwarebytes" = 'cmd.exe /C winget install Malwarebytes.Malwarebytes --accept-package-agreements --silent --force'
        "Avast Free Antivirus" = 'cmd.exe /C winget install Avast.AvastFreeAntivirus --accept-package-agreements --silent --force'
        "Kaspersky Security Cloud" = 'cmd.exe /C winget install Kaspersky.KasperskySecurityCloud --accept-package-agreements --silent --force'
        "Bitdefender Antivirus Free" = 'cmd.exe /C winget install Bitdefender.BitdefenderAntivirusFree --accept-package-agreements --silent --force'
        "Sophos Home" = 'cmd.exe /C winget install Sophos.SophosHome --accept-package-agreements --silent --force'
        "ESET NOD32" = 'cmd.exe /C winget install ESET.ESETNOD32 --accept-package-agreements --silent --force'
        "CCleaner" = 'cmd.exe /C winget install CCleaner.CCleaner --accept-package-agreements --silent --force'
        "VeraCrypt" = 'cmd.exe /C winget install VeraCrypt.VeraCrypt --accept-package-agreements --silent --force'
        "NordVPN" = 'cmd.exe /C winget install NordVPN.NordVPN --accept-package-agreements --silent --force'
        "ProtonVPN" = 'cmd.exe /C winget install ProtonVPN.ProtonVPN --accept-package-agreements --silent --force'
        "Mullvad VPN" = 'cmd.exe /C winget install MullvadVPN.MullvadVPN --accept-package-agreements --silent --force'
        "Gpg4win (GPG Suite)" = 'cmd.exe /C winget install Gpg4win.Gpg4win --accept-package-agreements --silent --force'
        "OpenSSL" = 'cmd.exe /C winget install OpenSSL.OpenSSL --accept-package-agreements --silent --force'
        "Cryptomator" = 'cmd.exe /C winget install Cryptomator.Cryptomator --accept-package-agreements --silent --force'
        "Tailscale (Mesh VPN)" = 'cmd.exe /C winget install Tailscale.Tailscale --accept-package-agreements --silent --force'
        "Simplewall (Firewall)" = 'cmd.exe /C winget.exe install --id "Henry++.simplewall" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Windows Firewall Control" = 'cmd.exe /C winget.exe install --id "BiniSoft.WindowsFirewallControl" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Portmaster" = 'cmd.exe /C winget.exe install --id "Safing.Portmaster" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }

    "📦 Package Managers & Core" = @{
        "Chocolatey (Package Manager)" = 'cmd.exe /C winget install Chocolatey.Choco --accept-package-agreements --silent --force'
        "Scoop (Package Manager)" = 'cmd.exe /C winget install Scoop.Scoop --accept-package-agreements --silent --force'
        "Python 3.13" = 'cmd.exe /C winget.exe install --id "Python.Python.3.13" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Java Corretto 11 (LTS)" = 'cmd.exe /C winget.exe install --id "Amazon.Corretto.11.JDK" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Java Corretto 17 (LTS)" = 'cmd.exe /C winget.exe install --id "Amazon.Corretto.17.JDK" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Java Corretto 21 (LTS)" = 'cmd.exe /C winget.exe install --id "Amazon.Corretto.21.JDK" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Java Corretto 8 (LTS)" = 'cmd.exe /C winget.exe install --id "Amazon.Corretto.8.JDK" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Visual C++ 2015-2022 32-bit" = 'cmd.exe /C winget.exe install --id "Microsoft.VCRedist.2015+.x86" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Visual C++ 2015-2022 64-bit" = 'cmd.exe /C winget.exe install --id "Microsoft.VCRedist.2015+.x64" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Desktop Runtime 5" = 'cmd.exe /C winget.exe install --id "Microsoft.DotNet.DesktopRuntime.5" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Desktop Runtime 6" = 'cmd.exe /C winget.exe install --id "Microsoft.DotNet.DesktopRuntime.6" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Desktop Runtime 7" = 'cmd.exe /C winget.exe install --id "Microsoft.DotNet.DesktopRuntime.7" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Desktop Runtime 8" = 'cmd.exe /C winget.exe install --id "Microsoft.DotNet.DesktopRuntime.8" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Desktop Runtime 9" = 'cmd.exe /C winget.exe install --id "Microsoft.DotNet.DesktopRuntime.9" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
        "Eclipse Temurin 21" = 'cmd.exe /C winget.exe install --id "EclipseAdoptium.Temurin.21.JDK" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
    }
}

# --- GUI Setup ---

# Main Form
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Ultimate Categorized Software Installer"
$Form.Size = New-Object System.Drawing.Size(750, 850) # Widen and lengthen
$Form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.MinimizeBox = $false
$Form.MaximizeBox = $false
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle

# Header Label
$HeaderLabel = New-Object System.Windows.Forms.Label
$HeaderLabel.Text = "Select software to install (All are checked by default):"
$HeaderLabel.Location = New-Object System.Drawing.Point(10, 10)
$HeaderLabel.AutoSize = $true
$HeaderLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($HeaderLabel)

# Panel for Checkboxes (makes it scrollable)
$Panel = New-Object System.Windows.Forms.Panel
$Panel.Location = New-Object System.Drawing.Point(10, 40)
$Panel.Size = New-Object System.Drawing.Size(720, 750) # Adjusted size
$Panel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$Panel.AutoScroll = $true
$Form.Controls.Add($Panel)

# Checkboxes and Category Headers
$Y_pos = 10
$Checkboxes = @{} # Hashtable to store checkbox name -> full command
$AllCommands = @() # A flat list for easier processing later

# Define the desired display order of categories (Prerequisites first)
$CategoryOrder = @(
    "⚙️ Prerequisites & Infrastructure",
    "🧰 System Utilities & Optimization",
    "🧠 Developer Tools & Programming",
    "🌐 Browsers",
    "💻 Productivity & Document Tools",
    "💬 Communication & Social",
    "🎨 Design & Creative Tools",
    "🎬 Media Production & Viewing",
    "🧑‍💻 Networking & Cloud Tools",
    "🕹️ Gaming & Entertainment",
    "🔐 Security & Privacy Tools",
    "📦 Package Managers & Core"
)

foreach ($Category in $CategoryOrder) {
    if (-not $CategorizedSoftware.ContainsKey($Category)) { continue }

    # 1. Add Category Header
    $CategoryLabel = New-Object System.Windows.Forms.Label
    $CategoryLabel.Text = "--- **$Category** ---"
    $CategoryLabel.Location = New-Object System.Drawing.Point(5, $Y_pos)
    $CategoryLabel.AutoSize = $true
    $CategoryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $Panel.Controls.Add($CategoryLabel)
    $Y_pos += 25
    
    # 2. Add Software Checkboxes for this Category (sorted alphabetically)
    $CategoryApps = $CategorizedSoftware[$Category]
    foreach ($DisplayName in $CategoryApps.Keys | Sort-Object) {
        $Command = $CategoryApps[$DisplayName]
        $AllCommands += $Command # Store command for later reference
        
        $CheckBox = New-Object System.Windows.Forms.CheckBox
        $CheckBox.Name = $DisplayName # Use DisplayName as key
        $CheckBox.Text = $DisplayName
        $CheckBox.Checked = $true # Select all by default
        $CheckBox.Location = New-Object System.Drawing.Point(15, $Y_pos)
        $CheckBox.AutoSize = $true
        
        $Panel.Controls.Add($CheckBox)
        
        # Store the checkbox control and the command, mapping DisplayName to properties
        $Checkboxes[$DisplayName] = @{
            'Control' = $CheckBox
            'Command' = $Command
            'Category' = $Category
        }
        
        $Y_pos += 25
    }
    # Add a small buffer after the category
    $Y_pos += 5
}

# Adjust panel scroll size
$Panel.VerticalScroll.Maximum = $Y_pos

# Select/Deselect All Button
$SelectAllButton = New-Object System.Windows.Forms.Button
$SelectAllButton.Text = "Toggle All"
$SelectAllButton.Location = New-Object System.Drawing.Point(10, 805)
$SelectAllButton.Size = New-Object System.Drawing.Size(120, 30)
$SelectAllButton.Add_Click({
    $State = $false
    # Check the first checkbox to determine the toggle state
    $FirstCheckBox = $Panel.Controls | Where-Object {$_.GetType().Name -eq "CheckBox"} | Select -First 1
    if ($FirstCheckBox.Checked -eq $false) {
        $State = $true
    }
    
    foreach ($Control in $Panel.Controls) {
        if ($Control.GetType().Name -eq "CheckBox") {
            $Control.Checked = $State
        }
    }
})
$Form.Controls.Add($SelectAllButton)

# Install Button
$InstallButton = New-Object System.Windows.Forms.Button
$InstallButton.Text = "Start Installation"
$InstallButton.Location = New-Object System.Drawing.Point(590, 805)
$InstallButton.Size = New-Object System.Drawing.Size(140, 30)
$InstallButton.Add_Click({
    $SelectedCommands = @()
    $SelectedCount = 0
    
    # 1. Gather selected commands and map to a command list
    $CommandMap = @{}
    foreach ($Category in $CategoryOrder) {
        if (-not $CategorizedSoftware.ContainsKey($Category)) { continue }
        $CategoryApps = $CategorizedSoftware[$Category]
        foreach ($DisplayName in $CategoryApps.Keys | Sort-Object) {
            $CommandMap[$DisplayName] = $CategoryApps[$DisplayName]
            
            # Check the actual control's state
            $Control = $Checkboxes[$DisplayName].Control
            if ($Control.Checked) {
                $SelectedCommands += $CommandMap[$DisplayName]
                $SelectedCount++
            }
        }
    }

    if ($SelectedCount -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one software to install.", "No Software Selected", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Exclamation)
        return
    }
    
    # 2. Confirmation prompt
    $ConfirmResult = [System.Windows.Forms.MessageBox]::Show(
        "You are about to run installation for $SelectedCount software packages. This may take a long time and requires elevated privileges for some commands. Continue?",
        "Confirm Installation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    
    if ($ConfirmResult -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }
    
    # Disable buttons and close GUI to start execution
    $InstallButton.Enabled = $false
    $Form.Hide() 
    
    # 3. Execute commands
    Write-Host "--- Starting Installation Process for $SelectedCount Packages ---" -ForegroundColor Yellow
    Write-Host "NOTE: Commands will run in the background. The script will close when done."
    Write-Host "Wait for all processes to complete."
    
    # Invert CommandMap for reverse lookup (Command -> DisplayName)
    $ReverseCommandMap = @{}
    $CommandMap.Keys | ForEach-Object {$ReverseCommandMap[$CommandMap[$_]] = $_}

    foreach ($Command in $SelectedCommands) {
        $SoftwareName = $ReverseCommandMap[$Command]
        Write-Host "-> Installing: $SoftwareName" -ForegroundColor Cyan
        
        # Execute the command
        Invoke-Expression $Command 2>&1 | Out-Host
        
        Write-Host "-> Finished installation for: $SoftwareName" -ForegroundColor Green
    }

    Write-Host "--- All selected installations complete! ---" -ForegroundColor Yellow
    
    [System.Windows.Forms.MessageBox]::Show("All selected software installations have finished. Check the PowerShell window for any errors.", "Installation Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    
    # Exit the script
    $Form.Close()
    
})
$Form.Controls.Add($InstallButton)

# --- Display the GUI ---
$Form.ShowDialog() | Out-Null