#!/bin/bash

. ~/.bash_profile
export ORACLE_SID=EMREP
export ORAENV_ASK=NO
export PATH=$PATH:/usr/local/bin
. oraenv

CREATE OR REPLACE PACKAGE slack_notification AS

  PROCEDURE incident_proc (incident_msg IN gc$notif_incident_msg);
  PROCEDURE event_proc (event_msg IN gc$notif_event_msg);
  gc_url            VARCHAR2(2000)  := 'https://slack.com/api/chat.postMessage';
  gc_token          VARCHAR2(1000)  := '&1';
  gc_wallet         VARCHAR2(1000)  :='file:'||sys_context('USERENV','ORACLE_HOME')||'/dbs/slack_wallet';

END slack_notification;
/

CREATE OR REPLACE PACKAGE BODY slack_notification AS

 PROCEDURE incident_proc (incident_msg IN gc$notif_incident_msg) AS 

   l_http_request   utl_http.req;
   l_http_response  utl_http.resp;
   l_message        VARCHAR2(32767);
   l_text           VARCHAR2(32767);
   l_param          VARCHAR2(32767);
   l_src_info_array gc$notif_source_info_array; 
   l_src_info       gc$notif_source_info; 
   l_categories     gc$category_string_array; 
   l_target_name    VARCHAR2(256); 
   l_target_type    VARCHAR2(256); 
   l_target_timezone VARCHAR2(256); 
   l_hostname       VARCHAR2(256); 
   l_categories_new VARCHAR2(1000); 
   l_username       VARCHAR2(256);
   l_emoji          VARCHAR2(256);
   l_mc_count       NUMBER(1);

  BEGIN
    utl_http.set_detailed_excp_support ( true );  
    utl_http.set_wallet(gc_wallet,NULL);
    
    -- Save Incident categories 
    l_categories := incident_msg.incident_payload.incident_attrs.categories;
    IF l_categories IS NOT NULL 
    THEN 
      FOR c IN 1..l_categories.COUNT 
      LOOP 
        l_categories_new := (l_categories_new|| c || ' - ' || l_categories(c)||','); 
      END LOOP; 
    END IF; 

    -- Get target info
    l_src_info_array := incident_msg.incident_payload.incident_attrs.source_info_arr; 
    IF l_src_info_array IS NOT NULL 
    THEN 
      FOR i IN 1..l_src_info_array.COUNT 
      LOOP 
        IF l_src_info_array(i).target IS NOT NULL 
        THEN 
          l_target_name := l_src_info_array(i).target.target_name; 
          l_target_type := l_src_info_array(i).target.target_type; 
          l_target_timezone := l_src_info_array(i).target.target_timezone; 
          l_hostname := l_src_info_array(i).target.host_name; 
        END IF; 
      END LOOP; 
    END IF; 

    -- What slack channel the alert is sent to depends on the targets lifecycle
    -- This is to prevent non-MissionCritical alerts being sent to the production slack channel
    -- from the production oem instance

    SELECT COUNT(cm_target_name)
    INTO   l_mc_count
    FROM sysman.cm$em_tprops_ecm_view a,
         v$database b
    WHERE a.property_name = 'orcl_gtp_lifecycle_status'
    AND   a.property_value = 'MissionCritical'
    AND   b.name = 'POEM'
    AND   cm_target_name = l_target_name;

    l_param := 'channel=#delius-aws-oracle-dev-alerts'||chr(38);
    IF l_mc_count > 0
    THEN
      l_param := 'channel=#delius-aws-oracle-prod-alerts'||chr(38);
    END IF;    

    -- Use the Incident ID as the Username as this will make it bold
    l_username:='Incident Id: '||incident_msg.incident_payload.incident_attrs.id||
                              ' ('||incident_msg.incident_payload.incident_attrs.severity||')';
    
    -- Use Emoji to highlight the type of incident
    l_emoji :=  CASE incident_msg.incident_payload.incident_attrs.severity
                WHEN 'Fatal'         THEN 'black_circle'
                WHEN 'Critical'      THEN 'red_circle'
                WHEN 'Warning'       THEN 'large_orange_circle'
                WHEN 'Advisory'      THEN 'large_blue_circle'
                WHEN 'Informational' THEN 'white_circle'
                WHEN 'Clear'         THEN 'green_circle'
                ELSE 'interrobang'
                END;

    -- Build message with incident notification attributes
    l_message:='```Creation Time: '||to_char(incident_msg.incident_payload.incident_attrs.creation_date,'DD-MON-YY HH24:MI:SS')||chr(10)||
               'Local Time: '||to_char(to_timestamp_tz(to_timestamp_tz(to_char(incident_msg.incident_payload.incident_attrs.creation_date,'DD-MON-YYYY HH24:MI:SS')||' UTC','DD-MON-YYYY HH24:MI:SS TZR')) at time zone l_target_timezone,'DD-MON-YYYY HH24:MI:SS TZR')||chr(10)||
               'Message: '||incident_msg.msg_info.message||chr(10)||
               'Target: '||l_target_name||chr(10)||
               'Target Type: '||l_target_type||chr(10)||
               'Host: '||l_hostname||chr(10)||
               'Severity: '||incident_msg.incident_payload.incident_attrs.severity||chr(10)||
               'Rule Set: '||incident_msg.msg_info.ruleset_name||chr(10)||
               'Repeat Count: '||incident_msg.msg_info.repeat_count||chr(10)||
               'Categories: '||l_categories_new||chr(10)||'```';
 
    l_param := l_param||'username='||l_username||chr(38)||'icon_emoji='||l_emoji||chr(38)||'text='||l_message;

    l_http_request  := utl_http.begin_request
                         ( url=>gc_url||'?token='||gc_token
                         , method => 'POST'
                         );
    utl_http.set_header
      ( r      =>  l_http_request
      , name   =>  'Content-Type'
      , value  =>  'application/x-www-form-urlencoded'
      );				
    utl_http.set_header 
      ( r      =>   l_http_request
      , name   =>   'Content-Length'
      , value  =>   length(l_param)
      );
    utl_http.write_text
      ( r      =>   l_http_request
      , data   =>   l_param
      );
  -- 
    l_http_response := utl_http.get_response(l_http_request);
    BEGIN
      LOOP
        UTL_HTTP.read_text(l_http_response, l_text, 32766);
        DBMS_OUTPUT.put_line (l_text);
      END LOOP;
    EXCEPTION
    WHEN utl_http.end_of_body 
    THEN
      utl_http.end_response(l_http_response);
    END;

  EXCEPTION
  WHEN OTHERS 
  THEN
    utl_http.end_response(l_http_response);
    RAISE;
  END incident_proc;


 PROCEDURE event_proc (event_msg IN gc$notif_event_msg) AS 

   l_http_request   utl_http.req;
   l_http_response  utl_http.resp;
   l_message        VARCHAR2(32767);
   l_text           VARCHAR2(32767);
   l_param          VARCHAR2(32676);
   l_src_info_array gc$notif_source_info_array; 
   l_src_info       gc$notif_source_info; 
   l_categories     gc$category_string_array; 
   l_category_codes gc$category_string_array;
   l_attrs          gc$notif_event_attr_array;
   l_target_name    VARCHAR2(256); 
   l_target_type    VARCHAR2(256); 
   l_target_timezone VARCHAR2(256); 
   l_hostname       VARCHAR2(256); 
   l_categories_new VARCHAR2(1000); 

  BEGIN
    utl_http.set_detailed_excp_support ( true );  
    utl_http.set_wallet(gc_wallet,NULL);
    
    -- Save event categories
    l_categories := event_msg.event_payload.categories;
    IF l_categories IS NOT NULL 
    THEN 
      FOR c IN 1..l_categories.COUNT 
      LOOP 
        l_categories_new := (l_categories_new|| c || ' - ' || l_categories(c)||','); 
      END LOOP; 
    END IF; 

    -- Build message with event notification attributes
    
    l_message := 'Notification Type: '||event_msg.msg_info.notification_type||chr(10)||
                 'Repeat Count: '||event_msg.msg_info.repeat_count||chr(10)||
                 'Ruleset Name: '||event_msg.msg_info.ruleset_name||chr(10)||
                 'Rule Name: '||event_msg.msg_info.rule_name||chr(10)||
                 'Message Url: '||event_msg.msg_info.message_url||chr(10)||
                 'Event Type: ' || event_msg.event_payload.event_type||chr(10)||
                 'Event Name: ' || event_msg.event_payload.event_name||chr(10)||
                 'Event Message: ' || event_msg.event_payload.event_msg||chr(10)||
                 'Target Name: ' || event_msg.event_payload.target.target_name||chr(10)||
                 'Severity: ' || event_msg.event_payload.severity||chr(10)||
                 'Event Reported Date: ' || to_char(event_msg.event_payload.reported_date, 'DD-MON-YY HH24:MI:SS')||chr(10)||
                 'Categories: '||l_categories_new||chr(10);

    l_param := 'channel=#delius-aws-oracle-prod-alerts'||chr(38); 
    l_param := l_param||l_message;

    l_http_request  := utl_http.begin_request
                         ( url=>gc_url||'?token='||gc_token
                         , method => 'POST'
                         );
    utl_http.set_header
      ( r      =>  l_http_request
      , name   =>  'Content-Type'
      , value  =>  'application/x-www-form-urlencoded'
      );				
    utl_http.set_header 
      ( r      =>   l_http_request
      , name   =>   'Content-Length'
      , value  =>   length(l_param)
      );
    utl_http.write_text
      ( r      =>   l_http_request
      , data   =>   l_param
      );
  -- 
    l_http_response := utl_http.get_response(l_http_request);
    BEGIN
      LOOP
        UTL_HTTP.read_text(l_http_response, l_text, 32766);
        DBMS_OUTPUT.put_line (l_text);
      END LOOP;
    EXCEPTION
    WHEN utl_http.end_of_body 
    THEN
      utl_http.end_response(l_http_response);
    END;

  EXCEPTION
  WHEN OTHERS 
  THEN
    utl_http.end_response(l_http_response);
    RAISE;
  END event_proc;

END slack_notification;
/
