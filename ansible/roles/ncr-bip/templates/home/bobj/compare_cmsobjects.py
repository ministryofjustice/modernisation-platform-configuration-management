#Copyright (c) 2024 Ministry Of Justice

#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

"""Compare SAP BIP database files in json format.

If migrating environments from one location to another, this allows some
basic comparison of configuration, assuming config has been pulled
via biprws API via select statements
"""

import json
import glob
import sys
import difflib

SHOW_PARSE=False
SHOW_MATCHES=False
SHOW_IGNORE=False
SHOW_EXCLUDE_NAME=False
SHOW_EXCLUDE_KIND=False
SHOW_DIFF_SOURCE=False
DIFF_CONTEXT_LINES=100
SHOW_NOT_IN_X_ITEMS=False
SHOW_NOT_IN_Y_ITEMS=False

COMPARE_EXCLUDE_KIND_ALL = [
  "MON.ManagedEntityStatus",
  "MON.Monitoring",
  "VMS",
  "DeploymentFile",
  "EnterpriseNode", # assume this is covered by Server
  "Event",
  "Install",
  "PlatformSearchQueue",
  "Webi",
  "MON.Subscription",
]

COMPARE_EXCLUDE_NAME_ALL = [
  "SI_CREATION_TIME",
  "SI_UPDATE_TS",
  "SI_GUID",
  "SI_RUID",
  "SI_CUID",
  "SI_ID",
  "SI_UID",
  "SI_DFO_CUID",
  "SI_OBTYPE",
  "SI_PARENT_FOLDER",
  "SI_PARENTID",
  "SI_CRAWLER_TASK_OWNER_SESSION_CUID",
  "SI_ANALYTICSHUB_SERVICE_SERVER_SESSIONS",
  "SI_ACTION_PLUGINS",  # revisit?
  "SI_ACTION_ACTION_SETS",
  "SI_ACTION_SET_ACTIONS",
  "SI_USAGE_ACTIONS",
  "SI_USAGE_CONTAINERS",
  "SI_PATH",
  "SI_FILES",
  "SI_CHILDREN",
  "SI_HAS_CHILDREN",
  "SI_AMBER_SUBSCRIPTION_ID",
  "SI_RED_SUBSCRIPTION_ID",
  "SI_TOP_KPIS",
  "SI_PLATFORM_SEARCH_OBJECTS",
  "SI_PLATFORM_SEARCH_LAST_TO_BE_EXTRACTED_DAILY_OBJECT_TIMESTAMP",
  "SI_PLATFORM_SEARCH_LAST_DAILY_REPO_CRAWL_TASK_RUN",
  "SI_PLATFORM_SEARCH_LAST_MAX_DOC_ID_SUGG",
  "SI_PLATFORM_SEARCH_LAST_UPDATED_TIME_SUGG",
  "SI_PLATFORM_SEARCH_LAST_INDEX_MODIFICATION_TIME",
  "SI_PLATFORM_SEARCH_DELETEDIDS_CLEANUP_TIMESTAMP",
  "SI_PLATFORM_SEARCH_TASK_DELETEDINFOOBJECT_COMPLETED_TIMESTAMP",
  "SI_PLATFORM_SEARCH_LAST_TO_BE_EXTRACTED_MAX_ID",
  "SI_PLATFORM_SEARCH_LAST_TO_BE_EXTRACTED_FOLDER_TIMESTAMP",
  "SI_PLATFORM_SEARCH_LAST_TO_BE_EXTRACTED_MAX_FOLDER_ID",
  "SI_PLATFORM_SEARCH_UNIVERSE_EXTRACTION_SESSION",
  "SI_PLATFORM_SEARCH_MERGE_OWNER_SESSION",
  "SI_ROLE_RIGHTS",
  "SI_RIGHTS_FROM_PLUGINS",
  "SI_USING_RELATIONSHIPS",
  "SI_DF_DATA",
  "SI_SERVER_TIMESTAMP",
  "SI_NODE_AUTH_ID",
  "SI_SERVER_IOR",
  "SI_PID",
  "SI_SERVER_TIMESTAMP",
  "SI_DATE",
  "SI_EXPECTED_RUN_STATE_TS",
  "SI_METRICS",
  "SI_AUDITING_THREAD_DATA_RETRIEVED_UNTIL",
  "SI_STATUS_CHECK_TS",
  "SI_PROCESS_ID",
  "SI_REQUIRES_RESTART",
  "SI_SERVER_ALIVE_TIMESTAMPS",
  "SI_RELATIONSHIPS",
  "SI_TIMESTAMP",
  "SI_SERVER_ID",
  "SI_SERVER_DESCRIPTOR",
  "SI_SYSTEM_TIME",
  "SI_SERVER_NAME", # mismatched CMSs?

  "SI_EXPECTED_RUN_STATE", # comment back in
  "SI_REGISTER_TO_APS",
  "SI_SERVERGROUPS",
  "SI_CONNECTION_CONNECTSTRING",
  "SI_CONNECTION_PARAMSTRING",
  "SI_CONNECTION_TIMESTAMP",
  "SI_SL_UPDATE_TS",
  "SI_SL_VERSION_NUMBER",
  "SI_SL_DATA_DIGEST",
  "SI_PLATFORM_SEARCH_UNIVERSE_EXTRACTION_TASK_COMPLETED_TIMESTAMP",
  "SI_PLATFORM_SEARCH_PAYLOAD_ID",
  "SI_PARENT_CUID",
  "SI_PARENT_FOLDER_CUID",
  "SI_TEMPLATE_CUID",
  "SI_VIRTUAL_METRICS",
  "SI_HEALTHPROBE_EXECTIME",
  "SI_CONTAINER_INSTALLS", # check server instead
  "SI_GROUP_MEMBERS", # too big
  "SI_REL_GROUP_MEMBERS", # too big or lookup users
  "SI_ENT_GROUP_MEMBERS", # ditto
  "SI_ENT_SUBGROUPS",
  "SI_ENT_USERGROUPS",
  "SI_REL_USERGROUPS",
  "SI_PLATFORM_SEARCH_LAST_TO_BE_EXTRACTED_TIMESTAMP",
  "SI_NEXT_INSTANCE_ID",
  "SI_FLAGS", # don't know what this is
  "SI_ACTIVE_INSTANCE_ID",
  "SI_ACTIVE_SERVER_PID",
  "SI_ACTIVE_SERVER_ID",
]

