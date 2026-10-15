#Requires -Version 5.1
# PCToolkit.ps1  — BY IRREBOY
# Full rewrite: 8 tabs, mode profiles, hardware panel, process manager, network panel, history log

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$ScriptsDir = Split-Path $MyInvocation.MyCommand.Path -Parent

# ─── State ────────────────────────────────────────────────────────────────────
$script:_ActiveTab    = "Security"
$script:_ActiveMode   = "Normal"
$script:_Job          = $null
$script:_JobStream    = $null
$script:_CpuHistory   = [System.Collections.Generic.List[double]]::new()
$script:_GpuHistory   = [System.Collections.Generic.List[double]]::new()
$script:_HealthSecCrit = 0
$script:_HealthSecWarn = 0
$script:_PrintQueue   = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$script:_HistoryLog   = [System.Collections.Generic.List[hashtable]]::new()
$script:_GpuCounter   = $null
$script:_DiskReadCtr  = $null
$script:_DiskWriteCtr = $null
$script:_NetDlCtr     = $null
$script:_NetUlCtr     = $null

# ─── XAML ─────────────────────────────────────────────────────────────────────
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PC Toolkit — BY IRREBOY"
        Width="1200" Height="740" MinWidth="900" MinHeight="600"
        WindowStartupLocation="CenterScreen"
        Background="#0a0015" Foreground="#e0d0ff"
        FontFamily="Segoe UI" FontSize="13"
        ResizeMode="CanResize">
  <Window.Resources>

    <Style x:Key="NavBtn" TargetType="Button">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#9988bb"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="Height" Value="36"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#1a0a2e"/>
                <Setter Property="Foreground" Value="#ccbbee"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="NavBtnActive" TargetType="Button" BasedOn="{StaticResource NavBtn}">
      <Setter Property="Background" Value="#2d1555"/>
      <Setter Property="Foreground" Value="#ffffff"/>
    </Style>

    <Style x:Key="ModeBtn" TargetType="Button">
      <Setter Property="Background" Value="#1a0a2e"/>
      <Setter Property="Foreground" Value="#9988bb"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#3a2060"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}"
                    CornerRadius="5">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#2d1555"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="ModeBtnActive" TargetType="Button" BasedOn="{StaticResource ModeBtn}">
      <Setter Property="Background" Value="#7b2fff"/>
      <Setter Property="Foreground" Value="#ffffff"/>
      <Setter Property="BorderBrush" Value="#9b4fff"/>
    </Style>

    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Background" Value="#4a1a8a"/>
      <Setter Property="Foreground" Value="#ffffff"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#6a2aaa"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="BtnGreen" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#1a6b3a"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#2a8b4a"/></Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="BtnRed" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#6b1a1a"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#8b2a2a"/></Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="BtnOrange" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#7a3a00"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#9a4a00"/></Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="BtnYellow" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#5a5000"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#7a7000"/></Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="BtnGhost" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#9988bb"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#3a2060"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#1a0a2e"/>
          <Setter Property="Foreground" Value="#ffffff"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="BtnFix" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#2a1060"/>
      <Setter Property="Foreground" Value="#bb99ff"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Height" Value="24"/>
      <Setter Property="Padding" Value="8,2"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#3a1880"/></Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="ConsoleScroll" TargetType="ScrollViewer">
      <Setter Property="Background" Value="#080012"/>
      <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
      <Setter Property="HorizontalScrollBarVisibility" Value="Auto"/>
    </Style>

    <Style x:Key="MonSec" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#bb88ff"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Margin" Value="0,10,0,3"/>
    </Style>

    <Style x:Key="MonVal" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#ddd0ff"/>
      <Setter Property="FontSize" Value="12"/>
    </Style>

  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="200"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="290"/>
    </Grid.ColumnDefinitions>

    <!-- LEFT NAV -->
    <Border Grid.Column="0" Background="#0d0020" BorderBrush="#220040" BorderThickness="0,0,1,0">
      <DockPanel>

        <Border DockPanel.Dock="Top" Padding="14,16,14,12" BorderBrush="#2a0055" BorderThickness="0,0,0,1">
          <StackPanel>
            <TextBlock Text="PC TOOLKIT" FontSize="16" FontWeight="Black" Foreground="#cc88ff"/>
            <TextBlock Text="BY IRREBOY" FontSize="10" Foreground="#664488" Margin="1,2,0,0"/>
          </StackPanel>
        </Border>

        <Border DockPanel.Dock="Top" Padding="14,10" Background="#0a001a" BorderBrush="#220040" BorderThickness="0,0,0,1">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel>
              <TextBlock Text="SALUD DEL SISTEMA" FontSize="9" Foreground="#664488" FontWeight="Bold"/>
              <TextBlock x:Name="HealthScore" Text="—" FontSize="28" FontWeight="Black" Foreground="#aa66ff" Margin="0,2,0,0"/>
              <TextBlock x:Name="HealthStatus" Text="Sin escanear" FontSize="10" Foreground="#886699"/>
            </StackPanel>
            <Ellipse x:Name="HealthDot" Grid.Column="1" Width="14" Height="14" Fill="#443366" VerticalAlignment="Center"/>
          </Grid>
        </Border>

        <ScrollViewer VerticalScrollBarVisibility="Auto" DockPanel.Dock="Top">
          <StackPanel Margin="8,8,8,8">

            <TextBlock Text="MÓDULOS" FontSize="9" FontWeight="Bold" Foreground="#553377" Margin="6,4,0,6"/>
            <Button x:Name="TabSecurity"  Content="🔒  Seguridad"  Style="{StaticResource NavBtnActive}"/>
            <Button x:Name="TabClean"     Content="🧹  Limpieza"   Style="{StaticResource NavBtn}" Margin="0,2,0,0"/>
            <Button x:Name="TabGaming"    Content="🎮  Gaming"     Style="{StaticResource NavBtn}" Margin="0,2,0,0"/>
            <Button x:Name="TabTweaks"    Content="⚙  Tweaks"     Style="{StaticResource NavBtn}" Margin="0,2,0,0"/>

            <TextBlock Text="SISTEMA" FontSize="9" FontWeight="Bold" Foreground="#553377" Margin="6,14,0,6"/>
            <Button x:Name="TabHardware"  Content="💻  Hardware"   Style="{StaticResource NavBtn}"/>
            <Button x:Name="TabProcesses" Content="📊  Procesos"   Style="{StaticResource NavBtn}" Margin="0,2,0,0"/>
            <Button x:Name="TabNetwork"   Content="🌐  Red"        Style="{StaticResource NavBtn}" Margin="0,2,0,0"/>
            <Button x:Name="TabHistory"   Content="📋  Historial"  Style="{StaticResource NavBtn}" Margin="0,2,0,0"/>

            <TextBlock Text="PERFIL" FontSize="9" FontWeight="Bold" Foreground="#553377" Margin="6,14,0,6"/>
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Button x:Name="ModGaming"  Grid.Column="0" Content="GAM" Style="{StaticResource ModeBtn}" Margin="0,0,2,0"/>
              <Button x:Name="ModTrabajo" Grid.Column="1" Content="TRB" Style="{StaticResource ModeBtn}" Margin="2,0,2,0"/>
              <Button x:Name="ModAhorro"  Grid.Column="2" Content="AHR" Style="{StaticResource ModeBtn}" Margin="2,0,0,0"/>
            </Grid>
            <TextBlock x:Name="ModeLabel" Text="Modo: Normal" FontSize="10"
                       Foreground="#776699" HorizontalAlignment="Center" Margin="0,4,0,0"/>

          </StackPanel>
        </ScrollViewer>

        <Border DockPanel.Dock="Bottom" Padding="14,8" BorderBrush="#220040" BorderThickness="0,1,0,0">
          <TextBlock Text="v3.0  |  Admin Mode" FontSize="9" Foreground="#443366"/>
        </Border>

      </DockPanel>
    </Border>

    <!-- CENTER -->
    <Grid Grid.Column="1">

      <!-- LOG PANEL (Security/Clean/Gaming/Tweaks) -->
      <Grid x:Name="LogPanel">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#0d0020" BorderBrush="#220040" BorderThickness="0,0,0,1" Padding="14,10">
          <StackPanel>
            <WrapPanel x:Name="ToolbarSecurity">
              <Button x:Name="BtnSecScan"     Content="▶  Escanear"              Style="{StaticResource Btn}"       Margin="0,0,8,0"/>
              <Button x:Name="BtnSecFix"      Content="⚡  Aplicar todos los fix" Style="{StaticResource BtnOrange}" Margin="0,0,8,0"/>
              <Button x:Name="BtnSecExport"   Content="📄  Exportar HTML"         Style="{StaticResource BtnGhost}"  Margin="0,0,8,0"/>
              <Button x:Name="BtnSecSchedule" Content="🕐  Auto-escaneo"          Style="{StaticResource BtnGhost}"/>
            </WrapPanel>
            <WrapPanel x:Name="ToolbarClean" Visibility="Collapsed">
              <Button x:Name="BtnClean"     Content="🧹  Limpiar"        Style="{StaticResource BtnGreen}"  Margin="0,0,8,0"/>
              <Button x:Name="BtnCleanDism" Content="🔧  Limpiar + DISM" Style="{StaticResource BtnOrange}" Margin="0,0,8,0"/>
              <Button x:Name="BtnRamClean"  Content="💾  Limpiar RAM"    Style="{StaticResource BtnGhost}"/>
            </WrapPanel>
            <WrapPanel x:Name="ToolbarGaming" Visibility="Collapsed">
              <Button x:Name="BtnGameApply"   Content="🚀  Aplicar Boost"  Style="{StaticResource BtnGreen}"  Margin="0,0,8,0"/>
              <Button x:Name="BtnGameRestore" Content="↩  Restaurar"       Style="{StaticResource BtnOrange}" Margin="0,0,8,0"/>
              <Button x:Name="BtnGameCheck"   Content="📋  Verificar"      Style="{StaticResource BtnGhost}"  Margin="0,0,8,0"/>
              <Button x:Name="BtnKillProcs"   Content="💀  Matar Procesos" Style="{StaticResource BtnRed}"    Margin="0,0,8,0"/>
              <Button x:Name="BtnPingTest"    Content="📡  Ping Test"      Style="{StaticResource BtnGhost}"  Margin="0,0,8,0"/>
              <Button x:Name="BtnFlushDns"    Content="🔄  Flush DNS"      Style="{StaticResource BtnGhost}"/>
            </WrapPanel>
            <WrapPanel x:Name="ToolbarTweaks" Visibility="Collapsed">
              <TextBlock Text="Tweaks del sistema — aplica individualmente"
                         Foreground="#886699" VerticalAlignment="Center" FontSize="12"/>
            </WrapPanel>
          </StackPanel>
        </Border>

        <ScrollViewer x:Name="ConsoleScroll" Grid.Row="1" Style="{StaticResource ConsoleScroll}">
          <StackPanel x:Name="ConsolePanel" Margin="14,10"/>
        </ScrollViewer>

        <ScrollViewer x:Name="TweaksScrollView" Grid.Row="1" Visibility="Collapsed"
                      Background="#080012" VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="16,14">

            <TextBlock Text="PRIVACIDAD" Foreground="#bb88ff" FontSize="11" FontWeight="Bold" Margin="0,0,0,8"/>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="Telemetría de Windows" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Desactiva la recopilación de datos de diagnóstico" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnTelemetria" Grid.Column="1" Content="Aplicar" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="Cortana" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Desactiva el asistente de voz y su búsqueda web" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnCortana" Grid.Column="1" Content="Aplicar" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="OneDrive" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Desinstala y desactiva OneDrive del inicio" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnOneDrive" Grid.Column="1" Content="Aplicar" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="Notificaciones" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Desactiva el centro de notificaciones" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnNotif" Grid.Column="1" Content="Aplicar" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

            <TextBlock Text="RENDIMIENTO" Foreground="#bb88ff" FontSize="11" FontWeight="Bold" Margin="0,8,0,8"/>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="Hibernación" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Desactiva hibernación y borra hiberfil.sys" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnHibernate" Grid.Column="1" Content="Aplicar" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="Power Throttling" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Desactiva la limitación de CPU en background" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnPowerThrottling" Grid.Column="1" Content="Aplicar" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="QoS Bandwidth" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Elimina la reserva del 20% de ancho de banda" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnQoS" Grid.Column="1" Content="Aplicar" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="Win32 Priority Separation" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Optimiza la prioridad del planificador de CPU" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnWin32Pri" Grid.Column="1" Content="Aplicar" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

            <TextBlock Text="INICIO" Foreground="#bb88ff" FontSize="11" FontWeight="Bold" Margin="0,8,0,8"/>

            <Border Background="#0d0020" CornerRadius="8" Padding="14,10" Margin="0,0,0,8">
              <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                  <TextBlock Text="Administrador de Inicio" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                  <TextBlock Text="Ver y deshabilitar programas que arrancan con Windows" Foreground="#776699" FontSize="11"/>
                </StackPanel>
                <Button x:Name="BtnStartupMgr" Grid.Column="1" Content="Abrir" Style="{StaticResource BtnFix}" VerticalAlignment="Center"/>
              </Grid>
            </Border>

          </StackPanel>
        </ScrollViewer>

        <Border Grid.Row="2" Background="#0a001a" BorderBrush="#220040" BorderThickness="0,1,0,0" Padding="14,6">
          <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <TextBlock x:Name="StatusBar" Text="Listo" Foreground="#776699" FontSize="11"/>
            <TextBlock x:Name="JobStatus" Grid.Column="1" Text="" Foreground="#aa66ff" FontSize="11"/>
          </Grid>
        </Border>
      </Grid>

      <!-- PROCESS PANEL -->
      <Grid x:Name="ProcPanel" Visibility="Collapsed">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Background="#0d0020" BorderBrush="#220040" BorderThickness="0,0,0,1" Padding="14,10">
          <WrapPanel>
            <TextBox x:Name="ProcSearch" Width="200" Background="#1a0a2e" Foreground="#e0d0ff"
                     BorderBrush="#3a2060" BorderThickness="1" Padding="8,6"
                     VerticalContentAlignment="Center" Margin="0,0,8,0"/>
            <Button x:Name="BtnProcRefresh" Content="🔄  Actualizar"       Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
            <Button x:Name="BtnProcKill"    Content="❌  Matar proceso"    Style="{StaticResource BtnRed}"   Margin="0,0,8,0"/>
            <Button x:Name="BtnProcSuspend" Content="⏸  Suspender"        Style="{StaticResource BtnOrange}"/>
          </WrapPanel>
        </Border>
        <ListView x:Name="ProcList" Grid.Row="1" Background="#080012" Foreground="#ddd0ff"
                  BorderThickness="0" SelectionMode="Single"
                  VirtualizingPanel.IsVirtualizing="True">
          <ListView.View>
            <GridView>
              <GridViewColumn Header="PID"      Width="65"  DisplayMemberBinding="{Binding PID}"/>
              <GridViewColumn Header="Nombre"   Width="200" DisplayMemberBinding="{Binding Name}"/>
              <GridViewColumn Header="CPU s"    Width="75"  DisplayMemberBinding="{Binding CPU}"/>
              <GridViewColumn Header="RAM MB"   Width="90"  DisplayMemberBinding="{Binding RAM}"/>
              <GridViewColumn Header="Handles"  Width="75"  DisplayMemberBinding="{Binding Handles}"/>
              <GridViewColumn Header="Usuario"  Width="130" DisplayMemberBinding="{Binding User}"/>
            </GridView>
          </ListView.View>
        </ListView>
        <Border Grid.Row="2" Background="#0a001a" BorderBrush="#220040" BorderThickness="0,1,0,0" Padding="14,6">
          <TextBlock x:Name="ProcCount" Text="" Foreground="#776699" FontSize="11"/>
        </Border>
      </Grid>

      <!-- HARDWARE PANEL -->
      <ScrollViewer x:Name="HwPanel" Visibility="Collapsed" Background="#080012"
                    VerticalScrollBarVisibility="Auto">
        <StackPanel Margin="20,16">
          <TextBlock Text="INFORMACIÓN DE HARDWARE" FontSize="14" FontWeight="Bold"
                     Foreground="#cc88ff" Margin="0,0,0,16"/>
          <WrapPanel>
            <Border Background="#0d0020" CornerRadius="10" Padding="16,14" Margin="0,0,12,12" MinWidth="260">
              <StackPanel>
                <TextBlock Text="PROCESADOR" Foreground="#bb88ff" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                <TextBlock x:Name="HwCpuName"   Text="—" Foreground="#ddd0ff" FontWeight="SemiBold" TextWrapping="Wrap"/>
                <TextBlock x:Name="HwCpuCores"  Text="—" Foreground="#886699" FontSize="11" Margin="0,4,0,0"/>
                <TextBlock x:Name="HwCpuSpeed"  Text="—" Foreground="#886699" FontSize="11"/>
                <TextBlock x:Name="HwCpuSocket" Text="—" Foreground="#886699" FontSize="11"/>
              </StackPanel>
            </Border>
            <Border Background="#0d0020" CornerRadius="10" Padding="16,14" Margin="0,0,12,12" MinWidth="260">
              <StackPanel>
                <TextBlock Text="MEMORIA RAM" Foreground="#bb88ff" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                <TextBlock x:Name="HwRamTotal"  Text="—" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                <TextBlock x:Name="HwRamUsed"   Text="—" Foreground="#886699" FontSize="11" Margin="0,4,0,0"/>
                <TextBlock x:Name="HwRamSlots"  Text="—" Foreground="#886699" FontSize="11"/>
                <TextBlock x:Name="HwRamSpeed"  Text="—" Foreground="#886699" FontSize="11"/>
              </StackPanel>
            </Border>
            <Border Background="#0d0020" CornerRadius="10" Padding="16,14" Margin="0,0,12,12" MinWidth="260">
              <StackPanel>
                <TextBlock Text="TARJETA GRÁFICA" Foreground="#bb88ff" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                <TextBlock x:Name="HwGpuName"   Text="—" Foreground="#ddd0ff" FontWeight="SemiBold" TextWrapping="Wrap"/>
                <TextBlock x:Name="HwGpuVram"   Text="—" Foreground="#886699" FontSize="11" Margin="0,4,0,0"/>
                <TextBlock x:Name="HwGpuDriver" Text="—" Foreground="#886699" FontSize="11"/>
              </StackPanel>
            </Border>
            <Border Background="#0d0020" CornerRadius="10" Padding="16,14" Margin="0,0,12,12" MinWidth="260">
              <StackPanel>
                <TextBlock Text="PLACA MADRE" Foreground="#bb88ff" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                <TextBlock x:Name="HwMoboName"  Text="—" Foreground="#ddd0ff" FontWeight="SemiBold"/>
                <TextBlock x:Name="HwMoboMfg"   Text="—" Foreground="#886699" FontSize="11" Margin="0,4,0,0"/>
                <TextBlock x:Name="HwBiosVer"   Text="—" Foreground="#886699" FontSize="11"/>
                <TextBlock x:Name="HwBiosDate"  Text="—" Foreground="#886699" FontSize="11"/>
              </StackPanel>
            </Border>
            <Border Background="#0d0020" CornerRadius="10" Padding="16,14" Margin="0,0,12,12" MinWidth="260">
              <StackPanel>
                <TextBlock Text="ALMACENAMIENTO" Foreground="#bb88ff" FontSize="10" FontWeight="Bold" Margin="0,0,0,8"/>
                <TextBlock x:Name="HwDiskInfo" Text="—" Foreground="#ddd0ff" TextWrapping="Wrap"/>
              </StackPanel>
            </Border>
          </WrapPanel>
          <Button x:Name="BtnHwRefresh" Content="🔄  Actualizar información"
                  Style="{StaticResource BtnGhost}" HorizontalAlignment="Left" Margin="0,8,0,0"/>
        </StackPanel>
      </ScrollViewer>

      <!-- NETWORK PANEL -->
      <Grid x:Name="NetPanel" Visibility="Collapsed">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Background="#0d0020" BorderBrush="#220040" BorderThickness="0,0,0,1" Padding="14,10">
          <WrapPanel>
            <Button x:Name="BtnNetRefresh"  Content="🔄  Adaptadores"     Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
            <Button x:Name="BtnNetConnTest" Content="🌐  Test Conexión"   Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
            <Button x:Name="BtnNetTrace"    Content="🗺  Traceroute"     Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
            <Button x:Name="BtnNetFlushDns" Content="🔄  Flush DNS"       Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
            <Button x:Name="BtnNetReset"    Content="♻  Reset Adaptador" Style="{StaticResource BtnOrange}"/>
          </WrapPanel>
        </Border>
        <ScrollViewer Grid.Row="1" Background="#080012" VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="NetContent" Margin="20,14"/>
        </ScrollViewer>
      </Grid>

      <!-- HISTORY PANEL -->
      <Grid x:Name="HistPanel" Visibility="Collapsed">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Background="#0d0020" BorderBrush="#220040" BorderThickness="0,0,0,1" Padding="14,10">
          <WrapPanel>
            <Button x:Name="BtnHistRefresh" Content="🔄  Actualizar"          Style="{StaticResource BtnGhost}" Margin="0,0,8,0"/>
            <Button x:Name="BtnHistClear"   Content="🗑  Limpiar historial" Style="{StaticResource BtnRed}"/>
          </WrapPanel>
        </Border>
        <ScrollViewer Grid.Row="1" Background="#080012" VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="HistContent" Margin="20,14"/>
        </ScrollViewer>
      </Grid>

    </Grid>

    <!-- RIGHT MONITOR -->
    <Border Grid.Column="2" Background="#0d0020" BorderBrush="#220040" BorderThickness="1,0,0,0">
      <DockPanel>

        <Border DockPanel.Dock="Top" Padding="14,12" BorderBrush="#2a0055" BorderThickness="0,0,0,1">
          <TextBlock Text="MONITOR EN VIVO" FontSize="10" FontWeight="Bold" Foreground="#9966cc"/>
        </Border>

        <ScrollViewer VerticalScrollBarVisibility="Auto" DockPanel.Dock="Top">
          <StackPanel Margin="14,6,14,14">

            <TextBlock Text="CPU" Style="{StaticResource MonSec}"/>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <ProgressBar x:Name="MonCpuBar" Height="8" Maximum="100" Value="0"
                           Background="#1a0a2e" Foreground="#9966ff" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonCpuPct" Grid.Column="1" Text="0%" Style="{StaticResource MonVal}" Margin="8,0,0,0"/>
            </Grid>
            <TextBlock x:Name="MonCpuSpark" Text="" Foreground="#7755bb" FontSize="10"
                       FontFamily="Consolas" Margin="0,2,0,0"/>
            <TextBlock x:Name="MonCpuTemp"  Text="Temp: —" Foreground="#aa7733" FontSize="11" Margin="0,2,0,0"/>

            <TextBlock Text="RAM" Style="{StaticResource MonSec}"/>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <ProgressBar x:Name="MonRamBar" Height="8" Maximum="100" Value="0"
                           Background="#1a0a2e" Foreground="#44aaff" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonRamPct" Grid.Column="1" Text="0%" Style="{StaticResource MonVal}" Margin="8,0,0,0"/>
            </Grid>
            <TextBlock x:Name="MonRamUsed" Text="— / — GB" Foreground="#5588cc" FontSize="11" Margin="0,2,0,0"/>

            <TextBlock Text="GPU" Style="{StaticResource MonSec}"/>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <ProgressBar x:Name="MonGpuBar" Height="8" Maximum="100" Value="0"
                           Background="#1a0a2e" Foreground="#ff6633" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonGpuPct" Grid.Column="1" Text="0%" Style="{StaticResource MonVal}" Margin="8,0,0,0"/>
            </Grid>
            <TextBlock x:Name="MonGpuSpark" Text="" Foreground="#bb5522" FontSize="10"
                       FontFamily="Consolas" Margin="0,2,0,0"/>
            <TextBlock x:Name="MonGpuTemp"  Text="Temp GPU: —" Foreground="#aa7733" FontSize="11" Margin="0,2,0,0"/>

            <TextBlock Text="DISCO (C:)" Style="{StaticResource MonSec}"/>
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <ProgressBar x:Name="MonDiskBar" Height="8" Maximum="100" Value="0"
                           Background="#1a0a2e" Foreground="#44dd88" VerticalAlignment="Center"/>
              <TextBlock x:Name="MonDiskPct" Grid.Column="1" Text="0%" Style="{StaticResource MonVal}" Margin="8,0,0,0"/>
            </Grid>
            <TextBlock x:Name="MonDiskFree" Text="Libre: — GB"  Foreground="#338855" FontSize="11" Margin="0,2,0,0"/>
            <TextBlock x:Name="MonDiskIO"   Text="↓— ↑—"        Foreground="#338855" FontSize="11"/>

            <TextBlock Text="RED" Style="{StaticResource MonSec}"/>
            <TextBlock x:Name="MonNetDl" Text="↓ —" Foreground="#66ccff" FontSize="12" FontFamily="Consolas"/>
            <TextBlock x:Name="MonNetUl" Text="↑ —" Foreground="#66aaff" FontSize="12" FontFamily="Consolas"/>

            <TextBlock Text="TOP PROCESOS" Style="{StaticResource MonSec}"/>
            <TextBlock x:Name="MonProc1" Text="—" Foreground="#cc99ff" FontSize="11" FontFamily="Consolas"/>
            <TextBlock x:Name="MonProc2" Text="—" Foreground="#aa77ee" FontSize="11" FontFamily="Consolas"/>
            <TextBlock x:Name="MonProc3" Text="—" Foreground="#8855cc" FontSize="11" FontFamily="Consolas"/>

            <TextBlock Text="SISTEMA" Style="{StaticResource MonSec}"/>
            <TextBlock x:Name="MonUptime" Text="Up: —"   Foreground="#aa88dd" FontSize="11"/>
            <TextBlock x:Name="MonOS"     Text="OS: —"   Foreground="#886699" FontSize="10" TextWrapping="Wrap"/>
            <TextBlock x:Name="MonHost"   Text="Host: —" Foreground="#886699" FontSize="10"/>

          </StackPanel>
        </ScrollViewer>

      </DockPanel>
    </Border>

  </Grid>
