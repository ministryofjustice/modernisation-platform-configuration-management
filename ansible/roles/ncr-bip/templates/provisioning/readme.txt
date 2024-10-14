------------------------------------------------------------------------------------------
Version: 5.0.0

Provisioning configuration setup for Provisioning on the BIP servers.
NOTE: Single SignOn (SSO) code has been remove since v5.0.0
NOTE: This code is installed via ansible modernisation-platform-configuration-management repo, ncr-bip role
------------------------------------------------------------------------------------------

<install dir> = The directory where the provisioning files have been extracted to (i.e. /u01/app/bobj/java/provisioning_5).


Directory structure
-------------------

<install dir>
      |_ conf     - Contains configuration files. Environment specific.
      |_ lib      - Contains the provisioning_5.jar file and its dependencies.
                    NOTE: The provisioning_5.jar file is in this directory as a backup and to enable the scripts to run.
                          This jar file is added to the CMS and scheduled via the CMC and is executed from the BIP 4.x FRS.
                          HOWEVER: If the whole lib directory or the provisioning_5.jar file is in the classpath then that one will be used.
      |_ logs     - Contains the log4j log file.
      |_ scripts  - Contains scripts to verify and test various elements of the provisioning code.



System Configuration
--------------------

The following changes must be made on each environment to complete the configuration for the provisioning:

- Amend file <install dir>/conf/defaultSys.properties to reflect the environment.

- Amend the following lines in file <install dir>/conf/log4j.provisioning.properties to the required settings.

    - log4j.debug=false                                 -- true to enable debugging for log4j, anything else disables debugging.
                                                           Debugging should be disabled in a production environment.

    - log4j.rootLogger=????, nomis, stdout              -- ???? should normally be set to 'info' (in a production environment)
                                                                Set it to 'debug' to enable additional logging.

    - log4j.appender.nomis.File=????/provisioning.html  -- ???? should be set to the location of where the log file will be written to,
                                                                normally <install dir>/logs

    - log4j.appender.nomis.Threshold=????               -- ???? should normally be set to 'info' (in a production environment)
                                                                Set it to 'debug' to enable additional logging.

    - log4j.appender.stdout.Threshold=????              -- ???? should normally be set to 'info' (in a production environment)
                                                                Set it to 'debug' to enable additional logging.

- Amend file <install dir>/conf/dbconnection.properties to reflect the oracle connection information to the P-NOMIS database.

- Amend the following line in file <install dir>/scripts/provisioning_env.sh
    
    - INSTALLDIR=????   -- ???? should be set to <install dir>