COMMAND_LINE = [
   "SI_CURRENT_COMMAND_LINE"
]

# the value of these keys are an SI_ID, lookup the SI_NAME for each SI_ID
SI_KEY = [
  "SI_ROLES_ON_OBJECT",
  "SI_ACTION_APPLICATIONS",
  "SI_ACTION_USAGES",
  "SI_APPLICATION_ACTIONS",
  "SI_DEPENDENCY_RULES",
  "SI_OBJECTS_ASSIGNED_ROLE",
  "SI_ENABLED_AUDIT_EVENTS",
  "SI_SERVER4ENTNODE",
  "SI_EVENT_ALERTNOTIFICATIONS",
  "SI_MANAGED_ENTITY_STATUS",
  "SI_ENTERPRISENODE",
  "SI_SERVERGROUPS",
  "SI_SL_DOCUMENTS",
  "SI_SL_UNIVERSE_TO_CONNECTIONS",
  "SI_FHSQL_WEBI_DOCUMENT",
  "SI_CONNUNIVERSE",
  "SI_WORKFLOWTEMPLATES",
  "SI_TASKTEMPLATES",
  "SI_REL_GROUP_MEMBERS",
  "SI_CONTAINER_INSTANCES",
]

# these keys have a list of metadata, just pull out the given field for comparison
SI_VALUE = {
  "SI_AUDIT_APPLICATIONS": "SI_DESCRIPTION",
  "SI_HOSTED_SERVICES": "SI_NAME",  # TODO, compare other fields
  "SI_CONFIGURED_CONTAINERS": "SI_NAME",  # TODO, compare other fields
  "SI_DEFAULT_OBJECT_FRAGMENTS": "SI_FILENAME",
  "SI_SERVICE_HOSTS": "SI_ID",
  "SI_SERVICE_INSTALLS": "SI_ID",
  "SI_SL_CONTENT_IDS": "SI_TYPE",
  "SI_ALIASES": "SI_NAME",
}

