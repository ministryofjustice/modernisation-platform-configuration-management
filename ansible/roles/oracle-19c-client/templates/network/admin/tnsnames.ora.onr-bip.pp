# Managed by ansible modernisation-platform-configuration-management repo, oracle-19c-client role

PPBOAUD =
 (DESCRIPTION =
  (ENABLE = broken)
  (ADDRESS = (PROTOCOL = TCP)(HOST = pp-oasys-db-a.oasys.hmpps-preproduction.modernisation-platform.internal)(PORT = 1521))
  (CONNECT_DATA =
   (SERVER = DEDICATED)
   (SERVICE_NAME = BIAUD_TAF)
  )
 )

PPBOSYS =
 (DESCRIPTION =
  (ENABLE = broken)
  (ADDRESS = (PROTOCOL = TCP)(HOST = pp-oasys-db-a.oasys.hmpps-preproduction.modernisation-platform.internal)(PORT = 1521))
  (CONNECT_DATA =
   (SERVER = DEDICATED)
   (SERVICE_NAME = BISYS_TAF)
  )
 )

OASYSREP =
 (DESCRIPTION =
  (ENABLE = broken)
  (ADDRESS = (PROTOCOL = TCP)(HOST = db.pp.onr.hmpps-preproduction.modernisation-platform.service.justice.gov.uk)(PORT = 1521))
  (CONNECT_DATA =
   (SERVER = DEDICATED)
   (SERVICE_NAME = OASYSREP_TAF)
  )
 )
