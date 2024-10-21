#!/bin/bash

# Script for pulling each SI_KIND set of objects in turn from the biprws interface.
# NOTE: SQL may need something like `SELECT TOP 10000` to ensure all objects returned

apps="AdminConsole
AdminTool
AlertingApp
AnalyticsHubPublishedData
AnalyticsHubPublishedDocumentList
#AnalyticsHubQueue
#AnalyticsHubSACToken
AnalyticsHubServiceRTI
AO.Plugin
AppFoundation
AutomationFramework
BEX.BExWeb
BICommentaryApplication
BIonBI
BIP.CafApplication
busobjReporter
CCIS.DataConnection
ClientAction
ClientActionSet
ClientActionUsage
CMC
CRConfig
DataSearchUniverseDataAccessProvider
Designer
DSL.MetaDataFile
Folder
HANAAuthentication
InformationControlCenter
InformationDesigner
InfoView
LCM
LCMOverride
LCMSettings
MOB_Mobile
MON.ManagedEntityStatus
MON.MBeanConfig
MON.MonAppDataStore
MON.Monitoring
MultitenancyManager
OpenDocument
Pioneer
PlatformSearchApplication
PlatformSearchApplicationStatus
PlatformSearchContentExtractor
PlatformSearchContentStore
PlatformSearchIndexEngine
PlatformSearchQueue
PlatformSearchSearchAgent
PlatformSearchServiceSession
RecycleBinApplication
RestWebService
SAPAnalyticsCloud
StreamWorkIntegration
TransMgr
VisualDiff
VisualDiffApp
VMS
WebIntelligence
WebService"

systems="AdminConsole
AdminTool
AFDashboardPage
Agent
Agnostic
AlertingApp
AlertNotification
Analytic
AnalyticsHubPublishedData
AnalyticsHubPublishedDocumentList
AnalyticsHubQueue
AnalyticsHubSACToken
AnalyticsHubServiceRTI
AO.Plugin
AO.Presentation
AO.Workbook
AppFoundation
AppObjectsFolder
AuditAdmin
AuditEventInfo
AuditEventInfo2
AutomationFramework
BEX.BExWeb
BICommentaryApplication
BIonBI
BIP.CafApplication
BIVariant
busobjReporter
CacheServerAdmin
Calendar
Category
CCIS.DataConnection
ClientAction
ClientActionSet
ClientActionUsage
CMC
CMSAdmin
CommonConnection
Connection
CRConfig
CryptographicKey
CrystalReport
CsContainerAdmin
CustomMappedAttribute
CustomRole
DataDiscovery
DataDiscoveryAlbum
DataFederator.DataSource
DataSearchUniverseDataAccessProvider
DatasourceReference
DeltaStore
DependencyRule
DeploymentFile
Designer
Destination
DFS.ConnectorConfiguration
DFS.Parameters
DFS.TableStatistics
DiscussionsProgram
DiskUnmanaged
DocProcessingCacheAdmin
DocProcessingProcAdmin
DSL.MetaDataFile
EnterpriseNode
Event
EventServerAdmin
Excel
FavoritesFolder
Federation
FileServerAdmin
Flash
Folder
Ftp
FullClient
FullClientAddin
FullClientCacheAdmin
FullClientProcAdmin
FullClientTemplate
GDPRObject
HANAAuthentication
HotBackup
HTMLWhiteList
Hyperlink
Inbox
InfoObject
InfoObjectsFolder
InformationControlCenter
InformationDesigner
InfoView
Install
JavaScheduling
JobServerAdmin
KCDefinitions
KCProductDescriptions
Landscape
LandscapeConnection
LCM
LCMJob
LCMOverride
LCMScan
LCMScanHistory
LCMSettings
LicenseKey
LicenseRestriction
LiveOffice
Managed
Manifest
MDAnalysis
MetaData.BusinessCompositeFilter
MetaData.BusinessElement
MetaData.BusinessField
MetaData.BusinessFilter
MetaData.BusinessFormulaField
MetaData.BusinessParameterField
MetaData.BusinessView
MetaData.DataCommandTable
MetaData.DataConnection
MetaData.DataDBField
MetaData.DataFoundation
MetaData.DataProcedure
MetaData.DataTable
MetaData.DynamicDataConnection
MetaData.MetaDataCustomFunction
MetaData.MetaDataPictureObject
MetaData.MetaDataRepositoryInfo
MetaData.MetaDataTextObject
MetaData.ReportCommand
MetricDescriptions
MobileOfflineDocuments
MobileSubscriptions
MOB_Mobile
MON.ManagedEntityStatus
MON.MBeanConfig
MON.MonAppDataStore
MON.Monitoring
MON.NewDB
MON.Probe
MON.Subscription
MultitenancyManager
MyInfoView
Note
NotificationSchedule
ObjectPackage
OLP.CustomGroup
OpenDocument
Overload
OverrideEntry
PageServerAdmin
Pdf
PersonalCategory
Pioneer
PlatformSearchApplication
PlatformSearchApplicationStatus
PlatformSearchContentExtractor
PlatformSearchContentStore
PlatformSearchContentSurrogate
PlatformSearchDeltaIndex
PlatformSearchIndexEngine
PlatformSearchQueue
PlatformSearchScheduling
PlatformSearchSearchAgent
PlatformSearchServiceSession
Powerpoint
pQuery
Profile
Program
Publication
QaaWS
RecycleBin
RecycleBinApplication
RemoteCluster
Replication
ReportAppServerAdmin
RepositoryPromptGroup
RestWebService
Rtf
SAMLServiceProvider
SAPAnalyticsCloud
Scenario
ScopeBatch
secEnterprise
secLDAP
Server
ServerGroup
Service
ServiceCategory
ServiceContainer
Sftp
SharedElement
SharedQuery
Shortcut
Smtp
SSOAdmin
StreamWork
StreamWorkIntegration
SystemObjectsFolder
TaskTemplate
Tenant
TransMgr
Txt
Universe
#User
UserGroup
VisualDiff
VisualDiffApp
VisualDiffComparator
VMS
Webi
WebIntelligence
WebService
Word
WorkflowTemplate
XL.XcelsiusEnterprise"

