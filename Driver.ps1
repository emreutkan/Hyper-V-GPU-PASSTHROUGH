# Check the current execution policy
$executionPolicy = Get-ExecutionPolicy

# Check if the execution policy is Restricted
if ($executionPolicy -eq 'Restricted') {
    Write-Host "Running scripts is disabled on this system."
    Write-Host "Changing the execution policy to Unrestricted..."
    Set-ExecutionPolicy Unrestricted -Scope Process -Force
}


# Prompt the user about system configuration updates
$userConfirmation = Read-Host "Have you disabled enhanced session mode, checkpoints in Hyper-V settings, and updated your Nvidia GPU drivers? (yes/no)"

# Check the user's response and stop the script if not 'yes'
if ($userConfirmation -ne 'yes') {
    Write-Host "Please complete the required system configuration updates before proceeding."
    return
}


# Prompt the user about Nvidia GPU drivers
$userConfirmation = Read-Host "Do you want to copy Nvidia GPU drivers that will be sent to VM (you have to do it manually if you say no)? (yes/no)"

# Check if the user's response is 'yes'
if ($userConfirmation.ToLower() -eq 'yes') {
    # User confirmed 'yes'
    Write-Host "User confirmed 'yes'. Proceeding with copying Nvidia GPU drivers."

    # Create the destination folder if it doesn't exist
    if (-not (Test-Path -Path $destinationFolder -PathType Container)) {
        try {
            New-Item -Path $destinationFolder -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "Error creating folder: $_"
            return
        }
    }
    # Set the destination folder path for copying NV files
    $destinationFolder = "C:\NV_Files"
    # Set the source folder path
    $sourceFolder = "C:\Windows\System32"

    # Copy files from the source folder to the destination folder recursively
    if (Test-Path -Path $sourceFolder -PathType Container) {
        Get-ChildItem -Path $sourceFolder -File -Recurse | 
            Where-Object { $_.Name -like "nv*" } |
            ForEach-Object {
                $destinationFile = Join-Path -Path $destinationFolder -ChildPath $_.FullName.Substring($sourceFolder.Length + 1)
                # Create the destination folder if it doesn't exist
                $null = New-Item -Path (Split-Path -Path $destinationFile) -ItemType Directory -Force
                # Copy the file to the destination folder
                Copy-Item -Path $_.FullName -Destination $destinationFile -Force
                Write-Host "Copying file: $($_.Name)"
            }
        Write-Host "Copied all files starting with 'nv' to $destinationFolder"
        # Copying done, now we rename the DriverStore folder to HostDriverStore
        
        # Get the DriverStore folder path
        $driverStoreFolder = Join-Path -Path $destinationFolder -ChildPath "DriverStore"

        # Get the HostDriverStore folder path
        $hostDriverStoreFolder = Join-Path -Path $destinationFolder -ChildPath "HostDriverStore"

        # Check if DriverStore folder exists
        if (Test-Path -Path $driverStoreFolder -PathType Container) {
            # Rename the DriverStore folder to HostDriverStore
            Move-Item -Path $driverStoreFolder -Destination $hostDriverStoreFolder -Force
            Write-Host "Renamed 'DriverStore' folder to 'HostDriverStore'"
        } else {
            Write-Host "DriverStore folder not found in $destinationFolder"
        }
    } else {
        Write-Host "Source folder not found: $sourceFolder"
    }
} else {
    # User did not confirm 'yes'
    Write-Host "User did not confirm 'yes'. Please complete the required system configuration updates before proceeding."
}



# Prompt the user about system configuration updates
$userConfirmation = Read-Host "Do you want to Copy Drivers to Virtual Machine (if no you have to copy all files under  $sourceFolder to the virtual machines `System32` folder ? (yes/no)"