REPLACE_DICT = {
  "ppazure": [
    ("Install1_PPNOMIS2", "Install1_ppncrapp1"),
    ("Install2_PPNOMIS3", "Install2_ppncrcms2"),
    ("PPNOMIS3.AdaptiveProcessingServer1", "PPNOMIS3.APS.DF"),
    ("-ns pppmlh4hujv0001.azure.hmpp.root:6400", "-ns xxxx"),
    ("-ns pppmlh4hujv0002.azure.hmpp.root:6400", "-ns xxxx"),
    ("pppmlh4hujv0001.azure.hmpp.root", "ip-10-27-0-75.eu-west-2.compute.internal"),
    ("pppmlh4hujv0002.azure.hmpp.root", "ip-10-27-1-112.eu-west-2.compute.internal"),
    ("pppmlh4hujv0003.azure.hmpp.root", "ip-10-27-0-155.eu-west-2.compute.internal"),
    ("PPPDL2QGCPE0001", "db.preproduction.reporting.nomis.service.justice.gov.uk"),
    ("BIPAUDPP", "BIAUD_TAF"),
    ("PPBIPAUD", "PPBIAUD"),
    ("BIP_AUDIT_OWNER", "bip_audit_owner"),
    ("reporting.preprod.nomis.az.justice.gov.uk", "preproduction.reporting.nomis.service.justice.gov.uk"),
    ("PPNOMIS1", "ppncrcms1"),
    ("PPNOMIS2", "ppncrcms2"),
    ("PPNOMIS3", "ppncrapp1"),
    ("PPPMLH4HUJV0001", "ip-10-27-0-75"),
    ("PPPMLH4HUJV0002", "ip-10-27-1-112"),
    ("PPPMLH4HUJV0003", "ip-10-27-0-155"),
  ],
  "ppaws": [
    ("-ns ip-10-27-0-75.eu-west-2.compute.internal:6400", "-ns xxxx"),
    ("-ns ip-10-27-1-112.eu-west-2.compute.internal:6400", "-ns xxxx"),
  ]
}

def parse_json_file(filename, replace_list):
    cms_json = {}
    with open(filename, encoding="utf-8") as f:
        file = f.read()
        for item in replace_list:
            file = file.replace(item[0], item[1])
        cms_json = json.loads(file)
        if SHOW_PARSE:
            print(f"# parse {filename}: {len(file)} B; {len(cms_json)} key(s)")
    return cms_json

def parse_json_files(path, replace_list):
    filenames = glob.glob(path)
    if len(filenames) == 0:
        raise ValueError(f"Could not find files matching {path}")
    cmsobjects = []
    for filename in filenames:
        cmsobjects += parse_json_file(filename, replace_list)
    return cmsobjects

def parse_cmsobjects(path, replace_list):
    cmsobjects = {
        "systemobjects": parse_json_files(f"{path}*systemobjects.*.json", replace_list),
        "infoobjects": parse_json_files(f"{path}*infoobjects.*.json", replace_list),
        "appobjects": parse_json_files(f"{path}*appobjects.*.json", replace_list)
    }
    return cmsobjects

def parse_ignore_file(filename):
    ignore_list = []
    with open(filename, encoding="utf-8") as f:
        ignore_list = [line[1:] for line in f.read().splitlines() if line.startswith("#TABLE")]
    print(f"{filename}: parse ignore file {len(ignore_list)}")
    return ignore_list

def parse_ignore_files(path):
    filenames = glob.glob(path)
    ignore_list = []
    for filename in filenames:
        ignore_list += parse_ignore_file(filename)
    return set(ignore_list)

def print_header(header, ignore):
    if header in ignore:
        if SHOW_IGNORE:
            print("IGNORE: " + header)
        return False
    print(header)
    return True

