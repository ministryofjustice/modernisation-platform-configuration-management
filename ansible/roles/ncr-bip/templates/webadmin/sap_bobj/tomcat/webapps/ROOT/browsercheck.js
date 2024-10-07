function init() {
    var isIELessThan11 = (navigator.userAgent.indexOf("MSIE") >= 0);
    if (isIELessThan11) {
        window.location.href = '/Unsupported_Browser.html';
    }
    else {
        document.getElementById("checking").style.display = "none";
        document.getElementById("supported").style.display = "inline";
        
        var BIPURL = '/BOE/BI/logon/start.do?ivsLogonToken=';
        var URL = window.location.href;
        var qs = getParameterByName('t', URL);

        if (!qs || qs.length === 0) {
            window.location.href = '/BIlogoff.jsp';
        } else {
            //BIPURL = BIPURL + qs;
            BIPURL = BIPURL + encodeURIComponent(qs);
            window.location.href = BIPURL;
        }
    }
    
    window.focus();
}

function getParameterByName(name, url) {
    name = name.replace(/[\[\]]/g, '\\$&');
    var regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)'),
        results = regex.exec(url);
    if (!results) return null;
    if (!results[2]) return '';
    return decodeURIComponent(results[2].replace(/\+/g, ' '));
}