#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$CsvPath,

    [ValidatePattern('^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$DominioUPN = 'empresa.com',

    [string]$LogPath = (Join-Path $PSScriptRoot 'logs'),

    [ValidateRange(12, 32)]
    [int]$PasswordLength = 16
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-RandomPassword {
    param([int]$Length = 16)
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%'.ToCharArray()
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Test-InputRow {
    param([Parameter(Mandatory)]$Row)
    $required = 'Nombre', 'Apellido', 'Usuario', 'OU'
    $missing = $required | Where-Object { [string]::IsNullOrWhiteSpace($Row.$_) }
    if ($missing) { return "Faltan campos: $($missing -join ', ')" }
    if ($Row.Usuario -notmatch '^[a-zA-Z0-9._-]{3,20}$') {
        return "Usuario invalido: '$($Row.Usuario)'"
    }
    return $null
}

function Get-RowValue {
    param($Row, [string]$Name)
    if ($Row.PSObject.Properties.Name -contains $Name) { return $Row.$Name }
    return $null
}

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }
$timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$transcript = Join-Path $LogPath "onboarding_$timestamp.log"
$reportFile = Join-Path $LogPath "onboarding_$timestamp.csv"
Start-Transcript -Path $transcript -Force | Out-Null

$rows = Import-Csv -Path $CsvPath -Encoding UTF8
$results = [System.Collections.Generic.List[object]]::new()
$newPasswords = [System.Collections.Generic.List[object]]::new()

Write-Verbose "Modo: $(if ($WhatIfPreference) { 'SIMULACION' } else { 'REAL' })"
Write-Verbose "CSV: $CsvPath | Dominio: $DominioUPN | Registros: $($rows.Count)"

foreach ($row in $rows) {
    $estado = 'Omitido'
    $detalle = ''
    $usuario = $row.Usuario
    $departamento = Get-RowValue -Row $row -Name 'Departamento'

    try {
        $errorFila = Test-InputRow -Row $row
        if ($errorFila) { throw $errorFila }

        if (Get-ADUser -Filter "SamAccountName -eq '$usuario'" -ErrorAction SilentlyContinue) {
            $estado = 'Ya existia'
            $detalle = 'Sin cambios'
            continue
        }

        if (-not (Get-ADOrganizationalUnit -Identity $row.OU -ErrorAction SilentlyContinue)) {
            throw "OU no encontrada: $($row.OU)"
        }

        $passFromCsv = Get-RowValue -Row $row -Name 'Password'
        $passwordPlano = if ($passFromCsv) {
            $passFromCsv
        } else {
            $p = New-RandomPassword -Length $PasswordLength
            $newPasswords.Add([pscustomobject]@{ Usuario = $usuario; Password = $p })
            $p
        }
        $securePass = ConvertTo-SecureString $passwordPlano -AsPlainText -Force

        if ($PSCmdlet.ShouldProcess($usuario, 'Crear usuario en Active Directory')) {

            New-ADUser `
                -Name                  "$($row.Nombre) $($row.Apellido)" `
                -GivenName             $row.Nombre `
                -Surname               $row.Apellido `
                -SamAccountName        $usuario `
                -UserPrincipalName     "$usuario@$DominioUPN" `
                -EmailAddress          "$usuario@$DominioUPN" `
                -AccountPassword       $securePass `
                -Path                  $row.OU `
                -Enabled               $true `
                -ChangePasswordAtLogon $true

            $gruposFallidos = @()
            $gruposRaw = Get-RowValue -Row $row -Name 'Grupos'
            if ($gruposRaw) {
                foreach ($g in ($gruposRaw -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
                    try { Add-ADGroupMember -Identity $g -Members $usuario -ErrorAction Stop }
                    catch { $gruposFallidos += $g }
                }
            }

            if ($gruposFallidos) {
                $estado = 'Creado con avisos'
                $detalle = "Grupos no asignados: $($gruposFallidos -join ', ')"
            }
            else {
                $estado = 'Creado'
                $detalle = 'OK'
            }
            Write-Verbose "Creado: $usuario"
        }
        else {
            $estado = 'Omitido (WhatIf)'
            $detalle = 'No se realizaron cambios'
        }
    }
    catch {
        $estado = 'Error'
        $detalle = $_.Exception.Message
        Write-Warning "[$usuario] $($_.Exception.Message)"
    }
    finally {
        $results.Add([pscustomobject]@{
            Nombre       = "$($row.Nombre) $($row.Apellido)"
            Usuario      = $usuario
            UPN          = "$usuario@$DominioUPN"
            Departamento = $departamento
            Estado       = $estado
            Detalle      = $detalle
            Fecha        = (Get-Date).ToString('s')
        })
    }
}

$results | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8

if ($newPasswords.Count -gt 0) {
    $passFile = Join-Path $LogPath "CREDENCIALES_$timestamp.csv"
    $newPasswords | Export-Csv -Path $passFile -NoTypeInformation -Encoding UTF8
    Write-Host "Contrasenas temporales en: $passFile" -ForegroundColor Yellow
}

$creados  = @($results | Where-Object Estado -eq 'Creado').Count
$avisos   = @($results | Where-Object Estado -eq 'Creado con avisos').Count
$existent = @($results | Where-Object Estado -eq 'Ya existia').Count
$errores  = @($results | Where-Object Estado -eq 'Error').Count
$omitidos = @($results | Where-Object Estado -like 'Omitido*').Count

Write-Host ""
Write-Host "===== RESUMEN =====" -ForegroundColor Cyan
Write-Host "Creados:            $creados"
Write-Host "Creados con avisos: $avisos" -ForegroundColor Yellow
Write-Host "Ya existian:        $existent"
Write-Host "Omitidos:           $omitidos"
Write-Host "Errores:            $errores" -ForegroundColor Red
Write-Host "Reporte:            $reportFile"
Write-Host "Log:                $transcript"

Stop-Transcript | Out-Null
$results