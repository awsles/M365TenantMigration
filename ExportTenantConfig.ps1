# ============================================================
# ExportTenantConfig.ps1
# 
# Export various aspects of the tenant that may be factors in migrations
# ============================================================
# $$ | export-csv -Encoding UTF8 -UseQuotes AsNeeded -NoTypeInformation -Path 'C:\Users\lwaters\Desktop\PHOENIX\Service Migrations\name.csv'

$Scopes = @(
            "Directory.Read.All",
            "Policy.Read.All",
            "RoleManagement.Read.Directory",
            "AuditLog.Read.All",
            "IdentityRiskyUser.Read.All",
            "Application.Read.All"
        )


# Connect to Graph
#    Connect-MgGraph # -Scopes $Scopes
#    Select-MgProfile -Name "beta"


# Category: "Organization_Profile"
$CategoryName = "Organization_Profile" 
$organization = Get-MgOrganization
$tenantID = $organization.ID
$domains = Get-MgDomain
$branding = Get-MgOrganizationBranding -OrganizationId $tenantID


# Category: Authentication_Identity
$CategoryName = "Authentication_Identity" 
$authenticationMethodsPolicy = Get-MgPolicyAuthenticationMethodsPolicy
$authMethodConfigurations = Get-MgPolicyAuthenticationMethodPolicyAuthenticationMethodConfiguration
$authorizationPolicy = Get-MgPolicyAuthorizationPolicy
$identitySecurityDefaults = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy


# Category: Conditional_Access
$CategoryName = "Conditional_Access" 
$policies = Get-MgIdentityConditionalAccessPolicy						# PRIVILEGED
$namedLocations = Get-MgIdentityConditionalAccessNamedLocation			# PRIVILEGED
$authenticationContexts = Get-MgIdentityConditionalAccessAuthenticationContextClassReference	# PRIVILEGED


# Category: Identity_Protection
$CategoryName = "Identity_Protection" 
# $riskyUsers = Get-MgIdentityRiskyUser		# Unknown Method



# Category: Roles_and_PIM
$CategoryName = "Roles_and_PIM" 
$roleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition
$roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment
$pimPolicies = Get-MgPolicyRoleManagementPolicy

# Category: Enterprise_Applications
$CategoryName = "Enterprise_Applications" 
$servicePrincipals = Get-MgServicePrincipal -All
$appRegistrations = Get-MgApplication -All
	| Select-Object -Property AppId,DisplayName,CreatedDateTime,Description,SignInAudience,Tags,Owners 
	| ForEach-Object {
		[PSCustomObject]@{
			AppId = $_.AppId
			DisplayName = $_.DisplayName
			CreatedDateTime = $_.CreatedDateTime
			Description = $_.Description
			SignInAudience = $_.SignInAudience
			Tags   = ($_.Tags -join ';')
			Owners = ($_.Owners -join ';')
		}
	}
$consentPolicy = Get-MgPolicyAdminConsentRequestPolicy


# Category: External_Identities
$CategoryName = "External_Identities" 
$crossTenantAccessPolicy = Get-MgPolicyCrossTenantAccessPolicy				# PRIVILEGED
$crossTenantAccessPartners = Get-MgPolicyCrossTenantAccessPolicyPartner		# PRIVILEGED

# Category: Device_Settings
$CategoryName = "Device_Settings" 
$deviceRegistrationPolicy = Get-MgPolicyDeviceRegistrationPolicy   			# PRIVILEGED
$devices = Get-MgDevice -All
	| Select-Object -Property DeviceId,DisplayName,DeviceOwnership,EnrollmentType,IsManaged,ManagementType,Manufacturer,Model,OperatingSystem,OperatingSystemVersion,RegistrationDateTime,AccountEnabled,ApproximateLastSignInDateTime


# Category: Identity_Governance
$CategoryName = "Identity_Governance" 
$accessPackages = Get-MgEntitlementManagementAccessPackage -All				# PRIVILEGED
$accessPackagePolicies = Get-MgEntitlementManagementAccessPackageAssignmentPolicy -All  # Requires -AccessPackageId
$lifecycleWorkflows = Get-MgIdentityGovernanceLifecycleWorkflow -All		# PRIVILEGED


# Category: Audit_and_Monitoring
#$CategoryName = "Audit_and_Monitoring" 
#$auditLogs = Get-MgAuditLogDirectoryAudit -Top 50
#$signInLogs = Get-MgAuditLogSignIn -Top 50

return
# Example: Exporting distribution group members
Get-DistributionGroup -Filter {name -like "*forwarder"} | ForEach-Object {
    [PSCustomObject]@{
        GroupName = $_.Name
        Members   = (Get-DistributionGroupMember $_.Name | Select-Object -ExpandProperty Name) -join ';'
    }
} | Export-Csv -Path C:\temp\group_members.csv -NoTypeInformation
