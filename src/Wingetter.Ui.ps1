# ============================================================================
# SPLASH SCREEN (pure code - no XAML FindName issues)
# ============================================================================
function Show-Splash {
    $bc = New-Object System.Windows.Media.BrushConverter

    $win = New-Object System.Windows.Window
    $win.WindowStyle = [System.Windows.WindowStyle]::None
    $win.AllowsTransparency = $true
    $win.Background = [System.Windows.Media.Brushes]::Transparent
    $win.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
    $win.Width = 540; $win.Height = 300
    $win.Topmost = $true; $win.ShowInTaskbar = $false
    $win.ResizeMode = [System.Windows.ResizeMode]::NoResize

    # Outer border with shadow
    $outer = New-Object System.Windows.Controls.Border
    $outer.Background = $bc.ConvertFromString("#08131f")
    $outer.CornerRadius = [System.Windows.CornerRadius]::new(18)
    $outer.BorderBrush = $bc.ConvertFromString("#24374a")
    $outer.BorderThickness = [System.Windows.Thickness]::new(1.5, 1.5, 1.5, 1.5)
    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.BlurRadius = 30; $shadow.Opacity = 0.5; $shadow.ShadowDepth = 0
    $outer.Effect = $shadow

    $grid = New-Object System.Windows.Controls.Grid
    $outer.Child = $grid

    # Top gradient accent line
    $accentLine = New-Object System.Windows.Controls.Border
    $accentLine.Height = 3
    $accentLine.VerticalAlignment = [System.Windows.VerticalAlignment]::Top
    $accentLine.CornerRadius = [System.Windows.CornerRadius]::new(18, 18, 0, 0)
    $grad = New-Object System.Windows.Media.LinearGradientBrush
    $grad.StartPoint = [System.Windows.Point]::new(0, 0)
    $grad.EndPoint = [System.Windows.Point]::new(1, 0)
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#3da4ff"), 0)))
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#7dd3fc"), 0.55)))
    $grad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#22c55e"), 1)))
    $accentLine.Background = $grad
    [void]$grid.Children.Add($accentLine)

    # Center stack
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $stack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center

    # Title "Wingetter" with gradient
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = "Wingetter"
    $title.FontSize = 46; $title.FontWeight = [System.Windows.FontWeights]::Bold
    $title.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $title.Margin = [System.Windows.Thickness]::new(0, 0, 0, 2)
    $titleGrad = New-Object System.Windows.Media.LinearGradientBrush
    $titleGrad.StartPoint = [System.Windows.Point]::new(0, 0)
    $titleGrad.EndPoint = [System.Windows.Point]::new(1, 0)
    $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#8cd2ff"), 0)))
    $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#d3f1ff"), 1)))
    $title.Foreground = $titleGrad
    [void]$stack.Children.Add($title)

    # Version
    $ver = New-Object System.Windows.Controls.TextBlock
    $ver.Text = "v6.1.0"; $ver.FontSize = 12
    $ver.Foreground = $bc.ConvertFromString("#7a90a6")
    $ver.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $ver.Margin = [System.Windows.Thickness]::new(0, 0, 0, 24)
    [void]$stack.Children.Add($ver)

    # Status text
    $statusTb = New-Object System.Windows.Controls.TextBlock
    $statusTb.Text = "Initializing..."
    $statusTb.FontSize = 13
    $statusTb.Foreground = $bc.ConvertFromString("#9db0c2")
    $statusTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $statusTb.Margin = [System.Windows.Thickness]::new(0, 0, 0, 14)
    [void]$stack.Children.Add($statusTb)

    # Progress bar container
    $barBg = New-Object System.Windows.Controls.Border
    $barBg.Background = $bc.ConvertFromString("#132132")
    $barBg.CornerRadius = [System.Windows.CornerRadius]::new(4)
    $barBg.Height = 6; $barBg.Width = 340
    $barBg.Margin = [System.Windows.Thickness]::new(0, 0, 0, 10)

    # Progress bar fill
    $barFill = New-Object System.Windows.Controls.Border
    $barFill.CornerRadius = [System.Windows.CornerRadius]::new(4)
    $barFill.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $barFill.Width = 0; $barFill.Height = 6
    $barGrad = New-Object System.Windows.Media.LinearGradientBrush
    $barGrad.StartPoint = [System.Windows.Point]::new(0, 0)
    $barGrad.EndPoint = [System.Windows.Point]::new(1, 0)
    $barGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#3da4ff"), 0)))
    $barGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#34d399"), 1)))
    $barFill.Background = $barGrad
    $barBg.Child = $barFill
    [void]$stack.Children.Add($barBg)

    # Percent text
    $pctTb = New-Object System.Windows.Controls.TextBlock
    $pctTb.Text = ""; $pctTb.FontSize = 11
    $pctTb.Foreground = $bc.ConvertFromString("#7a90a6")
    $pctTb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    [void]$stack.Children.Add($pctTb)

    [void]$grid.Children.Add($stack)
    $win.Content = $outer

    return @{
        Window  = $win
        Status  = $statusTb
        Bar     = $barFill
        Pct     = $pctTb
    }
}

function Update-Splash {
    param($Splash, [string]$Text, [int]$Percent)
    if ($null -eq $Splash -or $null -eq $Splash.Status) { return }
    $Splash.Status.Text = $Text
    $Splash.Bar.Width = [math]::Round(340 * ($Percent / 100))
    $Splash.Pct.Text = "$Percent%"
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [Action]{ }
    )
}

# ============================================================================
# ICON CACHE SETUP
# ============================================================================

$Script:IconCacheDir = "$env:TEMP\WingetterIcons"
if (!(Test-Path $Script:IconCacheDir)) { New-Item -ItemType Directory -Path $Script:IconCacheDir -Force | Out-Null }

function Get-AppIcon {
    param([string]$Url, [string]$AppName)
    
    $safeName = ($AppName -replace '[^\w]', '_') + ".png"
    $cachePath = Join-Path $Script:IconCacheDir $safeName
    
    # Return cached
    if (Test-Path $cachePath) {
        try {
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.UriSource = [Uri]::new($cachePath)
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.DecodePixelWidth = 20
            $bitmap.DecodePixelHeight = 20
            $bitmap.EndInit()
            if ($bitmap.PixelWidth -gt 0) { return $bitmap }
        } catch { }
    }
    
    # Download
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")
        $wc.DownloadFile($Url, $cachePath)
        $wc.Dispose()
        
        $fi = [System.IO.FileInfo]::new($cachePath)
        if ($fi.Length -gt 100) {
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.UriSource = [Uri]::new($cachePath)
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.DecodePixelWidth = 20
            $bitmap.DecodePixelHeight = 20
            $bitmap.EndInit()
            if ($bitmap.PixelWidth -gt 0) { return $bitmap }
        }
    } catch { }
    
    return $null
}

function New-LetterIcon {
    param([string]$Letter, [string]$ColorHex)
    
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    
    $bgBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($ColorHex)
    $dc.DrawRoundedRectangle($bgBrush, $null, [System.Windows.Rect]::new(0, 0, 20, 20), 4, 4)
    
    $ft = New-Object System.Windows.Media.FormattedText(
        $Letter.ToUpper(),
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Windows.FlowDirection]::LeftToRight,
        (New-Object System.Windows.Media.Typeface("Segoe UI")),
        11,
        [System.Windows.Media.Brushes]::White,
        1.0
    )
    
    $x = (20 - $ft.Width) / 2
    $y = (20 - $ft.Height) / 2
    $dc.DrawText($ft, (New-Object System.Windows.Point($x, $y)))
    $dc.Close()
    
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(20, 20, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    return $rtb
}

$Script:LetterColors = @("#e74c3c","#e67e22","#f1c40f","#2ecc71","#1abc9c","#3498db","#9b59b6","#e91e63","#00bcd4","#ff5722","#607d8b","#795548","#4caf50","#ff9800","#673ab7","#009688","#c0392b","#2980b9","#8e44ad","#27ae60","#d35400","#16a085","#2c3e50","#7f8c8d","#34495e","#1a237e")

function Get-LetterColor {
    param([string]$Name)
    $idx = 0
    foreach ($c in $Name.ToCharArray()) { $idx += [int]$c }
    return $Script:LetterColors[$idx % $Script:LetterColors.Count]
}

# ============================================================================
# THEME DEFINITIONS
# ============================================================================

$Script:Themes = @{
    Light = @{
        WindowBg = "#f3f6fb"; HeaderBg = "#0f2740"; HeaderText = "#ffffff"; HeaderSubText = "#d6e2ee"
        ToolbarBg = "#ffffff"; ToolbarBorder = "#dbe6f0"
        CategoryCardBg = "#ffffff"; CategoryCardBorder = "#d7e2ed"
        CategoryHeaderBg = "#f7fafe"; CategoryHeaderBorder = "#dbe6f0"
        CategoryTitle = "#0f5fb8"; CategoryAllText = "#5f7487"
        AppText = "#17293b"; AppSubtleText = "#6a7f91"; AppHoverBg = "#f2f7fc"; AppSelectedBg = "#e6f2ff"
        FooterBg = "#ffffff"; FooterBorder = "#dbe6f0"; FooterText = "#54697c"
        StatusPillBg = "#eef4fa"; StatusPillText = "#294053"; StatusPillBorder = "#d0dde8"
        AccentGreen = "#198754"; AccentGreenHover = "#157347"
        ProgressBg = "#e4ecf4"; ProgressText = "#1c3246"
        SecBtnBg = "#f6f9fc"; SecBtnBorder = "#d2dde8"; SecBtnText = "#22384d"
        CheckboxText = "#22384d"
        SearchBg = "#ffffff"; SearchBorder = "#c7d6e3"; SearchText = "#0f2438"; SearchPlaceholder = "#77899b"; SearchFocus = "#0f6fd6"
        CountBg = "#eef4fa"; CountText = "#1c3246"
        GroupBtnBg = "#eef4fa"; GroupBtnBorder = "#d2dde8"; GroupBtnText = "#22384d"
        ComboBg = "#ffffff"; ComboBorder = "#c7d6e3"; ComboPopupBg = "#ffffff"; ComboArrow = "#77899b"
        ComboItemHover = "#f2f7fc"; ComboItemText = "#17293b"; ComboDisabledText = "#9cb0c1"
        ScrollThumbBg = "#c2d3e2"; ScrollThumbHover = "#9eb8cc"
        DividerColor = "#dbe6f0"; CountBadgeBg = "#eef4fa"; CountBadgeText = "#60778b"
        ChkBorder = "#94abc0"; ChkBorderHover = "#0f6fd6"; ChkMark = "#0f6fd6"; ChkText = "#22384d"
        SearchIcon = "#8094a8"; VersionText = "#d6e2ee"
        SidebarBg = "#f8fbff"; SidebarText = "#304658"; SidebarHover = "#edf5fd"; SidebarActive = "#dbeeff"
        SidebarBorder = "#dbe6f0"; SidebarCountText = "#7a8ea0"; SidebarSubtitle = "#7a8ea0"
        LogBg = "#f8fbff"; LogBorder = "#dbe6f0"; LogSuccess = "#198754"; LogFail = "#dc3545"; LogSkip = "#b7791f"; LogText = "#1f3447"; LogEntryBg = "#ffffff"
        InstalledDot = "#1aa56b"; InstalledBadgeBg = "#e7f8ef"; InstalledBadgeText = "#167d53"
        UpdateBtnBg = "#dd8b21"; UpdateBtnHover = "#c77611"
        CollapseArrow = "#6e8296"
        EmptyStateBg = "#ffffff"; EmptyStateBorder = "#dbe6f0"; EmptyStateTitle = "#12263a"; EmptyStateText = "#60778b"
    }
    Dark = @{
        WindowBg = "#071018"; HeaderBg = "#08131f"; HeaderText = "#f8fafc"; HeaderSubText = "#8ca0b7"
        ToolbarBg = "#0b1725"; ToolbarBorder = "#1d2a3a"
        CategoryCardBg = "#0d1b2b"; CategoryCardBorder = "#1f3145"
        CategoryHeaderBg = "#0f2133"; CategoryHeaderBorder = "#21354a"
        CategoryTitle = "#8cd2ff"; CategoryAllText = "#8ca0b7"
        AppText = "#e5edf5"; AppSubtleText = "#95a7bb"; AppHoverBg = "#11263a"; AppSelectedBg = "#15334b"
        FooterBg = "#0b1725"; FooterBorder = "#1d2a3a"; FooterText = "#94a7bc"
        StatusPillBg = "#0d1f30"; StatusPillText = "#c4d2df"; StatusPillBorder = "#22405a"
        AccentGreen = "#1fb879"; AccentGreenHover = "#32c98a"
        ProgressBg = "#132132"; ProgressText = "#c8d8e8"
        SecBtnBg = "#102133"; SecBtnBorder = "#23374c"; SecBtnText = "#dbe7f1"
        CheckboxText = "#dbe7f1"
        SearchBg = "#08131f"; SearchBorder = "#24374a"; SearchText = "#eff6fb"; SearchPlaceholder = "#70859b"; SearchFocus = "#5ab0ff"
        CountBg = "#102133"; CountText = "#dce8f3"
        GroupBtnBg = "#102133"; GroupBtnBorder = "#23374c"; GroupBtnText = "#dbe7f1"
        ComboBg = "#08131f"; ComboBorder = "#24374a"; ComboPopupBg = "#0b1725"; ComboArrow = "#7a90a6"
        ComboItemHover = "#102133"; ComboItemText = "#dbe7f1"; ComboDisabledText = "#5f7489"
        ScrollThumbBg = "#27405a"; ScrollThumbHover = "#3b5d7f"
        DividerColor = "#223247"; CountBadgeBg = "#102133"; CountBadgeText = "#8ca0b7"
        ChkBorder = "#36506a"; ChkBorderHover = "#63b7ff"; ChkMark = "#63b7ff"; ChkText = "#dbe7f1"
        SearchIcon = "#7a90a6"; VersionText = "#7a90a6"
        SidebarBg = "#08131f"; SidebarText = "#acc0d4"; SidebarHover = "#0f2438"; SidebarActive = "#15314a"
        SidebarBorder = "#1d2a3a"; SidebarCountText = "#6e859a"; SidebarSubtitle = "#8196aa"
        LogBg = "#071019"; LogBorder = "#1d2a3a"; LogSuccess = "#2dd58f"; LogFail = "#ff6b6b"; LogSkip = "#ffbf69"; LogText = "#dbe7f2"; LogEntryBg = "#0d1825"
        InstalledDot = "#1fd389"; InstalledBadgeBg = "#103526"; InstalledBadgeText = "#78ddb1"
        UpdateBtnBg = "#d97706"; UpdateBtnHover = "#f59e0b"
        CollapseArrow = "#6f879e"
        EmptyStateBg = "#0b1724"; EmptyStateBorder = "#1f3145"; EmptyStateTitle = "#f0f6fb"; EmptyStateText = "#90a4b8"
    }
}

# ============================================================================
# MAIN GUI
# ============================================================================

