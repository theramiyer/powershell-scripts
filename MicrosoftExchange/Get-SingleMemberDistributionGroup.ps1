function Get-SingleMemberDistributionGroup {
    begin {
        # Connect to your Exchange Server and load the Exchange snap-in
        # Load the AD module

        $GroupDetailTable = @()
    }

    process {
        $Groups = Get-DistributionGroup -ResultSize Unlimited | Where-Object { (Get-DistributionGroupMember $_).Count -eq 1 }

        foreach ($Group in $Groups) {
            $GroupMembership = Get-DistributionGroupMember $Group
            if ($GroupMembership.RecipientType -eq 'User') {
                $UserDetails = Get-ADUser $GroupMembership.SamAccountName
            }
            else {
                $UserDetails = @{}
            }

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
                Member               = $GroupMembership.Name
                MemberType           = $GroupMembership.RecipientType
                MemberSam            = $GroupMembership.SamAccountName
                UserEnabled          = $UserDetails.Enabled
            }

            $GroupDetailTable += New-Object -TypeName PsObject -Property $GroupDetailObject
        }
        $GroupDetailTable
    }
}
