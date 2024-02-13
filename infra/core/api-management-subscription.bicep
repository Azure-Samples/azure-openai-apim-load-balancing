@description('Name of the Subscription.')
param name string
@description('Name of the API Management associated with the Subscription.')
param apiManagementName string
@description('Display name of the Subscription.')
param displayName string
@description('Scope of the Subscription (e.g., /products or /apis) associated with the API Management resource.')
param scope string

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apiManagementName

  resource subscription 'subscriptions@2023-05-01-preview' = {
    name: name
    properties: {
      displayName: displayName
      scope: scope
      state: 'active'
    }
  }
}

@description('ID for the deployed API Management Subscription resource.')
output id string = apiManagement::subscription.id
@description('Name for the deployed API Management Subscription resource.')
output name string = apiManagement::subscription.name