function Show-WinGetInstallerGUI {
    # Shared mutable state - local hashtable captured by closures
    $ui = @{
        AllCheckboxes = @{}
        Cancelled     = $false
        IsDark        = $true
        HoverBg       = "#2a2a4a"
        SelectedBg    = "#1a3a5c"
        Themes        = $Script:Themes
        Categories    = [System.Collections.ArrayList]::new()
        IconQueue     = [System.Collections.ArrayList]::new()
        Elements      = @{
            CategoryCards   = [System.Collections.ArrayList]::new()
            CategoryHeaders = [System.Collections.ArrayList]::new()
            CategoryTitles  = [System.Collections.ArrayList]::new()
            CategoryAlls    = [System.Collections.ArrayList]::new()
            CountBadges     = [System.Collections.ArrayList]::new()
            CountTexts      = [System.Collections.ArrayList]::new()
            AppBorders      = [System.Collections.ArrayList]::new()
            AppLabels       = [System.Collections.ArrayList]::new()
            AppStatusBadges = [System.Collections.ArrayList]::new()
            AppStatusTexts  = [System.Collections.ArrayList]::new()
            SecButtons      = [System.Collections.ArrayList]::new()
            FooterChecks    = [System.Collections.ArrayList]::new()
            CollapseArrows  = [System.Collections.ArrayList]::new()
            InstalledDots   = [System.Collections.ArrayList]::new()
            SidebarButtons  = [System.Collections.ArrayList]::new()
            SidebarCounts   = [System.Collections.ArrayList]::new()
            SidebarRows     = [System.Collections.ArrayList]::new()
        }
    }

    $XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Wingetter v6.1.0 - Curated Windows App Installs and Updates"
        Height="920" Width="1450" MinHeight="720" MinWidth="1080"
        WindowStartupLocation="CenterScreen" Background="#071018"
        FontFamily="Segoe UI" SnapsToDevicePixels="True" UseLayoutRounding="True"
        TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
    <Window.Resources>
        <!-- Theme brush resources (updated dynamically by ApplyTheme) -->
        <SolidColorBrush x:Key="ComboBg" Color="#08131f"/>
        <SolidColorBrush x:Key="ComboBorder" Color="#24374a"/>
        <SolidColorBrush x:Key="ComboPopupBg" Color="#0b1725"/>
        <SolidColorBrush x:Key="ComboArrow" Color="#7a90a6"/>
        <SolidColorBrush x:Key="ComboItemHover" Color="#102133"/>
        <SolidColorBrush x:Key="ComboItemText" Color="#dbe7f1"/>
        <SolidColorBrush x:Key="ComboDisabledText" Color="#5f7489"/>
        <SolidColorBrush x:Key="ScrollThumbBg" Color="#27405a"/>
        <SolidColorBrush x:Key="ScrollThumbHover" Color="#3b5d7f"/>
        <SolidColorBrush x:Key="DividerBrush" Color="#223247"/>
        <SolidColorBrush x:Key="ChkBorder" Color="#36506a"/>
        <SolidColorBrush x:Key="ChkBorderHover" Color="#63b7ff"/>
        <SolidColorBrush x:Key="ChkMark" Color="#63b7ff"/>
        <SolidColorBrush x:Key="ChkText" Color="#dbe7f1"/>
        <!-- Toolbar / secondary button style -->
        <Style x:Key="ToolBtn" TargetType="Button">
            <Setter Property="Background" Value="#102133"/>
            <Setter Property="Foreground" Value="#dbe7f1"/>
            <Setter Property="BorderBrush" Value="#23374c"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,8"/>
            <Setter Property="MinHeight" Value="34"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid>
                            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <Border x:Name="hover" Background="White" Opacity="0" CornerRadius="10" IsHitTestVisible="False"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="hover" Property="Opacity" Value="0.06"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#63b7ff"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="hover" Property="Opacity" Value="0.12"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="bd" Property="BorderBrush" Value="#63b7ff"/>
                                <Setter TargetName="bd" Property="BorderThickness" Value="1.5"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="bd" Property="Opacity" Value="0.38"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- ComboBox ToggleButton template -->
        <ControlTemplate x:Key="ComboToggle" TargetType="ToggleButton">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition/>
                    <ColumnDefinition Width="26"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="bd" Grid.ColumnSpan="2" Background="{DynamicResource ComboBg}" BorderBrush="{DynamicResource ComboBorder}" BorderThickness="1" CornerRadius="10"/>
                <Border x:Name="hv" Grid.ColumnSpan="2" Background="White" Opacity="0" CornerRadius="10" IsHitTestVisible="False"/>
                <Path x:Name="arrow" Grid.Column="1" Fill="{DynamicResource ComboArrow}" HorizontalAlignment="Center" VerticalAlignment="Center" Data="M0,0 L4,4 L8,0 Z"/>
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="hv" Property="Opacity" Value="0.05"/>
                    <Setter TargetName="bd" Property="BorderBrush" Value="#63b7ff"/>
                </Trigger>
                <Trigger Property="IsKeyboardFocused" Value="True">
                    <Setter TargetName="bd" Property="BorderBrush" Value="#63b7ff"/>
                    <Setter TargetName="bd" Property="BorderThickness" Value="1.5"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>
        <!-- Full ComboBox ControlTemplate (dark mode safe - popup + togglebutton + items) -->
        <Style TargetType="ComboBox">
            <Setter Property="Foreground" Value="{DynamicResource ComboItemText}"/>
            <Setter Property="SnapsToDevicePixels" Value="True"/>
            <Setter Property="Height" Value="36"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleButton" Template="{StaticResource ComboToggle}" Focusable="False" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press"/>
                            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" Margin="12,5,28,5" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                                <Grid x:Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <Border Background="{DynamicResource ComboPopupBg}" BorderBrush="{DynamicResource ComboBorder}" BorderThickness="1" CornerRadius="10" Margin="0,4,0,0" Padding="4">
                                        <ScrollViewer SnapsToDevicePixels="True">
                                            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                                        </ScrollViewer>
                                    </Border>
                                </Grid>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- ComboBoxItem -->
        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="{DynamicResource ComboItemText}"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Bd" Background="Transparent" Padding="{TemplateBinding Padding}" CornerRadius="8">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ComboItemHover}"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="{DynamicResource ComboDisabledText}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- Vertical ScrollBar -->
        <Style x:Key="SlimThumb" TargetType="Thumb">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Thumb">
                        <Border x:Name="tb" Background="{DynamicResource ScrollThumbBg}" CornerRadius="6" Margin="2"/>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="tb" Property="Background" Value="{DynamicResource ScrollThumbHover}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="Transparent"/>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Vertical">
                    <Setter Property="Width" Value="12"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ScrollBar">
                                <Track x:Name="PART_Track" IsDirectionReversed="True">
                                    <Track.Thumb>
                                        <Thumb Style="{StaticResource SlimThumb}"/>
                                    </Track.Thumb>
                                </Track>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Height" Value="12"/>
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ScrollBar">
                                <Track x:Name="PART_Track" IsDirectionReversed="False">
                                    <Track.Thumb>
                                        <Thumb Style="{StaticResource SlimThumb}"/>
                                    </Track.Thumb>
                                </Track>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Trigger>
            </Style.Triggers>
        </Style>
        <!-- Rounded ProgressBar -->
        <Style TargetType="ProgressBar">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid>
                            <Border x:Name="PART_Track" Background="{TemplateBinding Background}" CornerRadius="999"/>
                            <Border x:Name="PART_Indicator" HorizontalAlignment="Left" CornerRadius="999">
                                <Border.Background>
                                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                        <GradientStop Color="#1fb879" Offset="0"/>
                                        <GradientStop Color="#34d399" Offset="1"/>
                                    </LinearGradientBrush>
                                </Border.Background>
                            </Border>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <!-- Dark CheckBox -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{DynamicResource ChkText}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Border x:Name="box" Width="18" Height="18" Background="Transparent" BorderBrush="{DynamicResource ChkBorder}" BorderThickness="1.5" CornerRadius="5" VerticalAlignment="Center">
                                <Path x:Name="mark" Data="M3,8 L7,12 L14,4" Stroke="{DynamicResource ChkMark}" StrokeThickness="1.8" StrokeStartLineCap="Round" StrokeEndLineCap="Round" Visibility="Collapsed"/>
                            </Border>
                            <ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="mark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="box" Property="BorderBrush" Value="{DynamicResource ChkBorderHover}"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="box" Property="BorderBrush" Value="{DynamicResource ChkBorderHover}"/>
                                <Setter TargetName="box" Property="BorderThickness" Value="2"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <!-- Top gradient accent bar -->
        <Border Grid.Row="0" Height="4">
            <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                    <GradientStop Color="#3da4ff" Offset="0"/>
                    <GradientStop Color="#7dd3fc" Offset="0.58"/>
                    <GradientStop Color="#22c55e" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
        </Border>
        <Border x:Name="HeaderBorder" Grid.Row="1" Background="#08131f" Padding="28,20,28,18">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock x:Name="HeaderTitle" Text="Wingetter" FontSize="30" FontWeight="Bold">
                            <TextBlock.Foreground>
                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                    <GradientStop Color="#8cd2ff" Offset="0"/>
                                    <GradientStop Color="#d3f1ff" Offset="1"/>
                                </LinearGradientBrush>
                            </TextBlock.Foreground>
                        </TextBlock>
                        <Border Margin="10,0,0,2" Padding="8,3" CornerRadius="999" Background="#102133" BorderBrush="#24374a" BorderThickness="1">
                            <TextBlock x:Name="HeaderVersion" Text="v6.1.0" FontSize="11" FontWeight="SemiBold" Foreground="#7a90a6"/>
                        </Border>
                    </StackPanel>
                    <TextBlock x:Name="HeaderSubtitle" Text="Curated winget installs, reusable package groups, and cleaner Windows setup flows." FontSize="13" Foreground="#8ca0b7" Margin="0,8,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Top">
                    <Border x:Name="CountPill" Background="#0d1f30" BorderBrush="#22405a" BorderThickness="1" CornerRadius="14" Padding="14,9" Margin="0,0,10,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock x:Name="CountLabel1" Text="Selected" Foreground="#c4d2df" FontSize="12" Margin="0,0,7,0"/>
                            <TextBlock x:Name="SelectedCount" Text="0" Foreground="#2bd28f" FontSize="14" FontWeight="Bold"/>
                        </StackPanel>
                    </Border>
                    <Border x:Name="StatusPill" Background="#0d1f30" BorderBrush="#22405a" BorderThickness="1" CornerRadius="14" Padding="14,9" Margin="0,0,10,0">
                        <StackPanel Orientation="Horizontal">
                            <Ellipse x:Name="WinGetDot" Width="10" Height="10" Fill="#ff9d2f" Margin="0,0,8,0" VerticalAlignment="Center"/>
                            <TextBlock x:Name="WinGetStatus" Text="Checking WinGet..." Foreground="#c4d2df" FontSize="12.5" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                    <Button x:Name="ModeBtn" Width="44" Height="44" Cursor="Hand" ToolTip="Switch between dark and light mode">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="modeBorder" Background="#102133" BorderBrush="#24374a" BorderThickness="1" CornerRadius="14">
                                    <TextBlock Text="◐" FontSize="17" Foreground="#dbe7f1" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="modeBorder" Property="BorderBrush" Value="#63b7ff"/>
                                    </Trigger>
                                    <Trigger Property="IsKeyboardFocused" Value="True">
                                        <Setter TargetName="modeBorder" Property="BorderBrush" Value="#63b7ff"/>
                                        <Setter TargetName="modeBorder" Property="BorderThickness" Value="1.5"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </StackPanel>
            </Grid>
        </Border>
        <Border x:Name="ToolbarBorder" Grid.Row="2" Background="#0b1725" BorderBrush="#1d2a3a" BorderThickness="0,0,0,1" Padding="28,16">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <Border x:Name="SearchBorder" Grid.Column="0" Background="#08131f" BorderBrush="#24374a" BorderThickness="1" CornerRadius="14" Padding="12,0" Margin="0,0,12,0" Width="380" Height="42">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="SearchIcon" Grid.Column="0" Text="⌕" FontSize="17" Foreground="#7a90a6" VerticalAlignment="Center" Margin="1,0,8,0" IsHitTestVisible="False"/>
                            <TextBlock x:Name="SearchPlaceholder" Grid.Column="1" Text="Search apps or Winget IDs" Foreground="#70859b" FontSize="13" VerticalAlignment="Center" IsHitTestVisible="False"/>
                            <TextBox x:Name="SearchBox" Grid.Column="1" Background="Transparent" BorderThickness="0" FontSize="13" VerticalAlignment="Center" Foreground="#eff6fb" Padding="0,8,0,8"/>
                            <Button x:Name="ClearSearchBtn" Grid.Column="2" Style="{StaticResource ToolBtn}" Content="Clear" Padding="10,5" Margin="8,0,0,0" FontSize="11" Cursor="Hand" Visibility="Collapsed"/>
                        </Grid>
                    </Border>
                    <Border x:Name="VisibleCountBorder" Grid.Column="1" Background="#102133" BorderBrush="#223247" BorderThickness="1" CornerRadius="12" Padding="12,9" VerticalAlignment="Center" Margin="0,0,12,0">
                        <TextBlock x:Name="VisibleCountText" Text="765 apps available" FontSize="12" FontWeight="SemiBold" Foreground="#dce8f3"/>
                    </Border>
                    <Border x:Name="ToolbarHintBorder" Grid.Column="3" Background="#102133" BorderBrush="#223247" BorderThickness="1" CornerRadius="12" Padding="12,9" VerticalAlignment="Center">
                        <TextBlock x:Name="ToolbarHintText" Text="Tip: Shift+Click selects a range." FontSize="11.5" Foreground="#94a7bc"/>
                    </Border>
                </Grid>
                <Grid Grid.Row="1" Margin="0,14,0,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Orientation="Horizontal">
                        <Button x:Name="SelectAllBtn" Style="{StaticResource ToolBtn}" Content="Select Visible" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                        <Button x:Name="DeselectAllBtn" Style="{StaticResource ToolBtn}" Content="Clear Visible" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2" Orientation="Horizontal">
                        <ComboBox x:Name="GroupCombo" Width="220" FontSize="11.5" Margin="0,0,8,0" VerticalAlignment="Center"/>
                        <Button x:Name="LoadGroupBtn" Style="{StaticResource ToolBtn}" Content="Apply Group" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                        <Button x:Name="SaveGroupBtn" Style="{StaticResource ToolBtn}" Content="Save Group" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                        <Button x:Name="DeleteGroupBtn" Style="{StaticResource ToolBtn}" Content="Delete" Margin="0,0,12,0" FontSize="11.5" Cursor="Hand" ToolTip="Delete the selected saved group"/>
                        <Border x:Name="Divider1" Background="{DynamicResource DividerBrush}" Width="1" Margin="0,2,12,2"/>
                        <Button x:Name="ExportBtn" Style="{StaticResource ToolBtn}" Content="Export Selection" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand" ToolTip="Export the current selection as JSON or a PowerShell install script"/>
                        <Button x:Name="ImportBtn" Style="{StaticResource ToolBtn}" Content="Import Group" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                        <Button x:Name="CopyCommandBtn" Style="{StaticResource ToolBtn}" Content="Copy Commands" FontSize="11.5" Cursor="Hand"/>
                        <Border x:Name="Divider2" Visibility="Collapsed" Width="0"/>
                    </StackPanel>
                </Grid>
            </Grid>
        </Border>
        <!-- Main content: Sidebar + Categories -->
        <Grid Grid.Row="3">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="215"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <!-- Category Sidebar -->
            <Border x:Name="SidebarBorder" Grid.Column="0" Background="#08131f" BorderBrush="#1d2a3a" BorderThickness="0,0,1,0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Border Grid.Row="0" Padding="16,14" BorderBrush="#1d2a3a" BorderThickness="0,0,0,1">
                        <StackPanel>
                            <TextBlock x:Name="SidebarTitle" Text="Browse categories" FontSize="12.5" FontWeight="SemiBold" Foreground="#8cd2ff"/>
                            <TextBlock x:Name="SidebarSubtitle" Text="Jump into the software collection." FontSize="11.5" Foreground="#8196aa" Margin="0,4,0,0"/>
                        </StackPanel>
                    </Border>
                    <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,8,0,8">
                        <StackPanel x:Name="SidebarPanel" Margin="0,4,0,4"/>
                    </ScrollViewer>
                </Grid>
            </Border>
            <!-- App Cards Area -->
            <Grid Grid.Column="1">
                <ScrollViewer x:Name="MainScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="18,16,18,22">
                    <WrapPanel x:Name="CategoriesPanel" Orientation="Horizontal"/>
                </ScrollViewer>
                <Border x:Name="EmptyStateBorder" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Center" MaxWidth="430" Padding="28,26" CornerRadius="20" Background="#0b1724" BorderBrush="#1f3145" BorderThickness="1">
                    <StackPanel>
                        <TextBlock x:Name="EmptyStateEyebrow" Text="Nothing to show" FontSize="11.5" FontWeight="SemiBold" Foreground="#8cd2ff" HorizontalAlignment="Center"/>
                        <TextBlock x:Name="EmptyStateTitle" Text="No apps match your current filters." FontSize="20" FontWeight="Bold" Foreground="#f0f6fb" Margin="0,10,0,0" TextAlignment="Center" TextWrapping="Wrap"/>
                        <TextBlock x:Name="EmptyStateBody" Text="Try another search, clear the filter, or switch back from update mode to browse the full catalog." FontSize="12.5" Foreground="#90a4b8" Margin="0,10,0,0" TextAlignment="Center" TextWrapping="Wrap"/>
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,18,0,0">
                            <Button x:Name="EmptyStateClearBtn" Style="{StaticResource ToolBtn}" Content="Clear Search" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand"/>
                            <Button x:Name="EmptyStateResetModeBtn" Style="{StaticResource ToolBtn}" Content="Back to Browse" FontSize="11.5" Cursor="Hand" Visibility="Collapsed"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
            </Grid>
        </Grid>
        <!-- Package Detail Panel -->
        <Border x:Name="PackageDetailsBorder" Grid.Row="4" Background="#071019" BorderBrush="#1d2a3a" BorderThickness="0,1,0,0" Visibility="Collapsed" MaxHeight="240" Padding="20,14">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="PackageDetailsTitle" Text="Package details" FontSize="13" FontWeight="SemiBold" Foreground="#8cd2ff"/>
                        <TextBlock x:Name="PackageDetailsSubtitle" Text="Click a package to inspect source and installer metadata." FontSize="11.5" Foreground="#94a7bc" Margin="0,3,0,0"/>
                    </StackPanel>
                    <Button x:Name="PackageDetailsCloseBtn" Grid.Column="1" Style="{StaticResource ToolBtn}" Content="Close" Padding="10,5" FontSize="10.5" Cursor="Hand"/>
                </Grid>
                <Grid Grid.Row="1">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="120"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="120"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock x:Name="DetailSourceLabel" Grid.Row="0" Grid.Column="0" Text="Source" FontSize="11" Foreground="#94a7bc" Margin="0,0,8,6"/>
                    <TextBlock x:Name="DetailSource" Grid.Row="0" Grid.Column="1" Text="-" FontSize="11.5" Foreground="#dbe7f2" Margin="0,0,20,6" TextTrimming="CharacterEllipsis"/>
                    <TextBlock x:Name="DetailPublisherLabel" Grid.Row="0" Grid.Column="2" Text="Publisher" FontSize="11" Foreground="#94a7bc" Margin="0,0,8,6"/>
                    <TextBlock x:Name="DetailPublisher" Grid.Row="0" Grid.Column="3" Text="-" FontSize="11.5" Foreground="#dbe7f2" Margin="0,0,0,6" TextTrimming="CharacterEllipsis"/>
                    <TextBlock x:Name="DetailInstalledLabel" Grid.Row="1" Grid.Column="0" Text="Installed" FontSize="11" Foreground="#94a7bc" Margin="0,0,8,6"/>
                    <TextBlock x:Name="DetailInstalledVersion" Grid.Row="1" Grid.Column="1" Text="-" FontSize="11.5" Foreground="#dbe7f2" Margin="0,0,20,6" TextTrimming="CharacterEllipsis"/>
                    <TextBlock x:Name="DetailInstallerLabel" Grid.Row="1" Grid.Column="2" Text="Installer" FontSize="11" Foreground="#94a7bc" Margin="0,0,8,6"/>
                    <TextBlock x:Name="DetailInstallerType" Grid.Row="1" Grid.Column="3" Text="-" FontSize="11.5" Foreground="#dbe7f2" Margin="0,0,0,6" TextTrimming="CharacterEllipsis"/>
                    <TextBlock x:Name="DetailShaLabel" Grid.Row="2" Grid.Column="0" Text="SHA256" FontSize="11" Foreground="#94a7bc" Margin="0,0,8,0"/>
                    <TextBlock x:Name="DetailSha256" Grid.Row="2" Grid.Column="1" Grid.ColumnSpan="3" Text="-" FontSize="11.5" Foreground="#dbe7f2" TextTrimming="CharacterEllipsis"/>
                </Grid>
                <StackPanel Grid.Row="2" Margin="0,10,0,0">
                    <TextBlock x:Name="DetailInstallerUrl" Text="-" FontSize="11.5" Foreground="#94a7bc" TextWrapping="Wrap" TextTrimming="CharacterEllipsis"/>
                    <TextBlock x:Name="DetailWarnings" Text="" FontSize="11" Foreground="#ffbf69" TextWrapping="Wrap" Margin="0,5,0,0"/>
                </StackPanel>
            </Grid>
        </Border>
        <!-- Log Panel (shown during install) -->
        <Border x:Name="LogPanelBorder" Grid.Row="5" Background="#071019" BorderBrush="#1d2a3a" BorderThickness="0,1,0,0" Visibility="Collapsed" MaxHeight="210">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="16,10,16,8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="LogTitle" Text="Activity" FontSize="12" FontWeight="SemiBold" Foreground="#8cd2ff"/>
                        <TextBlock x:Name="LogSubtitle" Text="Install and update results appear here in real time." FontSize="11" Foreground="#94a7bc" Margin="0,3,0,0"/>
                    </StackPanel>
                    <Button x:Name="LogToggleBtn" Grid.Column="1" Style="{StaticResource ToolBtn}" Content="Hide" Padding="10,5" FontSize="10.5" Cursor="Hand"/>
                </Grid>
                <ScrollViewer x:Name="LogScrollViewer" Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="16,0,16,12">
                    <StackPanel x:Name="LogEntriesPanel"/>
                </ScrollViewer>
            </Grid>
        </Border>
        <Border x:Name="FooterBorder" Grid.Row="6" Background="#0b1725" BorderBrush="#1d2a3a" BorderThickness="0,1,0,0" Padding="28,16">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,12">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0">
                        <TextBlock x:Name="ProgressText" Text="Choose apps to install or load a saved group to get started." Foreground="#94a7bc" FontSize="12.5"/>
                        <ProgressBar x:Name="ProgressBar" Height="8" Value="0" Maximum="100" Background="#132132" Foreground="#1fb879" BorderThickness="0" Margin="0,8,0,0"/>
                    </StackPanel>
                    <TextBlock x:Name="ProgressPercent" Grid.Column="1" Text="" Foreground="#c8d8e8" FontSize="14" FontWeight="Bold" VerticalAlignment="Center" Margin="20,0,0,0"/>
                </Grid>
                <Grid Grid.Row="1">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                        <CheckBox x:Name="SilentCheck" Content="Use silent install where available" IsChecked="True" FontSize="12.5" Margin="0,0,20,0" VerticalAlignment="Center"/>
                        <CheckBox x:Name="AcceptCheck" Content="Accept package and source agreements" IsChecked="True" FontSize="12.5" VerticalAlignment="Center"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="InstallWinGetBtn" Style="{StaticResource ToolBtn}" Content="Install WinGet" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand" Visibility="Collapsed"/>
                        <Button x:Name="UpdateAllBtn" Content="Review Updates" FontSize="11.5" FontWeight="SemiBold" Padding="14,8" Margin="0,0,8,0" Cursor="Hand" Foreground="White" ToolTip="Show installed apps from this catalog so you can choose what to update.">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Border x:Name="updateAllBorder" CornerRadius="10" Padding="{TemplateBinding Padding}" Background="#d97706">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="updateAllBorder" Property="Background" Value="#f59e0b"/>
                                        </Trigger>
                                        <Trigger Property="IsKeyboardFocused" Value="True">
                                            <Setter TargetName="updateAllBorder" Property="Background" Value="#f59e0b"/>
                                        </Trigger>
                                        <Trigger Property="IsEnabled" Value="False">
                                            <Setter TargetName="updateAllBorder" Property="Background" Value="#445265"/>
                                            <Setter TargetName="updateAllBorder" Property="Opacity" Value="0.7"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Button.Template>
                        </Button>
                        <Button x:Name="CancelBtn" Style="{StaticResource ToolBtn}" Content="Stop" Margin="0,0,8,0" FontSize="11.5" Cursor="Hand" IsEnabled="False"/>
                        <Button x:Name="InstallBtn" Content="Install Selected" FontSize="14" FontWeight="SemiBold" Padding="24,11" Cursor="Hand" Foreground="White" IsEnabled="False">
                            <Button.Template>
                                <ControlTemplate TargetType="Button">
                                    <Grid>
                                        <Border x:Name="installBorder" CornerRadius="12" Padding="{TemplateBinding Padding}">
                                            <Border.Background>
                                                <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                                    <GradientStop Color="#1fb879" Offset="0"/>
                                                    <GradientStop Color="#34d399" Offset="1"/>
                                                </LinearGradientBrush>
                                            </Border.Background>
                                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                        </Border>
                                        <Border x:Name="installGlow" CornerRadius="12" Background="White" Opacity="0" IsHitTestVisible="False"/>
                                    </Grid>
                                    <ControlTemplate.Triggers>
                                        <Trigger Property="IsMouseOver" Value="True">
                                            <Setter TargetName="installGlow" Property="Opacity" Value="0.08"/>
                                        </Trigger>
                                        <Trigger Property="IsPressed" Value="True">
                                            <Setter TargetName="installGlow" Property="Opacity" Value="0.16"/>
                                        </Trigger>
                                        <Trigger Property="IsKeyboardFocused" Value="True">
                                            <Setter TargetName="installGlow" Property="Opacity" Value="0.12"/>
                                        </Trigger>
                                        <Trigger Property="IsEnabled" Value="False">
                                            <Setter TargetName="installBorder" Property="Background" Value="#445265"/>
                                            <Setter TargetName="installBorder" Property="Opacity" Value="0.72"/>
                                        </Trigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Button.Template>
                        </Button>
                    </StackPanel>
                </Grid>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($XAML))
    $Window = [Windows.Markup.XamlReader]::Load($reader)

