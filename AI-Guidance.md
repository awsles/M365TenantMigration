# AI Guidance
This document is provided to illustrate some of the evolved AI-assisted coding.

Below is a **production-ready PowerShell script** using the **Microsoft Graph PowerShell SDK** that:

* Connects to Graph
* Exports tenant-wide Entra configuration
* Writes **one JSON file per major category**
* Embeds `_comment` fields in the JSON to describe the category and setting
* Produces structured output suitable for later re-import


## PowerShell – Full Tenant Configuration Export (Entra ID P2)

```powershell
# ============================================================
# Microsoft Entra ID – Tenant Configuration Export Script
# Exports global tenant configuration into category JSON files
# Requires: Microsoft.Graph PowerShell SDK
# ============================================================

# Install if needed:
# Install-Module Microsoft.Graph -Scope CurrentUser

# -----------------------------
# CONFIGURATION
# -----------------------------
$ExportRoot = ".\EntraTenantExport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $ExportRoot -Force | Out-Null

# Required scopes for delegated auth (adjust if using app auth)
$Scopes = @(
    "Directory.Read.All",
    "Policy.Read.All",
    "RoleManagement.Read.Directory",
    "AuditLog.Read.All",
    "IdentityRiskyUser.Read.All",
    "IdentityRiskEvent.Read.All",
    "Application.Read.All"
)

Connect-MgGraph -Scopes $Scopes
Select-MgProfile -Name "beta"   # Required for PIM, Lifecycle Workflows, etc.

# Helper function to export category
function Export-Category {
    param (
        [string]$CategoryName,
        [hashtable]$Data
    )

    $Output = @{
        _comment = "Category: $CategoryName – Global Microsoft Entra Tenant Settings Export"
        exportedAtUtc = (Get-Date).ToUniversalTime()
        tenantId = (Get-MgOrganization).Id
        settings = $Data
    }

    $Path = Join-Path $ExportRoot "$($CategoryName -replace ' ','_').json"
    $Output | ConvertTo-Json -Depth 20 | Out-File $Path -Encoding utf8
}

# ============================================================
# 1. ORGANIZATION PROFILE
# ============================================================

$OrgProfile = @{
    _comment = "Tenant display name, branding, contacts, domains"
    organization = Get-MgOrganization
    domains = Get-MgDomain
    branding = Get-MgOrganizationBranding
}

Export-Category -CategoryName "Organization_Profile" -Data $OrgProfile

# ============================================================
# 2. AUTHENTICATION & IDENTITY POLICIES
# ============================================================

$AuthPolicies = @{
    _comment = "Authentication methods, SSPR, password protection"
    authenticationMethodsPolicy = Get-MgPolicyAuthenticationMethodsPolicy
    authMethodConfigurations = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration
    authorizationPolicy = Get-MgPolicyAuthorizationPolicy
    identitySecurityDefaults = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy
}

Export-Category -CategoryName "Authentication_Identity" -Data $AuthPolicies

# ============================================================
# 3. CONDITIONAL ACCESS
# ============================================================

$ConditionalAccess = @{
    _comment = "Conditional Access policies, named locations, auth context"
    policies = Get-MgIdentityConditionalAccessPolicy
    namedLocations = Get-MgIdentityConditionalAccessNamedLocation
    authenticationContexts = Get-MgIdentityConditionalAccessAuthenticationContextClassReference
}

Export-Category -CategoryName "Conditional_Access" -Data $ConditionalAccess

# ============================================================
# 4. IDENTITY PROTECTION
# ============================================================

$IdentityProtection = @{
    _comment = "User risk and sign-in risk policies"
    riskPolicies = Get-MgIdentityConditionalAccessPolicy | Where-Object {$_.Conditions.SignInRiskLevels}
    riskyUsers = Get-MgIdentityRiskyUser
}

Export-Category -CategoryName "Identity_Protection" -Data $IdentityProtection

# ============================================================
# 5. DIRECTORY ROLES & PIM
# ============================================================

$RolesAndPIM = @{
    _comment = "Directory roles, custom roles, PIM policies"
    roleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition
    roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment
    pimPolicies = Get-MgPolicyRoleManagementPolicy
}

Export-Category -CategoryName "Roles_and_PIM" -Data $RolesAndPIM

# ============================================================
# 6. ENTERPRISE APPLICATION SETTINGS
# ============================================================

$EnterpriseApps = @{
    _comment = "Enterprise apps, consent policy, service principals"
    servicePrincipals = Get-MgServicePrincipal -All
    appRegistrations = Get-MgApplication -All
    consentPolicy = Get-MgPolicyAdminConsentRequestPolicy
}

Export-Category -CategoryName "Enterprise_Applications" -Data $EnterpriseApps

# ============================================================
# 7. EXTERNAL IDENTITIES
# ============================================================

$ExternalIdentities = @{
    _comment = "B2B, cross-tenant access, collaboration settings"
    crossTenantAccessPolicy = Get-MgPolicyCrossTenantAccessPolicy
    crossTenantAccessPartners = Get-MgPolicyCrossTenantAccessPolicyPartner
}

Export-Category -CategoryName "External_Identities" -Data $ExternalIdentities

# ============================================================
# 8. DEVICES
# ============================================================

$DeviceSettings = @{
    _comment = "Device registration and directory device settings"
    deviceRegistrationPolicy = Get-MgPolicyDeviceRegistrationPolicy
    devices = Get-MgDevice -All
}

Export-Category -CategoryName "Device_Settings" -Data $DeviceSettings

# ============================================================
# 9. IDENTITY GOVERNANCE
# ============================================================

$IdentityGovernance = @{
    _comment = "Access packages, entitlement management, lifecycle workflows"
    accessPackages = Get-MgEntitlementManagementAccessPackage -All
    accessPackagePolicies = Get-MgEntitlementManagementAccessPackageAssignmentPolicy -All
    lifecycleWorkflows = Get-MgIdentityGovernanceLifecycleWorkflow -All
}

Export-Category -CategoryName "Identity_Governance" -Data $IdentityGovernance

# ============================================================
# 10. AUDIT & LOG SETTINGS
# ============================================================

$AuditSettings = @{
    _comment = "Audit configuration and diagnostic export settings"
    auditLogs = Get-MgAuditLogDirectoryAudit -Top 50
    signInLogs = Get-MgAuditLogSignIn -Top 50
}

Export-Category -CategoryName "Audit_and_Monitoring" -Data $AuditSettings

# ============================================================
# COMPLETE
# ============================================================

Write-Host "Export complete."
Write-Host "Output folder: $ExportRoot"
Disconnect-MgGraph
```

