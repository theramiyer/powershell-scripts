function Get-DistributionListDisabledAccounts {
    begin {
        # Connect to your Exchange Server and load the Exchange snap-in
        # Load the AD module

        $GroupDetailTable = @()
    }

    process {
        $Groups = Get-DistributionGroup -ResultSize Unlimited | Where-Object { (Get-DistributionGroupMember $_).Count -gt 1 }

        foreach ($Group in $Groups) {
            $GroupMembership = Get-DistributionGroupMember $Group

            $TotalMembers = $GroupMembership.Count
            $UsersInGroup = $GroupMembership | Where-Object RecipientType -eq 'User'
            $UserCount = $UsersInGroup.Count

            if ($UserCount -eq $TotalMembers) {
                $UserTable = @()

                foreach ($User in $UsersInGroup) {
                    $UserTable += New-Object PSObject -Property @{
                        SamAccountName = $User.SamAccountName
                        Enabled = (Get-ADUser $User.SamAccountName).Enabled
                    }
                }

                $DisabledUsers = $UserTable | Where-Object Enabled -eq $false

                if ($DisabledUsers.Count -eq $TotalMembers) {
                    $GroupDetailObject = [ordered]@{
                        Name                 = $Group.Name
                        GroupType            = $Group.GroupType
                        SamAccountName       = $Group.SamAccountName
                        ManagedBy            = $Group.ManagedBy -join ';'
                        EmailAddresses       = $Group.EmailAddresses -join ';'
                        HiddenFromGAL        = $Group.HiddenFromAddressListsEnabled
                        PrimarySmtpAddress   = $Group.PrimarySmtpAddress
                        RecipientType        = $Group.RecipientType
                        RecipientTypeDetails = $Group.RecipientTypeDetails
                    }

                    $GroupDetailTable += New-Object -TypeName PsObject -Property $GroupDetailObject
                }
            }
        }
        $GroupDetailTable
    }
}
