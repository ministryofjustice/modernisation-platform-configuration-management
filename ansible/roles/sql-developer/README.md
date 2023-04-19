Role for installing Oracle SQL Developer tools onto jumpservers for dba's debugging purposes

Since downloading SQL Developer requires an oracle.com login (username/passwort) we are storing the (jdk included) version in the S3 bucket. The role will download the file from S3 and install it.

The version of SQL Developer has been provided by the DBA team.