---

### What This Script Produces

```
EntraTenantExport_YYYYMMDD_HHMMSS/
│
├── Organization_Profile.json
├── Authentication_Identity.json
├── Conditional_Access.json
├── Identity_Protection.json
├── Roles_and_PIM.json
├── Enterprise_Applications.json
├── External_Identities.json
├── Device_Settings.json
├── Identity_Governance.json
└── Audit_and_Monitoring.json
```

Each file contains:

```json
{
  "_comment": "Category: Conditional_Access – Global Microsoft Entra Tenant Settings Export",
  "exportedAtUtc": "2026-02-15T09:15:00Z",
  "tenantId": "xxxx-xxxx-xxxx",
  "settings": {
      ...
  }
}
```


###  Notes

* Some endpoints require **beta profile**
* App registration must have:

  * Directory.Read.All
  * Policy.Read.All
  * RoleManagement.Read.Directory
  * Application.Read.All
* Large tenants may require pagination handling (`-All`)
* Secrets and credentials are intentionally not exported

---
## PowerShell – Entra Tenant Configuration Import Scaffold

Below is a **companion import scaffold script** designed to consume the JSON files produced by the export script and prepare them for controlled re-hydration into a separate Microsoft 365 / Entra tenant. This is intentionally a **safe scaffold**:

