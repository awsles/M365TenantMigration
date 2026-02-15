# ============================================================
# M365TenantMigration.psm1
# Exposes two cmdlets:
#   Export-M365TenantConfiguration
#   Import-M365TenantConfiguration
# ============================================================

# -----------------------------
# Helper: Export a category to JSON with error handling
# -----------------------------
function Invoke-ExportCategory {
    param(
        [string]$CategoryName,
        [scriptblock]$ExportScriptBlock,
        [string]$OutputRoot
    )
    try {
        $Data = & $ExportScriptBlock
        $Output = @{
            _comment = "Category: $CategoryName – Global Microsoft Entra Tenant Settings Export"
            exportedAtUtc = (Get-Date).ToUniversalTime()
            tenantId = (Get-MgOrganization).Id
            settings = $Data
        }
        $Path = Join-Path $OutputRoot "$($CategoryName -replace ' ','_').json"
        $Output | ConvertTo-Json -Depth 20 | Out-File $Path -Encoding utf8
        Write-Host "Exported category '$CategoryName' to $Path"
    }
    catch {
        Write-Warning "Failed to export category '$CategoryName': $($_.Exception.Message)"
    }
}

# -----------------------------
# Cmdlet: Export-M365TenantConfiguration
# -----------------------------
function Export-M365TenantConfiguration {
    [CmdletBinding()]
    param(
        [string]$OutputPath = ".",
        [string[]]$Scopes = @(
            "Directory.Read.All",
            "Policy.Read.All",
            "RoleManagement.Read.Directory",
            "AuditLog.Read.All",
            "IdentityRiskyUser.Read.All",
            "Application.Read.All"
        )
    )

    # Connect to Graph
    Connect-MgGraph -Scopes $Scopes
    Select-MgProfile -Name "beta"

    $OutputRoot = Resolve-Path $OutputPath
    if (!(Test-Path $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null }

    # -----------------------------
    # Export Categories
    # -----------------------------

    Invoke-ExportCategory -CategoryName "Organization_Profile" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            organization = Get-MgOrganization
            domains = Get-MgDomain
            branding = Get-MgOrganizationBranding
        }
    }

    Invoke-ExportCategory -CategoryName "Authentication_Identity" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            authenticationMethodsPolicy = Get-MgPolicyAuthenticationMethodsPolicy
            authMethodConfigurations = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration
            authorizationPolicy = Get-MgPolicyAuthorizationPolicy
            identitySecurityDefaults = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy
        }
    }

    Invoke-ExportCategory -CategoryName "Conditional_Access" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            policies = Get-MgIdentityConditionalAccessPolicy
            namedLocations = Get-MgIdentityConditionalAccessNamedLocation
            authenticationContexts = Get-MgIdentityConditionalAccessAuthenticationContextClassReference
        }
    }

    Invoke-ExportCategory -CategoryName "Identity_Protection" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            riskyUsers = Get-MgIdentityRiskyUser
        }
    }

    Invoke-ExportCategory -CategoryName "Roles_and_PIM" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            roleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition
            roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment
            pimPolicies = Get-MgPolicyRoleManagementPolicy
        }
    }

    Invoke-ExportCategory -CategoryName "Enterprise_Applications" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            servicePrincipals = Get-MgServicePrincipal -All
            appRegistrations = Get-MgApplication -All
            consentPolicy = Get-MgPolicyAdminConsentRequestPolicy
        }
    }

    Invoke-ExportCategory -CategoryName "External_Identities" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            crossTenantAccessPolicy = Get-MgPolicyCrossTenantAccessPolicy
            crossTenantAccessPartners = Get-MgPolicyCrossTenantAccessPolicyPartner
        }
    }

    Invoke-ExportCategory -CategoryName "Device_Settings" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            deviceRegistrationPolicy = Get-MgPolicyDeviceRegistrationPolicy
            devices = Get-MgDevice -All
        }
    }

    Invoke-ExportCategory -CategoryName "Identity_Governance" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            accessPackages = Get-MgEntitlementManagementAccessPackage -All
            accessPackagePolicies = Get-MgEntitlementManagementAccessPackageAssignmentPolicy -All
            lifecycleWorkflows = Get-MgIdentityGovernanceLifecycleWorkflow -All
        }
    }

    Invoke-ExportCategory -CategoryName "Audit_and_Monitoring" -OutputRoot $OutputRoot -ExportScriptBlock {
        @{
            auditLogs = Get-MgAuditLogDirectoryAudit -Top 50
            signInLogs = Get-MgAuditLogSignIn -Top 50
        }
    }

    Write-Host "Tenant export completed. JSON files saved to $OutputRoot"
    Disconnect-MgGraph
}

# -----------------------------
# Helper: Import a category JSON file
# -----------------------------
function Invoke-ImportCategory {
    param(
        [string]$CategoryFile
    )

    try {
        $CategoryData = Get-Content -Path $CategoryFile -Raw | ConvertFrom-Json
        $CategoryName = ($CategoryFile | Split-Path -Leaf).Replace('.json','')
        Write-Host "Importing category '$CategoryName'"

        foreach ($Key in $CategoryData.settings.PSObject.Properties.Name) {
            $Object = $CategoryData.settings.$Key
            try {
                # TODO: Implement specific object creation based on key
                # Placeholder: Example
                # New-MgWhatever -BodyParameter $Object
            }
            catch {
                Write-Warning "Failed to create object type '$Key': $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Warning "Failed to read/import category file '$CategoryFile': $($_.Exception.Message)"
    }
}

# -----------------------------
# Cmdlet: Import-M365TenantConfiguration
# -----------------------------
function Import-M365TenantConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ImportPath,
        [string[]]$Scopes = @(
            "Directory.ReadWrite.All",
            "Policy.ReadWrite.ConditionalAccess",
            "RoleManagement.ReadWrite.Directory",
            "Application.ReadWrite.All",
            "IdentityRiskyUser.ReadWrite.All"
        )
    )

    Connect-MgGraph -Scopes $Scopes
    Select-MgProfile -Name "beta"

    if (!(Test-Path $ImportPath)) {
        throw "Import path '$ImportPath' not found."
    }

    $Files = Get-ChildItem -Path $ImportPath -Filter *.json
    foreach ($File in $Files) {
        Invoke-ImportCategory -CategoryFile $File.FullName
    }

    Write-Host "Tenant import scaffold complete."
    Disconnect-MgGraph
}
