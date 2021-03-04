function main {
    begin {
        $Wintel             = 'citrixadmins@domain.com', 'windowsadmins@domain.com'
        $Servers            = 'CTXSVR000', 'CTXSVR001', 'CTXSVR002', 'CTXSVR003', 'CTXSVR004', 'CTXSVR005', 'CTXSVR006', 'CTXSVR007', 'CTXSVR008', 'CTXSVR009', 'CTXSVR010', 'CTXSVR011', 'CTXSVR012', 'CTXSVR013'
        $Controller         = 'CTXCTL.domain.com'
        $ExcludedServices   = 'clr_optimization_v4.0.30319_64', 'clr_optimization_v4.0.30319_32', 'sppsvc', 'stisvc'
        $style              = "<style>BODY{font-family:'Segoe UI';font-size:10pt;line-height: 120%}h1,h2{font-family:'Segoe UI Light';font-weight:normal;}TABLE{border:1px solid white;background:#f5f5f5;border-collapse:collapse;}TH{border:1px solid white;background:#f0f0f0;padding:5px 10px 5px 10px;font-family:'Segoe UI Light';font-size:13pt;font-weight:normal;}TD{border:1px solid white;padding:5px 10px 5px 10px;}</style>"
        $SmtpServer         = 'smtp.domain.com'
        $From               = 'CitrixMonitor@domain.com'
        $Subject            = 'Post-reboot service check on Citrix Servers'
        $ServerStatusReport = @()
    }
    process {
        $ServiceStatus = Get-ServiceStatus -ComputerName $Servers -Exclude $ExcludedServices

        if ($ServiceStatus) {
            $ServiceStatusReport = $ServiceStatus | Select-Object ServerName, ServiceName | ConvertTo-Html -As Table -Fragment -PreContent '<h2>Service Status</h2><p>Here are the services that are set to start automatically on each of the Citrix servers, but are not running post reboot.</p>' | Out-String
        }
        else {
            $ServiceStatusReport = '<h2>Service Status</h2><p>All the critical services on all the Citrix servers are running after the reboot.</p>'
        }

        foreach ($Server in $Servers) {
            $WindowsStatus            = Get-WindowsStatus -ComputerName $Server
            $CitrixStatus             = Get-CitrixStatus -ControllerFqdn $Controller -ComputerFqdn "$Server.domain.com"
            $ServerStatusReportEntry  = [ordered]@{
                Server            = $Server
                RdpPortOpen       = $WindowsStatus.RdpPortOpen
                UpTimeMins        = $WindowsStatus.UpTimeMins
                RegistrationState = $CitrixStatus.RegistrationState
                InMaintenanceMode = $CitrixStatus.MaintenanceMode
            }

            $ServerStatusReport += New-Object PSObject -Property $ServerStatusReportEntry
        }

        $ServerStatusReport = $ServerStatusReport | ConvertTo-Html -As Table -Fragment -PreContent '<h2>Server Status</h2><p>Also, here is a look at the other important parameters pertaining to the Citrix servers.</p>' | Out-String

        $Body = ConvertTo-Html -Head $Style -Body '<p>Hi Team,</p><p>The post-reboot service test was run on the Citrix servers. The service status report follows.</p><h1>Citrix Server Health Check Report</h1>', $ServiceStatusReport, $ServerStatusReport, '<p>Have a great day!</p><p>Regards,<br>Citrix Master Monitor</p>' | Out-String

        Send-MailMessage -SmtpServer $SmtpServer -From $From -To $Wintel -Subject $Subject -Body $Body -BodyAsHtml
    }
}

function Get-WindowsStatus {
    param (
        # Server names
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $ComputerName,

        # The RDP port number
        [Parameter(Mandatory=$false, Position=1)]
        [string]
        $Port = '3389'
    )
    if (Test-Connection $ComputerName -Count 1 -Quiet) {
        try {
            $Null = New-Object System.Net.Sockets.TCPClient -ArgumentList $ComputerName, $Port -ErrorAction Stop
            $PortStatus = 'Yes'
        }
        catch {
            $PortStatus = 'No'
        }
    }
    else {
        $PortStatus = 'No'
    }
    try {
        $Osdetails = Get-WmiObject win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop
        $UpTimeRaw = (Get-Date) - ($Osdetails.ConvertToDateTime($Osdetails.LastBootupTime))
        $UpTime    = [math]::Round($UpTimeRaw.TotalMinutes, 0)
    }
    catch {
        $UpTime = 'Unable to fetch'
    }
    $Properties = [ordered]@{
        Server      = $ComputerName
        RdpPortOpen = $PortStatus
        UpTimeMins  = $UpTime
    }
    New-Object PsObject -Property $Properties
}

function Get-CitrixStatus {
    param (
        # Server FQDN
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $ComputerFqdn,

        # Controller FQDN
        [Parameter(Mandatory=$true, Position=1)]
        [string]
        $ControllerFqdn
    )
    begin {
        try {
            if (!(Get-PSSnapin Citrix* -ErrorAction SilentlyContinue)) {
                Add-PSSnapin Citrix*
            }
            else {
                Write-Verbose "Citrix snap-in is already loaded"
            }
        }
        catch {
            Write-Warning "Unable to load the Citrix snap-in"
            break
        }
    }
    process {
        try {
            $BrokerMachine = Get-BrokerMachine -AdminAddress $ControllerFqdn -DNSName $ComputerFqdn -Property InMaintenanceMode -ErrorAction Stop

            $MaintMode = $BrokerMachine.InMaintenanceMode
            $RegState  = $BrokerMachine.RegistrationState
        }
        catch {
            $MaintMode = 'Unable to fetch'
            $RegState  = 'Unable to fetch'
        }
        $Properties = [ordered]@{
            Server            = $ComputerFqdn
            MaintenanceMode   = $MaintMode
            RegistrationState = $RegState
        }
        New-Object PsObject -Property $Properties
    }
}

function Get-ServiceStatus {
    param (
        # Names of the servers
        [Parameter(Mandatory=$true, Position=0)]
        [string[]]
        $ComputerName,

        # Services to be excluded
        [Parameter(Mandatory=$false, Position=1)]
        [string[]]
        $Exclude = $null
    )
    begin {
        $ServiceTable = @()
    }
    process {
        foreach ($Server in $ComputerName) {
            $Services = (Get-WmiObject win32_service -Filter "StartMode = 'auto' AND state != 'Running'" -ComputerName $Server |
                Where-Object Name -notin $Exclude).DisplayName
            foreach ($Service in $Services) {
                $Properties     = [ordered]@{
                    ServerName  = $Server
                    ServiceName = $Service
                }
                $ServiceTable += New-Object PSObject -Property $Properties
            }
        }
        $ServiceTable
    }
}

main # Call the main function
