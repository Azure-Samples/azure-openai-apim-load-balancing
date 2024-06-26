targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the workload which is used to generate a short unique hash used in all resources.')
param workloadName string

@minLength(1)
@description('Primary location for all resources.')
param location string

@description('Name of the resource group. If empty, a unique name will be generated.')
param resourceGroupName string = ''

@description('Tags for all resources.')
param tags object = {}

type openAIInstanceInfo = {
  name: string?
  location: string
  suffix: string
}

@description('Name of the Managed Identity. If empty, a unique name will be generated.')
param managedIdentityName string = ''
@description('OpenAI instances to deploy. Defaults to 2 across different regions.')
param openAIInstances openAIInstanceInfo[] = [
  {
    name: ''
    location: 'uksouth'
    suffix: 'uks'
  }
  {
    name: ''
    location: 'westus'
    suffix: 'wus'
  }
]
@description('Name of the API Management service. If empty, a unique name will be generated.')
param apiManagementName string = ''
@description('Email address for the API Management service publisher.')
param apiManagementPublisherEmail string
@description('Name of the API Management service publisher.')
param apiManagementPublisherName string

var abbrs = loadJsonContent('./abbreviations.json')
var roles = loadJsonContent('./roles.json')
var resourceToken = toLower(uniqueString(subscription().id, workloadName, location))

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourceGroup}${workloadName}'
  location: location
  tags: union(tags, {})
}

module managedIdentity './core/managed-identity.bicep' = {
  name: !empty(managedIdentityName) ? managedIdentityName : '${abbrs.managedIdentity}${resourceToken}'
  scope: resourceGroup
  params: {
    name: !empty(managedIdentityName) ? managedIdentityName : '${abbrs.managedIdentity}${resourceToken}'
    location: location
    tags: union(tags, {})
  }
}

resource cognitiveServicesOpenAIUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup
  name: roles.cognitiveServicesOpenAIUser
}

module openAI './core/openai.bicep' = [
  for openAIInstance in openAIInstances: {
    name: !empty(openAIInstance.name)
      ? openAIInstance.name!
      : '${abbrs.openAIService}${resourceToken}-${openAIInstance.suffix}'
    scope: resourceGroup
    params: {
      name: !empty(openAIInstance.name)
        ? openAIInstance.name!
        : '${abbrs.openAIService}${resourceToken}-${openAIInstance.suffix}'
      location: openAIInstance.location
      tags: union(tags, {})
      deployments: [
        {
          name: 'gpt-35-turbo'
          model: {
            format: 'OpenAI'
            name: 'gpt-35-turbo'
            version: '1106'
          }
          sku: {
            name: 'Standard'
            capacity: 1
          }
        }
        {
          name: 'text-embedding-ada-002'
          model: {
            format: 'OpenAI'
            name: 'text-embedding-ada-002'
            version: '2'
          }
          sku: {
            name: 'Standard'
            capacity: 1
          }
        }
      ]
      roleAssignments: [
        {
          principalId: managedIdentity.outputs.principalId
          roleDefinitionId: cognitiveServicesOpenAIUser.id
        }
      ]
    }
  }
]

module apiManagement './core/api-management.bicep' = {
  name: !empty(apiManagementName) ? apiManagementName : '${abbrs.apiManagementService}${resourceToken}'
  scope: resourceGroup
  params: {
    name: !empty(apiManagementName) ? apiManagementName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: union(tags, {})
    sku: {
      name: 'Developer'
      capacity: 1
    }
    publisherEmail: apiManagementPublisherEmail
    publisherName: apiManagementPublisherName
    apiManagementIdentityId: managedIdentity.outputs.id
  }
}

module managedIdentityClientIdNamedValue './core/api-management-named-value.bicep' = {
  name: 'NV-MANAGED-IDENTITY-CLIENT-ID'
  scope: resourceGroup
  params: {
    name: 'MANAGED-IDENTITY-CLIENT-ID'
    displayName: 'MANAGED-IDENTITY-CLIENT-ID'
    apiManagementName: apiManagement.outputs.name
    value: managedIdentity.outputs.clientId
  }
}

module openAIApi './core/api-management-openapi-api.bicep' = {
  name: '${apiManagement.name}-api-openai'
  scope: resourceGroup
  params: {
    name: 'openai'
    apiManagementName: apiManagement.outputs.name
    path: '/openai'
    format: 'openapi-link'
    displayName: 'OpenAI'
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/preview/2024-03-01-preview/inference.json'
  }
}

module apiSubscription './core/api-management-subscription.bicep' = {
  name: '${apiManagement.name}-subscription-openai'
  scope: resourceGroup
  params: {
    name: 'openai-sub'
    apiManagementName: apiManagement.outputs.name
    displayName: 'OpenAI API Subscription'
    scope: '/apis/${openAIApi.outputs.name}'
  }
}

module openAIApiBackend './core/api-management-backend.bicep' = [
  for (item, index) in openAIInstances: {
    name: '${apiManagement.name}-backend-openai-${item.suffix}'
    scope: resourceGroup
    params: {
      name: 'OPENAI${toUpper(item.suffix)}'
      apiManagementName: apiManagement.outputs.name
      url: openAI[index].outputs.endpoint
    }
  }
]

module loadBalancingPolicy './core/api-management-policy.bicep' = {
  name: '${apiManagement.name}-policy-load-balancing'
  scope: resourceGroup
  params: {
    apiManagementName: apiManagement.outputs.name
    apiName: openAIApi.outputs.name
    format: 'rawxml'
    value: loadTextContent('./policies/round-robin-policy.xml')
  }
}

output resourceGroupInfo object = {
  id: resourceGroup.id
  name: resourceGroup.name
  location: resourceGroup.location
}

output managedIdentityInfo object = {
  id: managedIdentity.outputs.id
  name: managedIdentity.outputs.name
  principalId: managedIdentity.outputs.principalId
  clientId: managedIdentity.outputs.clientId
}

output openAIInfo array = [
  for (item, index) in openAIInstances: {
    id: openAI[index].outputs.id
    name: openAI[index].outputs.name
    endpoint: openAI[index].outputs.endpoint
    location: item.location
    suffix: item.suffix
  }
]

output apiManagementInfo object = {
  id: apiManagement.outputs.id
  name: apiManagement.outputs.name
  gatewayUrl: apiManagement.outputs.gatewayUrl
  subscriptionName: apiSubscription.outputs.name
}
