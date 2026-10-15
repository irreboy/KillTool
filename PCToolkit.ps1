# PCToolkit.ps1 - BY IRREBOY
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

$ScriptsDir = "C:\Users\jdpbe\Scripts"
$script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$script:_Job         = $null
$script:_Timer       = $null
$script:_PrintTimer  = $null
$script:_PrintQueue  = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
$script:_StreamFile  = ""
$script:_LastLineIdx = 0
$script:_OkCount     = 0
$script:_WarnCount   = 0
$script:_CritCount   = 0
$script:_StartTime   = $null
$script:_SysJob      = $null
$script:_SysTimer    = $null
$script:ActiveTab    = "Security"
$script:LastAlerts   = @()
$script:LastLogFile  = ""
$script:_MonJob      = $null
$script:_MonTimer    = $null
$script:_MonStream   = ""
$script:_MonData     = @{}
$script:_Tray        = $null
$script:_TrayExit    = $false

$script:AsciiSkull = @(
    "⠀⠀⠀⠲⣦⣤⣀⣀⠀⠀⠀⣀⣀⣠⣤⣀⣀⠀⢀⣀⣠⣤⣶⣶⠟⠀⠀⠀",
    "⠀⠀⠀⠀⠙⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠋⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠈⢿⣿⣿⠻⣿⣿⣿⣿⣿⣿⣿⠟⢻⣿⣿⡿⠃⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠲⣶⣶⣾⣿⣿⠀⢨⠙⢿⣿⣿⠏⣅⠀⢸⣿⣿⣷⣾⠟⠁⠀⠀⠀",
    "⠀⠀⠀⠀⠈⠻⢿⣿⣿⢷⣶⣶⣾⣿⣿⣶⣶⣾⠟⣿⣿⣿⣋⠀⠀⠀⠀⠀",
    "⠀⠀⢀⣀⣀⠐⢶⣿⣿⣧⠁⠀⠋⠁⠈⠋⠀⢀⣾⣿⣿⡿⣷⣶⠀⠀⠀⠀",
    "⠀⠀⣼⣿⣿⣷⣤⣙⣿⣿⣷⣶⣶⣴⣴⣴⣶⣿⣿⣿⠟⣡⣿⣿⣧⣄⣀⡀",
    "⢀⣤⣿⣿⣿⣿⣿⣿⣿⣿⢿⣿⣿⣿⣿⣿⣿⣿⣿⠿⢿⣿⡿⠿⣿⣿⣿⣿",
    "⣿⡿⠛⠿⠟⠉⠉⠉⠸⠋⠀⠻⡿⣿⣿⣿⣿⠻⠇⠀⠀⠈⠀⠀⠈⠉⢸⠃",
    "⠛⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠈⢿⢻⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
)
$script:AsciiIRREBOY = @(
    "###  ###   ###   ####  ###    ##   #  #",
    " #   # #   # #   #     # #   #  #  #  #",
    " #   ##    ##    ###   ###   #  #   ## ",
    " #   # #   # #   #     # #   #  #    # ",
    "###  #  #  #  #  ####  ###    ##     # "
)

# ---- XAML ---------------------------------------------------------------
$XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PC Toolkit  //  BY IRREBOY"
        Height="700" Width="1080"
        WindowStartupLocation="CenterScreen"
        Background="#0a0008" Foreground="#e0d0ff"
        FontFamily="Consolas" FontSize="12"
        ResizeMode="CanResize">
  <Window.Resources>

    <Style x:Key="SideTabBtn" TargetType="Button">
      <Setter Property="Background" Value="#0d000b"/>
      <Setter Property="Foreground" Value="#553366"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="10,9"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Margin" Value="0,1,0,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="3" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SideTabActive" TargetType="Button" BasedOn="{StaticResource SideTabBtn}">
      <Setter Property="Background" Value="#1a0028"/>
      <Setter Property="Foreground" Value="#cc88ff"/>
    </Style>

    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Background" Value="#7722aa"/>
      <Setter Property="Foreground" Value="#ffffff"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="10,7"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="FontFamily" Value="Consolas"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="3"
                    Padding="{TemplateBinding Padding}" Opacity="{TemplateBinding Opacity}">
              <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Opacity" Value="0.8"/></Trigger>
        <Trigger Property="IsEnabled"   Value="False"><Setter Property="Opacity" Value="0.3"/></Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="BtnFix" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#aa2255"/>
      <Setter Property="Padding" Value="8,3"/>
      <Setter Property="FontSize" Value="10"/>
    </Style>
    <Style x:Key="BtnGreen" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#1a6a30"/>
    </Style>
    <Style x:Key="BtnRed" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#7a1818"/>
    </Style>
    <Style x:Key="BtnGhost" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#140016"/>
      <Setter Property="Foreground" Value="#553366"/>
    </Style>
    <Style x:Key="BtnOrange" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#773800"/>
    </Style>
    <Style x:Key="BtnYellow" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#665500"/>
      <Setter Property="Foreground" Value="#ffdd44"/>
    </Style>

  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="3"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- HEADER -->
    <Border Grid.Row="0" Background="#0d000b" Padding="16,10">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0" Orientation="Vertical">
          <StackPanel Orientation="Horizontal">
            <TextBlock Text="[ " Foreground="#440033" FontSize="17" FontWeight="Bold" VerticalAlignment="Center"/>
            <TextBlock Text="PC TOOLKIT" Foreground="#cc88ff" FontSize="17" FontWeight="Bold" VerticalAlignment="Center"/>
            <TextBlock Text=" ]" Foreground="#440033" FontSize="17" FontWeight="Bold" VerticalAlignment="Center"/>
            <TextBlock Text="  //  BY " Foreground="#440033" FontSize="11" VerticalAlignment="Center" Margin="8,0,0,0"/>
            <TextBlock Text="IRREBOY" Foreground="#9922cc" FontSize="11" FontWeight="Bold" VerticalAlignment="Center"/>
          </StackPanel>
          <TextBlock x:Name="SysInfo" Text="cargando..." Foreground="#330044" FontSize="10" Margin="0,3,0,0"/>
        </StackPanel>
        <StackPanel Grid.Column="1" HorizontalAlignment="Right">
          <TextBlock x:Name="ClockText" Text="" Foreground="#660099" FontSize="20" FontWeight="Bold" HorizontalAlignment="Right"/>
          <TextBlock x:Name="DateText"  Text="" Foreground="#330044" FontSize="10"  HorizontalAlignment="Right"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- PROGRESS BAR -->
    <ProgressBar x:Name="ScanProgress" Grid.Row="1"
                 IsIndeterminate="True" Visibility="Collapsed"
                 Foreground="#cc44ff" Background="#120010" BorderThickness="0"/>

    <!-- 3-COLUMN CONTENT -->
    <Grid Grid.Row="2">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="175"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="252"/>
      </Grid.ColumnDefinitions>

      <!-- LEFT: nav + buttons -->
      <Border Grid.Column="0" Background="#0d000b">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="10,12">

            <TextBlock Text="// MODULOS" Foreground="#440055" FontSize="9" FontWeight="Bold" Margin="4,0,0,5"/>
            <Button x:Name="TabSecurity" Content="[S]  SEGURIDAD"  Style="{StaticResource SideTabActive}"/>
            <Button x:Name="TabClean"    Content="[C]  LIMPIEZA"   Style="{StaticResource SideTabBtn}"/>
            <Button x:Name="TabGaming"   Content="[G]  GAMING"     Style="{StaticResource SideTabBtn}"/>

            <Rectangle Height="1" Fill="#1a001a" Margin="0,12,0,10"/>

            <!-- SECURITY PANEL -->
            <StackPanel x:Name="PanelSecurity">
              <Button x:Name="BtnRunSecurity" Content="> EJECUTAR CHEQUEO" Style="{StaticResource Btn}"/>
              <Button x:Name="BtnFixAll"      Content="[!] APLICAR FIXES"  Style="{StaticResource BtnFix}" IsEnabled="False"/>
              <Button x:Name="BtnOpenLog"     Content="[L] VER REPORTE"    Style="{StaticResource BtnGhost}" IsEnabled="False"/>
            </StackPanel>

            <!-- CLEAN PANEL -->
            <StackPanel x:Name="PanelClean" Visibility="Collapsed">
              <Button x:Name="BtnRunClean" Content="> LIMPIAR PC" Style="{StaticResource Btn}"/>
              <CheckBox x:Name="ChkDISM" Foreground="#553366" FontFamily="Consolas" FontSize="10"
                        Content="DISM cleanup (lento)" Margin="2,4,0,4"/>
              <TextBlock Text="Cierra los navegadores antes." Foreground="#330033"
                         FontSize="9" TextWrapping="Wrap" Margin="2,2,0,0"/>
            </StackPanel>

            <!-- GAMING PANEL -->
            <StackPanel x:Name="PanelGaming" Visibility="Collapsed">
              <Border x:Name="AdminWarning" Visibility="Collapsed"
                      Background="#221100" BorderBrush="#664400" BorderThickness="1"
                      CornerRadius="3" Padding="6,5" Margin="0,0,0,6">
                <StackPanel>
                  <TextBlock Text="! Sin permisos Admin" Foreground="#ffaa00" FontSize="9" FontWeight="Bold"/>
                  <TextBlock Text="Apply / Restore requieren admin." Foreground="#998844" FontSize="9" TextWrapping="Wrap" Margin="0,2,0,4"/>
                  <Button x:Name="BtnElevate" Content="[^] REINICIAR COMO ADMIN" Style="{StaticResource BtnYellow}"/>
                </StackPanel>
              </Border>

              <Button x:Name="BtnGameCheck"   Content="[?] ESTADO ACTUAL"     Style="{StaticResource BtnGhost}"/>
              <Button x:Name="BtnGameApply"   Content="[+] OPTIMIZAR"         Style="{StaticResource BtnGreen}"/>
              <Button x:Name="BtnGameRestore" Content="[-] RESTAURAR"         Style="{StaticResource BtnRed}"/>
              <TextBlock x:Name="BackupStatus" Text="sin backup" Foreground="#440033"
                         FontSize="9" Margin="2,2,0,10" TextWrapping="Wrap"/>

              <Rectangle Height="1" Fill="#1a001a" Margin="0,4,0,6"/>
              <Button x:Name="BtnKillProcs" Content="[X] KILL PROCESOS"       Style="{StaticResource BtnRed}"/>

              <Rectangle Height="1" Fill="#1a001a" Margin="0,4,0,6"/>
              <Button x:Name="BtnPingTest"   Content="[P] PING SERVERS"       Style="{StaticResource BtnOrange}"/>
              <Button x:Name="BtnSpeedTest"  Content="[W] SPEED TEST"          Style="{StaticResource BtnOrange}"/>

              <Rectangle Height="1" Fill="#1a001a" Margin="0,4,0,6"/>
              <Button x:Name="BtnVFX"          Content="[V] EFECTOS VISUALES" Style="{StaticResource BtnGhost}"/>
              <Button x:Name="BtnFlushDNS"     Content="[N] FLUSH DNS"         Style="{StaticResource BtnGhost}"/>
              <Button x:Name="BtnResetNet"     Content="[R] RESET ADAPTADOR"   Style="{StaticResource BtnGhost}"/>
              <Button x:Name="BtnClearShaders" Content="[S] LIMPIAR SHADERS"   Style="{StaticResource BtnGhost}"/>
            </StackPanel>

          </StackPanel>
        </ScrollViewer>
      </Border>

      <!-- CENTER: console -->
      <Border Grid.Column="1" Background="#05000a">
        <ScrollViewer x:Name="LogScroll" VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="LogPanel" Margin="14,8"/>
        </ScrollViewer>
      </Border>

      <!-- RIGHT: live monitor -->
      <Border Grid.Column="2" Background="#060010">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="12,12">
            <TextBlock Text="MONITOR" Foreground="#440055" FontWeight="Bold" FontSize="9" Margin="0,0,0,12"/>

            <!-- CPU: lbl | bar | pct -->
            <Grid Margin="0,0,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="26"/>
              </Grid.ColumnDefinitions>
              <TextBlock Text="CPU"  Foreground="#2a1540" FontSize="9" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonCpuBar" Text="░░░░░░░░░░░░░░░░░░░░" Foreground="#33cc66" FontSize="10" Grid.Column="1" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonCpuPct" Text="--"   Foreground="#33cc66" FontSize="9" FontWeight="Bold" Grid.Column="2" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
            <TextBlock x:Name="MonCpuInfo" Text="--" Foreground="#251035" FontSize="8" Margin="34,1,0,7" TextWrapping="Wrap"/>

            <!-- RAM -->
            <Grid Margin="0,0,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="26"/>
              </Grid.ColumnDefinitions>
              <TextBlock Text="RAM"  Foreground="#2a1540" FontSize="9" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonRamBar" Text="░░░░░░░░░░░░░░░░░░░░" Foreground="#33cc66" FontSize="10" Grid.Column="1" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonRamPct" Text="--"   Foreground="#33cc66" FontSize="9" FontWeight="Bold" Grid.Column="2" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
            <TextBlock x:Name="MonRamInfo" Text="--" Foreground="#251035" FontSize="8" Margin="34,1,0,7"/>

            <!-- GPU -->
            <Grid Margin="0,0,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="26"/>
              </Grid.ColumnDefinitions>
              <TextBlock Text="GPU"  Foreground="#2a1540" FontSize="9" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonGpuBar" Text="░░░░░░░░░░░░░░░░░░░░" Foreground="#33cc66" FontSize="10" Grid.Column="1" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonGpuPct" Text="--"   Foreground="#33cc66" FontSize="9" FontWeight="Bold" Grid.Column="2" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
            <TextBlock x:Name="MonGpuInfo" Text="--" Foreground="#251035" FontSize="8" Margin="34,1,0,7" TextWrapping="Wrap"/>

            <!-- TEMP -->
            <Grid Margin="0,0,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="34"/><ColumnDefinition Width="*"/><ColumnDefinition Width="26"/>
              </Grid.ColumnDefinitions>
              <TextBlock Text="TEMP" Foreground="#2a1540" FontSize="9" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonTempBar" Text="░░░░░░░░░░░░░░░░░░░░" Foreground="#33cc66" FontSize="10" Grid.Column="1" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonTempPct" Text="--"   Foreground="#33cc66" FontSize="9" FontWeight="Bold" Grid.Column="2" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
            <TextBlock x:Name="MonTempInfo" Text="--" Foreground="#251035" FontSize="8" Margin="34,1,0,10"/>

            <Rectangle Height="1" Fill="#0e0018" Margin="0,0,0,8"/>

            <!-- DISCO -->
            <Grid Margin="0,0,0,1">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="34"/><ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <TextBlock Text="DSK"  Foreground="#2a1540" FontSize="9" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonDiskBar" Text="░░░░░░░░░░░░░░░░░░░░" Foreground="#33cc66" FontSize="10" Grid.Column="1" VerticalAlignment="Center"/>
            </Grid>
            <TextBlock x:Name="MonDiskSpace" Text="-- / --"   Foreground="#251035" FontSize="8" Margin="34,1,0,1"/>
            <TextBlock x:Name="MonDiskIO"    Text="R --  W --" Foreground="#251035" FontSize="8" Margin="34,0,0,8"/>

            <!-- RED -->
            <Grid Margin="0,0,0,10">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="34"/><ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <TextBlock Text="NET" Foreground="#2a1540" FontSize="9" Margin="0,1,0,0"/>
              <StackPanel Grid.Column="1">
                <TextBlock x:Name="MonNetDown" Text="↓ --" Foreground="#251035" FontSize="9"/>
                <TextBlock x:Name="MonNetUp"   Text="↑ --" Foreground="#251035" FontSize="9"/>
              </StackPanel>
            </Grid>

            <Rectangle Height="1" Fill="#0e0018" Margin="0,0,0,8"/>

            <TextBlock x:Name="MonProc1" Text="--" Foreground="#251035" FontSize="9" Margin="0,0,0,2"/>
            <TextBlock x:Name="MonProc2" Text="--" Foreground="#251035" FontSize="9" Margin="0,0,0,2"/>
            <TextBlock x:Name="MonProc3" Text="--" Foreground="#251035" FontSize="9" Margin="0,0,0,8"/>

            <TextBlock x:Name="MonUptime"     Text="--" Foreground="#251035" FontSize="8" Margin="0,0,0,1"/>
            <TextBlock x:Name="MonLastUpdate" Text=""   Foreground="#140020" FontSize="8"/>
          </StackPanel>
        </ScrollViewer>
      </Border>

    </Grid>

    <!-- STATUS BAR -->
    <Border Grid.Row="3" Background="#070006" Padding="12,5">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="StatusBar"   Text="listo." Foreground="#440055" FontSize="10"/>
        <TextBlock x:Name="StatusRight" Text=""       Foreground="#330044" FontSize="10" Grid.Column="1"/>
      </Grid>
    </Border>

  </Grid>
