#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [Parameter(Mandatory)] [string]$Identity,
    [switch]$Unlock,
    [switch]$Enable,
    [switch]$ClearAccountExpiration,
    [switch]$RequirePasswordChange,
    [string]$OutputPath = "$env:USERPROFILE\Desktop\AD_User_Repair_Reports"
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory -ErrorAction Stop
if (-not ($Unlock -or $Enable -or $ClearAccountExpiration -or $RequirePasswordChange)) {
    throw 'Select at least one repair action.'
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runPath = Join-Path $OutputPath "Repair_$stamp"
New-Item -ItemType Directory -Path $runPath -Force | Out-Null
$log = Join-Path $runPath 'repair.log'

function Write-Log([string]$Message) {
    "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message | Tee-Object -FilePath $log -Append
}

$user = Get-ADUser -Identity $Identity -Properties Enabled,LockedOut,AccountExpirationDate,PasswordLastSet,DistinguishedName
$user | Select-Object SamAccountName,Enabled,LockedOut,AccountExpirationDate,PasswordLastSet,DistinguishedName |
    ConvertTo-Json | Set-Content (Join-Path $runPath 'before.json')

if ($Unlock -and $user.LockedOut -and $PSCmdlet.ShouldProcess($user.SamAccountName,'Unlock AD account')) {
    Unlock-ADAccount -Identity $user
    Write-Log "Unlocked $($user.SamAccountName)."
}
if ($Enable -and -not $user.Enabled -and $PSCmdlet.ShouldProcess($user.SamAccountName,'Enable AD account')) {
    Enable-ADAccount -Identity $user
    Write-Log "Enabled $($user.SamAccountName)."
}
if ($ClearAccountExpiration -and $user.AccountExpirationDate -and $PSCmdlet.ShouldProcess($user.SamAccountName,'Clear account expiration')) {
    Clear-ADAccountExpiration -Identity $user
    Write-Log "Cleared account expiration for $($user.SamAccountName)."
}
if ($RequirePasswordChange -and $PSCmdlet.ShouldProcess($user.SamAccountName,'Require password change at next sign-in')) {
    Set-ADUser -Identity $user -ChangePasswordAtLogon $true
    Write-Log "Password change at next sign-in enabled for $($user.SamAccountName)."
}

$after = Get-ADUser -Identity $Identity -Properties Enabled,LockedOut,AccountExpirationDate,PasswordLastSet,DistinguishedName
$after | Select-Object SamAccountName,Enabled,LockedOut,AccountExpirationDate,PasswordLastSet,DistinguishedName |
    ConvertTo-Json | Set-Content (Join-Path $runPath 'after.json')
Write-Log "Repair complete. Output: $runPath"

$failed = ($Unlock -and $after.LockedOut) -or ($Enable -and -not $after.Enabled) -or ($ClearAccountExpiration -and $after.AccountExpirationDate)
if ($failed) { exit 1 }
exit 0
