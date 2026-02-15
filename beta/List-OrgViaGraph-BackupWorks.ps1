param (
#    [Parameter(Mandatory)]
    [string]$RootUserUPN = 'les.waters@hitachivantara.com'
)

Import-Module Microsoft.Graph.Users

Connect-MgGraph -Scopes "User.Read.All"

# Script-scoped results container
$script:results = @()

function Get-OrgTree {
    param (
        [Parameter(Mandatory)]
        [string]$UserId,

        [int]$Level = 0,

        [string]$ManagerUPN = $null
    )

    # Get user details
    $user = Get-MgUser -UserId $UserId `
        -Property DisplayName,UserPrincipalName,JobTitle,Department,OfficeLocation,GivenName,EmployeeType, AboutMe,EmployeeHireDate,AccountEnabled `
        -ErrorAction Stop

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
		HVid				= $user.id
        Manager     		= $ManagerUPN
    }

    # Get direct reports
    $directReports = Get-MgUserDirectReport -UserId $UserId -All

    foreach ($dr in $directReports) {
		write-host -ForegroundColor Yellow $dr.additionalproperties['displayName'] - $dr.id - $dr.AdditionalProperties.mail
		
        # Graph returns directoryObjects — filter to users only
        # if ($dr.'@odata.type' -eq '#microsoft.graph.user') {
		# Retrieve User details
		# $user2 = Get-MgUser -UserId $dr.id `
		#	-Property DisplayName,UserPrincipalName,JobTitle,Department `
		#	-ErrorAction Stop
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