</Window>
'@

# ---- Cargar XAML --------------------------------------------------------
$reader = [System.Xml.XmlNodeReader]::new([xml]$XAML)
$Window = [Windows.Markup.XamlReader]::Load($reader)

$TabSecurity     = $Window.FindName("TabSecurity")
$TabClean        = $Window.FindName("TabClean")
$TabGaming       = $Window.FindName("TabGaming")
$LogPanel        = $Window.FindName("LogPanel")
$LogScroll       = $Window.FindName("LogScroll")
$StatusBar       = $Window.FindName("StatusBar")
$StatusRight     = $Window.FindName("StatusRight")
$ScanProgress    = $Window.FindName("ScanProgress")
$SysInfo         = $Window.FindName("SysInfo")
$ClockText       = $Window.FindName("ClockText")
$DateText        = $Window.FindName("DateText")
$PanelSecurity   = $Window.FindName("PanelSecurity")
$PanelClean      = $Window.FindName("PanelClean")
$PanelGaming     = $Window.FindName("PanelGaming")
$BtnRunSecurity  = $Window.FindName("BtnRunSecurity")
$BtnFixAll       = $Window.FindName("BtnFixAll")
$BtnOpenLog      = $Window.FindName("BtnOpenLog")
$BtnRunClean     = $Window.FindName("BtnRunClean")
$ChkDISM         = $Window.FindName("ChkDISM")
$AdminWarning    = $Window.FindName("AdminWarning")
$BtnElevate      = $Window.FindName("BtnElevate")
$BtnGameCheck    = $Window.FindName("BtnGameCheck")
$BtnGameApply    = $Window.FindName("BtnGameApply")
$BtnGameRestore  = $Window.FindName("BtnGameRestore")
$BackupStatus    = $Window.FindName("BackupStatus")
$BtnKillProcs    = $Window.FindName("BtnKillProcs")
$BtnPingTest     = $Window.FindName("BtnPingTest")
$BtnSpeedTest    = $Window.FindName("BtnSpeedTest")
$MonCpuPct       = $Window.FindName("MonCpuPct")
$MonCpuBar       = $Window.FindName("MonCpuBar")
$MonCpuInfo      = $Window.FindName("MonCpuInfo")
$MonRamPct       = $Window.FindName("MonRamPct")
$MonRamBar       = $Window.FindName("MonRamBar")
$MonRamInfo      = $Window.FindName("MonRamInfo")
$MonGpuPct       = $Window.FindName("MonGpuPct")
$MonGpuBar       = $Window.FindName("MonGpuBar")
$MonGpuInfo      = $Window.FindName("MonGpuInfo")
$MonTempPct      = $Window.FindName("MonTempPct")
$MonTempBar      = $Window.FindName("MonTempBar")
$MonTempInfo     = $Window.FindName("MonTempInfo")
$MonDiskBar      = $Window.FindName("MonDiskBar")
$MonDiskSpace    = $Window.FindName("MonDiskSpace")
$MonDiskIO       = $Window.FindName("MonDiskIO")
$MonNetDown      = $Window.FindName("MonNetDown")
$MonNetUp        = $Window.FindName("MonNetUp")
$MonProc1        = $Window.FindName("MonProc1")
$MonProc2        = $Window.FindName("MonProc2")
$MonProc3        = $Window.FindName("MonProc3")
$MonUptime       = $Window.FindName("MonUptime")
$MonLastUpdate   = $Window.FindName("MonLastUpdate")
$BtnVFX          = $Window.FindName("BtnVFX")
$BtnFlushDNS     = $Window.FindName("BtnFlushDNS")
$BtnResetNet     = $Window.FindName("BtnResetNet")
$BtnClearShaders = $Window.FindName("BtnClearShaders")

# ---- Color helpers ------------------------------------------------------
$script:Brushes = @{}
function Get-Brush { param($hex)
    if (-not $script:Brushes[$hex]) {
        $script:Brushes[$hex] = [Windows.Media.BrushConverter]::new().ConvertFromString($hex)
    }
    $script:Brushes[$hex]
}

function ColorOf-Line { param($line)
    if ($line -match "^\s*\[OK\]")             { return "#33aa55" }
    if ($line -match "^\s*\[XX\]|CRITICO")     { return "#cc3355" }
    if ($line -match "^\s*\[!!\]")             { return "#cc8800" }
    if ($line -match "^\s*>>" )                { return "#7733aa" }
    if ($line -match "^\s*\[i\]|\[FIX\]")     { return "#443355" }
    if ($line -match "^\s*\[P\]|\[--\]|^  --" ) { return "#332244" }
    if ($line -match "REPORTE|^Equipo:")        { return "#7744bb" }
    return "#553377"
}

