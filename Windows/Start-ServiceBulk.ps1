function main {
    Start-ServiceBulk '\\path\to\input-file.csv'
}

function Start-ServiceBulk {
    <#
    .SYNOPSIS
    Cmdlet to start multiple services on multiple computers
    
    .DESCRIPTION
    This cmdlet accepts the path to a CSV file, with two relevant columns in it being ComputerName and Service. In case multiple services must be started on a certain server, each service name should be a separate entry. The cmdlet starts the service on the corresponding computer.
    
    .PARAMETER InputFilePath
    Path to the input CSV file. A complete path (UNC is allowed) is recommended.
    
    .EXAMPLE
    Start-ServiceBulk 'C:\Scripts\ServiceStarter.csv'
    
    .NOTES
    Created by Ram Iyer
    #>
    [cmdletbinding()]
    param (
        # Path to the input file
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $InputFilePath
    )

    begin {
        try {
            Write-Verbose "Checking if $InputFilePath exists."
            $null = Test-Path $InputFilePath -ErrorAction Stop
        }
        catch {
            Write-Error "Valid input file not found at $InputFilePath."
            break
        }
        $ErrorLog = @()
    }

    process {
        $ServiceEntries = Import-Csv $InputFilePath

        foreach ($Entry in $ServiceEntries) {
            try {
                Write-Verbose "Testing connection to $($Entry.ComputerName)."
                if (Test-Connection -ComputerName $Entry.ComputerName -Count 1 -TimeToLive 5 -Quiet -ErrorAction SilentlyContinue) {
                    Write-Verbose "Connection successful."
                    Write-Verbose "Starting service, $($Entry.Service), on $($Entry.ComputerName)."
                    Get-Service -Name $Entry.Service -ComputerName $Entry.ComputerName -ErrorAction Stop | Start-Service -ErrorAction Stop
                }
                else {
                    Write-Verbose "$($Entry.ComputerName) could not be reached."
                    $ErrorLog += "Unable to reach $($Entry.ComputerName)."
                }
            }
            catch {
                Write-Warning $_
                $ErrorLog += "Unable to find/start $($Entry.Service) on $($Entry.ComputerName)."
            }
        }
        if ($ErrorLog) {
            Write-Verbose "There were errors in the operation. Exporting log."
            $ErrorLogFile = "$env:TEMP\StartServiceBulkLog.txt"
            $ErrorLog | Out-File $ErrorLogFile
            Write-Verbose "Opening error log, $ErrorLogFile"
            Invoke-Item $ErrorLogFile
        }
    }
}

main
