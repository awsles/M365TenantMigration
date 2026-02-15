<#
.SYNOPSIS
	Configure or Retrieve your photo in Active Directory.
.DESCRIPTION
	This will configure a user's photo in Active Directory by either uploading a
	specified file (which MUST be less than 100k in size) OR by retriving the image
	from exchange.
.PARAMETER file <string>
	Indicates the image file to upload (MUST be under 100k in size!)
.PARAMETER set
	If -set is specified, then the photo is set in Active Directory.
.NOTES
	Author: Lester Waters
.LINK
	
#>

################################################################################################################
#   PARAMETERS                                                                                                 #
################################################################################################################
Param (
	[string] $file = "",
	[switch] $set = $false
)


################################################################################################################
#   FUNCTIONS                                                                                                  #
################################################################################################################

# https://gist.github.com/zippy1981/969855
Function ShowPhoto {
Param ( $FileName)

[void][reflection.assembly]::LoadWithPartialName("System.Windows.Forms")

$file = (get-item $FileName)
#$file = (get-item "c:\image.jpg")

$img = [System.Drawing.Image]::Fromfile($file);

# This tip from http://stackoverflow.com/questions/3358372/windows-forms-look-different-in-powershell-and-powershell-ise-why/3359274#3359274
[System.Windows.Forms.Application]::EnableVisualStyles();
$form = new-object Windows.Forms.Form
$form.Text = "Image Viewer"
$form.Width = $img.Size.Width;
$form.Height =  $img.Size.Height;
$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.Width =  $img.Size.Width;
$pictureBox.Height =  $img.Size.Height;

$pictureBox.Image = $img;
$form.controls.add($pictureBox)
$form.Add_Shown( { $form.Activate() } )
$form.ShowDialog()
#$form.Show();
}

################################################################################################################
#   CONSTANTS                                                                                                  #
################################################################################################################


################################################################################################################
#   MODULES                                                                                                    #
################################################################################################################
Try {
	Import-Module ActiveDirectory -ErrorAction Stop
	}
Catch
{
	Write-Error "Please install the ActiveDirectory module  (Install-Module ActiveDirectory)"
}




################################################################################################################
#   MAIN BODY                                                                                                  #
################################################################################################################

#
# Variables
#

#
# Retrieve out startup directory and set our current
# directory (PowerShell scripts seem to default to the Windows System32 folder)
#
$invocation = (Get-Variable MyInvocation).Value
$Currentdirectorypath = Split-Path $invocation.MyCommand.Path
[IO.Directory]::SetCurrentDirectory($Currentdirectorypath)   # Set our current directory


#
# Determine Current logged in user
#
$CurrentUsername = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$CurrentSam = $CurrentUsername.Substring($CurrentUsername.IndexOf("\")+1).Trim()
$CurrentUser = Get-ADUser -Filter {SamAccountName -like $CurrentSam} -Properties EmailAddress, DisplayName, Title, City, State, Country, Office, OfficePhone, PostalCode, MobilePhone, EmployeeNumber -ErrorAction Stop
write-host "You are" $CurrentUsername "with a SamaAccountName of" $CurrentSam "and an email address of" $CurrentUser.EmailAddress

$ADuser = $CurrentUser
$ADusername = $ADUser.SamAccountName
if ($ADuser -eq $null) {
	write-host "User" $email "was not found in the Active Directory."
	write-host "Therefore, the will NOT be added to Azure Active Directory."
	write-host "Be sure to specify the email as 'GivenName.Surname@msci.com'."
	return $null
}	
if ($ADuser.Enabled -ne $true) {
	write-host "User" $ADuser.UserPrincipalName "is DISABLED in Active Directory."
	write-host "Therefore, this user will NOT be added for security reasons."
	return $null
}


######################
#
# Add the user's photo from http://n/  (http://photos.local/users/03109.jpg)
# Use the employee number to retreive the photo
#  $ADuser.EmployeeNumber
#  Set-UserPhoto "Kim Bing" -PictureData ([System.IO.File]::ReadAllBytes("C:\Temp\KA.jpg"))  -  https://technet.microsoft.com/en-us/library/jj218694(v=exchg.160).aspx
#  http://paulryan.com.au/2016/user-photos-office-365/
# https://wdmsb.wordpress.com/2013/02/04/how-to-populate-the-thumbnailphoto-attribute-in-ad-ds/
#  Azure AD in the thumbnailPhoto attribute
#  https://blogs.technet.microsoft.com/cloudtrek365/2014/12/31/uploading-high-resolution-photos-using-powershell-for-office-365/
#  https://social.technet.microsoft.com/wiki/contents/articles/19028.active-directory-add-or-update-a-user-picture-using-powershell.aspx
#  http://danstis.logdown.com/posts/461039-powershell-function-to-export-a-users-thumbnail-photo-from-ad
#
#  https://blogs.technet.microsoft.com/heyscriptingguy/2014/08/09/weekend-scripter-exporting-and-importing-photos-in-active-directory/
#    
#    SET-ADUser wateles –add @{thumbnailphoto=$Picture}
#
#    $user = get-Aduser wateles -Properties thumbnailphoto
#    [System.Io.File]::WriteAllBytes('c:\Users\lesterw\Desktop\03109a.jpg', $user.Thumbnailphoto)
#
#   $List = get-aduser -Filter{Thumbnailphoto -like "*"} -Properties Thumbnailphoto
#
#  $w = Invoke-WebRequest http://photos.local/users/03109.jpg    [-OutFile xx.jpg]
#   [System.Io.File]::WriteAllBytes('c:\Users\wateles.msci\Desktop\03109b.jpg', $w.Content)
#
#   Import-RecipientDataProperty -Identity “Bharat Jones” -Picture -FileData ([Byte[]]$(Get-Content -Path “C:\pictures\BharatSuneja.jpg” -Encoding Byte -ReadCount 0))
#
#   https://www.slipstick.com/exchange/cmdlets/import-images-active-directory/
#
#  http://www.cjwdev.co.uk/Software/ADPhotoEdit/Info.html
#
#   Set-UserPhoto    https://technet.microsoft.com/en-us/library/jj218694(v=exchg.160).aspx


# Retrieve employee photo
Write-Host -NoNewLine "Retrieving Employee Photo from http://n/... "
$url = "http://photos.local/users/" + $ADuser.EmployeeNumber + ".jpg"
$outfile = $ADuser.EmployeeNumber + ".jpg"
$w = Invoke-WebRequest $url -ErrorAction SilentlyContinue
if ($w -eq $null -Or $w.StatusCode -ne 200)
{
	write-host "No Photo"
}
else
{
	write-host ("OK  (" + [string]$w.Content.Length + " bytes)" )
	$Picture = $w.Content
	[System.Io.File]::WriteAllBytes($outfile, $Picture)   # Save a local copy
	write-host "You may Preview the photo (look for the popup)" -ForeGroundColor Yellow
	$x = ShowPhoto($outfile)
}

#
# If -file specified, then use that...
#
if ($file.Length -gt 1) 
{
	$Picture=[System.IO.File]::ReadAllBytes($file)
}

#
# Now set the photo
#
if ($set -eq $true -And $Picture -ne $null)
{
	SET-ADUser $CurrentSam -add @{thumbnailphoto=$Picture} -ErrorAction Stop
}
