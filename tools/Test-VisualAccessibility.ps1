param(
    [string]$UiModulePath = (Join-Path $PSScriptRoot "..\src\Wingetter.Ui.ps1")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $script:failures.Add($Message)
}

if (!(Test-Path $UiModulePath)) {
    Add-Failure "Missing UI module: $UiModulePath"
} else {
    $text = Get-Content -Path $UiModulePath -Raw

    if ($text -match 'CornerRadius\s*=\s*"?999') {
        Add-Failure "UI still contains XAML pill CornerRadius=999."
    }
    if ($text -match 'CornerRadius\]::new\(999\)') {
        Add-Failure "UI still contains generated pill CornerRadius=999."
    }
    foreach ($required in @(
        'AutomationProperties.Name="Switch between dark and light mode"',
        'AutomationProperties.Name="Search apps by name, package ID, category, group, source, or state"'
    )) {
        if ($text -notmatch [regex]::Escape($required)) {
            Add-Failure "Missing accessibility metadata: $required"
        }
    }

    # R-027: every named focusable XAML element must have an accessible name
    # source (Content/Text/ToolTip/AutomationProperties.Name). Controls that
    # have no text-content slot (TextBox / ComboBox / ListBox) must declare an
    # AutomationProperties.Name explicitly so screen readers can describe them.
    # Controls that carry a literal Template= attribute are allow-listed as
    # internal style template parts (e.g., the ComboBox toggle button) where
    # WPF's default focus behavior is intentionally suppressed.
    $textlessTags = @{
        TextBox  = $true
        ComboBox = $true
        ListBox  = $true
    }
    $controlPattern = '<(?<tag>Button|TextBox|ComboBox|CheckBox|ToggleButton|ListBox|RadioButton)\s+(?<attrs>[^>]+?)/?>'
    $controlMatches = [regex]::Matches($text, $controlPattern)
    $controlsSeen = 0
    foreach ($controlMatch in $controlMatches) {
        $tag = $controlMatch.Groups['tag'].Value
        $attrs = $controlMatch.Groups['attrs'].Value
        $nameMatch = [regex]::Match($attrs, 'x:Name="(?<name>[^"]+)"')
        if (-not $nameMatch.Success) { continue }
        $name = $nameMatch.Groups['name'].Value
        $controlsSeen++

        # Allow-list template parts: a control with a Template attribute is a
        # styling element, not a user-facing control. Verified case is the
        # ComboBox toggle inside the ComboToggle style.
        if ($attrs -match 'Template="[^"]+"') { continue }

        $contentMatch = [regex]::Match($attrs, 'Content="(?<value>[^"]*)"')
        $textMatch = [regex]::Match($attrs, '\bText="(?<value>[^"]*)"')
        $toolTipMatch = [regex]::Match($attrs, 'ToolTip="(?<value>[^"]*)"')
        $automationMatch = [regex]::Match($attrs, 'AutomationProperties\.Name="(?<value>[^"]*)"')

        $contentText = if ($contentMatch.Success) { $contentMatch.Groups['value'].Value.Trim() } else { "" }
        $textText = if ($textMatch.Success) { $textMatch.Groups['value'].Value.Trim() } else { "" }
        $toolTipText = if ($toolTipMatch.Success) { $toolTipMatch.Groups['value'].Value.Trim() } else { "" }
        $automationText = if ($automationMatch.Success) { $automationMatch.Groups['value'].Value.Trim() } else { "" }

        if ($textlessTags.ContainsKey($tag)) {
            if ([string]::IsNullOrWhiteSpace($automationText)) {
                Add-Failure "$tag x:Name='$name' has no AutomationProperties.Name (textless controls need an explicit accessible name)."
            }
        } else {
            if ([string]::IsNullOrWhiteSpace($contentText) -and
                [string]::IsNullOrWhiteSpace($textText) -and
                [string]::IsNullOrWhiteSpace($toolTipText) -and
                [string]::IsNullOrWhiteSpace($automationText)) {
                Add-Failure "$tag x:Name='$name' has no Content/Text/ToolTip/AutomationProperties.Name to expose to screen readers."
            }
        }

        # Suppressing focus or tab-stop on a user-facing named control is a
        # keyboard-navigation regression. The Template= allow-list above
        # excuses real style template parts; anything reaching this branch is
        # intended to be focusable.
        if ($attrs -match 'Focusable="False"') {
            Add-Failure "$tag x:Name='$name' has Focusable='False' but is not a template part - keyboard users cannot reach it."
        }
        if ($attrs -match 'IsTabStop="False"') {
            Add-Failure "$tag x:Name='$name' has IsTabStop='False' but is not a template part - keyboard users will skip past it."
        }
    }

    if ($controlsSeen -lt 20) {
        Add-Failure "Accessibility sweep matched only $controlsSeen named focusable controls; expected at least 20 - the regex may have regressed."
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Visual/accessibility validation failed:" -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host " - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Visual/accessibility validation passed."
