targetScope = 'subscription'

metadata name = 'Using default config'
metadata description = 'This instance deploys the module with the minimum set of required parameters.'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'dep-${namePrefix}-azurestackhci.vmi-${serviceShort}-rg'

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'ashvmimin'

@description('Optional. A token to inject into the name of each resource. This value can be automatically injected by the CI.')
param namePrefix string = '#_namePrefix_#'

@description('Required. The password of the LCM deployment user and local administrator accounts.')
@secure()
param arbLocalAdminAndDeploymentUserPass string = ''

@description('Required. The app ID of the service principal used for the Azure Stack HCI Resource Bridge deployment.')
@secure()
#disable-next-line secure-parameter-default
param arbDeploymentAppId string = ''

@description('Required. The service principal ID of the service principal used for the Azure Stack HCI Resource Bridge deployment.')
@secure()
#disable-next-line secure-parameter-default
param arbDeploymentSPObjectId string = ''

@description('Required. The secret of the service principal used for the Azure Stack HCI Resource Bridge deployment.')
@secure()
#disable-next-line secure-parameter-default
param arbDeploymentServicePrincipalSecret string = ''

@description('Optional. The service principal ID of the Azure Stack HCI Resource Provider.')
@secure()
#disable-next-line secure-parameter-default
param hciResourceProviderObjectId string = ''

@description('Optional. The password to use for the local and domain accounts in the test.')
param localAdminAndDeploymentUserPass string = newGuid()

// Kept as a param so the CI pipeline can inject it as a secret, but it is NOT
// forwarded to nestedDependencies — that module does not declare this parameter (BCP037).
@description('Optional. The resource ID of a pre-baked Azure Compute Gallery image for the HCI host VM.')
@secure()
#disable-next-line secure-parameter-default
param hciHostImageReferenceId string = ''

#disable-next-line no-hardcoded-location // Due to quotas and capacity challenges, this region must be used in the AVM testing subscription
var enforcedLocation = 'southeastasia'

// ============ //
// Dependencies //
// ============ //

// Fixed: was 2021-04-01 (1852 days old)
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: enforcedLocation
}

module nestedDependencies '../../../../../../../utilities/e2e-template-assets/module-specific/azure-stack-hci/dependencies/dependencies.bicep' = {
  name: '${uniqueString(deployment().name, enforcedLocation)}-test-nestedDependencies-${serviceShort}'
  scope: resourceGroup
  params: {
    clusterName: '${namePrefix}${serviceShort}1'
    clusterWitnessStorageAccountName: 'dep${namePrefix}wst${serviceShort}'
    keyVaultDiagnosticStorageAccountName: 'dep${namePrefix}st${serviceShort}'
    keyVaultName: 'dep-${namePrefix}-kv-${serviceShort}'
    userAssignedIdentityName: 'dep-${namePrefix}-msi-${serviceShort}'
    maintenanceConfigurationName: 'dep-${namePrefix}-mc-${serviceShort}'
    maintenanceConfigurationAssignmentName: 'dep-${namePrefix}-mca-${serviceShort}'
    HCIHostVirtualMachineScaleSetName: 'dep-${namePrefix}-hvmss-${serviceShort}'
    virtualNetworkName: 'dep-${namePrefix}-vnet-${serviceShort}'
    networkSecurityGroupName: 'dep-${namePrefix}-nsg-${serviceShort}'
    networkInterfaceName: 'dep-${namePrefix}-mice-${serviceShort}'
    virtualMachineName: 'dep-${namePrefix}-vm-${serviceShort}'
    arbDeploymentAppId: arbDeploymentAppId
    arbDeploymentServicePrincipalSecret: arbDeploymentServicePrincipalSecret
    arbDeploymentSPObjectId: arbDeploymentSPObjectId
    deploymentUserPassword: arbLocalAdminAndDeploymentUserPass
    localAdminPassword: arbLocalAdminAndDeploymentUserPass
    // hciHostImageReferenceId intentionally NOT passed here —
    // dependencies.bicep does not declare this parameter (fixes BCP037).
    location: enforcedLocation
  }
}

