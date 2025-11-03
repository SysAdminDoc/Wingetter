# Requires PowerShell 5.1 or later on Windows.
# This script uses WPF for enhanced UI features and Invoke-RestMethod for data fetching.

# Add necessary assemblies for WPF
Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing, System.Windows.Forms, System.Management.Automation

#region Environment & Constants
$Global:LOG_FILE_PATH = "$env:TEMP\AdvancedInstaller_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Global:CACHE_FILE_PATH = "$env:TEMP\advanced_installer_cache.json"
$Global:CACHE_EXPIRY_HOURS = 6
$Global:JSON_URI = "https://raw.githubusercontent.com/SysAdminDoc/NoNinite/refs/heads/main/data/ChocolateyPackageExporter/chocoapplications.json"
$Global:DefaultIconUrl = "https://placehold.co/24x24/1D3994/ffffff?text=PS"
$Global:MAX_PARALLEL_JOBS = 4 # Max concurrent installations
#endregion

#region Logging Functions

function Write-InstallerLog {
    param(
        [string]$Message,
        [string]$Level = "INFO" # INFO, WARN, ERROR, DEBUG
    )
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level]: $Message"
    $LogEntry | Out-File -FilePath $Global:LOG_FILE_PATH -Append -Encoding UTF8
    
    # Write to host for real-time visibility during headless execution
    Write-Host $LogEntry
}

