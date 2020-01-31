function Remove-Email {
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    param (
        # Username
        [Parameter(Mandatory=$true)]
        [string]
        $Sender,

        # Recipients; may be mailbox or distribution group
        [Parameter(Mandatory=$false)]
        [string]
        $Recipient,

        # Subject of the email
        [Parameter(Mandatory=$true)]
        [string]
        $Subject,

        # Date from
        [Parameter(Mandatory=$false)]
        [string]
        $Start = (Get-Date -Format d),

        # Date to
        [Parameter(Mandatory=$false)]
        [string]
        $End = (Get-Date -Format d),

        # Delete the email
        [Parameter(Mandatory=$false)]
        [switch]
        $Delete,

        # Report recipients
        [Parameter(Mandatory=$true)]
        [string]
        $ReportRecipient,

        # Folder to store the search results in
        [Parameter(Mandatory=$false)]
        [string]
        $TargetFolder = 'SearchResults'
    )

    begin {
        try {
            Get-ExchangeServer $env:COMPUTERNAME -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "Log into an Exchange server with an account that has the Discovery Management role assigned, and run this on the Exchange Management Shell."
            break
        }

        try {
            Get-Mailbox $ReportRecipient -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Error "Unable to locate the mailbox for $ReportRecipient. Process aborted."
            break
        }
    }

    process {
        if ($Subject -match '^(FW:|RE:)') {
            $Subject = $Subject -replace '^(FW:|RE:)' -replace '^\ '
        }

        $QueryString = "FROM:`"$Sender`" AND SUBJECT:`"$Subject`" AND RECEIVED:$Start..$End"

        if ($Recipient) {
            $RecipientType = (Get-Recipient $Recipient).RecipientType

            switch ($RecipientType) {
                'MailUniversalDistributionGroup' {
                    $Command = "Get-DistributionGroupMember '$Recipient' | Get-Mailbox"
                    break
                }
                'MailNonUniversalGroup' {
                    $Members = Get-ADGroupMember $(Get-Recipient $Recipient).Name | ForEach-Object { Get-Mailbox $PsItem.SamAccountName }
                    $Command = '$Members'
                    break
                }
                'UserMailbox' {
                    $Command = "Get-Mailbox '$Recipient'"
                }
                Default {
                    Write-Error "Invalid recipient type. Please check the Recipient parameter."
                    break
                }
            }
        }
        else {
            $Command = "Get-Mailbox -ResultSize Unlimited"
        }

        $Command += " | Search-Mailbox -SearchQuery '$QueryString' -TargetMailbox '$ReportRecipient' -TargetFolder $TargetFolder -LogLevel Full -LogOnly"

        $EmailStats = Invoke-Expression -Command $Command | Measure-Object -Property ResultItemsCount -Sum

        # Check if the admin wants the email deleted; don't delete it right away.
        if ($Delete) {
            if ($PSCmdlet.ShouldProcess("$($EmailStats.Sum) emails with subject, '$Subject' from $($EmailStats.Count) mailboxes", "Delete")) {
                $Command = $Command.Replace(" -TargetFolder $TargetFolder -LogLevel Full -LogOnly", " -TargetFolder $($TargetFolder + '-Deleted-' + $(Get-Date -Format "yyyy-MM-dd")) -DeleteContent" + ' -Confirm:$false -Force')
            }
            Invoke-Expression -Command $Command | Out-Null
        }
    }
}