module azlocal 'br/public:avm/res/azure-stack-hci/cluster:0.4.0' = {
  name: '${uniqueString(deployment().name, enforcedLocation)}-test-clustermodule-${serviceShort}'
  scope: resourceGroup
  params: {
    name: nestedDependencies.outputs.clusterName
    deploymentUser: 'deployUser'
    deploymentUserPassword: arbLocalAdminAndDeploymentUserPass
    localAdminUser: 'Administrator'
    localAdminPassword: arbLocalAdminAndDeploymentUserPass
    servicePrincipalId: arbDeploymentAppId
    servicePrincipalSecret: arbDeploymentServicePrincipalSecret
    hciResourceProviderObjectId: hciResourceProviderObjectId
    deploymentSettings: {
      customLocationName: '${namePrefix}${serviceShort}-location'
      clusterNodeNames: nestedDependencies.outputs.clusterNodeNames
      clusterWitnessStorageAccountName: nestedDependencies.outputs.clusterWitnessStorageAccountName
      defaultGateway: '172.20.0.1'
      deploymentPrefix: 'a${take(uniqueString(namePrefix, serviceShort), 7)}'
      dnsServers: ['172.20.0.1']
      domainFqdn: 'hci.local'
      domainOUPath: nestedDependencies.outputs.domainOUPath
      startingIPAddress: '172.20.0.55'
      endingIPAddress: '172.20.0.65'
      enableStorageAutoIp: true
      keyVaultName: nestedDependencies.outputs.keyVaultName
      networkIntents: [
        {
          adapter: ['FABRIC', 'FABRIC2']
          name: 'ManagementCompute'
          overrideAdapterProperty: true
          adapterPropertyOverrides: {
            jumboPacket: '9014'
            networkDirect: 'Disabled'
            networkDirectTechnology: 'iWARP'
          }
          overrideQosPolicy: false
          qosPolicyOverrides: {
            bandwidthPercentageSMB: '50'
            priorityValue8021ActionCluster: '7'
            priorityValue8021ActionSMB: '3'
          }
          overrideVirtualSwitchConfiguration: false
          virtualSwitchConfigurationOverrides: {
            enableIov: 'true'
            loadBalancingAlgorithm: 'Dynamic'
          }
          trafficType: ['Management', 'Compute']
        }
        {
          adapter: ['StorageA']
          name: 'Storage'
          overrideAdapterProperty: true
          adapterPropertyOverrides: {
            jumboPacket: '9014'
            networkDirect: 'Disabled'
            networkDirectTechnology: 'iWARP'
          }
          overrideQosPolicy: true
          qosPolicyOverrides: {
            bandwidthPercentageSMB: '50'
            priorityValue8021ActionCluster: '7'
            priorityValue8021ActionSMB: '3'
          }
          overrideVirtualSwitchConfiguration: false
          virtualSwitchConfigurationOverrides: {
            enableIov: 'true'
            loadBalancingAlgorithm: 'Dynamic'
          }
          trafficType: ['Storage']
        }
      ]
      storageConnectivitySwitchless: false
      storageNetworks: [
        {
          name: 'Storage1Network'
          adapterName: 'StorageA'
          vlan: '711'
        }
      ]
      subnetMask: '255.255.255.0'
    }
  }
}

// Fixed API version: was 2021-08-31-preview (1700 days old)
// dependsOn is valid on existing resources — only scope must be static (BCP120)
resource customLocation 'Microsoft.ExtendedLocation/customLocations@2021-08-15' existing = {
  scope: resourceGroup
  name: '${namePrefix}${serviceShort}-location'
  dependsOn: [
    azlocal
  ]
}

module hciImage 'br/public:avm/res/azure-stack-hci/marketplace-gallery-image:0.1.0' = {
  name: '${uniqueString(deployment().name, enforcedLocation)}-test-mgi-${serviceShort}'
  scope: resourceGroup
  params: {
    name: '${namePrefix}${serviceShort}marketplaceimage'
    customLocationResourceId: customLocation.id
    identifier: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2022-datacenter-azure-edition-core'
    }
    osType: 'Windows'
    version: {
      name: '20348.4830.260305'
    }
  }
}

// ============== //
// Test Execution //
// ============== //

module testDeployment '../../../main.bicep' = {
  name: '${uniqueString(deployment().name, enforcedLocation)}-vm-${serviceShort}'
  scope: resourceGroup
  params: {
    name: '${uniqueString(deployment().name, enforcedLocation)}-hc-${serviceShort}'
    customLocationResourceId: customLocation.id
    // adminPassword passed as top-level param so main.bicep's union() does not
    // overwrite it with null when osProfile is merged.
    adminPassword: localAdminAndDeploymentUserPass
    hardwareProfile: {
      memoryMB: 4096
      processors: 2
    }
    networkProfile: {}
    osProfile: {
      computerName: take('${namePrefix}${serviceShort}', 15)
      linuxConfiguration: {}
      windowsConfiguration: {
        provisionVMAgent: true
        provisionVMConfigAgent: true
      }
      adminUsername: 'Administrator'
    }
    storageProfile: {
      imageReference: { id: hciImage.outputs.resourceId }
      osDisk: {
        osType: 'Windows'
      }
    }
  }
}
