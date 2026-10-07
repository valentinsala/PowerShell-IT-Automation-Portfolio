# 🚀 Invoke-Onboarding.ps1 — Guía completa de instalación, uso y despliegue

Script de PowerShell para el **alta automatizada de usuarios en Active Directory** desde un archivo CSV. Esta guía cubre desde cero: creación del laboratorio, estructura en AD, el script, cómo ejecutarlo, cómo adaptarlo a cualquier entorno y cómo resolver problemas.

---

## 📋 Tabla de contenidos

1. [¿Qué hace el script?](#1--qué-hace-el-script)
2. [Características principales](#2--características-principales)
3. [Requisitos](#3--requisitos)
4. [Preparación del laboratorio (Hyper-V)](#4--preparación-del-laboratorio-hyper-v)
5. [Preparación de Active Directory](#5--preparación-de-active-directory)
6. [Preparación del entorno del script](#6--preparación-del-entorno-del-script)
7. [Formato del CSV](#7--formato-del-csv)
8. [Uso del script](#8--uso-del-script)
9. [Ejemplos](#9--ejemplos)
10. [Cómo funciona por dentro](#10--cómo-funciona-por-dentro)
11. [Estructura de salida](#11--estructura-de-salida)
12. [Verificación post-ejecución](#12--verificación-post-ejecución)
13. [Adaptación a cualquier entorno](#13--adaptación-a-cualquier-entorno)
14. [Solución de problemas](#14--solución-de-problemas)
15. [Seguridad](#15--seguridad)
16. [Licencia y autor](#16--licencia-y-autor)

---

## 1. 🎯 ¿Qué hace el script?

Lee un archivo CSV con datos de empleados y **crea automáticamente las cuentas en Active Directory**, asignándolos a los grupos que correspondan según su departamento.

**En lugar de dar de alta 3 empleados a mano (10 minutos), corres este script y se crean en 3 segundos.** Con 50 empleados, la diferencia es abismal.

### Flujo simplificado

```text
CSV de empleados  →  Script  →  Usuarios creados en AD
                               ├─ Nombre + Apellido
                               ├─ SamAccountName único
                               ├─ UPN + Email
                               ├─ Contraseña temporal
                               └─ Miembros de sus grupos
```

---

## 2. ✨ Características principales

| Característica | Descripción |
|:---------------|:------------|
| **Modo simulación** | `-WhatIf` muestra lo que haría sin tocar AD |
| **Idempotente** | Ejecutar 2 veces no rompe nada; los usuarios existentes se saltan |
| **Logging completo** | `Start-Transcript` guarda todo en un `.log` |
| **Reporte CSV** | Cada alta queda registrada con estado y detalle |
| **Contraseñas seguras** | Si el CSV no trae `Password`, se genera una aleatoria criptográficamente segura |
| **Validación previa** | Verifica campos obligatorios y formato de `Usuario` antes de crear |
| **Verificación de OU** | Si la OU no existe, no intenta crear el usuario |
| **Manejo de errores por fila** | Si un usuario falla, los demás siguen procesándose |
| **Manejo de errores por grupo** | Si un grupo no existe, el usuario se crea igual y queda marcado con aviso |
| **Compatible con PowerShell 5.1 y 7+** | Funciona en Windows Server 2016/2019/2022/2025 y Windows 10/11 |

---

## 3. 🧰 Requisitos

### Sistema operativo

- **Windows Server 2016 o superior** con rol **AD DS** instalado (o RSAT-AD-PowerShell)
- **Windows 10/11 Pro/Enterprise** con RSAT instalado (para administración remota)

### Módulos PowerShell

- **ActiveDirectory** (`RSAT-AD-PowerShell`)
  - En Windows Server: viene con el rol AD DS
  - En Windows 10/11: instalar RSAT

### Permisos

- Cuenta con permisos para crear usuarios en la OU destino
- **Recomendado:** miembro de `Domain Admins` o delegación específica sobre la OU

### Prerequisitos del dominio

- Un **dominio de Active Directory funcional**
- La **OU destino** creada
- Los **grupos destino** creados

---

## 4. 🖥️ Preparación del laboratorio (Hyper-V)

> Si ya tienes tu VM con Windows Server y tu dominio, salta a la sección 5.

### 4.1 Crear la VM

- **Generación:** 2
- **Memoria:** 4096 MB
- **Disco:** 60 GB
- **Red:** Default Switch o externo

### 4.2 Instalar Windows Server

Instala Windows Server con **experiencia de escritorio** y configura:

- **Nombre del equipo:** `SRV-DC01`
- **IP fija:**

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 192.168.1.10 -PrefixLength 24 -DefaultGateway 192.168.1.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 127.0.0.1
```

### 4.3 Promover a Domain Controller

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

$pass = ConvertTo-SecureString "P@ssw0rd2024!" -AsPlainText -Force
Install-ADDSForest `
    -DomainName "empresa.com" `
    -DomainNetbiosName "EMPRESA" `
    -InstallDns `
    -SafeModeAdministratorPassword $pass `
    -Force
```

La VM se reinicia sola. Entra como `EMPRESA\Administrator`.

Verifica:

```powershell
Get-ADDomain | Select Name, DNSRoot, NetBIOSName
Get-Service NTDS, DNS | Select Name, Status
```

---

## 5. 🗂️ Preparación de Active Directory

### 5.1 Crear la OU de usuarios

```powershell
New-ADOrganizationalUnit -Name "Usuarios" -Path "DC=empresa,DC=com" -ProtectedFromAccidentalDeletion $true
```

### 5.2 Crear los grupos base y por departamento

```powershell
$grupos = @(
    "GG_Todos_Empleados","GG_VPN_Usuarios",
    "GG_TI","GG_Admin_Remoto",
    "GG_Ventas","GG_CRM",
    "GG_Finanzas","GG_RRHH",
    "GG_Soporte","GG_Helpdesk"
)
foreach ($g in $grupos) {
    New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path "OU=Usuarios,DC=empresa,DC=com"
}
Write-Host "OU + $($grupos.Count) grupos creados" -ForegroundColor Green
```

### 5.3 Verificar

```powershell
Get-ADOrganizationalUnit -Filter 'Name -eq "Usuarios"' | Select DistinguishedName
(Get-ADGroup -Filter 'Name -like "GG_*"').Count
```

Debe dar **10**.

---

## 6. 📦 Preparación del entorno del script

### 6.1 Crear carpetas

```powershell
New-Item -ItemType Directory -Path C:\Scripts -Force | Out-Null
New-Item -ItemType Directory -Path C:\Scripts\logs -Force | Out-Null
```

### 6.2 Habilitar ejecución de scripts

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

### 6.3 Instalar el módulo AD (si no está)

**En Windows Server:**

```powershell
Install-WindowsFeature RSAT-AD-PowerShell
```

**En Windows 10/11:**

```powershell
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

### 6.4 Desbloquear el script si lo bajaste de internet

```powershell
Unblock-File C:\Scripts\Invoke-Onboarding.ps1
```

### 6.5 Verificar

```powershell
Import-Module ActiveDirectory
Get-ADDomain
```

Si responde con la info del dominio, todo está listo.

### 6.6 Guardar el script

Guarda el contenido del script como `C:\Scripts\Invoke-Onboarding.ps1`.

Para crearlo desde PowerShell sin problemas de portapapeles:

```powershell
notepad C:\Scripts\Invoke-Onboarding.ps1
```

Y pega el contenido. Guarda con `Ctrl+S`.

---

## 7. 📄 Formato del CSV

### Columnas obligatorias

| Columna | Descripción | Ejemplo |
|:--------|:------------|:--------|
| `Nombre` | Nombre de pila | `Juan` |
| `Apellido` | Apellido(s) | `Perez` |
| `Usuario` | SamAccountName (3-20 caracteres, solo `a-z A-Z 0-9 . _ -`) | `jperez` |
| `OU` | Distinguished Name de la OU destino | `OU=Usuarios,DC=empresa,DC=com` |

### Columnas opcionales

| Columna | Descripción | Si se omite |
|:--------|:------------|:------------|
| `Password` | Contraseña temporal | Se genera una aleatoria de 16 caracteres |
| `Departamento` | Departamento (informativo en el reporte) | Queda vacío en el log |
| `Grupos` | Grupos separados por `;` | No se asigna ningún grupo extra |

### Ejemplo mínimo

```csv
Nombre,Apellido,Usuario,OU
Juan,Perez,jperez,"OU=Usuarios,DC=empresa,DC=com"
Maria,Lopez,mlopez,"OU=Usuarios,DC=empresa,DC=com"
```

### Ejemplo completo

```csv
Nombre,Apellido,Usuario,Password,Departamento,OU,Grupos
Juan,Perez,jperez,P@ssw0rd2024!,TI,"OU=Usuarios,DC=empresa,DC=com",GG_TI;GG_Todos_Empleados
Maria,Lopez,mlopez,P@ssw0rd2024!,Ventas,"OU=Usuarios,DC=empresa,DC=com",GG_Ventas;GG_Todos_Empleados
Carlos,Ramirez,cramirez,P@ssw0rd2024!,Finanzas,"OU=Usuarios,DC=empresa,DC=com",GG_Finanzas;GG_Todos_Empleados
```

### Crear el CSV desde PowerShell (evita problemas de encoding)

```powershell
$data = @(
    [pscustomobject]@{Nombre='Juan';Apellido='Perez';Usuario='jperez';Password='P@ssw0rd2024!';Departamento='TI';OU='OU=Usuarios,DC=empresa,DC=com';Grupos='GG_TI;GG_Todos_Empleados'}
    [pscustomobject]@{Nombre='Maria';Apellido='Lopez';Usuario='mlopez';Password='P@ssw0rd2024!';Departamento='Ventas';OU='OU=Usuarios,DC=empresa,DC=com';Grupos='GG_Ventas;GG_Todos_Empleados'}
    [pscustomobject]@{Nombre='Carlos';Apellido='Ramirez';Usuario='cramirez';Password='P@ssw0rd2024!';Departamento='Finanzas';OU='OU=Usuarios,DC=empresa,DC=com';Grupos='GG_Finanzas;GG_Todos_Empleados'}
)
$data | Export-Csv -Path C:\Scripts\empleados.ejemplo.csv -NoTypeInformation -Encoding UTF8
Get-Content C:\Scripts\empleados.ejemplo.csv
```

### ⚠️ Notas sobre encoding

- Guarda el CSV como **UTF-8 con BOM** para que Excel y PowerShell respeten acentos.
- Si usas Excel, al guardar elige **"CSV UTF-8 (delimitado por comas)"**.
- Las comillas dobles alrededor de la OU son obligatorias porque contiene comas.

---

## 8. 🚀 Uso del script

### Sintaxis

```powershell
.\Invoke-Onboarding.ps1 -CsvPath <ruta> [-DominioUPN <dominio>] [-LogPath <carpeta>] [-PasswordLength <n>] [-WhatIf] [-Verbose]
```

### Parámetros

| Parámetro | Tipo | Obligatorio | Default | Descripción |
|:----------|:-----|:-----------:|:--------|:------------|
| `-CsvPath` | String | ✅ | — | Ruta del archivo CSV |
| `-DominioUPN` | String | ❌ | `empresa.com` | Sufijo UPN para el correo y login |
| `-LogPath` | String | ❌ | `<script>\logs` | Carpeta donde se guardan reportes |
| `-PasswordLength` | Int (12-32) | ❌ | `16` | Longitud de contraseñas auto-generadas |
| `-WhatIf` | Switch | ❌ | — | Simula sin crear usuarios |
| `-Verbose` | Switch | ❌ | — | Muestra cada acción paso a paso |
| `-Confirm` | Switch | ❌ | — | Pide confirmación por cada usuario |

### Flujo recomendado

1. Correr siempre `-WhatIf` primero para validar el CSV.
2. Correr real con `-Verbose`.
3. Revisar el reporte y el CSV de credenciales.
4. Verificar los usuarios en AD.
5. Borrar el CSV de credenciales.

---

## 9. 💡 Ejemplos

### 1. Simulación (siempre haz esto primero)

```powershell
.\Invoke-Onboarding.ps1 -CsvPath .\empleados.ejemplo.csv -WhatIf -Verbose
```

Muestra lo que **haría** sin tocar AD. Ideal para validar el CSV antes de ejecutar de verdad.

### 2. Ejecución real

```powershell
.\Invoke-Onboarding.ps1 -CsvPath .\empleados.ejemplo.csv -Verbose
```

### 3. Con dominio personalizado

```powershell
.\Invoke-Onboarding.ps1 -CsvPath .\empleados.csv -DominioUPN "miempresa.local"
```

### 4. Con logs en carpeta específica

```powershell
.\Invoke-Onboarding.ps1 -CsvPath .\empleados.csv -LogPath "D:\Reports\Onboarding"
```

### 5. Con confirmación interactiva

```powershell
.\Invoke-Onboarding.ps1 -CsvPath .\empleados.csv -Confirm
```

Pregunta `¿Crear usuario jperez? [S/N/A]` por cada usuario.

### 6. Contraseñas más largas

```powershell
.\Invoke-Onboarding.ps1 -CsvPath .\empleados.csv -PasswordLength 24
```

---

## 10. 🔍 Cómo funciona por dentro

### Fase 1 — Carga y validación

1. Importa el módulo `ActiveDirectory`.
2. Crea la carpeta de logs si no existe.
3. Inicia un `Start-Transcript` para capturar toda la sesión.
4. Carga el CSV con `Import-Csv`.
5. Valida que existan las columnas obligatorias en la primera fila.

### Fase 2 — Procesamiento por fila

Para cada usuario del CSV:

1. **Validación** (`Test-InputRow`): verifica que `Nombre`, `Apellido`, `Usuario` y `OU` tengan datos, y que `Usuario` cumpla el patrón `^[a-zA-Z0-9._-]{3,20}$`.
2. **Idempotencia**: consulta `Get-ADUser` con el SamAccountName. Si ya existe, salta la fila.
3. **Verificación de OU**: consulta `Get-ADOrganizationalUnit`. Si no existe, lanza error y salta.
4. **Generación de contraseña**:
   - Si el CSV trae `Password`, la usa tal cual.
   - Si no, genera una aleatoria con `New-RandomPassword` usando `RandomNumberGenerator` (criptográficamente segura).
5. **`ShouldProcess`**: si pasaste `-WhatIf`, aquí es donde se detiene y simula.
6. **Creación del usuario**: `New-ADUser` con todos los atributos.
7. **Asignación de grupos**: por cada grupo en `Grupos` (separado por `;`), hace `Add-ADGroupMember`. Si uno falla, lo acumula en `$gruposFallidos` y sigue con el resto.
8. **Captura de resultado**: agrega un `PSCustomObject` a `$results` con el estado final.

### Fase 3 — Reportes

1. **Reporte principal** (`onboarding_<fecha>.csv`): una fila por usuario con columnas `Nombre, Usuario, UPN, Departamento, Estado, Detalle, Fecha`.
2. **Reporte de contraseñas** (`CREDENCIALES_<fecha>.csv`): solo si se generaron contraseñas aleatorias.
3. **Transcript** (`onboarding_<fecha>.log`): el log completo de la sesión.
4. **Resumen en consola**: contadores por estado.

### Estados posibles

| Estado | Significado |
|:-------|:------------|
| `Creado` | Usuario creado y grupos asignados correctamente |
| `Creado con avisos` | Usuario creado pero algún grupo no se pudo asignar |
| `Ya existia` | SamAccountName duplicado, no se tocó |
| `Omitido (WhatIf)` | Se ejecutó en modo simulación |
| `Error` | Falló la creación (OU no existe, permisos, etc.) |

---

## 11. 📂 Estructura de salida

Después de cada ejecución, la carpeta `logs/` contiene:

```text
logs/
├── onboarding_20260115_143022.log          ← transcript completo de la sesión
├── onboarding_20260115_143022.csv          ← reporte por usuario
└── CREDENCIALES_20260115_143022.csv        ← passwords generadas (solo si aplica)
```

### Ejemplo de `onboarding_*.csv`

```csv
"Nombre","Usuario","UPN","Departamento","Estado","Detalle","Fecha"
"Juan Perez","jperez","jperez@empresa.com","TI","Creado","OK","2026-01-15T14:30:25"
"Maria Lopez","mlopez","mlopez@empresa.com","Ventas","Creado","OK","2026-01-15T14:30:26"
```

### Ejemplo de `CREDENCIALES_*.csv`

```csv
"Usuario","Password"
"jperez","Kj8#mPq2xVn5Rw9z"
"mlopez","Ht4$bNc7yLm1Qs6p"
```

> ⚠️ **Guarda el archivo de credenciales en un lugar seguro.** Bórralo cuando ya las hayas entregado a los usuarios.

---

## 12. ✅ Verificación post-ejecución

Copia y pega este bloque para verificar todo de una vez:

```powershell
Write-Host "`n=== USUARIOS CREADOS ===" -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase "OU=Usuarios,DC=empresa,DC=com" |
    Select Name, SamAccountName, Enabled | Format-Table -AutoSize

Write-Host "`n=== GRUPOS DE jperez ===" -ForegroundColor Cyan
Get-ADPrincipalGroupMembership jperez -ErrorAction SilentlyContinue | Select Name

Write-Host "`n=== DEBE CAMBIAR PASSWORD ===" -ForegroundColor Cyan
Get-ADUser jperez -Properties pwdLastSet |
    Select Name, @{n='DebeCambiar';e={$_.pwdLastSet -eq 0}}

Write-Host "`n=== ARCHIVOS GENERADOS ===" -ForegroundColor Cyan
Get-ChildItem C:\Scripts\logs\ | Select Name, Length | Sort LastWriteTime -Desc
```

### Prueba de idempotencia

Corre el script otra vez. Debe mostrar `Ya existian: N` sin errores.

### Limpieza entre pruebas

```powershell
Get-ADUser -Filter * -SearchBase "OU=Usuarios,DC=empresa,DC=com" | Remove-ADUser -Confirm:$false
Remove-Item C:\Scripts\logs\* -Force
```

---

## 13. 🔧 Adaptación a cualquier entorno

### Cambiar el dominio

```powershell
.\Invoke-Onboarding.ps1 -CsvPath .\empleados.csv -DominioUPN "miempresa.local"
```

O edita el default en el script:

```powershell
[string]$DominioUPN = 'miempresa.local',
```

### Cambiar la OU en el CSV

Solo cambia el valor de la columna `OU`:

```csv
Nombre,Apellido,Usuario,OU
Juan,Perez,jperez,"OU=Empleados,OU=Madrid,DC=miempresa,DC=local"
```

### Agregar más atributos al usuario

Edita el bloque `New-ADUser` y agrega los parámetros que necesites:

```powershell
New-ADUser `
    -Name "$($row.Nombre) $($row.Apellido)" `
    -GivenName $row.Nombre `
    -Surname $row.Apellido `
    -SamAccountName $usuario `
    -UserPrincipalName "$usuario@$DominioUPN" `
    -EmailAddress "$usuario@$DominioUPN" `
    -AccountPassword $securePass `
    -Path $row.OU `
    -Enabled $true `
    -ChangePasswordAtLogon $true `
    -Company $row.Empresa `
    -Office $row.Oficina `
    -City $row.Ciudad
```

Y agrega esas columnas al CSV.

### Cambiar el separador de grupos

Si prefieres separar grupos por `,` en vez de `;`, cambia:

```powershell
foreach ($g in ($gruposRaw -split ';' | ...
```

por:

```powershell
foreach ($g in ($gruposRaw -split ',' | ...
```

### Cambiar la generación de SamAccountName

Si quieres que el script **calcule** el `Usuario` en vez de leerlo del CSV, reemplaza la línea:

```powershell
$usuario = $row.Usuario
```

por algo como:

```powershell
$usuario = ($row.Nombre.Substring(0,1) + $row.Apellido).ToLower() -replace '[^a-z0-9]',''
```

Esto generaría `jperez` a partir de `Juan` + `Perez`.

### Ejecutarlo desde otro servidor (administración remota)

Si no tienes el módulo AD local, puedes usar `Invoke-Command`:

```powershell
Invoke-Command -ComputerName SRV-DC01 -FilePath .\Invoke-Onboarding.ps1 -ArgumentList "C:\temp\empleados.csv"
```

O usar `-Credential` y PSRemoting.

### Automatizarlo con el Programador de tareas

```powershell
$action  = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Invoke-Onboarding.ps1 -CsvPath C:\Scripts\pendientes.csv"

$trigger = New-ScheduledTaskTrigger -Daily -At 8am

Register-ScheduledTask -TaskName "Onboarding-Diario" `
    -Action $action -Trigger $trigger -User "SYSTEM"
```

### Ejecutarlo para múltiples dominios

```powershell
$dominios = @('empresa1.com', 'empresa2.com')
foreach ($d in $dominios) {
    .\Invoke-Onboarding.ps1 -CsvPath ".\empleados_$d.csv" -DominioUPN $d
}
```

---

## 14. 🐛 Solución de problemas

| Error | Causa | Solución |
|:------|:------|:---------|
| `No se puede cargar el archivo ... no está firmado digitalmente` | Execution Policy | `Unblock-File .\Invoke-Onboarding.ps1` y `Set-ExecutionPolicy RemoteSigned` |
| `No se encuentra la propiedad 'X' en este objeto` | Falta una columna en el CSV | Verifica el CSV; agrega la columna faltante o vacíala |
| `Faltan campos: Usuario, OU` | CSV incompleto | Revisa la primera fila del CSV |
| `OU no encontrada` | La OU en el CSV no coincide | `Get-ADOrganizationalUnit -Filter *` para verificar el DN exacto |
| `No se puede encontrar el objeto ...` en grupo | El grupo no existe en AD | `Get-ADGroup -Filter *` para ver los grupos reales |
| `Acceso denegado` | Falta permiso en la OU | Delegar permisos o usar cuenta con privilegios |
| El CSV con acentos se ve mal | Encoding incorrecto | Guarda como UTF-8 con BOM |
| El script se queda colgado | Espera al AD | Normal en dominios grandes; considera `-Verbose` |
| `PropertyNotFoundException` en `$row.Departamento` | Falta columna y `Set-StrictMode` | Añade la columna al CSV o vacíala |
| Error al pegar en Hyper-V | Portapapeles > 10 KB | Usa Notepad dentro de la VM, o divide el script |

---

## 15. 🔒 Seguridad

### Lo que hace bien

- ✅ Contraseñas aleatorias criptográficamente seguras (`RandomNumberGenerator`)
- ✅ `ChangePasswordAtLogon` por defecto: el usuario debe cambiar la pass en el primer login
- ✅ Separación de credenciales en archivo aislado (`CREDENCIALES_*.csv`)
- ✅ Log de auditoría completo
- ✅ Idempotencia: no sobrescribe usuarios existentes

### Lo que debes cuidar

- ⚠️ **No subas el CSV con contraseñas a Git.**
- ⚠️ **Borra `CREDENCIALES_*.csv` después de entregarlas.**
- ⚠️ **Usa cuentas con permisos mínimos** (delegación sobre la OU, no Domain Admin).
- ⚠️ **Considera usar `SecretManagement`** para credenciales en vez del CSV.
- ⚠️ **Ejecuta siempre con `-WhatIf` primero** en producción.

### `.gitignore` recomendado

```gitignore
# Logs y reportes
logs/
*.log

# Datos sensibles
CREDENCIALES_*.csv
onboarding_*.csv
empleados*.csv
!empleados.ejemplo.csv

# Configuración local
config.json
!config.example.json
```

---

## 16. 📜 Licencia y autor

**Licencia:** MIT. Consulta el archivo `LICENSE` para más detalles.

**Autor:** Tu Nombre — SysAdmin / IT Automation

- [GitHub](https://github.com/TU-USUARIO)
- [LinkedIn](https://linkedin.com/in/TU-USUARIO)

---

## 📚 Referencias

- [New-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/new-aduser)
- [Add-ADGroupMember](https://learn.microsoft.com/powershell/module/activedirectory/add-adgroupmember)
- [Get-ADUser](https://learn.microsoft.com/powershell/module/activedirectory/get-aduser)
- [ShouldProcess](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-shouldprocess)
- [RandomNumberGenerator](https://learn.microsoft.com/dotnet/api/system.security.cryptography.randomnumbergenerator)
