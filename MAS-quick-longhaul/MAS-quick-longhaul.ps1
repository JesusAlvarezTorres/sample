param(
	[parameter(Mandatory=$true)]
	[string] $TemplateJSONPath,
	[parameter(Mandatory=$true)]
	[int] $NumberOfDeploymentsToDo,
	[string] $TemplateParametersJSONPath = "",
	[string]$UserName,
	[string]$Pwd
)

function ConnectToAzureStack
{
	Param(
		[string]$userName,
		[string]$pwd
	)
	
	$secpasswd = ConvertTo-SecureString $pwd -AsPlainText -Force
	$admincreds = New-Object System.Management.Automation.PSCredential ($userName, $secpasswd) 
	$armEndpoint = "https://api." + $env:USERDNSDOMAIN
	$directoryTenantName = "msazurestack.onmicrosoft.com"
	$response = Invoke-RestMethod "${armEndpoint}/metadata/endpoints?api-version=1.0"
	$AadtenantId="msazurestack.onmicrosoft.com"
	Add-AzureRmEnvironment -Name 'Azure Stack' `
    	-ActiveDirectoryEndpoint ("https://login.windows.net/$AadTenantId/") `
    	-ActiveDirectoryServiceEndpointResourceId ($response.authentication.audiences[0])`
    	-ResourceManagerEndpoint ($armEndpoint) `
    	-GalleryEndpoint ($response.galleryEndpoint) `
    	-GraphEndpoint ($response.graphEndpoint)

	$privateEnv = Get-AzureRmEnvironment 'Azure Stack' 
	Add-AzureRmAccount -Environment $privateEnv -Credential $admincreds
}

function DeployARMTemplate
{
	Param(
		[string] $resourceGroupName,
		[string] $templateJSONPath,
		[string] $templateParametersJSONPath = ""
	)
	
	$deploymentName = "Microsoft.Template"
	$currentDir = Convert-Path ".\"
	$logFilePostFix = Get-Date -Format FileDateTime
	$logFileName = "$($resourceGroupName)_$($logFilePostFix).txt"
	$logFilePath = Join-Path $currentDir $logFileName
	Start-Transcript -Path $logFilePath
	
	if(!(Test-Path $templateJSONPath))
	{
		$timeStamp = Get-Date -Format FileDateTime
		Write-Error "[$timeStamp]::Template json file not found at $($templateJSONPath)"
		Stop-Transcript
		exit
	}
	
	if([string]::IsNullOrEmpty($templateParametersJSONPath))
	{
		$timeStamp = Get-Date -Format FileDateTime
		Write-Host "[$timeStamp]::No parameters file specified, starting deployment $($deploymentName) without parameters file"
		New-AzurermResourceGroup -Name $resourceGroupName -Location "Local"
		New-AzurermResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateJSONPath -Verbose
		$timeStamp = Get-Date -Format FileDateTime
		Write-Host "[$timeStamp]:: Deployment $deploymentName complete"
	}
	elseif (!(Test-Path $templateParametersJSONPath))
	{
		$timeStamp = Get-Date -Format FileDateTime
		Write-Error "[$timeStamp]::Template parameters json file not found at $($templateParametersJSONPath)"
		Stop-Transcript
		exit
	}
	else
	{	
		$timeStamp = Get-Date -Format FileDateTime
		Write-Host "[$timeStamp]::Parameters file specified, starting deployment $($deploymentName) with parameters file"	
		New-AzurermResourceGroup -Name $resourceGroupName -Location "Local"
		New-AzurermResourceGroupDeployment -Name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile $templateJSONPath -TemplateParameterFile $templateParametersJSONPath -Verbose
		$timeStamp = Get-Date -Format FileDateTime
		Write-Host "[$timeStamp]:: Deployment $deploymentName complete"
	}
	Stop-Transcript
}

function GetAzureStackDeploymentReport
{
	Param(
		[string]$resourceGroupName
	)
	
	$currentDir = Convert-Path ".\"
	$logFilePostFix = Get-Date -Format FileDateTime
	$logFileName = "$($resourceGroupName)_DeploymentsReport_$($logFilePostFix).txt"
	$logFilePath = Join-Path $currentDir $logFileName
	
	Start-Transcript -Path $logFilePath
	Write-Host "`n"
	Write-Host "===========REPORT START==========="
	$deployments = @(Get-AzureRmResourceGroupDeployment -ResourceGroupName $resourceGroupName)
	[array]::Reverse($deployments)
	
	foreach($deployment in $deployments)
	{
		$deploymentOperations = @(Get-AzureRmResourceGroupDeploymentOperation -ResourceGroupName $resourceGroupName -DeploymentName $deployment.DeploymentName)
		[array]::Reverse($deploymentOperations)
		foreach($deploymentOperation in $deploymentOperations)
		{
			if(($deploymentOperation | select -ExpandProperty Properties | select -ExpandProperty TargetResource) -ne $null -and `
			($deploymentOperation | select -ExpandProperty Properties | select -ExpandProperty TargetResource | select ResourceType).ResourceType -ne 'Microsoft.Resources/deployments')
			{
				$entry = [ordered]@{
				Deployment = ($deployment | select DeploymentName).DeploymentName
				DeploymentProvisioningState = ($deployment | select ProvisioningState).ProvisioningState
				ResourceName =  ($deploymentOperation | select -ExpandProperty Properties | select -ExpandProperty TargetResource | select ResourceName).ResourceName
				ResourceType =  ($deploymentOperation | select -ExpandProperty Properties | select -ExpandProperty TargetResource | select ResourceType).ResourceType
				ProvisioningState = ($deploymentOperation | select -ExpandProperty Properties | select ProvisioningState).ProvisioningState
				Duration = ($deploymentOperation | select -ExpandProperty Properties | select Duration).Duration
				}
				New-Object -TypeName PSObject -Property $entry 
			}
		}
	}
	Write-Host "===========REPORT END==========="
	Write-Host "`n"
	Stop-Transcript
}

ConnectToAzureStack -userName $UserName -pwd $Pwd | Out-Null
for($i=0;$i -lt $NumberOfDeploymentsToDo; $i++)
{
	$resourceGroupPostfix = [Guid]::NewGuid().ToString().Substring(0,6)
	$rgName = "rg$($resourceGroupPostfix)"
	
	DeployARMTemplate -resourceGroupName $rgName -templateJSONPath $TemplateJSONPath -templateParametersJSONPath $TemplateParametersJSONPath
	GetAzureStackDeploymentReport -resourceGroupName $rgName
}
