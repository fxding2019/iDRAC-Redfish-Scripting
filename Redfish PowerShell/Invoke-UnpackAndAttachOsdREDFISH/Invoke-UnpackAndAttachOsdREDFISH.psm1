<#
_author_ = Texas Roemer <Texas_Roemer@Dell.com>
_version_ = 3.0
Copyright (c) 2019, Dell, Inc.

This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>




<#
.Synopsis
   Cmdlet using Redfish API with OEM extension to either get driver pack information, unpack and attach driver pack or detach driver pack. 
.DESCRIPTION
   Cmdlet using Redfish API with OEM extension to either get driver pack information, unpack and attach driver pack or detach driver pack. For performing OS installation, it's recommended to unpack and attach driver pack cmdlet first, then execute cmdlet to perform boot to network ISO.  
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
   - get_driver_pack_info: Pass in "y" to get driver pack information (list of supported operating systems).
   - get_attach_status: Pass in "y" to get attach status for driver pack.
   - unpack_and_attach: Pass in operating system string name to unpack and attach. Example: pass in "Microsoft Windows Server 2012 R2"(make sure to pass double quotes around the string value)  
   - detach: Pass in "y" to detach driver pack.
.EXAMPLE
   .\Invoke-UnpackAndAttachOsdREDFISH.ps1 -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -get_driver_pack_info y
   This example will get driver pack information and return supported operating systems.
.EXAMPLE
   .\Invoke-UnpackAndAttachOsdREDFISH.ps1 -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -unpack_and_attach "Microsoft Windows Server 2016"
   This example will unpack and attach driver pack for OS Windows Server 2016.
.EXAMPLE
   .\Invoke-UnpackAndAttachOsdREDFISH.ps1 -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -detach y
   This example will detach driver pack
#>

function Invoke-UnpackAndAttachOsdREDFISH {




param(
    [Parameter(Mandatory=$True)]
    [string]$idrac_ip,
    [Parameter(Mandatory=$True)]
    [string]$idrac_username,
    [Parameter(Mandatory=$True)]
    [string]$idrac_password,
    [Parameter(Mandatory=$False)]
    [string]$get_driver_pack_info,
    [Parameter(Mandatory=$False)]
    [string]$get_attach_status,
    [Parameter(Mandatory=$False)]
    [string]$unpack_and_attach,
    [Parameter(Mandatory=$False)]
    [string]$detach
    )

# Function to ignore SSL certs

function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}


# Setting up iDRAC credentials for functions  

function setup_idrac_creds

{
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$global:credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
}

# Function to test if iDRAC version supports this cmdlet

function test_iDRAC_version 

{
$uri = "https://$idrac_ip/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService"
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $get_result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorAction RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $get_result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorAction RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    Write-Host "`n- WARNING, iDRAC version detected does not support this feature using Redfish API or incorrect iDRAC user credentials passed in.`n"
    $RespErr
    break
    }
}

# Function to get Powershell version

function get_powershell_version 
{
$get_host_info = Get-Host
$major_number = $get_host_info.Version.Major
$global:get_powershell_version = $major_number
}


# Function to GET driver pack information 

function get_driver_pack_info

{
Write-Host "`n- WARNING, getting driver pack information for iDRAC $idrac_ip"
$uri = "https://$idrac_ip/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService/Actions/DellOSDeploymentService.GetDriverPackInfo"
$JsonBody = @{} | ConvertTo-Json -Compress
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    break
    } 
if ($result1.StatusCode -eq 200)
{
$get_OS_list = $result1.Content |  ConvertFrom-Json
Write-Host "`n- Supported Driver Packs For OS Installation -`n"
$get_OS_list.OSList
Write-Host
} 
}

# Function to get driver pack attach status

function get_attach_status

{
Write-Host "`n- WARNING, getting driver pack attach information for iDRAC $idrac_ip"
$uri = "https://$idrac_ip/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService/Actions/DellOSDeploymentService.GetAttachStatus"
$JsonBody = @{} | ConvertTo-Json -Compress
   try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    break
    } 
if ($result1.StatusCode -eq 200)
{
$get_attach_status=$result1.Content |  ConvertFrom-Json
[String]::Format("`n- PASS, POST command passed to get attach status. Current driver pack attach status is: {0}", $get_attach_status.DriversAttachStatus)
Write-Host
} 
}


# Function to unpack and attach driver pack

function unpack_and_attach