def parse_java_cmdline(cmdline):
    args = cmdline.split(" ")
    current_arg_sequence = []
    split_args = []
    for arg in args[1:]:
        if arg[0] == "-":
            if current_arg_sequence:
                split_args.append(" ".join(current_arg_sequence))
            current_arg_sequence = ["", arg]
        else:
            current_arg_sequence.append(arg)
    if current_arg_sequence:
        split_args.append(" ".join(current_arg_sequence))
    return [args[0]] + sorted(split_args)

def get_si_name(cmsobjects, si_id):
    for table in cmsobjects.keys():
        for item in cmsobjects[table]:
            if isinstance(si_id, dict):
                if item["SI_ID"] == si_id["SI_ID"]:
                    return item["SI_NAME"]
            elif item["SI_ID"] == si_id:
                return item["SI_NAME"]
    return f"{si_id}:notfound"

def get_si_names(cmsobjects, item):
    si_names = []
    for i in range(item["SI_TOTAL"]):
        si_names.append(get_si_name(cmsobjects, item[str(i+1)]))
    return sorted(si_names)

def get_si_value(cmsobjects, item, si_key_item):
    if si_key_item in item:
        if si_key_item == "SI_ID":
            return get_si_name(cmsobjects, item[si_key_item])
        else:
            return item[si_key_item]
    else:
        return f"{si_key_item}:notfound"

def get_si_values(cmsobjects, item, si_key_item):
    si_values = []
    for i in range(item["SI_TOTAL"]):
        si_values.append(get_si_value(cmsobjects, item[str(i+1)], si_key_item))
    return sorted(si_values)

def print_si_diffs(x_item, y_item):
    diff = difflib.unified_diff(x_item, y_item, lineterm="", n=DIFF_CONTEXT_LINES)
    print("\n".join(list(diff)))
    if SHOW_DIFF_SOURCE:
        print("------")
        print("\n".join(x_item))

def print_diffs(x_item, y_item):
    x_json = json.dumps(x_item, sort_keys=True, indent=4)
    y_json = json.dumps(y_item, sort_keys=True, indent=4)
    diff = difflib.unified_diff(x_json.splitlines(), y_json.splitlines(), lineterm="", n=DIFF_CONTEXT_LINES)
    print("\n".join(list(diff)))
    if SHOW_DIFF_SOURCE:
        print("------")
        print(x_json)

def print_item(item):
    print(json.dumps(item, sort_keys=True, indent=4))

def compare_item(prefix, x_cmsobjects, y_cmsobjects, x_name, y_name, x_item, y_item, ignore):
    for key in x_item.keys():
        if key in COMPARE_EXCLUDE_NAME_ALL:
            if SHOW_EXCLUDE_NAME:
                print_header(f"{prefix} {key}: exclude", ignore)
        elif key not in y_item:
            if print_header(f"{prefix} {key}: in {x_name} but not {y_name}", ignore):
                if SHOW_NOT_IN_Y_ITEMS:
                    print_item(x_item[key])
                    print("======")
        elif key in SI_VALUE:
            x_si_values = get_si_values(x_cmsobjects, x_item[key], SI_VALUE[key])
            y_si_values = get_si_values(y_cmsobjects, y_item[key], SI_VALUE[key])
            if x_si_values != y_si_values:
                if print_header(f"{prefix} {key}: SI_VALUE mismatch {x_name} -> {y_name}", ignore):
                    print_si_diffs(x_si_values, y_si_values)
                    print("======")
            else:
                if SHOW_MATCHES:
                    print_header(f"{prefix} {key}: match", ignore)
        elif key in SI_KEY:
            x_si_names = get_si_names(x_cmsobjects, x_item[key])
            y_si_names = get_si_names(y_cmsobjects, y_item[key])
            if x_si_names != y_si_names:
                if print_header(f"{prefix} {key}: SI_KEY mismatch {x_name} -> {y_name}", ignore):
                    print_si_diffs(x_si_names, y_si_names)
                    print("======")
            else:
                if SHOW_MATCHES:
                    print_header(f"{prefix} {key}: match", ignore)
        elif key in COMMAND_LINE:
            x_cmdline = parse_java_cmdline(x_item[key])
            y_cmdline = parse_java_cmdline(y_item[key])
            if x_cmdline != y_cmdline:
                if print_header(f"{prefix} {key}: CMDLINE mismatch {x_name} -> {y_name}", ignore):
                    print_si_diffs(x_cmdline, y_cmdline)
                    print("======")
            else:
                if SHOW_MATCHES:
                    print_header(f"{prefix} {key}: match", ignore)
        elif x_item[key] != y_item[key]:
            if print_header(f"{prefix} {key}: mismatch {x_name} -> {y_name}", ignore):
                print_diffs(x_item[key], y_item[key])
        else:
            if SHOW_MATCHES:
                print_header(f"{prefix} {key}: match", ignore)
    for key in y_item.keys():
        if key not in x_item:
            if print_header(f"{prefix} {key}: in {x_name} but not {y_name}", ignore):
                if SHOW_NOT_IN_X_ITEMS:
                    print_item(y_item[key])
                    print("======")

