function Clear-Repository {
    param(
        # Path to the UPM repository
        [Parameter(Mandatory=$true, Position=1)]
        [string]
        $Path,

        # Name of the folder to be removed
        [Parameter(Mandatory=$false)]
        [string]
        $SubDirectory
    )
    begin {
        try {
            Write-Verbose "Testing connection to the path, $Path."
            $null = Test-Path -Path $Path -ErrorAction Stop
        }
        catch {
            Write-Error "Unable to reach the path, $Path."
            break
        }
        $DeletionTable = @()
    }
    process {
        $ChildItems = (Get-ChildItem $Path | Where-Object PsIsContainer | Select-Object FullName).FullName

        foreach ($Item in $ChildItems) {
            $DeletionStatus = $null
            $FolderSize     = $null

            if ($SubDirectory) {
                Write-Verbose "Joining the subdirectory to the path."
                $Item = Join-Path -Path $Item -ChildPath $SubDirectory
                Write-Verbose "The full path is $Item."
            }

            Write-Verbose "Testing if $Item exists."
            if (Test-Path -Path $Item) {
                $PathExists = $true
                try {
                    try {
                        Write-Verbose "Calculating folder size."
                        $FolderSize = [math]::Round(((Get-ChildItem -Path $Item -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum/1MB), 2)
                    }
                    catch {
                        Write-Verbose 'Folder size could not be determined.'
                    }
                    Write-Verbose "Attempting to delete the folder, $Item and its contents."
                    Remove-Item -LiteralPath $Item -Recurse -Force -WhatIf -ErrorAction Stop
                    $DeletionStatus = 'Deleted'
                }
                catch {
                    $DeletionStatus = 'Error'
                    Write-Error "Unable to delete $Item."
                }
            }
            else {
                Write-Verbose "$Item doesn't exist."
                $PathExists     = $false
            }

            $DeletionTable += New-Object -TypeName PsObject -Property @{
                Location        = $Item
                PathExists      = $PathExists
                DeletionStatus  = $DeletionStatus
                FolderSizeMB    = $FolderSize
            }
        }
        $DeletionTable | Select-Object Location, PathExists, DeletionStatus, FolderSizeMB
    }
}

function Clear-ProfileData {
    param(
        # List of servers
        [Parameter(Mandatory=$true, Position=1)]
        [string[]]
        $FilePath
    )

    begin {
        try {
            Test-Path $FilePath -ErrorAction Stop
        }
        catch {
            Write-Error "Unable to reach $FilePath"
            break
        }
    }

    process {
        $InputObject = Import-Csv $FilePath
        foreach ($Object in $InputObject) {
            Clear-Repository -Path $Object.ProfilePath -SubDirectory $Object.ChildPath
        }
    }
}
