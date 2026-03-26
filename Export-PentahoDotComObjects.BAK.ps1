# Connect to Exchange Online
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline

$domain = "@pentaho.com"
$output = @()

# Retrieve recipients
# $recipients = Get-EXORecipient -ResultSize Unlimited -Properties EmailAddresses,PrimarySmtpAddress,DisplayName,RecipientTypeDetails
write-host -ForegroundColor Yellow "Getting recipients..."
$recipients = Get-EXORecipient `
    -Filter "EmailAddresses -like '*@pentaho.com'" `
    -ResultSize Unlimited `
    -Properties DisplayName,PrimarySmtpAddress,EmailAddresses,RecipientTypeDetails  

$total = $recipients.Count
$counter = 0

foreach ($r in $recipients) {

    $counter++
    $percent = [int](($counter / $total) * 100)

    Write-Progress `
        -Activity "Scanning mail-enabled recipients" `
        -Status "Processing $counter of $total : $($r.DisplayName)" `
        -PercentComplete $percent

    $primary = $r.PrimarySmtpAddress.ToString()

    # Extract SMTP addresses and strip prefix
    $smtpAddresses = $r.EmailAddresses |
        Where-Object { $_ -like "smtp:*" } |
        ForEach-Object { $_.Substring(5) }

    # Secondary emails = all smtp except primary
    $secondary = $smtpAddresses | Where-Object { $_ -ne $primary }

    if ($primary -like "*$domain" -or ($secondary | Where-Object { $_ -like "*$domain" })) {

        $output += [PSCustomObject]@{
            DisplayName     = $r.DisplayName
            ObjectType      = $r.RecipientTypeDetails
            PrimaryEmail    = $primary
            SecondaryEmails = ($secondary -join ";")
        }
    }
}

Write-Progress -Activity "Scanning mail-enabled recipients" -Completed

$output | Export-Csv ".\pentaho_email_recipients.csv" -NoTypeInformation -Encoding UTF8

Write-Host "Export complete: pentaho_email_recipients.csv"