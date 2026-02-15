# List-OrgViaGraph.ps1
###

param (
    [Parameter(Mandatory)]
    [string]$RootUserUPN    # Starting root to enumerate users
)

Import-Module Microsoft.Graph.Users
Import-Module ExchangeOnlineManagement


# Connect to Microsoft Graph using device code flow to avoid broker issues
Connect-MgGraph -Scopes "User.Read.All" -UseDeviceAuthentication
$me = (Get-MgContext).Account

# Connect as the current user (no admin required)
# Connect-ExchangeOnline -ShowBanner:$false # This MAY be disabled on some tenants
start Chrome.exe https://microsoft.com/devicelogin
Connect-ExchangeOnline -ShowBanner:$false -device # Use -device login

# Script-scoped results container
$script:results = @()

<#
.SYNOPSIS
Retrieves the user's photo from Microsoft Graph and saves it as a .jpg file.

.PARAMETER UserId
The Id of the user whose photo will be retrieved.

.PARAMETER OutputFolder
The folder where photos will be saved. Defaults to '.\photos'.

.RETURNS
The file path to the saved photo, or $null if no photo exists.
#>
function Get-GraphUserPhoto {
    param (
        [Parameter(Mandatory)]
        [string]$UserId,

        [string]$OutputFolder = ".\photos"
    )

    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    $photoPath = Join-Path $OutputFolder "$UserId.jpg"

    try {
        Invoke-MgGraphRequest `
            -Method GET `
            -Uri "/users/$UserId/photo/`$value" `
            -OutputFilePath $photoPath

        return $photoPath
    }
    catch {
        # No photo assigned (very common)
        return $null
    }
}

<#
.SYNOPSIS
Retrieves the user's Exchange Online mailbox photo if Graph photo is not available.

.PARAMETER UserPrincipalName
The UPN of the user whose Exchange photo will be retrieved.

.PARAMETER OutputFolder
The folder where photos will be saved. Defaults to '.\photos'.

.RETURNS
The file path to the saved photo, or $null if no photo exists.
#>
function Get-ExchangeUserPhoto {
    param (
        [Parameter(Mandatory)]
        [string]$UserPrincipalName,

        [string]$OutputFolder = ".\photos"
    )

    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    $photoPath = Join-Path $OutputFolder "$($UserPrincipalName.Replace('@','_').Replace('.','_')).jpg"

    try {
        # Attempt to download the user's mailbox photo
        $photo = Get-UserPhoto -Identity $UserPrincipalName -ErrorAction Stop
        if ($photo -ne $null) {
            $photo | ForEach-Object {
                $_.PictureData | Set-Content -Path $photoPath -Encoding Byte
            }
            return $photoPath
        }
        else {
            return $null
        }
    }
    catch {
        # No photo available
        return $null
    }
}

<#
.SYNOPSIS
Recursively enumerates the organizational hierarchy starting from a given user.

.DESCRIPTION
Recursively walks the DirectReports hierarchy starting from a specified user.
Stores various user details along with the file path to the user's photo.

.PARAMETER UserId
The Id of the user to start traversal from.

.PARAMETER Level
Current hierarchy level (for indentation).

.PARAMETER ManagerUPN
UPN of the manager of the current user.
#>
function Get-OrgTree {
    param (
        [Parameter(Mandatory)]
        [string]$UserId,

        [int]$Level = 0,

        [string]$ManagerUPN = $null
    )

    # Get user details
    $user = Get-MgUser -UserId $UserId `
        -Property DisplayName,UserPrincipalName,JobTitle,Department,OfficeLocation,GivenName,EmployeeType,AboutMe,EmployeeHireDate,AccountEnabled, Id, Extensions,OnPremisesExtensionAttributes `
        -ErrorAction Stop
	
	# Get extended properties (employee ID, etc.)


    # Retrieve the user's photo (Graph first)
    $photoPath = Get-GraphUserPhoto -UserId $UserId

    # Fallback to Exchange photo if Graph photo not available
    if ($null -eq $photoPath) {
        $photoPath = Get-ExchangeUserPhoto -UserPrincipalName $user.UserPrincipalName
    }

	# Retrieve non-null extensions (these vary by company)
	$extensions = @{}
	$null = $user.OnPremisesExtensionAttributes.PSObject.Properties |
		Where-Object { $_.Name -like 'Extension*' -and $_.Value } |
		ForEach-Object { $extensions[$_.Name] = $_.Value }
	
	# Get EXCHANGE info for this user
	try {
		# Get mailbox information
        $EXuser = Get-User -Identity $User.UserPrincipalName -ErrorAction Stop
		# Get SMTP email addresses
		$SMTPDetails = Get-Mailbox $User.UserPrincipalName |
			Select-Object -ExpandProperty EmailAddresses |
			Where-Object { $_ -like "smtp:*" } | ForEach-Object { $_.Substring(5) }
		# Get distribution groups that the user is a member of... (SLOW)
		# $DL = Get-Recipient -RecipientTypeDetails MailUniversalDistributionGroup, MailUniversalSecurityGroup, MailNonUniversalGroup |
		#		Where-Object { (Get-DistributionGroupMember $_.Identity | Where-Object {$_.PrimarySmtpAddress -eq $User.UserPrincipalName}) }
    }
    catch {
        Write-Warning "Error accessing Exchange user: $($User.UserPrincipalName)"
		$EXuser = $null
		$SMTPDetails = $null
    }


    # Add to results
    $script:results += [PSCustomObject]@{
        Level       		= $Level
        DisplayName 		= $user.DisplayName
        UPN         		= $user.UserPrincipalName
        Title      		 	= $user.JobTitle
        Department  		= $user.Department
        OfficeLocation		= $user.OfficeLocation
        GivenName			= $user.GivenName
        EmployeeType		= $user.EmployeeType
        AboutMe				= $user.AboutMe
        EmployeeHireDate	= $user.EmployeeHireDate
        AccountEnabled		= $user.AccountEnabled
        Manager     		= $ManagerUPN
        PhotoPath           = $photoPath
		ObjectId			= $user.Id
 		ExtensionAttributes = $extensions | ConvertTo-Json
		EX_SamAccountName	= $EXUser.SamAccountName
		EX_OrgUnitRoot		= $EXUser.OrganizationalUnitRoot
		EX_SMTPAddresses	= $SMTPDetails
   }

    # Get direct reports
    $directReports = Get-MgUserDirectReport -UserId $UserId -All

    foreach ($dr in $directReports) {
        # write-host -ForegroundColor Yellow $dr.additionalproperties['displayName'] - $dr.id - $dr.AdditionalProperties.mail   # DEBUG

        # Graph returns directoryObjects — filter to users only
        # if ($dr.'@odata.type' -eq '#microsoft.graph.user') {
        # Retrieve User details
        # $user2 = Get-MgUser -UserId $dr.id `
        #    -Property DisplayName,UserPrincipalName,JobTitle,Department `
        #    -ErrorAction Stop
        Get-OrgTree `
            -UserId $dr.Id `
            -Level ($Level + 1) `
            -ManagerUPN $user.UserPrincipalName
    }
}

# Resolve root user
$root = Get-MgUser -UserId $RootUserUPN -Property Id,UserPrincipalName

# Start traversal
Get-OrgTree -UserId $root.Id

# Output as hierarchy
$script:results |
    Sort-Object Level, DisplayName |
    ForEach-Object {
        "{0}{1} ({2})" -f (' ' * ($_.Level * 2)), $_.DisplayName, $_.UPN
    }

# Return structured data
$script:results
