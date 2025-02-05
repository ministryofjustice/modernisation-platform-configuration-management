<%@ page session="false" language="java" pageEncoding="UTF-8" contentType="text/html; charset=UTF-8" %>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="X-UA-Compatible" content="IE=edge,requiresActiveX=true" charset="UTF-8" />
	<title>Prison-NOMIS Reporting - User Notification</title>
	<link rel="shortcut icon" type="image/x-icon" href="InfoView.ico" />
    <link rel="stylesheet" href="browsercheck.css?v=3">
    <script type="text/javascript" src="browsercheck.js?v=3"></script>
    <script type="text/javascript">
        window.onload = function() {
          var a = document.getElementById("biplink");

          a.onclick = function() {
	    var BIPURL = '/BOE/BI/logon/start.do?ivsLogonToken=';
            launchURL(BIPURL);
            
            return false;
          }
        }
    </script>
</head>
<body>
    <div class="BILP-launchpadbackground">
        <div class="divCenterUserInfo" style="display:inline;">
            <h2>IMPORTANT</h2>
            Please ensure to log out of MIS and ORS Reporting when you are finished.
            <br><br>To log out, click on <img style="vertical-align:middle" src="BIP_profile_icon.png" alt="User icon"> then choose "Log out" from the menu: <img style="vertical-align:middle" src="BIP_profile_menu_70pct.png" alt="Menu - Log out">
            <br><br><a id="biplink" href="#">{{ ncr_web_reporting_link_text }}</a>
        </div>
    </div>
</body>
</html>
