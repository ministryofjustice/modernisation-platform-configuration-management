# Modernisation Platform Powershell Modules and Scripts

## Introduction

For provisioning and in-life management of windows EC2 instances.

## Pre-requisite

Install git on EC2 if not already in AMI, e.g.

```
choco install git.install -y
```

## Directory structure and Naming

### Modules

A module contains a collection of functions available for use 
in other modules or scripts. There is a helper script for creating
the manifest file.  Create a directory for each module under
`powershell/Modules/` folder.

Please add a README.md to the module directory.
Please add powershell comments to exported functions to enable `Get-Help`:

```
Get-Help Get-ModPlatformADConfig
```

### Scripts

Put scripts in a `powershell/Scripts` folder. For example, active
directory related scripts in `powershell/Scripts/ModPlatformAD`

### Naming

Be consistent. Pascal case (capitalize the first letter of each word) except keywords
and operators which are in lower case.

Verbs: https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.4
Formatting: https://poshcode.gitbook.io/powershell-practice-and-style/style-guide/code-layout-and-formatting

## Using powershell to provision an EC2 instance

There is a wrapper script `Run-GitScript.ps1` for cloning the repo,
configuring modules and running script.  Similar to the equivalent
`ansible-script` role in ansible directory.

Configure `user_data` in terraform like this

```
version: 1.0 # version 1.0 is required as this executes AFTER the SSM Agent is running
tasks:
  - task: executeScript
    inputs:
      - frequency: once
        type: powershell
        runAs: admin
        content: |-
          Set-Location -Path ([System.IO.Path]::GetTempPath())
          $GitBranch = "main"
          $Script = "ModPlatformAD/Join-ModPlatformAD.ps1"
          $ScriptArgs = @{"NewHostname" = "tag:Name"}
          [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # since powershell 4 uses Tls1 as default
          Invoke-WebRequest "https://raw.githubusercontent.com/ministryofjustice/modernisation-platform-configuration-management/${GitBranch}/powershell/Scripts/Run-GitScript.ps1" -OutFile "Run-GitScript.ps1"
          . ./Run-GitScript.ps1 $Script -ScriptArgs $ScriptArgs -GitBranch $GitBranch
```

This example downloads the wrapper script and executes it with an example script.
The wrapper script will clone the repo, ensure `powershell/Modules` are available,
and execute the script.

## Running powershell locally on a windows EC2 instance

Preferred approach is to use SSM Documents to encapsulate the powershell.
The SSM Documents can be executed against the given EC2 instances.
