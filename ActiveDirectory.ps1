
<#
.SYNOPSIS
    Script RBAC inside AD for Cloud Assembly
.AUTHOR
    Lukasz Tworek

    vworld.lukasztworek.pl
    lukasz.tworek@gmail.com

.DESCRIPTION
    Script will create all required groups based on RBAC for Cloud Assembly 8.8
.VERSION HISTORY
    1.0 Main Release 
#>

#Module Installation

#Get-WindowsCapability -Name RSAT* -Online | Add-WindowsCapability -Online 


#RBAC
$Organization = @("Organization Owner","Organization Member")
$Service = @("Cloud Assembly Administrator","Cloud Assembly User","Cloud Assembly Viewer","Service Broker Administrator","Service Broker User","Service Broker Viewer","Code Stream Administrator","Code Stream User","Code Stream Viewer" )
$Project = @("Project Administrator","Project User","Project Viewer","Project Supervisor" )


#Credentials
$password = ConvertTo-SecureString 'VMware1!' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ('vworld\Administrator', $password)


#Creation Process
foreach($org in $Organization)
{
    New-ADGroup -Server win-ad.vworld.domain.local -Name $org -GroupScope Global  -Credential $credential -Description "Organization Groups for vRealize Automation RBAC"
}
foreach($ser in $Service)
{
    New-ADGroup -Server win-ad.vworld.domain.local -Name $ser -GroupScope Global  -Credential $credential -Description "Service Groups for vRealize Automation RBAC"
}
foreach($prj in $Project)
{
    New-ADGroup -Server win-ad.vworld.domain.local -Name $prj -GroupScope Global  -Credential $credential -Description "Project Groups for vRealize Automation RBAC"
}