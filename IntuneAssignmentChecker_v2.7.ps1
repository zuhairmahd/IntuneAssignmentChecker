Write-Host "🚀 Intune Assignment Checker v2.7" -ForegroundColor Green
Write-Host "📄 Changelog: " -NoNewline -ForegroundColor Cyan
Write-Host "https://github.com/ugurkocde/IntuneAssignmentChecker/releases" -ForegroundColor White
Write-Host ""
Write-Host "💝 Support this Project: " -NoNewline -ForegroundColor Cyan
Write-Host "https://github.com/sponsors/ugurkocde" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  DISCLAIMER: This script is provided AS IS without warranty of any kind." -ForegroundColor Yellow
Write-Host ""

####################################################################################################
# Autoupdate function

# URL to the version file on GitHub
$versionUrl = "https://raw.githubusercontent.com/ugurkocde/IntuneAssignmentChecker/main/version_v2.7.txt"

# URL to the latest script on GitHub
$scriptUrl = "https://raw.githubusercontent.com/ugurkocde/IntuneAssignmentChecker/main/IntuneAssignmentChecker_v2.7.ps1"

# Determine the script path based on whether it's run as a file or from an IDE
if ($PSScriptRoot) {
    $newScriptPath = Join-Path $PSScriptRoot "IntuneAssignmentChecker_v2.7.ps1"
}
else {
    $currentDirectory = Get-Location
    $newScriptPath = Join-Path $currentDirectory "IntuneAssignmentChecker_v2.7.ps1"
}

# Flag to control auto-update behavior
$autoUpdate = $false  # Set to $false to disable auto-update

try {
    # Fetch the latest version number from GitHub
    $latestVersion = Invoke-RestMethod -Uri $versionUrl
    
    # Compare versions using System.Version for proper semantic versioning
    $local = [System.Version]::new($localVersion)
    $latest = [System.Version]::new($latestVersion)
    
    if ($local -lt $latest) {
        Write-Host "A new version is available: $latestVersion (you are running $localVersion)" -ForegroundColor Yellow
        if ($autoUpdate) {
            Write-Host "AutoUpdate is enabled. Downloading the latest version..." -ForegroundColor Yellow
            try {
                # Download the latest version of the script
                Invoke-WebRequest -Uri $scriptUrl -OutFile $newScriptPath
                Write-Host "The latest version has been downloaded to $newScriptPath" -ForegroundColor Yellow
                Write-Host "Please restart the script to use the updated version." -ForegroundColor Yellow
            }
            catch {
                Write-Host "An error occurred while downloading the latest version. Please download it manually from: https://github.com/ugurkocde/IntuneAssignmentChecker" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Auto-update is disabled. Get the latest version at:" -ForegroundColor Yellow
            Write-Host "https://github.com/ugurkocde/IntuneAssignmentChecker" -ForegroundColor Cyan
            Write-Host "" 
        }
    }
    elseif ($local -gt $latest) {
        Write-Host "Note: You are running a pre-release version ($localVersion)" -ForegroundColor Magenta
        Write-Host ""
    }
}
catch {
    Write-Host "Unable to check for updates. Continue with current version..." -ForegroundColor Gray
}

####################################################################################################

# Do not change the following code

# Connect to Microsoft Graph using certificate-based authentication
try {
    # Define required permissions with reasons
    $requiredPermissions = @(
        @{
            Permission = "User.Read.All"
            Reason     = "Required to read user profile information and check group memberships"
        },
        @{
            Permission = "Group.Read.All"
            Reason     = "Needed to read group information and memberships"
        },
        @{
            Permission = "DeviceManagementConfiguration.Read.All"
            Reason     = "Allows reading Intune device configuration policies and their assignments"
        },
        @{
            Permission = "DeviceManagementApps.Read.All"
            Reason     = "Necessary to read mobile app management policies and app configurations"
        },
        @{
            Permission = "DeviceManagementManagedDevices.Read.All"
            Reason     = "Required to read managed device information and compliance policies"
        },
        @{
            Permission = "Device.Read.All"
            Reason     = "Needed to read device information from Entra ID"
        }
    )

    # Check if any of the variables are not set or contain placeholder values
    if (-not $appid -or $appid -eq '<YourAppIdHere>' -or
        -not $tenantid -or $tenantid -eq '<YourTenantIdHere>' -or
        -not $certThumbprint -or $certThumbprint -eq '<YourCertificateThumbprintHere>') {
        Write-Host "App ID, Tenant ID, or Certificate Thumbprint is missing or not set correctly." -ForegroundColor Red
        $manualConnection = Read-Host "Would you like to attempt a manual interactive connection? (y/n)"
        if ($manualConnection -eq 'y') {
            # Manual connection using interactive login
            write-host "Attempting manual interactive connection (you need privileges to consent permissions)..." -ForegroundColor Yellow
            $permissionsList = ($requiredPermissions | ForEach-Object { $_.Permission }) -join ', '
            $connectionResult = Connect-MgGraph -Scopes $permissionsList -NoWelcome -ErrorAction Stop
        }
        else {
            Write-Host "Script execution cancelled by user." -ForegroundColor Red
            exit
        }
    }
    else {
        $connectionResult = Connect-MgGraph -ClientId $appid -TenantId $tenantid -CertificateThumbprint $certThumbprint -NoWelcome -ErrorAction Stop
    }
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green

    # Check and display the current permissions
    $context = Get-MgContext
    $currentPermissions = $context.Scopes

    Write-Host "Checking required permissions:" -ForegroundColor Cyan
    $missingPermissions = @()
    foreach ($permissionInfo in $requiredPermissions) {
        $permission = $permissionInfo.Permission
        $reason = $permissionInfo.Reason

        # Check if either the exact permission or a "ReadWrite" version of it is granted
        $hasPermission = $currentPermissions -contains $permission -or $currentPermissions -contains $permission.Replace(".Read", ".ReadWrite")

        if ($hasPermission) {
            Write-Host "  [✓] $permission" -ForegroundColor Green
            Write-Host "      Reason: $reason" -ForegroundColor Gray
        }
        else {
            Write-Host "  [✗] $permission" -ForegroundColor Red
            Write-Host "      Reason: $reason" -ForegroundColor Gray
            $missingPermissions += $permission
        }
    }

    if ($missingPermissions.Count -eq 0) {
        Write-Host "All required permissions are present." -ForegroundColor Green
        Write-Host ""
    }
    else {
        Write-Host "WARNING: The following permissions are missing:" -ForegroundColor Red
        $missingPermissions | ForEach-Object { 
            $missingPermission = $_
            $reason = ($requiredPermissions | Where-Object { $_.Permission -eq $missingPermission }).Reason
            Write-Host "  - $missingPermission" -ForegroundColor Yellow
            Write-Host "    Reason: $reason" -ForegroundColor Gray
        }
        Write-Host "The script will continue, but it may not function correctly without these permissions." -ForegroundColor Red
        Write-Host "Please ensure these permissions are granted to the app registration for full functionality." -ForegroundColor Yellow
        
        $continueChoice = Read-Host "Do you want to continue anyway? (y/n)"
        if ($continueChoice -ne 'y') {
            Write-Host "Script execution cancelled by user." -ForegroundColor Red
            exit
        }
    }
}
catch {
    Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
    
    # Additional error handling for certificate issues
    if ($_.Exception.Message -like "*Certificate with thumbprint*was not found*") {
        Write-Host "The specified certificate was not found or has expired. Please check your certificate configuration." -ForegroundColor Yellow
    }
    
    exit
}

# Common Functions
function Get-IntuneAssignments {
    param (
        [Parameter(Mandatory = $true)]
        [string]$EntityType,
        
        [Parameter(Mandatory = $true)]
        [string]$EntityId,
        
        [Parameter(Mandatory = $false)]
        [string]$GroupId = $null
    )

    # Handle special cases for App Protection Policies
    $assignmentsUri = if ($EntityType -like "deviceAppManagement/*") {
        # For App Protection Policies, we need to use the specific endpoints
        "https://graph.microsoft.com/beta/deviceAppManagement/managedAppPolicies/$EntityId/assignments"
    } else {
        "https://graph.microsoft.com/beta/deviceManagement/$EntityType('$EntityId')/assignments"
    }
    # For App Protection Policies that use $expand, the response structure is different
    $isAppProtectionPolicy = $EntityType -like "deviceAppManagement/*" -and ($EntityType -like "*ManagedAppProtections")
    
    if ($isAppProtectionPolicy) {
        $policyDetails = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get
        $assignments = @()
        
        foreach ($assignment in $policyDetails.assignments) {
            $assignmentReason = $null
            
            switch ($assignment.target.'@odata.type') {
                '#microsoft.graph.allLicensedUsersAssignmentTarget' { 
                    $assignmentReason = "All Users"
                }
                '#microsoft.graph.groupAssignmentTarget' {
                                    if ($assignment.target.groupId -eq $groupId) {
                                        $assignmentReason = "Direct Assignment"
                                    } elseif (!$GroupId -or $assignment.target.groupId -eq $GroupId) {
                                        $assignmentReason = "Group Assignment"
                                    }
                }
            }

            if ($assignmentReason) {
                $assignments += @{
                    Reason = $assignmentReason
                    GroupId = $assignment.target.groupId
                    Apps = $policyDetails.apps
                }
            }
        }
    }
    else {
        $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get
        $assignments = @()

        $assignmentList = if ($EntityType -like "deviceAppManagement/*") { $assignmentResponse } else { $assignmentResponse.value }
        
        foreach ($assignment in $assignmentList) {
        $assignmentReason = $null
        
        switch ($assignment.target.'@odata.type') {
            '#microsoft.graph.allLicensedUsersAssignmentTarget' { 
                $assignmentReason = "All Users"
            }
            '#microsoft.graph.allDevicesAssignmentTarget' { 
                $assignmentReason = "All Devices"
            }
            '#microsoft.graph.groupAssignmentTarget' {
                if (!$GroupId -or $assignment.target.groupId -eq $GroupId) {
                    $assignmentReason = "Group Assignment"
                }
            }
        }

        if ($assignmentReason) {
            $assignments += @{
                Reason = $assignmentReason
                GroupId = $assignment.target.groupId
                Apps = if ($isAppProtectionPolicy) { $policyDetails.apps } else { $null }
            }
        }
    }
}

    return $assignments
}

function Get-IntuneEntities {
    param (
        [Parameter(Mandatory = $true)]
        [string]$EntityType,
        
        [Parameter(Mandatory = $false)]
        [string]$Filter = "",
        
        [Parameter(Mandatory = $false)]
        [string]$Select = "",
        
        [Parameter(Mandatory = $false)]
        [string]$Expand = ""
    )

    # Handle special cases for app management endpoints
    $baseUri = if ($EntityType -like "deviceAppManagement/*") {
        "https://graph.microsoft.com/beta"
    } else {
        "https://graph.microsoft.com/beta/deviceManagement"
    }
    
    # Extract the actual entity type from full path if needed
    $actualEntityType = if ($EntityType -like "deviceAppManagement/*") {
        $EntityType
    } else {
        "$EntityType"
    }
    
    $uri = "$baseUri/$actualEntityType"
    if ($Filter) { $uri += "?`$filter=$Filter" }
    if ($Select) { $uri += $(if($Filter){"&"}else{"?"}) + "`$select=$Select" }
    if ($Expand) { $uri += $(if($Filter -or $Select){"&"}else{"?"}) + "`$expand=$Expand" }

    $response = Invoke-MgGraphRequest -Uri $uri -Method Get
    $entities = $response.value

    while ($response.'@odata.nextLink') {
        $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method Get
        $entities += $response.value
    }

    return $entities
}

function Get-GroupInfo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )

    try {
        $groupUri = "https://graph.microsoft.com/v1.0/groups/$GroupId"
        $group = Invoke-MgGraphRequest -Uri $groupUri -Method Get
        return @{
            Id = $group.id
            DisplayName = $group.displayName
            Success = $true
        }
    }
    catch {
        return @{
            Id = $GroupId
            DisplayName = "Unknown Group"
            Success = $false
        }
    }
}

function Get-DeviceInfo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DeviceName
    )

    $deviceUri = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$DeviceName'"
    $deviceResponse = Invoke-MgGraphRequest -Uri $deviceUri -Method Get
    
    if ($deviceResponse.value) {
        return @{
            Id = $deviceResponse.value[0].id
            DisplayName = $deviceResponse.value[0].displayName
            Success = $true
        }
    }
    
    return @{
        Id = $null
        DisplayName = $DeviceName
        Success = $false
    }
}

function Get-UserInfo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )

    try {
        $userUri = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName"
        $user = Invoke-MgGraphRequest -Uri $userUri -Method Get
        return @{
            Id = $user.id
            UserPrincipalName = $user.userPrincipalName
            Success = $true
        }
    }
    catch {
        return @{
            Id = $null
            UserPrincipalName = $UserPrincipalName
            Success = $false
        }
    }
}

function Get-GroupMemberships {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ObjectId,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("User", "Device")]
        [string]$ObjectType
    )

    $uri = "https://graph.microsoft.com/v1.0/$($ObjectType.ToLower())s/$ObjectId/transitiveMemberOf?`$select=id,displayName"
    $response = Invoke-MgGraphRequest -Uri $uri -Method Get
    
    return $response.value
}

function Show-SaveFileDialog {
    param (
        [string]$DefaultFileName
    )
    
    Add-Type -AssemblyName System.Windows.Forms
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "Excel files (*.xlsx)|*.xlsx|CSV files (*.csv)|*.csv|All files (*.*)|*.*"
    $saveFileDialog.FileName = $DefaultFileName
    $saveFileDialog.Title = "Save Policy Report"
    
    if ($saveFileDialog.ShowDialog() -eq 'OK') {
        return $saveFileDialog.FileName
    }
    return $null
}

