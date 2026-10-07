# Onboarding de usuarios

Script que automatiza el alta de empleados a partir de un CSV: genera usuario y UPN únicos, contraseña temporal aleatoria, grupos por departamento y asignación de licencia.

## Modos

| Modo | Comando | Efecto |
|---|---|---|
| Simulación (default) | `.\Invoke-Onboarding.ps1 -CsvPath .\empleados.ejemplo.csv` | No modifica nada, genera reporte |
| WhatIf | `... -WhatIf` | Muestra qué haría |
| Live | `... -ConfigPath .\config.json -Live` | Crea usuarios en AD y asigna licencias en M365 |

## Archivos

- `Invoke-Onboarding.ps1`: script principal
- `config.example.json`: copia como `config.json` y ajusta dominio, OU, grupos y SKUs (`config.json` está en `.gitignore`)
- `empleados.ejemplo.csv`: datos ficticios de ejemplo

## Requisitos (solo modo Live)

- PowerShell 5.1+
- Módulo `ActiveDirectory` (RSAT)
- Módulo `Microsoft.Graph.Users.Actions` con permiso `User.ReadWrite.All`

## Seguridad

- La contraseña se genera como `SecureString` y **nunca** se guarda en logs.
- Los reportes se escriben en `logs/` (agrégalo a `.gitignore`).