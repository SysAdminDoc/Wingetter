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
                [string]$SourceName = "",
                [int]$TimeoutSeconds = 20
            )
            $arguments = @("search")
            if (![string]::IsNullOrWhiteSpace($Query)) { $arguments += $Query }
            if (![string]::IsNullOrWhiteSpace($SourceName)) {
                $arguments += "--source"
                $arguments += $SourceName
            }
            $arguments += "--disable-interactivity"
            $arguments += "--accept-source-agreements"
            $arguments = Add-WinGetCleanOutputArguments -Arguments $arguments
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
            param(
                [string]$PackageId,
                [string]$SourceName = ""
            )
            Get-WinGetPackageDetails -PackageId $PackageId -SourceName $SourceName
        }
        Install = {
            param(
                [string]$PackageId,
                [string]$PackageName,
                [string]$SourceName = "",
                [bool]$Silent,
                [bool]$AcceptAgreements,
                [bool]$IncludePinned,
                [object]$InstallOptions = $null,
                [string]$RunLogDir,
                [scriptblock]$ShouldCancel = { $false }
            )
            Invoke-WinGetPackageOperation -Action "install" -PackageId $PackageId -PackageName $PackageName -SourceName $SourceName -Silent $Silent -AcceptAgreements $AcceptAgreements -IncludePinned $IncludePinned -InstallOptions $InstallOptions -RunLogDir $RunLogDir -ShouldCancel $ShouldCancel
        }
        Upgrade = {
            param(
                [string]$PackageId,
                [string]$PackageName,
                [string]$SourceName = "",
                [bool]$Silent,
                [bool]$AcceptAgreements,
                [bool]$IncludePinned,
                [object]$InstallOptions = $null,
                [string]$RunLogDir,
                [scriptblock]$ShouldCancel = { $false }
            )
            Invoke-WinGetPackageOperation -Action "upgrade" -PackageId $PackageId -PackageName $PackageName -SourceName $SourceName -Silent $Silent -AcceptAgreements $AcceptAgreements -IncludePinned $IncludePinned -InstallOptions $InstallOptions -RunLogDir $RunLogDir -ShouldCancel $ShouldCancel
        }
        Uninstall = {
            param(
                [string]$PackageId,
                [string]$PackageName,
                [string]$SourceName = "",
                [bool]$Silent,
                [bool]$AcceptAgreements,
                [bool]$IncludePinned,
                [object]$InstallOptions = $null,
                [string]$RunLogDir,
                [scriptblock]$ShouldCancel = { $false }
            )
            # AcceptAgreements and IncludePinned are part of the install/upgrade/
            # uninstall adapter contract but do not apply to uninstall; reference
            # them so the analyzer treats them as intentionally inert.
            [void]$AcceptAgreements
            [void]$IncludePinned
            [void]$InstallOptions
            Invoke-WinGetPackageOperation -Action "uninstall" -PackageId $PackageId -PackageName $PackageName -SourceName $SourceName -Silent $Silent -AcceptAgreements $false -IncludePinned $false -RunLogDir $RunLogDir -ShouldCancel $ShouldCancel
        }
        ExportProfile = {
            param(
                [string]$GroupName,
                [string[]]$PackageIds,
                [string]$FilePath,
                [object[]]$PackageEntries = @()
            )
            Export-GroupAsWinGetJSON -GroupName $GroupName -PackageIds $PackageIds -FilePath $FilePath -PackageEntries $PackageEntries
        }
        ImportProfile = {
            param(
                [object]$Content,
                [string]$FallbackGroupName = "Imported"
            )
            Import-PackageIdsFromJSON -Content $Content -FallbackGroupName $FallbackGroupName
        }
        GetInstalledCatalogPackages = {
            param(
                [string[]]$PackageIds,
                [string]$SourceName = ""
            )
            Get-WinGetInstalledCatalogPackages -PackageIds $PackageIds -SourceName $SourceName
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
                [string]$SourceName = "",
                [bool]$Silent,
                [bool]$AcceptAgreements,
                [object]$InstallOptions = $null
            )
            $arguments = New-WinGetPackageOperationArguments -Action "install" -PackageId $PackageId -SourceName $SourceName -Silent $Silent -AcceptAgreements $AcceptAgreements -IncludePinned $false -InstallOptions $InstallOptions
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
        if (Get-Command Get-WingetterScoopSourceAdapter -ErrorAction SilentlyContinue) {
            Register-WingetterPackageSourceAdapter -Adapter (Get-WingetterScoopSourceAdapter) | Out-Null
        }
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
        [string]$SourceName = "",
        [int]$TimeoutSeconds = 20
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "Search" -Parameters @{
        Query          = $Query
        SourceName     = $SourceName
        TimeoutSeconds = $TimeoutSeconds
    }
}

