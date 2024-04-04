@description('Name of the named value.')
param name string
@description('Name of the API Management associated with the named value.')
param apiManagementName string
@description('Display name of the named value.')
param displayName string
@description('Value of the named value.')
param value string

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apiManagementName

  resource namedValue 'namedValues@2023-05-01-preview' = {
    name: name
    properties: {
      displayName: displayName
      value: value
    }
  }
}

@description('ID for the deployed API Management Named Value resource.')
output id string = apiManagement::namedValue.id
@description('Name for the deployed API Management Named Value resource.')
output name string = apiManagement::namedValue.name