{
Write-Host "`n- WARNING, unpacking and attach driver pack for iDRAC $idrac_ip"
$uri = "https://$idrac_ip/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService/Actions/DellOSDeploymentService.UnpackAndAttach"
$JsonBody = @{'OSName'=$unpack_and_attach} | ConvertTo-Json -Compress
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    break
    } 
        if ($result1.StatusCode -eq 202)
        {
        Write-Host "- PASS, POST command passed to unpack and attach driver pack, cmdlet will now loop checking concrete job status"
        $concrete_job_uri = $result1.Headers.Location
        }
            while ($result2.TaskState -ne "Completed")
            {
            $uri = "https://$idrac_ip$concrete_job_uri"
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $result2 = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorAction RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $result2 = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorAction RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    Write-Host
    $RespErr
    break
    }
            $result2 = $result2.Content | ConvertFrom-Json
            if ($result2.TaskState -eq "Exception")
            {
            $error_results = $result2.Messages.Message
            Write-Host "`n- FAIL, concrete job status failed to be marked completed, detailed error message $error_results"
            return
            }
            else
            {
            Start-Sleep 15
            $current_status = $result2.TaskState
            Write-Host "- WARNING, current concrete job status not marked completed, current status is $current_status"
            }
            }
Write-Host "- PASS, concrete job marked completed, verifying driver pack attach status"
Start-Sleep 5
$uri = "https://$idrac_ip/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService/Actions/DellOSDeploymentService.GetAttachStatus"
$JsonBody = @{} | ConvertTo-Json -Compress
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    break
    } 
if ($result1.StatusCode -eq 200)
{
$get_attach_status=$result1.Content |  ConvertFrom-Json
}
    if ($get_attach_status.DriversAttachStatus -eq "Attached")
    {
    [String]::Format("- PASS, driver pack verified as attached")
    }
    else
    {
    [String]::Format("`n- FAIL, driver pack not attached, current status is {0}, $get_attach_status.DriversAttachStatus")
    }
Write-Host
}


# Function to detach driver pack

function detach

{
Write-Host "`n- WARNING, detaching driver pack for iDRAC $idrac_ip"
$uri = "https://$idrac_ip/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService/Actions/DellOSDeploymentService.DetachDrivers"
$JsonBody = @{} | ConvertTo-Json -Compress
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    break
    } 
if ($result1.StatusCode -eq 200)
{
$get_attach_status=$result1.Content |  ConvertFrom-Json
[String]::Format("`n- PASS, POST command passed to detach driver pack, verifying attach status")
Start-Sleep 5
} 
$uri = "https://$idrac_ip/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService/Actions/DellOSDeploymentService.GetAttachStatus"
$JsonBody = @{} | ConvertTo-Json -Compress
    try
    {
    if ($global:get_powershell_version -gt 5)
    {
    
    $result1 = Invoke-WebRequest -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Body $JsonBody -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
    }
    else
    {
    Ignore-SSLCertificates
    $result1 = Invoke-WebRequest -Uri $uri -Credential $credential -Method Post -ContentType 'application/json' -Headers @{"Accept"="application/json"} -Body $JsonBody -ErrorVariable RespErr
    }
    }
    catch
    {
    Write-Host
    $RespErr
    break
    } 
if ($result1.StatusCode -eq 200)
{
$get_attach_status=$result1.Content |  ConvertFrom-Json
}
    if ($get_attach_status.DriversAttachStatus -eq "NotAttached")
    {
    [String]::Format("- PASS, driver pack verified as not attached")
    }
    else
    {
    [String]::Format("`n- FAIL, driver pack is not detached, current status is {0}, $get_attach_status.DriversAttachStatus")
    }
Write-Host
}




# Run code

get_powershell_version 
setup_idrac_creds

# Code to check for supported iDRAC version

$uri = "https://$idrac_ip/redfish/v1/Dell/Systems/System.Embedded.1/DellOSDeploymentService"
try
    {
    if ($global:get_powershell_version -gt 5)
    {
    $get_result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorAction RespErr -Headers @{"Accept"="application/json"}
    }
    else
    {
    Ignore-SSLCertificates
    $get_result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorAction RespErr -Headers @{"Accept"="application/json"}
    }
    }
    catch
    {
    Write-Host "`n- WARNING, iDRAC version detected does not support this feature using Redfish API or incorrect iDRAC user credentials passed in.`n"
    $RespErr
    break
    }

if ($get_driver_pack_info -ne "")
{
get_driver_pack_info
}
elseif ($get_attach_status -ne "")
{
get_attach_status
}
elseif ($unpack_and_attach -ne "")
{
unpack_and_attach
}
elseif ($detach -ne "")
{
detach
}
else
{
Write-Host "- FAIL, either invalid parameter value passed in or missing required parameter"
return
}


}