# Check the user's response and stop the script if not 'yes'
if ($userConfirmation -eq 'yes') {
    Add-Type -AssemblyName System.Windows.Forms

    # Set up the file dialog box
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.InitialDirectory = "C:\ProgramData\Microsoft\Windows\Virtual Hard Disks"
    $fileDialog.Filter = "Virtual Hard Disk files (*.vhd, *.vhdx)|*.vhd;*.vhdx|All files (*.*)|*.*"
    $fileDialog.Title = "Select Virtual Hard Disk File"

    # Display the file dialog box and wait for user input
    $result = $fileDialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedImagePath = $fileDialog.FileName

        try {
            # Mount the virtual disk and retrieve the drive letter
            $driveLetter = (Mount-VHD -Path $selectedImagePath -PassThru | Get-Disk | Get-Partition | Get-Volume).DriveLetter

            if ($driveLetter -ne $null) {
            Write-Host "Type of driveLetter: $($driveLetter.GetType())"
                Write-Host "Virtual disk mounted successfully with drive letter: $driveLetter"
                
                # Ensure $driveLetter is a single character
                if ($driveLetter -is [array]) {
                    foreach ($letter in $driveLetter) {
                        if (-not [string]::IsNullOrWhiteSpace($letter)) {
                            $driveLetter = $letter
                            break
                        }
                    }
                }

                if ($driveLetter -eq 'C') {
                    Write-Host "Drive letter is 'C'. Exiting script. this is to exit the script if the system detects the main drive as the mounted drive"
                    Write-Host "if your main disk is not on C and your mounted drive mounts to C then delete this if function in the source code"
                    Write-Host "Open GPUPass.ps1 hit ctrl+f and search $driveLetter -eq 'C' then delete all until # Construct the destination folder path "
                    break
                }
                # Construct the destination folder path
                $destinationFolder = "${driveLetter}:\Windows\System32"
                # Get the current username
                $currentUsername = $env:USERNAME
                # Set the path of the System32 folder
                $system32Folder = "${driveLetter}:\Windows\System32"

                # Create a new Access Rule allowing Full Control for the current user account
                $permission = New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $env:USERNAME,
                    'FullControl',
                    'None',  # Remove inheritance and propagation flags for files
                    'None',
                    'Allow'
                )

                try {
                    # Get the Security Descriptor for the System32 folder
                    $aclSystem32 = Get-Acl -Path $system32Folder

                    # Apply the modified Security Descriptor to the System32 folder
                    $aclSystem32.SetAccessRule($permission)
                    Set-Acl -Path $system32Folder -AclObject $aclSystem32

                    # Apply permissions recursively to all files and folders within System32 folder
                    Get-ChildItem -Path $system32Folder -Recurse | ForEach-Object {
                        $item = $_.FullName
                        $aclItem = $null  # Ensure $aclItem is initialized
                        try {
                            $aclItem = Get-Acl -Path $item
                            if ($aclItem -eq $null) {
                                $aclItem = New-Object System.Security.AccessControl.DirectorySecurity
                            }
                            $aclItem.SetAccessRule($permission)
                            Set-Acl -Path $item -AclObject $aclItem
                        } catch {
                            Write-Host "Error applying permissions to ${item}: $_"
                        }
                    }
                } catch {
                    Write-Host "Error: $_"
                }

                # Copy contents of C:\NV_Files to the mounted volume's System32 folder
                $sourceFolder = "C:\NV_Files"

                if (Test-Path -Path $sourceFolder -PathType Container) {
                    Write-Host "Copying contents of $sourceFolder to $destinationFolder"
                    Copy-Item -Path $sourceFolder\* -Destination $destinationFolder -Recurse -ErrorAction Stop -Force
                    Write-Host "Copy completed."


                } else {
                    Write-Host "Source folder not found: $sourceFolder"
                }
            } else {
                Write-Host "Virtual disk mounted successfully, but no drive letter assigned."
            }
        } catch {
            Write-Host "$_"
        } finally {
            # Unmount the virtual disk even if an error occurred
            if (Test-Path -Path $selectedImagePath) {
                Dismount-VHD -Path $selectedImagePath
                Write-Host "Virtual disk detached successfully."
            }
        }
    } else {
        Write-Host "Operation canceled by the user."
    }
} else {
    # User did not confirm 'yes'
    Write-Host "User did not confirm 'yes'. Please complete the required system configuration updates before proceeding."
}


# Get the GPU Information
$gpuInfo = Get-VMHostPartitionableGpu

# Save OptimalPartitionVRAM to a variable
$optimalPartitionVRAM = $gpuInfo.OptimalPartitionVRAM

# Save TotalEncode to another variable
$totalEncode = $gpuInfo.TotalEncode

# Extract the Partition Count
$partitionCount = $gpuInfo.PartitionCount

# Display the current Partition Count to the user
Write-Host "Current Partition Count is: $partitionCount"

# Prompt the user for the desired number of partitions
$userInput = Read-Host "Please enter the number of partitions you need"

# Validate the user input
# Make sure it's an integer and within a valid range (optional)
# Note: Adjust the validation as necessary based on your requirements
if ($userInput -match '^\d+$') { # Check if input is a positive number
    $desiredPartitions = [int]$userInput
    
    # Example validation: Ensure desired partitions is positive and not greater than some maximum (adjust as needed)
    $maxPartitionsAllowed = $partitionCount-1 # Example condition, adjust based on your logic
    if ($desiredPartitions -gt 0 -and $desiredPartitions -le $maxPartitionsAllowed-1) {
        Write-Host "You've requested to split into $desiredPartitions partitions."
        Write-Host "Optimal Partition VRAM : $optimalPartitionVRAM"
        Write-Host "Total Encode : $totalEncode"
        # Insert logic here to handle the partitioning based on user input
    } else {
        Write-Host "Invalid number of partitions requested. Please enter a number from 1 to $maxPartitionsAllowed."
    }
} else {
    Write-Host "Invalid input. Please enter a valid number."
}