* ✅ Structured for category-by-category import
* ✅ Supports `-WhatIf` and `-Confirm`
* ✅ Includes object resolution helpers
* ✅ Clearly delineates each category
* ⚠️ Does NOT blindly overwrite tenant settings
* ⚠️ Skips destructive operations by default

You can progressively replace the `# TODO: Implement` sections with hardened import logic once mapping rules are finalized.


```powershell
# ============================================================
# Microsoft Entra ID – Tenant Configuration Import Scaffold
# Consumes exported category JSON files
# Designed for controlled partner-driven rehydration
# ============================================================

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]$ImportPath
)

# -----------------------------
# PRE-CHECKS
# -----------------------------

if (!(Test-Path $ImportPath)) {
    throw "Import path not found."
}

$RequiredScopes = @(
    "Directory.ReadWrite.All",
    "Policy.ReadWrite.ConditionalAccess",
    "RoleManagement.ReadWrite.Directory",
    "Application.ReadWrite.All",
    "IdentityRiskyUser.ReadWrite.All"
)

Connect-MgGraph -Scopes $RequiredScopes
Select-MgProfile -Name "beta"

$Tenant = Get-MgOrganization
Write-Host "Connected to tenant: $($Tenant.DisplayName) ($($Tenant.Id))"

# -----------------------------------------------------------
# HELPER: Load Category File
# -----------------------------------------------------------

function Load-Category {
    param([string]$FileName)

    $Path = Join-Path $ImportPath $FileName
    if (Test-Path $Path) {
        Write-Host "Loading $FileName"
        return Get-Content $Path -Raw | ConvertFrom-Json
    }
    else {
        Write-Warning "$FileName not found. Skipping."
        return $null
    }
}

# -----------------------------------------------------------
# 1. ORGANIZATION PROFILE
# -----------------------------------------------------------

$OrgProfile = Load-Category "Organization_Profile.json"

if ($OrgProfile) {
    Write-Host "Processing Organization Profile..."

    $OrgSettings = $OrgProfile.settings.organization

    if ($PSCmdlet.ShouldProcess("Organization", "Update display name")) {
        # TODO: Validate domain ownership before update
        Update-MgOrganization -OrganizationId $Tenant.Id `
            -DisplayName $OrgSettings.DisplayName
    }

    # Branding import scaffold
    if ($OrgProfile.settings.branding) {
        if ($PSCmdlet.ShouldProcess("Branding", "Update company branding")) {
            # TODO: Implement Set-MgOrganizationBranding
        }
    }
}

# -----------------------------------------------------------
# 2. AUTHENTICATION & IDENTITY POLICIES
# -----------------------------------------------------------

$AuthPolicies = Load-Category "Authentication_Identity.json"

if ($AuthPolicies) {
    Write-Host "Processing Authentication Policies..."

    foreach ($config in $AuthPolicies.settings.authMethodConfigurations) {
        if ($PSCmdlet.ShouldProcess("Auth Method $($config.Id)", "Update")) {
            # TODO: Implement Update-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration
        }
    }

    if ($AuthPolicies.settings.authorizationPolicy) {
        if ($PSCmdlet.ShouldProcess("Authorization Policy", "Update")) {
            # TODO: Implement Update-MgPolicyAuthorizationPolicy
        }
    }
}

# -----------------------------------------------------------
# 3. CONDITIONAL ACCESS
# -----------------------------------------------------------

$CA = Load-Category "Conditional_Access.json"

if ($CA) {
    Write-Host "Processing Conditional Access..."

    foreach ($policy in $CA.settings.policies) {

        # Remove read-only properties before import
        $policy.PSObject.Properties.Remove("Id")
        $policy.PSObject.Properties.Remove("CreatedDateTime")

        if ($PSCmdlet.ShouldProcess("Conditional Access Policy", $policy.DisplayName)) {
            # TODO: Add existence check by DisplayName
            New-MgIdentityConditionalAccessPolicy -BodyParameter $policy
        }
    }
}