function Show-CriticalError {
    param(
        [string]$Message
    )
    $FullMessage = "$Message`n`nLog file available at: $($Global:LOG_FILE_PATH)"
    Write-InstallerLog -Message $FullMessage -Level "FATAL"
    
    # Only show MessageBox if not in headless mode
    if (-not $AutoInstall) {
        [System.Windows.MessageBox]::Show($FullMessage, "CRITICAL ERROR", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
    Exit 1
}

#endregion

#region Dependency & Permission Checks

function Check-Dependencies {
    $Missing = @()

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        $Missing += "Winget (Windows Package Manager)"
    }
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        $Missing += "Choco (Chocolatey Package Manager)"
    }

    if ($Missing.Count -gt 0) {
        $Msg = "The following package managers are missing: $($Missing -join ', ').`n`nAutomatic installation will be severely limited or fail if you attempt to use the missing source."
        Write-InstallerLog -Message $Msg -Level "WARN"
        if (-not $AutoInstall) {
            [System.Windows.MessageBox]::Show($Msg, "Missing Dependencies", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        }
    }
}

Check-Dependencies
#endregion

#region Data Fetching and Processing

function Get-PackageData {
    
    # Needs to be defined within the function scope if used here, or passed as a param/Global
    $DefaultIconUrl = "https://placehold.co/24x24/1D3994/ffffff?text=PS" 
    
    # Use global StatusText only if running in GUI mode
    if (-not $AutoInstall) { $StatusText.Text = "Attempting to load cached data..." }

    # --- Caching Check ---
    $UseCache = $false
    if (Test-Path $Global:CACHE_FILE_PATH) {
        $CacheAge = (Get-Date) - (Get-Item $Global:CACHE_FILE_PATH).LastWriteTime
        if ($CacheAge.TotalHours -lt $Global:CACHE_EXPIRY_HOURS) {
            Write-InstallerLog -Message "Using cache: file is only $($CacheAge.TotalMinutes -as [int]) minutes old."
            $Data = Get-Content $Global:CACHE_FILE_PATH | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($Data) { $UseCache = $true }
        }
    }

    # --- Remote Fetch if cache is stale or missing ---
    if (-not $UseCache) {
        if (-not $AutoInstall) { $StatusText.Text = "Fetching live data from GitHub (Timeout: 10s)..." }
        Write-InstallerLog -Message "Fetching live data from: $($Global:JSON_URI)"
        try {
            $RemoteData = Invoke-RestMethod -Uri $Global:JSON_URI -TimeoutSec 10 -ErrorAction Stop
            
            # Save the new data to cache
            $RemoteData | ConvertTo-Json -Depth 10 | Out-File -FilePath $Global:CACHE_FILE_PATH -Encoding UTF8
            $Data = $RemoteData
            Write-InstallerLog -Message "Live data fetched and cached successfully."
        }
        catch {
            Write-InstallerLog -Message "Remote fetch failed: $($_.Exception.Message)" -Level "ERROR"
            
            # Fallback to expired cache if available
            if (Test-Path $Global:CACHE_FILE_PATH) {
                $Data = Get-Content $Global:CACHE_FILE_PATH | ConvertFrom-Json -ErrorAction SilentlyContinue
                Write-InstallerLog -Message "Falling back to stale cache data."
                if (-not $AutoInstall) { $StatusText.Text = "Warning: Failed to fetch live data. Using stale cache." }
            } else {
                Show-CriticalError "Failed to fetch data and no cache file was found."
                return $null
            }
        }
    }

    # --- Data Processing ---
    $ProcessedData = @()
    foreach ($Item in $Data) {
        # --- 1. Fix Downloads for Numeric Sorting ---
        $Item.downloads = try { [int]::Parse($Item.downloads, [System.Globalization.NumberStyles]::AllowThousands) } catch { 0 }
        
        # --- 2. Initialize Selection State ---
        $Item | Add-Member -MemberType NoteProperty -Name "IsSelected" -Value $false -Force

        # --- 3. Fix Categorization for Grouping ---
        if (-not $Item.categorization -or -not $Item.categorization.mainCategory) {
            $Item | Add-Member -MemberType NoteProperty -Name "categorization" -Value @{mainCategory="Uncategorized"} -Force
        }

        # --- 4. Fix Optional Display Fields ---
        if (-not $Item.name) { $Item | Add-Member -MemberType NoteProperty -Name "name" -Value "Unknown Package" -Force }
        if (-not $Item.description) { $Item | Add-Member -MemberType NoteProperty -Name "description" -Value "(No Description Available)" -Force }
        if (-not $Item.oneLiner) { $Item | Add-Member -MemberType NoteProperty -Name "oneLiner" -Value "(No one-liner provided)" -Force }

        # --- 5. Fix Official Website Link ---
        $WebLink = $Item.officialWebsite
        if ($WebLink -and -not ($WebLink -match "^https?://")) { $WebLink = "http://" + $WebLink }
        $Item | Add-Member -MemberType NoteProperty -Name "officialWebsite" -Value ($WebLink -or "about:blank") -Force

        # --- 6. Fix Icon URL ---
        if (-not $Item.IconUrl) {
            # Use default placeholder if no URL is provided in the JSON
            $Item | Add-Member -MemberType NoteProperty -Name "IconUrl" -Value $Global:DefaultIconUrl -Force
        }

        # --- 7. Add Winget/Choco Install Commands ---
        $Winget = $null
        $Choco = $null
        if ($Item.packageManagers -and $Item.packageManagers.winget -and $Item.packageManagers.winget.id) { 
            # Note: Winget command generation simplified here; flags are added during final script generation
            $Winget = "winget install --id $($Item.packageManagers.winget.id)"
        }
        if ($Item.installCommand -and $Item.installCommand -ne 'N/A') { 
            $Choco = $Item.installCommand 
        }

        $Item | Add-Member -MemberType NoteProperty -Name "WingetCommand" -Value $Winget -Force
        $Item | Add-Member -MemberType NoteProperty -Name "ChocoCommand" -Value $Choco -Force

        $ProcessedData += $Item
    }
    
    if (-not $AutoInstall) { $StatusText.Text = "Data ready. Select packages to install." }
    return $ProcessedData
}
#endregion

#region WPF XAML Definition
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Advanced Package Installer" Height="850" Width="1350"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header and Controls -->
        <StackPanel Grid.Row="0" Margin="0,0,0,15">
            <TextBlock FontWeight="Bold" FontSize="20" Foreground="#0096FF" Text="Advanced Package Installer"/>
            <TextBlock Name="StatusText" FontSize="11" Foreground="#AAAAAA" />
            
            <Grid Margin="0,10,0,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="2*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="1*"/>
                </Grid.ColumnDefinitions>

                <!-- Search Input -->
                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Foreground="#E0E0E0" Margin="0,0,10,0" FontWeight="SemiBold">Search Name/Desc:</TextBlock>
                    <TextBox Name="SearchTextBox" Width="300" Height="28" Background="#2D2D2D" Foreground="#E0E0E0" Padding="5"/>
                </StackPanel>

                <!-- Category Filter -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="20,0">
                    <TextBlock Foreground="#E0E0E0" Margin="0,0,10,0" FontWeight="SemiBold">Filter by Category:</TextBlock>
                    <ComboBox Name="CategoryComboBox" Width="200" Background="#2D2D2D" Foreground="#E0E0E0"/>
                </StackPanel>
                
                <!-- Icon Search Button (Simulated Favicon Search) -->
                <Button Name="btnIconSearch" Grid.Column="2" Content="Attempt Favicon Search" Width="180" Height="30" Margin="10,0" 
                        Background="#3A3A3A" Foreground="#E0E0E0" FontWeight="Bold" />
            </Grid>
        </StackPanel>

        <!-- Package Manager and Theme Selection -->
        <Grid Grid.Row="1" Margin="0,0,0,10" VerticalAlignment="Center">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            
            <StackPanel Grid.Column="0" Orientation="Horizontal">
                <TextBlock Foreground="#0096FF" Margin="0,0,20,0" FontWeight="SemiBold">Installation Source:</TextBlock>
                <RadioButton Name="rbWinget" GroupName="Manager" IsChecked="True" Margin="0,0,20,0" Content="Winget (Default)" Foreground="#E0E0E0"/>
                <RadioButton Name="rbChoco" GroupName="Manager" Content="Chocolatey" Foreground="#E0E0E0"/>
            </StackPanel>

            <StackPanel Grid.Column="2" Orientation="Horizontal" Margin="20,0">
                <TextBlock Foreground="#0096FF" Margin="0,0,10,0" FontWeight="SemiBold">Script Options:</TextBlock>
                <CheckBox Name="chkParallel" Content="Parallel Install (Max 4)" Foreground="#E0E0E0" IsChecked="False" Margin="0,0,10,0"/>
                <CheckBox Name="chkShowConsole" Content="Show Console" Foreground="#E0E0E0" IsChecked="False"/>
            </StackPanel>
            
            <Button Name="btnThemeToggle" Grid.Column="3" Content="Toggle Theme" Width="100" Height="30" Margin="10,0" 
                    Background="#3A3A3A" Foreground="#E0E0E0" FontWeight="Bold" />
        </Grid>

        <!-- Main Data View -->
        <ListView Name="PackageListView" Grid.Row="2" ScrollViewer.VerticalScrollBarVisibility="Auto" Background="#252526" BorderBrush="#444" BorderThickness="1" SelectionMode="Single">
            <ListView.View>
                <GridView>
                    <!-- Checkbox Column -->
                    <GridViewColumn Header="" Width="30">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <CheckBox IsChecked="{Binding IsSelected}" Margin="5,0"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    
                    <GridViewColumn Header="Icon" Width="40">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Image Source="{Binding IconUrl}" Width="24" Height="24" Stretch="Uniform" ToolTipService.ToolTip="{Binding}">
                                    <Image.ToolTip>
                                        <StackPanel Background="#2D2D2D" TextBlock.Foreground="#E0E0E0">
                                            <TextBlock FontWeight="Bold" Text="{Binding name}" Margin="10,10,10,5"/>
                                            <TextBlock Text="{Binding oneLiner}" TextWrapping="Wrap" MaxWidth="300" Margin="10,0,10,5" />
                                            <TextBlock Text="{Binding description}" TextWrapping="Wrap" MaxWidth="300" FontStyle="Italic" Margin="10,0,10,10" />
                                        </StackPanel>
                                    </Image.ToolTip>
                                </Image>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    
                    <GridViewColumn Header="Name" Width="200" DisplayMemberBinding="{Binding name}">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock Text="{Binding name}" Foreground="#E0E0E0"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    
                    <GridViewColumn Header="Downloads (Popularity)" Width="150" DisplayMemberBinding="{Binding downloads}">
                         <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock Text="{Binding downloads, StringFormat='N0'}" FontWeight="SemiBold" HorizontalAlignment="Right" Foreground="#00A0A0"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    
                    <GridViewColumn Header="One-Liner Description" Width="400" DisplayMemberBinding="{Binding oneLiner}">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock Text="{Binding oneLiner}" Foreground="#CCCCCC" TextTrimming="CharacterEllipsis"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    
                    <GridViewColumn Header="Category" Width="150" DisplayMemberBinding="{Binding categorization.mainCategory}">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock Text="{Binding categorization.mainCategory}" Foreground="#999999"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    
                    <GridViewColumn Header="Website" Width="150">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <TextBlock>
                                    <Hyperlink NavigateUri="{Binding officialWebsite}" Foreground="#0096FF">
                                        Open Link
                                    </Hyperlink>
                                </TextBlock>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                </GridView>
            </ListView.View>
            
            <!-- Grouping Style for Main Category -->
            <ListView.GroupStyle>
                <GroupStyle>
                    <GroupStyle.HeaderTemplate>
                        <DataTemplate>
                            <Border BorderBrush="#005696" BorderThickness="0,0,0,2" Margin="0,5,0,2" Padding="5,2,5,2" Background="#3A3A3A">
                                <TextBlock FontWeight="ExtraBold" FontSize="14" Text="{Binding Name}" Foreground="#00BFFF" />
                            </Border>
                        </DataTemplate>
                    </GroupStyle.HeaderTemplate>
                </GroupStyle>
            </ListView.GroupStyle>
        </ListView>

        <!-- Footer Buttons -->
        <Grid Grid.Row="3" Margin="0,15,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            
            <Button Name="btnToggleAll" Grid.Column="0" Content="Toggle All Visible" Width="180" Height="35" Margin="0,0,10,0" 
                    Background="#3A3A3A" Foreground="#E0E0E0" FontWeight="Bold"/>

            <TextBlock Name="DataFetchTime" Grid.Column="1" FontSize="10" Foreground="#AAAAAA" VerticalAlignment="Center" HorizontalAlignment="Left" Margin="10,0,0,0"/>

            <Button Name="btnCopyScript" Grid.Column="2" Content="Copy Install Script" Width="180" Height="35" Margin="0,0,10,0" 
                    Background="#3A3A3A" Foreground="#E0E0E0" FontWeight="Bold"/>

            <Button Name="btnInstall" Grid.Column="3" Content="Generate &amp; Run Install Script" Width="250" Height="35" 
                    Background="#007ACC" Foreground="#FFFFFF" FontWeight="Bold"/>
        </Grid>

    </Grid>
</Window>
"@
#endregion

#region WPF Initialization and Control Mapping

# FIX: Explicitly cast the XAML string to XML before creating XmlNodeReader
$reader=(New-Object System.Xml.XmlNodeReader (([xml]$XAML)))
$Form=[Windows.Markup.XamlReader]::Load($reader)

# Get controls (using Try/Catch blocks for safety if XAML load fails)
try {
    $PackageListView = $Form.FindName("PackageListView")
    $StatusText = $Form.FindName("StatusText")
    $DataFetchTime = $Form.FindName("DataFetchTime")
    $SearchTextBox = $Form.FindName("SearchTextBox")
    $CategoryComboBox = $Form.FindName("CategoryComboBox")
    $rbWinget = $Form.FindName("rbWinget")
    $rbChoco = $Form.FindName("rbChoco")
    $btnToggleAll = $Form.FindName("btnToggleAll")
    $btnInstall = $Form.FindName("btnInstall")
    $btnIconSearch = $Form.FindName("btnIconSearch")
    $btnThemeToggle = $Form.FindName("btnThemeToggle")
    $btnCopyScript = $Form.FindName("btnCopyScript")
    $chkParallel = $Form.FindName("chkParallel")
    $chkShowConsole = $Form.FindName("chkShowConsole")
} catch {
    Show-CriticalError "Failed to map WPF controls. The XAML structure may be invalid."
}

# Define the global data array and CollectionViewSource
$script:Data = @()
$script:CollectionViewSource = New-Object System.Windows.Data.CollectionViewSource
$script:CollectionViewSource.IsLiveGroupingRequested = $true
$script:IsInitialized = $false # Flag to track post-load initialization

#endregion

#region Theme Management

$Global:IsDarkMode = $true # Start in Dark Mode

function Apply-Theme {
    param([switch]$IsDark)

    if ($IsDark) {
        $Form.Background = "#1E1E1E"
        $PackageListView.Background = "#252526"
        $PackageListView.BorderBrush = "#444444"
        # Since WPF styling for controls inside the ListBox is complex, we primarily change the container/backgrounds.
        Write-InstallerLog -Message "Applied Dark Theme."
    } else {
        $Form.Background = "#F0F0F0"
        $PackageListView.Background = "#FFFFFF"
        $PackageListView.BorderBrush = "#DDDDDD"
        Write-InstallerLog -Message "Applied Light Theme."
    }

    $Global:IsDarkMode = $IsDark
    
    # Refresh is done only when data is bound in Initialize-DataBinding or manually by user
}

$btnThemeToggle.Add_Click({
    Apply-Theme -IsDark (-not $Global:IsDarkMode)
})

#endregion

#region Filtering, Sorting, and Grouping Logic

# Debounce timer object
$script:FilterTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:FilterTimer.Interval = New-Object System.TimeSpan (0, 0, 0, 0, 300) # 300ms delay

function Apply-DataView {
    param(
        [string]$Category = "All Categories",
        [string]$SearchTerm = ""
    )
    
    # CRITICAL FIX: Ensure initialization is complete before manipulating the view
    if (-not $script:IsInitialized) {
        Write-InstallerLog -Message "CollectionViewSource View not yet fully initialized. Skipping filter application." -Level "DEBUG"
        return
    }

    # 1. Apply Filtering 
    $script:CollectionViewSource.View.Filter = {
        param([object]$Item)
        $NameMatch = $true
        $CategoryMatch = $true
        $SearchTerm = $SearchTerm.ToLower()

        if ($SearchTerm) {
            $NameMatch = ($Item.name -clike "*$SearchTerm*" -or $Item.oneLiner -clike "*$SearchTerm*" -or $Item.description -clike "*$SearchTerm*")
        }

        if ($Category -and $Category -ne "All Categories") {
            $CategoryMatch = ($Item.categorization.mainCategory -ceq $Category)
        }

        return $NameMatch -and $CategoryMatch
    }
    
    # 2. Apply Sorting (Always by Downloads descending)
    $script:CollectionViewSource.SortDescriptions.Clear()
    $SortDescription = New-Object System.ComponentModel.SortDescription
    $SortDescription.PropertyName = "downloads"
    $SortDescription.Direction = [System.ComponentModel.ListSortDirection]::Descending
    $script:CollectionViewSource.SortDescriptions.Add($SortDescription)

    # 3. Apply Grouping Logic
    $script:CollectionViewSource.GroupDescriptions.Clear()
    if ($Category -and $Category -ne "All Categories") {
        $script:CollectionViewSource.GroupDescriptions.Add((New-Object System.Windows.Data.PropertyGroupDescription "categorization.mainCategory"))
        Write-InstallerLog -Message "Enabled grouping and sorting for category: $Category" -Level "DEBUG"
    } else {
        # Global view: no grouping - fulfills "All Categories" as global leaderboard view
        Write-InstallerLog -Message "Disabled grouping for global view." -Level "DEBUG"
    }

    $script:CollectionViewSource.View.Refresh()
}

# Debounced filter handler
$script:FilterTimer.Add_Tick({
    # Stop timer immediately to prevent re-triggering
    $script:FilterTimer.Stop() 
    
    # Execute the actual filtering/sorting logic
    Apply-DataView -Category $CategoryComboBox.SelectedItem -SearchTerm $SearchTextBox.Text
})

# Search Bar Event (triggers debounce timer)
$SearchTextBox.Add_TextChanged({
    $script:FilterTimer.Stop()
    $script:FilterTimer.Start()
})

# Category ComboBox Event (runs filter immediately)
$CategoryComboBox.Add_SelectionChanged({
    # Stop the search debounce timer to ensure category change takes precedence
    $script:FilterTimer.Stop()
    
    # Run the filter logic immediately
    Apply-DataView -Category $CategoryComboBox.SelectedItem -SearchTerm $SearchTextBox.Text
})

#endregion

#region Button Actions

$btnToggleAll.Add_Click({
    # Operate only on currently filtered/visible items
    $VisibleItems = @($script:CollectionViewSource.View)
    
    # Check if ANY visible item is currently UNSELECTED. If so, select all. If all are selected, deselect all.
    $HasUnselected = $VisibleItems | Where-Object { $_.IsSelected -eq $false } | Select -First 1
    $NewState = if ($HasUnselected) { $true } else { $false }
    
    # Apply the new state
    $VisibleItems | ForEach-Object { $_.IsSelected = $NewState }
    
    $script:CollectionViewSource.View.Refresh()
    Write-InstallerLog -Message "Toggled all visible items to '$NewState'." -Level "INFO"
})

$btnIconSearch.Add_Click({
    $SearchCount = 0
    
    $script:Data | ForEach-Object {
        # Only attempt to update if the current icon is the generic placeholder
        if ($_.IconUrl -eq $Global:DefaultIconUrl) {
            $Domain = try {
                $Uri = [System.Uri]$_.officialWebsite
                $BaseDomain = $Uri.Host
                if ($BaseDomain -like "www.*") { $BaseDomain = $BaseDomain.Substring(4) }
                $BaseDomain
            } catch { $null }

            if ($BaseDomain -and $BaseDomain -ne "about:blank") {
                # Favicon service replacement for Google search
                $_.IconUrl = "https://www.google.com/s2/favicons?domain=$BaseDomain&sz=32"
                $SearchCount++
            }
        }
    }
    $script:CollectionViewSource.View.Refresh()
    [System.Windows.MessageBox]::Show("$SearchCount icons updated using a Favicon Service.", "Icon Update Complete", "OK", "Information") | Out-Null
})

function Generate-InstallationScript {
    param(
        [switch]$ForExecution
    )
    
    $Source = if ($WingetOnly -or $rbWinget.IsChecked) { "Winget" } else { "Chocolatey" }
    $Parallel = if ($AutoInstall) { $false } else { $chkParallel.IsChecked }
    $MaxJobs = $Global:MAX_PARALLEL_JOBS
    
    $SelectedPackages = $script:Data | Where-Object { $_.IsSelected -eq $true }
    
    if ($SelectedPackages.Count -eq 0) {
        if (-not $AutoInstall) {
            [System.Windows.MessageBox]::Show("Please select at least one package.", "No Selection", "OK", "Exclamation") | Out-Null
        }
        return $null
    }

    Write-InstallerLog -Message "Generating install script for $Source. Parallel: $Parallel, Packages: $($SelectedPackages.Count)"

    $ScriptContent = ""
    $ScriptContent += "@echo off\n"
    $ScriptContent += "REM Installation script generated by Advanced Installer on $(Get-Date)\n"
    $ScriptContent += "REM Source: $Source. Packages: $($SelectedPackages.Count). Parallel Mode: $($Parallel)\n\n"
    
    $ValidCount = 0
    $SkippedCount = 0

    $CommandList = @()

    foreach ($Item in $SelectedPackages) {
        $Command = $null
        if ($Source -eq "Winget" -and $Item.WingetCommand) {
            $Command = $Item.WingetCommand + " --accept-package-agreements --accept-source-agreements --silent --force"
        } elseif ($Source -eq "Chocolatey" -and $Item.ChocoCommand) {
            $Command = $Item.ChocoCommand + " -y --force"
        }
        
        if ($Command) {
            $CommandList += $Command
            $ValidCount++
        } else {
            Write-InstallerLog -Message "Skipped $($Item.name): No valid command found for $Source" -Level "WARN"
            $SkippedCount++
        }
    }
    
    if ($Parallel) {
        # FIX: Correctly escape nested PowerShell commands for BAT execution
        $CommandString = ($CommandList | ForEach-Object { "$(\"'$_\'")" }) -join ", " # Escape single quote, escape double quote, join
        
        # FIX: Use escaped characters in the embedded PowerShell script
        $ScriptContent += "powershell.exe -ExecutionPolicy Bypass -Command `" `n"
        $ScriptContent += "    `$Commands = @($CommandString); `n"
        $ScriptContent += "    `$MaxJobs = $Global:MAX_PARALLEL_JOBS; `n"
        $ScriptContent += "    `$i = 0; foreach (`$cmd in `$Commands) { `n"
        $ScriptContent += "        Start-Job -ScriptBlock { param(`$c) & cmd.exe /C `$c } -ArgumentList `$cmd | Out-Null; `n"
        $ScriptContent += "        `$i++; if (`$i % `$MaxJobs -eq 0) { Get-Job | Wait-Job -Timeout 99999 | Out-Null; Receive-Job * | Out-Host; Remove-Job * | Out-Null; } `n"
        $ScriptContent += "    }; `n"
        $ScriptContent += "    Get-Job | Wait-Job -Timeout 99999 | Out-Null; Receive-Job * | Out-Host; Remove-Job * | Out-Null; `n"
        $ScriptContent += "`"\n" # End of powershell.exe -Command block
    } else {
        # Sequential logic (more stable)
        foreach ($Command in $CommandList) {
            $ScriptContent += "REM Installing $($Item.name)\n"
            $ScriptContent += "cmd.exe /C ""$Command""\n"
        }
    }
    
    $ScriptContent += "echo.\n"
    $ScriptContent += "echo ===================================================\n"
    $ScriptContent += "echo Installation Complete. Press any key to close...\n"
    $ScriptContent += "pause >nul\n"
    $ScriptContent += "exit /b\n"

    $Results = @{
        Content = $ScriptContent
        Count = $ValidCount
        Skipped = $SkippedCount
    }
    return $Results
}

# Copy Script Button
$btnCopyScript.Add_Click({
    $ScriptDetails = Generate-InstallationScript
    
    if ($ScriptDetails) {
        $ScriptDetails.Content | clip.exe
        $Msg = "Installation script for $($ScriptDetails.Count) package(s) copied to clipboard."
        [System.Windows.MessageBox]::Show($Msg, "Script Copied", "OK", "Information") | Out-Null
        Write-InstallerLog -Message $Msg
    }
})

# Install Button
$btnInstall.Add_Click({
    $ScriptDetails = Generate-InstallationScript -ForExecution
    if (-not $ScriptDetails) { return }

    $ScriptPath = "$([System.IO.Path]::GetTempPath())$(Get-Random)_install_script_temp.bat"
    $ScriptDetails.Content | Out-File -FilePath $ScriptPath -Encoding UTF8
    
    $ValidCount = $ScriptDetails.Count
    $SkippedCount = $ScriptDetails.Skipped
    
    Write-InstallerLog -Message "Generated script for $ValidCount packages, saved to: $ScriptPath"

    $ShowConsole = $chkShowConsole.IsChecked
    
    # Execute the generated BAT file via PowerShell for admin elevation
    if ($ShowConsole) {
        # Option 1: Show Console via Start-Process
        $ExecutionCmd = "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit', '-Command', '& { cmd.exe /C ""$ScriptPath"" }'"
    } else {
        # Option 2: Execute silently in BAT console
        $ExecutionCmd = "Start-Process cmd.exe -Verb RunAs -ArgumentList '/C', '""$ScriptPath""'"
    }
    
    # Execute the command
    Invoke-Expression $ExecutionCmd
    
    # Close GUI after execution command is sent
    $Form.Close()
})

#endregion

#region Headless Execution

if ($AutoInstall) {
    Write-InstallerLog -Message "--- Starting Headless Execution ---"
    
    # Load data
    $script:Data = Get-PackageData
    if ($script:Data.Count -eq 0) { Exit 1 }

    # Set filter parameters (AutoInstall forces selection)
    $TargetCategory = $CategoryFilter
    $Source = if ($WingetOnly) { "Winget" } else { "Chocolatey" }
    
    Write-InstallerLog -Message "Parameters: Category='$TargetCategory', Source='$Source'"
    
    # Select packages matching the category filter
    $script:Data | ForEach-Object {
        $CategoryMatch = ($TargetCategory -eq "All Categories") -or ($_.categorization.mainCategory -ceq $TargetCategory)
        if ($CategoryMatch) {
            $_.IsSelected = $true
        }
    }
    
    $ScriptDetails = Generate-InstallationScript -ForExecution
    
    if (-not $ScriptDetails -or $ScriptDetails.Count -eq 0) {
        Write-InstallerLog -Message "Headless installation failed: No packages selected or valid commands found." -Level "ERROR"
        Exit 1
    }

    # Execute silently
    $ScriptPath = "$([System.IO.Path]::GetTempPath())$(Get-Random)_install_script_headless.bat"
    $ScriptDetails.Content | Out-File -FilePath $ScriptPath -Encoding UTF8
    
    Write-InstallerLog -Message "Generated script for $($ScriptDetails.Count) packages: $ScriptPath. Executing..."
    
    # Execute the script in a hidden console
    Start-Process cmd.exe -Verb RunAs -ArgumentList "/C", """$ScriptPath""" -Wait -NoNewWindow
    
    Write-InstallerLog -Message "Headless installation finished."
    Exit 0
}

#endregion

#region GUI Startup and Cleanup

# Function to initialize bindings and controls after data fetch
function Initialize-DataBinding {
    
    # 1. Set ItemsSource for ListView
    $script:CollectionViewSource.Source = $script:Data
    $PackageListView.ItemsSource = $script:CollectionViewSource.View

    # 2. Populate Category ComboBox
    $Categories = @("All Categories") + ($script:Data.categorization.mainCategory | Select-Object -Unique | Sort-Object)
    $CategoryComboBox.ItemsSource = $Categories
    $CategoryComboBox.SelectedIndex = 0 # This triggers the SelectionChanged event
    
    # 3. Mark initialization complete AFTER setting Source and Index
    $script:IsInitialized = $true 

    # 4. Manually trigger the initial view filter/sort to set up the default "All Categories" leaderboard
    # We call Apply-DataView directly here, bypassing the SelectionChanged event's debounce timer,
    # ensuring the view is ready before the user interacts.
    Apply-DataView -Category $CategoryComboBox.SelectedItem -SearchTerm $SearchTextBox.Text
    
    # 5. Final UI setup
    Apply-Theme -IsDark $Global:IsDarkMode
    if ($DataFetchTime) { $DataFetchTime.Text = "Last fetch: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
}

# Cleanup: Detach events on window close to prevent memory leaks
$Form.Add_Closed({
    # Detach debounced timer
    $script:FilterTimer.Stop()
    $script:FilterTimer.Remove_Tick($script:FilterTimer.Tick.Target)
    
    # Detach dynamic hyperlink handler (this is handled by WPF internally but good practice)
    Remove-Variable script:Hyperlink_RequestNavigate -Force -ErrorAction SilentlyContinue
    
    Write-InstallerLog -Message "GUI closed. Application exiting."
})


# --- Initialization ---
$script:Data = Get-PackageData

if ($script:Data.Count -gt 0) {
    # Initialize the bindings and controls now that data is loaded
    Initialize-DataBinding
    
    # Show Form
    $Form.ShowDialog() | Out-Null
} else {
    Show-CriticalError "Could not initialize the application due to data loading failure."
}

#endregion
