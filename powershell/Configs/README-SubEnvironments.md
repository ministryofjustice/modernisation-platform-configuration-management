# Enhanced Cluster-Based Configuration System

## Overview

This enhanced configuration system supports multiple IPS/DataServices clusters within a single environment using a **primary node name as configuration key** approach. This flexible design accommodates any environment structure without requiring specific naming patterns or sub-environment concepts.

## Key Benefits

✅ **Flexible**: Works with any machine naming convention  
✅ **Explicit**: Each cluster is explicitly defined by its primary node name  
✅ **Backward Compatible**: Existing configurations continue to work  
✅ **Scalable**: Easily add new clusters to any environment  
✅ **No Assumptions**: No rigid sub-environment patterns required  

## Architecture

### Configuration Structure

The system uses a **primary node name as the configuration key** approach:

```powershell
$ApplicationConfig = @{
    # Environment-level defaults (backward compatibility)
    'delius-mis-preproduction' = @{
        # Default configuration
    }
    
    # Cluster-specific configurations (keyed by primary node name)
    'delius-mis-stage-dfi-1' = @{
        'EnvironmentName' = 'delius-mis-preproduction'
        'ClusterName'     = 'stage'
        'NodeConfig'      = @{
            'cmsPrimaryNode'   = 'delius-mis-stage-dfi-1'
            'cmsSecondaryNode' = 'delius-mis-stage-dfi-2'
        }
        # Cluster-specific database, service configs, etc.
    }
    
    'delius-mis-pp-dfi-1' = @{
        'EnvironmentName' = 'delius-mis-preproduction'
        'ClusterName'     = 'pp'
        'NodeConfig'      = @{
            'cmsPrimaryNode'   = 'delius-mis-pp-dfi-1'
            'cmsSecondaryNode' = 'delius-mis-pp-dfi-2'
        }
        # Different database, etc.
    }
}
```

### How It Works

1. **Machine boots** with Name tag (e.g., `delius-mis-stage-dfi-2`)
2. **System searches** all configurations for matching primary/secondary nodes
3. **Finds cluster config** `'delius-mis-stage-dfi-1'` (matches secondary node)
4. **Returns configuration** with `DetectedRole = 'secondary'`
5. **Install scripts** use the role and cluster-specific settings

## Real-World Examples

### Example 1: MISDis Preproduction with Two Clusters

```powershell
# Environment has two separate clusters with different databases
'delius-mis-preproduction' = @{
    # Legacy fallback configuration
}

'delius-mis-stage-dfi-1' = @{
    'EnvironmentName' = 'delius-mis-preproduction'
    'ClusterName'     = 'stage'
    'DatabaseConfig'  = @{
        'sysDbName' = 'DMPDSD'  # Stage database
    }
    'NodeConfig' = @{
        'cmsPrimaryNode'   = 'delius-mis-stage-dfi-1'
        'cmsSecondaryNode' = 'delius-mis-stage-dfi-2'
    }
}

'delius-mis-pp-dfi-1' = @{
    'EnvironmentName' = 'delius-mis-preproduction'
    'ClusterName'     = 'pp'
    'DatabaseConfig'  = @{
        'sysDbName' = 'DMPPSD'  # Different database
    }
    'NodeConfig' = @{
        'cmsPrimaryNode'   = 'delius-mis-pp-dfi-1'
        'cmsSecondaryNode' = 'delius-mis-pp-dfi-2'
    }
}
```

### Example 2: ONR Test with Multiple Clusters

```powershell
# Environment will have multiple clusters with different purposes
't2-onr-bods-1' = @{
    'EnvironmentName' = 'oasys-national-reporting-test'
    'ClusterName'     = 'cluster1'
    'DatabaseConfig'  = @{
        'sysDbName' = 'T2BOSYS'
    }
    'NodeConfig' = @{
        'cmsPrimaryNode'   = 't2-onr-bods-1'
        'cmsSecondaryNode' = 't2-onr-bods-2'
    }
}

't2-onr-bods-3' = @{
    'EnvironmentName' = 'oasys-national-reporting-test'
    'ClusterName'     = 'cluster2'
    'DatabaseConfig'  = @{
        'sysDbName' = 'T2BOSYS2'  # Different database
    }
    'NodeConfig' = @{
        'cmsPrimaryNode'   = 't2-onr-bods-3'
        'cmsSecondaryNode' = 't2-onr-bods-4'
    }
}
```