</Window>
'@

# ─── Build Window ─────────────────────────────────────────────────────────────
$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

function W { param($n) $window.FindName($n) }

$TabSecurity  = W "TabSecurity"
$TabClean     = W "TabClean"
$TabGaming    = W "TabGaming"
$TabTweaks    = W "TabTweaks"
$TabHardware  = W "TabHardware"
$TabProcesses = W "TabProcesses"
$TabNetwork   = W "TabNetwork"
$TabHistory   = W "TabHistory"

$ModGaming    = W "ModGaming"
$ModTrabajo   = W "ModTrabajo"
$ModAhorro    = W "ModAhorro"
$ModeLabel    = W "ModeLabel"

$LogPanel         = W "LogPanel"
$ProcPanel        = W "ProcPanel"
$HwPanel          = W "HwPanel"
$NetPanel         = W "NetPanel"
$HistPanel        = W "HistPanel"
$TweaksScrollView = W "TweaksScrollView"
$ToolbarSecurity  = W "ToolbarSecurity"
$ToolbarClean     = W "ToolbarClean"
$ToolbarGaming    = W "ToolbarGaming"
$ToolbarTweaks    = W "ToolbarTweaks"
$ConsoleScroll    = W "ConsoleScroll"
$ConsolePanel     = W "ConsolePanel"
$StatusBar        = W "StatusBar"
$JobStatus        = W "JobStatus"

