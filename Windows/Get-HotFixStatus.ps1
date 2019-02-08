function Get-HotFixStatus { # Incomplete, quick-and-dirty mode
    $Results = $()
    
    $computers = Get-Content C:\scripts\computers\computers.txt
    $patches = Get-Content C:\scripts\computers\kb.txt
    
    foreach ($Computer in $Computers) {
        foreach ($Patch in $Patches) {
            try {
                if (Get-HotFix -Id $Patch -ComputerName $Computer -ErrorAction Stop) {
                    $PatchStatus = $true
                }
                else {
                    $PatchStatus = $false
                }
            }
            catch {
                $PatchStatus = $false
            }
            $Results += New-Object PsObject -Property @{
                ComputerName = $Computer
                PatchId = $Patch
                Status = $PatchStatus
            }
        }
    }
    
    $Results
}
