# ============================================================================
# PACKAGE SOURCE ADAPTERS
# ============================================================================

$Script:WingetterPackageSourceAdapters = $null

function New-WingetterPackageSourceAdapter {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [string]$CommandName = "",
        [object]$Capabilities = @{},
        [Parameter(Mandatory = $true)][object]$Operations
    )

    if ($Operations -isnot [System.Collections.IDictionary]) {
        throw "Package source adapter '$Name' must provide operations as a dictionary."
    }

    $requiredOperations = @(
        "TestAvailability",
        "InstallManager",
        "Search",
        "GetDetails",
        "Install",
        "Upgrade",
        "Uninstall",
        "ExportProfile",
        "ImportProfile",
        "GetInstalledCatalogPackages",
        "GetPinStatus",
        "InvokePinOperation",
        "GetInstallCommand"
    )
    foreach ($operation in $requiredOperations) {
        if (@($Operations.Keys) -notcontains $operation) {
            throw "Package source adapter '$Name' is missing required operation '$operation'."
        }
        if ($Operations[$operation] -isnot [scriptblock]) {
            throw "Package source adapter '$Name' operation '$operation' must be a scriptblock."
        }
    }

    if ($Capabilities -isnot [System.Collections.IDictionary]) {
        $Capabilities = @{}
    }

    [PSCustomObject]@{
        PSTypeName    = "Wingetter.PackageSourceAdapter"
        Name          = $Name.ToLowerInvariant()
        DisplayName   = $DisplayName
        CommandName   = $CommandName
        Capabilities  = $Capabilities
        Operations    = $Operations
    }
}