$BtnSecScan     = W "BtnSecScan"
$BtnSecFix      = W "BtnSecFix"
$BtnSecExport   = W "BtnSecExport"
$BtnSecSchedule = W "BtnSecSchedule"
$BtnClean       = W "BtnClean"
$BtnCleanDism   = W "BtnCleanDism"
$BtnRamClean    = W "BtnRamClean"
$BtnGameApply   = W "BtnGameApply"
$BtnGameRestore = W "BtnGameRestore"
$BtnGameCheck   = W "BtnGameCheck"
$BtnKillProcs   = W "BtnKillProcs"
$BtnPingTest    = W "BtnPingTest"
$BtnFlushDns    = W "BtnFlushDns"
$BtnTelemetria      = W "BtnTelemetria"
$BtnCortana         = W "BtnCortana"
$BtnOneDrive        = W "BtnOneDrive"
$BtnNotif           = W "BtnNotif"
$BtnHibernate       = W "BtnHibernate"
$BtnPowerThrottling = W "BtnPowerThrottling"
$BtnQoS             = W "BtnQoS"
$BtnWin32Pri        = W "BtnWin32Pri"
$BtnStartupMgr      = W "BtnStartupMgr"
$ProcSearch    = W "ProcSearch"
$ProcList      = W "ProcList"
$ProcCount     = W "ProcCount"
$BtnProcRefresh= W "BtnProcRefresh"
$BtnProcKill   = W "BtnProcKill"
$BtnProcSuspend= W "BtnProcSuspend"
$BtnHwRefresh  = W "BtnHwRefresh"
$HwCpuName     = W "HwCpuName"
$HwCpuCores    = W "HwCpuCores"
$HwCpuSpeed    = W "HwCpuSpeed"
$HwCpuSocket   = W "HwCpuSocket"
$HwRamTotal    = W "HwRamTotal"
$HwRamUsed     = W "HwRamUsed"
$HwRamSlots    = W "HwRamSlots"
$HwRamSpeed    = W "HwRamSpeed"
$HwGpuName     = W "HwGpuName"
$HwGpuVram     = W "HwGpuVram"
$HwGpuDriver   = W "HwGpuDriver"
$HwMoboName    = W "HwMoboName"
$HwMoboMfg     = W "HwMoboMfg"
$HwBiosVer     = W "HwBiosVer"
$HwBiosDate    = W "HwBiosDate"
$HwDiskInfo    = W "HwDiskInfo"
$NetContent      = W "NetContent"
$BtnNetRefresh   = W "BtnNetRefresh"
$BtnNetConnTest  = W "BtnNetConnTest"
$BtnNetTrace     = W "BtnNetTrace"
$BtnNetFlushDns  = W "BtnNetFlushDns"
$BtnNetReset     = W "BtnNetReset"
$HistContent     = W "HistContent"
$BtnHistRefresh  = W "BtnHistRefresh"
$BtnHistClear    = W "BtnHistClear"
$HealthDot    = W "HealthDot"
$HealthScore  = W "HealthScore"
$HealthStatus = W "HealthStatus"
$MonCpuBar    = W "MonCpuBar"
$MonCpuPct    = W "MonCpuPct"
$MonCpuSpark  = W "MonCpuSpark"
$MonCpuTemp   = W "MonCpuTemp"
$MonRamBar    = W "MonRamBar"
$MonRamPct    = W "MonRamPct"
$MonRamUsed   = W "MonRamUsed"
$MonGpuBar    = W "MonGpuBar"
$MonGpuPct    = W "MonGpuPct"
$MonGpuSpark  = W "MonGpuSpark"
$MonGpuTemp   = W "MonGpuTemp"
$MonDiskBar   = W "MonDiskBar"
$MonDiskPct   = W "MonDiskPct"
$MonDiskFree  = W "MonDiskFree"
$MonDiskIO    = W "MonDiskIO"
$MonNetDl     = W "MonNetDl"
$MonNetUl     = W "MonNetUl"
$MonProc1     = W "MonProc1"
$MonProc2     = W "MonProc2"
$MonProc3     = W "MonProc3"
$MonUptime    = W "MonUptime"
$MonOS        = W "MonOS"
$MonHost      = W "MonHost"