## Configuration Resolution Process

The system uses this lookup order:

1. **Search all configs** for machine name matching primary/secondary nodes
2. **If found**: Use cluster-specific configuration
3. **If not found**: Fall back to environment-level configuration
4. **If still not found**: Use base template with warnings

```
Machine: delius-mis-pp-dfi-2
↓
Search for configs where machine matches primary/secondary nodes
↓
Found: 'delius-mis-pp-dfi-1' config (machine matches secondary node)
↓
Return: Configuration with DetectedRole = 'secondary', ClusterName = 'pp'
```

## Key Fields Returned

- **`ConfigKey`**: The configuration key used (e.g., `'delius-mis-pp-dfi-1'`)
- **`DetectedRole`**: `'primary'` or `'secondary'`
- **`ClusterName`**: Optional cluster identifier for logging
- **`EnvironmentName`**: Original environment name for reference

## Usage in Install Scripts

The install scripts automatically use the detected role:

```powershell
$Config = Get-Config

# Enhanced automatic role detection
$nodeType = if ($Config.ContainsKey('DetectedRole') -and $Config.DetectedRole -ne 'unknown') {
    $Config.DetectedRole  # Use automatically detected role
} else {
    # Fallback to legacy detection
    # ... legacy logic
}

Write-Host "Node type: $nodeType"
Write-Host "Using configuration: $($Config.ConfigKey)"
Write-Host "Cluster: $($Config.ClusterName)"
```

## Adding New Clusters

To add a new cluster to any environment:

1. **Add cluster configuration** using primary node name as key
2. **Deploy machines** with appropriate names
3. **System automatically detects** cluster membership
4. **No changes needed** to install scripts

### Example: Adding Third Cluster to ONR Test

```powershell
# Just add this to the ONR config:
't2-onr-bods-5' = @{
    'EnvironmentName' = 'oasys-national-reporting-test'
    'ClusterName'     = 'cluster3'
    'DatabaseConfig'  = @{
        'sysDbName' = 'T2BOSYS3'
    }
    'NodeConfig' = @{
        'cmsPrimaryNode'   = 't2-onr-bods-5'
        'cmsSecondaryNode' = 't2-onr-bods-6'
    }
    'TnsConfig' = @{
        'tnsOraFile' = 'ONR\tnsnames_T2_CLUSTER3_BODS.ora'
    }
}
```

## Backward Compatibility

- **Existing machines**: Continue to work with environment-level configs
- **Existing deployments**: No changes required
- **Legacy configs**: Remain as fallbacks
- **Migration**: Can be done gradually per cluster

## Testing

Use the test script to verify configuration:

```powershell
.\Scripts\Test-ClusterConfig.ps1
```

Tests include:
- Multiple cluster detection
- Role assignment
- Backward compatibility
- Cross-application scenarios

## Migration Strategy

### Phase 1: Add Cluster Configs
Add cluster-specific configurations alongside existing environment configs.

### Phase 2: Deploy New Machines
Deploy machines that will match cluster configurations.

### Phase 3: Validate
Use test scripts to verify correct cluster assignment.

### Phase 4: Clean Up (Optional)
Remove redundant environment-level configs once all machines use cluster configs.

## Troubleshooting

### Machine Not Found in Any Cluster

```
Warning: No configuration found for machine 'unknown-machine' in environment 'test-env'
```

**Solution**: Add cluster configuration or ensure machine name matches existing cluster nodes.

### Wrong Database Connection

**Check**: 
- Machine name matches cluster primary/secondary nodes exactly
- Cluster configuration has correct database settings
- TNS configuration points to right database

### Role Detection Issues

**Debug Info Available**:
- `ConfigKey`: Which configuration was used
- `DetectedRole`: Detected primary/secondary role  
- `ClusterName`: Cluster identifier
- `NormalizedMachineName`: Normalized name (for MISDis)

Look for these fields in install script output for troubleshooting.