# ---- Monitor bar helpers ------------------------------------------------
function Make-Bar { param([int]$pct, [int]$w=20)
    $p = [Math]::Max(0,[Math]::Min(100,$pct))
    $f = [math]::Round($p/100*$w)
    ("█" * $f) + ("░" * ($w-$f))
}
function Bar-Color { param([int]$pct)
    if ($pct -lt 50) { "#33cc66" }
    elseif ($pct -lt 70) { "#99cc22" }
    elseif ($pct -lt 85) { "#ddaa22" }
    else { "#cc3355" }
}
function Format-BPS { param([double]$kbps)
    if ($kbps -ge 1024) { return "$([math]::Round($kbps/1024,1)) MB/s" }
    if ($kbps -ge 1)    { return "$([math]::Round($kbps,0)) KB/s" }
    return "$([math]::Round($kbps*1024,0)) B/s"
}

# ---- Log helpers --------------------------------------------------------
function Add-LogLine {
    param([string]$Text, [string]$Color = "#664488",
          [switch]$Bold, [string]$FixCmd = "")

    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = "Horizontal"
    $sp.Margin      = "0,0,0,0"

    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text         = $Text
    $tb.Foreground   = Get-Brush $Color
    $tb.TextWrapping = "Wrap"
    $tb.FontSize     = 11
    $tb.MaxWidth     = 540
    if ($Bold) { $tb.FontWeight = "SemiBold" }
    $sp.Children.Add($tb) | Out-Null

    if ($FixCmd) {
        $btn             = New-Object Windows.Controls.Button
        $btn.Content     = " fix "
        $btn.Style       = $Window.Resources["BtnFix"]
        $btn.Margin      = "8,0,0,0"
        $btn.Tag         = $FixCmd
        $btn.VerticalAlignment = "Center"
        $btn.Add_Click({
            param($s,$e)
            $s.IsEnabled = $false; $s.Content = "..."
            try {
                & ([scriptblock]::Create($s.Tag)) | Out-Null
                $s.Content = "[ok]"; $s.Background = Get-Brush "#1a7a3a"
            } catch { $s.Content = "[err]" }
        })
        $sp.Children.Add($btn) | Out-Null
    }

    $LogPanel.Children.Add($sp) | Out-Null
    $LogScroll.ScrollToBottom()
}

function Add-LogSection { param([string]$Title)
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Margin = "0,14,0,6"
    $line = New-Object Windows.Controls.Rectangle
    $line.Height = 1; $line.Fill = Get-Brush "#1a0028"; $line.Margin = "0,0,0,5"
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text       = $Title.ToUpper()
    $tb.Foreground = Get-Brush "#440055"
    $tb.FontSize   = 9
    $tb.FontWeight = "Bold"
    $sp.Children.Add($line) | Out-Null
    $sp.Children.Add($tb)   | Out-Null
    $LogPanel.Children.Add($sp) | Out-Null
}

function Add-SummaryCard { param([int]$Ok, [int]$Warn, [int]$Crit, [string]$Duration)
    $bgHex = if ($Crit -gt 0){"#160008"} elseif ($Warn -gt 0){"#120010"} else {"#060e08"}
    $bdHex = if ($Crit -gt 0){"#aa2255"} elseif ($Warn -gt 0){"#aaaa22"} else {"#225533"}

    $outer = New-Object Windows.Controls.Border
    $outer.Margin = "0,12,0,6"; $outer.Padding = "14,10"; $outer.CornerRadius = "4"
    $outer.Background = Get-Brush $bgHex
    $outer.BorderBrush = Get-Brush $bdHex; $outer.BorderThickness = "1"

    $grid = New-Object Windows.Controls.Grid
    for ($i=0;$i-lt4;$i++){$col=New-Object Windows.Controls.ColumnDefinition;$col.Width="1*";$grid.ColumnDefinitions.Add($col)}

    function Add-Stat { param($g,$col,$val,$lbl,$clr)
        $sp=New-Object Windows.Controls.StackPanel;$sp.HorizontalAlignment="Center"
        [Windows.Controls.Grid]::SetColumn($sp,$col)
        $n=New-Object Windows.Controls.TextBlock;$n.Text=$val;$n.FontSize=20
        $n.FontWeight="Bold";$n.HorizontalAlignment="Center";$n.Foreground=Get-Brush $clr
        $l=New-Object Windows.Controls.TextBlock;$l.Text=$lbl;$l.FontSize=9
        $l.HorizontalAlignment="Center";$l.Foreground=Get-Brush "#440055"
        $sp.Children.Add($n)|Out-Null;$sp.Children.Add($l)|Out-Null;$g.Children.Add($sp)|Out-Null
    }
    Add-Stat $grid 0 $Ok       "OK"       "#44bb66"
    Add-Stat $grid 1 $Warn     "WARNINGS" "#ddaa22"
    Add-Stat $grid 2 $Crit     "CRITICOS" "#cc3355"
    Add-Stat $grid 3 $Duration "DURACION" "#9944cc"
    $outer.Child = $grid
    $LogPanel.Children.Add($outer) | Out-Null
    $LogScroll.ScrollToBottom()
}

function Add-SpeedCard { param([double]$Down,[double]$Up,[int]$Lat,[int]$Jitter,[string]$Duration)
    function Spd-Color { param([double]$m)
        if ($m -ge 100){"#44ffaa"} elseif($m-ge50){"#44bb66"} elseif($m-ge20){"#99cc22"} elseif($m-ge5){"#ddaa22"} else{"#cc3355"}
    }
    function Spd-Label { param([double]$m)
        if ($m -ge 100){"EXCELENTE"} elseif($m-ge50){"muy bueno"} elseif($m-ge20){"bueno"} elseif($m-ge5){"aceptable"} else{"lento"}
    }
    function Lat-Color { param([int]$ms)
        if ($ms -lt 25){"#44ffaa"} elseif($ms-lt60){"#44bb66"} elseif($ms-lt100){"#ddaa22"} else{"#cc3355"}
    }
    function Lat-Label { param([int]$ms)
        if ($ms -lt 25){"excelente"} elseif($ms-lt60){"bueno"} elseif($ms-lt100){"aceptable"} else{"alto"}
    }
    function Jit-Color { param([int]$j)
        if ($j -lt 5){"#44bb66"} elseif($j-lt15){"#ddaa22"} else{"#cc3355"}
    }
    function Jit-Label { param([int]$j)
        if ($j -lt 5){"estable"} elseif($j-lt15){"normal"} else{"inestable"}
    }

    $outer = New-Object Windows.Controls.Border
    $outer.Margin = "0,14,0,6"; $outer.Padding = "16,14"; $outer.CornerRadius = "6"
    $outer.Background = Get-Brush "#050810"
    $outer.BorderBrush = Get-Brush "#1a3366"; $outer.BorderThickness = "1"

    $root = New-Object Windows.Controls.StackPanel

    $ttl = New-Object Windows.Controls.TextBlock
    $ttl.Text = "SPEED TEST  //  CLOUDFLARE"; $ttl.FontSize = 10; $ttl.FontWeight = "Bold"
    $ttl.HorizontalAlignment = "Center"; $ttl.Margin = "0,0,0,12"
    $ttl.Foreground = Get-Brush "#2244aa"
    $root.Children.Add($ttl) | Out-Null

    $grid = New-Object Windows.Controls.Grid
    for ($i=0;$i-lt4;$i++){ $c=New-Object Windows.Controls.ColumnDefinition; $c.Width="1*"; $grid.ColumnDefinitions.Add($c) }

    function Add-SpeedStat { param($G,$Col,$Big,$Unit,$Lbl,$Sub,$Clr)
        $cell = New-Object Windows.Controls.StackPanel; $cell.HorizontalAlignment="Center"
        [Windows.Controls.Grid]::SetColumn($cell,$Col)
        $vt = New-Object Windows.Controls.TextBlock; $vt.Text=$Big; $vt.FontSize=30; $vt.FontWeight="Bold"
        $vt.HorizontalAlignment="Center"; $vt.Foreground=Get-Brush $Clr
        $ut = New-Object Windows.Controls.TextBlock; $ut.Text=$Unit; $ut.FontSize=11; $ut.FontWeight="Bold"
        $ut.HorizontalAlignment="Center"; $ut.Foreground=Get-Brush $Clr; $ut.Margin="0,-2,0,0"
        $lt = New-Object Windows.Controls.TextBlock; $lt.Text=$Lbl; $lt.FontSize=9
        $lt.HorizontalAlignment="Center"; $lt.Foreground=Get-Brush "#440055"; $lt.Margin="0,4,0,0"
        $st = New-Object Windows.Controls.TextBlock; $st.Text=$Sub; $st.FontSize=8
        $st.HorizontalAlignment="Center"; $st.Foreground=Get-Brush "#336622"
        $cell.Children.Add($vt)|Out-Null; $cell.Children.Add($ut)|Out-Null
        $cell.Children.Add($lt)|Out-Null; $cell.Children.Add($st)|Out-Null
        $G.Children.Add($cell)|Out-Null
    }

    $dRound = [math]::Round($Down,1); $uRound = [math]::Round($Up,1)
    Add-SpeedStat $grid 0 $dRound       "Mbps" "DESCARGA"  (Spd-Label $Down)   (Spd-Color $Down)
    Add-SpeedStat $grid 1 $uRound       "Mbps" "SUBIDA"    (Spd-Label $Up)     (Spd-Color $Up)
    Add-SpeedStat $grid 2 "$Lat"        "ms"   "LATENCIA"  (Lat-Label $Lat)    (Lat-Color $Lat)
    Add-SpeedStat $grid 3 "$Jitter"     "ms"   "JITTER"    (Jit-Label $Jitter) (Jit-Color $Jitter)
    $root.Children.Add($grid) | Out-Null

    $sep = New-Object Windows.Controls.Border; $sep.Height=1; $sep.Margin="0,12,0,8"
    $sep.Background=Get-Brush "#111a33"
    $root.Children.Add($sep) | Out-Null

    $foot = New-Object Windows.Controls.TextBlock
    $foot.Text = "completado en $Duration  //  speed.cloudflare.com"
    $foot.FontSize=9; $foot.HorizontalAlignment="Center"; $foot.Foreground=Get-Brush "#222840"
    $root.Children.Add($foot) | Out-Null

    $outer.Child = $root
    $LogPanel.Children.Add($outer) | Out-Null
    $LogScroll.ScrollToBottom()
}

function Clear-Log {
    $LogPanel.Children.Clear()
    while (-not $script:_PrintQueue.IsEmpty) {
        $x = [hashtable]$null; $script:_PrintQueue.TryDequeue([ref]$x) | Out-Null
    }
}

# ---- Print timer --------------------------------------------------------
function Ensure-PrintTimer {
    if ($script:_PrintTimer -and $script:_PrintTimer.IsEnabled) { return }
    $script:_PrintTimer = New-Object Windows.Threading.DispatcherTimer
    $script:_PrintTimer.Interval = [TimeSpan]::FromMilliseconds(75)
    $script:_PrintTimer.Add_Tick({
        $item = [hashtable]$null
        if (-not $script:_PrintQueue.TryDequeue([ref]$item)) { return }
        switch ($item.Type) {
            "Line"    { Add-LogLine $item.Text $item.Color -FixCmd $item.Fix }
            "Section" { Add-LogSection $item.Title }
            "Summary"   { Add-SummaryCard $item.Ok $item.Warn $item.Crit $item.Duration }
            "SpeedCard" { Add-SpeedCard $item.Down $item.Up $item.Lat $item.Jitter $item.Duration }
            "Done"    {
                $ScanProgress.Visibility = "Collapsed"
                $StatusRight.Text = (Get-Date -Format "HH:mm:ss")
                if ($item.OnDone -and $item.Result) { & $item.OnDone $item.Result }
                elseif ($item.OnDone -and -not $item.Result) { & $item.OnDone $null }
            }
        }
    })
    $script:_PrintTimer.Start()
}