# ─── Console helpers ──────────────────────────────────────────────────────────
$ColorMap = @{
    "[OK]"   = "#44cc88"
    "[WARN]" = "#ffaa00"
    "[BAD]"  = "#ff4455"
    "[CRIT]" = "#ff2244"
    "[INFO]" = "#66aaff"
    "[..]"   = "#aa88ff"
    "[--]"   = "#555577"
    "[!]"    = "#ffcc00"
    "[!!]"   = "#ff8800"
}

$BrushConv = [Windows.Media.BrushConverter]::new()

function New-Brush { param($hex) $BrushConv.ConvertFrom($hex) }

function Print-Line { param($line)
    $window.Dispatcher.Invoke([action]{
        if ($line -match '^=SECTION=(.+)$') {
            $tb = New-Object Windows.Controls.TextBlock
            $tb.Text = "── $($Matches[1]) ──────────────────────────────────"
            $tb.Foreground = New-Brush "#553377"
            $tb.FontSize = 11
            $tb.Margin = [Windows.Thickness]::new(0,10,0,4)
            $null = $ConsolePanel.Children.Add($tb)
        } elseif ($line -match '^\s*(\[[A-Z!\.]+\])\s+(.+)$') {
            $tag = $Matches[1]; $msg = $Matches[2]
            $hex = $ColorMap[$tag]; if (-not $hex) { $hex = "#ccbbee" }

            $sp = New-Object Windows.Controls.StackPanel
            $sp.Orientation = "Horizontal"
            $sp.Margin = [Windows.Thickness]::new(0,1,0,0)

            $tagTb = New-Object Windows.Controls.TextBlock
            $tagTb.Text = $tag
            $tagTb.Foreground = New-Brush $hex
            $tagTb.FontFamily = [Windows.Media.FontFamily]::new("Consolas")
            $tagTb.FontSize = 12
            $tagTb.Width = 52
            $tagTb.Margin = [Windows.Thickness]::new(0,0,6,0)

            $msgTb = New-Object Windows.Controls.TextBlock
            $msgTb.Text = $msg
            $msgTb.Foreground = New-Brush "#ddd0ff"
            $msgTb.FontSize = 12
            $msgTb.TextWrapping = "Wrap"

            $null = $sp.Children.Add($tagTb)
            $null = $sp.Children.Add($msgTb)
            $null = $ConsolePanel.Children.Add($sp)
        } else {
            $tb = New-Object Windows.Controls.TextBlock
            $tb.Text = $line
            $tb.Foreground = New-Brush "#776699"
            $tb.FontSize = 11
            $tb.Margin = [Windows.Thickness]::new(0,1,0,0)
            $null = $ConsolePanel.Children.Add($tb)
        }
        $ConsoleScroll.ScrollToBottom()
    })
}

function Console-Clear {
    $window.Dispatcher.Invoke([action]{ $ConsolePanel.Children.Clear() })
}

# ─── Tab switching ─────────────────────────────────────────────────────────────
$NavBtnActive = $window.FindResource("NavBtnActive")
$NavBtnStyle  = $window.FindResource("NavBtn")
$NavButtons   = @($TabSecurity,$TabClean,$TabGaming,$TabTweaks,$TabHardware,$TabProcesses,$TabNetwork,$TabHistory)

function Switch-Tab { param($name)
    $script:_ActiveTab = $name
    foreach ($b in $NavButtons) { $b.Style = $NavBtnStyle }

    $LogPanel.Visibility         = "Collapsed"
    $ProcPanel.Visibility        = "Collapsed"
    $HwPanel.Visibility          = "Collapsed"
    $NetPanel.Visibility         = "Collapsed"
    $HistPanel.Visibility        = "Collapsed"
    $TweaksScrollView.Visibility = "Collapsed"
    $ConsoleScroll.Visibility    = "Collapsed"
    $ToolbarSecurity.Visibility  = "Collapsed"
    $ToolbarClean.Visibility     = "Collapsed"
    $ToolbarGaming.Visibility    = "Collapsed"
    $ToolbarTweaks.Visibility    = "Collapsed"

    switch ($name) {
        "Security"  {
            $TabSecurity.Style = $NavBtnActive
            $LogPanel.Visibility = "Visible"
            $ConsoleScroll.Visibility = "Visible"
            $ToolbarSecurity.Visibility = "Visible"
        }
        "Clean"     {
            $TabClean.Style = $NavBtnActive
            $LogPanel.Visibility = "Visible"
            $ConsoleScroll.Visibility = "Visible"
            $ToolbarClean.Visibility = "Visible"
        }
        "Gaming"    {
            $TabGaming.Style = $NavBtnActive
            $LogPanel.Visibility = "Visible"
            $ConsoleScroll.Visibility = "Visible"
            $ToolbarGaming.Visibility = "Visible"
        }
        "Tweaks"    {
            $TabTweaks.Style = $NavBtnActive
            $LogPanel.Visibility = "Visible"
            $TweaksScrollView.Visibility = "Visible"
            $ToolbarTweaks.Visibility = "Visible"
        }
        "Hardware"  {
            $TabHardware.Style = $NavBtnActive
            $HwPanel.Visibility = "Visible"
            Load-HardwareInfo
        }
        "Processes" {
            $TabProcesses.Style = $NavBtnActive
            $ProcPanel.Visibility = "Visible"
            Refresh-Processes
        }
        "Network"   {
            $TabNetwork.Style = $NavBtnActive
            $NetPanel.Visibility = "Visible"
            Load-NetworkInfo
        }
        "History"   {
            $TabHistory.Style = $NavBtnActive
            $HistPanel.Visibility = "Visible"
            Render-History
        }
    }
}

