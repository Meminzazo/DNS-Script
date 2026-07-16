<#
    DNS-Script.ps1
    Configura DNS (AdGuard, rapidos, privados o personalizados) en el adaptador de red activo.
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

    [string[]]$CustomIPv6,

    [string]$CustomLabel
)

# ------------------------------------------------------------------
# Catalogo de categorias y proveedores DNS
# ------------------------------------------------------------------
$Categories = @(
    @{
        Title = "Bloqueo de anuncios"
        Providers = @(
            @{ Name = "AdGuard DNS";           Desc = "Bloquea anuncios y rastreadores";               IPv4 = @("94.140.14.14","94.140.15.15");     IPv6 = @("2a10:50c0::ad1:ff","2a10:50c0::ad2:ff") }
            @{ Name = "AdGuard Family";        Desc = "Bloquea anuncios + contenido adulto";           IPv4 = @("94.140.14.15","94.140.15.16");     IPv6 = @("2a10:50c0::bad1:ff","2a10:50c0::bad2:ff") }
            @{ Name = "CleanBrowsing (Adult)"; Desc = "Bloquea contenido adulto y anuncios explicitos"; IPv4 = @("185.228.168.10","185.228.169.11"); IPv6 = @("2a0d:2a00:1::","2a0d:2a00:2::") }
        )
    },
    @{
        Title = "Rapidos"
        Providers = @(
            @{ Name = "Cloudflare";       Desc = "DNS publico mas rapido del mercado"; IPv4 = @("1.1.1.1","1.0.0.1");     IPv6 = @("2606:4700:4700::1111","2606:4700:4700::1001") }
            @{ Name = "Google Public DNS"; Desc = "Rapido y muy estable";               IPv4 = @("8.8.8.8","8.8.4.4");     IPv6 = @("2001:4860:4860::8888","2001:4860:4860::8844") }
            @{ Name = "OpenDNS";          Desc = "Buena velocidad, filtrado opcional";  IPv4 = @("208.67.222.222","208.67.220.220"); IPv6 = @("2620:119:35::35","2620:119:53::53") }
        )
    },
    @{
        Title = "Privacidad"
        Providers = @(
            @{ Name = "Quad9";                  Desc = "Bloquea malware, sin registro de datos";     IPv4 = @("9.9.9.9","149.112.112.112"); IPv6 = @("2620:fe::fe","2620:fe::9") }
            @{ Name = "Mullvad DNS";             Desc = "Sin filtrado ni registro de actividad";      IPv4 = @("194.242.2.2","194.242.2.3"); IPv6 = @("2a07:e340::2","2a07:e340::3") }
            @{ Name = "AdGuard Non-filtering";   Desc = "Sin bloqueo, enfocado en privacidad";        IPv4 = @("94.140.14.140","94.140.14.141"); IPv6 = @("2a10:50c0::1:ff","2a10:50c0::2:ff") }
        )
    }
)

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
# Utilidades
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

function Read-YesNo {
    param([string]$Prompt)
    $ans = Read-Host "$Prompt (S/N)"
    return $ans -match '^[sS]'
}

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

# Deja elegir al usuario que direcciones exactas de un proveedor quiere aplicar
function Select-Addresses {
    param($Provider)

    $ipv4_1 = if ($Provider.IPv4.Count -gt 0) { $Provider.IPv4[0] } else { $null }
    $ipv4_2 = if ($Provider.IPv4.Count -gt 1) { $Provider.IPv4[1] } else { $null }
    $ipv6_1 = if ($Provider.IPv6.Count -gt 0) { $Provider.IPv6[0] } else { $null }
    $ipv6_2 = if ($Provider.IPv6.Count -gt 1) { $Provider.IPv6[1] } else { $null }

    Write-Host "`nDirecciones disponibles para $($Provider.Name):" -ForegroundColor Cyan
    if ($ipv4_1) { Write-Host "  IPv4 primario:   $ipv4_1" }
    if ($ipv4_2) { Write-Host "  IPv4 secundario: $ipv4_2" }
    if ($ipv6_1) { Write-Host "  IPv6 primario:   $ipv6_1" }
    if ($ipv6_2) { Write-Host "  IPv6 secundario: $ipv6_2" }

    Write-Host "`nQue direcciones quieres aplicar?"
    Write-Host "  1. Todas (recomendado)"
    Write-Host "  2. Solo IPv4 (ambos)"
    Write-Host "  3. Solo IPv6 (ambos)"
    Write-Host "  4. Solo el primario de cada tipo"
    Write-Host "  5. Elegir individualmente"

    $opt = Read-Host "`nSelecciona una opcion"
    while ($opt -notin @("1","2","3","4","5")) {
        Write-Host "Opcion invalida." -ForegroundColor Red
        $opt = Read-Host "Selecciona una opcion"
    }

    $selIPv4 = @()
    $selIPv6 = @()

    switch ($opt) {
        "1" {
            $selIPv4 = @($ipv4_1, $ipv4_2) | Where-Object { $_ }
            $selIPv6 = @($ipv6_1, $ipv6_2) | Where-Object { $_ }
        }
        "2" {
            $selIPv4 = @($ipv4_1, $ipv4_2) | Where-Object { $_ }
        }
        "3" {
            $selIPv6 = @($ipv6_1, $ipv6_2) | Where-Object { $_ }
        }
        "4" {
            $selIPv4 = @($ipv4_1) | Where-Object { $_ }
            $selIPv6 = @($ipv6_1) | Where-Object { $_ }
        }
        "5" {
            if ($ipv4_1 -and (Read-YesNo "  Incluir IPv4 primario ($ipv4_1)?"))   { $selIPv4 += $ipv4_1 }
            if ($ipv4_2 -and (Read-YesNo "  Incluir IPv4 secundario ($ipv4_2)?")) { $selIPv4 += $ipv4_2 }
            if ($ipv6_1 -and (Read-YesNo "  Incluir IPv6 primario ($ipv6_1)?"))   { $selIPv6 += $ipv6_1 }
            if ($ipv6_2 -and (Read-YesNo "  Incluir IPv6 secundario ($ipv6_2)?")) { $selIPv6 += $ipv6_2 }
        }
    }

    if (-not $selIPv4 -and -not $selIPv6) {
        Write-Host "No seleccionaste ninguna direccion, se usaran todas por defecto." -ForegroundColor Yellow
        $selIPv4 = @($ipv4_1, $ipv4_2) | Where-Object { $_ }
        $selIPv6 = @($ipv6_1, $ipv6_2) | Where-Object { $_ }
    }

    return @{ IPv4 = $selIPv4; IPv6 = $selIPv6 }
}

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
# Menu interactivo (solo aparece si NO se paso -Mode ni -Revert por linea de comandos)
# ------------------------------------------------------------------
$interactive = -not $PSBoundParameters.ContainsKey('Mode') -and -not $PSBoundParameters.ContainsKey('Revert')