function Export-PolicyData {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]$ExportData,
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    if ($extension -eq '.xlsx') {
        # Check if ImportExcel module is installed
        if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
            Write-Host "The ImportExcel module is required for Excel export. Would you like to install it? (y/n)" -ForegroundColor Yellow
            $install = Read-Host
            if ($install -eq 'y') {
                try {
                    Install-Module -Name ImportExcel -Force -Scope CurrentUser
                    Write-Host "ImportExcel module installed successfully." -ForegroundColor Green
                }
                catch {
                    Write-Host "Failed to install ImportExcel module. Falling back to CSV export." -ForegroundColor Red
                    $FilePath = [System.IO.Path]::ChangeExtension($FilePath, '.csv')
                    $ExportData | Export-Csv -Path $FilePath -NoTypeInformation
                    Write-Host "Results exported to $FilePath" -ForegroundColor Green
                    return
                }
            }
            else {
                Write-Host "Falling back to CSV export." -ForegroundColor Yellow
                $FilePath = [System.IO.Path]::ChangeExtension($FilePath, '.csv')
                $ExportData | Export-Csv -Path $FilePath -NoTypeInformation
                Write-Host "Results exported to $FilePath" -ForegroundColor Green
                return
            }
        }

        try {
            $ExportData | Export-Excel -Path $FilePath -AutoSize -AutoFilter -WorksheetName "Intune Assignments" -TableName "IntuneAssignments"
            Write-Host "Results exported to $FilePath" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to export to Excel. Falling back to CSV export." -ForegroundColor Red
            $FilePath = [System.IO.Path]::ChangeExtension($FilePath, '.csv')
            $ExportData | Export-Csv -Path $FilePath -NoTypeInformation
            Write-Host "Results exported to $FilePath" -ForegroundColor Green
        }
    }
    else {
        $ExportData | Export-Csv -Path $FilePath -NoTypeInformation
        Write-Host "Results exported to $FilePath" -ForegroundColor Green
    }
}

function Add-ExportData {
    param (
        [System.Collections.ArrayList]$ExportData,
        [string]$Category,
        [object[]]$Items,
        [Parameter(Mandatory = $false)]
        [object]$AssignmentReason = "N/A"
    )
    
    foreach ($item in $Items) {
        $itemName = if ($item.displayName) { $item.displayName } else { $item.name }
        
        # Handle different types of assignment reason input
        $reason = if ($AssignmentReason -is [scriptblock]) {
            & $AssignmentReason $item
        }
        elseif ($item.AssignmentReason) {
            $item.AssignmentReason
        }
        elseif ($item.AssignmentSummary) {
            $item.AssignmentSummary
        }
        else {
            $AssignmentReason
        }
        
        $null = $ExportData.Add([PSCustomObject]@{
            Category = $Category
            Item = "$itemName (ID: $($item.id))"
            AssignmentReason = $reason
        })
    }
}

function Add-AppExportData {
    param (
        [System.Collections.ArrayList]$ExportData,
        [string]$Category,
        [object[]]$Apps,
        [string]$AssignmentReason = "N/A"
    )
    
    foreach ($app in $Apps) {
        $appName = if ($app.displayName) { $app.displayName } else { $app.name }
        $null = $ExportData.Add([PSCustomObject]@{
            Category = $Category
            Item = "$appName (ID: $($app.id))"
            AssignmentReason = "$AssignmentReason - $($app.AssignmentIntent)"
        })
    }
}

function Show-Menu {    
    Write-Host "Assignment Checks:" -ForegroundColor Cyan
    Write-Host "  [1] Check User(s) Assignments" -ForegroundColor White
    Write-Host "  [2] Check Group(s) Assignments" -ForegroundColor White
    Write-Host "  [3] Check Device(s) Assignments" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Policy Overview:" -ForegroundColor Cyan
    Write-Host "  [4] Show All Policies and Their Assignments" -ForegroundColor White
    Write-Host "  [5] Show All 'All Users' Assignments" -ForegroundColor White
    Write-Host "  [6] Show All 'All Devices' Assignments" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Advanced Options:" -ForegroundColor Cyan
    Write-Host "  [7] Search for Assignments by Setting Name" -ForegroundColor White
    Write-Host "  [8] Show Policies Without Assignments" -ForegroundColor White
    Write-Host "  [9] Check for Empty Groups in Assignments" -ForegroundColor White
    Write-Host "  [10] Show all Administrative Templates (deprecates in December 2024)" -ForegroundColor Yellow
    Write-Host "  [11] Compare Assignments Between Groups" -ForegroundColor White
    Write-Host ""
    
    Write-Host "System:" -ForegroundColor Cyan
    Write-Host "  [0] Exit" -ForegroundColor White
    Write-Host "  [98] Support the Project 💝" -ForegroundColor Magenta
    Write-Host "  [99] Report a Bug or Request a Feature" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Select an option: " -ForegroundColor Yellow -NoNewline
}

