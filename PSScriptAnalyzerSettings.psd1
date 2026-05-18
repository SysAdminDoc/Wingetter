@{
    # PSScriptAnalyzer settings for the Wingetter repository.
    #
    # Run via tools\Test-Analyzer.ps1 (local) and .github/workflows/validate.yml
    # (CI). Use pwsh 7+ so the PSScriptAnalyzer module installed under PSGallery
    # CurrentUser scope is discoverable.
    #
    # The IncludeRules list is intentionally narrow: it enforces the regressions
    # called out in PROJECT_CONTEXT.md "Important Gaps" (automatic-variable
    # shadowing, write-only parameters), plus a handful of security-oriented
    # rules. We do NOT enforce style rules (verb conventions, ShouldProcess on
    # internal helpers, trailing whitespace) because the project favors small
    # PowerShell scripts over cmdlet-style modules.

    Severity = @('Error', 'Warning')

    IncludeRules = @(
        # Acceptance: shadowed-automatic-variable warning and undeclared
        # write-only parameter must fail the build.
        'PSAvoidAssignmentToAutomaticVariable',
        'PSReviewUnusedParameter',

        # Security-oriented rules.
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingComputerNameHardcoded',
        'PSAvoidUsingUserNameAndPasswordParams',
        'PSAvoidNullOrEmptyHelpMessageAttribute',
        'PSAvoidShouldContinueWithoutForce',
        'PSAvoidGlobalAliases',

        # Correctness rules.
        'PSPossibleIncorrectComparisonWithNull',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSMissingModuleManifestField',
        'PSUsePSCredentialType'
    )
}