if ($interactive) {

    $done = $false
    while (-not $done) {

        Write-Host "`n==================================================" -ForegroundColor Cyan
        Write-Host "           Configurador de DNS" -ForegroundColor Cyan
        Write-Host "==================================================`n" -ForegroundColor Cyan

        for ($i = 0; $i -lt $Categories.Count; $i++) {
            Write-Host "  $($i + 1). $($Categories[$i].Title)"
        }
        $customIndex = $Categories.Count + 1
        $revertIndex = $Categories.Count + 2
        Write-Host "  $customIndex. Custom (ingresar DNS manualmente)"
        Write-Host "  $revertIndex. Revert (volver a DHCP)"
        Write-Host "  0. Salir`n"

        $validMain = @("0") + (1..$revertIndex | ForEach-Object { "$_" })
        $mainChoice = Read-Host "Selecciona una opcion"
        while ($mainChoice -notin $validMain) {
            Write-Host "Opcion invalida." -ForegroundColor Red
            $mainChoice = Read-Host "Selecciona una opcion"
        }

        if ($mainChoice -eq "0") { exit }

        if ($mainChoice -eq "$revertIndex") {
            $Revert = $true
            $done = $true
            continue
        }

        if ($mainChoice -eq "$customIndex") {
            $Mode = "Custom"
            $done = $true
            continue
        }

        # Categoria seleccionada -> mostrar submenu de proveedores
        $category = $Categories[[int]$mainChoice - 1]
        $inSubmenu = $true

        while ($inSubmenu) {
            Write-Host "`n---- $($category.Title) ----`n" -ForegroundColor Cyan
            for ($j = 0; $j -lt $category.Providers.Count; $j++) {
                $p = $category.Providers[$j]
                Write-Host "  $($j + 1). $($p.Name) - $($p.Desc)"
            }
            Write-Host "  0. Volver`n"

            $validSub = @("0") + (1..$category.Providers.Count | ForEach-Object { "$_" })
            $subChoice = Read-Host "Selecciona una opcion"
            while ($subChoice -notin $validSub) {
                Write-Host "Opcion invalida." -ForegroundColor Red
                $subChoice = Read-Host "Selecciona una opcion"
            }

            if ($subChoice -eq "0") {
                $inSubmenu = $false
                continue
            }

            $provider = $category.Providers[[int]$subChoice - 1]
            $selection = Select-Addresses -Provider $provider

            $Mode = "Custom"
            $CustomIPv4 = $selection.IPv4
            $CustomIPv6 = $selection.IPv6
            $CustomLabel = "$($category.Title) - $($provider.Name)"

            $inSubmenu = $false
            $done = $true
        }
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
    if ($CustomLabel) { $argList += "-CustomLabel `"$CustomLabel`"" }

    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" $($argList -join ' ')"
    exit
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

    if (-not $CustomIPv4 -and -not $CustomIPv6) {

        Write-Host "`n=== Configuracion de DNS personalizados ===" -ForegroundColor Cyan
        Write-Host "Ingresa las direcciones IP. Deja en blanco y presiona Enter para omitir un campo opcional.`n"

        $primaryIPv4   = Read-ValidIP -Prompt "DNS primario IPv4 (obligatorio)" -Required $true
        $secondaryIPv4 = Read-ValidIP -Prompt "DNS secundario IPv4 (opcional)"
        $primaryIPv6   = Read-ValidIP -Prompt "DNS primario IPv6 (opcional)"
        $secondaryIPv6 = Read-ValidIP -Prompt "DNS secundario IPv6 (opcional)"

        $CustomIPv4 = @($primaryIPv4, $secondaryIPv4) | Where-Object { $_ }
        $CustomIPv6 = @($primaryIPv6, $secondaryIPv6) | Where-Object { $_ }
    }
    else {
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
        Descripcion = if ($CustomLabel) { $CustomLabel } else { "DNS personalizados definidos por el usuario" }
    }
}
else {
    $config = $AdGuardServers[$Mode]
}

Write-Host "Aplicando DNS - $($config.Descripcion)" -ForegroundColor Cyan
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