function Q-Line { param($text,$color,$fix="")
    if ($text -match "^\s*\[OK\]")             { $script:_OkCount++ }
    elseif ($text -match "^\s*\[!!\]")         { $script:_WarnCount++ }
    elseif ($text -match "^\s*\[XX\]|CRITICO") { $script:_CritCount++ }
    $script:_PrintQueue.Enqueue(@{Type="Line";Text=$text;Color=$color;Fix=$fix})
}
function Q-Section { param($title)
    $script:_PrintQueue.Enqueue(@{Type="Section";Title=$title})
}
function Q-Done { param($result,$elapsed,$onDone)
    $script:_PrintQueue.Enqueue(@{
        Type="Summary";Ok=$script:_OkCount;Warn=$script:_WarnCount;
        Crit=$script:_CritCount;Duration="${elapsed}s"
    })
    $script:_PrintQueue.Enqueue(@{Type="Done";Result=$result;OnDone=$onDone})
}

function Show-Splash {
    $script:_PrintQueue.Enqueue(@{Type="Line";Text="";Color="#330044";Fix=""})
    foreach ($line in $script:AsciiSkull) {
        $script:_PrintQueue.Enqueue(@{Type="Line";Text="  $line";Color="#7700bb";Fix=""})
    }
    $script:_PrintQueue.Enqueue(@{Type="Line";Text="";Color="#330044";Fix=""})
    foreach ($line in $script:AsciiIRREBOY) {
        $script:_PrintQueue.Enqueue(@{Type="Line";Text="  $line";Color="#cc66ff";Fix=""})
    }
    $script:_PrintQueue.Enqueue(@{Type="Line";Text="";Color="#330044";Fix=""})
    $script:_PrintQueue.Enqueue(@{Type="Line";Text="  [ PC TOOLKIT v3.0 ]   //   BY IRREBOY";Color="#aa44ff";Fix=""})
    $script:_PrintQueue.Enqueue(@{Type="Line";Text="  -------------------------------------------";Color="#330044";Fix=""})
    $adminTxt = if ($script:IsAdmin) { "  modo: ADMINISTRADOR" } else { "  modo: usuario normal  [Gaming boost limitado]" }
    $adminClr = if ($script:IsAdmin) { "#44bb66" } else { "#ddaa22" }
    $script:_PrintQueue.Enqueue(@{Type="Line";Text=$adminTxt;Color=$adminClr;Fix=""})
    $script:_PrintQueue.Enqueue(@{Type="Line";Text="";Color="#330044";Fix=""})
}

