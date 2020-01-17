#Requires -Version 5

function main {
    Add-BulkUsersToDl -DistributionGroupName 'My-Cool-Dl' -CsvPath '\\path\to\file.csv' 6> '\\path\to\error.txt'
}

function Add-BulkUsersToDl {
    param (
        # The name of the distribution group
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $DistributionGroupName,

        # Path to the CSV file
        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $CsvPath
    )

    begin {
        try {
            $Members = (Import-Csv $CsvPath -ErrorAction Stop).Email | Sort-Object -Unique
        }
        catch {
            Write-Error "Could not import the CSV; please check if the CSV exists at the path, check it has 'Email' as the email column header, and try again."
        }

        try {
            Get-DistributionGroup $DistributionGroupName -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "$DistributionGroupName invalid"
            break
        }
    }

    process {
        foreach ($Member in $Members) {
            try {
                Add-DistributionGroupMember $DistributionGroupName -Member $Member -ErrorAction Stop
            }
            catch {
                Write-Information $Member
            }
        }
    }
}

main
