<#
.SYNOPSIS
    IDM Setup
.AUTHOR
    Lukasz Tworek

    vworld.lukasztworek.pl
    lukasz.tworek@gmail.com

.DESCRIPTION
    Script will create all required groups based on RBAC for Cloud Assembly 8.8
.VERSION HISTORY
    1.0 Main Release 
#>

#Ignore Certificate issue
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


#Credentials for OAuth2.0 - Access Token
$username = "POSTMAN"
$password = "hbP35GSJDntK4qNYogPibMMpTSC0cFle6RgUNt0oynHF5PNl"

#variables
$HostName = "idm.vworld.domain.local"
$url = New-Object System.UriBuilder
$url.Scheme = 'https'
$url.Host = $HostName


#authorization Token
$headers = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password));"Content-Type"="application/x-www-form-urlencoded"}
$body = @{grant_type='client_credentials'}


$url.Path = ('/SAAS/auth/oauthtoken')
$uri = $url.ToString()

$response = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -body $body
$content = $response.Content | ConvertFrom-Json
$access_token = $content.access_token


#Get ConnectorInstance ID

$url.Path = ('/SAAS/jersey/manager/api/connectormanagement/connectorinstances/')
$uri = $url.ToString()

$headers = @{"Authorization" = "Bearer "+$access_token;"Content-Type"="application/vnd.vmware.horizon.manager.connector.management.connectorinstance.list+json"}
$response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers 
$content = $response.items
foreach($item in $content)
{
    if($item.host -eq $HostName)
    {
        $instanceId = $item.instanceId
    }
}

#Create Directory
$url.Path = ('/SAAS/jersey/manager/api/connectormanagement/directoryconfigs')
$uri = $url.ToString()

$headers = @{"Authorization" = "Bearer "+$access_token;"Content-Type"="application/vnd.vmware.horizon.manager.connector.management.directory.ad.over.ldap+json"}

$properties = @{
‘baseDN’ = 'DC=vworld,DC=domain,DC=local'; 
‘bindDN’ = 'CN=administrator,CN=Users,DC=vworld,DC=domain,DC=local';
'directoryConfigId'= $null;
'directorySearchAttribute'= 'sAMAccountName';
'directoryType'= 'ACTIVE_DIRECTORY_LDAP';
'name'= 'vworld.domain.local';
'domainControllerHost'= 'win-ad.vworld.domain.local';
'domainControllerPort'= 389
}
$bodyObject = New-Object –TypeName PSObject –Property $properties
$body = $bodyObject | ConvertTo-Json


$response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -body $body
$directoryConfigId = $response.directoryConfigId


#Bind Connector
$url.Path = ('SAAS','jersey','manager','api','connectormanagement','connectorinstances',$instanceId,'associatedirectory'-join '/')
$uri = $url.ToString()

$headers = @{"Authorization" = "Bearer "+$access_token;"Content-Type"="application/vnd.vmware.horizon.manager.connector.management.directory.details+json"}

$properties = @{
‘directoryBindPassword’ = 'VMware1!'; 
‘directoryId’ = $directoryConfigId;
'usedForAuthentication'= $true;
}
$bodyObject = New-Object –TypeName PSObject –Property $properties
$body = $bodyObject | ConvertTo-Json

$response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -body $body

#Search For Groups

$url.Path = ('SAAS','jersey','manager','api','connectormanagement','directoryconfigs',$directoryConfigId ,'directorygroups'-join '/')
$uri = $url.ToString()

$headers = @{"Authorization" = "Bearer "+$access_token;"Content-Type"="application/vnd.vmware.horizon.manager.connector.management.ops.groupquery+json"}
$file = Get-Content -Path C:\Data\VMware\Projects\vrealize\vRA8\groups.txt
$list = @()

foreach($line in $file)
{
    
    $searchDNS = $line

    $properties = @"
    {
    "searchDns":["$searchDNS"]
    }
"@

    $body = $properties 
    

    $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -body $body
    $mappedGroupData = $response.identityGroups.$searchDNS.mappedGroupData | ConvertTo-Json
    $list+=$mappedGroupData
    
}
$payload = @()
$Total = $list.count
$Counter = 1
foreach ($l in $list)
{
    if($Counter -eq $Total)
    {
    $json = $l | ConvertFrom-Json
    $dn = $json.mappedGroup.dn
    
    $properties = @"
 
    
        "$dn" : 
        {
            "mappedGroupData" : [$l],
        
        
        "numSelected" : 1,
        "numTotal" : 1,
        "selected" : true
        }
    
"@
    $payload += $properties
    }
    else
    {
    $json = $l | ConvertFrom-Json
    $dn = $json.mappedGroup.dn
    
    $properties = @"
 
    
        "$dn" : 
        {
            "mappedGroupData" : [$l],
        
        
        "numSelected" : 1,
        "numTotal" : 1,
        "selected" : true
        },
    
    
"@
    $payload += $properties
    }
    $Counter+= 1
}

$body = @"
{
    "identityGroupInfo" : {
    
        $payload 
        }
}
"@





# Sync Groups
$url.Path = ('SAAS','jersey','manager','api','connectormanagement','directoryconfigs',$directoryConfigId ,'syncprofile'-join '/')
$uri = $url.ToString()

$headers = @{"Authorization" = "Bearer "+$access_token;"Content-Type"="application/vnd.vmware.horizon.manager.connector.management.directory.sync.profile.groups+json"}

$response = Invoke-RestMethod -Uri $uri -Method PUT -Headers $headers -body $body


#sync
$url.Path = ('SAAS','jersey','manager','api','connectormanagement','directoryconfigs',$directoryConfigId ,'syncprofile','sync'-join '/')
$uri = $url.ToString()

$headers = @{"Authorization" = "Bearer "+$access_token;"Content-Type"="application/vnd.vmware.horizon.manager.connector.management.directory.sync.profile.sync+json"}

$body = @"
{"ignoreSafeguards":true}
"@

$response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -body $body