# codex-branding:start
                try {
                    $brandingIconPath = Join-Path (Get-WingetterRootPath) 'icon.ico'
                    if (Test-Path $brandingIconPath) {
                        $Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object System.Uri($brandingIconPath)))
                    }
                } catch {
                }
                # codex-branding:end
    # Named controls
    $CategoriesPanel  = $Window.FindName("CategoriesPanel")
    $SelectedCount    = $Window.FindName("SelectedCount")
    $WinGetStatus     = $Window.FindName("WinGetStatus")
    $WinGetDot        = $Window.FindName("WinGetDot")
    $ProgressBar      = $Window.FindName("ProgressBar")
    $ProgressText     = $Window.FindName("ProgressText")
    $ProgressPercent  = $Window.FindName("ProgressPercent")
    $InstallBtn       = $Window.FindName("InstallBtn")
    $CancelBtn        = $Window.FindName("CancelBtn")
    $UpdateAllBtn     = $Window.FindName("UpdateAllBtn")
    $SelectAllBtn     = $Window.FindName("SelectAllBtn")
    $DeselectAllBtn   = $Window.FindName("DeselectAllBtn")
    $ExportBtn        = $Window.FindName("ExportBtn")
    $ImportBtn        = $Window.FindName("ImportBtn")
    $CopyCommandBtn   = $Window.FindName("CopyCommandBtn")
    $InstallWinGetBtn = $Window.FindName("InstallWinGetBtn")
    $GroupCombo       = $Window.FindName("GroupCombo")
    $LoadGroupBtn     = $Window.FindName("LoadGroupBtn")
    $SaveGroupBtn     = $Window.FindName("SaveGroupBtn")
    $DeleteGroupBtn   = $Window.FindName("DeleteGroupBtn")
    $SilentCheck      = $Window.FindName("SilentCheck")
    $AcceptCheck      = $Window.FindName("AcceptCheck")
    $ModeBtn          = $Window.FindName("ModeBtn")

    $MainScroll       = $Window.FindName("MainScroll")
    $SearchBox        = $Window.FindName("SearchBox")
    $ClearSearchBtn   = $Window.FindName("ClearSearchBtn")
    $SearchPlaceholder= $Window.FindName("SearchPlaceholder")
    $VisibleCountText = $Window.FindName("VisibleCountText")
    $SidebarPanel     = $Window.FindName("SidebarPanel")
    $Divider1         = $Window.FindName("Divider1")
    $Divider2         = $Window.FindName("Divider2")
    $LogPanelBorder   = $Window.FindName("LogPanelBorder")
    $LogEntriesPanel  = $Window.FindName("LogEntriesPanel")
    $LogScrollViewer  = $Window.FindName("LogScrollViewer")
    $LogToggleBtn     = $Window.FindName("LogToggleBtn")
    $LogTitle         = $Window.FindName("LogTitle")
    $PackageDetailsBorder = $Window.FindName("PackageDetailsBorder")
    $PackageDetailsCloseBtn = $Window.FindName("PackageDetailsCloseBtn")
    $EmptyStateBorder = $Window.FindName("EmptyStateBorder")
    $EmptyStateTitle  = $Window.FindName("EmptyStateTitle")
    $EmptyStateBody   = $Window.FindName("EmptyStateBody")
    $EmptyStateClearBtn = $Window.FindName("EmptyStateClearBtn")
    $EmptyStateResetModeBtn = $Window.FindName("EmptyStateResetModeBtn")

    # Store in $ui for closure access
    $ui["Window"]          = $Window
    $ui["HeaderBorder"]    = $Window.FindName("HeaderBorder")
    $ui["HeaderTitle"]     = $Window.FindName("HeaderTitle")
    $ui["HeaderSubtitle"]  = $Window.FindName("HeaderSubtitle")
    $ui["HeaderVersion"]   = $Window.FindName("HeaderVersion")
    $ui["SearchIcon"]      = $Window.FindName("SearchIcon")
    $ui["ToolbarBorder"]   = $Window.FindName("ToolbarBorder")
    $ui["StatusPill"]      = $Window.FindName("StatusPill")
    $ui["CountPill"]       = $Window.FindName("CountPill")
    $ui["CountLabel1"]     = $Window.FindName("CountLabel1")
    $ui["FooterBorder"]    = $Window.FindName("FooterBorder")
    $ui["ProgressTextCtl"] = $ProgressText
    $ui["ProgressBarCtl"]  = $ProgressBar
    $ui["ProgressPctCtl"]  = $ProgressPercent
    $ui["WinGetStatusCtl"] = $WinGetStatus
    $ui["ModeBtn"]         = $ModeBtn
    $ui["SearchBorder"]    = $Window.FindName("SearchBorder")
    $ui["SearchBox"]       = $SearchBox
    $ui["SearchPlaceholder"] = $SearchPlaceholder
    $ui["VisibleCountBorder"] = $Window.FindName("VisibleCountBorder")
    $ui["VisibleCountText"]   = $VisibleCountText
    $ui["GroupCombo"]          = $GroupCombo
    $ui["SidebarPanel"]        = $SidebarPanel
    $ui["SidebarBorder"]       = $Window.FindName("SidebarBorder")
    $ui["SidebarTitle"]        = $Window.FindName("SidebarTitle")
    $ui["SidebarSubtitle"]     = $Window.FindName("SidebarSubtitle")
    $ui["LogPanelBorder"]      = $LogPanelBorder
    $ui["LogEntriesPanel"]     = $LogEntriesPanel
    $ui["LogScrollViewer"]     = $LogScrollViewer
    $ui["LogToggleBtn"]        = $LogToggleBtn
    $ui["LogTitle"]            = $LogTitle
    $ui["LogSubtitle"]         = $Window.FindName("LogSubtitle")
    $ui["PackageDetailsBorder"] = $PackageDetailsBorder
    $ui["PackageDetailsTitle"] = $Window.FindName("PackageDetailsTitle")
    $ui["PackageDetailsSubtitle"] = $Window.FindName("PackageDetailsSubtitle")
    $ui["PackageDetailsCloseBtn"] = $PackageDetailsCloseBtn
    $ui["DetailSource"] = $Window.FindName("DetailSource")
    $ui["DetailPublisher"] = $Window.FindName("DetailPublisher")
    $ui["DetailInstalledVersion"] = $Window.FindName("DetailInstalledVersion")
    $ui["DetailInstallerType"] = $Window.FindName("DetailInstallerType")
    $ui["DetailInstallerUrl"] = $Window.FindName("DetailInstallerUrl")
    $ui["DetailSha256"] = $Window.FindName("DetailSha256")
    $ui["DetailWarnings"] = $Window.FindName("DetailWarnings")
    $ui["DetailLabels"] = @(
        $Window.FindName("DetailSourceLabel"),
        $Window.FindName("DetailPublisherLabel"),
        $Window.FindName("DetailInstalledLabel"),
        $Window.FindName("DetailInstallerLabel"),
        $Window.FindName("DetailShaLabel")
    )
    $ui["DetailValues"] = @(
        $ui["DetailSource"],
        $ui["DetailPublisher"],
        $ui["DetailInstalledVersion"],
        $ui["DetailInstallerType"],
        $ui["DetailInstallerUrl"],
        $ui["DetailSha256"]
    )
    $ui["MainScroll"]          = $MainScroll
    $ui["ToolbarHintBorder"]   = $Window.FindName("ToolbarHintBorder")
    $ui["ToolbarHintText"]     = $Window.FindName("ToolbarHintText")
    $ui["ClearSearchBtn"]      = $ClearSearchBtn
    $ui["EmptyStateBorder"]    = $EmptyStateBorder
    $ui["EmptyStateTitle"]     = $EmptyStateTitle
    $ui["EmptyStateBody"]      = $EmptyStateBody
    $ui["EmptyStateClearBtn"]  = $EmptyStateClearBtn
    $ui["EmptyStateResetModeBtn"] = $EmptyStateResetModeBtn

    $ui["IsUpdateMode"]        = $false
    $ui["LastClickedIndex"]    = -1
    $ui["InstalledIds"]        = @{}
    $ui["SidebarButtons"]      = [System.Collections.ArrayList]::new()
    $ui["CategoryAppsStacks"]  = [System.Collections.ArrayList]::new()
    $ui["BuiltInGroups"]       = $Script:BuiltInGroups

    foreach ($btn in @($SelectAllBtn, $DeselectAllBtn, $CopyCommandBtn, $ExportBtn, $ImportBtn, $InstallWinGetBtn, $CancelBtn, $LoadGroupBtn, $SaveGroupBtn, $DeleteGroupBtn, $PackageDetailsCloseBtn)) {
        [void]$ui["Elements"]["SecButtons"].Add($btn)
    }
    foreach ($chk in @($SilentCheck, $AcceptCheck)) {
        [void]$ui["Elements"]["FooterChecks"].Add($chk)
    }

    # Total app count for display
    $totalApps = 0
    foreach ($cat in $Script:SoftwareDatabase.Keys) { $totalApps += $Script:SoftwareDatabase[$cat].Count }
    $ui["TotalApps"] = $totalApps
    $ui["SidebarSubtitle"].Text = "$($Script:SoftwareDatabase.Keys.Count) categories ready to browse."

    $CountPill = $Window.FindName("CountPill")
    $UpdateGroupActionState = {
        $selected = $GroupCombo.SelectedItem
        $hasGroup = ($null -ne $selected) -and ($null -ne $selected.Tag)
        $isUserGroup = $hasGroup -and ($selected.Tag["Type"] -eq "user")
        $LoadGroupBtn.IsEnabled = $hasGroup
        $DeleteGroupBtn.IsEnabled = $isUserGroup
    }
    $UpdateCardLayout = {
        if ($ui["IsUpdateMode"]) { return }
        $available = $ui["MainScroll"].ViewportWidth
        if ($available -le 0) { $available = $ui["MainScroll"].ActualWidth }
        if ($available -le 0) { return }

        $gap = 16
        $minWidth = 252
        $maxWidth = 340
        $columns = [math]::Max(1, [math]::Min(4, [math]::Floor(($available + $gap) / ($minWidth + $gap))))
        $targetWidth = [math]::Floor(($available - (($columns + 1) * 8)) / $columns)
        $targetWidth = [math]::Max($minWidth, [math]::Min($maxWidth, $targetWidth))

        foreach ($card in $ui["Elements"]["CategoryCards"]) {
            $card.Width = $targetWidth
        }
    }
    $UpdateEmptyState = {
        $hasVisibleContent = $false
        foreach ($cat in $ui["Categories"]) {
            if ($cat["Card"].Visibility -eq [System.Windows.Visibility]::Visible) {
                $hasVisibleContent = $true
                break
            }
        }

        if ($hasVisibleContent) {
            $ui["EmptyStateBorder"].Visibility = [System.Windows.Visibility]::Collapsed
        } else {
            $ui["EmptyStateBorder"].Visibility = [System.Windows.Visibility]::Visible
            if ($ui["IsUpdateMode"]) {
                $ui["EmptyStateTitle"].Text = "No installed apps match the current view."
                $ui["EmptyStateBody"].Text = "Try a different search, or switch back to the full catalog to browse everything Wingetter can install."
                $ui["EmptyStateResetModeBtn"].Visibility = [System.Windows.Visibility]::Visible
            } else {
                $ui["EmptyStateTitle"].Text = "No apps match your current filters."
                $ui["EmptyStateBody"].Text = "Try another search term, or clear the filter to browse the full catalog."
                $ui["EmptyStateResetModeBtn"].Visibility = [System.Windows.Visibility]::Collapsed
            }
        }
    }
    $UpdateSelectedCount = {
        $count = 0
        foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked -eq $true) { $count++ } }
        $SelectedCount.Text = $count.ToString()
        $theme = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        $accentBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($theme["AccentGreen"])
        if ($count -gt 0) {
            $CountPill.BorderBrush = $accentBrush
            $CountPill.BorderThickness = [System.Windows.Thickness]::new(1)
            $SelectedCount.Foreground = $accentBrush
        } else {
            $CountPill.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($theme["StatusPillBorder"])
            $CountPill.BorderThickness = [System.Windows.Thickness]::new(1)
            $SelectedCount.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($theme["StatusPillText"])
        }

        $InstallBtn.IsEnabled = ($count -gt 0)
        $SaveGroupBtn.IsEnabled = ($count -gt 0)
        $ExportBtn.IsEnabled = ($count -gt 0)
        $CopyCommandBtn.IsEnabled = ($count -gt 0)
        $InstallBtn.Content = if ($count -gt 0) {
            if ($ui["IsUpdateMode"]) { "Update Selected ($count)" } else { "Install Selected ($count)" }
        } else {
            if ($ui["IsUpdateMode"]) { "Update Selected" } else { "Install Selected" }
        }
    }

    # ========================================================
    # FILTER LOGIC - search
    # ========================================================
    $ApplyFilter = {
        $searchText = $SearchBox.Text.Trim().ToLower()
        $visCount = 0
        $inUpdateMode = $ui["IsUpdateMode"]

        foreach ($cat in $ui["Categories"]) {
            $catVisible = 0
            foreach ($appEntry in $cat["Apps"]) {
                $nameMatch = ($searchText -eq "") -or ($appEntry["Name"].ToLower().Contains($searchText)) -or ($appEntry["WingetId"].ToLower().Contains($searchText))
                # In update mode, also require the app to be installed
                if ($inUpdateMode -and -not $ui["InstalledIds"].ContainsKey($appEntry["WingetId"])) { $nameMatch = $false }
                if ($nameMatch) {
                    $appEntry["Border"].Visibility = [System.Windows.Visibility]::Visible
                    $catVisible++
                    $visCount++
                } else {
                    $appEntry["Border"].Visibility = [System.Windows.Visibility]::Collapsed
                }
            }
            if ($inUpdateMode) {
                # In update mode, cards are always visible (flat layout), visibility driven by apps
                $cat["Card"].Visibility = if ($catVisible -gt 0) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            } else {
                $cat["Card"].Visibility = if ($catVisible -gt 0) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
        }

        $total = if ($inUpdateMode) { $ui["InstalledIds"].Count } else { $ui["TotalApps"] }
        $VisibleCountText.Text = if ($searchText -ne "") {
            if ($visCount -eq 1) { "1 match" } else { "$visCount matches" }
        } elseif ($inUpdateMode) {
            if ($total -eq 1) { "1 installed app ready" } else { "$total installed apps ready" }
        } else {
            "$total apps available"
        }
        $ClearSearchBtn.Visibility = if ($searchText -ne "") { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        & $UpdateEmptyState
        & $UpdateCardLayout
    }

    # ========================================================
    # APPLY THEME
    # ========================================================
    $ApplyTheme = {
        $themeName = if ($ui["IsDark"]) { "Dark" } else { "Light" }
        $t = $ui["Themes"][$themeName]
        $bc = [System.Windows.Media.BrushConverter]::new()

        $ui["HoverBg"]    = $t["AppHoverBg"]
        $ui["SelectedBg"] = $t["AppSelectedBg"]

        $ui["Window"].Background              = $bc.ConvertFromString($t["WindowBg"])
        $ui["HeaderBorder"].Background        = $bc.ConvertFromString($t["HeaderBg"])
        # Header title gradient (matches splash screen)
        $titleGrad = New-Object System.Windows.Media.LinearGradientBrush
        $titleGrad.StartPoint = [System.Windows.Point]::new(0, 0)
        $titleGrad.EndPoint = [System.Windows.Point]::new(1, 0)
        if ($ui["IsDark"]) {
            $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#8cd2ff"), 0)))
            $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#d3f1ff"), 1)))
        } else {
            $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#ffffff"), 0)))
            $titleGrad.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.ColorConverter]::ConvertFromString("#d6e2ee"), 1)))
        }
        $ui["HeaderTitle"].Foreground         = $titleGrad
        $ui["HeaderSubtitle"].Foreground      = $bc.ConvertFromString($t["HeaderSubText"])
        $ui["ToolbarBorder"].Background       = $bc.ConvertFromString($t["ToolbarBg"])
        $ui["ToolbarBorder"].BorderBrush      = $bc.ConvertFromString($t["ToolbarBorder"])
        $ui["StatusPill"].Background          = $bc.ConvertFromString($t["StatusPillBg"])
        $ui["StatusPill"].BorderBrush         = $bc.ConvertFromString($t["StatusPillBorder"])
        $ui["WinGetStatusCtl"].Foreground     = $bc.ConvertFromString($t["StatusPillText"])
        $ui["CountPill"].Background           = $bc.ConvertFromString($t["StatusPillBg"])
        $ui["CountPill"].BorderBrush          = $bc.ConvertFromString($t["StatusPillBorder"])
        $ui["CountLabel1"].Foreground         = $bc.ConvertFromString($t["StatusPillText"])
        $ui["FooterBorder"].Background        = $bc.ConvertFromString($t["FooterBg"])
        $ui["FooterBorder"].BorderBrush       = $bc.ConvertFromString($t["FooterBorder"])
        $ui["ProgressTextCtl"].Foreground     = $bc.ConvertFromString($t["FooterText"])
        $ui["ProgressBarCtl"].Background      = $bc.ConvertFromString($t["ProgressBg"])
        $ui["ProgressPctCtl"].Foreground      = $bc.ConvertFromString($t["ProgressText"])

        # Search bar
        $ui["SearchBorder"].Background  = $bc.ConvertFromString($t["SearchBg"])
        $ui["SearchBorder"].BorderBrush = $bc.ConvertFromString($t["SearchBorder"])
        $ui["SearchBox"].Foreground     = $bc.ConvertFromString($t["SearchText"])
        $ui["SearchPlaceholder"].Foreground = $bc.ConvertFromString($t["SearchPlaceholder"])

        # Visible count
        $ui["VisibleCountBorder"].Background = $bc.ConvertFromString($t["CountBg"])
        $ui["VisibleCountBorder"].BorderBrush = $bc.ConvertFromString($t["SecBtnBorder"])
        $ui["VisibleCountText"].Foreground   = $bc.ConvertFromString($t["CountText"])
        $ui["ToolbarHintBorder"].Background  = $bc.ConvertFromString($t["CountBg"])
        $ui["ToolbarHintBorder"].BorderBrush = $bc.ConvertFromString($t["SecBtnBorder"])
        $ui["ToolbarHintText"].Foreground    = $bc.ConvertFromString($t["FooterText"])

        # DynamicResource brush updates (ComboBox, ScrollBar, Dividers, CheckBox)
        $res = $ui["Window"].Resources
        $toColor = { param([string]$hex) [System.Windows.Media.ColorConverter]::ConvertFromString($hex) }
        $res["ComboBg"]          = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboBg"]))
        $res["ComboBorder"]      = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboBorder"]))
        $res["ComboPopupBg"]     = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboPopupBg"]))
        $res["ComboArrow"]       = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboArrow"]))
        $res["ComboItemHover"]   = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboItemHover"]))
        $res["ComboItemText"]    = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboItemText"]))
        $res["ComboDisabledText"]= [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ComboDisabledText"]))
        $res["ScrollThumbBg"]    = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ScrollThumbBg"]))
        $res["ScrollThumbHover"] = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ScrollThumbHover"]))
        $res["DividerBrush"]     = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["DividerColor"]))
        $res["ChkBorder"]        = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ChkBorder"]))
        $res["ChkBorderHover"]   = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ChkBorderHover"]))
        $res["ChkMark"]          = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ChkMark"]))
        $res["ChkText"]          = [System.Windows.Media.SolidColorBrush]::new((& $toColor $t["ChkText"]))

        # Search icon
        $ui["SearchIcon"].Foreground = $bc.ConvertFromString($t["SearchIcon"])

        # Version text
        $ui["HeaderVersion"].Foreground = $bc.ConvertFromString($t["VersionText"])

        $el = $ui["Elements"]
        for ($i = 0; $i -lt $el["CategoryCards"].Count; $i++) {
            $el["CategoryCards"][$i].Background  = $bc.ConvertFromString($t["CategoryCardBg"])
            $el["CategoryCards"][$i].BorderBrush = $bc.ConvertFromString($t["CategoryCardBorder"])
        }
        for ($i = 0; $i -lt $el["CategoryHeaders"].Count; $i++) {
            $el["CategoryHeaders"][$i].Background  = $bc.ConvertFromString($t["CategoryHeaderBg"])
            $el["CategoryHeaders"][$i].BorderBrush = $bc.ConvertFromString($t["CategoryHeaderBorder"])
        }
        for ($i = 0; $i -lt $el["CategoryTitles"].Count; $i++) {
            $el["CategoryTitles"][$i].Foreground = $bc.ConvertFromString($t["CategoryTitle"])
        }
        for ($i = 0; $i -lt $el["CategoryAlls"].Count; $i++) {
            $el["CategoryAlls"][$i].Foreground = $bc.ConvertFromString($t["CategoryAllText"])
        }
        for ($i = 0; $i -lt $el["CountBadges"].Count; $i++) {
            $el["CountBadges"][$i].Background = $bc.ConvertFromString($t["CountBadgeBg"])
        }
        for ($i = 0; $i -lt $el["CountTexts"].Count; $i++) {
            $el["CountTexts"][$i].Foreground = $bc.ConvertFromString($t["CountBadgeText"])
        }
        for ($i = 0; $i -lt $el["AppLabels"].Count; $i++) {
            $labelColor = if (($i -lt $el["InstalledDots"].Count) -and ($el["InstalledDots"][$i].Visibility -eq [System.Windows.Visibility]::Visible) -and (-not $ui["IsUpdateMode"])) {
                $t["AppSubtleText"]
            } else {
                $t["AppText"]
            }
            $el["AppLabels"][$i].Foreground = $bc.ConvertFromString($labelColor)
        }
        for ($i = 0; $i -lt $el["AppStatusBadges"].Count; $i++) {
            $el["AppStatusBadges"][$i].Background = $bc.ConvertFromString($t["InstalledBadgeBg"])
            $el["AppStatusBadges"][$i].BorderBrush = $bc.ConvertFromString($t["InstalledBadgeBg"])
        }
        for ($i = 0; $i -lt $el["AppStatusTexts"].Count; $i++) {
            $el["AppStatusTexts"][$i].Foreground = $bc.ConvertFromString($t["InstalledBadgeText"])
        }
        for ($i = 0; $i -lt $el["AppBorders"].Count; $i++) {
            $ab = $el["AppBorders"][$i]
            $cb = $ab.Child.Children[0]
            if ($cb.IsChecked) { $ab.Background = $bc.ConvertFromString($t["AppSelectedBg"]) }
            else { $ab.Background = [System.Windows.Media.Brushes]::Transparent }
        }
        foreach ($btn in $el["SecButtons"]) {
            $btn.Background  = $bc.ConvertFromString($t["SecBtnBg"])
            $btn.BorderBrush = $bc.ConvertFromString($t["SecBtnBorder"])
            $btn.Foreground  = $bc.ConvertFromString($t["SecBtnText"])
        }
        foreach ($chk in $el["FooterChecks"]) { $chk.Foreground = $bc.ConvertFromString($t["CheckboxText"]) }
        try {
            $ModeBtn.ApplyTemplate()
            $modeBorder = [System.Windows.Media.VisualTreeHelper]::GetChild($ModeBtn, 0)
            if ($modeBorder) {
                $modeBorder.Background = $bc.ConvertFromString($t["SecBtnBg"])
                $modeBorder.BorderBrush = $bc.ConvertFromString($t["SecBtnBorder"])
                $iconTb = $modeBorder.Child
                if ($iconTb) { $iconTb.Text = if ($ui["IsDark"]) { [char]0x2600 } else { [char]0x263E } }
            }
        } catch {}

        # Sidebar theming
        try {
            $ui["SidebarBorder"].Background = $bc.ConvertFromString($t["SidebarBg"])
            $ui["SidebarBorder"].BorderBrush = $bc.ConvertFromString($t["SidebarBorder"])
            $ui["SidebarTitle"].Foreground = $bc.ConvertFromString($t["CategoryTitle"])
            $ui["SidebarSubtitle"].Foreground = $bc.ConvertFromString($t["SidebarSubtitle"])
            foreach ($sbBtn in $ui["Elements"]["SidebarButtons"]) {
                $sbBtn.Foreground = $bc.ConvertFromString($t["SidebarText"])
            }
            foreach ($sbCount in $ui["Elements"]["SidebarCounts"]) {
                $sbCount.Foreground = $bc.ConvertFromString($t["SidebarCountText"])
            }
            foreach ($sbRow in $ui["Elements"]["SidebarRows"]) {
                if ($ui["ActiveSidebarRow"] -eq $sbRow) {
                    $sbRow.Background = $bc.ConvertFromString($t["SidebarActive"])
                } else {
                    $sbRow.Background = [System.Windows.Media.Brushes]::Transparent
                }
            }
        } catch {}

        # Log panel theming
        try {
            $ui["LogPanelBorder"].Background = $bc.ConvertFromString($t["LogBg"])
            $ui["LogPanelBorder"].BorderBrush = $bc.ConvertFromString($t["LogBorder"])
            $ui["LogTitle"].Foreground = $bc.ConvertFromString($t["CategoryTitle"])
            $ui["LogSubtitle"].Foreground = $bc.ConvertFromString($t["FooterText"])
        } catch {}

        # Package detail panel theming
        try {
            $ui["PackageDetailsBorder"].Background = $bc.ConvertFromString($t["LogBg"])
            $ui["PackageDetailsBorder"].BorderBrush = $bc.ConvertFromString($t["LogBorder"])
            $ui["PackageDetailsTitle"].Foreground = $bc.ConvertFromString($t["CategoryTitle"])
            $ui["PackageDetailsSubtitle"].Foreground = $bc.ConvertFromString($t["FooterText"])
            foreach ($label in $ui["DetailLabels"]) { if ($label) { $label.Foreground = $bc.ConvertFromString($t["FooterText"]) } }
            foreach ($value in $ui["DetailValues"]) { if ($value) { $value.Foreground = $bc.ConvertFromString($t["LogText"]) } }
            $ui["DetailWarnings"].Foreground = $bc.ConvertFromString($t["LogSkip"])
        } catch {}

        try {
            $ui["EmptyStateBorder"].Background = $bc.ConvertFromString($t["EmptyStateBg"])
            $ui["EmptyStateBorder"].BorderBrush = $bc.ConvertFromString($t["EmptyStateBorder"])
            $ui["EmptyStateTitle"].Foreground = $bc.ConvertFromString($t["EmptyStateTitle"])
            $ui["EmptyStateBody"].Foreground = $bc.ConvertFromString($t["EmptyStateText"])
        } catch {}

        # Collapse arrow theming
        foreach ($arrow in $ui["Elements"]["CollapseArrows"]) {
            $arrow.Foreground = $bc.ConvertFromString($t["CollapseArrow"])
        }
    }

    # ========================================================
    # BUILD CATEGORIES (instant - icons lazy-loaded after open)
    # ========================================================
    $splash = Show-Splash
    $splash.Window.Show()
    Update-Splash $splash "Building interface..." 50

    $toBrush = { param([string]$hex) [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex) }
    $SetDetailText = {
        param([object]$TextBlock, [string]$Value)
        if ($TextBlock) {
            $TextBlock.Text = if ([string]::IsNullOrWhiteSpace($Value)) { "-" } else { $Value }
        }
    }
    $ShowPackageDetails = {
        param([object]$App)

        $ui["PackageDetailsBorder"].Visibility = [System.Windows.Visibility]::Visible
        $ui["PackageDetailsTitle"].Text = $App.Name
        $ui["PackageDetailsSubtitle"].Text = "$($App.WingetId) - loading source and installer metadata..."
        & $SetDetailText $ui["DetailSource"] "-"
        & $SetDetailText $ui["DetailPublisher"] "-"
        & $SetDetailText $ui["DetailInstalledVersion"] "-"
        & $SetDetailText $ui["DetailInstallerType"] "-"
        & $SetDetailText $ui["DetailInstallerUrl"] "-"
        & $SetDetailText $ui["DetailSha256"] "-"
        $ui["DetailWarnings"].Text = ""
        [System.Windows.Forms.Application]::DoEvents()

        $details = Get-WinGetPackageDetails -PackageId $App.WingetId
        & $SetDetailText $ui["DetailSource"] $details.Source
        & $SetDetailText $ui["DetailPublisher"] $details.Publisher
        $installedText = if ($details.InstalledVersion) { $details.InstalledVersion } elseif ($ui["InstalledIds"].ContainsKey($App.WingetId)) { "Detected" } else { "Not detected" }
        if ($details.LatestVersion) { $installedText = "$installedText / latest $($details.LatestVersion)" }
        & $SetDetailText $ui["DetailInstalledVersion"] $installedText
        & $SetDetailText $ui["DetailInstallerType"] $details.InstallerType
        & $SetDetailText $ui["DetailInstallerUrl"] $(if ($details.InstallerUrl) { "URL: $($details.InstallerUrl)" } elseif ($details.Homepage) { "Homepage: $($details.Homepage)" } else { "" })
        & $SetDetailText $ui["DetailSha256"] $details.InstallerSha256
        if ($details.Warnings.Count -gt 0) {
            $ui["DetailWarnings"].Text = "Warnings: $($details.Warnings -join ' ')"
        } else {
            $ui["DetailWarnings"].Text = ""
        }
        $ui["PackageDetailsSubtitle"].Text = "$($App.WingetId) - metadata from winget show"
    }
    $PackageDetailsCloseBtn.Add_Click({ $ui["PackageDetailsBorder"].Visibility = [System.Windows.Visibility]::Collapsed }.GetNewClosure())
    $appNum = 0

    foreach ($category in $Script:SoftwareDatabase.Keys) {
        $catData = @{ Card = $null; Apps = [System.Collections.ArrayList]::new() }

        $categoryBorder = New-Object System.Windows.Controls.Border
        $categoryBorder.Background = (& $toBrush "#0d1b2b")
        $categoryBorder.BorderBrush = (& $toBrush "#1f3145")
        $categoryBorder.BorderThickness = [System.Windows.Thickness]::new(1)
        $categoryBorder.CornerRadius = [System.Windows.CornerRadius]::new(14)
        $categoryBorder.Margin = [System.Windows.Thickness]::new(6, 6, 6, 6)
        $categoryBorder.Width = 252
        $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadow.BlurRadius = 16; $shadow.Opacity = 0.18; $shadow.ShadowDepth = 2
        $shadow.Color = [System.Windows.Media.Colors]::Black
        $categoryBorder.Effect = $shadow
        [void]$ui["Elements"]["CategoryCards"].Add($categoryBorder)
        $catData["Card"] = $categoryBorder

        $categoryStack = New-Object System.Windows.Controls.StackPanel

        $headerBorder = New-Object System.Windows.Controls.Border
        $headerBorder.Background = (& $toBrush "#0f2133")
        $headerBorder.CornerRadius = [System.Windows.CornerRadius]::new(14, 14, 0, 0)
        $headerBorder.Padding = [System.Windows.Thickness]::new(12, 10, 12, 10)
        $headerBorder.BorderBrush = (& $toBrush "#21354a")
        $headerBorder.BorderThickness = [System.Windows.Thickness]::new(0, 0, 0, 1)
        [void]$ui["Elements"]["CategoryHeaders"].Add($headerBorder)

        $headerGrid = New-Object System.Windows.Controls.Grid
        $col0 = New-Object System.Windows.Controls.ColumnDefinition; $col0.Width = [System.Windows.GridLength]::Auto
        $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = [System.Windows.GridLength]::Auto
        $col3 = New-Object System.Windows.Controls.ColumnDefinition; $col3.Width = [System.Windows.GridLength]::Auto
        $headerGrid.ColumnDefinitions.Add($col0); $headerGrid.ColumnDefinitions.Add($col1); $headerGrid.ColumnDefinitions.Add($col2); $headerGrid.ColumnDefinitions.Add($col3)

        # Collapse/expand arrow
        $collapseArrow = New-Object System.Windows.Controls.TextBlock
        $collapseArrow.Text = [string][char]0x25BC
        $collapseArrow.FontSize = 9
        $collapseArrow.Foreground = (& $toBrush "#6f879e")
        $collapseArrow.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $collapseArrow.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
        [System.Windows.Controls.Grid]::SetColumn($collapseArrow, 0)
        [void]$ui["Elements"]["CollapseArrows"].Add($collapseArrow)

        $categoryTitle = New-Object System.Windows.Controls.TextBlock
        $categoryTitle.Text = $category
        $categoryTitle.FontSize = 12
        $categoryTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
        $categoryTitle.Foreground = (& $toBrush "#8cd2ff")
        $categoryTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($categoryTitle, 1)
        [void]$ui["Elements"]["CategoryTitles"].Add($categoryTitle)

        $catCount = $Script:SoftwareDatabase[$category].Count
        $countBadge = New-Object System.Windows.Controls.Border
        $countBadge.Background = (& $toBrush "#102133")
        $countBadge.CornerRadius = [System.Windows.CornerRadius]::new(999)
        $countBadge.Padding = [System.Windows.Thickness]::new(8, 3, 8, 3)
        $countBadge.Margin = [System.Windows.Thickness]::new(6, 0, 6, 0)
        $countBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $countText = New-Object System.Windows.Controls.TextBlock
        $countText.Text = $catCount.ToString()
        $countText.FontSize = 9.5
        $countText.FontWeight = [System.Windows.FontWeights]::SemiBold
        $countText.Foreground = (& $toBrush "#8ca0b7")
        $countText.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $countBadge.Child = $countText
        [System.Windows.Controls.Grid]::SetColumn($countBadge, 2)
        [void]$ui["Elements"]["CountBadges"].Add($countBadge)
        [void]$ui["Elements"]["CountTexts"].Add($countText)

        $catSelectAll = New-Object System.Windows.Controls.CheckBox
        $catSelectAll.Content = "All"
        $catSelectAll.Foreground = (& $toBrush "#8ca0b7")
        $catSelectAll.FontSize = 10.5
        $catSelectAll.Cursor = [System.Windows.Input.Cursors]::Hand
        $catSelectAll.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        [System.Windows.Controls.Grid]::SetColumn($catSelectAll, 3)
        [void]$ui["Elements"]["CategoryAlls"].Add($catSelectAll)

        [void]$headerGrid.Children.Add($collapseArrow); [void]$headerGrid.Children.Add($categoryTitle); [void]$headerGrid.Children.Add($countBadge); [void]$headerGrid.Children.Add($catSelectAll)
        $headerBorder.Child = $headerGrid
        $headerBorder.Cursor = [System.Windows.Input.Cursors]::Hand
        [void]$categoryStack.Children.Add($headerBorder)

        $appsStack = New-Object System.Windows.Controls.StackPanel
        $appsStack.Margin = [System.Windows.Thickness]::new(8, 6, 8, 8)
        $categoryCheckboxList = [System.Collections.ArrayList]::new()

        foreach ($app in $Script:SoftwareDatabase[$category]) {
            $appNum++

            $appBorder = New-Object System.Windows.Controls.Border
            $appBorder.CornerRadius = [System.Windows.CornerRadius]::new(10)
            $appBorder.Padding = [System.Windows.Thickness]::new(8, 6, 8, 6)
            $appBorder.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
            $appBorder.Cursor = [System.Windows.Input.Cursors]::Hand
            [void]$ui["Elements"]["AppBorders"].Add($appBorder)

            $appStack = New-Object System.Windows.Controls.Grid
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) }))
            $appStack.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = [System.Windows.GridLength]::Auto }))

            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $checkbox.Tag = $app
            [System.Windows.Controls.Grid]::SetColumn($checkbox, 0)

            $iconImage = New-Object System.Windows.Controls.Image
            $iconImage.Width = 18; $iconImage.Height = 18
            $iconImage.Margin = [System.Windows.Thickness]::new(10, 0, 8, 0)
            $iconImage.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            [System.Windows.Controls.Grid]::SetColumn($iconImage, 2)

            # Instant letter-icon placeholder; real icons load async after window opens
            $iconImage.Source = New-LetterIcon -Letter $app.Name[0] -ColorHex (Get-LetterColor $app.Name)
            [void]$ui["IconQueue"].Add(@{ Image = $iconImage; Url = $app.Icon; Name = $app.Name })

            $appLabel = New-Object System.Windows.Controls.TextBlock
            $appLabel.Text = $app.Name
            $appLabel.FontSize = 11.5
            $appLabel.Foreground = (& $toBrush "#e5edf5")
            $appLabel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $appLabel.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
            [System.Windows.Controls.Grid]::SetColumn($appLabel, 3)
            [void]$ui["Elements"]["AppLabels"].Add($appLabel)

            $installedBadge = New-Object System.Windows.Controls.Border
            $installedBadge.Background = (& $toBrush "#103526")
            $installedBadge.BorderBrush = (& $toBrush "#103526")
            $installedBadge.BorderThickness = [System.Windows.Thickness]::new(1)
            $installedBadge.CornerRadius = [System.Windows.CornerRadius]::new(999)
            $installedBadge.Padding = [System.Windows.Thickness]::new(7, 2, 7, 2)
            $installedBadge.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
            $installedBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $installedBadge.Visibility = [System.Windows.Visibility]::Collapsed
            $installedBadge.ToolTip = "Already installed"
            [System.Windows.Controls.Grid]::SetColumn($installedBadge, 4)

            $installedText = New-Object System.Windows.Controls.TextBlock
            $installedText.Text = "Installed"
            $installedText.FontSize = 9.5
            $installedText.FontWeight = [System.Windows.FontWeights]::SemiBold
            $installedText.Foreground = (& $toBrush "#78ddb1")
            $installedBadge.Child = $installedText
            [void]$ui["Elements"]["InstalledDots"].Add($installedBadge)
            [void]$ui["Elements"]["AppStatusBadges"].Add($installedBadge)
            [void]$ui["Elements"]["AppStatusTexts"].Add($installedText)

            [void]$appStack.Children.Add($checkbox)
            [void]$appStack.Children.Add($iconImage)
            [void]$appStack.Children.Add($appLabel)
            [void]$appStack.Children.Add($installedBadge)

            $appBorder.Child = $appStack

            # Enhanced tooltip with WingetId
            $tipStack = New-Object System.Windows.Controls.StackPanel
            $tipName = New-Object System.Windows.Controls.TextBlock
            $tipName.Text = $app.Name; $tipName.FontWeight = [System.Windows.FontWeights]::SemiBold; $tipName.FontSize = 12
            $tipId = New-Object System.Windows.Controls.TextBlock
            $tipId.Text = $app.WingetId; $tipId.Foreground = (& $toBrush "#6c7a89"); $tipId.FontSize = 11
            [void]$tipStack.Children.Add($tipName); [void]$tipStack.Children.Add($tipId)
            $appBorder.ToolTip = $tipStack

            # Shift-click support: track app index for range selection
            $localAppNum = $appNum
            $localApp = $app
            $appBorder.Add_MouseLeftButtonDown({
                param($s,$e)
                $cb = $s.Child.Children[0]
                $shiftHeld = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
                if ($shiftHeld -and $ui["LastClickedIndex"] -ge 0) {
                    $startIdx = [math]::Min($ui["LastClickedIndex"], $localAppNum)
                    $endIdx = [math]::Max($ui["LastClickedIndex"], $localAppNum)
                    $newState = -not $cb.IsChecked
                    $idx = 0
                    foreach ($cat in $ui["Categories"]) {
                        foreach ($appEntry in $cat["Apps"]) {
                            $idx++
                            if ($idx -ge $startIdx -and $idx -le $endIdx) {
                                $ui["AllCheckboxes"][$appEntry["WingetId"]].IsChecked = $newState
                            }
                        }
                    }
                } else {
                    $cb.IsChecked = -not $cb.IsChecked
                }
                $ui["LastClickedIndex"] = $localAppNum
                & $ShowPackageDetails $localApp
                $e.Handled = $true
            }.GetNewClosure())
            $appBorder.Add_MouseEnter({ param($s,$e); $hc=$ui["HoverBg"]; if($hc){ $s.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($hc) } }.GetNewClosure())
            $appBorder.Add_MouseLeave({ param($s,$e); $cb=$s.Child.Children[0]; if($cb.IsChecked){ $sc=$ui["SelectedBg"]; if($sc){$s.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($sc)}}else{$s.Background=[System.Windows.Media.Brushes]::Transparent} }.GetNewClosure())
            $checkbox.Add_Checked({ param($sender,$e); $sc=$ui["SelectedBg"]; if($sc){$sender.Parent.Parent.Background=[System.Windows.Media.BrushConverter]::new().ConvertFromString($sc)}; & $UpdateSelectedCount }.GetNewClosure())
            $checkbox.Add_Unchecked({ param($sender,$e); $sender.Parent.Parent.Background=[System.Windows.Media.Brushes]::Transparent; & $UpdateSelectedCount }.GetNewClosure())

            [void]$appsStack.Children.Add($appBorder)
            $ui["AllCheckboxes"][$app.WingetId] = $checkbox
            [void]$categoryCheckboxList.Add($checkbox)

            # Track for filtering
            [void]$catData["Apps"].Add(@{
                Border = $appBorder; Name = $app.Name; WingetId = $app.WingetId
            })
        }

        $catCbList = $categoryCheckboxList.ToArray()
        $catSelectAll.Add_Click({ param($sender,$e); $isChecked=$sender.IsChecked; foreach($cb in $catCbList){if($cb.Parent.Parent.Visibility -eq 'Visible'){$cb.IsChecked=$isChecked}} }.GetNewClosure())

        # Collapse/expand on header click
        $localAppsStack = $appsStack
        $localArrow = $collapseArrow
        $headerBorder.Add_MouseLeftButtonDown({
            param($s, $e)
            if ($localAppsStack.Visibility -eq [System.Windows.Visibility]::Visible) {
                $localAppsStack.Visibility = [System.Windows.Visibility]::Collapsed
                $localArrow.Text = [string][char]0x25B6
            } else {
                $localAppsStack.Visibility = [System.Windows.Visibility]::Visible
                $localArrow.Text = [string][char]0x25BC
            }
            $e.Handled = $true
        }.GetNewClosure())

        [void]$categoryStack.Children.Add($appsStack)
        [void]$ui["CategoryAppsStacks"].Add($appsStack)
        $categoryBorder.Child = $categoryStack
        [void]$CategoriesPanel.Children.Add($categoryBorder)
        [void]$ui["Categories"].Add($catData)
    }

    # ========================================================
    # POPULATE SIDEBAR
    # ========================================================
    $catIdx = 0
    foreach ($category in $Script:SoftwareDatabase.Keys) {
        $catCount = $Script:SoftwareDatabase[$category].Count
        $localIdx = $catIdx
        $localCard = $ui["Categories"][$catIdx]["Card"]

        $sideBtn = New-Object System.Windows.Controls.Border
        $sideBtn.Padding = [System.Windows.Thickness]::new(12, 8, 12, 8)
        $sideBtn.Margin = [System.Windows.Thickness]::new(6, 2, 6, 2)
        $sideBtn.CornerRadius = [System.Windows.CornerRadius]::new(10)
        $sideBtn.Cursor = [System.Windows.Input.Cursors]::Hand
        $sideBtn.Background = [System.Windows.Media.Brushes]::Transparent

        $sideBtnGrid = New-Object System.Windows.Controls.Grid
        $sCol1 = New-Object System.Windows.Controls.ColumnDefinition; $sCol1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $sCol2 = New-Object System.Windows.Controls.ColumnDefinition; $sCol2.Width = [System.Windows.GridLength]::Auto
        $sideBtnGrid.ColumnDefinitions.Add($sCol1); $sideBtnGrid.ColumnDefinitions.Add($sCol2)

        $sideBtnText = New-Object System.Windows.Controls.TextBlock
        $sideBtnText.Text = $category
        $sideBtnText.FontSize = 11
        $sideBtnText.Foreground = (& $toBrush "#acc0d4")
        $sideBtnText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $sideBtnText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
        [System.Windows.Controls.Grid]::SetColumn($sideBtnText, 0)

        $sideBtnCount = New-Object System.Windows.Controls.TextBlock
        $sideBtnCount.Text = $catCount.ToString()
        $sideBtnCount.FontSize = 9.5
        $sideBtnCount.Foreground = (& $toBrush "#6e859a")
        $sideBtnCount.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        $sideBtnCount.Margin = [System.Windows.Thickness]::new(6, 0, 0, 0)
        [System.Windows.Controls.Grid]::SetColumn($sideBtnCount, 1)

        [void]$sideBtnGrid.Children.Add($sideBtnText); [void]$sideBtnGrid.Children.Add($sideBtnCount)
        $sideBtn.Child = $sideBtnGrid

        $sideBtn.Add_MouseEnter({
            param($s,$e)
            if ($ui["ActiveSidebarRow"] -ne $s) {
                $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
                $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($t["SidebarHover"])
            }
        }.GetNewClosure())
        $sideBtn.Add_MouseLeave({
            param($s,$e)
            if ($ui["ActiveSidebarRow"] -ne $s) {
                $s.Background = [System.Windows.Media.Brushes]::Transparent
            }
        }.GetNewClosure())
        $sideBtn.Add_MouseLeftButtonDown({
            param($s,$e)
            # Expand the category if collapsed
            $stack = $ui["CategoryAppsStacks"][$localIdx]
            if ($stack.Visibility -eq [System.Windows.Visibility]::Collapsed) {
                $stack.Visibility = [System.Windows.Visibility]::Visible
                $ui["Elements"]["CollapseArrows"][$localIdx].Text = [string][char]0x25BC
            }
            if ($ui["ActiveSidebarRow"] -and $ui["ActiveSidebarRow"] -ne $s) {
                $ui["ActiveSidebarRow"].Background = [System.Windows.Media.Brushes]::Transparent
            }
            $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
            $s.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($t["SidebarActive"])
            $ui["ActiveSidebarRow"] = $s
            $localCard.BringIntoView()
            $e.Handled = $true
        }.GetNewClosure())

        [void]$SidebarPanel.Children.Add($sideBtn)
        [void]$ui["SidebarButtons"].Add($sideBtnText)
        [void]$ui["Elements"]["SidebarButtons"].Add($sideBtnText)
        [void]$ui["Elements"]["SidebarCounts"].Add($sideBtnCount)
        [void]$ui["Elements"]["SidebarRows"].Add($sideBtn)
        $catIdx++
    }

    # Apps ready, icons loading in background

    # ========================================================
    # GROUPS COMBO POPULATION
    # ========================================================
    $RefreshGroupCombo = {
        $GroupCombo.Items.Clear()
        # Placeholder
        $placeholder = New-Object System.Windows.Controls.ComboBoxItem
        $placeholder.Content = "Saved and starter groups"
        $placeholder.IsEnabled = $false
        $GroupCombo.Items.Add($placeholder) | Out-Null

        # Built-in groups header
        $biHeader = New-Object System.Windows.Controls.ComboBoxItem
        $biHeader.Content = "--- Built-in Groups ---"
        $biHeader.IsEnabled = $false
        $biHeader.FontWeight = [System.Windows.FontWeights]::Bold
        $biHeader.FontSize = 10
        $GroupCombo.Items.Add($biHeader) | Out-Null

        foreach ($gName in $ui["BuiltInGroups"].Keys) {
            $count = $ui["BuiltInGroups"][$gName].Count
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Content = "$gName ($count)"
            $item.Tag = @{ Name = $gName; Type = "builtin" }
            $GroupCombo.Items.Add($item) | Out-Null
        }

        # User saved groups
        $saved = Get-SavedGroups
        $userProps = @($saved.PSObject.Properties)
        if ($userProps.Count -gt 0) {
            $usrHeader = New-Object System.Windows.Controls.ComboBoxItem
            $usrHeader.Content = "--- My Saved Groups ---"
            $usrHeader.IsEnabled = $false
            $usrHeader.FontWeight = [System.Windows.FontWeights]::Bold
            $usrHeader.FontSize = 10
            $GroupCombo.Items.Add($usrHeader) | Out-Null

            foreach ($prop in $userProps) {
                $count = @($prop.Value).Count
                $item = New-Object System.Windows.Controls.ComboBoxItem
                $item.Content = "$($prop.Name) ($count)"
                $item.Tag = @{ Name = $prop.Name; Type = "user" }
                $GroupCombo.Items.Add($item) | Out-Null
            }
        }

        $GroupCombo.SelectedIndex = 0
        & $UpdateGroupActionState
    }
    & $RefreshGroupCombo

    # ========================================================
    # WINGET CHECK
    # ========================================================
    $checkWinGet = {
        $status = Test-WinGet
        if ($status.Installed) {
            $WinGetStatus.Text = "WinGet $($status.Version)"
            $WinGetDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#1fb879")
            $InstallWinGetBtn.Visibility = [System.Windows.Visibility]::Collapsed
        } else {
            $WinGetStatus.Text = "WinGet required"
            $WinGetDot.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#dc3545")
            $InstallWinGetBtn.Visibility = [System.Windows.Visibility]::Visible
        }
    }
    & $checkWinGet

    # ========================================================
    # EVENT HANDLERS
    # ========================================================

    # Search
    $SearchBorder = $Window.FindName("SearchBorder")
    $SearchBox.Add_GotFocus({
        $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        $SearchBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($t["SearchFocus"])
        $SearchBorder.BorderThickness = [System.Windows.Thickness]::new(1.5)
    }.GetNewClosure())
    $SearchBox.Add_LostFocus({
        $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        $SearchBorder.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($t["SearchBorder"])
        $SearchBorder.BorderThickness = [System.Windows.Thickness]::new(1)
    }.GetNewClosure())
    $SearchBox.Add_TextChanged({
        $SearchPlaceholder.Visibility = if ($SearchBox.Text.Length -gt 0) { "Collapsed" } else { "Visible" }
        & $ApplyFilter
    }.GetNewClosure())
    $ClearSearchBtn.Add_Click({ $SearchBox.Clear(); $SearchBox.Focus() | Out-Null }.GetNewClosure())
    $EmptyStateClearBtn.Add_Click({ $SearchBox.Clear(); $SearchBox.Focus() | Out-Null }.GetNewClosure())
    $EmptyStateResetModeBtn.Add_Click({ & $ExitUpdateView }.GetNewClosure())
    $MainScroll.Add_SizeChanged({ & $UpdateCardLayout }.GetNewClosure())
    $Window.Add_SizeChanged({ & $UpdateCardLayout }.GetNewClosure())
    $GroupCombo.Add_SelectionChanged({ & $UpdateGroupActionState }.GetNewClosure())

    # Dark mode
    $ModeBtn.Add_Click({ $ui["IsDark"] = -not $ui["IsDark"]; & $ApplyTheme; & $UpdateSelectedCount }.GetNewClosure())

    # Log panel toggle
    $LogToggleBtn.Add_Click({
        if ($LogPanelBorder.Visibility -eq [System.Windows.Visibility]::Visible) {
            $LogPanelBorder.Visibility = [System.Windows.Visibility]::Collapsed
            $LogToggleBtn.Content = "Show"
        } else {
            $LogPanelBorder.Visibility = [System.Windows.Visibility]::Visible
            $LogToggleBtn.Content = "Hide"
        }
    }.GetNewClosure())

    # Select/deselect only visible apps
    $SelectAllBtn.Add_Click({
        foreach ($cat in $ui["Categories"]) {
            foreach ($appEntry in $cat["Apps"]) {
                if ($appEntry["Border"].Visibility -eq 'Visible') {
                    $ui["AllCheckboxes"][$appEntry["WingetId"]].IsChecked = $true
                }
            }
        }
    }.GetNewClosure())

    $DeselectAllBtn.Add_Click({
        foreach ($cat in $ui["Categories"]) {
            foreach ($appEntry in $cat["Apps"]) {
                if ($appEntry["Border"].Visibility -eq 'Visible') {
                    $ui["AllCheckboxes"][$appEntry["WingetId"]].IsChecked = $false
                }
            }
        }
    }.GetNewClosure())

    $InstallWinGetBtn.Add_Click({
        $ProgressText.Text = "Repairing WinGet/App Installer..."
        $installed = Install-WinGet
        & $checkWinGet
        $logSuffix = if ($Script:LastBootstrapLogPath) { " Log: $Script:LastBootstrapLogPath" } else { "" }
        $ProgressText.Text = if ($installed) { "WinGet is ready.$logSuffix" } else { "WinGet repair needs manual follow-up.$logSuffix" }
    }.GetNewClosure())

    # ========================================================
    # GROUP HANDLERS
    # ========================================================

    # Helper to get selected package IDs
    $GetSelectedIds = {
        $sel = [System.Collections.ArrayList]::new()
        foreach ($cb in $ui["AllCheckboxes"].Values) {
            if ($cb.IsChecked -eq $true) { [void]$sel.Add($cb.Tag.WingetId) }
        }
        return $sel.ToArray()
    }

    # Helper to apply a list of package IDs as checked
    $ApplyPackageList = {
        param([string[]]$ids)
        foreach ($cb in $ui["AllCheckboxes"].Values) { $cb.IsChecked = $false }
        $loaded = 0
        foreach ($id in $ids) {
            if ($ui["AllCheckboxes"].ContainsKey($id)) {
                $ui["AllCheckboxes"][$id].IsChecked = $true
                $loaded++
            }
        }
        return $loaded
    }

    $LoadGroupBtn.Add_Click({
        $selected = $GroupCombo.SelectedItem
        if ($null -eq $selected -or $null -eq $selected.Tag) {
            $ProgressText.Text = "Choose a starter group or saved group first."
            return
        }
        $gName = $selected.Tag["Name"]
        $gType = $selected.Tag["Type"]

        if ($gType -eq "builtin") {
            $ids = $ui["BuiltInGroups"][$gName]
        } else {
            $saved = Get-SavedGroups
            $ids = @($saved.$gName)
        }

        $loaded = & $ApplyPackageList $ids
        $ProgressText.Text = "Applied '$gName' and selected $loaded of $($ids.Count) apps."
    }.GetNewClosure())

    $SaveGroupBtn.Add_Click({
        $sel = & $GetSelectedIds
        if ($sel.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Select at least one app before saving a group.", "No Apps Selected", "OK", "Information")
            return
        }

        # Input dialog for group name
        $inputXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Save Package Group" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" Background="#071018" MinWidth="420">
    <StackPanel Margin="26,22,26,22">
        <TextBlock Text="Save the current selection as a reusable group" Foreground="#f0f6fb" FontSize="15" FontWeight="SemiBold" Margin="0,0,0,6"/>
        <TextBlock Text="Wingetter will keep the exact package IDs so you can reload this setup later." Foreground="#90a4b8" FontSize="12" Margin="0,0,0,14" TextWrapping="Wrap" MaxWidth="340"/>
        <TextBlock Text="Group name" Foreground="#c4d2df" FontSize="12" Margin="0,0,0,6"/>
        <TextBox x:Name="GroupNameBox" FontSize="13" Padding="10,8" Background="#08131f" Foreground="#eff6fb" BorderBrush="#24374a" BorderThickness="1"/>
        <TextBlock Text="$($sel.Count) selected apps will be included." Foreground="#7a90a6" FontSize="11.5" Margin="0,10,0,0"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
            <Button x:Name="OkBtn" Content="Save Group" Padding="20,7" Margin="0,0,8,0" FontSize="12" IsDefault="True" Background="#1fb879" Foreground="White" BorderThickness="0" Cursor="Hand"/>
            <Button x:Name="CancelDlgBtn" Content="Cancel" Padding="18,7" FontSize="12" IsCancel="True" Background="#102133" Foreground="#dbe7f1" BorderBrush="#24374a" BorderThickness="1" Cursor="Hand"/>
        </StackPanel>
    </StackPanel>
</Window>
"@
        $inputReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($inputXaml))
        $inputWin = [Windows.Markup.XamlReader]::Load($inputReader)
        $inputWin.Owner = $ui["Window"]
        $nameBox = $inputWin.FindName("GroupNameBox")
        $okBtn = $inputWin.FindName("OkBtn")
        $cancelDlgBtn = $inputWin.FindName("CancelDlgBtn")

        $okBtn.Add_Click({ $inputWin.DialogResult = $true; $inputWin.Close() }.GetNewClosure())
        $cancelDlgBtn.Add_Click({ $inputWin.DialogResult = $false; $inputWin.Close() }.GetNewClosure())

        $nameBox.Focus() | Out-Null
        if ($inputWin.ShowDialog() -eq $true) {
            $gName = $nameBox.Text.Trim()
            if ($gName -ne "") {
                Save-GroupToFile -Name $gName -PackageIds $sel
                & $RefreshGroupCombo
                $ProgressText.Text = "Saved '$gName' with $($sel.Count) selected apps."
            }
        }
    }.GetNewClosure())

    $DeleteGroupBtn.Add_Click({
        $selected = $GroupCombo.SelectedItem
        if ($null -eq $selected -or $null -eq $selected.Tag) {
            $ProgressText.Text = "Choose a saved group to delete."
            return
        }
        if ($selected.Tag["Type"] -eq "builtin") {
            $ProgressText.Text = "Built-in groups can't be deleted."
            return
        }
        $gName = $selected.Tag["Name"]
        $confirm = [System.Windows.MessageBox]::Show("Delete the saved group '$gName'? This can't be undone.", "Delete Saved Group", "YesNo", "Warning")
        if ($confirm -ne "Yes") {
            $ProgressText.Text = "Delete cancelled."
            return
        }
        Remove-GroupFromFile -Name $gName
        & $RefreshGroupCombo
        $ProgressText.Text = "Deleted '$gName'."
    }.GetNewClosure())

    # ========================================================
    # EXPORT (WinGet JSON, Wingetter JSON, or PS1 script)
    # ========================================================
    $ExportBtn.Add_Click({
        $sel = & $GetSelectedIds
        if ($sel.Count -eq 0) { $ProgressText.Text = "Select at least one app before exporting."; return }

        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.Filter = "WinGet Import JSON (*.json)|*.json|Wingetter Group JSON (*.wingetter.json)|*.wingetter.json|PowerShell Script (*.ps1)|*.ps1"
        $dlg.FileName = "WinGetPackages.json"

        if ($dlg.ShowDialog() -eq $true) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)

            switch ($dlg.FilterIndex) {
                1 {
                    Export-GroupAsWinGetJSON -GroupName $baseName -PackageIds $sel -FilePath $dlg.FileName
                    $ProgressText.Text = "Exported $($sel.Count) apps as official WinGet import JSON."
                }
                2 {
                    Export-GroupAsJSON -GroupName $baseName -PackageIds $sel -FilePath $dlg.FileName
                    $ProgressText.Text = "Exported $($sel.Count) apps as a Wingetter group JSON profile."
                }
                3 {
                    Export-GroupAsPS1 -GroupName $baseName -PackageIds $sel -FilePath $dlg.FileName -Silent $SilentCheck.IsChecked -AcceptAgreements $AcceptCheck.IsChecked
                    $ProgressText.Text = "Exported $($sel.Count) apps as a PowerShell installer."
                }
            }
        }
    }.GetNewClosure())

    # ========================================================
    # IMPORT (WinGet JSON, Wingetter JSON, or simple package ID arrays)
    # ========================================================
    $ImportBtn.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Filter = "JSON Config (*.json;*.wingetter.json)|*.json;*.wingetter.json|All Files (*.*)|*.*"
        if ($dlg.ShowDialog() -eq $true) {
            try {
                $content = Get-Content $dlg.FileName -Raw | ConvertFrom-Json
                $fallbackName = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
                $import = Import-PackageIdsFromJSON -Content $content -FallbackGroupName $fallbackName
                $ids = @($import.PackageIds)
                if ($ids.Count -eq 0) { throw "No package IDs were found in the selected JSON file." }
                if ($import.Warnings.Count -gt 0) {
                    $ProgressText.Text = "Import warning: $($import.Warnings[0])"
                }

                $loaded = & $ApplyPackageList $ids
                $missing = $ids.Count - $loaded
                $sourceSuffix = if ($import.SourceNames.Count -gt 0) { " Sources: $(@($import.SourceNames | Select-Object -Unique) -join ', ')." } else { "" }
                if ($missing -gt 0) {
                    $ProgressText.Text = "Imported '$($import.GroupName)' ($($import.Format)) and selected $loaded of $($ids.Count) apps; $missing are not in the Wingetter catalog.$sourceSuffix"
                } else {
                    $ProgressText.Text = "Imported '$($import.GroupName)' ($($import.Format)) and selected all $loaded apps.$sourceSuffix"
                }

                # Offer to save as group
                $save = [System.Windows.MessageBox]::Show("Save '$($import.GroupName)' as a reusable Wingetter group for later?", "Save Imported Group", "YesNo", "Question")
                if ($save -eq "Yes") {
                    Save-GroupToFile -Name $import.GroupName -PackageIds $ids
                    & $RefreshGroupCombo
                    $ProgressText.Text = "Imported and saved '$($import.GroupName)' ($loaded matched apps)."
                }
            } catch {
                $ProgressText.Text = "Import failed: $($_.Exception.Message)"
            }
        }
    }.GetNewClosure())

    $CopyCommandBtn.Add_Click({
        $sel = @(); foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked) { $sel += $cb.Tag.WingetId } }
        if ($sel.Count -eq 0) { $ProgressText.Text = "Select at least one app before copying commands."; return }
        $s = if ($SilentCheck.IsChecked) { " --silent" } else { "" }
        $a = if ($AcceptCheck.IsChecked) { " --accept-package-agreements --accept-source-agreements" } else { "" }
        $cmds = $sel | ForEach-Object { "winget install --id $_ --exact$s$a" }
        [System.Windows.Clipboard]::SetText(($cmds -join "`n")); $ProgressText.Text = "Copied $($sel.Count) winget commands to the clipboard."
    }.GetNewClosure())

    $CancelBtn.Add_Click({ $ui["Cancelled"] = $true; $ProgressText.Text = "Stopping after the current package..." }.GetNewClosure())

    # Helper: add log entry to log panel
    $AddLogEntry = {
        param([string]$AppName, [string]$Status, [string]$Color)
        $statusBg = if ($ui["IsDark"]) {
            switch ($Status) {
                "SUCCESS" { "#183a2c" }
                "UP TO DATE" { "#3d3119" }
                "FAILED" { "#3d2024" }
                "ERROR" { "#3d2024" }
                "CANCELLED" { "#3d3119" }
                default { "#132132" }
            }
        } else {
            switch ($Status) {
                "SUCCESS" { "#ecfaf2" }
                "UP TO DATE" { "#fff8ea" }
                "FAILED" { "#fdf0f2" }
                "ERROR" { "#fdf0f2" }
                "CANCELLED" { "#fff8ea" }
                default { "#f4f7fb" }
            }
        }
        $entry = New-Object System.Windows.Controls.Border
        $entry.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)
        $entry.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
        $entry.CornerRadius = [System.Windows.CornerRadius]::new(10)
        $entry.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($statusBg)
        $entryGrid = New-Object System.Windows.Controls.Grid
        $eCol1 = New-Object System.Windows.Controls.ColumnDefinition; $eCol1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $eCol2 = New-Object System.Windows.Controls.ColumnDefinition; $eCol2.Width = [System.Windows.GridLength]::Auto
        $entryGrid.ColumnDefinitions.Add($eCol1); $entryGrid.ColumnDefinitions.Add($eCol2)
        $nameText = New-Object System.Windows.Controls.TextBlock
        $nameText.Text = $AppName; $nameText.FontSize = 11.5
        $theme = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        $nameText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($theme["LogText"])
        [System.Windows.Controls.Grid]::SetColumn($nameText, 0)
        $statusBadge = New-Object System.Windows.Controls.Border
        $statusBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString((if ($ui["IsDark"]) { "#132132" } else { "#ffffff" }))
        $statusBadge.CornerRadius = [System.Windows.CornerRadius]::new(999)
        $statusBadge.Padding = [System.Windows.Thickness]::new(8, 3, 8, 3)
        [System.Windows.Controls.Grid]::SetColumn($statusBadge, 1)
        $statusText = New-Object System.Windows.Controls.TextBlock
        $statusText.Text = $Status; $statusText.FontSize = 10; $statusText.FontWeight = [System.Windows.FontWeights]::SemiBold
        $statusText.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
        $statusBadge.Child = $statusText
        [void]$entryGrid.Children.Add($nameText); [void]$entryGrid.Children.Add($statusBadge)
        $entry.Child = $entryGrid
        [void]$LogEntriesPanel.Children.Add($entry)
        $LogScrollViewer.ScrollToEnd()
    }

    # Install / Update handler
    $InstallBtn.Add_Click({
        $status = Test-WinGet
        if (-not $status.Installed) { [System.Windows.MessageBox]::Show("WinGet is required before Wingetter can install packages. Use 'Install WinGet' and try again.", "WinGet Required", "OK", "Warning"); return }
        $selected = @()
        foreach ($cb in $ui["AllCheckboxes"].Values) { if ($cb.IsChecked) { $selected += @{ Name = $cb.Tag.Name; WingetId = $cb.Tag.WingetId } } }
        if ($selected.Count -eq 0) { [System.Windows.MessageBox]::Show("Select at least one app before continuing.", "No Apps Selected", "OK", "Information"); return }

        $InstallBtn.IsEnabled = $false; $CancelBtn.IsEnabled = $true; $SelectAllBtn.IsEnabled = $false; $DeselectAllBtn.IsEnabled = $false
        foreach ($ctl in @($CopyCommandBtn, $ExportBtn, $ImportBtn, $LoadGroupBtn, $SaveGroupBtn, $DeleteGroupBtn, $GroupCombo, $UpdateAllBtn, $SearchBox, $ClearSearchBtn, $InstallWinGetBtn)) {
            $ctl.IsEnabled = $false
        }
        $ui["Cancelled"] = $false

        # Show log panel and clear previous entries
        $LogEntriesPanel.Children.Clear()
        $LogPanelBorder.Visibility = [System.Windows.Visibility]::Visible
        $LogToggleBtn.Content = "Hide"

        $isUpdate = $ui["IsUpdateMode"]
        $actionVerb = if ($isUpdate) { "Updating" } else { "Installing" }
        $operation = if ($isUpdate) { "upgrade" } else { "install" }
        $runLogDir = New-WingetterRunLogDirectory -Action $operation
        $runResults = [System.Collections.ArrayList]::new()
        $total = $selected.Count; $current = 0; $ok = 0; $fail = 0; $skip = 0

        foreach ($app in $selected) {
            if ($ui["Cancelled"]) { $ProgressText.Text = "Stopped before completing the full list."; & $AddLogEntry $app.Name "CANCELLED" "#f39c12"; break }
            $current++; $pct = [math]::Round(($current / $total) * 100)
            $ProgressBar.Value = $pct; $ProgressPercent.Text = "$pct%"
            $ProgressText.Text = "$actionVerb $($app.Name) ($current of $total)..."
            [System.Windows.Forms.Application]::DoEvents()

            $result = Invoke-WinGetPackageOperation `
                -Action $operation `
                -PackageId $app.WingetId `
                -PackageName $app.Name `
                -Silent ([bool]$SilentCheck.IsChecked) `
                -AcceptAgreements ([bool]$AcceptCheck.IsChecked) `
                -RunLogDir $runLogDir `
                -ShouldCancel { $ui["Cancelled"] } `
                -PumpUi { [System.Windows.Forms.Application]::DoEvents() }

            [void]$runResults.Add($result)
            switch ($result.Status) {
                "SUCCESS" { $ok++; & $AddLogEntry $app.Name "SUCCESS" "#2ecc71" }
                "UP TO DATE" { $skip++; & $AddLogEntry $app.Name "UP TO DATE" "#f39c12" }
                "CANCELLED" { $ui["Cancelled"] = $true; & $AddLogEntry $app.Name "CANCELLED" "#f39c12" }
                default { $fail++; & $AddLogEntry $app.Name "FAILED" "#e74c3c" }
            }
            if ($ui["Cancelled"]) { break }
            [System.Windows.Forms.Application]::DoEvents()
        }

        $ui["LastRunLogDir"] = $runLogDir
        $ui["LastRunResults"] = $runResults.ToArray()

        $InstallBtn.IsEnabled = $true; $CancelBtn.IsEnabled = $false; $SelectAllBtn.IsEnabled = $true; $DeselectAllBtn.IsEnabled = $true
        foreach ($ctl in @($ImportBtn, $GroupCombo, $UpdateAllBtn, $SearchBox, $ClearSearchBtn, $InstallWinGetBtn)) {
            $ctl.IsEnabled = $true
        }
        & $UpdateGroupActionState
        & $UpdateSelectedCount
        $doneVerb = if ($isUpdate) { "updated" } else { "installed" }
        if (-not $ui["Cancelled"]) {
            $ProgressBar.Value = 100; $ProgressPercent.Text = "100%"
            $ProgressText.Text = "Finished: $ok $doneVerb, $skip already current, $fail failed. Logs: $runLogDir"

            # Windows Toast notification
            try {
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
                [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
                $toastXml = [Windows.Data.Xml.Dom.XmlDocument]::new()
                $toastXml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>Wingetter Complete</text><text>$ok $doneVerb, $skip skipped, $fail failed (of $total)</text></binding></visual></toast>")
                $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
                [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Wingetter").Show($toast)
            } catch {}

            # Auto-restore install view after update completes
            if ($isUpdate) {
                $doneMsg = $ProgressText.Text
                & $ExitUpdateView
                $ProgressText.Text = $doneMsg
            }
        } else {
            $ProgressText.Text = "Stopped before completing the full list. Logs: $runLogDir"
        }
    }.GetNewClosure())

    # ========================================================
    # UPDATE VIEW - show only installed apps in single column
    # ========================================================
    $EnterUpdateView = {
        $ui["IsUpdateMode"] = $true
        $bc = [System.Windows.Media.BrushConverter]::new()

        # Hide sidebar
        $SidebarBorder.Visibility = [System.Windows.Visibility]::Collapsed

        # Hide irrelevant toolbar buttons (groups, export, import, copy)
        $GroupCombo.Visibility = [System.Windows.Visibility]::Collapsed
        $LoadGroupBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $SaveGroupBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $DeleteGroupBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $ExportBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $ImportBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $CopyCommandBtn.Visibility = [System.Windows.Visibility]::Collapsed
        $Divider1.Visibility = [System.Windows.Visibility]::Collapsed
        $Divider2.Visibility = [System.Windows.Visibility]::Collapsed

        # Change CategoriesPanel to single column vertical layout
        $CategoriesPanel.Orientation = [System.Windows.Controls.Orientation]::Vertical

        # Show only installed apps, hide everything else
        $appIdx = 0; $installedCount = 0; $catIdx2 = 0
        $activeTheme = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
        foreach ($catName in $Script:SoftwareDatabase.Keys) {
            $card = $ui["Elements"]["CategoryCards"][$catIdx2]
            $apps = $Script:SoftwareDatabase[$catName]
            $catHasInstalled = $false

            # Hide category header elements
            try { $ui["Elements"]["CategoryHeaders"][$catIdx2].Visibility = [System.Windows.Visibility]::Collapsed } catch {}

            foreach ($app in $apps) {
                $isInstalled = $ui["InstalledIds"].ContainsKey($app.WingetId)
                $border = $ui["Elements"]["AppBorders"][$appIdx]

                if ($isInstalled) {
                    $border.Visibility = [System.Windows.Visibility]::Visible
                    $border.Opacity = 1.0
                    $ui["Elements"]["AppLabels"][$appIdx].Foreground = $bc.ConvertFromString($activeTheme["AppText"])
                    $ui["AllCheckboxes"][$app.WingetId].IsChecked = $true
                    $installedCount++
                    $catHasInstalled = $true
                } else {
                    $border.Visibility = [System.Windows.Visibility]::Collapsed
                }
                $appIdx++
            }

            if ($catHasInstalled) {
                # Show card but without header - just the app list
                $card.Visibility = [System.Windows.Visibility]::Visible
                $card.Width = [double]::NaN
                $card.Margin = [System.Windows.Thickness]::new(0)
                $card.BorderThickness = [System.Windows.Thickness]::new(0)
                $card.Background = [System.Windows.Media.Brushes]::Transparent
                try { $card.Effect = $null } catch {}
            } else {
                $card.Visibility = [System.Windows.Visibility]::Collapsed
            }

            # Expand apps stack (in case collapsed)
            try { $ui["CategoryAppsStacks"][$catIdx2].Visibility = [System.Windows.Visibility]::Visible } catch {}
            $catIdx2++
        }

        # Update button states - repurpose UpdateAllBtn as "Back to Browse"
        $UpdateAllBtn.Content = "Back to Browse"
        $UpdateAllBtn.ToolTip = "Return to the full install catalog."
        $ProgressText.Text = "$installedCount installed apps are ready to review. Uncheck anything you want to skip."
        $ToolbarHintText.Text = "Review mode shows only apps already detected on this PC."

        $SelectAllBtn.Content = "Select Visible"
        $DeselectAllBtn.Content = "Clear Visible"
        & $UpdateSelectedCount
        & $ApplyFilter
    }

    $ExitUpdateView = {
        $ui["IsUpdateMode"] = $false
        $bc = [System.Windows.Media.BrushConverter]::new()

        # Restore sidebar
        $SidebarBorder.Visibility = [System.Windows.Visibility]::Visible

        # Restore toolbar buttons
        $GroupCombo.Visibility = [System.Windows.Visibility]::Visible
        $LoadGroupBtn.Visibility = [System.Windows.Visibility]::Visible
        $SaveGroupBtn.Visibility = [System.Windows.Visibility]::Visible
        $DeleteGroupBtn.Visibility = [System.Windows.Visibility]::Visible
        $ExportBtn.Visibility = [System.Windows.Visibility]::Visible
        $ImportBtn.Visibility = [System.Windows.Visibility]::Visible
        $CopyCommandBtn.Visibility = [System.Windows.Visibility]::Visible
        $Divider1.Visibility = [System.Windows.Visibility]::Visible
        $Divider2.Visibility = [System.Windows.Visibility]::Visible

        # Restore horizontal wrap layout
        $CategoriesPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal

        # Clear search when leaving update mode
        $SearchBox.Text = ""

        # Show all apps, restore installed dimming and card styling
        $appIdx = 0; $catIdx2 = 0
        foreach ($catName in $Script:SoftwareDatabase.Keys) {
            $card = $ui["Elements"]["CategoryCards"][$catIdx2]
            $card.Visibility = [System.Windows.Visibility]::Visible
            $card.Width = 252
            $card.Margin = [System.Windows.Thickness]::new(6, 6, 6, 6)
            $card.BorderThickness = [System.Windows.Thickness]::new(1)
            $t = if ($ui["IsDark"]) { $ui["Themes"]["Dark"] } else { $ui["Themes"]["Light"] }
            $card.Background = $bc.ConvertFromString($t["CategoryCardBg"])
            $card.BorderBrush = $bc.ConvertFromString($t["CategoryCardBorder"])
            $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
            $shadow.BlurRadius = 16; $shadow.Opacity = 0.18; $shadow.ShadowDepth = 2
            $shadow.Color = [System.Windows.Media.Colors]::Black
            $card.Effect = $shadow

            # Restore category headers
            try { $ui["Elements"]["CategoryHeaders"][$catIdx2].Visibility = [System.Windows.Visibility]::Visible } catch {}

            $apps = $Script:SoftwareDatabase[$catName]
            foreach ($app in $apps) {
                $border = $ui["Elements"]["AppBorders"][$appIdx]
                $border.Visibility = [System.Windows.Visibility]::Visible
                $ui["AllCheckboxes"][$app.WingetId].IsChecked = $false

                if ($ui["InstalledIds"].ContainsKey($app.WingetId)) {
                    $border.Opacity = 0.55
                    $ui["Elements"]["AppLabels"][$appIdx].Foreground = $bc.ConvertFromString($t["AppSubtleText"])
                } else {
                    $border.Opacity = 1.0
                    $ui["Elements"]["AppLabels"][$appIdx].Foreground = $bc.ConvertFromString($t["AppText"])
                }
                $appIdx++
            }
            $catIdx2++
        }

        $UpdateAllBtn.Content = "Review Updates"
        $UpdateAllBtn.ToolTip = "Show installed apps from this catalog so you can choose what to update."
        $SelectAllBtn.Content = "Select Visible"
        $DeselectAllBtn.Content = "Clear Visible"
        $ToolbarHintText.Text = "Tip: Shift+Click selects a range."
        $ProgressText.Text = "Choose apps to install or load a saved group to get started."
        $ProgressBar.Value = 0; $ProgressPercent.Text = ""
        & $UpdateSelectedCount
        & $ApplyFilter
        & $UpdateCardLayout
    }

    $UpdateAllBtn.Add_Click({
        if ($ui["IsUpdateMode"]) {
            & $ExitUpdateView
            return
        }
        if ($ui["InstalledIds"].Count -eq 0) {
            [System.Windows.MessageBox]::Show("Wingetter has not detected any installed apps from its catalog yet. Please wait for the background scan to finish and try again.", "Updates Not Ready", "OK", "Information")
            return
        }
        & $EnterUpdateView
    }.GetNewClosure())

    & $ApplyTheme
    & $UpdateSelectedCount
    & $UpdateCardLayout
    & $ApplyFilter

    Update-Splash $splash "Ready!" 100
    $splash.Window.Close()

    # ==============================================================
    # ASYNC INSTALLED APP DETECTION - background winget list scan
    # ==============================================================
    $installedQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $installedRunspace = [runspacefactory]::CreateRunspace()
    $installedRunspace.Open()
    $installedPs = [PowerShell]::Create()
    $installedPs.Runspace = $installedRunspace
    [void]$installedPs.AddScript({
        param($queue)
        try {
            $output = & winget list --source winget 2>$null
            foreach ($line in $output) {
                if ($line -match '^\s*\S+.*?\s+(\S+\.\S+)\s+') {
                    $queue.Enqueue($Matches[1])
                }
            }
        } catch {}
        $queue.Enqueue("__DONE__")
    })
    [void]$installedPs.AddArgument($installedQueue)
    $installedHandle = $installedPs.BeginInvoke()

    # Build lookup: WingetId -> index in InstalledDots list
    $installedDotMap = @{}
    $dotIdx = 0
    foreach ($cat in $Script:SoftwareDatabase.Keys) {
        foreach ($app in $Script:SoftwareDatabase[$cat]) {
            $installedDotMap[$app.WingetId] = $dotIdx
            $dotIdx++
        }
    }

    $installedTimer = New-Object System.Windows.Threading.DispatcherTimer
    $installedTimer.Interval = [TimeSpan]::FromMilliseconds(200)
    $installedTimer.Add_Tick({
        $id = $null
        $batch = 0
        while ($batch -lt 50 -and $installedQueue.TryDequeue([ref]$id)) {
            if ($id -eq "__DONE__") {
                $installedTimer.Stop()
                try { $installedPs.EndInvoke($installedHandle) } catch {}
                $installedPs.Dispose(); $installedRunspace.Close()
                $count = $ui["InstalledIds"].Count
                $baselineText = "Choose apps to install or load a saved group to get started."
                if (($ProgressText.Text -eq $baselineText) -or ($ProgressText.Text -eq "Installed-app scan complete.")) {
                    if ($count -gt 0) {
                        $ProgressText.Text = "$count installed apps detected from the Wingetter catalog. Use Review Updates to focus on them."
                    } else {
                        $ProgressText.Text = "Installed-app scan complete."
                    }
                }
                break
            }
                if ($installedDotMap.ContainsKey($id)) {
                    $ui["InstalledIds"][$id] = $true
                    $idx = $installedDotMap[$id]
                    try {
                        $ui["Elements"]["InstalledDots"][$idx].Visibility = [System.Windows.Visibility]::Visible
                        $lbl = $ui["Elements"]["AppLabels"][$idx]
                        $themeName = if ($ui["IsDark"]) { "Dark" } else { "Light" }
                        $theme = $ui["Themes"][$themeName]
                        $lbl.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($theme["AppSubtleText"])
                        $ui["Elements"]["AppBorders"][$idx].Opacity = 0.55
                    } catch {}
                }
            $batch++
        }
    }.GetNewClosure())
    $installedTimer.Start()

    # ==============================================================
    # PARALLEL ICON LOADER - 4 concurrent runspaces via RunspacePool
    # ==============================================================
    $iconWork = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $ui["IconQueue"].Count; $i++) {
        $entry = $ui["IconQueue"][$i]
        $safeName = ($entry.Name -replace '[^\w]', '_') + ".png"
        $cachePath = Join-Path $Script:IconCacheDir $safeName
        [void]$iconWork.Add(@{ Index = $i; Url = $entry.Url; CachePath = $cachePath; Name = $entry.Name })
    }

    $doneQueue = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
    $iconWorkCount = $iconWork.Count
    $iconDoneCount = [System.Collections.Concurrent.ConcurrentDictionary[string,int]]::new()
    [void]$iconDoneCount.TryAdd("count", 0)

    # Split work across 4 chunks for parallel download
    $chunkCount = 4
    $chunkSize = [math]::Ceiling($iconWorkCount / $chunkCount)
    $iconPool = [runspacefactory]::CreateRunspacePool(1, $chunkCount)
    $iconPool.Open()
    $iconJobs = [System.Collections.ArrayList]::new()

    $iconScript = {
        param($chunk, $done, $counter)
        foreach ($item in $chunk) {
            $path = $item.CachePath
            if ((Test-Path $path) -and ([System.IO.FileInfo]::new($path)).Length -gt 100) {
                $done.Enqueue(@{ Index = $item.Index; Path = $path })
                [void]$counter.AddOrUpdate("count", 1, [Func[string,int,int]]{ param($k,$v) $v + 1 })
                continue
            }
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("User-Agent", "Mozilla/5.0")
                $wc.DownloadFile($item.Url, $path)
                $wc.Dispose()
                if ((Test-Path $path) -and ([System.IO.FileInfo]::new($path)).Length -gt 100) {
                    $done.Enqueue(@{ Index = $item.Index; Path = $path })
                }
            } catch {}
            [void]$counter.AddOrUpdate("count", 1, [Func[string,int,int]]{ param($k,$v) $v + 1 })
        }
    }

    for ($c = 0; $c -lt $chunkCount; $c++) {
        $start = $c * $chunkSize
        $end = [math]::Min($start + $chunkSize, $iconWorkCount) - 1
        if ($start -gt $end) { continue }
        $chunk = $iconWork[$start..$end]
        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $iconPool
        [void]$ps.AddScript($iconScript)
        [void]$ps.AddArgument($chunk)
        [void]$ps.AddArgument($doneQueue)
        [void]$ps.AddArgument($iconDoneCount)
        [void]$iconJobs.Add(@{ PS = $ps; Handle = $ps.BeginInvoke() })
    }

    # DispatcherTimer polls doneQueue and updates Image controls on UI thread
    $iconTimer = New-Object System.Windows.Threading.DispatcherTimer
    $iconTimer.Interval = [TimeSpan]::FromMilliseconds(60)
    $iconTimer.Add_Tick({
        $batch = 0
        $result = $null
        while ($batch -lt 30 -and $doneQueue.TryDequeue([ref]$result)) {
            try {
                $entry = $ui["IconQueue"][$result.Index]
                $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
                $bitmap.BeginInit()
                $bitmap.UriSource = [Uri]::new($result.Path)
                $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bitmap.DecodePixelWidth = 20
                $bitmap.DecodePixelHeight = 20
                $bitmap.EndInit()
                if ($bitmap.PixelWidth -gt 0) { $entry.Image.Source = $bitmap }
            } catch {}
            $batch++
        }
        # Check if all workers are done
        $processed = 0; try { $processed = $iconDoneCount["count"] } catch {}
        if ($processed -ge $iconWorkCount) {
            $allDone = $true
            foreach ($j in $iconJobs) { if (-not $j.Handle.IsCompleted) { $allDone = $false; break } }
            if ($allDone) {
                $iconTimer.Stop()
                foreach ($j in $iconJobs) { try { $j.PS.EndInvoke($j.Handle) } catch {}; $j.PS.Dispose() }
                $iconPool.Close()
            }
        }
    }.GetNewClosure())
    $iconTimer.Start()

    $Window.ShowDialog() | Out-Null

    # Cleanup if window closed before icons finished
    try { $iconTimer.Stop() } catch {}
    try { foreach ($j in $iconJobs) { try { if (-not $j.Handle.IsCompleted) { $j.PS.Stop() }; $j.PS.Dispose() } catch {} }; $iconPool.Close() } catch {}
    try { $installedTimer.Stop() } catch {}
    try { if (-not $installedHandle.IsCompleted) { $installedPs.Stop() }; $installedPs.Dispose(); $installedRunspace.Close() } catch {}
}
