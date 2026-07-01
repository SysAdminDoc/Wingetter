param(
    [string]$SourceDir = (Join-Path $PSScriptRoot "..\src"),
    [string]$OutputPath = (Join-Path ([System.IO.Path]::GetTempPath()) ("wingetter-ui-smoke-" + [System.Guid]::NewGuid().ToString("N")))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

function Test-SmokeScreenshot {
    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path)) {
        Add-Failure "Screenshot was not created: $Path"
        return
    }

    $fileInfo = Get-Item -LiteralPath $Path
    if ($fileInfo.Length -lt 4096) {
        Add-Failure "Screenshot is too small to be a rendered UI capture: $Path ($($fileInfo.Length) bytes)"
        return
    }

    $stream = [System.IO.File]::OpenRead($fileInfo.FullName)
    try {
        $decoder = [System.Windows.Media.Imaging.PngBitmapDecoder]::new(
            $stream,
            [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        )
        if ($decoder.Frames.Count -lt 1) {
            Add-Failure "Screenshot has no bitmap frames: $Path"
            return
        }

        $frame = $decoder.Frames[0]
        if ($frame.PixelWidth -lt 300 -or $frame.PixelHeight -lt 200) {
            Add-Failure "Screenshot dimensions are too small: $Path ($($frame.PixelWidth)x$($frame.PixelHeight))"
            return
        }

        $converted = [System.Windows.Media.Imaging.FormatConvertedBitmap]::new()
        $converted.BeginInit()
        $converted.Source = $frame
        $converted.DestinationFormat = [System.Windows.Media.PixelFormats]::Bgra32
        $converted.EndInit()

        $stride = [int]($converted.PixelWidth * 4)
        $pixels = New-Object byte[] ($stride * $converted.PixelHeight)
        $converted.CopyPixels($pixels, $stride, 0)
        $sampleStep = [math]::Max(4, [int]([math]::Floor($pixels.Length / 4096 / 4) * 4))
        $colors = [System.Collections.Generic.HashSet[string]]::new()
        for ($i = 0; $i -le ($pixels.Length - 4); $i += $sampleStep) {
            [void]$colors.Add("$($pixels[$i]),$($pixels[$i + 1]),$($pixels[$i + 2]),$($pixels[$i + 3])")
            if ($colors.Count -gt 12) { break }
        }
        if ($colors.Count -lt 4) {
            Add-Failure "Screenshot appears blank or nearly blank: $Path"
        }
    } finally {
        $stream.Dispose()
    }
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    Add-Failure "UI smoke test must run in an STA PowerShell session."
}

if ($failures.Count -eq 0) {
    try {
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Windows.Forms
    } catch {
        Add-Failure "Could not load WPF assemblies: $($_.Exception.Message)"
    }
}

if ($failures.Count -eq 0) {
    foreach ($moduleName in @(
        "Wingetter.Common.ps1",
        "Wingetter.Catalog.ps1",
        "Wingetter.WinGet.ps1",
        "Wingetter.Groups.ps1",
        "Wingetter.ProfileGallery.ps1",
        "Wingetter.Sources.ps1",
        "Wingetter.Scoop.ps1",
        "Wingetter.OfflineCache.ps1",
        "Wingetter.Configuration.ps1",
        "Wingetter.UpdateWatcher.ps1",
        "Wingetter.Diagnostics.ps1",
        "Wingetter.Resources.ps1",
        "Wingetter.Ui.ps1"
    )) {
        $modulePath = Join-Path $SourceDir $moduleName
        if (!(Test-Path -LiteralPath $modulePath)) {
            Add-Failure "Missing source module '$moduleName'."
            continue
        }
        try {
            . (Resolve-Path -LiteralPath $modulePath).Path
        } catch {
            Add-Failure "Could not import '$moduleName': $($_.Exception.Message)"
        }
    }
}

if ($failures.Count -eq 0) {
    try {
        if (Test-Path -LiteralPath $OutputPath) {
            Remove-Item -LiteralPath $OutputPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

        $rawResult = @(Show-WinGetInstallerGUI -SmokeTest -SmokeOutputPath $OutputPath)
        $result = @($rawResult | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties["Screenshots"] } | Select-Object -Last 1)
        if ($result.Count -eq 0) {
            Add-Failure "UI smoke run did not return a result object."
        } else {
            $screenshots = [string[]]@($result[0].Screenshots)
            foreach ($requiredName in @(
                "01-dark-main.png",
                "02-light-main.png",
                "03-empty-state.png",
                "04-profile-gallery.png",
                "06-update-mode.png",
                "07-browse-restored.png"
            )) {
                $expectedPath = Join-Path $OutputPath $requiredName
                if ($screenshots -notcontains $expectedPath) {
                    Add-Failure "UI smoke result did not include screenshot '$requiredName'."
                }
                Test-SmokeScreenshot -Path $expectedPath
            }

            if ($screenshots.Count -lt 6) {
                Add-Failure "UI smoke captured $($screenshots.Count) screenshots; expected at least 6."
            }
        }
    } catch {
        Add-Failure "UI smoke validation threw: $($_.Exception.Message)"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "UI smoke validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "UI smoke validation passed. Screenshots: $OutputPath"
