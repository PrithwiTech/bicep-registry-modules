# Changelog

The latest version of the changelog can be found [here](https://github.com/Azure/bicep-registry-modules/blob/main/avm/res/azure-stack-hci/logical-network/CHANGELOG.md).
## 0.3.0

### Changes

- Updated API version from `2024-05-01-preview` to `2026-02-01-preview`
- Added optional `networkSecurityGroupResourceId` parameter for subnet-level NSG association
- Added optional `lock` interface for resource locking (AVM RMFR4 compliance)
- Updated module metadata to reflect Azure Local rebranding (formerly Azure Stack HCI)
- Fixed test files: removed deprecated `domainAdminPassword` property
- Bumped `avm/res/azure-stack-hci/cluster` dependency from `0.1.6` to `0.2.0` in tests
- Removed unsupported `addressPrefixes` property (not supported by current cluster extension)

### Breaking Changes

- None

## 0.2.0

### Changes

- Support ipPools

### Breaking Changes

- Removed input parameter `startingAddress`
- Removed input parameter `endingAddress`

## 0.1.1

### Changes

- Initial version
- Updated ReadMe with AzAdvertizer reference

### Breaking Changes

- None
