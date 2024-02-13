@description('Name of the API Management associated with the Policy.')
param apiManagementName string
@description('Name of the API to associate with the Policy.')
param apiName string
@description('Format of the Policy associated with the API Management resource.')
@allowed([
  'rawxml'
  'rawxml-link'
  'xml'
  'xml-link'
])
param format string
@description('Value of the Policy associated with the API Management resource.')
param value string

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apiManagementName

  resource api 'apis@2023-05-01-preview' existing = {
    name: apiName

    resource policy 'policies@2023-05-01-preview' = {
      name: 'policy'
      properties: {
        format: format
        value: value
      }
    }
  }
}

@description('ID for the deployed API Management Policy resource.')
output id string = apiManagement::api::policy.id
@description('Name for the deployed API Management Policy resource.')
output name string = apiManagement::api::policy.name
