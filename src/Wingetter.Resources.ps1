# ============================================================================
# UI STRING RESOURCES
# ============================================================================

$Script:WingetterStrings = @{
    WindowTitle          = "Wingetter v6.1.0 - Curated Windows App Installs and Updates"
    SplashTitle          = "Wingetter"
    SplashLoading        = "Loading Wingetter..."
    SplashBuilding       = "Building interface..."
    SplashReady          = "Ready!"

    SearchPlaceholder    = "Search apps or Winget IDs"
    SearchA11yName       = "Search apps by name, package ID, category, group, source, or state"
    ClearSearchA11y      = "Clear search filter"

    InstallSelected      = "Install Selected"
    UpdateSelected       = "Update Selected"
    SelectVisible        = "Select Visible"
    ClearVisible         = "Clear Visible"
    BackToBrowse         = "Back to Browse"

    ProgressDefault      = "Choose apps to install or load a saved group to get started."
    ProgressRepairStart  = "Repairing WinGet/App Installer..."
    ProgressRepairBlock  = "WinGet repair blocked: {0}"
    ProgressRepairDone   = "WinGet is ready.{0}"
    ProgressRepairFail   = "WinGet repair needs manual follow-up: {0}{1}"

    ProgressPrivateOn    = "Private icon mode enabled. Remote favicon fetches are disabled."
    ProgressPrivateOff   = "Private icon mode disabled. Remote icons will refresh on next launch."
    ProgressCorpOn       = "Corporate source policy enabled: {0}."
    ProgressCorpOff      = "Corporate source policy disabled."

    ProgressNoApps       = "Select at least one app before {0}."
    ProgressApplied      = "Applied '{0}' and selected {1} of {2} apps."
    ProgressSaved        = "Saved '{0}' with {1} selected apps."
    ProgressDeleted      = "Deleted '{0}'."
    ProgressDeleteCancel = "Delete cancelled."

    EmptySearchTitle     = "No apps match your search"
    EmptySearchText      = "Try a different keyword, category name, package ID, source, or state."
    EmptyUpdateTitle     = "No installed apps with updates"
    EmptyUpdateText      = "All detected apps appear to be current. Re-scan or go back to browse."

    DialogSaveTitle      = "Save Package Group"
    DialogPlanTitle      = "Preflight run plan"
    DialogGalleryTitle   = "Profile Gallery"
    DialogPolicyTitle    = "Scheduled Update Policy"
    DialogSourceTitle    = "Corporate Source Policy"

    ToastComplete        = "Wingetter Complete"
    ToastUpdateCheck     = "Wingetter Update Check"

    TipShiftClick        = "Tip: Shift+Click selects a range."
    UpdateReviewHint     = "Review mode shows only apps already detected on this PC."
}

function Get-WingetterString {
    param(
        [Parameter(Mandatory)][string]$Key,
        [string[]]$FormatArgs = @()
    )

    $value = $Script:WingetterStrings[$Key]
    if ($null -eq $value) { return $Key }
    if ($FormatArgs.Count -gt 0) {
        return [string]::Format($value, [object[]]$FormatArgs)
    }
    return $value
}
