<#
    DNS-Script.ps1
    Configura DNS de AdGuard (o personalizados) en el adaptador de red activo.
    Ver README.md para documentacion completa.
    Requiere ejecutarse como Administrador.
#>

[CmdletBinding()]
param(
    [ValidateSet("Default", "Family", "NonFiltering", "Custom")]
    [string]$Mode = "Default",

    [string]$AdapterName,

    [switch]$Revert,

    [string[]]$CustomIPv4,

    [string[]]$CustomIPv6
)

# ------------------------------------------------------------------
# Menu interactivo (solo aparece si NO se paso -Mode ni -Revert por linea de comandos)
# ------------------------------------------------------------------
$interactive = -not $PSBoundParameters.ContainsKey('Mode') -and -not $PSBoundParameters.ContainsKey('Revert')

if ($interactive) {
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host "        Configurador de DNS - AdGuard" -ForegroundColor Cyan
    Write-Host "==================================================`n" -ForegroundColor Cyan
    Write-Host "  1. Default       - Bloquea anuncios y rastreadores"
    Write-Host "  2. Family        - Bloquea anuncios + contenido adulto"
    Write-Host "  3. NonFiltering  - Sin bloqueo, solo resolucion DNS"
    Write-Host "  4. Custom        - DNS personalizados (tu ingresas las IP)"
    Write-Host "  5. Revert        - Volver a DNS automatico (DHCP)"
    Write-Host "  0. Salir`n"

    $validChoices = @("0", "1", "2", "3", "4", "5")
    $choice = Read-Host "Selecciona una opcion"
    while ($choice -notin $validChoices) {
        Write-Host "Opcion invalida. Ingresa un numero del 0 al 5." -ForegroundColor Red
        $choice = Read-Host "Selecciona una opcion"
    }

    switch ($choice) {
        "0" { exit }
        "1" { $Mode = "Default" }
        "2" { $Mode = "Family" }
        "3" { $Mode = "NonFiltering" }
        "4" { $Mode = "Custom" }
        "5" { $Revert = $true }
    }
    Write-Host ""
}

# ------------------------------------------------------------------
# Verificar que se ejecuta como Administrador
# ------------------------------------------------------------------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script requiere permisos de Administrador." -ForegroundColor Red
    Write-Host "Reintentando con elevacion..." -ForegroundColor Yellow

    $argList = @()
    if ($Mode)        { $argList += "-Mode `"$Mode`"" }
    if ($AdapterName) { $argList += "-AdapterName `"$AdapterName`"" }
    if ($Revert)      { $argList += "-Revert" }
    if ($CustomIPv4)  { $argList += "-CustomIPv4 $($CustomIPv4 -join ',')" }
    if ($CustomIPv6)  { $argList += "-CustomIPv6 $($CustomIPv6 -join ',')" }

    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" $($argList -join ' ')"
    exit
}

# ------------------------------------------------------------------
# Tabla de servidores DNS de AdGuard (IPv4 e IPv6)
# ------------------------------------------------------------------
$AdGuardServers = @{
    Default = @{
        IPv4 = @("94.140.14.14", "94.140.15.15")
        IPv6 = @("2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff")
        Descripcion = "Bloqueo de anuncios y rastreadores"
    }
    Family = @{
        IPv4 = @("94.140.14.15", "94.140.15.16")
        IPv6 = @("2a10:50c0::bad1:ff", "2a10:50c0::bad2:ff")
        Descripcion = "Bloqueo de anuncios, rastreadores y contenido adulto"
    }
    NonFiltering = @{
        IPv4 = @("94.140.14.140", "94.140.14.141")
        IPv6 = @("2a10:50c0::1:ff", "2a10:50c0::2:ff")
        Descripcion = "Sin filtrado, solo resolucion DNS"
    }
}

# ------------------------------------------------------------------
# Validar direcciones IP (IPv4 o IPv6)
# ------------------------------------------------------------------
function Test-ValidIP {
    param([string]$IPAddress)
    try {
        [void][System.Net.IPAddress]::Parse($IPAddress)
        return $true
    }
    catch {
        return $false
    }
}

# ------------------------------------------------------------------
# Obtener adaptadores de red a modificar
# ------------------------------------------------------------------
function Get-TargetAdapters {
    param([string]$Name)

    if ($Name) {
        $adapter = Get-NetAdapter -Name $Name -ErrorAction SilentlyContinue
        if (-not $adapter) {
            Write-Host "No se encontro el adaptador '$Name'." -ForegroundColor Red
            exit 1
        }
        return @($adapter)
    }

    # Adaptadores activos con conexion (Up) que no sean virtuales/loopback
    $adapters = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and
        $_.InterfaceDescription -notmatch "Virtual|Loopback|Bluetooth"
    }

    if (-not $adapters) {
        Write-Host "No se encontro ningun adaptador de red activo." -ForegroundColor Red
        exit 1
    }

    return $adapters
}