$TabSecurity.Add_Click({  Switch-Tab "Security"  })
$TabClean.Add_Click({     Switch-Tab "Clean"     })
$TabGaming.Add_Click({    Switch-Tab "Gaming"    })
$TabTweaks.Add_Click({    Switch-Tab "Tweaks"    })
$TabHardware.Add_Click({  Switch-Tab "Hardware"  })
$TabProcesses.Add_Click({ Switch-Tab "Processes" })
$TabNetwork.Add_Click({   Switch-Tab "Network"   })
$TabHistory.Add_Click({   Switch-Tab "History"   })

# ─── Mode profiles ─────────────────────────────────────────────────────────────
$ModeBtnActive = $window.FindResource("ModeBtnActive")
$ModeBtnStyle  = $window.FindResource("ModeBtn")

function Set-Mode { param($mode)
    $script:_ActiveMode = $mode
    $ModGaming.Style = $ModTrabajo.Style = $ModAhorro.Style = $ModeBtnStyle
    switch ($mode) {
        "Gaming"  { $ModGaming.Style  = $ModeBtnActive; $ModeLabel.Text = "Modo: GAMING";  try { powercfg /setactive SCHEME_MIN } catch {} }
        "Trabajo" { $ModTrabajo.Style = $ModeBtnActive; $ModeLabel.Text = "Modo: TRABAJO"; try { powercfg /setactive SCHEME_BALANCED } catch {} }
        "Ahorro"  { $ModAhorro.Style  = $ModeBtnActive; $ModeLabel.Text = "Modo: AHORRO";  try { powercfg /setactive SCHEME_MAX } catch {} }
    }
    Print-Line "  [OK]  Perfil activado: $mode"
}

$ModGaming.Add_Click({  Set-Mode "Gaming"  })
$ModTrabajo.Add_Click({ Set-Mode "Trabajo" })
$ModAhorro.Add_Click({  Set-Mode "Ahorro"  })

# ─── Script runner (with streaming output) ────────────────────────────────────
function Run-Script { param($scriptPath, [hashtable]$extraArgs = @{}, $onDone = $null, $label = "")
    if ($script:_Job -and $script:_Job.State -eq "Running") {
        [System.Windows.MessageBox]::Show("Ya hay una tarea en ejecución.", "PC Toolkit") | Out-Null
        return
    }

    Console-Clear
    $StatusBar.Text = "Ejecutando: $label..."
    $JobStatus.Text = "● RUNNING"

    $streamFile = [System.IO.Path]::GetTempFileName()
    $script:_JobStream = $streamFile
    $ea2 = $extraArgs

    $script:_Job = Start-Job -ScriptBlock {
        param($sp, $sf, $ea)
        $params = @{ StreamFile = $sf } + $ea
        & $sp @params
    } -ArgumentList $scriptPath, $streamFile, $ea2

    $pos = 0
    $sf2 = $streamFile
    $lbl = $label
    $od  = $onDone

    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(200)
    $timer.Add_Tick({
        try {
            if (Test-Path $sf2) {
                $lines = [System.IO.File]::ReadAllLines($sf2)
                while ($pos -lt $lines.Count) {
                    $ln = $lines[$pos]; $pos++
                    if ($ln) { Print-Line $ln }
                }
            }
        } catch {}

        if ($script:_Job -and $script:_Job.State -ne "Running") {
            $timer.Stop()
            try {
                $lines2 = [System.IO.File]::ReadAllLines($sf2)
                while ($pos -lt $lines2.Count) {
                    $ln = $lines2[$pos]; $pos++
                    if ($ln) { Print-Line $ln }
                }
            } catch {}

            $result = $null
            try { $result = Receive-Job $script:_Job -ErrorAction SilentlyContinue } catch {}
            Remove-Job $script:_Job -Force -ErrorAction SilentlyContinue
            $script:_Job = $null
            try { Remove-Item $sf2 -Force -ErrorAction SilentlyContinue } catch {}

            $JobStatus.Text = ""
            $StatusBar.Text = "Listo"

            if ($od) { & $od $result }

            $script:_HistoryLog.Add(@{
                Time  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Label = $lbl
            })
        }
    })
    $timer.Start()
}

# ─── SECURITY ─────────────────────────────────────────────────────────────────
$BtnSecScan.Add_Click({
    Switch-Tab "Security"
    $secPath = Join-Path $ScriptsDir "SecurityCheck.ps1"
    Run-Script -scriptPath $secPath -label "Escaneo de Seguridad" -onDone {
        param($result)
        if ($result -and $result.PSObject.Properties["Alerts"]) {
            $script:_HealthSecCrit = @($result.Alerts | Where-Object { $_.Level -eq "CRIT" }).Count
            $script:_HealthSecWarn = @($result.Alerts | Where-Object { $_.Level -eq "WARN" }).Count
        }
    }
})

$BtnSecFix.Add_Click({
    Switch-Tab "Security"
    $secPath = Join-Path $ScriptsDir "SecurityCheck.ps1"
    Run-Script -scriptPath $secPath -extraArgs @{ ApplyFixes = $true } -label "Aplicar todos los fixes"
})