function Get-WingetterPackageSourceDetails {
    param(
        [object]$SourceAdapter,
        [string]$PackageId,
        [string]$SourceName = ""
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "GetDetails" -Parameters @{
        PackageId  = $PackageId
        SourceName = $SourceName
    }
}

function Invoke-WingetterPackageSourcePackageOperation {
    param(
        [object]$SourceAdapter,
        [ValidateSet("install", "upgrade", "uninstall")]
        [string]$Action,
        [string]$PackageId,
        [string]$PackageName,
        [string]$SourceName = "",
        [bool]$Silent,
        [bool]$AcceptAgreements,
        [bool]$IncludePinned,
        [object]$InstallOptions = $null,
        [string]$RunLogDir,
        [scriptblock]$ShouldCancel = { $false }
    )

    $operation = switch ($Action) {
        "install" { "Install" }
        "upgrade" { "Upgrade" }
        "uninstall" { "Uninstall" }
    }

    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation $operation -Parameters @{
        PackageId        = $PackageId
        PackageName      = $PackageName
        SourceName       = $SourceName
        Silent           = $Silent
        AcceptAgreements = $AcceptAgreements
        IncludePinned    = $IncludePinned
        InstallOptions   = $InstallOptions
        RunLogDir        = $RunLogDir
        ShouldCancel     = $ShouldCancel
    }
}

function Export-WingetterPackageSourceProfile {
    param(
        [object]$SourceAdapter,
        [string]$GroupName,
        [string[]]$PackageIds,
        [string]$FilePath,
        [object[]]$PackageEntries = @()
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "ExportProfile" -Parameters @{
        GroupName      = $GroupName
        PackageIds     = $PackageIds
        FilePath       = $FilePath
        PackageEntries = $PackageEntries
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
        PackageIds  = $PackageIds
        SourceName   = $SourceName
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
        [string]$SourceName = "",
        [bool]$Silent,
        [bool]$AcceptAgreements,
        [object]$InstallOptions = $null
    )
    Invoke-WingetterPackageSourceOperation -SourceAdapter $SourceAdapter -Operation "GetInstallCommand" -Parameters @{
        PackageId        = $PackageId
        SourceName       = $SourceName
        Silent           = $Silent
        AcceptAgreements = $AcceptAgreements
        InstallOptions   = $InstallOptions
    }
}

function Get-WingetterSourcePolicyPath {
    $root = Join-Path $env:APPDATA "Wingetter"
    if (!(Test-Path $root)) { New-Item -ItemType Directory -Path $root -Force | Out-Null }
    return (Join-Path $root "source-policy.json")
}

function New-WingetterSourceDefinition {
    param(
        [string]$Name,
        [string]$Type = "Microsoft.PreIndexed.Package",
        [string]$Argument = "",
        [ValidateSet("Community", "Trusted", "Private", "Unknown")]
        [string]$TrustLevel = "Community",
        [bool]$Explicit = $false,
        [bool]$Private = $false,
        [string]$Header = "",
        [Nullable[int]]$Priority = $null
    )

    [PSCustomObject]@{
        Name       = $Name
        Type       = $Type
        Argument   = $Argument
        TrustLevel = $TrustLevel
        Explicit   = [bool]$Explicit
        Private    = [bool]$Private
        Header     = $Header
        Priority   = $Priority
    }
}

function New-WingetterPrivateRestSourceDefinition {
    param(
        [string]$Name,
        [string]$Argument,
        [string]$Header = "",
        [bool]$Explicit = $true
    )

    New-WingetterSourceDefinition -Name $Name -Type "Microsoft.Rest" -Argument $Argument -TrustLevel "Private" -Explicit $Explicit -Private $true -Header $Header
}

function New-WingetterDefaultSourcePolicy {
    $defaultSource = New-WingetterSourceDefinition -Name "winget" -Type "Microsoft.PreIndexed.Package" -Argument "https://cdn.winget.microsoft.com/cache" -TrustLevel "Community" -Explicit $false -Private $false
    [PSCustomObject]@{
        Schema                = "Wingetter.SourcePolicy.v1"
        CorporateMode         = $false
        RequireAllowedSource  = $true
        AllowedSources        = @($defaultSource)
        PrivateSources        = @()
        Notes                 = "Enable CorporateMode to refuse packages whose source is not listed in AllowedSources or PrivateSources."
        UpdatedAtUtc          = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function Get-WingetterPolicyPropertyValue {
    param(
        [object]$InputObject,
        [string]$PropertyName,
        [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) { return $DefaultValue }
    if ($InputObject -is [System.Collections.IDictionary] -and $InputObject.Contains($PropertyName)) {
        return $InputObject[$PropertyName]
    }
    $prop = $InputObject.PSObject.Properties[$PropertyName]
    if ($prop) { return $prop.Value }
    return $DefaultValue
}

function ConvertTo-WingetterSourceDefinition {
    param([object]$Source)

    if ($null -eq $Source) { return $null }
    $name = [string](Get-WingetterPolicyPropertyValue -InputObject $Source -PropertyName "Name" -DefaultValue "")
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }

    $type = [string](Get-WingetterPolicyPropertyValue -InputObject $Source -PropertyName "Type" -DefaultValue "Microsoft.PreIndexed.Package")
    $argument = [string](Get-WingetterPolicyPropertyValue -InputObject $Source -PropertyName "Argument" -DefaultValue "")
    $trustLevel = [string](Get-WingetterPolicyPropertyValue -InputObject $Source -PropertyName "TrustLevel" -DefaultValue "Unknown")
    if (@("Community", "Trusted", "Private", "Unknown") -notcontains $trustLevel) { $trustLevel = "Unknown" }
    $explicit = [bool](Get-WingetterPolicyPropertyValue -InputObject $Source -PropertyName "Explicit" -DefaultValue $false)
    $private = [bool](Get-WingetterPolicyPropertyValue -InputObject $Source -PropertyName "Private" -DefaultValue $false)
    $header = [string](Get-WingetterPolicyPropertyValue -InputObject $Source -PropertyName "Header" -DefaultValue "")
    $priorityValue = Get-WingetterPolicyPropertyValue -InputObject $Source -PropertyName "Priority" -DefaultValue $null
    $priority = $null
    if ($null -ne $priorityValue -and "$priorityValue" -match '^\d+$') {
        $priority = [int]$priorityValue
    }

    New-WingetterSourceDefinition -Name $name -Type $type -Argument $argument -TrustLevel $trustLevel -Explicit $explicit -Private $private -Header $header -Priority $priority
}

function ConvertTo-WingetterSourcePolicy {
    param([object]$Policy)

    $defaultPolicy = New-WingetterDefaultSourcePolicy
    if ($null -eq $Policy) { return $defaultPolicy }

    $allowed = @()
    foreach ($source in @((Get-WingetterPolicyPropertyValue -InputObject $Policy -PropertyName "AllowedSources" -DefaultValue @()))) {
        $converted = ConvertTo-WingetterSourceDefinition -Source $source
        if ($converted) { $allowed += $converted }
    }
    if ($allowed.Count -eq 0) { $allowed = @($defaultPolicy.AllowedSources) }

    $private = @()
    foreach ($source in @((Get-WingetterPolicyPropertyValue -InputObject $Policy -PropertyName "PrivateSources" -DefaultValue @()))) {
        $converted = ConvertTo-WingetterSourceDefinition -Source $source
        if ($converted) { $private += $converted }
    }

    [PSCustomObject]@{
        Schema                = "Wingetter.SourcePolicy.v1"
        CorporateMode         = [bool](Get-WingetterPolicyPropertyValue -InputObject $Policy -PropertyName "CorporateMode" -DefaultValue $false)
        RequireAllowedSource  = [bool](Get-WingetterPolicyPropertyValue -InputObject $Policy -PropertyName "RequireAllowedSource" -DefaultValue $true)
        AllowedSources        = @($allowed)
        PrivateSources        = @($private)
        Notes                 = [string](Get-WingetterPolicyPropertyValue -InputObject $Policy -PropertyName "Notes" -DefaultValue $defaultPolicy.Notes)
        UpdatedAtUtc          = [string](Get-WingetterPolicyPropertyValue -InputObject $Policy -PropertyName "UpdatedAtUtc" -DefaultValue (Get-Date).ToUniversalTime().ToString("o"))
    }
}

function Get-WingetterSourcePolicy {
    param([string]$Path = (Get-WingetterSourcePolicyPath))

    if (![string]::IsNullOrWhiteSpace($Path) -and (Test-Path $Path)) {
        try {
            return ConvertTo-WingetterSourcePolicy -Policy (Get-Content -Path $Path -Raw | ConvertFrom-Json)
        } catch {
            # Preserve the unparseable file as .corrupt before returning defaults
            # so a malformed source-policy.json (truncated write, manual edit
            # that produced invalid JSON) can be recovered manually and the
            # user sees a warning rather than silently reverting to defaults.
            if (Get-Command Move-WingetterCorruptFileAside -ErrorAction SilentlyContinue) {
                Move-WingetterCorruptFileAside -Path $Path
            } else {
                Write-Warning "Source policy at '$Path' is not valid JSON; using defaults."
            }
            return New-WingetterDefaultSourcePolicy
        }
    }

    return New-WingetterDefaultSourcePolicy
}

function Save-WingetterSourcePolicy {
    param(
        [object]$Policy,
        [string]$Path = (Get-WingetterSourcePolicyPath)
    )

    $normalized = ConvertTo-WingetterSourcePolicy -Policy $Policy
    $normalized.UpdatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    Set-WingetterFileAtomic -Path $Path -Content ($normalized | ConvertTo-Json -Depth 8) -Encoding UTF8
    return $normalized
}

function Set-WingetterSourcePolicyCorporateMode {
    param(
        [object]$Policy,
        [bool]$Enabled
    )

    $normalized = ConvertTo-WingetterSourcePolicy -Policy $Policy
    $normalized.CorporateMode = [bool]$Enabled
    $normalized.UpdatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    return $normalized
}

function Get-WingetterSourcePolicyDefinitions {
    param([object]$Policy)

    $normalized = ConvertTo-WingetterSourcePolicy -Policy $Policy
    $definitions = @()
    $seen = @{}
    foreach ($source in @(@($normalized.AllowedSources) + @($normalized.PrivateSources))) {
        if ($null -eq $source -or [string]::IsNullOrWhiteSpace([string]$source.Name)) { continue }
        $key = ([string]$source.Name).ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $definitions += $source
    }
    return $definitions
}

function Get-WingetterSourceDefinition {
    param(
        [object]$Policy,
        [string]$Name
    )

    foreach ($source in @(Get-WingetterSourcePolicyDefinitions -Policy $Policy)) {
        if ([string]::Equals([string]$source.Name, [string]$Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $source
        }
    }
    return $null
}

function Get-WingetterPackageCatalogSourceName {
    param(
        [object]$App,
        [string]$DefaultSource = "winget"
    )

    foreach ($propertyName in @("Source", "SourceName", "PackageSource")) {
        $value = Get-WingetterPolicyPropertyValue -InputObject $App -PropertyName $propertyName -DefaultValue ""
        if (![string]::IsNullOrWhiteSpace([string]$value)) { return [string]$value }
    }
    return $DefaultSource
}

function Test-WingetterPackageAllowedBySourcePolicy {
    param(
        [object]$Policy,
        [string]$PackageId,
        [string]$SourceName = "winget"
    )

    $normalized = ConvertTo-WingetterSourcePolicy -Policy $Policy
    $resolvedSource = if ([string]::IsNullOrWhiteSpace($SourceName)) { "winget" } else { $SourceName }
    $definition = Get-WingetterSourceDefinition -Policy $normalized -Name $resolvedSource

    if (!$normalized.CorporateMode) {
        $trust = if ($definition) { [string]$definition.TrustLevel } else { "Unknown" }
        $type = if ($definition) { [string]$definition.Type } else { "Unknown" }
        return [PSCustomObject]@{
            PackageId  = $PackageId
            SourceName = $resolvedSource
            Allowed    = $true
            TrustLevel = $trust
            SourceType = $type
            Priority   = if ($definition) { $definition.Priority } else { $null }
            Reason     = "Corporate mode is disabled."
        }
    }

    if ($normalized.RequireAllowedSource -and $null -eq $definition) {
        return [PSCustomObject]@{
            PackageId  = $PackageId
            SourceName = $resolvedSource
            Allowed    = $false
            TrustLevel = "Unknown"
            SourceType = "Unknown"
            Priority   = $null
            Reason     = "Source '$resolvedSource' is not listed in the corporate source policy."
        }
    }

    [PSCustomObject]@{
        PackageId  = $PackageId
        SourceName = $resolvedSource
        Allowed    = $true
        TrustLevel = if ($definition) { [string]$definition.TrustLevel } else { "Unknown" }
        SourceType = if ($definition) { [string]$definition.Type } else { "Unknown" }
        Priority   = if ($definition) { $definition.Priority } else { $null }
        Reason     = "Source '$resolvedSource' is allowed by the corporate source policy."
    }
}

function Get-WingetterPackageSourceTrustSummary {
    param(
        [object]$Policy,
        [string]$SourceName = "winget"
    )

    $check = Test-WingetterPackageAllowedBySourcePolicy -Policy $Policy -PackageId "" -SourceName $SourceName
    $state = if ($check.Allowed) { "allowed" } else { "blocked" }
    $priorityText = if ($null -ne $check.Priority) { " / priority $($check.Priority)" } else { "" }
    "$($check.SourceName) / $($check.TrustLevel) / $state$priorityText"
}

$Script:WingetterSourceHeaderPlaceholder = "<redacted-header>"

function Get-WingetterRedactedSourceHeaderPlaceholder {
    return $Script:WingetterSourceHeaderPlaceholder
}

function Get-WingetterSourceHeaderForExport {
    param(
        [object]$Source,
        [switch]$IncludeRawHeader
    )

    $definition = ConvertTo-WingetterSourceDefinition -Source $Source
    if ($null -eq $definition -or [string]::IsNullOrWhiteSpace([string]$definition.Header)) { return "" }
    if ($IncludeRawHeader) { return [string]$definition.Header }
    return $Script:WingetterSourceHeaderPlaceholder
}

function ConvertTo-WingetterSourceDefinitionForExport {
    param(
        [object]$Source,
        [switch]$IncludeRawHeader
    )

    $definition = ConvertTo-WingetterSourceDefinition -Source $Source
    if ($null -eq $definition) { return $null }

    New-WingetterSourceDefinition `
        -Name $definition.Name `
        -Type $definition.Type `
        -Argument $definition.Argument `
        -TrustLevel $definition.TrustLevel `
        -Explicit $definition.Explicit `
        -Private $definition.Private `
        -Header (Get-WingetterSourceHeaderForExport -Source $definition -IncludeRawHeader:$IncludeRawHeader) `
        -Priority $definition.Priority
}

function Test-WingetterWinGetSourcePrioritySupported {
    param([string]$WinGetVersion = "")

    if ([string]::IsNullOrWhiteSpace($WinGetVersion) -and (Get-Command Get-WinGetCliVersionText -ErrorAction SilentlyContinue)) {
        $WinGetVersion = Get-WinGetCliVersionText
    }
    if (Get-Command Test-WinGetVersionAtLeast -ErrorAction SilentlyContinue) {
        return (Test-WinGetVersionAtLeast -VersionText $WinGetVersion -MinimumVersion ([version]"1.29.0"))
    }
    return $false
}

function New-WingetterWinGetSourceAddArguments {
    param(
        [object]$Source,
        [switch]$IncludeRawHeader,
        [string]$WinGetVersion = ""
    )

    $definition = ConvertTo-WingetterSourceDefinition -Source $Source
    if ($null -eq $definition) { throw "Cannot build source command for an empty source definition." }
    if ([string]::IsNullOrWhiteSpace($definition.Argument)) { throw "Source '$($definition.Name)' is missing an Argument URL/path." }

    $arguments = @("source", "add", "--name", [string]$definition.Name, "--arg", [string]$definition.Argument, "--type", [string]$definition.Type)
    $trust = if ($definition.TrustLevel -in @("Trusted", "Private")) { "trusted" } else { "none" }
    $arguments += "--trust-level"
    $arguments += $trust
    if ($definition.Explicit) { $arguments += "--explicit" }
    if ($null -ne $definition.Priority -and (Test-WingetterWinGetSourcePrioritySupported -WinGetVersion $WinGetVersion)) {
        $arguments += "--priority"
        $arguments += [string]$definition.Priority
    }
    $header = Get-WingetterSourceHeaderForExport -Source $definition -IncludeRawHeader:$IncludeRawHeader
    if (![string]::IsNullOrWhiteSpace($header)) {
        $arguments += "--header"
        $arguments += $header
    }
    $arguments += "--accept-source-agreements"
    $arguments += "--disable-interactivity"
    return [string[]]$arguments
}

function New-WingetterWinGetSourceAddCommand {
    param(
        [object]$Source,
        [switch]$IncludeRawHeader,
        [string]$WinGetVersion = ""
    )
    "winget " + (Join-ProcessArguments -Arguments (New-WingetterWinGetSourceAddArguments -Source $Source -IncludeRawHeader:$IncludeRawHeader -WinGetVersion $WinGetVersion))
}

function ConvertFrom-WingetterWinGetSourceListText {
    param([string]$Text)

    $lines = @(([string]$Text -split "`r?`n") | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    $headerIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '\bName\b' -and $lines[$i] -match '\bArgument\b') {
            $headerIndex = $i
            break
        }
    }
    if ($headerIndex -lt 0) { return @() }

    $headers = @($lines[$headerIndex].Trim() -split '\s{2,}' | ForEach-Object {
        ([string]$_ -replace '\s+', '').ToLowerInvariant()
    })
    $sources = [System.Collections.ArrayList]::new()
    for ($i = $headerIndex + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*-{3,}') { continue }
        $values = @($line.Trim() -split '\s{2,}')
        if ($values.Count -lt 2) { continue }

        $row = @{}
        for ($j = 0; $j -lt $headers.Count -and $j -lt $values.Count; $j++) {
            $row[$headers[$j]] = [string]$values[$j]
        }

        $name = if ($row.ContainsKey("name")) { [string]$row["name"] } else { [string]$values[0] }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $priorityValue = if ($row.ContainsKey("priority")) { [string]$row["priority"] } else { "" }
        $priority = $null
        if ($priorityValue -match '^\d+$') { $priority = [int]$priorityValue }
        $explicitValue = if ($row.ContainsKey("explicit")) { [string]$row["explicit"] } else { "" }
        $explicit = $null
        if ($explicitValue -match '^(true|yes|1)$') { $explicit = $true }
        if ($explicitValue -match '^(false|no|0)$') { $explicit = $false }

        [void]$sources.Add([PSCustomObject]@{
            Name       = $name
            Argument   = if ($row.ContainsKey("argument")) { [string]$row["argument"] } else { "" }
            Type       = if ($row.ContainsKey("type")) { [string]$row["type"] } else { "" }
            Explicit   = $explicit
            TrustLevel = if ($row.ContainsKey("trustlevel")) { [string]$row["trustlevel"] } elseif ($row.ContainsKey("trust")) { [string]$row["trust"] } else { "" }
            Priority   = $priority
        })
    }

    return [object[]]$sources.ToArray()
}

function Compare-WingetterSourcePolicyDrift {
    param(
        [object]$Policy,
        [object[]]$LiveSources
    )

    $policySources = @(Get-WingetterSourcePolicyDefinitions -Policy $Policy)
    $policyByName = @{}
    foreach ($source in $policySources) {
        if ($null -eq $source -or [string]::IsNullOrWhiteSpace([string]$source.Name)) { continue }
        $policyByName[([string]$source.Name).ToLowerInvariant()] = ConvertTo-WingetterSourceDefinition -Source $source
    }
    $liveByName = @{}
    foreach ($source in @($LiveSources)) {
        if ($null -eq $source -or [string]::IsNullOrWhiteSpace([string]$source.Name)) { continue }
        $liveByName[([string]$source.Name).ToLowerInvariant()] = $source
    }

    $items = [System.Collections.ArrayList]::new()
    foreach ($key in @($policyByName.Keys | Sort-Object)) {
        $policySource = $policyByName[$key]
        if (!$liveByName.ContainsKey($key)) {
            [void]$items.Add([PSCustomObject]@{
                Name        = [string]$policySource.Name
                Status      = "Missing"
                Differences = [string[]]@("missing")
                Policy      = $policySource
                Live        = $null
            })
            continue
        }

        $liveSource = $liveByName[$key]
        $differences = [System.Collections.ArrayList]::new()
        if (![string]::IsNullOrWhiteSpace([string]$liveSource.Argument) -and [string]$liveSource.Argument -ne [string]$policySource.Argument) {
            [void]$differences.Add("argument")
        }
        if (![string]::IsNullOrWhiteSpace([string]$liveSource.Type) -and [string]$liveSource.Type -ne [string]$policySource.Type) {
            [void]$differences.Add("type")
        }
        if ($null -ne $liveSource.Explicit -and [bool]$liveSource.Explicit -ne [bool]$policySource.Explicit) {
            [void]$differences.Add("explicit")
        }
        if (![string]::IsNullOrWhiteSpace([string]$liveSource.TrustLevel) -and [string]$liveSource.TrustLevel -ne [string]$policySource.TrustLevel) {
            [void]$differences.Add("trust")
        }
        if ($null -ne $policySource.Priority -or $null -ne $liveSource.Priority) {
            if ([string]$policySource.Priority -ne [string]$liveSource.Priority) {
                [void]$differences.Add("priority")
            }
        }

        [void]$items.Add([PSCustomObject]@{
            Name        = [string]$policySource.Name
            Status      = if ($differences.Count -gt 0) { "Changed" } else { "Matched" }
            Differences = [string[]]$differences.ToArray()
            Policy      = $policySource
            Live        = $liveSource
        })
    }

    foreach ($key in @($liveByName.Keys | Sort-Object)) {
        if ($policyByName.ContainsKey($key)) { continue }
        $liveSource = $liveByName[$key]
        [void]$items.Add([PSCustomObject]@{
            Name        = [string]$liveSource.Name
            Status      = "Extra"
            Differences = [string[]]@("extra")
            Policy      = $null
            Live        = $liveSource
        })
    }

    $rows = [object[]]$items.ToArray()
    [PSCustomObject]@{
        Schema       = "Wingetter.SourcePolicyDrift.v1"
        CheckedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        Summary      = [ordered]@{
            policySources = $policyByName.Count
            liveSources   = $liveByName.Count
            missing       = @($rows | Where-Object { $_.Status -eq "Missing" }).Count
            extra         = @($rows | Where-Object { $_.Status -eq "Extra" }).Count
            changed       = @($rows | Where-Object { $_.Status -eq "Changed" }).Count
            matched       = @($rows | Where-Object { $_.Status -eq "Matched" }).Count
        }
        Items        = $rows
    }
}

function Get-WingetterSourcePolicyDrift {
    param(
        [object]$Policy,
        [int]$TimeoutSeconds = 20
    )

    $arguments = @("source", "list", "--disable-interactivity")
    $arguments = Add-WinGetCleanOutputArguments -Arguments $arguments
    $capture = Invoke-WinGetCapture -Arguments $arguments -TimeoutSeconds $TimeoutSeconds
    $liveSources = ConvertFrom-WingetterWinGetSourceListText -Text "$($capture.StdOut)`n$($capture.StdErr)"
    $drift = Compare-WingetterSourcePolicyDrift -Policy $Policy -LiveSources $liveSources
    $drift | Add-Member -NotePropertyName Command -NotePropertyValue ("winget " + (Join-ProcessArguments -Arguments $arguments))
    $drift | Add-Member -NotePropertyName ExitCode -NotePropertyValue ([int]$capture.ExitCode)
    $drift | Add-Member -NotePropertyName TimedOut -NotePropertyValue ([bool]$capture.TimedOut)
    return $drift
}

function Export-WingetterSourcePolicy {
    param(
        [object]$Policy,
        [string]$FilePath,
        [switch]$IncludeRawHeaders,
        [string]$WinGetVersion = ""
    )

    $normalized = ConvertTo-WingetterSourcePolicy -Policy $Policy
    $commands = @()
    foreach ($source in @(Get-WingetterSourcePolicyDefinitions -Policy $normalized)) {
        if (![string]::IsNullOrWhiteSpace([string]$source.Argument)) {
            $commands += New-WingetterWinGetSourceAddCommand -Source $source -IncludeRawHeader:$IncludeRawHeaders -WinGetVersion $WinGetVersion
        }
    }

    $export = [ordered]@{
        Schema               = "Wingetter.SourcePolicyExport.v1"
        ExportedAtUtc        = (Get-Date).ToUniversalTime().ToString("o")
        CorporateMode        = [bool]$normalized.CorporateMode
        RequireAllowedSource = [bool]$normalized.RequireAllowedSource
        HeadersRedacted      = -not [bool]$IncludeRawHeaders
        HeaderPlaceholder    = $Script:WingetterSourceHeaderPlaceholder
        AllowedSources       = @($normalized.AllowedSources | ForEach-Object { ConvertTo-WingetterSourceDefinitionForExport -Source $_ -IncludeRawHeader:$IncludeRawHeaders })
        PrivateSources       = @($normalized.PrivateSources | ForEach-Object { ConvertTo-WingetterSourceDefinitionForExport -Source $_ -IncludeRawHeader:$IncludeRawHeaders })
        SourceAddCommands    = @($commands)
    }

    Set-WingetterFileAtomic -Path $FilePath -Content ($export | ConvertTo-Json -Depth 8) -Encoding UTF8
    return [PSCustomObject]$export
}
