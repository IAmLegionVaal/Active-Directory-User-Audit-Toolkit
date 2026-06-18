#requires -Version 5.1
<#
.SYNOPSIS
    Active Directory User Audit Toolkit.
.DESCRIPTION
    Read-only AD user evidence collector for helpdesk and L1/L2 escalation.
#>
[CmdletBinding()]
param([string]$Identity,[string]$OutputPath)

$RunStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AD_User_Audit_Reports' }
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

function Write-Info { param([string]$Message) Write-Host $Message -ForegroundColor Cyan }
function Export-Report { param([string]$Name,[object]$Data) $Data | Export-Csv (Join-Path $OutputPath "$Name.csv") -NoTypeInformation -Encoding UTF8; $Data | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $OutputPath "$Name.json") -Encoding UTF8 }

try { Import-Module ActiveDirectory -ErrorAction Stop } catch { Write-Error 'ActiveDirectory module not found. Install RSAT Active Directory tools and retry.'; return }

if ([string]::IsNullOrWhiteSpace($Identity)) { $Identity = Read-Host 'Enter username, email, or display name' }
if ([string]::IsNullOrWhiteSpace($Identity)) { Write-Warning 'No identity entered.'; return }

Write-Info "Searching Active Directory for: $Identity"
$filter = "SamAccountName -like '*$Identity*' -or UserPrincipalName -like '*$Identity*' -or mail -like '*$Identity*' -or DisplayName -like '*$Identity*'"
$users = Get-ADUser -Filter $filter -Properties DisplayName,Mail,Enabled,LockedOut,PasswordLastSet,PasswordExpired,PasswordNeverExpires,AccountExpirationDate,LastLogonDate,Department,Title,Manager,CanonicalName,Created,Modified,UserPrincipalName

if (-not $users) { Write-Warning 'No matching AD user found.'; return }
if (@($users).Count -gt 1) { $users | Select-Object SamAccountName,DisplayName,Mail,Enabled,LockedOut | Format-Table -AutoSize; $sam = Read-Host 'Multiple matches found. Enter exact SamAccountName'; $user = Get-ADUser -Identity $sam -Properties * } else { $user = $users | Select-Object -First 1 }

$summary = [PSCustomObject]@{
    SamAccountName = $user.SamAccountName
    DisplayName = $user.DisplayName
    UserPrincipalName = $user.UserPrincipalName
    Mail = $user.Mail
    Enabled = $user.Enabled
    LockedOut = $user.LockedOut
    PasswordLastSet = $user.PasswordLastSet
    PasswordExpired = $user.PasswordExpired
    PasswordNeverExpires = $user.PasswordNeverExpires
    AccountExpirationDate = $user.AccountExpirationDate
    LastLogonDate = $user.LastLogonDate
    Department = $user.Department
    Title = $user.Title
    Manager = $user.Manager
    Created = $user.Created
    Modified = $user.Modified
    CanonicalName = $user.CanonicalName
}

$groups = Get-ADPrincipalGroupMembership -Identity $user.SamAccountName | Sort-Object Name | Select-Object Name,GroupCategory,GroupScope,DistinguishedName
$summary | Format-List
$groups | Format-Table Name,GroupCategory,GroupScope -AutoSize

$baseName = "$($user.SamAccountName)_$RunStamp"
Export-Report -Name "$baseName`_summary" -Data @($summary)
Export-Report -Name "$baseName`_groups" -Data $groups

$htmlPath = Join-Path $OutputPath "$baseName`_report.html"
@($summary) | ConvertTo-Html -Title "AD User Audit - $($user.SamAccountName)" -PreContent "<h1>AD User Audit - $($user.SamAccountName)</h1><p>Generated $(Get-Date)</p>" -PostContent "<h2>Direct Group Membership</h2>$($groups | ConvertTo-Html -Fragment)" | Set-Content $htmlPath -Encoding UTF8
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
Start-Process explorer.exe -ArgumentList "`"$OutputPath`"" -ErrorAction SilentlyContinue