# Main script logic
do {
    Show-Menu
    $selection = Read-Host

    switch ($selection) {
        '1' {
            Write-Host "User selection chosen" -ForegroundColor Green

            # Prompt for one or more User Principal Names
            Write-Host "Please enter User Principal Name(s), separated by commas (,): " -ForegroundColor Cyan
            $upnInput = Read-Host
    
            # Validate input
            if ([string]::IsNullOrWhiteSpace($upnInput)) {
                Write-Host "No UPN provided. Please try again with a valid UPN." -ForegroundColor Red
                continue
            }
    
            $upns = $upnInput -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    
            if ($upns.Count -eq 0) {
                Write-Host "No valid UPNs provided. Please try again with at least one valid UPN." -ForegroundColor Red
                continue
            }

            $exportData = [System.Collections.ArrayList]::new()

            foreach ($upn in $upns) {
                Write-Host "Checking following UPN: $upn" -ForegroundColor Yellow

                # Get User Info
                $userInfo = Get-UserInfo -UserPrincipalName $upn
                if (-not $userInfo.Success) {
                    Write-Host "User not found: $upn" -ForegroundColor Red
                    Write-Host "Please verify the User Principal Name is correct." -ForegroundColor Yellow
                    continue
                }

                # Get User Group Memberships
                try {
                    $groupMemberships = Get-GroupMemberships -ObjectId $userInfo.Id -ObjectType "User"
                    Write-Host "User Group Memberships: $($groupMemberships.displayName -join ', ')" -ForegroundColor Green
                }
                catch {
                    Write-Host "Error fetching group memberships for user: $upn" -ForegroundColor Red
                    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
                    continue
                }

                Write-Host "Fetching Intune Profiles and Applications for the user ... (this takes a few seconds)" -ForegroundColor Yellow

                # Initialize collections for relevant policies
                $relevantPolicies = @{
                    DeviceConfigs = @()
                    SettingsCatalog = @()
                    AdminTemplates = @()
                    CompliancePolicies = @()
                    AppProtectionPolicies = @()
                    AppConfigurationPolicies = @()
                    AppsRequired = @()
                    AppsAvailable = @()
                    AppsUninstall = @()
                    PlatformScripts = @()
                    HealthScripts = @()
                }

                # Get Device Configurations
                Write-Host "Fetching Device Configurations..." -ForegroundColor Yellow
                $deviceConfigs = Get-IntuneEntities -EntityType "deviceConfigurations"
                foreach ($config in $deviceConfigs) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceConfigurations" -EntityId $config.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $config | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.DeviceConfigs += $config
                            break
                        }
                    }
                }

                # Get Settings Catalog Policies
                Write-Host "Fetching Settings Catalog Policies..." -ForegroundColor Yellow
                $settingsCatalog = Get-IntuneEntities -EntityType "configurationPolicies"
                foreach ($policy in $settingsCatalog) {
                    $assignments = Get-IntuneAssignments -EntityType "configurationPolicies" -EntityId $policy.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.SettingsCatalog += $policy
                            break
                        }
                    }
                }

                # Get Administrative Templates
                Write-Host "Fetching Administrative Templates..." -ForegroundColor Yellow
                $adminTemplates = Get-IntuneEntities -EntityType "groupPolicyConfigurations"
                foreach ($template in $adminTemplates) {
                    $assignments = Get-IntuneAssignments -EntityType "groupPolicyConfigurations" -EntityId $template.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $template | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.AdminTemplates += $template
                            break
                        }
                    }
                }

                # Get Compliance Policies
                Write-Host "Fetching Compliance Policies..." -ForegroundColor Yellow
                $compliancePolicies = Get-IntuneEntities -EntityType "deviceCompliancePolicies"
                foreach ($policy in $compliancePolicies) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceCompliancePolicies" -EntityId $policy.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.CompliancePolicies += $policy
                            break
                        }
                    }
                }

                # Get App Protection Policies
                Write-Host "Fetching App Protection Policies..." -ForegroundColor Yellow
                $appProtectionPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/managedAppPolicies"
                foreach ($policy in $appProtectionPolicies) {
                    $policyType = $policy.'@odata.type'
                    $assignmentsUri = switch ($policyType) {
                        "#microsoft.graph.androidManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($policy.id)')/assignments" }
                        "#microsoft.graph.iosManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($policy.id)')/assignments" }
                        "#microsoft.graph.windowsManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections('$($policy.id)')/assignments" }
                        default { $null }
                    }

                    if ($assignmentsUri) {
                        try {
                            $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get
                            $assignments = @()
                            foreach ($assignment in $assignmentResponse.value) {
                                $assignmentReason = $null
                                switch ($assignment.target.'@odata.type') {
                                    '#microsoft.graph.allLicensedUsersAssignmentTarget' { 
                                        $assignmentReason = "All Users"
                                    }
                                    '#microsoft.graph.groupAssignmentTarget' {
                                        if (!$GroupId -or $assignment.target.groupId -eq $GroupId) {
                                            $assignmentReason = "Group Assignment"
                                        }
                                    }
                                }

                                if ($assignmentReason) {
                                    $assignments += @{
                                        Reason = $assignmentReason
                                        GroupId = $assignment.target.groupId
                                    }
                                }
                            }

                            if ($assignments.Count -gt 0) {
                                $assignmentSummary = $assignments | ForEach-Object {
                                    if ($_.Reason -eq "Group Assignment") {
                                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                                        "$($_.Reason) - $($groupInfo.DisplayName)"
                                    }
                                    else {
                                        $_.Reason
                                    }
                                }
                                $policy | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                                $relevantPolicies.AppProtectionPolicies += $policy
                            }
                        }
                        catch {
                            Write-Host "Error fetching assignments for policy $($policy.displayName): $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }

                # Get App Configuration Policies
                Write-Host "Fetching App Configuration Policies..." -ForegroundColor Yellow
                $appConfigPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/mobileAppConfigurations"
                foreach ($policy in $appConfigPolicies) {
                    $assignments = Get-IntuneAssignments -EntityType "mobileAppConfigurations" -EntityId $policy.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.AppConfigurationPolicies += $policy
                            break
                        }
                    }
                }

                # Get Platform Scripts
                Write-Host "Fetching Platform Scripts..." -ForegroundColor Yellow
                $platformScripts = Get-IntuneEntities -EntityType "deviceManagementScripts"
                foreach ($script in $platformScripts) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceManagementScripts" -EntityId $script.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.PlatformScripts += $script
                            break
                        }
                    }
                }

                # Get Proactive Remediation Scripts
                Write-Host "Fetching Proactive Remediation Scripts..." -ForegroundColor Yellow
                $healthScripts = Get-IntuneEntities -EntityType "deviceHealthScripts"
                foreach ($script in $healthScripts) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceHealthScripts" -EntityId $script.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.HealthScripts += $script
                            break
                        }
                    }
                }

                # Display results
                Write-Host "`nAssignments for User: $upn" -ForegroundColor Green

                # Display Device Configurations
                Write-Host "`n------- Device Configurations -------" -ForegroundColor Cyan
                foreach ($config in $relevantPolicies.DeviceConfigs) {
                    $configName = if ([string]::IsNullOrWhiteSpace($config.name)) { $config.displayName } else { $config.name }
                    $assignmentInfo = if ($config.AssignmentReason) { ", Assignment Reason: $($config.AssignmentReason)" } else { "" }
                    Write-Host "Device Configuration Name: $configName, Configuration ID: $($config.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Settings Catalog Policies
                Write-Host "`n------- Settings Catalog Policies -------" -ForegroundColor Cyan
                foreach ($policy in $relevantPolicies.SettingsCatalog) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    $assignmentInfo = if ($policy.AssignmentReason) { ", Assignment Reason: $($policy.AssignmentReason)" } else { "" }
                    Write-Host "Settings Catalog Policy Name: $policyName, Policy ID: $($policy.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Administrative Templates
                Write-Host "`n------- Administrative Templates -------" -ForegroundColor Cyan
                foreach ($template in $relevantPolicies.AdminTemplates) {
                    $templateName = if ([string]::IsNullOrWhiteSpace($template.name)) { $template.displayName } else { $template.name }
                    $assignmentInfo = if ($template.AssignmentReason) { ", Assignment Reason: $($template.AssignmentReason)" } else { "" }
                    Write-Host "Administrative Template Name: $templateName, Template ID: $($template.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Compliance Policies
                Write-Host "`n------- Compliance Policies -------" -ForegroundColor Cyan
                foreach ($policy in $relevantPolicies.CompliancePolicies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    $assignmentInfo = if ($policy.AssignmentReason) { ", Assignment Reason: $($policy.AssignmentReason)" } else { "" }
                    Write-Host "Compliance Policy Name: $policyName, Policy ID: $($policy.id)$assignmentInfo" -ForegroundColor White
                }

                # Display App Protection Policies
                Write-Host "`n------- App Protection Policies -------" -ForegroundColor Cyan
                foreach ($policy in $relevantPolicies.AppProtectionPolicies) {
                    $policyName = $policy.displayName
                    $policyId = $policy.id
                    $policyType = switch ($policy.'@odata.type') {
                        "#microsoft.graph.androidManagedAppProtection" { "Android" }
                        "#microsoft.graph.iosManagedAppProtection" { "iOS" }
                        "#microsoft.graph.windowsManagedAppProtection" { "Windows" }
                        default { "Unknown" }
                    }
                    $assignmentInfo = if ($policy.AssignmentReason) { ", Assignment Reason: $($policy.AssignmentReason)" } else { "" }
                    Write-Host "App Protection Policy Name: $policyName, Policy ID: $policyId, Type: $policyType$assignmentInfo" -ForegroundColor White
                }

                # Display App Configuration Policies
                Write-Host "`n------- App Configuration Policies -------" -ForegroundColor Cyan
                foreach ($policy in $relevantPolicies.AppConfigurationPolicies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    $assignmentInfo = if ($policy.AssignmentReason) { ", Assignment Reason: $($policy.AssignmentReason)" } else { "" }
                    Write-Host "App Configuration Policy Name: $policyName, Policy ID: $($policy.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Platform Scripts
                Write-Host "`n------- Platform Scripts -------" -ForegroundColor Cyan
                foreach ($script in $relevantPolicies.PlatformScripts) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    $assignmentInfo = if ($script.AssignmentReason) { ", Assignment Reason: $($script.AssignmentReason)" } else { "" }
                    Write-Host "Script Name: $scriptName, Script ID: $($script.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Proactive Remediation Scripts
                Write-Host "`n------- Proactive Remediation Scripts -------" -ForegroundColor Cyan
                foreach ($script in $relevantPolicies.HealthScripts) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    $assignmentInfo = if ($script.AssignmentReason) { ", Assignment Reason: $($script.AssignmentReason)" } else { "" }
                    Write-Host "Script Name: $scriptName, Script ID: $($script.id)$assignmentInfo" -ForegroundColor White
                }

                # Add all data to export
                Add-ExportData -ExportData $exportData -Category "User" -Items @([PSCustomObject]@{
                    displayName = $upn
                    id = $userInfo.Id
                    AssignmentReason = "N/A"
                })

                Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items $relevantPolicies.DeviceConfigs -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Settings Catalog Policy" -Items $relevantPolicies.SettingsCatalog -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Administrative Template" -Items $relevantPolicies.AdminTemplates -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Compliance Policy" -Items $relevantPolicies.CompliancePolicies -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "App Protection Policy" -Items $relevantPolicies.AppProtectionPolicies -AssignmentReason { param($item) $item.AssignmentSummary }
                Add-ExportData -ExportData $exportData -Category "App Configuration Policy" -Items $relevantPolicies.AppConfigurationPolicies -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Platform Scripts" -Items $relevantPolicies.PlatformScripts -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Proactive Remediation Scripts" -Items $relevantPolicies.HealthScripts -AssignmentReason { param($item) $item.AssignmentReason }

                # Offer to export results
                $export = Read-Host "`nWould you like to export the results to CSV? (y/n)"
                if ($export -eq 'y') {
                    $exportPath = Show-SaveFileDialog -DefaultFileName "IntuneUserAssignments.csv"
                    if ($exportPath) {
                        $exportData | Export-Csv -Path $exportPath -NoTypeInformation
                        Write-Host "Results exported to $exportPath" -ForegroundColor Green
                    }
                }
            }
        }
        '2' {
            Write-Host "Group selection chosen" -ForegroundColor Green

            # Prompt for Group names or IDs
            Write-Host "Please enter Group names or Object IDs, separated by commas (,): " -ForegroundColor Cyan
            Write-Host "Example: 'Marketing Team, 12345678-1234-1234-1234-123456789012'" -ForegroundColor Gray
            $groupInput = Read-Host

            if ([string]::IsNullOrWhiteSpace($groupInput)) {
                Write-Host "No group information provided. Please try again." -ForegroundColor Red
                continue
            }

            $groupInputs = $groupInput -split ',' | ForEach-Object { $_.Trim() }
            $exportData = [System.Collections.ArrayList]::new()

            foreach ($input in $groupInputs) {
                Write-Host "`nProcessing input: $input" -ForegroundColor Yellow

                # Initialize variables
                $groupId = $null
                $groupName = $null

                # Check if input is a GUID
                if ($input -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
                    $groupInfo = Get-GroupInfo -GroupId $input
                    if (-not $groupInfo.Success) {
                        Write-Host "No group found with ID: $input" -ForegroundColor Red
                        continue
                    }
                    $groupId = $groupInfo.Id
                    $groupName = $groupInfo.DisplayName
                }
                else {
                    # Try to find group by display name
                    $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$input'"
                    $groupResponse = Invoke-MgGraphRequest -Uri $groupUri -Method Get

                    if ($groupResponse.value.Count -eq 0) {
                        Write-Host "No group found with name: $input" -ForegroundColor Red
                        continue
                    }
                    elseif ($groupResponse.value.Count -gt 1) {
                        Write-Host "Multiple groups found with name: $input. Please use the Object ID instead:" -ForegroundColor Red
                        foreach ($group in $groupResponse.value) {
                            Write-Host "  - $($group.displayName) (ID: $($group.id))" -ForegroundColor Yellow
                        }
                        continue
                    }

                    $groupId = $groupResponse.value[0].id
                    $groupName = $groupResponse.value[0].displayName
                }

                Write-Host "Found group: $groupName (ID: $groupId)" -ForegroundColor Green
                Write-Host "Fetching Intune Profiles and Applications for the group ... (this takes a few seconds)" -ForegroundColor Yellow

                # Initialize collections for relevant policies
                $relevantPolicies = @{
                    DeviceConfigs = @()
                    SettingsCatalog = @()
                    AdminTemplates = @()
                    CompliancePolicies = @()
                    AppProtectionPolicies = @()
                    AppConfigurationPolicies = @()
                    AppsRequired = @()
                    AppsAvailable = @()
                    AppsUninstall = @()
                    PlatformScripts = @()
                    HealthScripts = @()
                }

                # Get Device Configurations
                Write-Host "Fetching Device Configurations..." -ForegroundColor Yellow
                $deviceConfigs = Get-IntuneEntities -EntityType "deviceConfigurations"
                foreach ($config in $deviceConfigs) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceConfigurations" -EntityId $config.id -GroupId $groupId
                    if ($assignments) {
                        $assignmentReason = if ($assignments[0].Reason -eq "Group Assignment") {
                            if ($assignments[0].GroupId -eq $groupId) {
                                "Direct Assignment"
                            } else {
                                $groupInfo = Get-GroupInfo -GroupId $assignments[0].GroupId
                                "$($assignments[0].Reason) - $($groupInfo.DisplayName)"
                            }
                        } else {
                            $assignments[0].Reason
                        }
                        $config | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                        $relevantPolicies.DeviceConfigs += $config
                    }
                }

                # Get Settings Catalog Policies
                Write-Host "Fetching Settings Catalog Policies..." -ForegroundColor Yellow
                $settingsCatalog = Get-IntuneEntities -EntityType "configurationPolicies"
                foreach ($policy in $settingsCatalog) {
                    $assignments = Get-IntuneAssignments -EntityType "configurationPolicies" -EntityId $policy.id -GroupId $groupId
                    if ($assignments) {
                        $assignmentReason = if ($assignments[0].Reason -eq "Group Assignment") {
                            if ($assignments[0].GroupId -eq $groupId) {
                                "Direct Assignment"
                            } else {
                                $groupInfo = Get-GroupInfo -GroupId $assignments[0].GroupId
                                "$($assignments[0].Reason) - $($groupInfo.DisplayName)"
                            }
                        } else {
                            $assignments[0].Reason
                        }
                        $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                        $relevantPolicies.SettingsCatalog += $policy
                    }
                }

                # Get Administrative Templates
                Write-Host "Fetching Administrative Templates..." -ForegroundColor Yellow
                $adminTemplates = Get-IntuneEntities -EntityType "groupPolicyConfigurations"
                foreach ($template in $adminTemplates) {
                    $assignments = Get-IntuneAssignments -EntityType "groupPolicyConfigurations" -EntityId $template.id -GroupId $groupId
                    if ($assignments) {
                        $assignmentReason = if ($assignments[0].Reason -eq "Group Assignment") {
                            if ($assignments[0].GroupId -eq $groupId) {
                                "Direct Assignment"
                            } else {
                                $groupInfo = Get-GroupInfo -GroupId $assignments[0].GroupId
                                "$($assignments[0].Reason) - $($groupInfo.DisplayName)"
                            }
                        } else {
                            $assignments[0].Reason
                        }
                        $template | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                        $relevantPolicies.AdminTemplates += $template
                    }
                }

                # Get Compliance Policies
                Write-Host "Fetching Compliance Policies..." -ForegroundColor Yellow
                $compliancePolicies = Get-IntuneEntities -EntityType "deviceCompliancePolicies"
                foreach ($policy in $compliancePolicies) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceCompliancePolicies" -EntityId $policy.id -GroupId $groupId
                    if ($assignments) {
                        $assignmentReason = if ($assignments[0].Reason -eq "Group Assignment") {
                            if ($assignments[0].GroupId -eq $groupId) {
                                "Direct Assignment"
                            } else {
                                $groupInfo = Get-GroupInfo -GroupId $assignments[0].GroupId
                                "$($assignments[0].Reason) - $($groupInfo.DisplayName)"
                            }
                        } else {
                            $assignments[0].Reason
                        }
                        $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                        $relevantPolicies.CompliancePolicies += $policy
                    }
                }

                # Get App Protection Policies
                Write-Host "Fetching App Protection Policies..." -ForegroundColor Yellow
                $appProtectionPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/managedAppPolicies"
                foreach ($policy in $appProtectionPolicies) {
                    $policyType = $policy.'@odata.type'
                    $assignmentsUri = switch ($policyType) {
                        "#microsoft.graph.androidManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($policy.id)')/assignments" }
                        "#microsoft.graph.iosManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($policy.id)')/assignments" }
                        "#microsoft.graph.windowsManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections('$($policy.id)')/assignments" }
                        default { $null }
                    }

                    if ($assignmentsUri) {
                        try {
                            $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get
                            $assignments = @()
                            foreach ($assignment in $assignmentResponse.value) {
                                $assignmentReason = $null
                                switch ($assignment.target.'@odata.type') {
                                    '#microsoft.graph.allLicensedUsersAssignmentTarget' { 
                                        $assignmentReason = "All Users"
                                    }
                                    '#microsoft.graph.groupAssignmentTarget' {
                                        if (!$GroupId -or $assignment.target.groupId -eq $GroupId) {
                                            $assignmentReason = "Group Assignment"
                                        }
                                    }
                                }

                                if ($assignmentReason) {
                                    $assignments += @{
                                        Reason = $assignmentReason
                                        GroupId = $assignment.target.groupId
                                    }
                                }
                            }

                            if ($assignments.Count -gt 0) {
                                $assignmentSummary = $assignments | ForEach-Object {
                                    if ($_.Reason -eq "Group Assignment") {
                                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                                        "$($_.Reason) - $($groupInfo.DisplayName)"
                                    }
                                    else {
                                        $_.Reason
                                    }
                                }
                                $policy | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                                $relevantPolicies.AppProtectionPolicies += $policy
                            }
                        }
                        catch {
                            Write-Host "Error fetching assignments for policy $($policy.displayName): $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }

                # Get App Configuration Policies
                Write-Host "Fetching App Configuration Policies..." -ForegroundColor Yellow
                $appConfigPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/mobileAppConfigurations"
                foreach ($policy in $appConfigPolicies) {
                    $assignments = Get-IntuneAssignments -EntityType "mobileAppConfigurations" -EntityId $policy.id -GroupId $groupId
                    if ($assignments) {
                        $assignmentReason = if ($assignments[0].Reason -eq "Group Assignment") {
                            if ($assignments[0].GroupId -eq $groupId) {
                                "Direct Assignment"
                            } else {
                                $groupInfo = Get-GroupInfo -GroupId $assignments[0].GroupId
                                "$($assignments[0].Reason) - $($groupInfo.DisplayName)"
                            }
                        } else {
                            $assignments[0].Reason
                        }
                        $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                        $relevantPolicies.AppConfigurationPolicies += $policy
                    }
                }

                # Get Platform Scripts
                Write-Host "Fetching Platform Scripts..." -ForegroundColor Yellow
                $platformScripts = Get-IntuneEntities -EntityType "deviceManagementScripts"
                foreach ($script in $platformScripts) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceManagementScripts" -EntityId $script.id -GroupId $groupId
                    if ($assignments) {
                        $assignmentReason = if ($assignments[0].Reason -eq "Group Assignment") {
                            if ($assignments[0].GroupId -eq $groupId) {
                                "Direct Assignment"
                            } else {
                                $groupInfo = Get-GroupInfo -GroupId $assignments[0].GroupId
                                "$($assignments[0].Reason) - $($groupInfo.DisplayName)"
                            }
                        } else {
                            $assignments[0].Reason
                        }
                        $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                        $relevantPolicies.PlatformScripts += $script
                    }
                }

                # Get Proactive Remediation Scripts
                Write-Host "Fetching Proactive Remediation Scripts..." -ForegroundColor Yellow
                $healthScripts = Get-IntuneEntities -EntityType "deviceHealthScripts"
                foreach ($script in $healthScripts) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceHealthScripts" -EntityId $script.id -GroupId $groupId
                    if ($assignments) {
                        $assignmentReason = if ($assignments[0].Reason -eq "Group Assignment") {
                            if ($assignments[0].GroupId -eq $groupId) {
                                "Direct Assignment"
                            } else {
                                $groupInfo = Get-GroupInfo -GroupId $assignments[0].GroupId
                                "$($assignments[0].Reason) - $($groupInfo.DisplayName)"
                            }
                        } else {
                            $assignments[0].Reason
                        }
                        $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignmentReason -Force
                        $relevantPolicies.HealthScripts += $script
                    }
                }

                # Display results
                Write-Host "`nAssignments for Group: $groupName" -ForegroundColor Green

                # Display Device Configurations
                Write-Host "`n------- Device Configurations -------" -ForegroundColor Cyan
                foreach ($config in $relevantPolicies.DeviceConfigs) {
                    $configName = if ([string]::IsNullOrWhiteSpace($config.name)) { $config.displayName } else { $config.name }
                    $assignmentInfo = if ($config.AssignmentReason) { ", Assignment Reason: $($config.AssignmentReason)" } else { "" }
                    Write-Host "Device Configuration Name: $configName, Configuration ID: $($config.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Settings Catalog Policies
                Write-Host "`n------- Settings Catalog Policies -------" -ForegroundColor Cyan
                foreach ($policy in $relevantPolicies.SettingsCatalog) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    $assignmentInfo = if ($policy.AssignmentReason) { ", Assignment Reason: $($policy.AssignmentReason)" } else { "" }
                    Write-Host "Settings Catalog Policy Name: $policyName, Policy ID: $($policy.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Administrative Templates
                Write-Host "`n------- Administrative Templates -------" -ForegroundColor Cyan
                foreach ($template in $relevantPolicies.AdminTemplates) {
                    $templateName = if ([string]::IsNullOrWhiteSpace($template.name)) { $template.displayName } else { $template.name }
                    $assignmentInfo = if ($template.AssignmentReason) { ", Assignment Reason: $($template.AssignmentReason)" } else { "" }
                    Write-Host "Administrative Template Name: $templateName, Template ID: $($template.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Compliance Policies
                Write-Host "`n------- Compliance Policies -------" -ForegroundColor Cyan
                foreach ($policy in $relevantPolicies.CompliancePolicies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    $assignmentInfo = if ($policy.AssignmentReason) { ", Assignment Reason: $($policy.AssignmentReason)" } else { "" }
                    Write-Host "Compliance Policy Name: $policyName, Policy ID: $($policy.id)$assignmentInfo" -ForegroundColor White
                }

                # Display App Protection Policies
                Write-Host "`n------- App Protection Policies -------" -ForegroundColor Cyan
                foreach ($policy in $relevantPolicies.AppProtectionPolicies) {
                    $policyName = $policy.displayName
                    $policyId = $policy.id
                    $policyType = switch ($policy.'@odata.type') {
                        "#microsoft.graph.androidManagedAppProtection" { "Android" }
                        "#microsoft.graph.iosManagedAppProtection" { "iOS" }
                        "#microsoft.graph.windowsManagedAppProtection" { "Windows" }
                        default { "Unknown" }
                    }
                    $assignmentInfo = if ($policy.AssignmentReason) { ", Assignment Reason: $($policy.AssignmentReason)" } else { "" }
                    Write-Host "App Protection Policy Name: $policyName, Policy ID: $policyId, Type: $policyType$assignmentInfo" -ForegroundColor White
                }

                # Display App Configuration Policies
                Write-Host "`n------- App Configuration Policies -------" -ForegroundColor Cyan
                foreach ($policy in $relevantPolicies.AppConfigurationPolicies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    $assignmentInfo = if ($policy.AssignmentReason) { ", Assignment Reason: $($policy.AssignmentReason)" } else { "" }
                    Write-Host "App Configuration Policy Name: $policyName, Policy ID: $($policy.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Platform Scripts
                Write-Host "`n------- Platform Scripts -------" -ForegroundColor Cyan
                foreach ($script in $relevantPolicies.PlatformScripts) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    $assignmentInfo = if ($script.AssignmentReason) { ", Assignment Reason: $($script.AssignmentReason)" } else { "" }
                    Write-Host "Script Name: $scriptName, Script ID: $($script.id)$assignmentInfo" -ForegroundColor White
                }

                # Display Proactive Remediation Scripts
                Write-Host "`n------- Proactive Remediation Scripts -------" -ForegroundColor Cyan
                foreach ($script in $relevantPolicies.HealthScripts) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    $assignmentInfo = if ($script.AssignmentReason) { ", Assignment Reason: $($script.AssignmentReason)" } else { "" }
                    Write-Host "Script Name: $scriptName, Script ID: $($script.id)$assignmentInfo" -ForegroundColor White
                }

                # Add to export data
                Add-ExportData -ExportData $exportData -Category "Group" -Items @([PSCustomObject]@{
                    displayName = $groupName
                    id = $groupId
                    AssignmentReason = "Direct Assignment"
                })

                Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items $relevantPolicies.DeviceConfigs -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Settings Catalog Policy" -Items $relevantPolicies.SettingsCatalog -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Administrative Template" -Items $relevantPolicies.AdminTemplates -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Compliance Policy" -Items $relevantPolicies.CompliancePolicies -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "App Protection Policy" -Items $relevantPolicies.AppProtectionPolicies -AssignmentReason { param($item) $item.AssignmentSummary }
                Add-ExportData -ExportData $exportData -Category "App Configuration Policy" -Items $relevantPolicies.AppConfigurationPolicies -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Platform Scripts" -Items $relevantPolicies.PlatformScripts -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Proactive Remediation Scripts" -Items $relevantPolicies.HealthScripts -AssignmentReason { param($item) $item.AssignmentReason }
            }

            # Offer to export results
            $export = Read-Host "`nWould you like to export the results to CSV? (y/n)"
            if ($export -eq 'y') {
                $exportPath = Show-SaveFileDialog -DefaultFileName "IntuneGroupAssignments.csv"
                if ($exportPath) {
                    $exportData | Export-Csv -Path $exportPath -NoTypeInformation
                    Write-Host "Results exported to $exportPath" -ForegroundColor Green
                }
            }
        }
        '3' {
            Write-Host "Device selection chosen" -ForegroundColor Green

            # Prompt for one or more Device Names
            Write-Host "Please enter Device Name(s), separated by commas (,): " -ForegroundColor Cyan
            $deviceInput = Read-Host

            if ([string]::IsNullOrWhiteSpace($deviceInput)) {
                Write-Host "No device name provided. Please try again." -ForegroundColor Red
                continue
            }

            $deviceNames = $deviceInput -split ',' | ForEach-Object { $_.Trim() }
            $exportData = [System.Collections.ArrayList]::new()

            foreach ($deviceName in $deviceNames) {
                Write-Host "`nProcessing device: $deviceName" -ForegroundColor Yellow

                # Get Device Info
                $deviceInfo = Get-DeviceInfo -DeviceName $deviceName
                if (-not $deviceInfo.Success) {
                    Write-Host "Device not found: $deviceName" -ForegroundColor Red
                    Write-Host "Please verify the device name is correct." -ForegroundColor Yellow
                    continue
                }

                # Get Device Group Memberships
                try {
                    $groupMemberships = Get-GroupMemberships -ObjectId $deviceInfo.Id -ObjectType "Device"
                    Write-Host "Device Group Memberships: $($groupMemberships.displayName -join ', ')" -ForegroundColor Green
                }
                catch {
                    Write-Host "Error fetching group memberships for device: $deviceName" -ForegroundColor Red
                    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
                    continue
                }

                Write-Host "Fetching Intune Profiles and Applications for the device ... (this takes a few seconds)" -ForegroundColor Yellow

                # Initialize collections for relevant policies
                $relevantPolicies = @{
                    DeviceConfigs = @()
                    SettingsCatalog = @()
                    AdminTemplates = @()
                    CompliancePolicies = @()
                    AppProtectionPolicies = @()
                    AppConfigurationPolicies = @()
                    AppsRequired = @()
                    AppsAvailable = @()
                    AppsUninstall = @()
                    PlatformScripts = @()
                    HealthScripts = @()
                }

                # Get Device Configurations
                Write-Host "Fetching Device Configurations..." -ForegroundColor Yellow
                $deviceConfigs = Get-IntuneEntities -EntityType "deviceConfigurations"
                foreach ($config in $deviceConfigs) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceConfigurations" -EntityId $config.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Devices" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $config | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.DeviceConfigs += $config
                            break
                        }
                    }
                }

                # Get Settings Catalog Policies
                Write-Host "Fetching Settings Catalog Policies..." -ForegroundColor Yellow
                $settingsCatalog = Get-IntuneEntities -EntityType "configurationPolicies"
                foreach ($policy in $settingsCatalog) {
                    $assignments = Get-IntuneAssignments -EntityType "configurationPolicies" -EntityId $policy.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Devices" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.SettingsCatalog += $policy
                            break
                        }
                    }
                }

                # Get Administrative Templates
                Write-Host "Fetching Administrative Templates..." -ForegroundColor Yellow
                $adminTemplates = Get-IntuneEntities -EntityType "groupPolicyConfigurations"
                foreach ($template in $adminTemplates) {
                    $assignments = Get-IntuneAssignments -EntityType "groupPolicyConfigurations" -EntityId $template.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Devices" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $template | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.AdminTemplates += $template
                            break
                        }
                    }
                }

                # Get Compliance Policies
                Write-Host "Fetching Compliance Policies..." -ForegroundColor Yellow
                $compliancePolicies = Get-IntuneEntities -EntityType "deviceCompliancePolicies"
                foreach ($policy in $compliancePolicies) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceCompliancePolicies" -EntityId $policy.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Devices" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.CompliancePolicies += $policy
                            break
                        }
                    }
                }

                # Get App Protection Policies
                Write-Host "Fetching App Protection Policies..." -ForegroundColor Yellow
                $appProtectionPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/managedAppPolicies"
                foreach ($policy in $appProtectionPolicies) {
                    $policyType = $policy.'@odata.type'
                    $assignmentsUri = switch ($policyType) {
                        "#microsoft.graph.androidManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($policy.id)')/assignments" }
                        "#microsoft.graph.iosManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($policy.id)')/assignments" }
                        "#microsoft.graph.windowsManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections('$($policy.id)')/assignments" }
                        default { $null }
                    }

                    if ($assignmentsUri) {
                        try {
                            $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get
                            $assignments = @()
                            foreach ($assignment in $assignmentResponse.value) {
                                $assignmentReason = $null
                                switch ($assignment.target.'@odata.type') {
                                    '#microsoft.graph.allLicensedUsersAssignmentTarget' { 
                                        $assignmentReason = "All Users"
                                    }
                                    '#microsoft.graph.groupAssignmentTarget' {
                                        if (!$GroupId -or $assignment.target.groupId -eq $GroupId) {
                                            $assignmentReason = "Group Assignment"
                                        }
                                    }
                                }

                                if ($assignmentReason) {
                                    $assignments += @{
                                        Reason = $assignmentReason
                                        GroupId = $assignment.target.groupId
                                    }
                                }
                            }

                            if ($assignments.Count -gt 0) {
                                $assignmentSummary = $assignments | ForEach-Object {
                                    if ($_.Reason -eq "Group Assignment") {
                                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                                        "$($_.Reason) - $($groupInfo.DisplayName)"
                                    }
                                    else {
                                        $_.Reason
                                    }
                                }
                                $policy | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                                $relevantPolicies.AppProtectionPolicies += $policy
                            }
                        }
                        catch {
                            Write-Host "Error fetching assignments for policy $($policy.displayName): $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }

                # Get App Configuration Policies
                Write-Host "Fetching App Configuration Policies..." -ForegroundColor Yellow
                $appConfigPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/mobileAppConfigurations"
                foreach ($policy in $appConfigPolicies) {
                    $assignments = Get-IntuneAssignments -EntityType "mobileAppConfigurations" -EntityId $policy.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.AppConfigurationPolicies += $policy
                            break
                        }
                    }
                }

                # Get Platform Scripts
                Write-Host "Fetching Platform Scripts..." -ForegroundColor Yellow
                $platformScripts = Get-IntuneEntities -EntityType "deviceManagementScripts"
                foreach ($script in $platformScripts) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceManagementScripts" -EntityId $script.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.PlatformScripts += $script
                            break
                        }
                    }
                }

                # Get Proactive Remediation Scripts
                Write-Host "Fetching Proactive Remediation Scripts..." -ForegroundColor Yellow
                $healthScripts = Get-IntuneEntities -EntityType "deviceHealthScripts"
                foreach ($script in $healthScripts) {
                    $assignments = Get-IntuneAssignments -EntityType "deviceHealthScripts" -EntityId $script.id
                    foreach ($assignment in $assignments) {
                        if ($assignment.Reason -eq "All Users" -or 
                            ($assignment.Reason -eq "Group Assignment" -and $groupMemberships.id -contains $assignment.GroupId)) {
                            $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue $assignment.Reason -Force
                            $relevantPolicies.HealthScripts += $script
                            break
                        }
                    }
                }

                # Display results
                Write-Host "`nAssignments for Device: $deviceName" -ForegroundColor Green

                # Function to format and display policy table
                function Format-PolicyTable {
                    param (
                        [string]$Title,
                        [object[]]$Policies,
                        [scriptblock]$GetName,
                        [scriptblock]$GetExtra = { param($p) "" }
                    )

                    if ($Policies.Count -eq 0) {
                        return
                    }

                    # Create prominent section header
                    $headerSeparator = "-" * ($Title.Length + 16)  # 16 accounts for the added spaces and dashes
                    Write-Host "`n$headerSeparator" -ForegroundColor Cyan
                    Write-Host "------- $Title -------" -ForegroundColor Cyan
                    Write-Host "$headerSeparator" -ForegroundColor Cyan
                    
                    # Create table header with custom formatting
                    $headerFormat = "{0,-50} {1,-40} {2,-30}" -f "Policy Name", "ID", "Assignment"
                    $tableSeparator = "-" * 120
                    
                    Write-Host $headerFormat -ForegroundColor Yellow
                    Write-Host $separator -ForegroundColor Gray
                    
                    # Display each policy in table format
                    foreach ($policy in $Policies) {
                        $name = & $GetName $policy
                        $extra = & $GetExtra $policy
                        
                        # Truncate long names and add ellipsis
                        if ($name.Length -gt 47) {
                            $name = $name.Substring(0, 44) + "..."
                        }
                        
                        # Format ID
                        $id = $policy.id
                        if ($id.Length -gt 37) {
                            $id = $id.Substring(0, 34) + "..."
                        }
                        
                        # Format assignment reason
                        $assignment = if ($policy.AssignmentReason) { $policy.AssignmentReason } else { "No Assignment" }
                        if ($assignment.Length -gt 27) {
                            $assignment = $assignment.Substring(0, 24) + "..."
                        }
                        
                        # Output formatted row
                        $rowFormat = "{0,-50} {1,-40} {2,-30}" -f $name, $id, $assignment
                        Write-Host $rowFormat -ForegroundColor White
                    }
                    
                    Write-Host $separator -ForegroundColor Gray
                }

                # Display Device Configurations
                Format-PolicyTable -Title "Device Configurations" -Policies $relevantPolicies.DeviceConfigs -GetName {
                    param($config)
                    if ([string]::IsNullOrWhiteSpace($config.name)) { $config.displayName } else { $config.name }
                }

                # Display Settings Catalog Policies
                Format-PolicyTable -Title "Settings Catalog Policies" -Policies $relevantPolicies.SettingsCatalog -GetName {
                    param($policy)
                    if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                }

                # Display Administrative Templates
                Format-PolicyTable -Title "Administrative Templates" -Policies $relevantPolicies.AdminTemplates -GetName {
                    param($template)
                    if ([string]::IsNullOrWhiteSpace($template.name)) { $template.displayName } else { $template.name }
                }

                # Display Compliance Policies
                Format-PolicyTable -Title "Compliance Policies" -Policies $relevantPolicies.CompliancePolicies -GetName {
                    param($policy)
                    if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                }

                # Display App Protection Policies
                Format-PolicyTable -Title "App Protection Policies" -Policies $relevantPolicies.AppProtectionPolicies -GetName {
                    param($policy)
                    $policy.displayName
                } -GetExtra {
                    param($policy)
                    @{
                        Label = 'Platform'
                        Value = switch ($policy.'@odata.type') {
                            "#microsoft.graph.androidManagedAppProtection" { "Android" }
                            "#microsoft.graph.iosManagedAppProtection" { "iOS" }
                            "#microsoft.graph.windowsManagedAppProtection" { "Windows" }
                            default { "Unknown" }
                        }
                    }
                }

                # Display App Configuration Policies
                Format-PolicyTable -Title "App Configuration Policies" -Policies $relevantPolicies.AppConfigurationPolicies -GetName {
                    param($policy)
                    if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                }

                # Display Platform Scripts
                Format-PolicyTable -Title "Platform Scripts" -Policies $relevantPolicies.PlatformScripts -GetName {
                    param($script)
                    if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                }

                # Display Proactive Remediation Scripts
                Format-PolicyTable -Title "Proactive Remediation Scripts" -Policies $relevantPolicies.HealthScripts -GetName {
                    param($script)
                    if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                }

                # Add to export data
                Add-ExportData -ExportData $exportData -Category "Device" -Items @([PSCustomObject]@{
                    displayName = $deviceName
                    id = $deviceInfo.Id
                    AssignmentReason = "N/A"
                })

                Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items $relevantPolicies.DeviceConfigs -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Settings Catalog Policy" -Items $relevantPolicies.SettingsCatalog -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Administrative Template" -Items $relevantPolicies.AdminTemplates -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Compliance Policy" -Items $relevantPolicies.CompliancePolicies -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "App Protection Policy" -Items $relevantPolicies.AppProtectionPolicies -AssignmentReason { param($item) $item.AssignmentSummary }
                Add-ExportData -ExportData $exportData -Category "App Configuration Policy" -Items $relevantPolicies.AppConfigurationPolicies -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Platform Scripts" -Items $relevantPolicies.PlatformScripts -AssignmentReason { param($item) $item.AssignmentReason }
                Add-ExportData -ExportData $exportData -Category "Proactive Remediation Scripts" -Items $relevantPolicies.HealthScripts -AssignmentReason { param($item) $item.AssignmentReason }
            }

            # Offer to export results
            $export = Read-Host "`nWould you like to export the results to CSV? (y/n)"
            if ($export -eq 'y') {
                $exportPath = Show-SaveFileDialog -DefaultFileName "IntuneDeviceAssignments.csv"
                if ($exportPath) {
                    $exportData | Export-Csv -Path $exportPath -NoTypeInformation
                    Write-Host "Results exported to $exportPath" -ForegroundColor Green
                }
            }
        }
        '4' {
            Write-Host "Fetching all policies and their assignments..." -ForegroundColor Green
            $exportData = [System.Collections.ArrayList]::new()

            # Initialize collections for all policies
            $allPolicies = @{
                DeviceConfigs = @()
                SettingsCatalog = @()
                AdminTemplates = @()
                CompliancePolicies = @()
                AppProtectionPolicies = @()
                AppConfigurationPolicies = @()
                PlatformScripts = @()
                HealthScripts = @()
            }

            # Function to process and display policy assignments
            function Process-PolicyAssignments {
                param (
                    [Parameter(Mandatory = $true)]
                    [string]$PolicyType,
                    
                    [Parameter(Mandatory = $true)]
                    [object[]]$Policies,
                    
                    [Parameter(Mandatory = $true)]
                    [string]$DisplayName
                )
                
                Write-Host "`n------- $DisplayName -------" -ForegroundColor Cyan
                foreach ($policy in $Policies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "Policy Name: $policyName" -ForegroundColor White
                    Write-Host "Policy ID: $($policy.id)" -ForegroundColor Gray
                    if ($policy.AssignmentSummary) {
                        Write-Host "Assignments: $($policy.AssignmentSummary)" -ForegroundColor Gray
                    } else {
                        Write-Host "No assignments found" -ForegroundColor Yellow
                    }
                    Write-Host ""
                }
            }

            # Get Device Configurations
            Write-Host "Fetching Device Configurations..." -ForegroundColor Yellow
            $deviceConfigs = Get-IntuneEntities -EntityType "deviceConfigurations"
            foreach ($config in $deviceConfigs) {
                $assignments = Get-IntuneAssignments -EntityType "deviceConfigurations" -EntityId $config.id
                $assignmentSummary = $assignments | ForEach-Object {
                    if ($_.Reason -eq "Group Assignment") {
                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                        "$($_.Reason) - $($groupInfo.DisplayName)"
                    }
                    else {
                        $_.Reason
                    }
                }
                $config | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                $allPolicies.DeviceConfigs += $config
            }

            # Get Settings Catalog Policies
            Write-Host "Fetching Settings Catalog Policies..." -ForegroundColor Yellow
            $settingsCatalog = Get-IntuneEntities -EntityType "configurationPolicies"
            foreach ($policy in $settingsCatalog) {
                $assignments = Get-IntuneAssignments -EntityType "configurationPolicies" -EntityId $policy.id
                $assignmentSummary = $assignments | ForEach-Object {
                    if ($_.Reason -eq "Group Assignment") {
                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                        "$($_.Reason) - $($groupInfo.DisplayName)"
                    }
                    else {
                        $_.Reason
                    }
                }
                $policy | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                $allPolicies.SettingsCatalog += $policy
            }

            # Get Administrative Templates
            Write-Host "Fetching Administrative Templates..." -ForegroundColor Yellow
            $adminTemplates = Get-IntuneEntities -EntityType "groupPolicyConfigurations"
            foreach ($template in $adminTemplates) {
                $assignments = Get-IntuneAssignments -EntityType "groupPolicyConfigurations" -EntityId $template.id
                $assignmentSummary = $assignments | ForEach-Object {
                    if ($_.Reason -eq "Group Assignment") {
                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                        "$($_.Reason) - $($groupInfo.DisplayName)"
                    }
                    else {
                        $_.Reason
                    }
                }
                $template | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                $allPolicies.AdminTemplates += $template
            }

            # Get Compliance Policies
            Write-Host "Fetching Compliance Policies..." -ForegroundColor Yellow
            $compliancePolicies = Get-IntuneEntities -EntityType "deviceCompliancePolicies"
            foreach ($policy in $compliancePolicies) {
                $assignments = Get-IntuneAssignments -EntityType "deviceCompliancePolicies" -EntityId $policy.id
                $assignmentSummary = $assignments | ForEach-Object {
                    if ($_.Reason -eq "Group Assignment") {
                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                        "$($_.Reason) - $($groupInfo.DisplayName)"
                    }
                    else {
                        $_.Reason
                    }
                }
                $policy | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                $allPolicies.CompliancePolicies += $policy
            }

            # Get App Protection Policies
            Write-Host "Fetching App Protection Policies..." -ForegroundColor Yellow
            $appProtectionPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/managedAppPolicies"
            foreach ($policy in $appProtectionPolicies) {
                $policyType = $policy.'@odata.type'
                $assignmentsUri = switch ($policyType) {
                    "#microsoft.graph.androidManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($policy.id)')/assignments" }
                    "#microsoft.graph.iosManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($policy.id)')/assignments" }
                    "#microsoft.graph.windowsManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections('$($policy.id)')/assignments" }
                    default { $null }
                }

                if ($assignmentsUri) {
                    try {
                        $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get
                        $assignments = @()
                        foreach ($assignment in $assignmentResponse.value) {
                            $assignmentReason = $null
                            switch ($assignment.target.'@odata.type') {
                                '#microsoft.graph.allLicensedUsersAssignmentTarget' { 
                                    $assignmentReason = "All Users"
                                }
                                '#microsoft.graph.groupAssignmentTarget' {
                                    if ($assignment.target.groupId -eq $groupId) {
                                        $assignmentReason = "Direct Assignment"
                                    } else {
                                        $groupInfo = Get-GroupInfo -GroupId $assignment.target.groupId
                                        $assignmentReason = "Group Assignment - $($groupInfo.DisplayName)"
                                    }
                                }
                            }

                            if ($assignmentReason) {
                                $assignments += $assignmentReason
                            }
                        }
                        if ($assignments.Count -gt 0) {
                            $policy | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignments -join "; ") -Force
                            $allPolicies.AppProtectionPolicies += $policy
                        }
                    }
                    catch {
                        Write-Host "Error fetching assignments for policy $($policy.displayName): $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }

            # Get App Configuration Policies
            Write-Host "Fetching App Configuration Policies..." -ForegroundColor Yellow
            $appConfigPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/mobileAppConfigurations"
            foreach ($policy in $appConfigPolicies) {
                $assignments = Get-IntuneAssignments -EntityType "mobileAppConfigurations" -EntityId $policy.id
                $assignmentSummary = $assignments | ForEach-Object {
                    if ($_.Reason -eq "Group Assignment") {
                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                        "$($_.Reason) - $($groupInfo.DisplayName)"
                    }
                    else {
                        $_.Reason
                    }
                }
                $policy | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                $allPolicies.AppConfigurationPolicies += $policy
            }

            # Get Platform Scripts
            Write-Host "Fetching Platform Scripts..." -ForegroundColor Yellow
            $platformScripts = Get-IntuneEntities -EntityType "deviceManagementScripts"
            foreach ($script in $platformScripts) {
                $assignments = Get-IntuneAssignments -EntityType "deviceManagementScripts" -EntityId $script.id
                $assignmentSummary = $assignments | ForEach-Object {
                    if ($_.Reason -eq "Group Assignment") {
                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                        "$($_.Reason) - $($groupInfo.DisplayName)"
                    }
                    else {
                        $_.Reason
                    }
                }
                $script | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                $allPolicies.PlatformScripts += $script
            }

            # Get Proactive Remediation Scripts
            Write-Host "Fetching Proactive Remediation Scripts..." -ForegroundColor Yellow
            $healthScripts = Get-IntuneEntities -EntityType "deviceHealthScripts"
            foreach ($script in $healthScripts) {
                $assignments = Get-IntuneAssignments -EntityType "deviceHealthScripts" -EntityId $script.id
                $assignmentSummary = $assignments | ForEach-Object {
                    if ($_.Reason -eq "Group Assignment") {
                        $groupInfo = Get-GroupInfo -GroupId $_.GroupId
                        "$($_.Reason) - $($groupInfo.DisplayName)"
                    }
                    else {
                        $_.Reason
                    }
                }
                $script | Add-Member -NotePropertyName 'AssignmentSummary' -NotePropertyValue ($assignmentSummary -join "; ") -Force
                $allPolicies.HealthScripts += $script
            }

            # Display all policies and their assignments
            Process-PolicyAssignments -PolicyType "deviceConfigurations" -Policies $allPolicies.DeviceConfigs -DisplayName "Device Configurations"
            Process-PolicyAssignments -PolicyType "configurationPolicies" -Policies $allPolicies.SettingsCatalog -DisplayName "Settings Catalog Policies"
            Process-PolicyAssignments -PolicyType "groupPolicyConfigurations" -Policies $allPolicies.AdminTemplates -DisplayName "Administrative Templates"
            Process-PolicyAssignments -PolicyType "deviceCompliancePolicies" -Policies $allPolicies.CompliancePolicies -DisplayName "Compliance Policies"
            Process-PolicyAssignments -PolicyType "managedAppPolicies" -Policies $allPolicies.AppProtectionPolicies -DisplayName "App Protection Policies"
            Process-PolicyAssignments -PolicyType "mobileAppConfigurations" -Policies $allPolicies.AppConfigurationPolicies -DisplayName "App Configuration Policies"
            Process-PolicyAssignments -PolicyType "deviceManagementScripts" -Policies $allPolicies.PlatformScripts -DisplayName "Platform Scripts"
            Process-PolicyAssignments -PolicyType "deviceHealthScripts" -Policies $allPolicies.HealthScripts -DisplayName "Proactive Remediation Scripts"

            # Add to export data
            Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items $allPolicies.DeviceConfigs -AssignmentReason { param($item) $item.AssignmentSummary }
            Add-ExportData -ExportData $exportData -Category "Settings Catalog Policy" -Items $allPolicies.SettingsCatalog -AssignmentReason { param($item) $item.AssignmentSummary }
            Add-ExportData -ExportData $exportData -Category "Administrative Template" -Items $allPolicies.AdminTemplates -AssignmentReason { param($item) $item.AssignmentSummary }
            Add-ExportData -ExportData $exportData -Category "Compliance Policy" -Items $allPolicies.CompliancePolicies -AssignmentReason { param($item) $item.AssignmentSummary }
            Add-ExportData -ExportData $exportData -Category "App Protection Policy" -Items $allPolicies.AppProtectionPolicies -AssignmentReason { param($item) $item.AssignmentSummary }
            Add-ExportData -ExportData $exportData -Category "App Configuration Policy" -Items $allPolicies.AppConfigurationPolicies -AssignmentReason { param($item) $item.AssignmentSummary }
            Add-ExportData -ExportData $exportData -Category "Platform Scripts" -Items $allPolicies.PlatformScripts -AssignmentReason { param($item) $item.AssignmentSummary }
            Add-ExportData -ExportData $exportData -Category "Proactive Remediation Scripts" -Items $allPolicies.HealthScripts -AssignmentReason { param($item) $item.AssignmentSummary }

            # Offer to export results
            $export = Read-Host "`nWould you like to export the results to CSV? (y/n)"
            if ($export -eq 'y') {
                $exportPath = Show-SaveFileDialog -DefaultFileName "IntuneAllPolicies.csv"
                if ($exportPath) {
                    $exportData | Export-Csv -Path $exportPath -NoTypeInformation
                    Write-Host "Results exported to $exportPath" -ForegroundColor Green
                }
            }
        }
        '5' {
            Write-Host "Fetching all 'All Users' assignments..." -ForegroundColor Green
            $exportData = [System.Collections.ArrayList]::new()

            # Initialize collections for policies with "All Users" assignments
            $allUsersAssignments = @{
                DeviceConfigs = @()
                SettingsCatalog = @()
                AdminTemplates = @()
                CompliancePolicies = @()
                AppProtectionPolicies = @()
                AppConfigurationPolicies = @()
                PlatformScripts = @()
                HealthScripts = @()
            }

            # Get Device Configurations
            Write-Host "Fetching Device Configurations..." -ForegroundColor Yellow
            $deviceConfigs = Get-IntuneEntities -EntityType "deviceConfigurations"
            foreach ($config in $deviceConfigs) {
                $assignments = Get-IntuneAssignments -EntityType "deviceConfigurations" -EntityId $config.id
                if ($assignments | Where-Object { $_.Reason -eq "All Users" }) {
                    $config | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Users" -Force
                    $allUsersAssignments.DeviceConfigs += $config
                }
            }

            # Get Settings Catalog Policies
            Write-Host "Fetching Settings Catalog Policies..." -ForegroundColor Yellow
            $settingsCatalog = Get-IntuneEntities -EntityType "configurationPolicies"
            foreach ($policy in $settingsCatalog) {
                $assignments = Get-IntuneAssignments -EntityType "configurationPolicies" -EntityId $policy.id
                if ($assignments | Where-Object { $_.Reason -eq "All Users" }) {
                    $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Users" -Force
                    $allUsersAssignments.SettingsCatalog += $policy
                }
            }

            # Get Administrative Templates
            Write-Host "Fetching Administrative Templates..." -ForegroundColor Yellow
            $adminTemplates = Get-IntuneEntities -EntityType "groupPolicyConfigurations"
            foreach ($template in $adminTemplates) {
                $assignments = Get-IntuneAssignments -EntityType "groupPolicyConfigurations" -EntityId $template.id
                if ($assignments | Where-Object { $_.Reason -eq "All Users" }) {
                    $template | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Users" -Force
                    $allUsersAssignments.AdminTemplates += $template
                }
            }

            # Get Compliance Policies
            Write-Host "Fetching Compliance Policies..." -ForegroundColor Yellow
            $compliancePolicies = Get-IntuneEntities -EntityType "deviceCompliancePolicies"
            foreach ($policy in $compliancePolicies) {
                $assignments = Get-IntuneAssignments -EntityType "deviceCompliancePolicies" -EntityId $policy.id
                if ($assignments | Where-Object { $_.Reason -eq "All Users" }) {
                    $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Users" -Force
                    $allUsersAssignments.CompliancePolicies += $policy
                }
            }

            # Get App Protection Policies
            Write-Host "Fetching App Protection Policies..." -ForegroundColor Yellow
            $appProtectionPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/managedAppPolicies"
            foreach ($policy in $appProtectionPolicies) {
                $policyType = $policy.'@odata.type'
                $assignmentsUri = switch ($policyType) {
                    "#microsoft.graph.androidManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($policy.id)')/assignments" }
                    "#microsoft.graph.iosManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($policy.id)')/assignments" }
                    "#microsoft.graph.windowsManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections('$($policy.id)')/assignments" }
                    default { $null }
                }

                if ($assignmentsUri) {
                    try {
                        $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get
                        $hasAllUsers = $false
                        foreach ($assignment in $assignmentResponse.value) {
                            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                                $hasAllUsers = $true
                                break
                            }
                        }
                        if ($hasAllUsers) {
                            $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Users" -Force
                            $allUsersAssignments.AppProtectionPolicies += $policy
                        }
                    }
                    catch {
                        Write-Host "Error fetching assignments for policy $($policy.displayName): $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }

            # Get App Configuration Policies
            Write-Host "Fetching App Configuration Policies..." -ForegroundColor Yellow
            $appConfigPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/mobileAppConfigurations"
            foreach ($policy in $appConfigPolicies) {
                $assignments = Get-IntuneAssignments -EntityType "mobileAppConfigurations" -EntityId $policy.id
                if ($assignments | Where-Object { $_.Reason -eq "All Users" }) {
                    $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Users" -Force
                    $allUsersAssignments.AppConfigurationPolicies += $policy
                }
            }

            # Get Platform Scripts
            Write-Host "Fetching Platform Scripts..." -ForegroundColor Yellow
            $platformScripts = Get-IntuneEntities -EntityType "deviceManagementScripts"
            foreach ($script in $platformScripts) {
                $assignments = Get-IntuneAssignments -EntityType "deviceManagementScripts" -EntityId $script.id
                if ($assignments | Where-Object { $_.Reason -eq "All Users" }) {
                    $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Users" -Force
                    $allUsersAssignments.PlatformScripts += $script
                }
            }

            # Get Proactive Remediation Scripts
            Write-Host "Fetching Proactive Remediation Scripts..." -ForegroundColor Yellow
            $healthScripts = Get-IntuneEntities -EntityType "deviceHealthScripts"
            foreach ($script in $healthScripts) {
                $assignments = Get-IntuneAssignments -EntityType "deviceHealthScripts" -EntityId $script.id
                if ($assignments | Where-Object { $_.Reason -eq "All Users" }) {
                    $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Users" -Force
                    $allUsersAssignments.HealthScripts += $script
                }
            }

            # Display results
            Write-Host "`nPolicies Assigned to All Users:" -ForegroundColor Green

            # Display Device Configurations
            Write-Host "`n------- Device Configurations -------" -ForegroundColor Cyan
            if ($allUsersAssignments.DeviceConfigs.Count -eq 0) {
                Write-Host "No Device Configurations assigned to All Users" -ForegroundColor Gray
            }
            else {
                foreach ($config in $allUsersAssignments.DeviceConfigs) {
                    $configName = if ([string]::IsNullOrWhiteSpace($config.name)) { $config.displayName } else { $config.name }
                    Write-Host "Device Configuration Name: $configName, Configuration ID: $($config.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items @($config) -AssignmentReason "All Users"
                }
            }

            # Display Settings Catalog Policies
            Write-Host "`n------- Settings Catalog Policies -------" -ForegroundColor Cyan
            if ($allUsersAssignments.SettingsCatalog.Count -eq 0) {
                Write-Host "No Settings Catalog Policies assigned to All Users" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $allUsersAssignments.SettingsCatalog) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "Settings Catalog Policy Name: $policyName, Policy ID: $($policy.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Settings Catalog Policy" -Items @($policy) -AssignmentReason "All Users"
                }
            }

            # Display Administrative Templates
            Write-Host "`n------- Administrative Templates -------" -ForegroundColor Cyan
            if ($allUsersAssignments.AdminTemplates.Count -eq 0) {
                Write-Host "No Administrative Templates assigned to All Users" -ForegroundColor Gray
            }
            else {
                foreach ($template in $allUsersAssignments.AdminTemplates) {
                    $templateName = if ([string]::IsNullOrWhiteSpace($template.name)) { $template.displayName } else { $template.name }
                    Write-Host "Administrative Template Name: $templateName, Template ID: $($template.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Administrative Template" -Items @($template) -AssignmentReason "All Users"
                }
            }

            # Display Compliance Policies
            Write-Host "`n------- Compliance Policies -------" -ForegroundColor Cyan
            if ($allUsersAssignments.CompliancePolicies.Count -eq 0) {
                Write-Host "No Compliance Policies assigned to All Users" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $allUsersAssignments.CompliancePolicies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "Compliance Policy Name: $policyName, Policy ID: $($policy.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Compliance Policy" -Items @($policy) -AssignmentReason "All Users"
                }
            }

            # Display App Protection Policies
            Write-Host "`n------- App Protection Policies -------" -ForegroundColor Cyan
            if ($allUsersAssignments.AppProtectionPolicies.Count -eq 0) {
                Write-Host "No App Protection Policies assigned to All Users" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $allUsersAssignments.AppProtectionPolicies) {
                    $policyName = $policy.displayName
                    $policyType = switch ($policy.'@odata.type') {
                        "#microsoft.graph.androidManagedAppProtection" { "Android" }
                        "#microsoft.graph.iosManagedAppProtection" { "iOS" }
                        "#microsoft.graph.windowsManagedAppProtection" { "Windows" }
                        default { "Unknown" }
                    }
                    Write-Host "App Protection Policy Name: $policyName, Policy ID: $($policy.id), Type: $policyType" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "App Protection Policy" -Items @($policy) -AssignmentReason "All Users"
                }
            }

            # Display App Configuration Policies
            Write-Host "`n------- App Configuration Policies -------" -ForegroundColor Cyan
            if ($allUsersAssignments.AppConfigurationPolicies.Count -eq 0) {
                Write-Host "No App Configuration Policies assigned to All Users" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $allUsersAssignments.AppConfigurationPolicies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "App Configuration Policy Name: $policyName, Policy ID: $($policy.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "App Configuration Policy" -Items @($policy) -AssignmentReason "All Users"
                }
            }

            # Display Platform Scripts
            Write-Host "`n------- Platform Scripts -------" -ForegroundColor Cyan
            if ($allUsersAssignments.PlatformScripts.Count -eq 0) {
                Write-Host "No Platform Scripts assigned to All Users" -ForegroundColor Gray
            }
            else {
                foreach ($script in $allUsersAssignments.PlatformScripts) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    Write-Host "Script Name: $scriptName, Script ID: $($script.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Platform Scripts" -Items @($script) -AssignmentReason "All Users"
                }
            }

            # Display Proactive Remediation Scripts
            Write-Host "`n------- Proactive Remediation Scripts -------" -ForegroundColor Cyan
            if ($allUsersAssignments.HealthScripts.Count -eq 0) {
                Write-Host "No Proactive Remediation Scripts assigned to All Users" -ForegroundColor Gray
            }
            else {
                foreach ($script in $allUsersAssignments.HealthScripts) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    Write-Host "Script Name: $scriptName, Script ID: $($script.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Proactive Remediation Scripts" -Items @($script) -AssignmentReason "All Users"
                }
            }

            # Offer to export results
            $export = Read-Host "`nWould you like to export the results to CSV? (y/n)"
            if ($export -eq 'y') {
                $exportPath = Show-SaveFileDialog -DefaultFileName "IntuneAllUsersAssignments.csv"
                if ($exportPath) {
                    $exportData | Export-Csv -Path $exportPath -NoTypeInformation
                    Write-Host "Results exported to $exportPath" -ForegroundColor Green
                }
            }
        }
        '6' {
            Write-Host "Fetching all 'All Devices' assignments..." -ForegroundColor Green
            $exportData = [System.Collections.ArrayList]::new()

            # Initialize collections for policies with "All Devices" assignments
            $allDevicesAssignments = @{
                DeviceConfigs = @()
                SettingsCatalog = @()
                AdminTemplates = @()
                CompliancePolicies = @()
                AppProtectionPolicies = @()
                AppConfigurationPolicies = @()
                PlatformScripts = @()
                HealthScripts = @()
            }

            # Get Device Configurations
            Write-Host "Fetching Device Configurations..." -ForegroundColor Yellow
            $deviceConfigs = Get-IntuneEntities -EntityType "deviceConfigurations"
            foreach ($config in $deviceConfigs) {
                $assignments = Get-IntuneAssignments -EntityType "deviceConfigurations" -EntityId $config.id
                if ($assignments | Where-Object { $_.Reason -eq "All Devices" }) {
                    $config | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Devices" -Force
                    $allDevicesAssignments.DeviceConfigs += $config
                }
            }

            # Get Settings Catalog Policies
            Write-Host "Fetching Settings Catalog Policies..." -ForegroundColor Yellow
            $settingsCatalog = Get-IntuneEntities -EntityType "configurationPolicies"
            foreach ($policy in $settingsCatalog) {
                $assignments = Get-IntuneAssignments -EntityType "configurationPolicies" -EntityId $policy.id
                if ($assignments | Where-Object { $_.Reason -eq "All Devices" }) {
                    $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Devices" -Force
                    $allDevicesAssignments.SettingsCatalog += $policy
                }
            }

            # Get Administrative Templates
            Write-Host "Fetching Administrative Templates..." -ForegroundColor Yellow
            $adminTemplates = Get-IntuneEntities -EntityType "groupPolicyConfigurations"
            foreach ($template in $adminTemplates) {
                $assignments = Get-IntuneAssignments -EntityType "groupPolicyConfigurations" -EntityId $template.id
                if ($assignments | Where-Object { $_.Reason -eq "All Devices" }) {
                    $template | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Devices" -Force
                    $allDevicesAssignments.AdminTemplates += $template
                }
            }

            # Get Compliance Policies
            Write-Host "Fetching Compliance Policies..." -ForegroundColor Yellow
            $compliancePolicies = Get-IntuneEntities -EntityType "deviceCompliancePolicies"
            foreach ($policy in $compliancePolicies) {
                $assignments = Get-IntuneAssignments -EntityType "deviceCompliancePolicies" -EntityId $policy.id
                if ($assignments | Where-Object { $_.Reason -eq "All Devices" }) {
                    $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Devices" -Force
                    $allDevicesAssignments.CompliancePolicies += $policy
                }
            }

            # Get App Protection Policies
            Write-Host "Fetching App Protection Policies..." -ForegroundColor Yellow
            $appProtectionPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/managedAppPolicies"
            foreach ($policy in $appProtectionPolicies) {
                $policyType = $policy.'@odata.type'
                $assignmentsUri = switch ($policyType) {
                    "#microsoft.graph.androidManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($policy.id)')/assignments" }
                    "#microsoft.graph.iosManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($policy.id)')/assignments" }
                    "#microsoft.graph.windowsManagedAppProtection" { "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections('$($policy.id)')/assignments" }
                    default { $null }
                }

                if ($assignmentsUri) {
                    try {
                        $assignmentResponse = Invoke-MgGraphRequest -Uri $assignmentsUri -Method Get
                        $hasAllDevices = $false
                        foreach ($assignment in $assignmentResponse.value) {
                            if ($assignment.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {
                                $hasAllDevices = $true
                                break
                            }
                        }
                        if ($hasAllDevices) {
                            $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Devices" -Force
                            $allDevicesAssignments.AppProtectionPolicies += $policy
                        }
                    }
                    catch {
                        Write-Host "Error fetching assignments for policy $($policy.displayName): $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }

            # Get App Configuration Policies
            Write-Host "Fetching App Configuration Policies..." -ForegroundColor Yellow
            $appConfigPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/mobileAppConfigurations"
            foreach ($policy in $appConfigPolicies) {
                $assignments = Get-IntuneAssignments -EntityType "mobileAppConfigurations" -EntityId $policy.id
                if ($assignments | Where-Object { $_.Reason -eq "All Devices" }) {
                    $policy | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Devices" -Force
                    $allDevicesAssignments.AppConfigurationPolicies += $policy
                }
            }

            # Get Platform Scripts
            Write-Host "Fetching Platform Scripts..." -ForegroundColor Yellow
            $platformScripts = Get-IntuneEntities -EntityType "deviceManagementScripts"
            foreach ($script in $platformScripts) {
                $assignments = Get-IntuneAssignments -EntityType "deviceManagementScripts" -EntityId $script.id
                if ($assignments | Where-Object { $_.Reason -eq "All Devices" }) {
                    $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Devices" -Force
                    $allDevicesAssignments.PlatformScripts += $script
                }
            }

            # Get Proactive Remediation Scripts
            Write-Host "Fetching Proactive Remediation Scripts..." -ForegroundColor Yellow
            $healthScripts = Get-IntuneEntities -EntityType "deviceHealthScripts"
            foreach ($script in $healthScripts) {
                $assignments = Get-IntuneAssignments -EntityType "deviceHealthScripts" -EntityId $script.id
                if ($assignments | Where-Object { $_.Reason -eq "All Devices" }) {
                    $script | Add-Member -NotePropertyName 'AssignmentReason' -NotePropertyValue "All Devices" -Force
                    $allDevicesAssignments.HealthScripts += $script
                }
            }

            # Display results
            Write-Host "`nPolicies Assigned to All Devices:" -ForegroundColor Green

            # Display Device Configurations
            Write-Host "`n------- Device Configurations -------" -ForegroundColor Cyan
            if ($allDevicesAssignments.DeviceConfigs.Count -eq 0) {
                Write-Host "No Device Configurations assigned to All Devices" -ForegroundColor Gray
            }
            else {
                foreach ($config in $allDevicesAssignments.DeviceConfigs) {
                    $configName = if ([string]::IsNullOrWhiteSpace($config.name)) { $config.displayName } else { $config.name }
                    Write-Host "Device Configuration Name: $configName, Configuration ID: $($config.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items @($config) -AssignmentReason "All Devices"
                }
            }

            # Display Settings Catalog Policies
            Write-Host "`n------- Settings Catalog Policies -------" -ForegroundColor Cyan
            if ($allDevicesAssignments.SettingsCatalog.Count -eq 0) {
                Write-Host "No Settings Catalog Policies assigned to All Devices" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $allDevicesAssignments.SettingsCatalog) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "Settings Catalog Policy Name: $policyName, Policy ID: $($policy.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Settings Catalog Policy" -Items @($policy) -AssignmentReason "All Devices"
                }
            }

            # Display Administrative Templates
            Write-Host "`n------- Administrative Templates -------" -ForegroundColor Cyan
            if ($allDevicesAssignments.AdminTemplates.Count -eq 0) {
                Write-Host "No Administrative Templates assigned to All Devices" -ForegroundColor Gray
            }
            else {
                foreach ($template in $allDevicesAssignments.AdminTemplates) {
                    $templateName = if ([string]::IsNullOrWhiteSpace($template.name)) { $template.displayName } else { $template.name }
                    Write-Host "Administrative Template Name: $templateName, Template ID: $($template.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Administrative Template" -Items @($template) -AssignmentReason "All Devices"
                }
            }

            # Display Compliance Policies
            Write-Host "`n------- Compliance Policies -------" -ForegroundColor Cyan
            if ($allDevicesAssignments.CompliancePolicies.Count -eq 0) {
                Write-Host "No Compliance Policies assigned to All Devices" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $allDevicesAssignments.CompliancePolicies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "Compliance Policy Name: $policyName, Policy ID: $($policy.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Compliance Policy" -Items @($policy) -AssignmentReason "All Devices"
                }
            }

            # Display App Protection Policies
            Write-Host "`n------- App Protection Policies -------" -ForegroundColor Cyan
            if ($allDevicesAssignments.AppProtectionPolicies.Count -eq 0) {
                Write-Host "No App Protection Policies assigned to All Devices" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $allDevicesAssignments.AppProtectionPolicies) {
                    $policyName = $policy.displayName
                    $policyType = switch ($policy.'@odata.type') {
                        "#microsoft.graph.androidManagedAppProtection" { "Android" }
                        "#microsoft.graph.iosManagedAppProtection" { "iOS" }
                        "#microsoft.graph.windowsManagedAppProtection" { "Windows" }
                        default { "Unknown" }
                    }
                    Write-Host "App Protection Policy Name: $policyName, Policy ID: $($policy.id), Type: $policyType" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "App Protection Policy" -Items @($policy) -AssignmentReason "All Devices"
                }
            }

            # Display App Configuration Policies
            Write-Host "`n------- App Configuration Policies -------" -ForegroundColor Cyan
            if ($allDevicesAssignments.AppConfigurationPolicies.Count -eq 0) {
                Write-Host "No App Configuration Policies assigned to All Devices" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $allDevicesAssignments.AppConfigurationPolicies) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "App Configuration Policy Name: $policyName, Policy ID: $($policy.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "App Configuration Policy" -Items @($policy) -AssignmentReason "All Devices"
                }
            }

            # Display Platform Scripts
            Write-Host "`n------- Platform Scripts -------" -ForegroundColor Cyan
            if ($allDevicesAssignments.PlatformScripts.Count -eq 0) {
                Write-Host "No Platform Scripts assigned to All Devices" -ForegroundColor Gray
            }
            else {
                foreach ($script in $allDevicesAssignments.PlatformScripts) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    Write-Host "Script Name: $scriptName, Script ID: $($script.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Platform Scripts" -Items @($script) -AssignmentReason "All Devices"
                }
            }

            # Display Proactive Remediation Scripts
            Write-Host "`n------- Proactive Remediation Scripts -------" -ForegroundColor Cyan
            if ($allDevicesAssignments.HealthScripts.Count -eq 0) {
                Write-Host "No Proactive Remediation Scripts assigned to All Devices" -ForegroundColor Gray
            }
            else {
                foreach ($script in $allDevicesAssignments.HealthScripts) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    Write-Host "Script Name: $scriptName, Script ID: $($script.id)" -ForegroundColor White
                    Add-ExportData -ExportData $exportData -Category "Proactive Remediation Scripts" -Items @($script) -AssignmentReason "All Devices"
                }
            }

            # Offer to export results
            $export = Read-Host "`nWould you like to export the results to CSV? (y/n)"
            if ($export -eq 'y') {
                $exportPath = Show-SaveFileDialog -DefaultFileName "IntuneAllDevicesAssignments.csv"
                if ($exportPath) {
                    $exportData | Export-Csv -Path $exportPath -NoTypeInformation
                    Write-Host "Results exported to $exportPath" -ForegroundColor Green
                }
            }
        }
        '11' {
            Write-Host "Compare Group Assignments chosen" -ForegroundColor Green

            # Prompt for source group
            Write-Host "`nEnter the first group name or Object ID: " -ForegroundColor Cyan
            Write-Host "Example: 'Marketing Team' or '12345678-1234-1234-1234-123456789012'" -ForegroundColor Gray
            $sourceGroupInput = Read-Host

            if ([string]::IsNullOrWhiteSpace($sourceGroupInput)) {
                Write-Host "No group information provided. Please try again." -ForegroundColor Red
                continue
            }

            # Get source group info
            $sourceGroupId = $null
            $sourceGroupName = $null

            if ($sourceGroupInput -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
                $groupInfo = Get-GroupInfo -GroupId $sourceGroupInput
                if (-not $groupInfo.Success) {
                    Write-Host "No group found with ID: $sourceGroupInput" -ForegroundColor Red
                    continue
                }
                $sourceGroupId = $groupInfo.Id
                $sourceGroupName = $groupInfo.DisplayName
            }
            else {
                $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$sourceGroupInput'"
                $groupResponse = Invoke-MgGraphRequest -Uri $groupUri -Method Get

                if ($groupResponse.value.Count -eq 0) {
                    Write-Host "No group found with name: $sourceGroupInput" -ForegroundColor Red
                    continue
                }
                elseif ($groupResponse.value.Count -gt 1) {
                    Write-Host "Multiple groups found with name: $sourceGroupInput. Please use the Object ID instead:" -ForegroundColor Red
                    foreach ($group in $groupResponse.value) {
                        Write-Host "  - $($group.displayName) (ID: $($group.id))" -ForegroundColor Yellow
                    }
                    continue
                }

                $sourceGroupId = $groupResponse.value[0].id
                $sourceGroupName = $groupResponse.value[0].displayName
            }

            # Prompt for target group
            Write-Host "`nEnter the second group name or Object ID: " -ForegroundColor Cyan
            Write-Host "Example: 'Sales Team' or '12345678-1234-1234-1234-123456789012'" -ForegroundColor Gray
            $targetGroupInput = Read-Host

            if ([string]::IsNullOrWhiteSpace($targetGroupInput)) {
                Write-Host "No group information provided. Please try again." -ForegroundColor Red
                continue
            }

            # Get target group info
            $targetGroupId = $null
            $targetGroupName = $null

            if ($targetGroupInput -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
                $groupInfo = Get-GroupInfo -GroupId $targetGroupInput
                if (-not $groupInfo.Success) {
                    Write-Host "No group found with ID: $targetGroupInput" -ForegroundColor Red
                    continue
                }
                $targetGroupId = $groupInfo.Id
                $targetGroupName = $groupInfo.DisplayName
            }
            else {
                $groupUri = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$targetGroupInput'"
                $groupResponse = Invoke-MgGraphRequest -Uri $groupUri -Method Get

                if ($groupResponse.value.Count -eq 0) {
                    Write-Host "No group found with name: $targetGroupInput" -ForegroundColor Red
                    continue
                }
                elseif ($groupResponse.value.Count -gt 1) {
                    Write-Host "Multiple groups found with name: $targetGroupInput. Please use the Object ID instead:" -ForegroundColor Red
                    foreach ($group in $groupResponse.value) {
                        Write-Host "  - $($group.displayName) (ID: $($group.id))" -ForegroundColor Yellow
                    }
                    continue
                }

                $targetGroupId = $groupResponse.value[0].id
                $targetGroupName = $groupResponse.value[0].displayName
            }

            Write-Host "`nComparing assignments between:" -ForegroundColor Green
            Write-Host "Group 1: $sourceGroupName (ID: $sourceGroupId)" -ForegroundColor White
            Write-Host "Group 2: $targetGroupName (ID: $targetGroupId)" -ForegroundColor White

            $exportData = [System.Collections.ArrayList]::new()

            # Helper function to get policy assignments for a group
            # Helper function to get policy assignments for a group
            function Get-GroupPolicyAssignments {
                param (
                    [Parameter(Mandatory = $true)]
                    [string]$GroupId,
                    
                    [Parameter(Mandatory = $true)]
                    [string]$EntityType,
                    
                    [Parameter(Mandatory = $true)]
                    [object[]]$Policies
                )

                $assignedPolicies = @()
                foreach ($policy in $Policies) {
                    $assignments = Get-IntuneAssignments -EntityType $EntityType -EntityId $policy.id -GroupId $GroupId
                    if ($assignments) {
                        $assignedPolicies += $policy
                    }
                }
                return $assignedPolicies
            }

            # Compare Device Configurations
            Write-Host "`nComparing Device Configurations..." -ForegroundColor Yellow
            $deviceConfigs = Get-IntuneEntities -EntityType "deviceConfigurations"
            $sourceDeviceConfigs = Get-GroupPolicyAssignments -GroupId $sourceGroupId -EntityType "deviceConfigurations" -Policies $deviceConfigs
            $targetDeviceConfigs = Get-GroupPolicyAssignments -GroupId $targetGroupId -EntityType "deviceConfigurations" -Policies $deviceConfigs

            Write-Host "`n------- Device Configurations -------" -ForegroundColor Cyan
            Write-Host ("Policies only in " + $sourceGroupName) -ForegroundColor White
            $uniqueToSource = $sourceDeviceConfigs | Where-Object { $_.id -notin $targetDeviceConfigs.id }
            if ($uniqueToSource.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($config in $uniqueToSource) {
                    $configName = if ([string]::IsNullOrWhiteSpace($config.name)) { $config.displayName } else { $config.name }
                    Write-Host "  - $configName (ID: $($config.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items @($config) -AssignmentReason ("Only in " + $sourceGroupName)
                }
            }

            Write-Host ("`nPolicies only in " + $targetGroupName) -ForegroundColor White
            $uniqueToTarget = $targetDeviceConfigs | Where-Object { $_.id -notin $sourceDeviceConfigs.id }
            if ($uniqueToTarget.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($config in $uniqueToTarget) {
                    $configName = if ([string]::IsNullOrWhiteSpace($config.name)) { $config.displayName } else { $config.name }
                    Write-Host "  - $configName (ID: $($config.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items @($config) -AssignmentReason "Only in $targetGroupName"
                }
            }

            # Compare Settings Catalog Policies
            Write-Host "`nComparing Settings Catalog Policies..." -ForegroundColor Yellow
            $settingsCatalog = Get-IntuneEntities -EntityType "configurationPolicies"
            $sourceSettingsCatalog = Get-GroupPolicyAssignments -GroupId $sourceGroupId -EntityType "configurationPolicies" -Policies $settingsCatalog
            $targetSettingsCatalog = Get-GroupPolicyAssignments -GroupId $targetGroupId -EntityType "configurationPolicies" -Policies $settingsCatalog

            Write-Host "`n------- Settings Catalog Policies -------" -ForegroundColor Cyan
            Write-Host ("Policies only in " + $sourceGroupName) -ForegroundColor White
            $uniqueToSource = $sourceDeviceConfigs | Where-Object { $_.id -notin $targetDeviceConfigs.id }
            if ($uniqueToSource.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($config in $uniqueToSource) {
                    $configName = if ([string]::IsNullOrWhiteSpace($config.name)) { $config.displayName } else { $config.name }
                    Write-Host "  - $configName (ID: $($config.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Device Configuration" -Items @($config) -AssignmentReason ("Only in " + $sourceGroupName)
                }
            }

            Write-Host ("`nPolicies only in " + $targetGroupName) -ForegroundColor White
            $uniqueToTarget = $targetSettingsCatalog | Where-Object { $_.id -notin $sourceSettingsCatalog.id }
            if ($uniqueToTarget.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $uniqueToTarget) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "  - $policyName (ID: $($policy.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Settings Catalog Policy" -Items @($policy) -AssignmentReason "Only in $targetGroupName"
                }
            }

            # Compare Administrative Templates
            Write-Host "`nComparing Administrative Templates..." -ForegroundColor Yellow
            $adminTemplates = Get-IntuneEntities -EntityType "groupPolicyConfigurations"
            $sourceAdminTemplates = Get-GroupPolicyAssignments -GroupId $sourceGroupId -EntityType "groupPolicyConfigurations" -Policies $adminTemplates
            $targetAdminTemplates = Get-GroupPolicyAssignments -GroupId $targetGroupId -EntityType "groupPolicyConfigurations" -Policies $adminTemplates

            Write-Host "`n------- Administrative Templates -------" -ForegroundColor Cyan
            Write-Host ("Templates only in " + $sourceGroupName) -ForegroundColor White
            $uniqueToSource = $sourceAdminTemplates | Where-Object { $_.id -notin $targetAdminTemplates.id }
            if ($uniqueToSource.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($template in $uniqueToSource) {
                    $templateName = if ([string]::IsNullOrWhiteSpace($template.name)) { $template.displayName } else { $template.name }
                    Write-Host "  - $templateName (ID: $($template.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Administrative Template" -Items @($template) -AssignmentReason ("Only in " + $sourceGroupName)
                }
            }

            Write-Host ("`nTemplates only in " + $targetGroupName) -ForegroundColor White
            $uniqueToTarget = $targetAdminTemplates | Where-Object { $_.id -notin $sourceAdminTemplates.id }
            if ($uniqueToTarget.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($template in $uniqueToTarget) {
                    $templateName = if ([string]::IsNullOrWhiteSpace($template.name)) { $template.displayName } else { $template.name }
                    Write-Host "  - $templateName (ID: $($template.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Administrative Template" -Items @($template) -AssignmentReason ("Only in " + $targetGroupName)
                }
            }

            # Compare Compliance Policies
            Write-Host "`nComparing Compliance Policies..." -ForegroundColor Yellow
            $compliancePolicies = Get-IntuneEntities -EntityType "deviceCompliancePolicies"
            $sourceCompliancePolicies = Get-GroupPolicyAssignments -GroupId $sourceGroupId -EntityType "deviceCompliancePolicies" -Policies $compliancePolicies
            $targetCompliancePolicies = Get-GroupPolicyAssignments -GroupId $targetGroupId -EntityType "deviceCompliancePolicies" -Policies $compliancePolicies

            Write-Host "`n------- Compliance Policies -------" -ForegroundColor Cyan
            Write-Host ("Policies only in " + $sourceGroupName) -ForegroundColor White
            $uniqueToSource = $sourceCompliancePolicies | Where-Object { $_.id -notin $targetCompliancePolicies.id }
            if ($uniqueToSource.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $uniqueToSource) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "  - $policyName (ID: $($policy.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Compliance Policy" -Items @($policy) -AssignmentReason ("Only in " + $sourceGroupName)
                }
            }

            Write-Host ("`nPolicies only in " + $targetGroupName) -ForegroundColor White
            $uniqueToTarget = $targetCompliancePolicies | Where-Object { $_.id -notin $sourceCompliancePolicies.id }
            if ($uniqueToTarget.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $uniqueToTarget) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "  - $policyName (ID: $($policy.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Compliance Policy" -Items @($policy) -AssignmentReason "Only in $targetGroupName"
                }
            }

            # Compare App Protection Policies
            Write-Host "`nComparing App Protection Policies..." -ForegroundColor Yellow
            $appProtectionPolicies = Get-IntuneEntities -EntityType "deviceAppManagement/managedAppPolicies"
            $sourceAppProtectionPolicies = Get-GroupPolicyAssignments -GroupId $sourceGroupId -EntityType "managedAppPolicies" -Policies $appProtectionPolicies
            $targetAppProtectionPolicies = Get-GroupPolicyAssignments -GroupId $targetGroupId -EntityType "managedAppPolicies" -Policies $appProtectionPolicies

            Write-Host "`n------- App Protection Policies -------" -ForegroundColor Cyan
            Write-Host ("Policies only in " + $sourceGroupName) -ForegroundColor White
            $uniqueToSource = $sourceAppProtectionPolicies | Where-Object { $_.id -notin $targetAppProtectionPolicies.id }
            if ($uniqueToSource.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $uniqueToSource) {
                    $policyName = $policy.displayName
                    $policyType = switch ($policy.'@odata.type') {
                        "#microsoft.graph.androidManagedAppProtection" { "Android" }
                        "#microsoft.graph.iosManagedAppProtection" { "iOS" }
                        "#microsoft.graph.windowsManagedAppProtection" { "Windows" }
                        default { "Unknown" }
                    }
                    Write-Host "  - $policyName (ID: $($policy.id), Type: $policyType)" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "App Protection Policy" -Items @($policy) -AssignmentReason "Only in $sourceGroupName"
                }
            }

            Write-Host ("`nPolicies only in " + $targetGroupName) -ForegroundColor White
            $uniqueToTarget = $targetAppProtectionPolicies | Where-Object { $_.id -notin $sourceAppProtectionPolicies.id }
            if ($uniqueToTarget.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $uniqueToTarget) {
                    $policyName = $policy.displayName
                    $policyType = switch ($policy.'@odata.type') {
                        "#microsoft.graph.androidManagedAppProtection" { "Android" }
                        "#microsoft.graph.iosManagedAppProtection" { "iOS" }
                        "#microsoft.graph.windowsManagedAppProtection" { "Windows" }
                        default { "Unknown" }
                    }
                    Write-Host "  - $policyName (ID: $($policy.id), Type: $policyType)" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "App Protection Policy" -Items @($policy) -AssignmentReason "Only in $targetGroupName"
                }
            }

            # Compare App Configuration Policies
            Write-Host "`nComparing App Configuration Policies..." -ForegroundColor Yellow
            $appConfigPolicies = Get-IntuneEntities -EntityType "mobileAppConfigurations"
            $sourceAppConfigPolicies = Get-GroupPolicyAssignments -GroupId $sourceGroupId -EntityType "mobileAppConfigurations" -Policies $appConfigPolicies
            $targetAppConfigPolicies = Get-GroupPolicyAssignments -GroupId $targetGroupId -EntityType "mobileAppConfigurations" -Policies $appConfigPolicies

            Write-Host "`n------- App Configuration Policies -------" -ForegroundColor Cyan
            Write-Host ("Policies only in " + $sourceGroupName) -ForegroundColor White
            $uniqueToSource = $sourceAppConfigPolicies | Where-Object { $_.id -notin $targetAppConfigPolicies.id }
            if ($uniqueToSource.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $uniqueToSource) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "  - $policyName (ID: $($policy.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "App Configuration Policy" -Items @($policy) -AssignmentReason "Only in $sourceGroupName"
                }
            }

            Write-Host ("`nPolicies only in " + $targetGroupName) -ForegroundColor White
            $uniqueToTarget = $targetAppConfigPolicies | Where-Object { $_.id -notin $sourceAppConfigPolicies.id }
            if ($uniqueToTarget.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($policy in $uniqueToTarget) {
                    $policyName = if ([string]::IsNullOrWhiteSpace($policy.name)) { $policy.displayName } else { $policy.name }
                    Write-Host "  - $policyName (ID: $($policy.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "App Configuration Policy" -Items @($policy) -AssignmentReason "Only in $targetGroupName"
                }
            }

            # Compare Platform Scripts
            Write-Host "`nComparing Platform Scripts..." -ForegroundColor Yellow
            $platformScripts = Get-IntuneEntities -EntityType "deviceManagementScripts"
            $sourcePlatformScripts = Get-GroupPolicyAssignments -GroupId $sourceGroupId -EntityType "deviceManagementScripts" -Policies $platformScripts
            $targetPlatformScripts = Get-GroupPolicyAssignments -GroupId $targetGroupId -EntityType "deviceManagementScripts" -Policies $platformScripts

            Write-Host "`n------- Platform Scripts -------" -ForegroundColor Cyan
            Write-Host ("Scripts only in " + $sourceGroupName) -ForegroundColor White
            $uniqueToSource = $sourcePlatformScripts | Where-Object { $_.id -notin $targetPlatformScripts.id }
            if ($uniqueToSource.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($script in $uniqueToSource) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    Write-Host "  - $scriptName (ID: $($script.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Platform Scripts" -Items @($script) -AssignmentReason "Only in $sourceGroupName"
                }
            }

            Write-Host ("`nScripts only in " + $targetGroupName) -ForegroundColor White
            $uniqueToTarget = $targetPlatformScripts | Where-Object { $_.id -notin $sourcePlatformScripts.id }
            if ($uniqueToTarget.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($script in $uniqueToTarget) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    Write-Host "  - $scriptName (ID: $($script.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Platform Scripts" -Items @($script) -AssignmentReason "Only in $targetGroupName"
                }
            }

            # Compare Proactive Remediation Scripts
            Write-Host "`nComparing Proactive Remediation Scripts..." -ForegroundColor Yellow
            $healthScripts = Get-IntuneEntities -EntityType "deviceHealthScripts"
            $sourceHealthScripts = Get-GroupPolicyAssignments -GroupId $sourceGroupId -EntityType "deviceHealthScripts" -Policies $healthScripts
            $targetHealthScripts = Get-GroupPolicyAssignments -GroupId $targetGroupId -EntityType "deviceHealthScripts" -Policies $healthScripts

            Write-Host "`n------- Proactive Remediation Scripts -------" -ForegroundColor Cyan
            Write-Host ("Scripts only in " + $sourceGroupName) -ForegroundColor White
            $uniqueToSource = $sourceHealthScripts | Where-Object { $_.id -notin $targetHealthScripts.id }
            if ($uniqueToSource.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($script in $uniqueToSource) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    Write-Host "  - $scriptName (ID: $($script.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Proactive Remediation Scripts" -Items @($script) -AssignmentReason "Only in $sourceGroupName"
                }
            }

            Write-Host ("`nScripts only in " + $targetGroupName) -ForegroundColor White
            $uniqueToTarget = $targetHealthScripts | Where-Object { $_.id -notin $sourceHealthScripts.id }
            if ($uniqueToTarget.Count -eq 0) {
                Write-Host "None" -ForegroundColor Gray
            }
            else {
                foreach ($script in $uniqueToTarget) {
                    $scriptName = if ([string]::IsNullOrWhiteSpace($script.name)) { $script.displayName } else { $script.name }
                    Write-Host "  - $scriptName (ID: $($script.id))" -ForegroundColor Gray
                    Add-ExportData -ExportData $exportData -Category "Proactive Remediation Scripts" -Items @($script) -AssignmentReason "Only in $targetGroupName"
                }
            }

            # Offer to export results
            $export = Read-Host "`nWould you like to export the results to CSV? (y/n)"
            if ($export -eq 'y') {
                $exportPath = Show-SaveFileDialog -DefaultFileName "IntuneGroupComparison.csv"
                if ($exportPath) {
                    $exportData | Export-Csv -Path $exportPath -NoTypeInformation
                    Write-Host "Results exported to $exportPath" -ForegroundColor Green
                }
            }
        }
        '0' {
            Write-Host "Disconnecting from Microsoft Graph..." -ForegroundColor Yellow
            Disconnect-MgGraph | Out-Null
            Write-Host "Thank you for using IntuneAssignmentChecker! 👋" -ForegroundColor Green
            Write-Host "If you found this tool helpful, please consider:" -ForegroundColor Cyan
            Write-Host "- Starring the repository: https://github.com/ugurkocde/IntuneAssignmentChecker" -ForegroundColor White
            Write-Host "- Supporting the project: https://github.com/sponsors/ugurkocde" -ForegroundColor White
            Write-Host ""
            exit
        }
        '98' {
            Write-Host "Opening GitHub Sponsor Page ..." -ForegroundColor Green
            Start-Process "https://github.com/sponsors/ugurkocde"
        }
        '99' {
            Write-Host "Opening GitHub Repository..." -ForegroundColor Green
            Start-Process "https://github.com/ugurkocde/IntuneAssignmentChecker"
        }
        default {
            Write-Host "Invalid choice, please select 1-11, 98, 99, or 0." -ForegroundColor Red
        }
    }

    if ($selection -ne '0') {
        Write-Host "Press any key to return to the main menu..." -ForegroundColor Cyan
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
} while ($selection -ne '0')