# Part 1: preparation
$BaseResourceName = "rameshandme"
$random = $(Get-Random)
$ResourceGroupName = $BaseResourceName + "rg" + $random
$SynapseWorkspaceName = $BaseResourceName + "ws" + $random
$StorageAccountName = $BaseResourceName + "sa" + $random
$FileShareName = $BaseResourceName + "fs" + $random
$Location = "West Europe"

Connect-AzAccount

# Create new resourcegroup
New-AzResourceGroup -Name $ResourceGroupName -Location $Location

# By running the script as follows: ./1.CreateSynAnalytics.ps1 adminusername password those two values are passed along with the script.
$SqlUser = $args[0]
$SqlPassword = $args[1]
$Cred = New-Object -TypeName System.Management.Automation.PSCredential ($SqlUser, (ConvertTo-SecureString $SqlPassword -AsPlainText -Force))

Write-Output $SqlPassword
# Part 2: Create Azure Data Lake
$StorageAccountParams = @{
  ResourceGroupName = $ResourceGroupName
  Name = $StorageAccountName
  Location = $Location
  SkuName = "Standard_LRS"
  Kind = "StorageV2"
  AccessTier = "Hot"
  EnableHierarchicalNamespace = $true
  AllowBlobPublicAccess = $false
}
New-AzStorageAccount @StorageAccountParams

$azStorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
if ($null -eq $azStorageAccount) {
  Write-Output "The Data Lake in Part 2 was not created correctly or cannot be reached from your side."  
}
# Part 3: Create Workspace
$WorkspaceParams = @{
  Name = $SynapseWorkspaceName
  ResourceGroupName = $ResourceGroupName
  DefaultDataLakeStorageAccountName = $StorageAccountName
  DefaultDataLakeStorageFilesystem = $FileShareName
  SqlAdministratorLoginCredential = $Cred
  Location = $Location
}
New-AzSynapseWorkspace @WorkspaceParams

# Access workspace
$ClientIP = (Invoke-WebRequest ifconfig.me/ip).Content.Trim() 

$FirewallParams = @{
    WorkspaceName = $SynapseWorkspaceName
    Name = 'Thuistoegang'
    ResourceGroupName = $ResourceGroupName
    StartIpAddress = $ClientIP
    EndIpAddress = $ClientIP
  }
New-AzSynapseFirewallRule @FirewallParams

$SubscriptionId = (Get-AzContext).Subscription.id

New-AzRoleAssignment -ObjectId (Get-AzADServicePrincipal -SearchString $SynapseWorkspaceName) `
-RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName"

# Test if it works properly (Mozilla Firefox is recommended for this app)
$WorkspaceWeb = (Get-AzSynapseWorkspace -Name $SynapseWorkspaceName -ResourceGroupName $ResourceGroupName).ConnectivityEndpoints.web
Start-Process $WorkspaceWeb
