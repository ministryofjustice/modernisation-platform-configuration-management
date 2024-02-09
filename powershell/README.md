# Modernisation Platform Powershell Modules and Scripts

## Introduction

For provisioning and in-life management of windows EC2 instances.

## Pre-requisite

Install git on EC2 if not already in AMI, e.g.

```
choco install git.install -y
```

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
          Invoke-WebRequest "https://raw.githubusercontent.com/ministryofjustice/modernisation-platform-configuration-management/${GitBranch}/powershell/Scripts/Run-GitScript.ps1" -OutFile "Run-GitScript.ps1"
          . ./Run-GitScript.ps1 $Script -GitBranch $GitBranch
```

This example downloads the wrapper script and executes it with an example script.
The wrapper script will clone the repo, ensure `powershell/Modules` are available,
and execute the script.

## Running powershell locally on a windows EC2 instance

Preferred approach is to use SSM Documents to encapsulate the powershell.
The SSM Documents can be executed against the given EC2 instances.
