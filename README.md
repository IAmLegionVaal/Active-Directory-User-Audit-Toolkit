# Active Directory User Audit Toolkit

A read-only PowerShell toolkit for L1/L2 Active Directory user checks.

This project helps IT support teams collect safe AD user evidence for account lockout, disabled account, group membership, sign-in, expiry, and escalation scenarios.

## Features

- Search for an AD user by username, email, or display name
- Show account enabled/locked status
- Show account expiry information
- Show password age and password last set date
- Export direct group membership
- Export recent logon-related fields
- Export selected AD user attributes to CSV/JSON
- Generate a simple HTML report

## Requirements

- Windows PowerShell 5.1+
- RSAT Active Directory PowerShell module
- Domain connectivity
- Read permissions to Active Directory

## How to run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_User_Audit_Toolkit.ps1
```

Run directly for one user:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_User_Audit_Toolkit.ps1 -Identity jsmith
```

## Safety

This script is read-only. It does not unlock, enable, disable, reset, move, or modify AD accounts.

## Suggested topics

```text
powershell
active-directory
rsat
windows-server
it-support
helpdesk
sysadmin
identity
```