# ---- Streaming engine ---------------------------------------------------
function Read-StreamLines { param([string]$path)
    if (-not (Test-Path $path)) { return @() }
    try {
        $fs = New-Object System.IO.FileStream($path,
            [System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
        $sr = New-Object System.IO.StreamReader($fs,[System.Text.Encoding]::UTF8)
        $content = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
        return ($content -split "`r?`n")
    } catch { return @() }
}

$script:_InitScript = { Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue }

function Invoke-StreamedJob {
    param([string]$Label,[scriptblock]$Job,[object[]]$JobArgs,[scriptblock]$OnDone)

    if ($script:_Job -and $script:_Job.State -eq "Running") {
        Q-Line "  [!!]  Ya hay una operacion en curso." "#ddaa22"; return
    }

    $script:_StreamFile  = [System.IO.Path]::GetTempFileName()
    $script:_LastLineIdx = 0
    $script:_OkCount = 0; $script:_WarnCount = 0; $script:_CritCount = 0
    $script:_StartTime = Get-Date

    $ScanProgress.Visibility = "Visible"
    $StatusBar.Text = $Label

    $allArgs = $JobArgs + @($script:_StreamFile)
    $initSb  = $script:_InitScript
    $script:_Job = Start-Job -InitializationScript $initSb -ScriptBlock $Job -ArgumentList $allArgs

    if ($script:_Timer -and $script:_Timer.IsEnabled) { $script:_Timer.Stop() }

    $onDoneCapture = $OnDone
    $script:_Timer = New-Object Windows.Threading.DispatcherTimer
    $script:_Timer.Interval = [TimeSpan]::FromMilliseconds(120)
    $script:_Timer.Add_Tick({
        if ($script:_StreamFile) {
            $lines = Read-StreamLines $script:_StreamFile
            for ($i = $script:_LastLineIdx; $i -lt $lines.Count; $i++) {
                $l = $lines[$i]; if (-not $l.Trim()) { $script:_LastLineIdx++; continue }
                if ($l -match "^=SECTION=(.+)") { Q-Section $matches[1].Trim() }
                else {
                    $fixCmd = ""
                    foreach ($a in $script:LastAlerts) {
                        if ($a.FixCmd -and $l.Length -gt 5) {
                            $snip = $a.Msg -replace '[^\w ]',''; $snip = $snip.Substring(0,[Math]::Min(15,$snip.Length))
                            if ($snip -and $l -match [regex]::Escape($snip)) { $fixCmd = $a.FixCmd; break }
                        }
                    }
                    Q-Line $l (ColorOf-Line $l) $fixCmd
                }
                $script:_LastLineIdx++
            }
        }
        if ($script:_Job -and $script:_Job.State -in "Completed","Failed","Stopped") {
            $script:_Timer.Stop()
            if ($script:_StreamFile) {
                $lines = Read-StreamLines $script:_StreamFile
                for ($i = $script:_LastLineIdx; $i -lt $lines.Count; $i++) {
                    $l = $lines[$i]; if (-not $l.Trim()) { continue }
                    if ($l -match "^=SECTION=(.+)") { Q-Section $matches[1].Trim() }
                    else { Q-Line $l (ColorOf-Line $l) }
                }
                Remove-Item $script:_StreamFile -ErrorAction SilentlyContinue
                $script:_StreamFile = ""
            }
            $result = $null
            try { $result = Receive-Job $script:_Job -ErrorAction Stop }
            catch {
                $errMsg = $_.ToString()
                Q-Line "  [XX]  Error en job: $errMsg" "#cc3355"
                Q-Line "  [i]   Revisa que el script exista y tenga permisos." "#9944cc"
            }
            Remove-Job $script:_Job -ErrorAction SilentlyContinue
            $script:_Job = $null
            $elapsed = [math]::Round(((Get-Date)-$script:_StartTime).TotalSeconds,1)
            Q-Done $result $elapsed $onDoneCapture
        }
    })
    $script:_Timer.Start()
}

# ---- Monitor job --------------------------------------------------------
function Start-MonitorJob {
    if ($script:_MonJob) { return }
    $script:_MonStream = [System.IO.Path]::GetTempFileName()
    $sf = $script:_MonStream

    $script:_MonJob = Start-Job -InitializationScript { Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue } -ScriptBlock {
        param($sf)
        function W { param($l)
            try {
                $fs = New-Object System.IO.FileStream($sf,
                    [System.IO.FileMode]::Append,[System.IO.FileAccess]::Write,[System.IO.FileShare]::ReadWrite)
                $sw = New-Object System.IO.StreamWriter($fs,[System.Text.Encoding]::UTF8)
                $sw.WriteLine($l); $sw.Flush(); $sw.Close()
            } catch {}
        }

        $iter = 0
        while ($true) {
            # CPU
            $cpu = 0
            try { $cpu = [math]::Round((Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop).PercentProcessorTime) } catch {}
            W "|M|cpu=$cpu"

            # RAM
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) {
                $free = [math]::Round($os.FreePhysicalMemory/1MB,1)
                $tot  = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
                $used = [math]::Round($tot-$free,1)
                $pct  = [math]::Round($used/$tot*100)
                W "|M|ram=$pct|ramUsed=$used|ramTot=$tot"
            }

            # GPU
            try {
                $gs = (Get-Counter '\GPU Engine(*engtype_3D*)\Utilization Percentage' -ErrorAction Stop).CounterSamples
                $gp = [Math]::Min(100,[math]::Round(($gs|Measure-Object CookedValue -Sum).Sum))
            } catch { $gp = -1 }
            W "|M|gpu=$gp"

            # TEMP
            try {
                $tk = (Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop).CurrentTemperature
                $tc = [math]::Round(($tk|Measure-Object -Maximum).Maximum/10-273.15)
            } catch { $tc = -1 }
            W "|M|temp=$tc"

            # DISK IO
            try {
                $dk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_LogicalDisk -Filter "Name='_Total'" -ErrorAction Stop
                $dR = [math]::Round($dk.DiskReadBytesPersec/1MB,1)
                $dW = [math]::Round($dk.DiskWriteBytesPersec/1MB,1)
            } catch { $dR=0; $dW=0 }
            W "|M|diskR=$dR|diskW=$dW"

            # NETWORK
            try {
                $nk = Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction Stop
                $nR = [math]::Round(($nk|Measure-Object BytesReceivedPersec -Sum).Sum/1KB,1)
                $nT = [math]::Round(($nk|Measure-Object BytesSentPersec -Sum).Sum/1KB,1)
            } catch { $nR=0; $nT=0 }
            W "|M|netRx=$nR|netTx=$nT"

            # TOP PROCESSES (every 4 iterations = 8s)
            if ($iter % 4 -eq 0) {
                try {
                    $nc = [System.Environment]::ProcessorCount
                    $procs = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
                        Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' } |
                        Sort-Object PercentProcessorTime -Descending |
                        Select-Object -First 3
                    $pi = 0
                    foreach ($p in $procs) {
                        $pct2 = [math]::Min(100,[math]::Round($p.PercentProcessorTime / [Math]::Max(1,$nc)))
                        W "|M|proc${pi}n=$($p.Name)|proc${pi}c=$pct2"
                        $pi++
                    }
                } catch {}
            }

            # DISK SPACE + UPTIME (every 15 iterations = 30s)
            if ($iter % 15 -eq 0) {
                try {
                    $drv = Get-PSDrive C -ErrorAction Stop
                    $usedGB = [math]::Round($drv.Used/1GB,0)
                    $freeGB = [math]::Round($drv.Free/1GB,0)
                    $totGB  = $usedGB + $freeGB
                    $dpct   = if ($totGB -gt 0) { [math]::Round($usedGB/$totGB*100) } else { 0 }
                    W "|M|diskPct=$dpct|diskUsedGB=$usedGB|diskFreeGB=$freeGB|diskTotGB=$totGB"
                } catch {}

                try {
                    $os2 = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
                    $up  = (Get-Date) - $os2.LastBootUpTime
                    $upStr = if ($up.Days -gt 0) { "$($up.Days)d $($up.Hours)h $($up.Minutes)m" }
                             elseif ($up.Hours -gt 0) { "$($up.Hours)h $($up.Minutes)m" }
                             else { "$($up.Minutes)m $($up.Seconds)s" }
                    W "|M|uptime=$upStr"
                } catch {}
            }

            $iter++
            Start-Sleep -Seconds 2
        }
    } -ArgumentList $sf

    $script:_MonTimer = New-Object Windows.Threading.DispatcherTimer
    $script:_MonTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:_MonTimer.Add_Tick({ Update-MonitorDisplay })
    $script:_MonTimer.Start()
}

function Update-MonitorDisplay {
    if (-not $script:_MonStream -or -not (Test-Path $script:_MonStream)) { return }
    try {
        $fs = New-Object System.IO.FileStream($script:_MonStream,
            [System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
        $sr = New-Object System.IO.StreamReader($fs,[System.Text.Encoding]::UTF8)
        $cnt = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
    } catch { return }

    foreach ($line in ($cnt -split "`r?`n")) {
        if ($line -match "^\|M\|") {
            foreach ($kv in ($line.Substring(3) -split '\|')) {
                if ($kv -match '^([^=]+)=(.+)$') { $script:_MonData[$matches[1]] = $matches[2] }
            }
        }
    }

    $d = $script:_MonData

    # CPU
    if ($null -ne $d["cpu"]) {
        $p = [int]$d["cpu"]
        $c = Bar-Color $p
        $MonCpuBar.Text       = Make-Bar $p
        $MonCpuBar.Foreground = Get-Brush $c
        $MonCpuPct.Text       = "$p%"
        $MonCpuPct.Foreground = Get-Brush $c
        $MonCpuInfo.Text      = "procesador principal"
    }

    # RAM
    if ($null -ne $d["ram"]) {
        $p = [int]$d["ram"]
        $c = Bar-Color $p
        $MonRamBar.Text       = Make-Bar $p
        $MonRamBar.Foreground = Get-Brush $c
        $MonRamPct.Text       = "$p%"
        $MonRamPct.Foreground = Get-Brush $c
        $MonRamInfo.Text      = "$($d['ramUsed']) GB / $($d['ramTot']) GB"
    }

    # GPU
    if ($null -ne $d["gpu"]) {
        $p = [int]$d["gpu"]
        if ($p -ge 0) {
            $c = Bar-Color $p
            $MonGpuBar.Text       = Make-Bar $p
            $MonGpuBar.Foreground = Get-Brush $c
            $MonGpuPct.Text       = "$p%"
            $MonGpuPct.Foreground = Get-Brush $c
            $MonGpuInfo.Text      = "GPU 3D engine"
        } else {
            $MonGpuBar.Text = "░░░░░░░░░░░░░░░░░░░░"
            $MonGpuPct.Text = "n/a"
            $MonGpuInfo.Text = "driver sin soporte PDH"
        }
    }

    # TEMP
    if ($null -ne $d["temp"]) {
        $t = [int]$d["temp"]
        if ($t -ge 0) {
            $p = [Math]::Min(100,[math]::Round($t/110*100))
            $c = Bar-Color $p
            $MonTempBar.Text       = Make-Bar $p
            $MonTempBar.Foreground = Get-Brush $c
            $MonTempPct.Text       = "${t}°C"
            $MonTempPct.Foreground = Get-Brush $c
            $st = if ($t -lt 60){"OK - sistema frio"} elseif ($t -lt 80){"CALIENTE - considera limpieza"} else {"CRITICO - revisa ventilacion"}
            $MonTempInfo.Text      = $st
            $MonTempInfo.Foreground = Get-Brush $c
        } else {
            $MonTempBar.Text = "░░░░░░░░░░░░░░░░░░░░"
            $MonTempPct.Text = "--"
            $MonTempInfo.Text = "sensor no disponible"
        }
    }

    # DISK IO
    if ($null -ne $d["diskR"]) {
        $rStr = if ([double]$d['diskR'] -gt 0) { "$($d['diskR']) MB/s" } else { "0 MB/s" }
        $wStr = if ([double]$d['diskW'] -gt 0) { "$($d['diskW']) MB/s" } else { "0 MB/s" }
        $MonDiskIO.Text = "R $rStr    W $wStr"
    }

    # DISK SPACE
    if ($null -ne $d["diskPct"]) {
        $p = [int]$d["diskPct"]
        $c = Bar-Color $p
        $MonDiskBar.Text       = Make-Bar $p
        $MonDiskBar.Foreground = Get-Brush $c
        $MonDiskSpace.Text     = "$($d['diskUsedGB']) GB usado  /  $($d['diskTotGB']) GB total  ($p%)"
    }

    # NETWORK
    if ($null -ne $d["netRx"]) {
        $rx = [double]$d["netRx"]; $tx = [double]$d["netTx"]
        $rxC = if ($rx -gt 512) { "#ddaa22" } else { "#4a2266" }
        $txC = if ($tx -gt 512) { "#ddaa22" } else { "#4a2266" }
        $MonNetDown.Text       = "↓  $(Format-BPS $rx)"
        $MonNetUp.Text         = "↑  $(Format-BPS $tx)"
        $MonNetDown.Foreground = Get-Brush $rxC
        $MonNetUp.Foreground   = Get-Brush $txC
    }

    # TOP PROCESSES
    $procTexts = @($MonProc1,$MonProc2,$MonProc3)
    for ($pi=0; $pi -lt 3; $pi++) {
        $n = $d["proc${pi}n"]; $c2 = $d["proc${pi}c"]
        if ($n -and $c2) {
            $pct3 = [int]$c2
            $barC = Bar-Color $pct3
            $nameShort = if ($n.Length -gt 16) { $n.Substring(0,14)+".." } else { $n }
            $procTexts[$pi].Text       = "$nameShort  $pct3%"
            $procTexts[$pi].Foreground = Get-Brush $barC
        }
    }

    # UPTIME
    if ($null -ne $d["uptime"]) {
        $MonUptime.Text = "uptime: $($d['uptime'])"
    }

    $MonLastUpdate.Text = "update: $(Get-Date -Format 'HH:mm:ss')"
}

# ---- Tray ---------------------------------------------------------------
function Setup-Tray {
    $ni = New-Object System.Windows.Forms.NotifyIcon
    try {
        $bmp = New-Object System.Drawing.Bitmap 16,16
        $g   = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $br  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(153,34,204))
        $g.FillEllipse($br,1,1,14,14); $g.Dispose()
        $ni.Icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    } catch { $ni.Icon = [System.Drawing.SystemIcons]::Application }
    $ni.Text = "PC Toolkit // IRREBOY"; $ni.Visible = $true

    $ctx   = New-Object System.Windows.Forms.ContextMenuStrip
    $mShow = $ctx.Items.Add("[>]  Mostrar")
    $mShow.ForeColor = [System.Drawing.Color]::MediumPurple
    $mShow.Add_Click({ $Window.Show(); $Window.WindowState = "Normal"; $Window.Activate() })
    $mScan = $ctx.Items.Add("[S]  Escanear Seguridad")
    $mScan.Add_Click({
        $Window.Show(); $Window.WindowState = "Normal"; Switch-Tab "Security"
        $BtnRunSecurity.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    })
    $mClean = $ctx.Items.Add("[C]  Limpiar PC")
    $mClean.Add_Click({
        $Window.Show(); $Window.WindowState = "Normal"; Switch-Tab "Clean"
        $BtnRunClean.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))
    })
    $ctx.Items.Add("-") | Out-Null
    $mExit = $ctx.Items.Add("[X]  Salir")
    $mExit.Add_Click({
        $script:_TrayExit = $true
        if ($script:_MonJob) { Stop-Job $script:_MonJob -ErrorAction SilentlyContinue; Remove-Job $script:_MonJob -ErrorAction SilentlyContinue }
        $ni.Visible = $false; $ni.Dispose(); $Window.Close()
    })
    $ni.ContextMenuStrip = $ctx
    $ni.Add_DoubleClick({ $Window.Show(); $Window.WindowState = "Normal"; $Window.Activate() })
    $script:_Tray = $ni

    $Window.Add_Closing({
        param($s,$e)
        if (-not $script:_TrayExit) { $e.Cancel = $true; $Window.Hide() }
    })
}

# ---- Tabs ---------------------------------------------------------------
function Switch-Tab { param([string]$Tab)
    $script:ActiveTab = $Tab
    $off = $Window.Resources["SideTabBtn"]
    $on  = $Window.Resources["SideTabActive"]
    $TabSecurity.Style = $off; $TabClean.Style = $off; $TabGaming.Style = $off
    $PanelSecurity.Visibility = "Collapsed"
    $PanelClean.Visibility    = "Collapsed"
    $PanelGaming.Visibility   = "Collapsed"
    switch ($Tab) {
        "Security" { $TabSecurity.Style = $on; $PanelSecurity.Visibility = "Visible" }
        "Clean"    { $TabClean.Style    = $on; $PanelClean.Visibility    = "Visible" }
        "Gaming"   {
            $TabGaming.Style = $on; $PanelGaming.Visibility = "Visible"
            if (-not $script:IsAdmin) {
                $AdminWarning.Visibility = "Visible"
            } else {
                $AdminWarning.Visibility = "Collapsed"
            }
            $bk = "$ScriptsDir\GameBoost_Backup.json"
            if (Test-Path $bk) {
                $d = (Get-Content $bk -Raw | ConvertFrom-Json).Timestamp
                $BackupStatus.Text = "backup: $($d.Substring(0,10))"; $BackupStatus.Foreground = Get-Brush "#44bb66"
            } else {
                $BackupStatus.Text = "sin backup"; $BackupStatus.Foreground = Get-Brush "#440033"
            }
        }
    }
}

$TabSecurity.Add_Click({ Switch-Tab "Security" })
$TabClean.Add_Click({    Switch-Tab "Clean" })
$TabGaming.Add_Click({   Switch-Tab "Gaming" })

