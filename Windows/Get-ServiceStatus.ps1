function New-InputFile {
    param (
        # Path to the file
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Path
    )
    
    $Fields = 'ComputerName,Service,NotificationEmail','SVR001,WinRM,admin@domain.com;me@domain.com;you@domain.com,<< Use this line as a guide; delete it before using the script.'

    New-Item -Path $Path -ItemType File -Value ($Fields | Out-String).Trim() -Force
}

function Get-ServiceStatus {
    [CmdletBinding(DefaultParameterSetName='FromFile')]
    param (
        # Path to the input file
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='FromFile')]
        [string]
        $InputFilePath,

        # Switch to create a new template
        [Parameter(Mandatory=$true, ParameterSetName='NewTemplate')]
        [string]
        $NewTemplatePath,

        # From address, from which the email should be sent
        [Parameter(Mandatory=$true)]
        [string]
        $From
    )

    begin {
        if ($NewTemplatePath) {
            if (Test-Path $NewTemplatePath) {
                $NewTemplatePathItem = Get-Item $NewTemplatePath
                if ($NewTemplatePathItem.PsIsContainer) {
                    Write-Verbose "The path given is that of a directory. Creating a new input file in the directory."
                    New-InputFile -Path "$NewTemplatePath\Input.csv"
                }
                elseif ($NewTemplatePathItem.Extension -eq '.csv') {
                    if (Read-Host "A file exists at the specified path. Would you like to overwrite it?" -imatch '^y') {
                        New-InputFile -Path $NewTemplatePath
                    }
                }
                else {
                    Write-Verbose "The path specified is neither a directory, nor a CSV file."
                    break
                }
            }
            elseif ($NewTemplatePath -match '\.csv$') {
                Write-Verbose 'Creating a new CSV file at the path specified.'
                New-InputFile -Path $NewTemplatePath
            }
            else {
                New-InputFile -Path "$NewTemplatePath\Input.csv"
            }
        }
        else {
            try {
                Write-Verbose 'Importing contents of the input file.'
                $ServiceRecords = Import-Csv $InputFilePath -ErrorAction Stop
            }
            catch {
                Write-Warning $_
                Write-Error 'Could not read the file.'
                break
            }
        }
    }

    process {
        foreach ($Record in $ServiceRecords) {
            Get-Service -Name $Record.Service -ComputerName $Record.ComputerName
        }
    }
}