# Deel 1: voorbereiding
$BaseResourceName = "rameshandme"
$random = $(Get-Random)
$ResourceGroupName = $BaseResourceName + "rg" + $random
$SynapseWorkspaceName = $BaseResourceName + "ws" + $random
$StorageAccountName = $BaseResourceName + "sa" + $random
$FileShareName = $BaseResourceName + "fs" + $random
$Location = "West Europe"

Connect-AzAccount

# Nieuwe resourcegroup maken
New-AzResourceGroup -Name $ResourceGroupName -Location $Location

# Door het script als volgt te runnen: ./1.CreateSynAnalytics.ps1 adminusername password worden de waardes meegegeven aan dit script.
$SqlUser = $args[0]
$SqlPassword = $args[1]
$Cred = New-Object -TypeName System.Management.Automation.PSCredential ($SqlUser, (ConvertTo-SecureString $SqlPassword -AsPlainText -Force))

Write-Output $SqlPassword
#Deel 2: Data Lake aanmaken
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
  Write-Output "Het data lake van deel 2 is niet goed aangemaakt of is niet bereikbaar."  
}
# Deel 3: Workspace aanmaken
$WorkspaceParams = @{
  Name = $SynapseWorkspaceName
  ResourceGroupName = $ResourceGroupName
  DefaultDataLakeStorageAccountName = $StorageAccountName
  DefaultDataLakeStorageFilesystem = $FileShareName
  SqlAdministratorLoginCredential = $Cred
  Location = $Location
}
New-AzSynapseWorkspace @WorkspaceParams

# Deel 3: toegang tot workspace
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

# Test of alles naar wens is.
$WorkspaceWeb = (Get-AzSynapseWorkspace -Name $SynapseWorkspaceName -ResourceGroupName $ResourceGroupName).ConnectivityEndpoints.web
Start-Process $WorkspaceWeb