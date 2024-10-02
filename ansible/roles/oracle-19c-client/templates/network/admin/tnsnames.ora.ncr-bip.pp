# Managed by ansible modernisation-platform-configuration-management repo, oracle-19c-client role

PPBIAUD =
  (DESCRIPTION =
    (ADDRESS = (HOST = db.preproduction.reporting.nomis.service.justice.gov.uk)(PROTOCOL = TCP)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = BIAUD_TAF)
    )
  )

PPBISYS =
  (DESCRIPTION =
    (ADDRESS = (HOST = db.preproduction.reporting.nomis.service.justice.gov.uk)(PROTOCOL = TCP)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = BISYS_TAF)
    )
  )

CNOMPP =
 (DESCRIPTION =
  (ENABLE=broken)
  (ADDRESS = (HOST = ppor-a.preproduction.nomis.service.justice.gov.uk) (protocol = tcp) (port = 1521))
  (ADDRESS = (HOST = ppor-b.preproduction.nomis.service.justice.gov.uk) (protocol = tcp) (port = 1521))
  (FAILOVER = YES)
  (CONNECT_DATA =
   (SERVICE_NAME = OR_TAF)
   (FAILOVER_MODE =
    (TYPE = SELECT)
    (METHOD = BASIC)
   )
  )
 )

CNMAUDPP =
 (DESCRIPTION =
  (ENABLE=broken)
  (ADDRESS = (HOST = ppaudit-a.preproduction.nomis.service.justice.gov.uk) (protocol = tcp) (port = 1521))
  (ADDRESS = (HOST = ppaudit-b.preproduction.nomis.service.justice.gov.uk) (protocol = tcp) (port = 1521))
  (FAILOVER = YES)
  (CONNECT_DATA =
   (SERVICE_NAME = CNMAUD_TAF)
   (FAILOVER_MODE =
    (TYPE = SELECT)
    (METHOD = BASIC)
   )
  )
 )

MISPP =
 (DESCRIPTION =
  (ENABLE=broken)
  (ADDRESS = (HOST = ppmis-a.preproduction.nomis.service.justice.gov.uk) (protocol = tcp) (port = 1521))
  (ADDRESS = (HOST = ppmis-b.preproduction.nomis.service.justice.gov.uk) (protocol = tcp) (port = 1521))
  (FAILOVER = YES)
  (CONNECT_DATA =
   (SERVICE_NAME = MIS_TAF)
   (FAILOVER_MODE =
    (TYPE = SELECT)
    (METHOD = BASIC)
   )
  )
 )

OASYSREP =
  (DESCRIPTION =
    (ADDRESS = (HOST = db.pp.onr.oasys.service.justice.gov.uk)(PROTOCOL = TCP)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = OASYSREP_TAF)
    )
  )

CNOMISPP =
 (DESCRIPTION =
  (ENABLE=broken)
  (ADDRESS = (HOST = ppnomis-a.preproduction.nomis.service.justice.gov.uk) (protocol = tcp) (port = 1521))
  (ADDRESS = (HOST = ppnomis-b.preproduction.nomis.service.justice.gov.uk) (protocol = tcp) (port = 1521))
  (FAILOVER = YES)
  (CONNECT_DATA =
   (SERVICE_NAME = NOMIS_TAF)
   (FAILOVER_MODE =
    (TYPE = SELECT)
    (METHOD = BASIC)
   )
  )
 )