def compare(prefix, x_cmsobjects, y_cmsobjects, x_name, y_name, table, kind, ignore):
    x = x_cmsobjects[table]
    y = y_cmsobjects[table]
    x_names = { item["SI_NAME"] for item in x if item["SI_KIND"] == kind }
    y_names = { item["SI_NAME"] for item in y if item["SI_KIND"] == kind }
    in_x_but_not_y = x_names.difference(y_names)
    in_y_but_not_x = y_names.difference(x_names)
    for name in sorted(in_x_but_not_y):
        print_header(f"{prefix} SI_NAME='{name}': in {x_name} but not {y_name}", ignore)
    for name in sorted(in_y_but_not_x):
        print_header(f"{prefix} SI_NAME='{name}': in {y_name} but not {x_name}", ignore)
    for name in sorted(x_names):
        if name in y_names:
            x_list = [x_item for x_item in x if x_item["SI_KIND"] == kind and x_item["SI_NAME"] == name]
            y_list = [y_item for y_item in y if y_item["SI_KIND"] == kind and y_item["SI_NAME"] == name]
            if len(x_list) != 1 or len(y_list) != 1:
                print_header(f"{prefix} SI_NAME='{name}': "
                             f"expected single item, {x_name}={len(x_list)} items; {y_name}={len(y_list)} item(s)",
                             ignore)
            else:
                compare_item(f"{prefix} SI_NAME='{name}'",
                             x_cmsobjects,
                             y_cmsobjects,
                             x_name,
                             y_name,
                             x_list[0],
                             y_list[0],
                             ignore)

def compare_cmsobjects(x_cmsobjects, y_cmsobjects, x_name, y_name, ignore):
    for table in sorted(x_cmsobjects.keys()):
        kinds = { item["SI_KIND"] for item in x_cmsobjects[table] }
        for kind in sorted(kinds):
            if kind in COMPARE_EXCLUDE_KIND_ALL:
                if SHOW_EXCLUDE_KIND:
                    print_header(f"TABLE={table} SI_KIND='{kind}' exclude", ignore)
            else:
                compare(f"TABLE={table} SI_KIND='{kind}'",
                        x_cmsobjects,
                        y_cmsobjects,
                        x_name,
                        y_name,
                        table,
                        kind,
                        ignore)

if len(sys.argv) != 3:
    print(f"Usage {sys.argv[0]} <source dir> <target dir>")
    sys.exit(1)
X_NAME = sys.argv[1]
Y_NAME = sys.argv[2]
ignore_lines = parse_ignore_files(f"{X_NAME}/{Y_NAME}.*.txt")
x_objects = parse_cmsobjects(f"{X_NAME}/", REPLACE_DICT[X_NAME] if X_NAME in REPLACE_DICT else [])
y_objects = parse_cmsobjects(f"{Y_NAME}/", REPLACE_DICT[Y_NAME] if Y_NAME in REPLACE_DICT else [])
compare_cmsobjects(x_objects, y_objects, X_NAME, Y_NAME, ignore_lines)
