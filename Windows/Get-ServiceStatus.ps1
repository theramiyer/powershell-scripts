function main {
    Get-ServiceStatus -InputFilePath '\\path\to\input-file.csv' -From 'bot@domain.com' -SmtpServer 'smtp@domain.com'

    <#
        The input file should have three columns, named, "ComputerName", "Service" and "NotificationEmail". You can have more columns if you want to use the same file for different purposes; this script will use only those three columns.

        If you need multiple services to be monitored on a single server, make multiple entries. Like so:

        SVR001  |  WinRM  | someone@domain.com
        SVR001  |  Store  | someone@domain.com;another@domain.com

        Service should contain the service name (NOT the display name).

        NotificationEmail can have multiple addresses, a semicolon (;) should be used to split the addresses. Like so: me@domain.com;you@domain.com;they@domain.com.

        DO NOT use quotes anywhere in the input file. It can confuse the script.
    #>
}

function New-InputFile {
    param (
        # Path to the file
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $Path
    )
    
    $Fields = 'ComputerName,Service,NotificationEmail','SVR001,WinRM,admin@domain.com;me@domain.com;you@domain.com,<< Use this line as a guide; delete it before using the script.'

    New-Item -Path $Path -ItemType File -Value ($Fields | Out-String).Trim() -Force
    Write-Host "New file was successfully created at $Path"
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
        [Parameter(Mandatory=$true, ParameterSetName='FromFile')]
        [string]
        $From,

        # SMTP server FQDN
        [Parameter(Mandatory=$true, ParameterSetName='FromFile')]
        [string]
        $SmtpServer
    )

    begin {
        if ($InputFilePath) {
            try {
                Write-Verbose 'Importing contents of the input file.'
                $ServiceRecords = Import-Csv $InputFilePath -ErrorAction Stop
            }
            catch {
                Write-Warning $PSItem.Exception
                Write-Error 'Could not read the file.'
                break
            }
        }

        $style = "<style>BODY{font-family:'Segoe UI';font-size:10pt;line-height: 120%}h1,h2{font-family:'Segoe UI Light';font-weight:normal;}TABLE{border:1px solid white;background:#f5f5f5;border-collapse:collapse;}TH{border:1px solid white;background:#f0f0f0;padding:5px 10px 5px 10px;font-family:'Segoe UI Light';font-size:13pt;font-weight: normal;}TD{border:1px solid white;padding:5px 10px 5px 10px;}</style>"
        
        $ServiceStatusTable = @()
    }
    
    process {
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
                    Write-Warning "The path specified is neither a directory, nor a CSV file. Attempting to create the file anyway."
                    New-InputFile -Path $NewTemplatePath
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
            foreach ($Record in $ServiceRecords) {
                try {
                    $ServiceStatus = (Get-Service -Name $Record.Service -ComputerName $Record.ComputerName -ErrorAction Stop).Status
                }
                catch {
                    $ServiceStatus = $PSItem.Exception
                }
    
                $ServiceStatusTable += New-Object PsObject -Property @{
                    ComputerName      = $Record.ComputerName
                    ServiceName       = $Record.Service
                    Status            = $ServiceStatus
                    NotificationEmail = $Record.NotificationEmail
                }
            }
    
            $StoppedServices = $ServiceStatusTable |
             Where-Object Status -ne 'Running' |
               Group-Object NotificationEmail

            if ($StoppedServices) {
                foreach ($Group in $StoppedServices) {
                    $FilteredStoppedServices = $Group.Group |
                     Select-Object ComputerName, ServiceName, Status |
                      ConvertTo-Html -As Table -Fragment | Out-String
        
                    $Body = ConvertTo-Html -Head $style -Body '<p>Hi Team,</p><p>The following services were found to be not running when the status was checked by the Automated Service Status Check monitor.</p>', $FilteredStoppedServices, '<p>Please take actions as necessary.</p><p>Thanks,<br />Service Check Bot</p>' | Out-String
        
                    Send-MailMessage -From $From -To ($Group.Name -split ';').Trim() -SmtpServer $SmtpServer -Subject 'Services found to be not running' -Body $Body -BodyAsHtml
                }
            }
        }
    }
}

main