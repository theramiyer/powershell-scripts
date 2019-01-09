function Get-ExchangeInventory {
    <#
    .SYNOPSIS
    Query an inventory of all the databases in the environment, with relevant statistics.

    .DESCRIPTION
    Query a complete inventory of all the databases in the environment, with relevant statistics such as the database name, the size, total item sizes of mailboxes for each database, the server and the drive on which the database is stored, whitespace details, etc.

    .PARAMETER MailboxServerFqdn
    The FQDN of an Exchange server, preferably a mailbox database server.

    .EXAMPLE
    Get-ExchangeInventory -MailboxServerFqdn EXMB001

    .NOTES
    Created by Ram Iyer (https://ramiyer.me)
    #>
    [CmdletBinding()]
    param (
        # The FQDN of a mailbox database server
        [Parameter(Mandatory=$true,Position=0)]
        [string]
        $MailboxServerFqdn
    )
    begin {
        $Statistics = @()

        try {
            Write-Verbose 'Intiating a PowerShell session to the Exchange server.'
            $ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ExServerFqdn -Authentication Kerberos -ErrorAction Stop
            Import-PSSession $ExchangeSession -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        }
        catch {
            try {
                Write-Verbose 'Initiation of the session failed. Trying alternate credentials.'
                Write-Warning "You do not have necessary access. Attempting fallback method."
                $Credentials = Get-Credential -Message "Enter the credentials that have 'Mailbox import-export permissions.'"
                $ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ExServerFqdn -Credential $Credentials -Authentication Kerberos -ErrorAction Stop
                Import-PSSession $ExchangeSession -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
            }
            catch {
                Write-Verbose 'Initiation of the session with alternate credentials failed.'
                Write-Error 'Unable to connect to the Exchange Server. Please check your credentials, or contact your Exchange Administrator.'
                Write-Verbose 'Aborting operation.'
                break
            }
        }
    }
    process {
        Write-Verbose 'Querying a list of all databases in the environment.'
        $DatabaseList = (Get-MailboxDatabase | Select-Object Name -ExpandProperty Name | Sort-Object)

        foreach ($Database in $DatabaseList) {
            Write-Verbose "Getting details for $Database."
            $DatabaseDetails    = Get-MailboxDatabase $Database -Status
            Write-Verbose "Getting statistics for $Database."
            $MailboxStatistics  = Get-MailboxStatistics -Database $Database

            $TotalItemSize      = ($MailboxStatistics | ForEach-Object { $PsItem.$TotalItemSize.Value.ToBytes() } | Measure-Object -Sum).Sum/1GB
            $MailboxCount       = $MailboxStatistics.Count
            $DatabaseSize       = $DatabaseDetails.DatabaseSize.ToBytes()/1GB
            $DatabaseDrive      = $DatabaseDetails.EdbFilePath.DriveName
            $ServerName         = $DatabaseDetails.Server.Name
            $WhiteSpace         = $DatabaseDetails.AvailableNewMailboxSpace.ToBytes()/1GB
            $Difference         = $DatabaseSize - $TotalItemSize
            $FreeSpace          = ((Get-WmiObject Win32_LogicalDisk -ComputerName $ServerName -Filter "DeviceID='$DbDrive'").FreeSpace)/1GB
            $PercentFreeSpace   = ((Get-WmiObject Win32_LogicalDisk -ComputerName $ServerName -Filter "DeviceID='$DbDrive'").FreeSpace / (Get-WmiObject Win32_LogicalDisk -ComputerName ($DatabaseDetails.Server.Name) -Filter "DeviceID='$DbDrive'").Size) * 100

            Write-Verbose "Creating a record for $Database."
            $Fields = [ordered]@{
                ServerName        = $ServerName
                DatabaseName      = $DatabaseName
                DatabaseSizeGB    = [math]::Round($DatabaseSize, 2)
                MailboxCount      = $MbCount
                TotalItemSizeGB   = [math]::Round($TotalItemSize, 2)
                WhitespaceGB      = [math]::Round($WhiteSpace, 2)
                DifferenceGB      = [math]::Round($Difference, 2)
                Drive             = $DbDrive
                FreeSpaceGB       = [math]::Round($FreeSpace, 2)
                PercentFreeSpace  = [math]::Round($PercentFreeSpace, 2)
            }

            $Statistics += New-Object -TypeName PsObject -Property $Fields
        }

        Write-Verbose "Completed fetching information for all the databases."
        $Statistics
    }
    end {
        Write-Verbose "Terminating the session to the Exchange server."
        Remove-PSSession $ExchangeSession
    }
}