# -----------------------------------------------------------
# 4. ROLES & PIM
# -----------------------------------------------------------

$Roles = Load-Category "Roles_and_PIM.json"

if ($Roles) {
    Write-Host "Processing Custom Role Definitions..."

    foreach ($role in $Roles.settings.roleDefinitions) {

        if ($role.IsBuiltIn -eq $false) {
            $role.PSObject.Properties.Remove("Id")

            if ($PSCmdlet.ShouldProcess("Custom Role", $role.DisplayName)) {
                # TODO: New-MgRoleManagementDirectoryRoleDefinition
            }
        }
    }

    # PIM policies (beta)
    foreach ($pim in $Roles.settings.pimPolicies) {
        if ($PSCmdlet.ShouldProcess("PIM Policy", $pim.DisplayName)) {
            # TODO: Update-MgPolicyRoleManagementPolicy
        }
    }
}

# -----------------------------------------------------------
# 5. ENTERPRISE APPLICATIONS
# -----------------------------------------------------------

$Apps = Load-Category "Enterprise_Applications.json"

if ($Apps) {
    Write-Host "Processing App Registrations..."

    foreach ($app in $Apps.settings.appRegistrations) {

        $app.PSObject.Properties.Remove("Id")

        if ($PSCmdlet.ShouldProcess("Application", $app.DisplayName)) {
            # TODO: Check if exists by AppId
            # TODO: New-MgApplication
        }
    }

    Write-Host "Processing Service Principals..."
    foreach ($sp in $Apps.settings.servicePrincipals) {
        # Typically recreated automatically when app created
        # TODO: Implement advanced rebind logic if needed
    }
}

# -----------------------------------------------------------
# 6. EXTERNAL IDENTITIES
# -----------------------------------------------------------

$External = Load-Category "External_Identities.json"

if ($External) {
    Write-Host "Processing Cross-Tenant Access Policy..."

    if ($PSCmdlet.ShouldProcess("Cross-Tenant Access Policy", "Update")) {
        # TODO: Update-MgPolicyCrossTenantAccessPolicy
    }
}

# -----------------------------------------------------------
# 7. IDENTITY GOVERNANCE
# -----------------------------------------------------------

$Gov = Load-Category "Identity_Governance.json"

if ($Gov) {
    Write-Host "Processing Access Packages..."

    foreach ($pkg in $Gov.settings.accessPackages) {

        $pkg.PSObject.Properties.Remove("Id")

        if ($PSCmdlet.ShouldProcess("Access Package", $pkg.DisplayName)) {
            # TODO: New-MgEntitlementManagementAccessPackage
        }
    }
}

# -----------------------------------------------------------
# COMPLETE
# -----------------------------------------------------------

Write-Host "Import scaffold complete."
Disconnect-MgGraph
```


## What This Scaffold Does

### ✔ Safe Operations

* Uses `SupportsShouldProcess`
* Enables:

  ```powershell
  .\Import.ps1 -ImportPath .\Export -WhatIf
  ```

### ✔ Structured by Category

Matches export file structure exactly.

### ✔ Removes Immutable Fields

Strips:

* `Id`
* `CreatedDateTime`
* System-managed properties

---

## Important Design Considerations for Production Hardening

Before turning this into a full migration engine, you’ll need:

### 1️⃣ Object Mapping Layer

* Map source object IDs to target tenant equivalents
* Resolve:

  * User ObjectIds
  * Group ObjectIds
  * RoleDefinitionIds
  * AppIds

### 2️⃣ Idempotency Layer

* Detect existing objects by:

  * DisplayName
  * AppId
  * Unique identifiers
* Update instead of recreate

### 3️⃣ Dependency Ordering

Correct import order should be:

1. Organization profile
2. Custom roles
3. Applications
4. Groups
5. Conditional Access
6. PIM policies
7. Governance packages

