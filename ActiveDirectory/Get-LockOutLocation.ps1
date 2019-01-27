function Get-LockOutLocation {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$True)]
        [String]$Identity
    )

    begin {
        try{
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        catch {
            Write-Output 'Unable to add Active Directory module'
            break
        }
    }

    process {
        $DcList = Get-ADDomainController -Filter *
        $PDCEmulator = ($DcList | Where-Object OperationMasterRoles -contains "PDCEmulator")

        Write-Verbose "Scanning the domain controllers in the domain for the user's last bad password attempt."
        foreach ($Dc in $DcList) {
            try {
                $UserInfo = Get-ADUser -Identity $Identity -Server $Dc.Hostname -Properties AccountLockoutTime, `
                LastBadPasswordAttempt, BadPwdCount, LockedOut -ErrorAction Stop
            }
            catch {
                Write-Warning "Unable to fetch user information with lockout data from $($Dc.Hostname)"
                continue
            }
            if ($UserInfo.LastBadPasswordAttempt) {
                $LockoutData = $UserInfo | Select-Object -Property @(
                    @{ Name = 'Name'; Expression = { $_.SamAccountName } }
                    @{ Name = 'SID'; Expression = { $_.SID.Value } }
                    @{ Name = 'LockedOut'; Expression = { $_.LockedOut } }
                    @{ Name = 'BadPwdCount'; Expression = { $_.BadPwdCount } }
                    @{ Name = 'BadPasswordTime'; Expression = { $_.BadPasswordTime } }
                    @{ Name = 'DomainController'; Expression = { $_.Hostname } }
                    @{ Name = 'AccountLockoutTime'; Expression = { $_.AccountLockoutTime } }
                    @{ Name = 'LastBadPasswordAttempt'; Expression = { ($_.LastBadPasswordAttempt).ToLocalTime() } }
                )
            }
        }
        Write-Information "$($LockoutData | Out-String)"
        try {
            $LockoutEvents = Get-WinEvent -ComputerName $PDCEmulator.HostName -FilterHashtable @{LogName='Security';Id=4740} `
            -Credential (Get-Credential -Message 'Enter AD admin credentials to query the events.') -ErrorAction Stop `
            | Sort-Object TimeCreated -Descending
        }
        catch {
            Write-Warning $_
            continue
        }

        foreach ($Event in $LockoutEvents) {
            if ($Event | Where-Object {$_.Properties[2].value -match $UserInfo.SID.Value}) {
                $Event | Select-Object -Property @(
                    @{ Label = 'User'; Expression = { $_.Properties[0].Value } }
                    @{ Label = 'DomainController'; Expression = { $_.MachineName } }
                    @{ Label = 'EventId'; Expression = { $_.Id } }
                    @{ Label = 'LockedOutTimeStamp'; Expression = { $_.TimeCreated } }
                    @{ Label = 'Message'; Expression = { $_.Message -split "`r" | Select-Object -First 1 } }
                    @{ Label = 'LockedOutLocation'; Expression = { $_.Properties[1].Value } }
                )
            }
            else {
                Write-Warning 'Could not find account lockout events in the logs.'
            }
        }
    }
}
