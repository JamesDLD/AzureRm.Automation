<#
.SYNOPSIS
  Connects to AzureRm, get the specified resource group tags and apply those tags to all it's sub resources

.DESCRIPTION
  REQUIRED AUTOMATION ASSETS
  1. An Automation credential asset with the name : $AzureCredentialAssetName that contains the Azure AD user credential with authorization for this subscription. 

.PARAMETER AzureTenantId
   Mandatory
   The Azure tenant Id from where the Azure Subscription belongs to.

.PARAMETER AzureCredentialAssetName
   Mandatory
   The name of an Automation credential asset that contains the Azure AD user credential with authorization for this subscription. 

.PARAMETER AzureSubscriptionId
   Mandatory
   The GUID for the Azure subscription where this runbook will be excecuted.

.PARAMETER ResourceGroupName
   Mandatory
   The Resource Group name from where the tag(s) will be applied to it's sub resources.

.NOTES
   AUTHOR: James Dumont le Douarec
   Blog : https://github.com/JamesDLD/AzureRm.Automation

   The following runbook uses an authentication through Service Principal and Password, 
   Instead of, I recommend to use an authentication through Service Principal and Certificate.
#>

param (
    [Parameter(Mandatory=$true)] 
    [String]  $AzureTenantId,

    [Parameter(Mandatory=$true)] 
    [String]  $AzureCredentialAssetName,
        
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
#region connection

$Action = "Getting the Azure Credential Asset Name : $AzureCredentialAssetName"
$Command = {Get-AutomationPSCredential -Name $AzureCredentialAssetName -ErrorAction Stop}
$AutomationPSCredential = Generate_Log_Action -Action $Action -Command $Command
if($AutomationPSCredential -eq "Error"){Exit 1}

$Action = "Connecting to Azure through the Credential Asset Name : $AzureCredentialAssetName"
$Command = {Login-AzureRmAccount -ServicePrincipal -Credential $AutomationPSCredential -Tenant $AzureTenantId -ErrorAction Stop}
$Result = Generate_Log_Action -Action $Action -Command $Command
if($Result -eq "Error"){Exit 1}

$Action = "Checking if the Service Principal has access to multiple subscriptions"
$Command = {Get-AzureRmSubscription -ErrorAction Stop}
$AzureRmSubscription = Generate_Log_Action -Action $Action -Command $Command
if($AzureRmSubscription -eq "Error"){Exit 1}

if($AzureRmSubscription)
{
    $Action = "Setting the AzureRm"
    $Command = {Get-AzureRmSubscription -SubscriptionId $AzureSubscriptionId | Set-AzureRmContext -ErrorAction Stop}
    $AzureRmContext = Generate_Log_Action -Action $Action -Command $Command
    if($AzureRmContext -eq "Error"){Exit 1}
    
    $Action = "Selecting the AzureRm subscription id : $AzureSubscriptionId"
    $Command = {Select-AzureRmSubscription -SubscriptionId $AzureSubscriptionId -Context $AzureRmContext -Force -ErrorAction Stop}
    $AzureRmSubscription = Generate_Log_Action -Action $Action -Command $Command
    if($AzureRmSubscription -eq "Error"){Exit 1}
}
#endregion