# ---- ELEVATE ------------------------------------------------------------
$BtnElevate.Add_Click({
    $thisScript = "$ScriptsDir\PCToolkit.ps1"
    try {
        Start-Process powershell.exe `
            -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$thisScript`"" `
            -Verb RunAs
        $script:_TrayExit = $true
        if ($script:_Tray) { $script:_Tray.Visible = $false; $script:_Tray.Dispose() }
        $Window.Close()
    } catch {
        Add-LogLine "  [!!]  UAC cancelado o no disponible: $_" "#ddaa22"
    }
})

# ---- SECURITY -----------------------------------------------------------
$BtnRunSecurity.Add_Click({
    Add-LogSection "SEGURIDAD"
    Add-LogLine ">> iniciando chequeo de seguridad..." "#9922cc" -Bold
    $BtnRunSecurity.IsEnabled = $false; $BtnFixAll.IsEnabled = $false; $BtnOpenLog.IsEnabled = $false
    $dir = $ScriptsDir
    Invoke-StreamedJob -Label "escaneando sistema..." `
        -Job { param($d,$sf) & "$d\SecurityCheck.ps1" -Silent -StreamFile $sf } `
        -JobArgs @($dir) `
        -OnDone {
            param($resultRaw)
            # SecurityCheck returns strings + PSCustomObject; extract the object
            $result = if ($resultRaw -is [array]) {
                $resultRaw | Where-Object { $_ -is [PSCustomObject] -and $_.PSObject.Properties['Alerts'] } | Select-Object -Last 1
            } else { $resultRaw }

            if ($result -and $result.PSObject.Properties['Alerts']) {
                $script:LastAlerts = $result.Alerts; $script:LastLogFile = $result.LogFile
                $n = $result.Alerts.Count
                if ($n -gt 0) {
                    $BtnFixAll.IsEnabled = $true
                    $StatusBar.Text = "$n alerta(s) - usa [!] APLICAR FIXES o los botones 'fix' junto a cada linea."
                } else {
                    $StatusBar.Text = "sistema limpio. Sin alertas."
                }
                $BtnOpenLog.IsEnabled = $true
            } else {
                $StatusBar.Text = "chequeo completado."
                $BtnOpenLog.IsEnabled = $true
            }
            $BtnRunSecurity.IsEnabled = $true
        }
})

$BtnFixAll.Add_Click({
    $fixables = $script:LastAlerts | Where-Object { $_.FixCmd }
    if (-not $fixables) { $StatusBar.Text = "sin fixes disponibles."; return }
    $BtnFixAll.IsEnabled = $false
    Add-LogSection "APLICANDO FIXES"
    $count = 0
    foreach ($a in $fixables) {
        try {
            Add-LogLine "  [i]   aplicando: $($a.Msg)" "#9944cc"
            & ([scriptblock]::Create($a.FixCmd)) | Out-Null
            Add-LogLine "  [OK]  fix aplicado: $($a.Msg)" "#44bb66"
            $count++
        } catch {
            Add-LogLine "  [XX]  error en fix: $($a.Msg) - $_" "#cc3355"
        }
    }
    Add-LogLine "  [OK]  $count fix(es) aplicado(s). Vuelve a escanear para verificar." "#44bb66"
    $StatusBar.Text = "$count fix(es) aplicado(s). Ejecuta el chequeo de nuevo para verificar."
    $BtnRunSecurity.IsEnabled = $true
    $BtnFixAll.IsEnabled = $false
})

$BtnOpenLog.Add_Click({
    if ($script:LastLogFile -and (Test-Path $script:LastLogFile)) { Start-Process notepad.exe $script:LastLogFile }
})

# ---- CLEAN --------------------------------------------------------------
$BtnRunClean.Add_Click({
    Add-LogSection "LIMPIEZA"
    Add-LogLine ">> iniciando limpieza de PC..." "#9922cc" -Bold
    $BtnRunClean.IsEnabled = $false; $dism = $ChkDISM.IsChecked; $dir = $ScriptsDir
    Invoke-StreamedJob -Label "limpiando sistema..." `
        -Job {
            param($d,$dism,$sf)
            if ($dism) { & "$d\CleanPC.ps1" -Silent -IncludeDISM -StreamFile $sf }
            else       { & "$d\CleanPC.ps1" -Silent -StreamFile $sf }
        } `
        -JobArgs @($dir,$dism) `
        -OnDone {
            param($result)
            if ($result) { $StatusBar.Text = "limpieza completa: $($result.TotalGB) GB liberados." }
            else         { $StatusBar.Text = "limpieza completada." }
            $BtnRunClean.IsEnabled = $true
        }
})

# ---- GAMING -------------------------------------------------------------
function Run-GameScript { param([string]$Mode)
    if ($Mode -in "Apply","Restore" -and -not $script:IsAdmin) {
        Add-LogSection "GAMING BOOST - $Mode"
        Add-LogLine "  [XX]  Requiere permisos de Administrador." "#cc3355" -Bold
        Add-LogLine "  [i]   Usa el boton [^] REINICIAR COMO ADMIN en el panel izquierdo." "#9944cc"
        Add-LogLine "  [i]   El modo [?] ESTADO ACTUAL funciona sin admin." "#9944cc"
        $StatusBar.Text = "gaming boost requiere admin para Apply/Restore."
        return
    }

    Add-LogSection "GAMING BOOST - $Mode"
    Add-LogLine ">> gameboost modo: $Mode" "#9922cc" -Bold
    $BtnGameCheck.IsEnabled = $false; $BtnGameApply.IsEnabled = $false; $BtnGameRestore.IsEnabled = $false
    $dir = $ScriptsDir
    Invoke-StreamedJob -Label "ejecutando gameboost $Mode..." `
        -Job { param($d,$m,$sf) & "$d\GameBoost.ps1" -Mode $m -Silent -StreamFile $sf } `
        -JobArgs @($dir,$Mode) `
        -OnDone {
            param($result)
            $StatusBar.Text = "gameboost $Mode completado."
            $bk = "$ScriptsDir\GameBoost_Backup.json"
            if (Test-Path $bk) {
                $d2 = (Get-Content $bk -Raw | ConvertFrom-Json).Timestamp
                $BackupStatus.Text = "backup: $($d2.Substring(0,10))"; $BackupStatus.Foreground = Get-Brush "#44bb66"
            } else {
                $BackupStatus.Text = "sin backup"; $BackupStatus.Foreground = Get-Brush "#440033"
            }
            $BtnGameCheck.IsEnabled = $true; $BtnGameApply.IsEnabled = $true; $BtnGameRestore.IsEnabled = $true
        }
}

$BtnGameCheck.Add_Click({ Run-GameScript "Check" })
$BtnGameApply.Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "Aplicar optimizaciones de red, CPU, mouse e input lag?`nSe guardara un backup para restaurar.",
        "GameBoost // IRREBOY","YesNo","Question")
    if ($r -eq "Yes") { Run-GameScript "Apply" }
})
$BtnGameRestore.Add_Click({
    if (-not (Test-Path "$ScriptsDir\GameBoost_Backup.json")) {
        [System.Windows.MessageBox]::Show("No hay backup disponible.","GameBoost","OK","Warning") | Out-Null; return
    }
    Run-GameScript "Restore"
})

# ---- KILL PROCESSES -----------------------------------------------------
$BtnKillProcs.Add_Click({
    Add-LogSection "KILL PROCESOS"
    $targets = @(
        @{N="discord";D="Discord"},@{N="chrome";D="Chrome"},@{N="msedge";D="Edge"},
        @{N="OneDrive";D="OneDrive"},@{N="Teams";D="Teams"},@{N="slack";D="Slack"},
        @{N="Spotify";D="Spotify"},@{N="EpicGamesLauncher";D="Epic Games"}
    )
    $killed = 0
    foreach ($t in $targets) {
        $procs = Get-Process -Name $t.N -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            try { $p.Kill(); Add-LogLine "  [OK]  cerrado: $($t.D)" "#44bb66"; $killed++ }
            catch { Add-LogLine "  [!!]  no se pudo cerrar $($t.D)" "#ddaa22" }
        }
    }
    if ($killed -eq 0) { Add-LogLine "  [--]  sin procesos pesados activos" "#445566" }
    else {
        try {
            $freeRam = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB,1)
            Add-LogLine "  [OK]  $killed cerrado(s) | RAM libre ahora: ${freeRam} GB" "#44bb66"
        } catch { Add-LogLine "  [OK]  $killed proceso(s) cerrado(s)" "#44bb66" }
    }
    $StatusBar.Text = "kill: $killed proceso(s) cerrado(s)."
})

# ---- PING TEST ----------------------------------------------------------
$BtnPingTest.Add_Click({
    Add-LogSection "PING GAMING SERVERS"
    Add-LogLine ">> probando latencia (ICMP + TCP fallback)..." "#9922cc" -Bold
    $BtnPingTest.IsEnabled = $false; $BtnSpeedTest.IsEnabled = $false
    $script:_StreamFile = [System.IO.Path]::GetTempFileName()
    $script:_LastLineIdx = 0; $script:_OkCount = 0; $script:_WarnCount = 0; $script:_CritCount = 0
    $script:_StartTime = Get-Date
    $sf = $script:_StreamFile
    $ScanProgress.Visibility = "Visible"; $StatusBar.Text = "probando latencia..."

    $initSb = $script:_InitScript
    $script:_Job = Start-Job -InitializationScript $initSb -ScriptBlock {
        param($sf)
        function W { param($l)
            try {
                $fs=New-Object System.IO.FileStream($sf,[System.IO.FileMode]::Append,[System.IO.FileAccess]::Write,[System.IO.FileShare]::ReadWrite)
                $sw=New-Object System.IO.StreamWriter($fs,[System.Text.Encoding]::UTF8)
                $sw.WriteLine($l);$sw.Flush();$sw.Close()
            } catch {}
        }

        # Mide latencia: ICMP primero, si falla -> TCP en el puerto dado
        function Measure-Latency {
            param([string]$Host, [int]$TcpPort = 443)
            # Intento ICMP (3 pings)
            try {
                $ping = New-Object System.Net.NetworkInformation.Ping
                $opts = New-Object System.Net.NetworkInformation.PingOptions
                $opts.Ttl = 64; $opts.DontFragment = $false
                $times = @()
                for ($i = 0; $i -lt 3; $i++) {
                    $r = $ping.Send($Host, 1500, ([byte[]]::new(32)), $opts)
                    if ($r.Status -eq 'Success') { $times += $r.RoundtripTime }
                }
                if ($times.Count -gt 0) {
                    return @{ Ms=[math]::Round(($times | Measure-Object -Average).Average); Via="ICMP" }
                }
            } catch {}
            # Fallback TCP
            try {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $tc  = New-Object System.Net.Sockets.TcpClient
                $ar  = $tc.BeginConnect($Host, $TcpPort, $null, $null)
                $ok  = $ar.AsyncWaitHandle.WaitOne(2500, $false)
                $sw.Stop()
                if ($ok -and $tc.Connected) {
                    $tc.Close()
                    return @{ Ms=[math]::Round($sw.ElapsedMilliseconds); Via="TCP:$TcpPort" }
                }
                try { $tc.Close() } catch {}
            } catch {}
            return $null
        }

        function Latency-Bar {
            param([int]$ms)
            if ($ms -lt 50)  { return "EXCELENTE" }
            if ($ms -lt 100) { return "bueno    " }
            if ($ms -lt 150) { return "aceptable" }
            if ($ms -lt 250) { return "alto     " }
            return "muy alto "
        }

        $servers = @(
            @{N="Riot LATAM SA ";H="la2.lol.riotgames.com";P=443},
            @{N="Riot LATAM SA1";H="la1.lol.riotgames.com";P=443},
            @{N="Steam CDN     ";H="cdn.cloudflare.steamstatic.com";P=443},
            @{N="Steam Login   ";H="store.steampowered.com";P=443},
            @{N="Blizzard      ";H="us.battle.net";P=1119},
            @{N="Epic Games    ";H="www.epicgames.com";P=443},
            @{N="Cloudflare DNS";H="1.1.1.1";P=53},
            @{N="Google DNS    ";H="8.8.8.8";P=53}
        )

        foreach ($s in $servers) {
            $res = Measure-Latency -Host $s.H -TcpPort $s.P
            if ($res) {
                $ms  = $res.Ms
                $via = $res.Via
                $bar = Latency-Bar $ms
                $pad = "{0,4}" -f $ms
                if ($ms -lt 50)       { W "  [OK]  $($s.N)  ${pad}ms  $bar  ($via)" }
                elseif ($ms -lt 100)  { W "  [OK]  $($s.N)  ${pad}ms  $bar  ($via)" }
                elseif ($ms -lt 150)  { W "  [!!]  $($s.N)  ${pad}ms  $bar  ($via)" }
                else                  { W "  [XX]  $($s.N)  ${pad}ms  $bar  ($via)" }
            } else {
                W "  [XX]  $($s.N)  ----  sin respuesta  (ICMP+TCP bloqueado)"
            }
        }
        [PSCustomObject]@{Done=$true}
    } -ArgumentList $sf

    if ($script:_Timer -and $script:_Timer.IsEnabled) { $script:_Timer.Stop() }
    $script:_Timer = New-Object Windows.Threading.DispatcherTimer
    $script:_Timer.Interval = [TimeSpan]::FromMilliseconds(180)
    $script:_Timer.Add_Tick({
        if ($script:_StreamFile) {
            $lines = Read-StreamLines $script:_StreamFile
            for ($i=$script:_LastLineIdx;$i-lt$lines.Count;$i++) {
                $l=$lines[$i];if($l.Trim()){Q-Line $l (ColorOf-Line $l)}
                $script:_LastLineIdx++
            }
        }
        if ($script:_Job -and $script:_Job.State -in "Completed","Failed","Stopped") {
            $script:_Timer.Stop()
            if ($script:_StreamFile) {
                $lines=Read-StreamLines $script:_StreamFile
                for ($i=$script:_LastLineIdx;$i-lt$lines.Count;$i++){$l=$lines[$i];if($l.Trim()){Q-Line $l (ColorOf-Line $l)}}
                Remove-Item $script:_StreamFile -ErrorAction SilentlyContinue; $script:_StreamFile=""
            }
            try { Receive-Job $script:_Job -ErrorAction Stop | Out-Null } catch { Q-Line "  [XX]  Error: $_" "#cc3355" }
            Remove-Job  $script:_Job -ErrorAction SilentlyContinue; $script:_Job=$null
            $elapsed=[math]::Round(((Get-Date)-$script:_StartTime).TotalSeconds,1)
            $script:_PrintQueue.Enqueue(@{Type="Summary";Ok=$script:_OkCount;Warn=$script:_WarnCount;Crit=$script:_CritCount;Duration="${elapsed}s"})
            $script:_PrintQueue.Enqueue(@{Type="Done";Result=$null;OnDone={
                $StatusBar.Text="ping test completado.";$ScanProgress.Visibility="Collapsed"
                $BtnPingTest.IsEnabled=$true; $BtnSpeedTest.IsEnabled=$true
            }})
        }
    })
    $script:_Timer.Start()
})

