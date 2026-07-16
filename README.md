# AdGuardDNS-Script

Script de PowerShell para configurar automáticamente los servidores DNS de [AdGuard](https://adguard-dns.io/es/public-dns.html) (o DNS personalizados) en el adaptador de red activo de Windows.

## Características

- Detecta automáticamente el adaptador de red activo (o permite indicar uno específico).
- 4 modos de DNS de AdGuard:
  | Modo | Descripción |
  |------|-------------|
  | **Default** | Bloquea anuncios y rastreadores |
  | **Family** | Bloquea anuncios, rastreadores y contenido adulto |
  | **NonFiltering** | Sin bloqueo, solo resolución DNS (útil para diagnóstico) |
  | **Custom** | Permite ingresar tus propios servidores DNS (AdGuard Home, Google, Cloudflare, etc.) |
- Modo **Custom** interactivo: si no pasas las IPs por parámetro, el script te las pide una por una (primario/secundario IPv4 e IPv6), validando el formato en tiempo real.
- Soporte para IPv4 e IPv6.
- Opción `-Revert` para volver a DNS automático (DHCP).
- Se auto-eleva a Administrador si no se ejecuta con esos permisos.
- Limpia la caché de DNS y verifica la configuración aplicada al finalizar.
- Menú interactivo si se ejecuta sin parámetros (doble clic o clic derecho → "Ejecutar con PowerShell").

## Requisitos

- Windows 10/11
- PowerShell 5.1 o superior
- Permisos de Administrador (el script los solicita automáticamente)

## Uso

### Sin parámetros (menú interactivo)

```powershell
.\Set-AdGuardDNS.ps1
```

Muestra un menú numerado para elegir el modo:

```
1. Default
2. Family
3. NonFiltering
4. Custom
5. Revert
0. Salir
```

### Con parámetros

```powershell
# DNS estándar de AdGuard (bloqueo de anuncios y rastreadores)
.\DNS-Script.ps1 -Mode Default

# Modo familiar (bloquea también contenido adulto)
.\DNS-Script.ps1 -Mode Family

# Sin filtrado, solo resolución DNS
.\DNS-Script.ps1 -Mode NonFiltering

# Especificar un adaptador en concreto (si tienes varios)
.\DNS-Script.ps1 -Mode Default -AdapterName "Wi-Fi"

# DNS personalizados, pidiendo las IPs de forma interactiva
.\DNS-Script.ps1 -Mode Custom

# DNS personalizados pasados directamente por parámetro
.\DNS-Script.ps1 -Mode Custom -CustomIPv4 8.8.8.8,8.8.4.4

# Revertir a DNS automático (DHCP)
.\DNS-Script.ps1 -Revert
```

## Parámetros

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `-Mode` | string | `Default`, `Family`, `NonFiltering` o `Custom`. Por defecto `Default`. |
| `-AdapterName` | string | (Opcional) Nombre específico del adaptador de red. Si se omite, se detectan automáticamente los adaptadores activos. |
| `-Revert` | switch | Revierte la configuración de DNS a automática (DHCP). |
| `-CustomIPv4` | string[] | Direcciones IPv4 a usar con `-Mode Custom`. Ej: `8.8.8.8,8.8.4.4`. Si se omite, se piden de forma interactiva. |
| `-CustomIPv6` | string[] | Direcciones IPv6 a usar con `-Mode Custom` (opcional). Si se omite, se piden de forma interactiva. |

## Servidores DNS de AdGuard utilizados

| Modo | IPv4 | IPv6 |
|------|------|------|
| Default | `94.140.14.14`, `94.140.15.15` | `2a10:50c0::ad1:ff`, `2a10:50c0::ad2:ff` |
| Family | `94.140.14.15`, `94.140.15.16` | `2a10:50c0::bad1:ff`, `2a10:50c0::bad2:ff` |
| NonFiltering | `94.140.14.140`, `94.140.14.141` | `2a10:50c0::1:ff`, `2a10:50c0::2:ff` |

Fuente: [AdGuard DNS Providers]((https://adguard-dns.io/es/public-dns.html))

## Notas

- El script requiere permisos de Administrador; si no los tiene, se relanza automáticamente en una consola elevada.
- Al finalizar, se limpia la caché de DNS (`Clear-DnsClientCache`) y se muestra la configuración final aplicada por adaptador.
- Si algo no toma efecto de inmediato, prueba con `ipconfig /flushdns` o reiniciando el adaptador de red.

## Licencia

Uso libre, sin garantías. Úsalo bajo tu propio riesgo.
