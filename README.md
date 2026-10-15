# PC Toolkit — BY IRREBOY

PC Toolkit es una herramienta de mantenimiento y optimización para Windows, construida en PowerShell con interfaz gráfica WPF.

---

## Módulos

### [S] Seguridad
- Escaneo completo del sistema con categorías OK / WARNING / CRÍTICO
- Botones de fix individuales por alerta
- Aplicar todos los fixes en un clic
- Exportar reporte en `.log`

### [C] Limpieza
- Limpieza de archivos temporales, caché y Recycle Bin
- Opción DISM para limpiar componentes del sistema (más lento, más profundo)

### [G] Gaming
- **GameBoost**: aplica y restaura optimizaciones de red, CPU, mouse e input lag
- **Kill Procesos**: cierra Discord, Chrome, Edge, OneDrive, Teams, Slack, Spotify, Epic
- **Ping Test**: latencia ICMP + TCP a servidores de Riot, Steam, Blizzard y Epic
- **Speed Test**: descarga, subida, latencia y jitter vía Cloudflare
- **Efectos Visuales**: desactiva animaciones y transparencia de Windows
- **Flush DNS** / **Reset Adaptador de Red** / **Limpiar Shader Caches**

### Monitor en vivo (panel derecho)
- CPU, RAM, GPU, Temperatura, Disco (I/O + espacio), Red (↓/↑)
- Top 3 procesos por consumo de CPU
- Uptime del sistema

---

## Estructura

```
PCToolkit.ps1       # App principal (WPF, lógica de UI y motor de jobs)
SecurityCheck.ps1   # Módulo de seguridad
CleanPC.ps1         # Módulo de limpieza
GameBoost.ps1       # Módulo de optimización gaming
PC Toolkit.lnk      # Acceso directo de lanzamiento
```

---

## Instalación

1. Clona el repo:
   ```powershell
   git clone https://github.com/irreboy/KillTool.git C:\Scripts
   ```

2. (Opcional) Ajusta `$ScriptsDir` en `PCToolkit.ps1` si usas otra ruta:
   ```powershell
   $ScriptsDir = "C:\Scripts"
   ```

3. Ejecuta:
   ```powershell
   powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Scripts\PCToolkit.ps1"
   ```

   O doble clic en `PC Toolkit.lnk` (requiere ajustar la ruta del acceso directo).

> Algunas funciones del módulo Gaming requieren ejecutar como **Administrador**.

---

## Requisitos

- Windows 10 / 11
- PowerShell 5.1 o superior
- .NET Framework (incluido en Windows)

---

*BY IRREBOY*
