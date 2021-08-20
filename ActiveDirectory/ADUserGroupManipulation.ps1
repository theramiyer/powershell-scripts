function Find-AdUser {
    [CmdletBinding()]
    param (
        # User's SAM account name
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string]
        $Identity,

        # Names of domains
        [Parameter(Position = 1)]
        [string[]]
        $Domains = $env:USERDNSDOMAIN
    )

    foreach ($Domain in $Domains) {
        try {
            Write-Verbose "Looking for $Identity in $Domain"
            $UserDetails = Get-AdUser $Identity -Server $Domain -ErrorAction Stop
            Write-Verbose "Found $Identity in $Domain"
            break
        }
        catch {
            Write-Verbose "$Identity not found in $Domain"
        }

        $UserDetails
    }
}

function Find-AdGroup {
    [CmdletBinding()]
    param (
        # Group's SAM account name
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string]
        $Identity,

        # Names of domains
        [Parameter(Position = 1)]
        [string[]]
        $Domains = $env:USERDNSDOMAIN
    )

    foreach ($Domain in $Domains) {
        try {
            Write-Verbose "Looking for $Identity in $Domain"
            $GroupDetails = Get-AdGroup $Identity -Server $Domain -ErrorAction Stop
            Write-Verbose "Found $Identity in $Domain"
            break
        }
        catch {
            Write-Verbose "$Identity not found in $Domain"
        }

        $GroupDetails
    }
}

function Add-AdUserToGroup {
    [CmdletBinding()]
    param (
        # User's SAM account name
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string]
        $Identity,

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
        $UserDetails = Find-AdUser $Identity -Domains $Domains

        if (-not $UserDetails) {
            Write-Error "$Identity not found in any of the specified domains" -Category ObjectNotFound -ErrorAction Stop
        }

        Write-Verbose "Getting the group membership of $Identity"
        $UserMembership = (Get-AdUser $UserDetails -Properties Memberof).MemberOf

        foreach ($Group in $GroupName) {
            Write-Verbose "Processing $Group"
            if ($UserMembership -match "^CN=$Group,") {
                Write-Warning "$Identity is already part of $Group"
            }
            else {
                $GroupDn = Find-AdGroup $Group -Domains $Domains
                if ($GroupDn) {
                    Write-Verbose "Adding $Identity to $($GroupDn.Name)"
                    Add-AdGroupMember $GroupDn -Member $UserDetails -Credential $Credential -ErrorAction Stop
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

function Remove-AdUserFromGroup {
    [CmdletBinding()]
    param (
        # User's SAM account name
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string]
        $Identity,

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
        $UserDetails = Find-AdUser $Identity -Domains $Domains

        if (-not $UserDetails) {
            Write-Error "$Identity not found in any of the specified domains" -Category ObjectNotFound -ErrorAction Stop
        }

        Write-Verbose "Getting the group membership of $Identity"
        $UserMembership = (Get-AdUser $UserDetails -Properties Memberof).MemberOf

        foreach ($Group in $GroupName) {
            Write-Verbose "Processing $Group"
            if ($UserMembership -match "^CN=$Group,") {
                $GroupDn = Find-AdGroup $Group -Domains $Domains
                if ($GroupDn) {
                    Write-Verbose "Adding $Identity to $($GroupDn.Name)"
                    Remove-AdGroupMember $GroupDn -Member $UserDetails.DistinguishedName -Credential $Credential -ErrorAction Stop
                }
                else {
                    Write-Error "Unable to find $($Group)" -ErrorAction Continue
                }
            }
            else {
                Write-Warning "$Identity is not part of $Group"
            }
        }
    }
    
    end {
        Remove-Module ActiveDirectory
    }
}