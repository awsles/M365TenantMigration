<#
.SYNOPSIS
Enumerates Exchange users following the organizational hierarchy starting from a given user.

.DESCRIPTION
Recursively walks the DirectReports hierarchy starting from a specified user
(user@domain.com). Uses only data normally visible to a standard Exchange user.

Exchange does not expose the distinguishedName or objectId of direct reports to non-admin users.
➡️ This makes true downward traversal impossible using Exchange cmdlets alone.
The Key Constraint (Important) is that there is no supported way to reliably walk the org hierarchy
downward using only Exchange PowerShell and user-level permissions.

.PARAMETER RootUser
The starting user UPN (e.g., user@domain.com)

.EXAMPLE
.\Get-ExchangeOrgHierarchy.ps1 -RootUser "jane.doe@contoso.com"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$RootUser
)

# Connect as the current user (no admin required)
Connect-ExchangeOnline -ShowBanner:$false

$results = @()

function Get-OrgTree {
    param (
        [string]$UserPrincipalName,
        [int]$Level = 0,
        [string]$ManagerUPN = $null
    )

    try {
        $user = Get-User -Identity $UserPrincipalName -ErrorAction Stop
    }
    catch {
        Write-Warning "Unable to access user: $UserPrincipalName"
        return
    }

    $results += [PSCustomObject]@{
        Level       = $Level
        DisplayName = $user.DisplayName
        UPN         = $user.UserPrincipalName
        Title       = $user.Title
        Department  = $user.Department
        Manager     = $ManagerUPN
    }

    foreach ($dr in $user.DirectReports) {
        try {
            $drUser = Get-User -Identity $dr
            Get-OrgTree `
                -UserPrincipalName $drUser.UserPrincipalName `
                -Level ($Level + 1) `
                -ManagerUPN $user.UserPrincipalName
        }
        catch {
            Write-Warning "Unable to access direct report: $dr"
        }
    }
}

# Start traversal
Get-OrgTree -UserPrincipalName $RootUser

# Output hierarchy (tree-style indentation)
$results |
    Sort-Object Level, DisplayName |
    ForEach-Object {
        "{0}{1} ({2})" -f (' ' * ($_.Level * 2)), $_.DisplayName, $_.UPN
    }

# Also return structured objects if script is dot-sourced
return $results
