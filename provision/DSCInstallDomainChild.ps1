Configuration ADDomainController_AddReadOnlyDomainController_Config
{
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $SafeModePassword,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $CredRODC,	

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $SafeRODC
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ActiveDirectoryDsc

    node localhost
    {
        WindowsFeature 'InstallADDomainServicesFeature'
        {
            Ensure = 'Present'
            Name   = 'AD-Domain-Services'
        }

        WindowsFeature 'RSATADPowerShell'
        {
            Ensure    = 'Present'
            Name      = 'RSAT-AD-PowerShell'

            DependsOn = '[WindowsFeature]InstallADDomainServicesFeature'
        }

        WaitForADDomain 'WaitForestAvailability'
        {
            DomainName = 'party.hard'
            Credential = $Credential

            DependsOn  = '[WindowsFeature]RSATADPowerShell'
        }

        ADDomainController 'Read-OnlyDomainController(RODC)'
        {
            DomainName                          = 'party.hard'
            Credential                          = $Credential
            SafeModeAdministratorPassword       = $SafeRODC 
            ReadOnlyReplica                     = $true
            SiteName                            = 'Default-First-Site-Name'
            AllowPasswordReplicationAccountName = @('Allowed RODC Password Replication Group')
            DenyPasswordReplicationAccountName  = @('Denied RODC Password Replication Group')

            DependsOn                           = '[WaitForADDomain]WaitForestAvailability'
        }
    }
}

#Next block is using to allow password as plain text
$cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
         }
    )
}

#Define user and password for ADDomain deployment (also used for restore).
$password = ConvertTo-SecureString "vagrant" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential('Administrator',$password)

#RODC.
$password = ConvertTo-SecureString "RestorePassword123$" -AsPlainText -Force
$credRODC = New-Object System.Management.Automation.PSCredential('vagrant',$password)

#Create MOF
ADDomainController_AddReadOnlyDomainController_Config -Credential $cred -SafeModePassword $cred -CredRODC $credRODC -SafeRODC $credRODC	 -ConfigurationData $cd

#Execute MOF
Start-DscConfiguration -Path .\ADDomainController_AddReadOnlyDomainController_Config -Force -Wait -Verbose