$BtnSecExport.Add_Click({
    $logDir = Join-Path $ScriptsDir "Logs"
    if (-not (Test-Path $logDir)) { New-Item $logDir -ItemType Directory | Out-Null }
    $htmlPath = Join-Path $logDir ("SecurityReport_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".html")

    $lines = $ConsolePanel.Children | ForEach-Object {
        if ($_ -is [Windows.Controls.StackPanel]) {
            ($_.Children | ForEach-Object { $_.Text }) -join " "
        } elseif ($_ -is [Windows.Controls.TextBlock]) {
            $_.Text
        }
    }
    $body = ($lines | ForEach-Object { "<p>$([System.Web.HttpUtility]::HtmlEncode($_))</p>" }) -join "`n"
    @"
<!DOCTYPE html><html><head><meta charset='utf-8'>
<title>PC Toolkit Security Report</title>
<style>body{background:#0a0015;color:#ddd0ff;font-family:Consolas,monospace;padding:24px;}
h1{color:#cc88ff;}p{margin:2px 0;font-size:13px;}</style></head>
<body><h1>PC Toolkit — Security Report</h1>
<p style='color:#664488'>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p><hr>
$body</body></html>
"@ | Out-File -FilePath $htmlPath -Encoding UTF8
    Print-Line "  [OK]  Reporte exportado: $htmlPath"
    try { Start-Process $htmlPath } catch {}
})

$BtnSecSchedule.Add_Click({
    $res = [System.Windows.MessageBox]::Show(
        "Crear tarea programada para escaneo diario a las 09:00?","Auto-escaneo","YesNo","Question")
    if ($res -eq "Yes") {
        $secPath = Join-Path $ScriptsDir "SecurityCheck.ps1"
        $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$secPath`""
        $trigger = New-ScheduledTaskTrigger -Daily -At "09:00"
        try {
            Register-ScheduledTask -TaskName "PCToolkit_SecurityScan" -Action $action `
                -Trigger $trigger -RunLevel Highest -Force -ErrorAction Stop
            Print-Line "  [OK]  Tarea programada creada: escaneo diario 09:00"
        } catch {
            Print-Line "  [!!]  Error creando tarea: $_"
        }
    }
})

# ─── CLEAN ────────────────────────────────────────────────────────────────────
$BtnClean.Add_Click({
    Switch-Tab "Clean"
    $cleanPath = Join-Path $ScriptsDir "CleanPC.ps1"
    Run-Script -scriptPath $cleanPath -label "Limpieza del sistema" -onDone {
        param($result)
        if ($result -and $result.PSObject.Properties["TotalGB"]) {
            Print-Line "  [OK]  Total liberado: $($result.TotalGB) GB"
        }
    }
})

$BtnCleanDism.Add_Click({
    Switch-Tab "Clean"
    $cleanPath = Join-Path $ScriptsDir "CleanPC.ps1"
    Run-Script -scriptPath $cleanPath -extraArgs @{ IncludeDISM = $true } -label "Limpieza + DISM"
})

$BtnRamClean.Add_Click({
    Print-Line "=SECTION=LIMPIEZA DE RAM"
    Print-Line "  [..]  Vaciando working sets de procesos..."
    $j = Start-Job -ScriptBlock {
        Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public class WS{[DllImport("psapi.dll")]public static extern bool EmptyWorkingSet(IntPtr h);}
"@
        Get-Process | ForEach-Object { try { [WS]::EmptyWorkingSet($_.Handle) | Out-Null } catch {} }
    }
    $t2 = New-Object Windows.Threading.DispatcherTimer
    $t2.Interval = [TimeSpan]::FromMilliseconds(300)
    $t2.Add_Tick({
        if ($j.State -ne "Running") {
            $t2.Stop()
            Receive-Job $j | Out-Null
            Remove-Job $j -Force
            Print-Line "  [OK]  RAM working sets vaciados"
        }
    })
    $t2.Start()
})

# ─── GAMING ───────────────────────────────────────────────────────────────────
$BtnGameApply.Add_Click({
    Switch-Tab "Gaming"
    $gamePath = Join-Path $ScriptsDir "GameBoost.ps1"
    Run-Script -scriptPath $gamePath -extraArgs @{ Action = "Apply" } -label "GameBoost Aplicar"
})
$BtnGameRestore.Add_Click({
    Switch-Tab "Gaming"
    $gamePath = Join-Path $ScriptsDir "GameBoost.ps1"
    Run-Script -scriptPath $gamePath -extraArgs @{ Action = "Restore" } -label "GameBoost Restaurar"
})
$BtnGameCheck.Add_Click({
    Switch-Tab "Gaming"
    $gamePath = Join-Path $ScriptsDir "GameBoost.ps1"
    Run-Script -scriptPath $gamePath -extraArgs @{ Action = "Check" } -label "GameBoost Verificar"
})

$BtnKillProcs.Add_Click({
    Switch-Tab "Gaming"
    Print-Line "=SECTION=MATAR PROCESOS NO ESENCIALES"
    @("Discord","chrome","msedge","OneDrive","Teams","slack","Spotify","EpicGamesLauncher","nvcontainer","Cortana") | ForEach-Object {
        $found = Get-Process -Name $_ -ErrorAction SilentlyContinue
        if ($found) {
            $found | Stop-Process -Force -ErrorAction SilentlyContinue
            Print-Line "  [OK]  Terminado: $_"
        } else {
            Print-Line "  [--]  No corriendo: $_"
        }
    }
})

$BtnPingTest.Add_Click({
    Switch-Tab "Gaming"
    Print-Line "=SECTION=PING TEST"
    @{
        "Riot NA"    = "104.160.131.3"
        "Steam"      = "208.64.200.50"
        "Cloudflare" = "1.1.1.1"
        "Google DNS" = "8.8.8.8"
    }.GetEnumerator() | ForEach-Object {
        $ping = New-Object System.Net.NetworkInformation.Ping
        try {
            $reply = $ping.Send($_.Value, 1000)
            if ($reply.Status -eq "Success") {
                $ms = $reply.RoundtripTime
                $tag = if ($ms -lt 50) {"[OK]"} elseif ($ms -lt 100) {"[WARN]"} else {"[BAD]"}
                Print-Line "  $tag  $($_.Key): ${ms}ms"
            } else { Print-Line "  [BAD]  $($_.Key): timeout" }
        } catch { Print-Line "  [!!]  $($_.Key): error" }
    }
})

$BtnFlushDns.Add_Click({
    Print-Line "=SECTION=FLUSH DNS"
    try {
        & ipconfig /flushdns 2>&1 | Out-Null
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Print-Line "  [OK]  Cache DNS vaciada"
    } catch { Print-Line "  [!!]  Error: $_" }
})

# ─── TWEAKS ───────────────────────────────────────────────────────────────────
function Apply-Tweak { param($name, [scriptblock]$block)
    try { & $block; Print-Line "  [OK]  $name aplicado" }
    catch { Print-Line "  [!!]  Error en $name`: $_" }
}

$BtnTelemetria.Add_Click({
    Apply-Tweak "Telemetría" {
        $k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
        Set-ItemProperty $k -Name AllowTelemetry -Value 0 -Type DWord -Force
        Stop-Service DiagTrack -Force -EA SilentlyContinue
        Set-Service DiagTrack -StartupType Disabled -EA SilentlyContinue
    }
})
$BtnCortana.Add_Click({
    Apply-Tweak "Cortana" {
        $k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
        Set-ItemProperty $k -Name AllowCortana -Value 0 -Type DWord -Force
        Set-ItemProperty $k -Name DisableWebSearch -Value 1 -Type DWord -Force
    }
})
$BtnOneDrive.Add_Click({
    Apply-Tweak "OneDrive" {
        $k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
        Set-ItemProperty $k -Name DisableFileSyncNGSC -Value 1 -Type DWord -Force
        Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -EA SilentlyContinue
    }
})
$BtnNotif.Add_Click({
    Apply-Tweak "Notificaciones" {
        $k = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
        if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
        Set-ItemProperty $k -Name DisableNotificationCenter -Value 1 -Type DWord -Force
    }
})
$BtnHibernate.Add_Click({
    Apply-Tweak "Hibernación" { & powercfg /hibernate off }
})
$BtnPowerThrottling.Add_Click({
    Apply-Tweak "Power Throttling" {
        $k = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
        if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
        Set-ItemProperty $k -Name PowerThrottlingOff -Value 1 -Type DWord -Force
    }
})
$BtnQoS.Add_Click({
    Apply-Tweak "QoS Bandwidth" {
        $k = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
        if (-not (Test-Path $k)) { New-Item $k -Force | Out-Null }
        Set-ItemProperty $k -Name NonBestEffortLimit -Value 0 -Type DWord -Force
    }
})
$BtnWin32Pri.Add_Click({
    Apply-Tweak "Win32 Priority" {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" `
            -Name Win32PrioritySeparation -Value 0x26 -Type DWord -Force
    }
})
$BtnStartupMgr.Add_Click({
    try { Start-Process "ms-settings:startupapps" } catch { Start-Process taskmgr.exe }
})

# ─── HARDWARE ─────────────────────────────────────────────────────────────────
function Load-HardwareInfo {
    $StatusBar.Text = "Cargando hardware..."
    $j = Start-Job -ScriptBlock {
        $cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1
        $cs   = Get-CimInstance Win32_ComputerSystem
        $os   = Get-CimInstance Win32_OperatingSystem
        $gpu  = Get-CimInstance Win32_VideoController | Where-Object { $_.PNPDeviceID -like "PCI*" } | Select-Object -First 1
        if (-not $gpu) { $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 }
        $mobo = Get-CimInstance Win32_BaseBoard
        $bios = Get-CimInstance Win32_BIOS
        $ram  = Get-CimInstance Win32_PhysicalMemory
        $disks= Get-CimInstance Win32_DiskDrive
        [PSCustomObject]@{
            CpuName   = $cpu.Name
            CpuCores  = "$($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads"
            CpuSpeed  = "$([math]::Round($cpu.MaxClockSpeed/1000,1)) GHz"
            CpuSocket = $cpu.SocketDesignation
            RamTotal  = "$([math]::Round($cs.TotalPhysicalMemory/1GB,0)) GB"
            RamUsed   = "$([math]::Round(($cs.TotalPhysicalMemory - $os.FreePhysicalMemory*1KB)/1GB,1)) GB usados"
            RamSlots  = "$($ram.Count) módulo(s)"
            RamSpeed  = "$($ram[0].Speed) MHz"
            GpuName   = $gpu.Name
            GpuVram   = "$([math]::Round($gpu.AdapterRAM/1GB,1)) GB VRAM"
            GpuDriver = $gpu.DriverVersion
            MoboName  = $mobo.Product
            MoboMfg   = $mobo.Manufacturer
            BiosVer   = $bios.SMBIOSBIOSVersion
            BiosDate  = "$($bios.ReleaseDate)"
            DiskInfo  = ($disks | ForEach-Object { "$($_.Model) — $([math]::Round($_.Size/1GB,0)) GB ($($_.MediaType))" }) -join "`n"
        }
    }
    $t2 = New-Object Windows.Threading.DispatcherTimer
    $t2.Interval = [TimeSpan]::FromMilliseconds(300)
    $t2.Add_Tick({
        if ($j.State -ne "Running") {
            $t2.Stop()
            $r = Receive-Job $j -EA SilentlyContinue
            Remove-Job $j -Force
            if ($r) {
                $HwCpuName.Text   = $r.CpuName
                $HwCpuCores.Text  = $r.CpuCores
                $HwCpuSpeed.Text  = $r.CpuSpeed
                $HwCpuSocket.Text = "Socket: $($r.CpuSocket)"
                $HwRamTotal.Text  = $r.RamTotal
                $HwRamUsed.Text   = $r.RamUsed
                $HwRamSlots.Text  = $r.RamSlots
                $HwRamSpeed.Text  = $r.RamSpeed
                $HwGpuName.Text   = $r.GpuName
                $HwGpuVram.Text   = $r.GpuVram
                $HwGpuDriver.Text = "Driver: $($r.GpuDriver)"
                $HwMoboName.Text  = $r.MoboName
                $HwMoboMfg.Text   = $r.MoboMfg
                $HwBiosVer.Text   = "BIOS: $($r.BiosVer)"
                $HwBiosDate.Text  = "Fecha: $($r.BiosDate)"
                $HwDiskInfo.Text  = $r.DiskInfo
            }
            $StatusBar.Text = "Listo"
        }
    })
    $t2.Start()
}
$BtnHwRefresh.Add_Click({ Load-HardwareInfo })

# ─── PROCESSES ────────────────────────────────────────────────────────────────
function Refresh-Processes {
    $StatusBar.Text = "Cargando procesos..."
    $f = $ProcSearch.Text.Trim()
    $j = Start-Job -ScriptBlock {
        param($filter)
        Get-Process | Sort-Object CPU -Descending | ForEach-Object {
            if ($filter -and $_.Name -notlike "*$filter*") { return }
            [PSCustomObject]@{
                PID     = $_.Id
                Name    = $_.Name
                CPU     = [math]::Round($_.CPU, 1)
                RAM     = [math]::Round($_.WorkingSet64/1MB, 1)
                Handles = $_.HandleCount
                User    = ""
            }
        }
    } -ArgumentList $f

    $t2 = New-Object Windows.Threading.DispatcherTimer
    $t2.Interval = [TimeSpan]::FromMilliseconds(300)
    $t2.Add_Tick({
        if ($j.State -ne "Running") {
            $t2.Stop()
            $items = @(Receive-Job $j -EA SilentlyContinue)
            Remove-Job $j -Force
            $ProcList.ItemsSource = $items
            $ProcCount.Text = "Total: $($items.Count) procesos"
            $StatusBar.Text = "Listo"
        }
    })
    $t2.Start()
}

$BtnProcRefresh.Add_Click({ Refresh-Processes })
$ProcSearch.Add_KeyDown({ param($s,$e); if ($e.Key -eq "Return") { Refresh-Processes } })

$BtnProcKill.Add_Click({
    $sel = $ProcList.SelectedItem
    if (-not $sel) { [System.Windows.MessageBox]::Show("Selecciona un proceso primero.","PC Toolkit") | Out-Null; return }
    $res = [System.Windows.MessageBox]::Show(
        "¿Matar proceso $($sel.Name) (PID $($sel.PID))?","Confirmar","YesNo","Warning")
    if ($res -eq "Yes") {
        try {
            Stop-Process -Id $sel.PID -Force -EA Stop
            Refresh-Processes
        } catch {
            [System.Windows.MessageBox]::Show("Error: $_","PC Toolkit") | Out-Null
        }
    }
})
$BtnProcSuspend.Add_Click({
    $sel = $ProcList.SelectedItem
    if (-not $sel) { [System.Windows.MessageBox]::Show("Selecciona un proceso primero.","PC Toolkit") | Out-Null; return }
    Print-Line "  [INFO]  Suspend requiere NtSuspendProcess (no incluido por seguridad)"
})

# ─── NETWORK ─────────────────────────────────────────────────────────────────
function Add-NetLine { param($text, $color = "#ddd0ff", $size = 12, $family = "Segoe UI")
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $text
    $tb.Foreground = New-Brush $color
    $tb.FontSize = $size
    $tb.Margin = [Windows.Thickness]::new(0,2,0,0)
    if ($family -ne "Segoe UI") { $tb.FontFamily = [Windows.Media.FontFamily]::new($family) }
    $null = $NetContent.Children.Add($tb)
}

function Load-NetworkInfo {
    $NetContent.Children.Clear()
    $StatusBar.Text = "Cargando red..."
    $j = Start-Job -ScriptBlock {
        $adapters = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } |
            ForEach-Object { "$($_.Name) — $($_.InterfaceDescription) — $($_.LinkSpeed)" })
        $ips = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } |
            ForEach-Object { "$($_.InterfaceAlias): $($_.IPv4Address.IPAddress) / GW: $($_.IPv4DefaultGateway.NextHop)" })
        $dns = (Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } |
            ForEach-Object { "$($_.InterfaceAlias): $($_.ServerAddresses -join ', ')" })
        $ext = try { (Invoke-WebRequest "https://api.ipify.org" -UseBasicParsing -TimeoutSec 4).Content } catch { "N/A" }
        [PSCustomObject]@{ Adapters=$adapters; IPs=$ips; DNS=$dns; ExtIP=$ext }
    }
    $t2 = New-Object Windows.Threading.DispatcherTimer
    $t2.Interval = [TimeSpan]::FromMilliseconds(400)
    $t2.Add_Tick({
        if ($j.State -ne "Running") {
            $t2.Stop()
            $r = Receive-Job $j -EA SilentlyContinue
            Remove-Job $j -Force
            if ($r) {
                @{
                    "ADAPTADORES ACTIVOS" = $r.Adapters
                    "DIRECCIONES IP"      = $r.IPs
                    "SERVIDORES DNS"      = $r.DNS
                    "IP EXTERNA"          = @("IP: $($r.ExtIP)")
                }.GetEnumerator() | ForEach-Object {
                    Add-NetLine $_.Key "#bb88ff" 10
                    foreach ($line in $_.Value) { Add-NetLine $line }
                }
            }
            $StatusBar.Text = "Listo"
        }
    })
    $t2.Start()
}

