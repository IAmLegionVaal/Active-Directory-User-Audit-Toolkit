# Active Directory User Audit Toolkit

A PowerShell toolkit for L1/L2 Active Directory user checks and selected guarded account repairs.

## Audit

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_User_Audit_Toolkit.ps1 -Identity jsmith
```

## Repair

Preview a change:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_User_Repair_Toolkit.ps1 -Identity jsmith -UnlockAccount -DryRun
```

Examples:

```powershell
.\AD_User_Repair_Toolkit.ps1 -Identity jsmith -UnlockAccount
.\AD_User_Repair_Toolkit.ps1 -Identity jsmith -EnableAccount
.\AD_User_Repair_Toolkit.ps1 -Identity jsmith -RequirePasswordChange -ClearPasswordNeverExpires
.\AD_User_Repair_Toolkit.ps1 -Identity contractor1 -SetAccountExpiration '2026-12-31'
.\AD_User_Repair_Toolkit.ps1 -Identity contractor1 -ClearAccountExpiration
```

## Repair behavior

- Requires an elevated Windows PowerShell session and the RSAT Active Directory module.
- Saves a JSON snapshot of the selected user before any modification.
- Supports explicit unlock, enable, disable, password-change-at-next-logon, password-expiry and account-expiration actions.
- Refuses protected administrative users and refuses to disable the current signed-in account.
- Supports `-DryRun`, confirmation or `-Yes`, timestamped action logs and post-change verification.
- Returns `0` for success, `2` for invalid input, `3` for missing privileges or prerequisites, `4` for cancellation, `5` for action failure and `6` for verification failure.

## Safety

The repair script modifies only the explicitly selected user. It does not reset passwords, change group membership, move or delete accounts, or apply bulk changes from the audit report.

## Author

Dewald Pretorius — L2 IT Support Engineer
