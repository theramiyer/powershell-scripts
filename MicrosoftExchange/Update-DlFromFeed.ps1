function Update-DlFromFeed {
    [CmdletBinding(DefaultParameterSetName = "NoFilter")]
    param(
        # The path to the Feed file
        [Parameter(Mandatory=$true, ParameterSetName='NoFilter')]
        [Parameter(Mandatory=$true, ParameterSetName='Filter')]
        [String]
        $FeedFilePath,

        # The name of the DL you'd like modified
        [Parameter(Mandatory=$true, ParameterSetName='NoFilter')]
        [Parameter(Mandatory=$true, ParameterSetName='Filter')]
        [String]
        $GroupName,

        # Column name
        [Parameter(Mandatory=$true, ParameterSetName='Filter')]
        [string]
        $ColumnName,

        # Filter string
        [Parameter(Mandatory=$true, ParameterSetName='Filter')]
        [string]
        $FilterString
    )
    begin {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        catch {
            Write-Error 'Unable to import the ActiveDirectory module'
            break
        }
        try {
            $InputPath = "$env:TEMP\input.csv"
            Copy-Item -Path $FeedFilePath -Destination $InputPath -ErrorAction Stop
            $Members = Import-Csv -Path $InputPath -ErrorAction Stop

            if ($FilterString) {
                $Members = $Members | Where-Object $ColumnName -eq $FilterString
            }
        }
        catch {
            Write-Error 'Unable to work the input file'
            break
        }
    }
    process {
        # Listing active employees
        $FeedActive = ($Members | Where-Object CNT_Status -eq 'Active' | ForEach-Object { Get-ADUser $PsItem.User_Name }).SamAccountName
        # Picking members who are not active (are termed)
        $FeedTermed = ($Members | Where-Object CNT_Status -ne 'Active' | ForEach-Object { Get-ADUser $PsItem.User_Name }).SamAccountName
        # Listing current members
        $CurrentMembers = (Get-ADGroupMember -Identity $GroupName).SamAccountName

        # Listing out the members to be added
        foreach ($MemberAdded in $FeedActive) {
            if ($MemberAdded -notin $CurrentMembers) {
                try {
                    Add-ADGroupMember -Identity $GroupName -Members $MemberAdded -Confirm:$false -ErrorAction Stop
                }
                catch {
                    Write-Error "Error adding $MemberAdded to $GroupName"
                }
            }
        }

        # Listing out the members to be removed
        foreach ($MemberRemoved in $CurrentMembers) {
            if (($MemberRemoved -notin $FeedActive) -or ($MembersRemoved -in $FeedTermed)) {
                try {
                    Remove-ADGroupMember -Identity $GroupName -Members $MemberRemoved -Confirm:$false -ErrorAction Stop
                }
                catch {
                    Write-Error "Error removing $MemberRemoved from $GroupName"
                }
            }
        }
    }
}
