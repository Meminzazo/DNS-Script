# DNS-Script

Script de PowerShell para configurar automáticamente los servidores DNS en el adaptador de red activo de Windows. Incluye un menú interactivo con categorías (bloqueo de anuncios, DNS rápidos, privacidad) y la opción de definir tus propios servidores.

## Características

- Menú interactivo con categorías y submenús de proveedores.
- Para cada proveedor, eliges exactamente qué direcciones aplicar: todas, solo IPv4, solo IPv6, solo los primarios, o una selección individual.
- Modo **Custom** totalmente manual: ingresas tus propias IPs (primario/secundario IPv4 e IPv6), con validación de formato en tiempo real.
- Detecta automáticamente el adaptador de red activo (o permite indicar uno específico).
- Opción `-Revert` para volver a DNS automático (DHCP).
- Se auto-eleva a Administrador si no se ejecuta con esos permisos.
- Limpia la caché de DNS y verifica la configuración aplicada al finalizar.
- Soporte para IPv4 e IPv6.

## Requisitos

- Windows 10/11
- PowerShell 5.1 o superior
- Permisos de Administrador (el script los solicita automáticamente)

## Uso

### Sin parámetros (menú interactivo)

```powershell
.\Set-AdGuardDNS.ps1
```

Muestra el menú principal:

```
1. Bloqueo de anuncios
2. Rapidos
3. Privacidad
4. Custom (ingresar DNS manualmente)
5. Revert (volver a DHCP)
0. Salir
```

Al elegir una categoría (1-3), se abre un submenú con los proveedores disponibles para esa categoría. Al elegir un proveedor, el script muestra sus direcciones IPv4/IPv6 y te deja decidir qué aplicar:

```
1. Todas (recomendado)
2. Solo IPv4 (ambos)
3. Solo IPv6 (ambos)
4. Solo el primario de cada tipo
5. Elegir individualmente
```

### Con parámetros (sin pasar por el menú)

```powershell
# DNS personalizados pasados directamente por parámetro
.\Set-AdGuardDNS.ps1 -Mode Custom -CustomIPv4 8.8.8.8,8.8.4.4

# Especificar un adaptador en concreto (si tienes varios)
.\Set-AdGuardDNS.ps1 -Mode Default -AdapterName "Wi-Fi"

# Revertir a DNS automático (DHCP)
.\Set-AdGuardDNS.ps1 -Revert
```

> Nota: `-Mode Default`, `-Mode Family` y `-Mode NonFiltering` siguen disponibles por línea de comandos y usan los servidores de AdGuard directamente, sin pasar por el menú interactivo (pensado para uso en scripts/automatización, por ejemplo con Task Scheduler).

## Parámetros

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `-Mode` | string | `Default`, `Family`, `NonFiltering` o `Custom`. Por defecto `Default`. Si no se pasa ningún parámetro, se muestra el menú interactivo en su lugar. |
| `-AdapterName` | string | (Opcional) Nombre específico del adaptador de red. Si se omite, se detectan automáticamente los adaptadores activos. |
| `-Revert` | switch | Revierte la configuración de DNS a automática (DHCP). |
| `-CustomIPv4` | string[] | Direcciones IPv4 a usar con `-Mode Custom`. Ej: `8.8.8.8,8.8.4.4`. Si se omite, se piden de forma interactiva. |
| `-CustomIPv6` | string[] | Direcciones IPv6 a usar con `-Mode Custom` (opcional). Si se omite, se piden de forma interactiva. |
| `-CustomLabel` | string | (Uso interno del menú) Etiqueta descriptiva mostrada al aplicar la configuración. |

## Categorías y proveedores incluidos

### 🚫 Bloqueo de anuncios

| Proveedor | Descripción | IPv4 | IPv6 |
|-----------|-------------|------|------|
| AdGuard DNS | Bloquea anuncios y rastreadores | `94.140.14.14`, `94.140.15.15` | `2a10:50c0::ad1:ff`, `2a10:50c0::ad2:ff` |
| AdGuard Family | Bloquea anuncios + contenido adulto | `94.140.14.15`, `94.140.15.16` | `2a10:50c0::bad1:ff`, `2a10:50c0::bad2:ff` |
| CleanBrowsing (Adult) | Bloquea contenido adulto y anuncios explícitos | `185.228.168.10`, `185.228.169.11` | `2a0d:2a00:1::`, `2a0d:2a00:2::` |

### ⚡ Rápidos

| Proveedor | Descripción | IPv4 | IPv6 |
|-----------|-------------|------|------|
| Cloudflare | DNS público más rápido del mercado | `1.1.1.1`, `1.0.0.1` | `2606:4700:4700::1111`, `2606:4700:4700::1001` |
| Google Public DNS | Rápido y muy estable | `8.8.8.8`, `8.8.4.4` | `2001:4860:4860::8888`, `2001:4860:4860::8844` |
| OpenDNS | Buena velocidad, filtrado opcional | `208.67.222.222`, `208.67.220.220` | `2620:119:35::35`, `2620:119:53::53` |

### 🔒 Privacidad

| Proveedor | Descripción | IPv4 | IPv6 |
|-----------|-------------|------|------|
| Quad9 | Bloquea malware, sin registro de datos | `9.9.9.9`, `149.112.112.112` | `2620:fe::fe`, `2620:fe::9` |
| Mullvad DNS | Sin filtrado ni registro de actividad | `194.242.2.2`, `194.242.2.3` | `2a07:e340::2`, `2a07:e340::3` |
| AdGuard Non-filtering | Sin bloqueo, enfocado en privacidad | `94.140.14.140`, `94.140.14.141` | `2a10:50c0::1:ff`, `2a10:50c0::2:ff` |

Fuentes: [AdGuard DNS](https://adguard-dns.io/en/public-dns.html) · [Cloudflare 1.1.1.1](https://1.1.1.1/) · [Google Public DNS](https://developers.google.com/speed/public-dns) · [Quad9](https://www.quad9.net/) · [Mullvad DNS](https://mullvad.net/en/help/dns-over-https-and-dns-over-tls) · [CleanBrowsing](https://cleanbrowsing.org/filters) · [OpenDNS](https://www.opendns.com/)

## Notas

- El script requiere permisos de Administrador; si no los tiene, se relanza automáticamente en una consola elevada.
- Al finalizar, se limpia la caché de DNS (`Clear-DnsClientCache`) y se muestra la configuración final aplicada por adaptador.
- Si algo no toma efecto de inmediato, prueba con `ipconfig /flushdns` o reiniciando el adaptador de red.

## Licencia

Uso libre, sin garantías. Úsalo bajo tu propio riesgo.
