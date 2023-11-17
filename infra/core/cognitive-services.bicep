@description('Name of the resource.')
param name string
@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location
@description('Tags for the resource.')
param tags object = {}

type keyVaultSecretInfo = {
  name: string
  property: 'PrimaryKey'
}

type keyVaultSecretsInfo = {
  name: string
  secrets: keyVaultSecretInfo[]
}

@description('Cognitive Services SKU. Defaults to S0.')
param sku object = {
  name: 'S0'
}
@description('Cognitive Services Kind. Defaults to OpenAI.')
@allowed([
  'Bing.Speech'
  'SpeechTranslation'
  'TextTranslation'
  'Bing.Search.v7'
  'Bing.Autosuggest.v7'
  'Bing.CustomSearch'
  'Bing.SpellCheck.v7'
  'Bing.EntitySearch'
  'Face'
  'ComputerVision'
  'ContentModerator'
  'TextAnalytics'
  'LUIS'
  'SpeakerRecognition'
  'CustomSpeech'
  'CustomVision.Training'
  'CustomVision.Prediction'
  'OpenAI'
])
param kind string = 'OpenAI'
@description('List of deployments for Cognitive Services.')
param deployments array = []
@description('Whether to enable public network access. Defaults to Enabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
@description('Properties to store in a Key Vault.')
param keyVaultSecrets keyVaultSecretsInfo?

resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: toLower(name)
    publicNetworkAccess: publicNetworkAccess
  }
  sku: sku
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: cognitiveServices
  name: deployment.name
  properties: {
    model: contains(deployment, 'model') ? deployment.model : null
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 20
  }
}]

module keyVaultSecret './key-vault-secret.bicep' = [for secret in keyVaultSecrets.?secrets!: {
  name: '${secret.name}-secret'
  params: {
    keyVaultName: keyVaultSecrets.?name!
    name: secret.name
    value: secret.property == 'PrimaryKey' ? cognitiveServices.listKeys().key1 : ''
  }
}]

@description('ID for the deployed Cognitive Services resource.')
output id string = cognitiveServices.id
@description('Name for the deployed Cognitive Services resource.')
output name string = cognitiveServices.name
@description('Endpoint for the deployed Cognitive Services resource.')
output endpoint string = cognitiveServices.properties.endpoint
@description('Host for the deployed Cognitive Services resource.')
output host string = split(cognitiveServices.properties.endpoint, '/')[2]