$BtnNetRefresh.Add_Click({ Load-NetworkInfo })

$BtnNetConnTest.Add_Click({
    $NetContent.Children.Clear()
    Add-NetLine "TEST DE CONEXIÓN" "#bb88ff" 10
    @("8.8.8.8","1.1.1.1","google.com","cloudflare.com") | ForEach-Object {
        $t_ = $_
        $ping = New-Object System.Net.NetworkInformation.Ping
        try {
            $reply = $ping.Send($t_, 2000)
            if ($reply.Status -eq "Success") {
                Add-NetLine "$t_ → OK  $($reply.RoundtripTime)ms" "#44cc88" 12 "Consolas"
            } else { Add-NetLine "$t_ → TIMEOUT" "#ff4455" 12 "Consolas" }
        } catch { Add-NetLine "$t_ → ERROR" "#ff4455" 12 "Consolas" }
    }
})

$BtnNetTrace.Add_Click({
    Add-Type -AssemblyName Microsoft.VisualBasic
    $host_ = [Microsoft.VisualBasic.Interaction]::InputBox("Host destino:","Traceroute","8.8.8.8")
    if (-not $host_) { return }
    $NetContent.Children.Clear()
    Add-NetLine "TRACEROUTE → $host_" "#bb88ff" 10

    $j = Start-Job -ScriptBlock { param($h); & tracert -d -h 15 $h 2>&1 } -ArgumentList $host_
    $t2 = New-Object Windows.Threading.DispatcherTimer
    $t2.Interval = [TimeSpan]::FromMilliseconds(500)
    $t2.Add_Tick({
        if ($j.State -ne "Running") {
            $t2.Stop()
            $lines = Receive-Job $j -EA SilentlyContinue
            Remove-Job $j -Force
            foreach ($l in $lines) { Add-NetLine "$l" "#ddd0ff" 11 "Consolas" }
        }
    })
    $t2.Start()
})

$BtnNetFlushDns.Add_Click({
    try {
        & ipconfig /flushdns 2>&1 | Out-Null
        Clear-DnsClientCache -EA SilentlyContinue
        Add-NetLine "[OK] Cache DNS vaciada" "#44cc88"
    } catch { Add-NetLine "[!!] Error" "#ff4455" }
})

$BtnNetReset.Add_Click({
    $res = [System.Windows.MessageBox]::Show("Reiniciar adaptador activo?","Confirmar","YesNo","Warning")
    if ($res -eq "Yes") {
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if ($adapter) {
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -EA SilentlyContinue
            Start-Sleep -Milliseconds 1500
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -EA SilentlyContinue
            Add-NetLine "[OK] Adaptador $($adapter.Name) reiniciado" "#44cc88"
        }
    }
})

# ─── HISTORY ─────────────────────────────────────────────────────────────────
function Render-History {
    $HistContent.Children.Clear()
    if ($script:_HistoryLog.Count -eq 0) {
        $tb = New-Object Windows.Controls.TextBlock
        $tb.Text = "Sin historial en esta sesión."
        $tb.Foreground = New-Brush "#664488"
        $tb.FontSize = 12
        $tb.Margin = [Windows.Thickness]::new(0,8,0,0)
        $null = $HistContent.Children.Add($tb)
        return
    }
    foreach ($entry in ($script:_HistoryLog | Sort-Object { $_["Time"] } -Descending)) {
        $border = New-Object Windows.Controls.Border
        $border.Background = New-Brush "#0d0020"
        $border.CornerRadius = [Windows.CornerRadius]::new(8)
        $border.Padding = [Windows.Thickness]::new(14,10,14,10)
        $border.Margin  = [Windows.Thickness]::new(0,0,0,8)
        $sp = New-Object Windows.Controls.StackPanel
        $t1 = New-Object Windows.Controls.TextBlock
        $t1.Text = $entry["Time"]
        $t1.Foreground = New-Brush "#664488"
        $t1.FontSize = 10
        $t2_ = New-Object Windows.Controls.TextBlock
        $t2_.Text = $entry["Label"]
        $t2_.Foreground = New-Brush "#ddd0ff"
        $t2_.FontSize = 13
        $t2_.FontWeight = "SemiBold"
        $t2_.Margin = [Windows.Thickness]::new(0,2,0,0)
        $null = $sp.Children.Add($t1)
        $null = $sp.Children.Add($t2_)
        $border.Child = $sp
        $null = $HistContent.Children.Add($border)
    }
}

$BtnHistRefresh.Add_Click({ Render-History })
$BtnHistClear.Add_Click({
    $res = [System.Windows.MessageBox]::Show("¿Limpiar historial?","Confirmar","YesNo","Question")
    if ($res -eq "Yes") { $script:_HistoryLog.Clear(); Render-History }
})

# ─── MONITOR LIVE ─────────────────────────────────────────────────────────────
try { $script:_DiskReadCtr  = New-Object System.Diagnostics.PerformanceCounter("PhysicalDisk","Disk Read Bytes/sec","_Total") } catch {}
try { $script:_DiskWriteCtr = New-Object System.Diagnostics.PerformanceCounter("PhysicalDisk","Disk Write Bytes/sec","_Total") } catch {}
try {
    $netInst = (New-Object System.Diagnostics.PerformanceCounterCategory("Network Interface")).GetInstanceNames() | Select-Object -First 1
    $script:_NetDlCtr = New-Object System.Diagnostics.PerformanceCounter("Network Interface","Bytes Received/sec",$netInst)
    $script:_NetUlCtr = New-Object System.Diagnostics.PerformanceCounter("Network Interface","Bytes Sent/sec",$netInst)
} catch {}

$sparkChars = [char[]]@(0x20,0x2581,0x2582,0x2583,0x2584,0x2585,0x2586,0x2587,0x2588)

function Get-Spark { param([System.Collections.Generic.List[double]]$hist)
    if ($hist.Count -eq 0) { return "" }
    $max = ($hist | Measure-Object -Maximum).Maximum
    if ($max -lt 1) { $max = 1 }
    -join ($hist | ForEach-Object {
        $idx = [int][math]::Round($_ / $max * 8)
        if ($idx -gt 8) { $idx = 8 }
        $sparkChars[$idx]
    })
}

