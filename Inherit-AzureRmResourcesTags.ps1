<#
.SYNOPSIS
  Connects to AzureRm, get the specified resource group tags and apply those tags to all it's sub resources and retain existing tags on resources that are not duplicates.

.DESCRIPTION
  REQUIRED AUTOMATION ASSETS
  1. An Automation credential asset with the name : $AzureCredentialAssetName that contains the Azure AD user credential with authorization for this subscription. 

  REQUIRED PowerShell modules
    ModuleType Version    Name
    ---------- -------    ----
    Script     5.0.1      AzureRM.profile
    Script     6.0.0      AzureRM.Resources

.PARAMETER AzureTenantId
   Mandatory
   The Azure tenant Id from where the Azure Subscription belongs to.

.PARAMETER AadApplicationId
   Mandatory
   The GUID of an azure application id (service principal) with authorization for this subscription.

.PARAMETER AadAppCertificatelAssetName
   Mandatory
   The name of the Automation certificate asset that contains certificate of the upper application id.

.PARAMETER AzureSubscriptionId
   Mandatory
   The GUID for the Azure subscription where this runbook will be excecuted.

.PARAMETER ResourceGroupName
   Mandatory
   The Resource Group name from where the tag(s) will be applied to it's sub resources.

.NOTES
   AUTHOR: James Dumont le Douarec

.LINK
    https://github.com/JamesDLD/AzureRm.Automation
    https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-using-tags
    https://github.com/Azure/azure-powershell/issues/1665

.EXAMPLE
   $AzureTenantId = "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   $AadApplicationId = "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   $AadAppCertificatelAssetName = $AadApplicationId
   $AzureCredentialAssetName = "sp_apps_owner"
   $AzureSubscriptionId = "xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   $ResourceGroupName = "infr-jdld-noprd-rg1"

   .\Inherit-AzureRmResourcesTags.ps1 -AzureTenantId $AzureTenantId -AadApplicationId $AadApplicationId -AadAppCertificatelAssetName $AadAppCertificatelAssetName -AzureSubscriptionId $AzureSubscriptionId -ResourceGroupName $ResourceGroupName
#>

param (
    [Parameter(Mandatory=$true)] 
    [String]  $AzureTenantId,

    [Parameter(Mandatory=$true)] 
    [String]  $AadApplicationId,

	[Parameter(Mandatory=$true)]
	[String] $AadAppCertificatelAssetName,
        
    [Parameter(Mandatory=$true)]
    [String] $AzureSubscriptionId,

    [Parameter(Mandatory=$true)] 
    [String] $ResourceGroupName
)

################################################################################
#                                 Variables
################################################################################
Set-StrictMode -Version 2
$ErrorActionPreference = "Continue"

################################################################################
#                                 Functions
################################################################################
#region function
Function Generate_Log_Action([string]$Action, [ScriptBlock]$Command){
	$Output = "Info : $Action  ... "
	Write-Verbose $Output -Verbose
    Write-Output $Output
	Try{
		$Result = Invoke-Command -ScriptBlock $Command 
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		$Output = "Error on action $Action : $ErrorMessage"
		Write-Error $Output 
		Throw $Output
		$Result = "Error"
	}
	Return $Result
}
#endregion

################################################################################
#                                 Action
################################################################################
#region authentication
$Action = "Getting the certificate : $AadAppCertificatelAssetName from the Automation Asset store"
$Command = {Get-AutomationCertificate -Name $AadAppCertificatelAssetName -ErrorAction Stop}
$AutomationCertificate = Generate_Log_Action -Action $Action -Command $Command
if($AutomationCertificate -eq "Error"){Exit 1}

$Action = "Connecting to the subscription : $SubscriptionName "
$Command = {Add-AzureRmAccount -ServicePrincipal -CertificateThumbprint $AutomationCertificate.Thumbprint -ApplicationId $AadApplicationId -TenantId $AzureTenantId -ErrorAction Stop}
$Result = Generate_Log_Action -Action $Action -Command $Command
if($Result -eq "Error"){Exit 1}

$Action = "Setting the AzureRm context"
$Command = {Get-AzureRmSubscription -SubscriptionId $AzureSubscriptionId | Set-AzureRmContext -ErrorAction Stop}
$AzureRmContext = Generate_Log_Action -Action $Action -Command $Command
if($AzureRmContext -eq "Error"){Exit 1}
    
$Action = "Selecting the AzureRm subscription id : $AzureSubscriptionId"
$Command = {Select-AzureRmSubscription -SubscriptionId $AzureSubscriptionId -Force -ErrorAction Stop}
$AzureRmSubscription = Generate_Log_Action -Action $Action -Command $Command
if($AzureRmSubscription -eq "Error"){Exit 1}
#endregion

#region tagging
$Action = "Getting the Resource Group : $ResourceGroupName"
$Command = {Get-AzureRmResourceGroup -ErrorAction Stop | where {$_.ResourceGroupName -like $ResourceGroupName}}
$ResourceGroup = Generate_Log_Action -Action $Action -Command $Command
if($ResourceGroup -eq "Error"){Exit 1}

if($ResourceGroup)
{
    if ($ResourceGroup.Tags -ne $null) {

        $Action = "Getting the Resources contained into the Resource group : $ResourceGroupName"
        $Command = {Get-AzureRmResource -ResourceGroupName $ResourceGroup.ResourceGroupName -ErrorAction Stop}
        $resources = Generate_Log_Action -Action $Action -Command $Command
        if($resources -eq "Error"){Exit 1}

        foreach ($r in $resources)
        {
            $resourcetags = $r.Tags
            $TaggingNeeded = $false

            if ($resourcetags)
            {
                foreach ($key in $ResourceGroup.Tags.Keys)
                {
                    if (-not($resourcetags.ContainsKey($key)))
                    {
                        $resourcetags.Add($key, $ResourceGroup.Tags[$key])
                        $TaggingNeeded = $true
                    }
                }
                
                if($TaggingNeeded -eq $true)
                {
                    $Action = "Tagging the Resource Id : $($r.ResourceId) named : $($r.Name)"
                    $Command = {Set-AzureRmResource -Tag $resourcetags -ResourceId $r.ResourceId -Force -ErrorAction Stop}
                    $Result = Generate_Log_Action -Action $Action -Command $Command
                    if($Result -eq "Error"){Exit 1}
                }

            }
            else
            {
                $Action = "Tagging the Resource Id : $($r.ResourceId) named : $($r.Name)"
                $Command = {Set-AzureRmResource -ResourceId $r.ResourceId -Tag $ResourceGroup.Tags -Force -ErrorAction Stop}
                $Result = Generate_Log_Action -Action $Action -Command $Command
                if($Result -eq "Error"){Exit 1}
            }
        }
    }
    else
    {
        $Info = "Resource Group : $ResourceGroupName doesn't have any tags"
        Generate_Log_Action -Action $Info -Command {Write-Output ""}
    }
}
else
{
    $Info = "Resource Group : $ResourceGroupName was not founded into the AzureRm subscription id : $AzureSubscriptionId"
    Generate_Log_Action -Action $Info -Command {Write-Output ""}
}
#endregion