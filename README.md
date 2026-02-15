# M365TenantMigration Module
The purpose of this module is to assist with migrating global tenant settings, devices, applications, roles, policies, and related configuration. This does NOT migrate users and groups.

See the beta\ folder for draft scripts relating to user and group export.

## Usage

### Export Tenant Configuration
```powershell
Import-Module .\M365TenantMigration
Export-M365TenantConfiguration -OutputPath ".\TenantExport"
````

### Import Tenant Configuration

```powershell
Import-Module .\M365TenantMigration
Import-M365TenantConfiguration -ImportPath ".\TenantExport"
```

### Notes

* Export uses Microsoft Graph interactive login by default.
* `-Scopes` parameter can be provided to override default scopes.
* Errors during export/import are output as warning messages to the console.
* Import does NOT attempt to check for existing objects; failed creations log a warning.
* Scripts were generated with AI assistance (based on strict specifications and implementation guidance). Be sure to verify results for accurancy and completeness.

---

## Required Permissions

### Export-M365TenantConfiguration

* Directory.Read.All
* Policy.Read.All
* RoleManagement.Read.Directory
* AuditLog.Read.All
* IdentityRiskyUser.Read.All
* Application.Read.All

### Import-M365TenantConfiguration

* Directory.ReadWrite.All
* Policy.ReadWrite.ConditionalAccess
* RoleManagement.ReadWrite.Directory
* Application.ReadWrite.All
* IdentityRiskyUser.ReadWrite.All

---

## Exported / Imported Tenant Settings by Category

### Organization Profile

* Tenant display name
* Verified domains
* Company branding

### Authentication & Identity

* Authentication methods policy:

  * FIDO2 security keys
  * Microsoft Authenticator
  * SMS / voice MFA
  * Temporary Access Pass
  * Certificate-Based Authentication
* Authorization policy
* Identity security defaults
* Self-service password reset (SSPR) policy
* Password protection (banned passwords, smart lockout)

### Conditional Access

* Conditional Access policies
* Named locations (IP ranges, countries)
* Authentication context definitions
* Terms of use
* Session controls

### Identity Protection

* User risk policies
* Sign-in risk policies
* Risky users

### Roles & PIM

* Directory roles
* Role assignments
* Custom roles
* Privileged Identity Management (PIM) policies

### Enterprise Applications

* Enterprise app consent policies
* Service principals
* App registrations
* Token configuration defaults
* Application proxy settings

### External Identities

* B2B collaboration settings
* Cross-tenant access policies
* External user lifecycle settings
* Guest invite restrictions

### Device Settings

* Device registration policies
* Azure AD join configuration
* Enterprise State Roaming
* Devices

### Identity Governance

* Access packages
* Access package assignment policies
* Lifecycle workflows
* Terms of use policies
* Entitlement management policies

### Audit & Monitoring

* Audit log configuration
* Directory audit logs
* Sign-in logs
* Diagnostic settings

---

Below is a structured tenant-scope view of **global Microsoft Entra ID configuration settings**, assuming **Entra ID P2** and using **built-in roles only**.

> Notes:
>
> * “MS Graph” includes v1.0 unless marked **(beta)**.
> * “API” refers to non-Graph programmatic endpoints (e.g., Azure AD Connect API, App Proxy API, ARM policy endpoints where applicable).
> * Minimum role reflects the least built-in role typically sufficient to *read* the setting.

---

### Global Entra ID Tenant Configuration

| Major Category            | Configurable Global Setting                                         | Minimum Role to Read                                | Programmatic Access |
| ------------------------- | ------------------------------------------------------------------- | --------------------------------------------------- | ------------------- |
| Identity & Authentication | Tenant display name & org profile                                   | Global Reader                                       | MS Graph            |
| Identity & Authentication | Verified domains & federation settings                              | Global Reader                                       | MS Graph            |
| Identity & Authentication | User consent settings                                               | Global Reader                                       | MS Graph            |
| Identity & Authentication | Admin consent workflow                                              | Global Reader                                       | MS Graph            |
| Identity & Authentication | Cross-tenant access settings                                        | Security Reader                                     | MS Graph            |
| Identity & Authentication | Authentication methods policy (FIDO2, Authenticator, SMS, TAP, CBA) | Authentication Policy Administrator / Global Reader | MS Graph            |
| Identity & Authentication | Password protection & smart lockout                                 | Security Reader                                     | MS Graph            |
| Identity & Authentication | Self-service password reset (SSPR) policy                           | Authentication Policy Administrator                 | MS Graph            |
| Identity & Authentication | Authentication strengths                                            | Security Reader                                     | MS Graph            |
| Identity & Authentication | Legacy authentication blocking                                      | Security Reader                                     | MS Graph            |
| Conditional Access        | Conditional Access policies                                         | Security Reader                                     | MS Graph            |
| Conditional Access        | Named locations                                                     | Security Reader                                     | MS Graph            |
| Conditional Access        | Authentication context definitions                                  | Security Reader                                     | MS Graph            |
| Conditional Access        | Terms of use                                                        | Security Reader                                     | MS Graph            |
| User & Group Settings     | Default user permissions                                            | Global Reader                                       | MS Graph            |
| User & Group Settings     | Guest user restrictions                                             | Global Reader                                       | MS Graph            |
| User & Group Settings     | Group naming policy                                                 | Groups Administrator / Global Reader                | MS Graph            |
| User & Group Settings     | Group expiration policy                                             | Groups Administrator                                | MS Graph            |
| User & Group Settings     | Administrative units                                                | Directory Reader                                    | MS Graph            |
| Roles & Privileged Access | Directory role definitions                                          | Global Reader                                       | MS Graph            |
| Roles & Privileged Access | Custom role definitions                                             | Global Reader                                       | MS Graph            |
| Roles & Privileged Access | PIM role settings & activation policies                             | Security Reader                                     | MS Graph (beta)     |
| Roles & Privileged Access | Access review policies                                              | Security Reader                                     | MS Graph            |
| Enterprise Applications   | Enterprise app consent policies                                     | Cloud Application Administrator / Global Reader     | MS Graph            |
| Enterprise Applications   | App proxy global settings                                           | Application Administrator                           | API                 |
| Enterprise Applications   | Token configuration defaults                                        | Application Administrator                           | MS Graph            |
| Security & Protection     | Identity Protection – user risk policy                              | Security Reader                                     | MS Graph            |
| Security & Protection     | Identity Protection – sign-in risk policy                           | Security Reader                                     | MS Graph            |
| Security & Protection     | Security defaults (on/off)                                          | Global Reader                                       | MS Graph            |
| Security & Protection     | Continuous Access Evaluation                                        | Security Reader                                     | MS Graph            |
| Audit & Monitoring        | Audit log retention settings                                        | Global Reader                                       | MS Graph            |
| Audit & Monitoring        | Diagnostic settings (log export config)                             | Global Reader                                       | MS Graph            |
| External Identities       | B2B collaboration settings                                          | Global Reader                                       | MS Graph            |
| External Identities       | Cross-tenant synchronization settings                               | Security Reader                                     | MS Graph (beta)     |
| Devices                   | Device settings (join/registration policy)                          | Global Reader                                       | MS Graph            |
| Devices                   | Enterprise State Roaming                                            | Global Reader                                       | MS Graph            |
| Identity Governance       | Entitlement management settings                                     | Identity Governance Administrator / Security Reader | MS Graph            |
| Identity Governance       | Access package policies                                             | Identity Governance Administrator                   | MS Graph            |
| Identity Governance       | Lifecycle workflows                                                 | Identity Governance Administrator                   | MS Graph (beta)     |
| Branding & UX             | Company branding                                                    | Global Reader                                       | MS Graph            |
| Organization Settings     | Privacy & technical contact info                                    | Global Reader                                       | MS Graph            |
| Synchronization           | Directory sync status (AAD Connect)                                 | Global Reader                                       | MS Graph            |
| Synchronization           | Cloud sync configuration                                            | Global Reader                                       | API                 |