$lastTempC = 0

function Update-MonitorDisplay {
    try {
        # CPU
        $samples = (Get-Counter '\Processor(_Total)\% Processor Time' -EA SilentlyContinue).CounterSamples
        $cpuPct = if ($samples) { [math]::Round($samples[0].CookedValue, 1) } else { 0 }
        $script:_CpuHistory.Add($cpuPct)
        if ($script:_CpuHistory.Count -gt 20) { $script:_CpuHistory.RemoveAt(0) }
        $MonCpuBar.Value = $cpuPct
        $MonCpuPct.Text  = "$cpuPct%"
        $MonCpuSpark.Text = Get-Spark $script:_CpuHistory

        # CPU Temp (WMI thermal)
        try {
            $tempObj = Get-CimInstance -Namespace "root/WMI" -ClassName MSAcpi_ThermalZoneTemperature -EA SilentlyContinue | Select-Object -First 1
            if ($tempObj) {
                $lastTempC = [math]::Round(($tempObj.CurrentTemperature - 2732) / 10, 1)
                $MonCpuTemp.Text = "Temp: ${lastTempC}°C"
                $MonCpuTemp.Foreground = New-Brush (if ($lastTempC -gt 85) {"#ff4455"} elseif ($lastTempC -gt 70) {"#ffaa00"} else {"#44cc88"})
            }
        } catch {}

        # RAM
        $os2 = Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue
        if ($os2) {
            $totalRam = [math]::Round($os2.TotalVisibleMemorySize / 1MB, 1)
            $freeRam  = [math]::Round($os2.FreePhysicalMemory / 1MB, 1)
            $usedRam  = [math]::Round($totalRam - $freeRam, 1)
            $ramPct   = if ($totalRam -gt 0) { [math]::Round($usedRam / $totalRam * 100, 0) } else { 0 }
            $MonRamBar.Value = $ramPct
            $MonRamPct.Text  = "$ramPct%"
            $MonRamUsed.Text = "$usedRam / $totalRam GB"
        } else { $ramPct = 0 }

        # GPU (counter or CIM)
        $gpuPct = 0
        try {
            if (-not $script:_GpuCounter) {
                $script:_GpuCounter = New-Object System.Diagnostics.PerformanceCounter("GPU Engine","Utilization Percentage","*","True")
            }
            $gpuPct = [math]::Min(100, [math]::Round($script:_GpuCounter.NextValue(), 1))
        } catch {}
        $script:_GpuHistory.Add($gpuPct)
        if ($script:_GpuHistory.Count -gt 20) { $script:_GpuHistory.RemoveAt(0) }
        $MonGpuBar.Value = $gpuPct
        $MonGpuPct.Text  = "$gpuPct%"
        $MonGpuSpark.Text = Get-Spark $script:_GpuHistory

        # Disk space
        $disk = Get-PSDrive C -EA SilentlyContinue
        if ($disk) {
            $dFree  = [math]::Round($disk.Free/1GB, 1)
            $dUsed  = [math]::Round($disk.Used/1GB, 1)
            $dTotal = $dFree + $dUsed
            $dPct   = if ($dTotal -gt 0) { [math]::Round($dUsed/$dTotal*100, 0) } else { 0 }
            $MonDiskBar.Value = $dPct
            $MonDiskPct.Text  = "$dPct%"
            $MonDiskFree.Text = "Libre: $dFree GB"
        }
        try {
            $dr = if ($script:_DiskReadCtr)  { [math]::Round($script:_DiskReadCtr.NextValue()/1KB,0) } else { 0 }
            $dw = if ($script:_DiskWriteCtr) { [math]::Round($script:_DiskWriteCtr.NextValue()/1KB,0) } else { 0 }
            $MonDiskIO.Text = "↓${dr}KB/s ↑${dw}KB/s"
        } catch {}

        # Network
        try {
            $dl = if ($script:_NetDlCtr) { [math]::Round($script:_NetDlCtr.NextValue()/1KB,1) } else { 0 }
            $ul = if ($script:_NetUlCtr) { [math]::Round($script:_NetUlCtr.NextValue()/1KB,1) } else { 0 }
            $MonNetDl.Text = "↓ ${dl} KB/s"
            $MonNetUl.Text = "↑ ${ul} KB/s"
        } catch {}

        # Top procs
        $topP = Get-Process | Sort-Object CPU -Descending | Select-Object -First 3
        $pL = @($MonProc1,$MonProc2,$MonProc3)
        for ($i = 0; $i -lt 3; $i++) {
            if ($topP[$i]) {
                $p = $topP[$i]
                $rmb = [math]::Round($p.WorkingSet64/1MB,0)
                $cv  = [math]::Round($p.CPU,0)
                $nm  = $p.Name
                if ($nm.Length -gt 16) { $nm = $nm.Substring(0,16) }
                $pL[$i].Text = $nm.PadRight(16) + " C:${cv}s R:${rmb}MB"
            } else { $pL[$i].Text = "—" }
        }

        # Uptime
        try {
            $boot = (Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue).LastBootUpTime
            if ($boot) {
                $up = [datetime]::Now - $boot
                $MonUptime.Text = "Up: $($up.Days)d $($up.Hours)h $($up.Minutes)m"
            }
        } catch {}
        $MonOS.Text   = "OS: Windows $([System.Environment]::OSVersion.Version.Major)"
        $MonHost.Text = "Host: $([System.Environment]::MachineName)"

        # Health score
        $rp = if ($ramPct -gt 90) {20} elseif ($ramPct -gt 75) {10} else {0}
        $tp = if ($lastTempC -gt 85) {20} elseif ($lastTempC -gt 70) {10} else {0}
        $health = [math]::Max(0, 100 - $rp - $tp - ($script:_HealthSecCrit*15) - ($script:_HealthSecWarn*3))
        $HealthScore.Text = "$health"
        if ($health -ge 80) {
            $HealthScore.Foreground = New-Brush "#44cc88"
            $HealthDot.Fill = New-Brush "#44cc88"
            $HealthStatus.Text = "Sistema saludable"
        } elseif ($health -ge 50) {
            $HealthScore.Foreground = New-Brush "#ffaa00"
            $HealthDot.Fill = New-Brush "#ffaa00"
            $HealthStatus.Text = "Revisar alertas"
        } else {
            $HealthScore.Foreground = New-Brush "#ff4455"
            $HealthDot.Fill = New-Brush "#ff4455"
            $HealthStatus.Text = "Acción requerida"
        }
    } catch {}
}

$monTimer = New-Object Windows.Threading.DispatcherTimer
$monTimer.Interval = [TimeSpan]::FromSeconds(2)
$monTimer.Add_Tick({ Update-MonitorDisplay })
$monTimer.Start()

# ─── System tray ──────────────────────────────────────────────────────────────
function Setup-Tray {
    $tray = New-Object System.Windows.Forms.NotifyIcon
    $tray.Text = "PC Toolkit"
    $tray.Icon = [System.Drawing.SystemIcons]::Application
    $tray.Visible = $true

    $menu = New-Object System.Windows.Forms.ContextMenuStrip

    $openItem = New-Object System.Windows.Forms.ToolStripMenuItem "Abrir PC Toolkit"
    $openItem.Add_Click({
        $window.Dispatcher.Invoke([action]{
            $window.Show()
            $window.WindowState = "Normal"
            $window.Activate()
        })
    })

    $gamItem = New-Object System.Windows.Forms.ToolStripMenuItem "Gaming Mode ON/OFF"
    $gamItem.Add_Click({
        $backupFile = Join-Path $ScriptsDir "GameBoost_Backup.json"
        $gp = Join-Path $ScriptsDir "GameBoost.ps1"
        $action = if (Test-Path $backupFile) { "Restore" } else { "Apply" }
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$gp`" -Action $action" -Verb RunAs
    })

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem "Salir"
    $exitItem.Add_Click({
        $tray.Visible = $false
        $tray.Dispose()
        $window.Dispatcher.Invoke([action]{ $window.Close() })
    })

    $null = $menu.Items.Add($openItem)
    $null = $menu.Items.Add($gamItem)
    $null = $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $null = $menu.Items.Add($exitItem)
    $tray.ContextMenuStrip = $menu
    $tray.Add_DoubleClick({
        $window.Dispatcher.Invoke([action]{
            $window.Show()
            $window.WindowState = "Normal"
            $window.Activate()
        })
    })

    $window.Add_StateChanged({
        if ($window.WindowState -eq "Minimized") { $window.Hide() }
    })

    $window.Add_Closing({
        param($s,$e)
        $e.Cancel = $true
        $window.Hide()
        $tray.ShowBalloonTip(2000,"PC Toolkit","Minimizado al área de sistema",[System.Windows.Forms.ToolTipIcon]::Info)
    })
}

# ─── Init ─────────────────────────────────────────────────────────────────────
$window.Add_Loaded({
    Console-Clear
    Print-Line "=SECTION=PC TOOLKIT v3.0 — BY IRREBOY"
    Print-Line "  [OK]  Interfaz cargada correctamente"
    Print-Line "  [INFO]  Selecciona un módulo del panel izquierdo"

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Print-Line "  [OK]  Corriendo como Administrador"
    } else {
        Print-Line "  [WARN]  Sin privilegios de Administrador — algunas funciones fallarán"
    }

    Update-MonitorDisplay
    try { Setup-Tray } catch {}
    $StatusBar.Text = "Listo — PC Toolkit v3.0"
})

$window.ShowDialog() | Out-Null
