
# Check the current execution policy
$executionPolicy = Get-ExecutionPolicy

# Check if the execution policy is Restricted
if ($executionPolicy -eq 'Restricted') {
    Write-Host "Running scripts is disabled on this system."
    Write-Host "Changing the execution policy to Unrestricted..."
    Set-ExecutionPolicy Unrestricted -Scope Process -Force
}

# Prompt the user for the VM name
$vm = Read-Host "Please enter the name of the virtual machine"

# Execute the cmdlet and store the output in a variable
$gpuInfo = Get-VMHostPartitionableGpu

# Extract properties from the output and store them in variables
$PartitionCount = $gpuInfo.PartitionCount
$TotalVRAM = $gpuInfo.TotalVRAM
$AvailableVRAM = $gpuInfo.AvailableVRAM
$MinPartitionVRAM = $gpuInfo.MinPartitionVRAM
$MaxPartitionVRAM = $gpuInfo.MaxPartitionVRAM
$OptimalPartitionVRAM = $gpuInfo.OptimalPartitionVRAM
$TotalEncode = $gpuInfo.TotalEncode
$AvailableEncode = $gpuInfo.AvailableEncode
$MinPartitionEncode = $gpuInfo.MinPartitionEncode
$MaxPartitionEncode = $gpuInfo.MaxPartitionEncode
$OptimalPartitionEncode = $gpuInfo.OptimalPartitionEncode
$TotalDecode = $gpuInfo.TotalDecode
$AvailableDecode = $gpuInfo.AvailableDecode
$MinPartitionDecode = $gpuInfo.MinPartitionDecode
$MaxPartitionDecode = $gpuInfo.MaxPartitionDecode
$OptimalPartitionDecode = $gpuInfo.OptimalPartitionDecode
$TotalCompute = $gpuInfo.TotalCompute
$AvailableCompute = $gpuInfo.AvailableCompute
$MinPartitionCompute = $gpuInfo.MinPartitionCompute
$MaxPartitionCompute = $gpuInfo.MaxPartitionCompute
$OptimalPartitionCompute = $gpuInfo.OptimalPartitionCompute


# Display the current Partition Count to the user
$partitionCount = $gpuInfo.PartitionCount
Write-Host "Current Partition Count is: $partitionCount"

# Prompt the user for the desired number of partitions
$userInput = Read-Host "Please enter the number of partitions you need"

# Validate the user input
if ($userInput -match '^\d+$') { # Check if input is a positive number
    $desiredPartitions = [int]$userInput
    
    # Example validation: Ensure desired partitions is positive and not greater than some maximum (adjust as needed)
    $maxPartitionsAllowed = $partitionCount - 1 # Example condition, adjust based on your logic
    if ($desiredPartitions -gt 0 -and $desiredPartitions -le $maxPartitionsAllowed) {
        Write-Host "You've requested to split into $desiredPartitions partitions."
        Add-VMGpuPartitionAdapter -VMName $vm
        # Set the GPU partition adapter for each VM accordingly
        Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionVRAM ($MaxPartitionVRAM - 20000000) -MaxPartitionVRAM $MaxPartitionVRAM -OptimalPartitionVRAM $OptimalPartitionVRAM `
            -MinPartitionEncode ($MaxPartitionEncode - 20000000) -MaxPartitionEncode $MaxPartitionEncode -OptimalPartitionEncode $OptimalPartitionEncode `
            -MinPartitionDecode ($MaxPartitionDecode - 20000000) -MaxPartitionDecode $MaxPartitionDecode -OptimalPartitionDecode $OptimalPartitionDecode `
            -MinPartitionCompute ($MaxPartitionCompute - 20000000) -MaxPartitionCompute $MaxPartitionCompute -OptimalPartitionCompute $OptimalPartitionCompute

        Set-VM -GuestControlledCacheTypes $true -VMName $vm
        Set-VM -LowMemoryMappedIoSpace 1Gb -VMName $vm
        Set-VM –HighMemoryMappedIoSpace 32GB –VMName $vm
        
        Write-Host "GPU partition adapter settings applied to $vm successfully."
    } else {
        Write-Host "Invalid number of partitions requested. Please enter a number from 1 to $maxPartitionsAllowed."
    }
} else {
    Write-Host "Invalid input. Please enter a valid number."
}