# ---- SPEED TEST ----------------------------------------------------------
$BtnSpeedTest.Add_Click({
    Add-LogSection "SPEED TEST  (Cloudflare)"
    Add-LogLine ">> midiendo latencia, descarga y subida..." "#9922cc" -Bold
    Add-LogLine "  [i]   servidor: speed.cloudflare.com" "#334466"
    $BtnSpeedTest.IsEnabled = $false; $BtnPingTest.IsEnabled = $false
    $script:_StreamFile = [System.IO.Path]::GetTempFileName()
    $script:_LastLineIdx = 0
    $script:_StartTime = Get-Date
    $sf = $script:_StreamFile
    $ScanProgress.Visibility = "Visible"; $StatusBar.Text = "midiendo velocidad..."

    $initSb = $script:_InitScript
    $script:_Job = Start-Job -InitializationScript $initSb -ScriptBlock {
        param($sf)
        function W { param($l)
            try {
                $fs=New-Object System.IO.FileStream($sf,[System.IO.FileMode]::Append,[System.IO.FileAccess]::Write,[System.IO.FileShare]::ReadWrite)
                $sw=New-Object System.IO.StreamWriter($fs,[System.Text.Encoding]::UTF8)
                $sw.WriteLine($l);$sw.Flush();$sw.Close()
            } catch {}
        }
        function Fmt { param([double]$bps)
            if ($bps -ge 1MB) { "{0:N1} MB/s  ({1:N1} Mbps)" -f ($bps/1MB),($bps*8/1MB) }
            else               { "{0:N1} KB/s  ({1:N2} Mbps)" -f ($bps/1KB),($bps*8/1MB) }
        }

        $avgLat = 0; $avgJitter = 0; $mbpsDl = 0.0; $mbpsUl = 0.0

        # --- LATENCIA (10 pings a 1.1.1.1) ---
        W "=SECTION=LATENCIA"
        try {
            $ping = New-Object System.Net.NetworkInformation.Ping
            $times = @()
            for ($i=0;$i-lt10;$i++) {
                $r = $ping.Send("1.1.1.1", 2000)
                if ($r.Status -eq 'Success') { $times += $r.RoundtripTime }
                Start-Sleep -Milliseconds 80
            }
            if ($times) {
                $avgLat = [int][math]::Round(($times|Measure-Object -Average).Average)
                $minLat = ($times|Measure-Object -Minimum).Minimum
                $maxLat = ($times|Measure-Object -Maximum).Maximum
                if ($times.Count -gt 1) {
                    $diffs=@(); for($i=1;$i-lt$times.Count;$i++){$diffs+=([Math]::Abs($times[$i]-$times[$i-1]))}
                    $avgJitter = [int][math]::Round(($diffs|Measure-Object -Average).Average)
                }
                W "  [OK]  latencia:  avg ${avgLat}ms  min ${minLat}ms  max ${maxLat}ms"
                W "  [OK]  jitter:    ${avgJitter}ms  ($($times.Count) muestras)"
            }
        } catch { W "  [!!]  latencia: error - $_" }

        # --- DESCARGA ---
        W "=SECTION=DESCARGA"
        $dlSizes = @(
            @{Url="https://speed.cloudflare.com/__down?bytes=1000000";  B=1000000;  L="  1 MB"},
            @{Url="https://speed.cloudflare.com/__down?bytes=10000000"; B=10000000; L=" 10 MB"},
            @{Url="https://speed.cloudflare.com/__down?bytes=25000000"; B=25000000; L=" 25 MB"}
        )
        $dlBps = @()
        foreach ($t in $dlSizes) {
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent","PCToolkit/3.0")
                $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
                $data = $wc.DownloadData($t.Url)
                $sw2.Stop()
                $bps = $data.Length / $sw2.Elapsed.TotalSeconds
                $dlBps += $bps
                W "  [OK]  $($t.L): $(Fmt $bps)"
            } catch { W "  [!!]  $($t.L): error - $_" }
        }
        if ($dlBps) {
            $avgBps = ($dlBps|Measure-Object -Average).Average
            $mbpsDl = [math]::Round($avgBps*8/1MB, 1)
        }

        # --- SUBIDA ---
        W "=SECTION=SUBIDA"
        $ulSizes = @(
            @{B=1000000;  L="  1 MB"},
            @{B=5000000;  L="  5 MB"},
            @{B=10000000; L=" 10 MB"}
        )
        $ulBps = @()
        foreach ($t in $ulSizes) {
            try {
                $payload = New-Object byte[] $t.B
                (New-Object System.Random).NextBytes($payload)
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent","PCToolkit/3.0")
                $wc.Headers.Add("Content-Type","application/octet-stream")
                $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
                $wc.UploadData("https://speed.cloudflare.com/__up","POST",$payload) | Out-Null
                $sw2.Stop()
                $bps = $t.B / $sw2.Elapsed.TotalSeconds
                $ulBps += $bps
                W "  [OK]  $($t.L): $(Fmt $bps)"
            } catch { W "  [!!]  $($t.L): error - $_" }
        }
        if ($ulBps) {
            $avgBps = ($ulBps|Measure-Object -Average).Average
            $mbpsUl = [math]::Round($avgBps*8/1MB, 1)
        }

        [PSCustomObject]@{
            Done=$true; DownMbps=$mbpsDl; UpMbps=$mbpsUl
            LatMs=$avgLat; JitterMs=$avgJitter
        }
    } -ArgumentList $sf

    if ($script:_Timer -and $script:_Timer.IsEnabled) { $script:_Timer.Stop() }
    $script:_Timer = New-Object Windows.Threading.DispatcherTimer
    $script:_Timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $script:_Timer.Add_Tick({
        if ($script:_StreamFile) {
            $lines = Read-StreamLines $script:_StreamFile
            for ($i=$script:_LastLineIdx;$i-lt$lines.Count;$i++) {
                $l=$lines[$i]; if($l.Trim()){ Q-Line $l (ColorOf-Line $l) }
                $script:_LastLineIdx++
            }
        }
        if ($script:_Job -and $script:_Job.State -in "Completed","Failed","Stopped") {
            $script:_Timer.Stop()
            if ($script:_StreamFile) {
                $lines = Read-StreamLines $script:_StreamFile
                for ($i=$script:_LastLineIdx;$i-lt$lines.Count;$i++){$l=$lines[$i];if($l.Trim()){Q-Line $l (ColorOf-Line $l)}}
                Remove-Item $script:_StreamFile -ErrorAction SilentlyContinue; $script:_StreamFile=""
            }
            $sr = $null
            try {
                $raw = Receive-Job $script:_Job -ErrorAction Stop
                $sr  = if ($raw -is [array]) { $raw | Where-Object { $_ -is [PSCustomObject] -and $_.PSObject.Properties['DownMbps'] } | Select-Object -Last 1 } else { $raw }
            } catch { Q-Line "  [XX]  Error job: $_" "#cc3355" }
            Remove-Job $script:_Job -ErrorAction SilentlyContinue; $script:_Job=$null
            $elapsed = [math]::Round(((Get-Date)-$script:_StartTime).TotalSeconds,1)
            $down    = if ($sr) { [double]$sr.DownMbps }   else { 0.0 }
            $up      = if ($sr) { [double]$sr.UpMbps }     else { 0.0 }
            $lat     = if ($sr) { [int]$sr.LatMs }         else { 0 }
            $jitter  = if ($sr) { [int]$sr.JitterMs }      else { 0 }
            $script:_PrintQueue.Enqueue(@{Type="SpeedCard";Down=$down;Up=$up;Lat=$lat;Jitter=$jitter;Duration="${elapsed}s"})
            $script:_PrintQueue.Enqueue(@{Type="Done";Result=$null;OnDone={
                $StatusBar.Text="speed test completado.";$ScanProgress.Visibility="Collapsed"
                $BtnSpeedTest.IsEnabled=$true; $BtnPingTest.IsEnabled=$true
            }})
        }
    })
    $script:_Timer.Start()
})

