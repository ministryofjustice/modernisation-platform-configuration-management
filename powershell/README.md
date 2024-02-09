# Modernisation Platform Powershell Modules and Scripts

## Introduction

For provisioning and in-life management of windows EC2 instances.

## Using powershell to provision an EC2 instance

Use `user_data` to provide a shell script which runs powershell. 
This should retrieve modules and scripts from this repo, for example:

```
TODO
```

Or alternatively, invoke SSM documents which in turn run powershell.

## Running powershell locally on a windows EC2 instance

Preferred approach is to use SSM Documents to encapsulate the powershell.
The SSM Documents can be executed against the given EC2 instances.

