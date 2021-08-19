function main {
    Add-UserToAdGroup -UserSam 'MyUserName' -GroupName 'MyGroupOne', 'MyGroupTwo' -Domains 'one.domain.com', 'two.domain.com' -Credential 'DOM\U739937'
}

function Add-UserToAdGroup {
    [CmdletBinding()]
    param (
        # User's SAM account name
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string]
        $UserSam,

        # Names of groups
        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [string[]]
        $GroupName,

        # Names of domains
        [Parameter()]
        [string[]]
        $Domains = $env:USERDNSDOMAIN,

        # Credential to use
        [Parameter()]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    
    begin {
        Write-Verbose "Importing the Active Directory module"
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    
    process {
        # Find which domain the user is in
        foreach ($Domain in $Domains) {
            try {
                Write-Verbose "Looking for $UserSam in $Domain"
                $UserDetails = Get-AdUser $UserSam -Server $Domain -Properties MemberOf -ErrorAction Stop
                Write-Verbose "Found $UserSam in $Domain"
                break
            }
            catch {
                Write-Verbose "$UserSam not found in $Domain"
            }
        }
        if (-not $UserDetails) {
            Write-Error "$UserSam not found in any of the specified domains" -Category ObjectNotFound -ErrorAction Stop
        }

        Write-Verbose "Getting the group membership of $UserSam"
        $UserMembership = $UserDetails.Memberof

        foreach ($Group in $Groupname) {
            Write-Verbose "Processing $Group"
            if ($Group -match $UserMembership) {
                Write-Warning "$UserSam is already part of $Group"
            }
            else {
                foreach ($Domain in $Domains) {
                    try {
                        Write-Verbose "Looking for $Group in $Domain"
                        $GroupDn = Get-AdGroup $Group -Server $Domain -ErrorAction Stop
                        Write-Verbose "$Group found in $Domain"
                        break
                    }
                    catch {
                        Write-Verbose "$Group not found in $Domain"
                    }
                }
                if ($GroupDn) {
                    Write-Verbose "Adding $($UserDetails.SamAccountName) to $($GroupDn.Name)"
                    $GroupDn | Add-AdGroupMember -Member $UserDetails.DistinguishedName -ErrorAction Stop
                }
                else {
                    Write-Error "Unable to find $($Group)" -ErrorAction Continue
                }
            }
        }
    }
    
    end {
        Remove-Module ActiveDirectory
    }
}

. main