This role installs Oracle 19c. It assumes the installation disks `\u01` and `\u02` have already been setup (with `disks` role for example).

### Tags

Some tasks are optional and can be included in the play by adding the appropriate tag at the command line. Currently these are:

E.g. Run `ansible-playbook` with `--tags "oracle_19c_install,pre_install,configure_asm,install_grid,install_database,post_install" " to run the Oracle install tasks 

### s3 bucket

The Oracle installation files should be located in an s3 bucket accessible by the remote host. The files should all have the same prefix and the prefix should be included as part of the variable, hence the variable name `s3_bucket_with_prefix`.

### Oracle ASM disks

Oracle ASM (Automatic Storage Manager) ASMLIB is used as the volume manager for Oracle database disks rather than manual configuration with [UDEV rules](https://dsdmoj.atlassian.net/wiki/spaces/DSTT/pages/579994207/UDEV+configuraion+for+ASM+Disks). The variables `oracle_asm_data_disks` and `oracle_asm_flash_disks` contains a list of devices to be configured by ASMlib and should match the device configuration on the remote host (in terms of matching the device names to the required ASM disk labels).

### Issues
With el8 currently we have issue with Oracle 19c Grid ASM disks discovery with ORCL , its working with only /dev/oracleasm/disks. With ORCL it results in ORA-7445 [kgfkWaitIO] , raised SR with oracle to get fix for this issue. 
