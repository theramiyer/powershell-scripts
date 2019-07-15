function Get-PublicFolderSendAsPermission {
    [CmdletBinding()]
    param (
        # The FQDN of an Exchange server
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $ExServerFqdn
    )
    begin {
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

        $List = @()
        $AccessList = @()

        Write-Verbose 'Fetching a list of all mail-enabled public folders'
        $PublicFolderList = Get-MailPublicFolder -ResultSize Unlimited | Select-Object Alias, DistinguishedName
    }
    process {
        foreach ($PublicFolder in $PublicFolderList) {
            Write-Verbose "Getting send-as permissions on for $($PublicFolder.DistinguishedName)"
            $List += Get-ADPermission -Identity $PublicFolder.DistinguishedName | Where-Object { ($PSItem.ExtendedRights -match 'send-as') -and ($PSItem.User -notmatch 'HQNT\\XHQCIC') } | Select-Object Identity, User
            Write-Verbose "Getting public folder details of $($PublicFolder.DistinguishedName)"
            $FolderDetails = Get-Recipient $PublicFolder.DistinguishedName | Get-PublicFolder
            Write-Verbose "Processing the permissions fetched for $($FolderDetails.Identity)"
            foreach ($Item in $List) {
                Write-Verbose "Processing properties for $($Item.User)"
                $FolderProperties = [ordered]@{
                    PublicFolder = $FolderDetails.Name
                    FolderPath = $FolderDetails.Identity
                    User = $Item.User
                }
                Write-Verbose "Adding permissions given to $($Item.User), to the final output object"
                $AccessList += New-Object PsObject -Property $FolderProperties
            }
        }
        $AccessList
    }
}