function Get-WingetterWinGetSourceAdapter {
    $capabilities = [ordered]@{
        Search             = $true
        Details            = $true
        Install            = $true
        Upgrade            = $true
        Uninstall          = $true
        ExportProfile      = $true
        ImportProfile      = $true
        InstalledScan      = $true
        Pin                = $true
        Hold               = $true
        Bootstrap          = $true
        CommandPreview     = $true
    }

    $operations = [ordered]@{
        TestAvailability = {
            Test-WinGet
        }
        InstallManager = {
            Install-WinGet
        }
        Search = {
            param(
                [string]$Query,
                [int]$TimeoutSeconds = 20
            )
            $arguments = @("search")
            if (![string]::IsNullOrWhiteSpace($Query)) { $arguments += $Query }
            $arguments += "--disable-interactivity"
            $arguments += "--accept-source-agreements"
            $capture = Invoke-WinGetCapture -Arguments $arguments -TimeoutSeconds $TimeoutSeconds
            [PSCustomObject]@{
                Source   = "winget"
                Query    = $Query
                Command  = "winget " + (Join-ProcessArguments -Arguments $arguments)
                ExitCode = $capture.ExitCode
                TimedOut = [bool]$capture.TimedOut
                Output   = $capture.StdOut
                Error    = $capture.StdErr
            }
        }
        GetDetails = {
            param([string]$PackageId)
            Get-WinGetPackageDetails -PackageId $PackageId
        }
        Install = {
            param(
                [string]$PackageId,
                [string]$PackageName,
                [bool]$Silent,
                [bool]$AcceptAgreements,
                [bool]$IncludePinned,
                [string]$RunLogDir,
                [scriptblock]$ShouldCancel = { $false },
                [scriptblock]$PumpUi = {}
            )
            Invoke-WinGetPackageOperation -Action "install" -PackageId $PackageId -PackageName $PackageName -Silent $Silent -AcceptAgreements $AcceptAgreements -IncludePinned $IncludePinned -RunLogDir $RunLogDir -ShouldCancel $ShouldCancel -PumpUi $PumpUi
        }
        Upgrade = {
            param(
                [string]$PackageId,
                [string]$PackageName,
                [bool]$Silent,
                [bool]$AcceptAgreements,
                [bool]$IncludePinned,
                [string]$RunLogDir,
                [scriptblock]$ShouldCancel = { $false },
                [scriptblock]$PumpUi = {}
            )
            Invoke-WinGetPackageOperation -Action "upgrade" -PackageId $PackageId -PackageName $PackageName -Silent $Silent -AcceptAgreements $AcceptAgreements -IncludePinned $IncludePinned -RunLogDir $RunLogDir -ShouldCancel $ShouldCancel -PumpUi $PumpUi
        }
        Uninstall = {
            param(
                [string]$PackageId,
                [string]$PackageName,
                [bool]$Silent,
                [bool]$AcceptAgreements,
                [bool]$IncludePinned,
                [string]$RunLogDir,
                [scriptblock]$ShouldCancel = { $false },
                [scriptblock]$PumpUi = {}
            )
            Invoke-WinGetPackageOperation -Action "uninstall" -PackageId $PackageId -PackageName $PackageName -Silent $Silent -AcceptAgreements $false -IncludePinned $false -RunLogDir $RunLogDir -ShouldCancel $ShouldCancel -PumpUi $PumpUi
        }
        ExportProfile = {
            param(
                [string]$GroupName,
                [string[]]$PackageIds,
                [string]$FilePath
            )
            Export-GroupAsWinGetJSON -GroupName $GroupName -PackageIds $PackageIds -FilePath $FilePath
        }
        ImportProfile = {
            param(
                [object]$Content,
                [string]$FallbackGroupName = "Imported"
            )
            Import-PackageIdsFromJSON -Content $Content -FallbackGroupName $FallbackGroupName
        }
        GetInstalledCatalogPackages = {
            param([string[]]$PackageIds)
            Get-WinGetInstalledCatalogPackages -PackageIds $PackageIds
        }
        GetPinStatus = {
            param([string]$PackageId)
            Get-WinGetPinStatus -PackageId $PackageId
        }
        InvokePinOperation = {
            param(
                [string]$PackageId,
                [string]$Operation
            )
            Invoke-WinGetPinOperation -PackageId $PackageId -Operation $Operation
        }
        GetInstallCommand = {
            param(
                [string]$PackageId,
                [bool]$Silent,
                [bool]$AcceptAgreements
            )
            $arguments = New-WinGetPackageOperationArguments -Action "install" -PackageId $PackageId -Silent $Silent -AcceptAgreements $AcceptAgreements -IncludePinned $false
            "winget " + (Join-ProcessArguments -Arguments $arguments)
        }
    }

    New-WingetterPackageSourceAdapter -Name "winget" -DisplayName "Windows Package Manager" -CommandName "winget" -Capabilities $capabilities -Operations $operations
}

function Register-WingetterPackageSourceAdapter {
    param([Parameter(Mandatory = $true)][object]$Adapter)

    if ($null -eq $Script:WingetterPackageSourceAdapters) {
        $Script:WingetterPackageSourceAdapters = @{}
    }
    $Script:WingetterPackageSourceAdapters[[string]$Adapter.Name] = $Adapter
    return $Adapter
}

function Get-WingetterPackageSourceAdapters {
    if ($null -eq $Script:WingetterPackageSourceAdapters) {
        $Script:WingetterPackageSourceAdapters = @{}
        Register-WingetterPackageSourceAdapter -Adapter (Get-WingetterWinGetSourceAdapter) | Out-Null
    }

    return $Script:WingetterPackageSourceAdapters
}

function Get-WingetterPackageSourceAdapter {
    param([string]$Name = "winget")

    $adapters = Get-WingetterPackageSourceAdapters
    $key = $Name.ToLowerInvariant()
    if (!$adapters.ContainsKey($key)) {
        throw "Unknown package source '$Name'. Available sources: $(@($adapters.Keys) -join ', ')."
    }
    return $adapters[$key]
}

function Invoke-WingetterPackageSourceOperation {
    param(
        [object]$SourceAdapter,
        [Parameter(Mandatory = $true)][string]$Operation,
        [hashtable]$Parameters = @{}
    )

    if ($null -eq $SourceAdapter) {
        $SourceAdapter = Get-WingetterPackageSourceAdapter -Name "winget"
    }
    if ($null -eq $Parameters) { $Parameters = @{} }

    if (@($SourceAdapter.Operations.Keys) -notcontains $Operation) {
        throw "Package source '$($SourceAdapter.Name)' does not implement '$Operation'."
    }

    $handler = $SourceAdapter.Operations[$Operation]
    & $handler @Parameters
}

