[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Identity,
    [switch]$UnlockAccount,
    [switch]$EnableAccount,
    [switch]$DisableAccount,
    [switch]$RequirePasswordChange,
    [switch]$ClearPasswordNeverExpires,
    [switch]$ClearAccountExpiration,
    [datetime]$SetAccountExpiration,
    [switch]$DryRun,
    [switch]$Yes,
    [string]$LogDirectory="$env:ProgramData\IAmLegionVaal\ADUserRepair"
)

$ErrorActionPreference='Stop'
$ExitInvalidInput=2; $ExitPrerequisite=3; $ExitCancelled=4; $ExitActionFailure=5; $ExitVerificationFailure=6
function Test-Admin {$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Write-Log([string]$Message){$line="{0:u} {1}" -f (Get-Date),$Message;Write-Host $line;Add-Content -LiteralPath $script:LogPath -Value $line}
function Invoke-Step([string]$Description,[scriptblock]$Action){if($DryRun){Write-Log "[DRY-RUN] $Description"}else{Write-Log "[ACTION] $Description";& $Action}}

$hasExpiration=$PSBoundParameters.ContainsKey('SetAccountExpiration')
if(-not($UnlockAccount -or $EnableAccount -or $DisableAccount -or $RequirePasswordChange -or $ClearPasswordNeverExpires -or $ClearAccountExpiration -or $hasExpiration)){Write-Error 'Select at least one repair action.';exit $ExitInvalidInput}
if($EnableAccount -and $DisableAccount){Write-Error 'Choose either -EnableAccount or -DisableAccount, not both.';exit $ExitInvalidInput}
if($ClearAccountExpiration -and $hasExpiration){Write-Error 'Choose either -ClearAccountExpiration or -SetAccountExpiration.';exit $ExitInvalidInput}
if($hasExpiration -and $SetAccountExpiration -le (Get-Date)){Write-Error '-SetAccountExpiration must be a future date.';exit $ExitInvalidInput}
if(-not(Test-Admin)){Write-Error 'Run from an elevated PowerShell session.';exit $ExitPrerequisite}
try{Import-Module ActiveDirectory -ErrorAction Stop}catch{Write-Error "ActiveDirectory module unavailable: $($_.Exception.Message)";exit $ExitPrerequisite}

New-Item -ItemType Directory -Path $LogDirectory -Force|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss';$script:LogPath=Join-Path $LogDirectory "ADUserRepair_$stamp.log";$backupPath=Join-Path $LogDirectory "ADUser_$stamp.json"
try{$user=Get-ADUser -Identity $Identity -Properties Enabled,LockedOut,AdminCount,PasswordNeverExpires,AccountExpirationDate,PasswordLastSet,DistinguishedName}
catch{Write-Error "Unable to resolve user '$Identity': $($_.Exception.Message)";exit $ExitInvalidInput}
if($user.AdminCount -eq 1){Write-Error 'Protected administrative users are excluded from automated repair.';exit $ExitInvalidInput}
if($DisableAccount -and $user.SamAccountName -ieq $env:USERNAME){Write-Error 'The current signed-in account cannot be disabled by this tool.';exit $ExitInvalidInput}
$user|Select-Object SamAccountName,Enabled,LockedOut,AdminCount,PasswordNeverExpires,AccountExpirationDate,PasswordLastSet,DistinguishedName|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $backupPath -Encoding UTF8
Write-Log "Saved pre-change user evidence to $backupPath"

$actions=@();foreach($pair in @(@($UnlockAccount,'unlock'),@($EnableAccount,'enable'),@($DisableAccount,'disable'),@($RequirePasswordChange,'require password change'),@($ClearPasswordNeverExpires,'clear password-never-expires'),@($ClearAccountExpiration,'clear account expiration'),@($hasExpiration,"set expiration to $SetAccountExpiration"))){if($pair[0]){$actions+=$pair[1]}}
if(-not $DryRun -and -not $Yes){$answer=Read-Host ("Proceed for {0}: {1}? [y/N]" -f $Identity,($actions -join '; '));if($answer -notmatch '^(?i)y(es)?$'){Write-Log '[CANCELLED] No changes were made.';exit $ExitCancelled}}

try{
    if($UnlockAccount){Invoke-Step "Unlock '$Identity'" {Unlock-ADAccount -Identity $user.DistinguishedName}}
    if($EnableAccount){Invoke-Step "Enable '$Identity'" {Enable-ADAccount -Identity $user.DistinguishedName}}
    if($DisableAccount){Invoke-Step "Disable '$Identity'" {Disable-ADAccount -Identity $user.DistinguishedName}}
    if($RequirePasswordChange){Invoke-Step "Require password change for '$Identity'" {Set-ADUser -Identity $user.DistinguishedName -ChangePasswordAtLogon $true}}
    if($ClearPasswordNeverExpires){Invoke-Step "Clear password-never-expires for '$Identity'" {Set-ADUser -Identity $user.DistinguishedName -PasswordNeverExpires $false}}
    if($ClearAccountExpiration){Invoke-Step "Clear account expiration for '$Identity'" {Clear-ADAccountExpiration -Identity $user.DistinguishedName}}
    if($hasExpiration){Invoke-Step "Set account expiration for '$Identity' to $SetAccountExpiration" {Set-ADAccountExpiration -Identity $user.DistinguishedName -DateTime $SetAccountExpiration}}
}catch{Write-Log "[FAILED] $($_.Exception.Message)";exit $ExitActionFailure}
if($DryRun){Write-Log '[COMPLETE] Dry-run completed.';exit 0}

$verifyFailed=$false
try{$after=Get-ADUser -Identity $user.DistinguishedName -Properties Enabled,LockedOut,PasswordNeverExpires,AccountExpirationDate;Write-Log ("[VERIFY] Enabled={0}; LockedOut={1}; PasswordNeverExpires={2}; Expiration={3}" -f $after.Enabled,$after.LockedOut,$after.PasswordNeverExpires,$after.AccountExpirationDate);if($UnlockAccount -and $after.LockedOut){$verifyFailed=$true};if($EnableAccount -and -not $after.Enabled){$verifyFailed=$true};if($DisableAccount -and $after.Enabled){$verifyFailed=$true};if($ClearPasswordNeverExpires -and $after.PasswordNeverExpires){$verifyFailed=$true};if($ClearAccountExpiration -and $after.AccountExpirationDate){$verifyFailed=$true}}
catch{Write-Log "[VERIFY-FAILED] $($_.Exception.Message)";$verifyFailed=$true}
if($verifyFailed){exit $ExitVerificationFailure}
Write-Log '[COMPLETE] Requested repairs completed and verification passed.'
exit 0