# ------------------------------------------------------------------
# Logica principal
# ------------------------------------------------------------------
$adapters = Get-TargetAdapters -Name $AdapterName

if ($Revert) {
    Write-Host "Revirtiendo DNS a configuracion automatica (DHCP)..." -ForegroundColor Cyan
    foreach ($adapter in $adapters) {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses
        Write-Host "  [OK] $($adapter.Name) -> DNS automatico (DHCP)" -ForegroundColor Green
    }
    Write-Host "`nListo. Puede que necesites ejecutar 'ipconfig /flushdns' o reiniciar el adaptador." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Presiona Enter para salir"
    exit
}

if ($Mode -eq "Custom") {

    # Si no se pasaron por parametro, se piden de forma interactiva
    if (-not $CustomIPv4 -and -not $CustomIPv6) {

        Write-Host "`n=== Configuracion de DNS personalizados ===" -ForegroundColor Cyan
        Write-Host "Ingresa las direcciones IP. Deja en blanco y presiona Enter para omitir un campo opcional.`n"

        function Read-ValidIP {
            param(
                [string]$Prompt,
                [bool]$Required = $false
            )
            while ($true) {
                $value = Read-Host $Prompt
                if ([string]::IsNullOrWhiteSpace($value)) {
                    if ($Required) {
                        Write-Host "  Este campo es obligatorio." -ForegroundColor Yellow
                        continue
                    }
                    return $null
                }
                if (Test-ValidIP $value) {
                    return $value
                }
                Write-Host "  '$value' no es una direccion IP valida. Intenta de nuevo." -ForegroundColor Red
            }
        }

        $primaryIPv4   = Read-ValidIP -Prompt "DNS primario IPv4 (obligatorio)" -Required $true
        $secondaryIPv4 = Read-ValidIP -Prompt "DNS secundario IPv4 (opcional)"
        $primaryIPv6   = Read-ValidIP -Prompt "DNS primario IPv6 (opcional)"
        $secondaryIPv6 = Read-ValidIP -Prompt "DNS secundario IPv6 (opcional)"

        $CustomIPv4 = @($primaryIPv4, $secondaryIPv4) | Where-Object { $_ }
        $CustomIPv6 = @($primaryIPv6, $secondaryIPv6) | Where-Object { $_ }
    }
    else {
        # Se pasaron por parametro: solo validar
        $allInputIPs = @($CustomIPv4) + @($CustomIPv6) | Where-Object { $_ }
        $invalidIPs = $allInputIPs | Where-Object { -not (Test-ValidIP $_) }
        if ($invalidIPs) {
            Write-Host "Las siguientes direcciones no son validas: $($invalidIPs -join ', ')" -ForegroundColor Red
            exit 1
        }
    }

    if (-not $CustomIPv4 -and -not $CustomIPv6) {
        Write-Host "No se ingreso ninguna direccion DNS valida. Cancelando." -ForegroundColor Red
        exit 1
    }

    $config = @{
        IPv4 = @($CustomIPv4)
        IPv6 = @($CustomIPv6)
        Descripcion = "DNS personalizados definidos por el usuario"
    }
}
else {
    $config = $AdGuardServers[$Mode]
}

Write-Host "Aplicando DNS - Modo: $Mode ($($config.Descripcion))" -ForegroundColor Cyan
if ($config.IPv4) { Write-Host "  IPv4: $($config.IPv4 -join ', ')" }
if ($config.IPv6) { Write-Host "  IPv6: $($config.IPv6 -join ', ')`n" } else { Write-Host "" }

foreach ($adapter in $adapters) {
    try {
        $allServers = @($config.IPv4) + @($config.IPv6) | Where-Object { $_ }
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $allServers
        Write-Host "  [OK] $($adapter.Name) configurado correctamente." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] No se pudo configurar $($adapter.Name): $_" -ForegroundColor Red
    }
}

# ------------------------------------------------------------------
# Limpiar cache DNS y verificar
# ------------------------------------------------------------------
Write-Host "`nLimpiando cache de DNS..." -ForegroundColor Cyan
Clear-DnsClientCache

Write-Host "`nVerificacion final:" -ForegroundColor Cyan
foreach ($adapter in $adapters) {
    $current = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
    Write-Host "  $($adapter.Name): $($current.ServerAddresses -join ', ')"
}

Write-Host "`nConfiguracion completada." -ForegroundColor Green
Write-Host ""
Read-Host "Presiona Enter para salir"