infos="Category
DFS.Parameters
Excel
#FavoritesFolder
Folder
Hyperlink
#Inbox
Landscape
LandscapeConnection
#LCMJob
LicenseRestriction
MON.Probe
NotificationSchedule
#PersonalCategory
PlatformSearchScheduling
SharedElement
TaskTemplate
Txt
Webi
WorkflowTemplate"

if [[ -z $1 ]]; then
    echo "Usage: $0 <prefix>"
    exit 1
fi
prefix=$1

if [[ ! -x ./biprws.sh ]]; then
    echo "Must be run from same directory as biprws.sh"
    exit 1
fi

mkdir -p "$prefix"

echo "Enter Administrator password"
read -rs ADMINPASSWORD
export PASSWORD="$ADMINPASSWORD"

for app in $apps; do
    if [[ ! -e $prefix.appobjects.$app.json && ${app:0:1} != "#" ]]; then
	echo "SELECT * FROM CI_APPOBJECTS WHERE SI_KIND='$app'" >&2
        ./biprws.sh "SELECT * FROM CI_APPOBJECTS WHERE SI_KIND='$app'" > "$prefix/appobjects.$app.json"
    fi
done

for info in $infos; do
    if [[ ! -e $prefix.infoobjects.$info.json && ${info:0:1} != "#" ]]; then
	echo "SELECT * FROM CI_INFOOBJECTS WHERE SI_KIND='$info'" >&2
        ./biprws.sh "SELECT * FROM CI_INFOOBJECTS WHERE SI_KIND='$info'" > "$prefix/infoobjects.$info.json"
    fi
done

for system in $systems; do
    if [[ ! -e $prefix.systemobjects.$system.json && ${system:0:1} != "#" ]]; then
	echo "SELECT * FROM CI_SYSTEMOBJECTS WHERE SI_KIND='$system'" >&2
        ./biprws.sh "SELECT * FROM CI_SYSTEMOBJECTS WHERE SI_KIND='$system'" > "$prefix/systemobjects.$system.json"
    fi
done

echo "Creating /tmp/$prefix.tgz"
tar czf "/tmp/$prefix.tgz" "$prefix"
echo "Deleting temporary $prefix directory"
rm -rf "$prefix"