function Test-WingetterPackageSource {
    param([object]$SourceAdapter)
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "TestAvailability"
}

function Install-WingetterPackageSource {
    param([object]$SourceAdapter)
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "InstallManager"
}

function Search-WingetterPackageSource {
    param(
        [object]$SourceAdapter,
        [string]$Query,
        [int]$TimeoutSeconds = 20
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "Search" -Parameters @{
        Query          = $Query
        TimeoutSeconds = $TimeoutSeconds
    }
}

function Get-WingetterPackageSourceDetails {
    param(
        [object]$SourceAdapter,
        [string]$PackageId
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "GetDetails" -Parameters @{
        PackageId = $PackageId
    }
}

function Invoke-WingetterPackageSourcePackageOperation {
    param(
        [object]$SourceAdapter,
        [ValidateSet("install", "upgrade", "uninstall")]
        [string]$Action,
        [string]$PackageId,
        [string]$PackageName,
        [bool]$Silent,
        [bool]$AcceptAgreements,
        [bool]$IncludePinned,
        [string]$RunLogDir,
        [scriptblock]$ShouldCancel = { $false },
        [scriptblock]$PumpUi = {}
    )

    $operation = switch ($Action) {
        "install" { "Install" }
        "upgrade" { "Upgrade" }
        "uninstall" { "Uninstall" }
    }

    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation $operation -Parameters @{
        PackageId        = $PackageId
        PackageName      = $PackageName
        Silent           = $Silent
        AcceptAgreements = $AcceptAgreements
        IncludePinned    = $IncludePinned
        RunLogDir        = $RunLogDir
        ShouldCancel     = $ShouldCancel
        PumpUi           = $PumpUi
    }
}

function Export-WingetterPackageSourceProfile {
    param(
        [object]$SourceAdapter,
        [string]$GroupName,
        [string[]]$PackageIds,
        [string]$FilePath
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "ExportProfile" -Parameters @{
        GroupName  = $GroupName
        PackageIds = $PackageIds
        FilePath   = $FilePath
    }
}

function Import-WingetterPackageSourceProfile {
    param(
        [object]$SourceAdapter,
        [object]$Content,
        [string]$FallbackGroupName = "Imported"
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "ImportProfile" -Parameters @{
        Content           = $Content
        FallbackGroupName = $FallbackGroupName
    }
}

function Get-WingetterPackageSourceInstalledCatalogPackages {
    param(
        [object]$SourceAdapter,
        [string]$SourceName = "",
        [string[]]$PackageIds
    )
    if ($null -eq $SourceAdapter) {
        $SourceAdapter = if ([string]::IsNullOrWhiteSpace($SourceName)) {
            Get-WingetterPackageSourceAdapter -Name "winget"
        } else {
            Get-WingetterPackageSourceAdapter -Name $SourceName
        }
    }
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "GetInstalledCatalogPackages" -Parameters @{
        PackageIds = $PackageIds
    }
}

function Get-WingetterPackageSourcePinStatus {
    param(
        [object]$SourceAdapter,
        [string]$PackageId
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "GetPinStatus" -Parameters @{
        PackageId = $PackageId
    }
}

function Invoke-WingetterPackageSourcePinOperation {
    param(
        [object]$SourceAdapter,
        [string]$PackageId,
        [string]$Operation
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "InvokePinOperation" -Parameters @{
        PackageId = $PackageId
        Operation = $Operation
    }
}

function Get-WingetterPackageSourceInstallCommand {
    param(
        [object]$SourceAdapter,
        [string]$PackageId,
        [bool]$Silent,
        [bool]$AcceptAgreements
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "GetInstallCommand" -Parameters @{
        PackageId        = $PackageId
        Silent           = $Silent
        AcceptAgreements = $AcceptAgreements
    }
}