# ---- TOOLTIPS Y HOVER HINTS PARA BOTONES VISUAL/RED --------------------
$BtnVFX.ToolTip          = "Desactiva animaciones, transparencia y efectos de ventana de Windows para liberar CPU/GPU"
$BtnFlushDNS.ToolTip     = "Limpia la cache DNS del sistema. Util si hay problemas de conexion o sitios no cargan"
$BtnResetNet.ToolTip     = "Desactiva y reactiva el adaptador de red activo. Corta la conexion ~3 segundos"
$BtnClearShaders.ToolTip = "Elimina caches de shaders de GPU (NVIDIA/AMD/Steam). Los juegos recompilan al iniciar, luego quedan mas rapidos"
$BtnKillProcs.ToolTip    = "Cierra forcosamente Discord, Chrome, Edge, OneDrive, Teams, Slack, Spotify y Epic para liberar RAM"
$BtnPingTest.ToolTip     = "Mide latencia a servidores de Riot, Steam, Blizzard, Epic y DNS (ICMP + TCP fallback)"
$BtnSpeedTest.ToolTip    = "Mide velocidad de descarga y subida usando servidores de Cloudflare"

$hoverMap = @{
    $BtnVFX          = "[V] EFECTOS VISUALES - desactiva animaciones y transparencia de Windows (requiere reiniciar Explorer)"
    $BtnFlushDNS     = "[N] FLUSH DNS - limpia cache DNS del sistema"
    $BtnResetNet     = "[R] RESET ADAPTADOR - reconecta el adaptador de red activo (corta ~3s)"
    $BtnClearShaders = "[S] LIMPIAR SHADERS - elimina caches de shaders de GPU (NVIDIA, AMD, Steam)"
    $BtnKillProcs    = "[X] KILL PROCESOS - cierra apps pesadas en background para liberar RAM"
    $BtnPingTest     = "[P] PING SERVERS - mide latencia a servidores de juegos (ICMP + TCP fallback automatico)"
    $BtnSpeedTest    = "[W] SPEED TEST - mide descarga y subida via Cloudflare (puede tomar ~30s)"
    $BtnGameCheck    = "[?] ESTADO ACTUAL - muestra el estado de cada optimizacion gaming (sin admin)"
    $BtnGameApply    = "[+] OPTIMIZAR - aplica ajustes de red, CPU, mouse, DVR y energia (requiere admin)"
    $BtnGameRestore  = "[-] RESTAURAR - deshace todas las optimizaciones aplicadas (requiere admin)"
}
foreach ($kv in $hoverMap.GetEnumerator()) {
    $msg = $kv.Value
    $kv.Key.Add_MouseEnter({ $StatusBar.Text = $msg }.GetNewClosure())
    $kv.Key.Add_MouseLeave({ $StatusBar.Text = "listo.  $env:COMPUTERNAME  $(if($script:IsAdmin){'[ADMIN]'}else{'[USER]'})" }.GetNewClosure())
}

# ---- VISUAL FX ----------------------------------------------------------
$BtnVFX.Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "Aplicar modo rendimiento?`n`n- Desactiva animaciones de ventana`n- Desactiva transparencia`n- Optimiza efectos visuales`n`nRequiere reiniciar Explorer para aplicar.",
        "Efectos Visuales","YesNo","Question")
    if ($r -ne "Yes") { return }
    Add-LogSection "EFECTOS VISUALES"
    try {
        $vk="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if(-not(Test-Path $vk)){New-Item $vk -Force|Out-Null}
        Set-ItemProperty $vk -Name "VisualFXSetting" -Value 2 -Type DWord
        Add-LogLine "  [OK]  Efectos visuales: modo rendimiento" "#44bb66"
    } catch { Add-LogLine "  [!!]  VisualFX: $_" "#ddaa22" }
    try {
        Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" `
            -Name "EnableTransparency" -Value 0 -Type DWord -ErrorAction Stop
        Add-LogLine "  [OK]  Transparencia desactivada" "#44bb66"
    } catch { Add-LogLine "  [!!]  Transparencia: $_" "#ddaa22" }
    try {
        Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -ErrorAction Stop
        Add-LogLine "  [OK]  Animaciones de ventana desactivadas" "#44bb66"
    } catch { Add-LogLine "  [!!]  Animaciones: $_" "#ddaa22" }
    Add-LogLine "  [i]   Para aplicar: clic derecho escritorio > Actualizar, o reinicia Explorer." "#9944cc"
    $StatusBar.Text = "efectos visuales: modo rendimiento aplicado."
})

# ---- FLUSH DNS ----------------------------------------------------------
$BtnFlushDNS.Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "Limpiar cache DNS del sistema?`n`nUtil si hay sitios que no cargan o conexiones lentas.",
        "Flush DNS","YesNo","Question")
    if ($r -ne "Yes") { return }
    try {
        Clear-DnsClientCache -ErrorAction Stop
        Add-LogLine "  [OK]  Cache DNS limpiada correctamente" "#44bb66"
        Add-LogLine "  [i]   Los sitios resolveran DNS de nuevo al conectarse" "#9944cc"
        $StatusBar.Text = "DNS flush completado."
    } catch { Add-LogLine "  [XX]  DNS flush fallido: $_" "#cc3355" }
})

# ---- RESET NET ----------------------------------------------------------
$BtnResetNet.Add_Click({
    $r=[System.Windows.MessageBox]::Show(
        "Resetear adaptador de red activo?`n`nDesactiva y reactiva la conexion (~3 segundos de corte).`nUtil para resolver problemas de conexion sin reiniciar.",
        "Reset Adaptador de Red","YesNo","Question")
    if ($r -ne "Yes") { return }
    Add-LogSection "RESET ADAPTADOR DE RED"
    $dir = $ScriptsDir
    Invoke-StreamedJob -Label "reseteando red..." `
        -Job {
            param($d,$sf)
            function S { param($l)
                try{$fs=New-Object System.IO.FileStream($sf,[System.IO.FileMode]::Append,[System.IO.FileAccess]::Write,[System.IO.FileShare]::ReadWrite)
                $sw=New-Object System.IO.StreamWriter($fs,[System.Text.Encoding]::UTF8);$sw.WriteLine($l);$sw.Flush();$sw.Close()}catch{}
            }
            Get-NetAdapter|Where-Object{$_.Status-eq"Up"}|ForEach-Object{
                S "  [i]   desactivando: $($_.Name)"
                Disable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 1500
                S "  [i]   reactivando: $($_.Name)"
                Enable-NetAdapter -Name $_.Name -Confirm:$false -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 2000
                S "  [OK]  $($_.Name): reset completado"
            }
            [PSCustomObject]@{Done=$true}
        } `
        -JobArgs @($dir) `
        -OnDone { $StatusBar.Text = "reset de red completado." }
})

# ---- CLEAR SHADERS ------------------------------------------------------
$BtnClearShaders.Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "Limpiar caches de shaders de GPU?`n`n- NVIDIA DX/GL Cache`n- AMD DX Cache`n- Steam Shaders`n- Epic Games y Riot Client`n`nLos juegos recompilaran shaders al primer inicio (puede tardar mas una vez).",
        "Limpiar Shader Caches","YesNo","Question")
    if ($r -ne "Yes") { return }
    Add-LogSection "SHADER CACHES"
    $paths = @(
        @{P="$env:LOCALAPPDATA\Steam\htmlcache";N="Steam HTML"},
        @{P="$env:LOCALAPPDATA\Steam\shaders";N="Steam Shaders"},
        @{P="$env:LOCALAPPDATA\NVIDIA\DXCache";N="NVIDIA DX"},
        @{P="$env:LOCALAPPDATA\NVIDIA\GLCache";N="NVIDIA GL"},
        @{P="$env:LOCALAPPDATA\AMD\DxCache";N="AMD DX"},
        @{P="$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache";N="Epic Games"},
        @{P="$env:APPDATA\Riot Games\Riot Client\Data\cache";N="Riot Client"}
    )
    $cleaned = 0
    foreach ($item in $paths) {
        if (Test-Path $item.P) {
            try {
                Get-ChildItem $item.P -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Add-LogLine "  [OK]  $($item.N): limpiado" "#44bb66"; $cleaned++
            } catch { Add-LogLine "  [!!]  $($item.N): parcial" "#ddaa22" }
        } else {
            Add-LogLine "  [--]  $($item.N): no instalado / no existe" "#445566"
        }
    }
    if ($cleaned -eq 0) { Add-LogLine "  [--]  nada que limpiar en shader caches" "#445566" }
    else {
        Add-LogLine "  [OK]  $cleaned carpeta(s) limpiadas" "#44bb66"
        Add-LogLine "  [i]   Los juegos recompilaran shaders al primer inicio (normal)" "#9944cc"
    }
    $StatusBar.Text = "shaders: $cleaned carpeta(s) limpiadas."
})

# ---- RELOJ --------------------------------------------------------------
$script:_ClockTimer = New-Object Windows.Threading.DispatcherTimer
$script:_ClockTimer.Interval = [TimeSpan]::FromSeconds(1)
$script:_ClockTimer.Add_Tick({ $ClockText.Text=Get-Date -Format "HH:mm:ss"; $DateText.Text=Get-Date -Format "ddd dd/MM/yyyy" })
$script:_ClockTimer.Start()

# ---- SYSTEM INFO (async) ------------------------------------------------
$script:_SysJob = Start-Job -InitializationScript { Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue } -ScriptBlock {
    $cpu=(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue|Select-Object -First 1).Name
    $free=[math]::Round((Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).FreePhysicalMemory/1MB,1)
    $tot=[math]::Round(((Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)|Measure-Object Capacity -Sum).Sum/1GB)
    $gpu=(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue|Select-Object -First 1).Name
    "$cpu  //  RAM: ${free}GB libre / ${tot}GB  //  GPU: $gpu"
}
$script:_SysTimer = New-Object Windows.Threading.DispatcherTimer
$script:_SysTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$script:_SysTimer.Add_Tick({
    if ($script:_SysJob -and $script:_SysJob.State -in "Completed","Failed","Stopped") {
        $script:_SysTimer.Stop()
        $info = Receive-Job $script:_SysJob -ErrorAction SilentlyContinue
        Remove-Job $script:_SysJob -ErrorAction SilentlyContinue; $script:_SysJob = $null
        if ($info) { $SysInfo.Text = $info }
    }
})
$script:_SysTimer.Start()

# ---- INICIO -------------------------------------------------------------
$Window.Add_Loaded({
    Ensure-PrintTimer
    Show-Splash
    Start-MonitorJob
    Setup-Tray
    $adminLabel = if ($script:IsAdmin) { "[ADMIN]" } else { "[USER]" }
    $StatusBar.Text = "listo.  $env:COMPUTERNAME  $adminLabel"
})

$Window.ShowDialog() | Out-Null
