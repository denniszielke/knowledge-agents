param accountName string
param databaseName string
param containerName string

@description('Location for the Cosmos DB account.')
param location string = resourceGroup().location

param tags object = {}

@allowed(['GlobalDocumentDB', 'MongoDB', 'Parse'])
@description('Sets the kind of account.')
param kind string = 'GlobalDocumentDB'

@description('Enables serverless for this account. Defaults to false.')
param enableServerless bool = true

@description('Enables NoSQL vector search for this account. Defaults to false.')
param enableNoSQLVectorSearch bool = true

@description('Disables key-based authentication. Defaults to false.')
param disableKeyBasedAuth bool = true

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  location: location
  kind: kind
  tags: tags
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    publicNetworkAccess: 'Enabled'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    apiProperties: (kind == 'MongoDB')
      ? {
          serverVersion: '7.0'
        }
      : {}
    disableLocalAuth: disableKeyBasedAuth
    capabilities: union(
      (enableServerless)
        ? [
            {
              name: 'EnableServerless'
            }
          ]
        : [],
      (kind == 'MongoDB')
        ? [
            {
              name: 'EnableMongo'
            }
          ]
        : [],
      (enableNoSQLVectorSearch)
        ? [
            {
              name: 'EnableNoSQLVectorSearch'
            }
          ]
        : []
    )
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  parent: account
  name: databaseName
  properties: {
    resource: { id: databaseName }
  }

  resource documentContainer 'containers' = {
      name: containerName
      properties: {
        resource: {
          id: containerName
          partitionKey: {
            kind: 'Hash'
            version: 2
            paths: [
              '/id'
            ]            
          }
        }
      }
    }

  resource memoryContainer 'containers' = {
      name: 'memory'
      properties: {
        resource: {
          id: 'memory'
          partitionKey: {
            kind: 'Hash'
            version: 2
            paths: [
              '/session_id'
            ]
          }
        }
      }
    }
}

output name string = account.name
output endpoint string = account.properties.documentEndpoint
output key string = listKeys(account.id, '2024-05-15').primaryMasterKey
