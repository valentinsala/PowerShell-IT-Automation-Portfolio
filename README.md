<div align="center">

# 🛠️ PowerShell IT Automation Portfolio

### Automatización real para entornos de TI: Active Directory · Microsoft 365 · Monitoreo · Inventario

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Microsoft 365](https://img.shields.io/badge/Microsoft%20365-Graph%20API-D83B01?style=for-the-badge&logo=microsoft&logoColor=white)](https://learn.microsoft.com/graph/)
[![Active Directory](https://img.shields.io/badge/Active%20Directory-On--Prem-003366?style=for-the-badge&logo=microsoftazure&logoColor=white)](https://learn.microsoft.com/windows-server/identity/ad-ds/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=for-the-badge)](https://github.com/)

<br>

> 💡 **"No se trata de escribir scripts. Se trata de resolver problemas reales de TI con automatización, seguridad y buenas prácticas."**

</div>

---

## 👋 Sobre este portafolio

Hola, soy **SysAdmin / IT Automation Engineer** apasionado por simplificar el trabajo diario mediante **PowerShell**.

Este repositorio reúne una colección de **scripts y herramientas** que desarrollé para resolver problemas comunes en entornos corporativos: altas masivas de usuarios, bajas seguras, auditoría de Active Directory, monitoreo de servidores e inventario de equipos.

Cada proyecto está pensado como una **solución completa**, no como un script suelto:

- ✅ Documentado
- ✅ Con manejo de errores
- ✅ Con soporte `-WhatIf` / `-Confirm`
- ✅ Sin credenciales hardcodeadas
- ✅ Con ejemplos de uso y datos ficticios

---

## 📦 Proyectos incluidos

| # | Proyecto | Descripción | Tecnologías |
|:-:|:---------|:------------|:------------|
| 1️⃣ | [**Onboarding masivo**](./Onboarding/) | Alta automática de usuarios en AD desde CSV, asignación de grupos y licencias M365. | `AD` · `Graph` · `CSV` |
| 2️⃣ | [**Offboarding seguro**](./Offboarding/) | Bloqueo de cuenta, revocación de sesiones, retiro de licencias y reenvío de correo. | `AD` · `Exchange` · `Graph` |
| 3️⃣ | [**Caza de usuarios fantasma**](./GhostUsers/) | Detecta cuentas inactivas +45/60 días, genera reporte y las desactiva. | `AD` · `Reporting` |
| 4️⃣ | [**Alerta de disco crítico**](./DiskMonitoring/) | Monitorea espacio libre en servidores y envía alerta por correo si baja del 10%. | `CIM` · `SMTP` · `Graph` |
| 5️⃣ | [**Inventario de equipos**](./Inventory/) | Extrae nombre, IP, serial, marca y versión de Windows. Exporta a Excel. | `CIM` · `ImportExcel` |

---

## 🚀 ¿Por qué estos scripts importan?

No es solo "saber PowerShell". Es demostrar que entiendo el **valor del negocio detrás de cada línea de código**.

<table>
<tr>
<th align="left">🎯 Área</th>
<th align="left">Lo que demuestro</th>
</tr>
<tr>
<td><b>Eficiencia</b></td>
<td>Lo que antes tomaba 50 clics y 1 hora, ahora toma 10 segundos.</td>
</tr>
<tr>
<td><b>Seguridad</b></td>
<td>Offboarding sin cabos sueltos: sesiones revocadas, cuentas bloqueadas, correos redirigidos.</td>
</tr>
<tr>
<td><b>Ahorro de costos</b></td>
<td>Retiro automático de licencias M365 de exempleados.</td>
</tr>
<tr>
<td><b>Proactividad</b></td>
<td>Alertas antes de que un servidor colapse. Prevenir > apagar incendios.</td>
</tr>
<tr>
<td><b>Auditoría</b></td>
<td>Detección de cuentas huérfanas, cerrando puertas a posibles atacantes.</td>
</tr>
<tr>
<td><b>Gestión de activos</b></td>
<td>Inventario automatizado, sin libreta ni visita escritorio por escritorio.</td>
</tr>
</table>

---

## 🧰 Stack técnico

<div align="center">

| Categoría | Herramientas |
|:----------|:-------------|
| **Lenguaje** | ![PowerShell](https://img.shields.io/badge/-PowerShell%207%2B-5391FE?logo=powershell&logoColor=white&style=flat-square) |
| **Identidad** | ![AD DS](https://img.shields.io/badge/-Active%20Directory-003366?style=flat-square) ![Entra ID](https://img.shields.io/badge/-Entra%20ID-0078D4?style=flat-square) |
| **Nube** | ![Microsoft Graph](https://img.shields.io/badge/-Microsoft%20Graph-D83B01?style=flat-square) ![Exchange Online](https://img.shields.io/badge/-Exchange%20Online-0078D4?style=flat-square) |
| **Módulos** | `ActiveDirectory` · `ExchangeOnlineManagement` · `Microsoft.Graph` · `ImportExcel` · `Pester` |
| **Calidad** | `PSScriptAnalyzer` · `Pester` · `GitHub Actions` |

</div>

---

## 📁 Estructura del repositorio

```text
PowerShell-IT-Automation-Portfolio/
├── 📄 README.md
├── 📄 LICENSE
├── 📄 .gitignore
├── 📄 PSScriptAnalyzerSettings.psd1
│
├── 📂 Onboarding/
│   ├── README.md
│   ├── Invoke-Onboarding.ps1
│   ├── config.example.json
│   └── empleados.ejemplo.csv
│
├── 📂 Offboarding/
│   ├── README.md
│   └── Invoke-Offboarding.ps1
│
├── 📂 GhostUsers/
│   ├── README.md
│   └── Find-GhostUsers.ps1
│
├── 📂 DiskMonitoring/
│   ├── README.md
│   └── Test-DiskSpace.ps1
│
└── 📂 Inventory/
    ├── README.md
    └── Get-PCInventory.ps1
