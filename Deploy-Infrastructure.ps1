<#
.SYNOPSIS
    Deploy the core infrastructure for the OpenAI API Management Load Balancing Sample to an Azure subscription.
.DESCRIPTION
    This script initiates the deployment of the main.bicep template to the current default Azure subscription,
    determined by the Azure CLI. The deployment name and location are required parameters.
.PARAMETER DeploymentName
    The name of the deployment to create in an Azure subscription.
.PARAMETER Location
    The location to deploy the Azure resources to.
.PARAMETER PublisherEmail
    The email address of the API Management publisher.
.PARAMETER PublisherName
    The name of the API Management publisher.
.EXAMPLE
    .\Deploy-Infrastructure.ps1 -DeploymentName 'my-deployment' -Location 'westeurope' -PublisherEmail 'test@email.com' -PublisherName 'Test User'
.NOTES
    Author: James Croft
    Date: 2024-03-27
#>

param
(
    [Parameter(Mandatory = $true)]
    [string]$DeploymentName,
    [Parameter(Mandatory = $true)]
    [string]$Location,
    [Parameter(Mandatory = $true)]
    [string]$PublisherEmail,
    [Parameter(Mandatory = $true)]
    [string]$PublisherName
)

Write-Host "Deploying infrastructure..."

Set-Location -Path $PSScriptRoot

az --version

$deploymentOutputs = (az deployment sub create --name $DeploymentName --location $Location --template-file './infra/main.bicep' --parameters './infra/main.parameters.json' `
        --parameters workloadName=$DeploymentName `
        --parameters location=$Location `
        --parameters apiManagementPublisherEmail=$PublisherEmail `
        --parameters apiManagementPublisherName=$PublisherName `
        --query 'properties.outputs' -o json) | ConvertFrom-Json
$deploymentOutputs | ConvertTo-Json | Out-File -FilePath './InfrastructureOutputs.json' -Encoding utf8

return $deploymentOutputs