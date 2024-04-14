
/*
* oasys-core-combined-min.js
*
*/
//---------------------------------------------------------------------------------
//NOD-808 : Multiple tabs fix
//---------------------------------------------------------------------------------
/*
        Filename: noMulTabs.js
        Version: 1.0, Date: 24.12.2019
        Author(s): Srihari Ravva
        Purpose: To detect if apex application/page is opened in more than one tab/window, with same APEX session
                         Tested with Firefox 68.3, Google Chrome 79.0 and Microsoft Edge 44.17763.831.0
        Usage: Just call noMulTabs.detect(); on page load or document.ready
                   Optionally you can pass
                                fallbackUrl -> URL to redirect when user try to open multiple tabs or windows
                                alrtMsg -> Alter messgae to user when user try to open multiple tabs or windows
                                paraName -> Used for Cookie and Session Storage
                        e.g. noMulTabs.detect({fallbackUrl: "http://www.xyz.com/",alrtMsg: "Multiple Tabs/windows not allowed!"});
*/

/* namespace: noMulTabs */
var noMulTabs = {};
if (noMulTabs === null || typeof (noMulTabs) != "object") {
    noMulTabs = {};
}

/* namespace util under noMulTabs for generic util functions */
if (noMulTabs.util === null || typeof (noMulTabs.util) != "object") {
    noMulTabs.util = {};
}

noMulTabs.util = {
    defaults: {
// NOD-808 fallbackUrl: "https://apex.oracle.com/"
        fallbackUrl: "about:blank",
        alrtMsg: "Multiple browser tabs are not allowed in OASys, please close this tab and return to your current OASys session.",
        paraName: "apexSessionTracker"
    },
    setCookie: function (cookieName, cookieValue) {
        document.cookie = cookieName + "=" + cookieValue + ";";
    },
    getCookie: function (cookieName) {
        var name = cookieName + "=";
        var ca = document.cookie.split(';');
        for (var i = 0; i < ca.length; i++) {
            var c = ca[i];
            while (c.charAt(0) == ' ') c = c.substring(1);
            if (c.indexOf(name) == 0) return c.substring(name.length, c.length);
        }
        return "";
    }
};

noMulTabs.detect = function (pOptions) {
    var currSessionId = $("#pInstance").val();
    settings = $.extend({}, noMulTabs.util.defaults, pOptions);

    if (noMulTabs.util.getCookie(settings.paraName) == "" || noMulTabs.util.getCookie(settings.paraName) != currSessionId) {
        // Session info not stored in cookie or user opened different session
                // store current apex session id in Cookie
        noMulTabs.util.setCookie(settings.paraName, currSessionId);
        // append current session id to window name
                window.name = window.name + "_" + currSessionId;
    } else {
        // Current Session id already stored in cookie
                // check if session id exists in window name. If not exists, that means user is opening new tab/window with same APEX session, using same browser
//        if (window.name.indexOf(currSessionId) == -1) noMulTabs.redirect(settings.fallbackUrl, settings.alrtMsg); // to fix  issue
    }
};

noMulTabs.redirect = function (pURL, pMsg) {
        // hide page body, to simulate as if page is not loaded
    //$("body").hide();
        // alert message to user
    //alert(pMsg);
        // redirect to specified url
        // NOD-808
        //window.location.replace(pURL);
        var tmpWrite = '<script>document.oncontextmenu = function() { return false; };</script><br /><br /><br /><br /><br /><div style="border-radius: 25px; border: 4px solid #cc0000; padding: 20px; margin: auto; width: 50%; height: 250px;"><center><h1>OASys (Offender Assessment System)</h1><br /><h2>' + pMsg + '<h2></center></div>';
  //      document.body.innerHTML = tmpWrite; // to fix issue
  //      document.write(tmpWrite); // to fix issue
};

//---------------------------------------------------------------------------------
// detect browser
//---------------------------------------------------------------------------------
var is_msie = false
var is_trident = false
var is_opera = false;
var is_firefox = false;
var is_mozilla = false;
var is_safari = false;
var is_chrome = false;
var is_edge = false;

function detectBrowser()
{
        var browser = (function (agent) {
                switch (true) {
                    case agent.indexOf("msie") > -1: return "ie";
                    case agent.indexOf("edge") > -1: return "edge";
                    case agent.indexOf("edg") > -1: return "edge"; //"chromium based edge (dev or canary)";
                    case agent.indexOf("opr") > -1 && !!window.opr: return "opera";
                    case agent.indexOf("chrome") > -1 && !!window.chrome: return "chrome";
                    case agent.indexOf("trident") > -1: return "trident";
                    case agent.indexOf("firefox") > -1: return "firefox";
                    case agent.indexOf("safari") > -1: return "safari";
                    default: return "other";
                }
            })(window.navigator.userAgent.toLowerCase());

        switch(browser) {
                    case "edge":    is_edge    = true; break;
                    case "edg":     is_edge    = true; break;
                    case "ie":      is_msie    = true; break;
                    case "opera":   is_opera   = true; break;
                    case "firefox": is_firefox = true; break;
                    case "safari":  is_safari  = true; break;
                    case "chrome":  is_chrome  = true; break;
                    //case "trident":  is_trident  = true; break;
                    case "trident":  is_msie  = true; break;
        }
//alert(' Agent : ' + window.navigator.userAgent.toLowerCase() );
/*
alert(browser + ' isEDGE ' + is_edge + ' isIE ' + is_msie + ' navigator.userAgent : ' + navigator.userAgent + ' jQuery.browser.version : ' + jQuery.browser.version);
*/

if (is_msie) {
        is_mozilla = false;
} else {
        is_mozilla = true;
}


}


/**
 * jQuery.netchanger - rich extension to the DOM onchange event
 *
 * version 0.9.2
 *
 * http://michaelmonteleone.net/projects/netchanger
 * http://github.com/mmonteleone/jquery.netchanger
 *
 * Copyright (c) 2009 Michael Monteleone
 * Licensed under terms of the MIT License (README.markdown)
 */
(function($) {
        var valueKey = 'netchanger.initialvalue', currentJqSupportsLive = Number($.fn.jquery.split('.').slice(0, 2).join('.')) >= 1.4,
        /**
         * Extension to the jQuery.fn.val
         * Intelligently compares values based on type of input
         * @param {jQuery} elm selection of elements
         * @param {Object} val when passed, sets value as current value of input
         */

        value = function(elm, val) {
                // setting
                if ( typeof val !== "undefined") {
                        // checked inputs set their checked statuses
                        // baed on true/false of val
                        if (elm.is("input:checkbox,input:radio")) {
                                return val ? elm.attr('checked', 'checked') : elm.removeAttr('checked');
                        } else {
                                return elm.val(val);
                        }
                        // getting
                } else {
                        // checked inputs return true/false
                        // based on checked status
                        if (elm.is("input:checkbox,input:radio")) {
                                return elm.is(":checked");
                        } else {
                                return elm.val();
                        }
                }
        };

        $.fn.extend({
                /**
                 * Main plugin method.  Ativates netchanger events on matched controls in selection.
                 *
                 * @param {Object} options optional object literal options
                 */
                netchanger : function(options) {
                        var settings = $.extend({}, $.netchanger.defaults, options || {});
                        if (!currentJqSupportsLive && settings.live) {
                                throw ("Use of the live option requires jQuery 1.4 or greater");
                        }
                        // lazily bind the events to watch only after
                        // the inputs have been focused in.  saves initiation time.

                        //alert("Bind Netchanger");

                        return this[settings.live ? 'live' : 'bind'](
                        //Z Change
                        //Fix for firstitem change - use focus not focusin for jquery live - does not work
                        //                settings.live ? 'focusin' : 'focus', function(){
                        'focus', function() {
                                var elm = $(this);
                                // if(typeof elm.data(valueKey) === "undefined") {
                                if (elm.data(valueKey) === null || typeof elm.data(valueKey) === "undefined") {
                                        elm.data(valueKey, value(elm)).bind(settings.events.replace(/,/g, ' '), function() {
                                                elm.trigger(value(elm) !== elm.data(valueKey) ? 'netchange' : 'revertchange');
                                        });
                                }
                        });
                },

                /**
                 * When passed a handler, binds handler to the `revertchange` event
                 * on matched selection.  When not passed handler, changes the current
                 * value of matched controls back to their initial state and raises
                 * `revertchange` event on any that had a difference between
                 * their current and initial values.
                 *
                 * @param {Function} handler optional event handler
                 */
                revertchange : function(handler) {
                        return handler ? this.bind('revertchange', handler) : this.each(function() {
                                // if values are effectively different,
                                // sets input back to initial value and triggers change
                                // which thus triggers a revertchange
                                var element = $(this);
                                if (element.data(valueKey) !== null && typeof element.data(valueKey) !== "undefined" && element.data(valueKey) !== value(element)) {
                                        value(element, element.data(valueKey));
                                        element.change();
                                }
                        });
                },

                /**
                 * When passed a handler, binds handler to the `refreshchange`
                 * event on matched selection.  When not passed handler, promotes
                 * the current value of matched controls to be the new initial
                 * reference value and raises `refreshchange` event on any that
                 * had a difference between their current and initial values.
                 *
                 * @param {Function} handler optional event handler
                 */
                refreshchange : function(handler) {
                        return handler ? this.bind('refreshchange', handler) : this.each(function() {
                                // if values are effectively different,
                                // sets initial of input to current value
                                // and raises refreshchange event
                                var element = $(this);
                                if ( typeof element.data(valueKey) !== "undefined" && element.data(valueKey) !== value(element)) {
                                        element.data(valueKey, value(element));
                                        element.trigger('refreshchange');
                                }
                        });
                },

                /**
                 * When passed a handler, binds handler to the `netchange`
                 * event on matched selection.  When not passed handler,
                 * artificially triggers `netchange` event on matched selection.
                 *
                 * @param {Function} handler optional event handler
                 */
                netchange : function(handler) {
                        return handler ? this.bind('netchange', handler) : this.trigger('netchange');
                }
        });

        $.extend({
                /**
                 * Shortcut alias for
                 * $('input,select,textarea,fileupload').netchanger(options);
                 *
                 * @param {Object} options optional object literal of options
                 */
                netchanger : function(options) {
                        $($.netchanger.defaults.selector).netchanger(options);
                }
        });

        $.extend($.netchanger, {
                version : '0.9.1',
                defaults : {
                        // defaults to live handling when in jq 1.4
                        live : currentJqSupportsLive,
                        selector : 'input,select,textarea,fileupload',
                        events : 'blur,change,keyup,paste'
                }
        });
})(jQuery);

/* Copyright (c) 2010 Brandon Aaron (http://brandonaaron.net)
 * Licensed under the MIT License (LICENSE.txt).
 *
 * Version 2.1.2
 */

(function($) {

        $.fn.bgiframe = ($.browser.msie && /msie 6\.0/i.test(navigator.userAgent) ? function(s) {
                //$.fn.bgiframe = (true && /msie 6\.0/i.test(navigator.userAgent) ? function(s) {
                s = $.extend({
                        top : 'auto', // auto == .currentStyle.borderTopWidth
                        left : 'auto', // auto == .currentStyle.borderLeftWidth
                        width : 'auto', // auto == offsetWidth
                        height : 'auto', // auto == offsetHeight
                        opacity : true,
                        src : 'javascript:false;'
                }, s);
                var html = '<iframe class="bgiframe"frameborder="0"tabindex="-1"src="' + s.src + '"' + 'style="display:block;position:absolute;z-index:-1;' +
                //                   ' style="display:block; position:absolute; z-index:-1; filter:alpha(opacity=0); ' +
                //                              '-ms-filter:"progid:DXImageTransform.Microsoft.Alpha(Opacity=0)";"'+

                (s.opacity !== false ? 'filter:Alpha(Opacity=\'0\');' : '') + 'top:' + (s.top == 'auto' ? 'expression(((parseInt(this.parentNode.currentStyle.borderTopWidth)||0)*-1)+\'px\')' : prop(s.top)) + ';' + 'left:' + (s.left == 'auto' ? 'expression(((parseInt(this.parentNode.currentStyle.borderLeftWidth)||0)*-1)+\'px\')' : prop(s.left)) + ';' + 'width:' + (s.width == 'auto' ? 'expression(this.parentNode.offsetWidth+\'px\')' : prop(s.width)) + ';' + 'height:' + (s.height == 'auto' ? 'expression(this.parentNode.offsetHeight+\'px\')' : prop(s.height)) + ';' + '"/>';

                return this.each(function() {

                        if ($(this).children('iframe.bgiframe').length === 0)
                                this.insertBefore(document.createElement(html), this.firstChild);
                });
        } : function() {
                return this;
        });

        // old alias
        $.fn.bgIframe = $.fn.bgiframe;

        function prop(n) {
                return n && n.constructor === Number ? n + 'px' : n;
        }

})(jQuery);

/*
 TopZIndex plugin for jQuery
 Version: 1.2

 http://topzindex.googlecode.com/

 Copyright (c) 2009-2011 Todd Northrop
 http://www.speednet.biz/

 October 21, 2010

 Calculates the highest CSS z-index value in the current document
 or specified set of elements.  Provides ability to push one or more
 elements to the top of the z-index.  Useful for dynamic HTML
 popup windows/panels.

 Based on original idea by Rick Strahl
 http://west-wind.com/weblog/posts/876332.aspx

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version, subject to the following conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 ------------------------------------------------------*/

(function($) {

        $.topZIndex = function(selector) {
                /// <summary>
                ///     Returns the highest (top-most) zIndex in the document
                ///     (minimum value returned: 0).
                /// </summary>
                /// <param name="selector" type="String" optional="true">
                ///     (optional, default = "*") jQuery selector specifying
                ///     the elements to use for calculating the highest zIndex.
                /// </param>
                /// <returns type="Number">
                ///     The minimum number returned is 0 (zero).
                /// </returns>

                return
                Math.max(0, Math.max.apply(null, $.map(((selector || "*") === "*") ? $.makeArray(document.getElementsByTagName("*")) : $(selector), function(v) {
                        return parseFloat($(v).css("z-index")) || null;
                })));
        };

        $.fn.topZIndex = function(opt) {
                /// <summary>
                ///     Increments the CSS z-index of each element in the matched set
                ///     to a value larger than the highest current zIndex in the document.
                ///     (i.e., brings all elements in the matched set to the top of the
                ///     z-index order.)
                /// </summary>
                /// <param name="opt" type="Object" optional="true">
                ///     (optional) Options, with the following possible values:
                ///     increment: (Number, default = 1) increment value added to the
                ///             highest z-index number to bring an element to the top.
                ///     selector: (String, default = "*") jQuery selector specifying
                ///             the elements to use for calculating the highest zIndex.
                /// </param>
                /// <returns type="jQuery" />

                // Do nothing if matched set is empty
                if (this.length === 0) {
                        return this;
                }

                opt = $.extend({
                        increment : 1
                }, opt);

                // Get the highest current z-index value
                var zmax = $.topZIndex(opt.selector), inc = opt.increment;

                // Increment the z-index of each element in the matched set to the next highest number
                return this.each(function() {
                        this.style.zIndex = (zmax += inc);
                });
        };

})(jQuery);

//
// --------------------------------------------------------------------------------------------
//

$.fn.stickyfloat = function(options, lockBottom) {
        var $obj = this;
        var parentPaddingTop = parseInt($obj.parent().css('padding-top'));
        var startOffset = $obj.parent().offset().top;
        var opts = $.extend({
                startOffset : startOffset,
                offsetY : parentPaddingTop,
                duration : 200,
                lockBottom : true
        }, options);
        var oheight = $(this).height();
        //$obj.outerHeight(); // Math.max($(document).height(),$(window).height(),document.documentElement.clientHeight); //$obj.outerHeight();

        $obj.css({
                position : 'relative'
        });

        if (opts.lockBottom) {
                var bottomPos = $obj.parent().height() - oheight/* $obj.height() */ + parentPaddingTop;
                //get the maximum scrollTop value
                if (bottomPos < 0)
                        bottomPos = 0;
        }

        $(window).scroll(function() {

                oheight = $($obj).height();
                //$obj.outerHeight(); // Math.max($(document).height(),$(window).height(),document.documentElement.clientHeight); //$obj.outerHeight();
                if (opts.lockBottom) {
                        var bottomPos = $obj.parent().height() - oheight/* $obj.height() */ + parentPaddingTop;
                        //get the maximum scrollTop value
                        if (bottomPos < 0)
                                bottomPos = 0;
                }

                $obj.stop();
                // stop all calculations on scroll event

                var pastStartOffset = $(document).scrollTop() > opts.startOffset;
                // check if the window was scrolled down more than the start offset declared.
                var objFartherThanTopPos = $obj.offset().top > startOffset;
                // check if the object is at it's top position (starting point)
                var objBiggerThanWindow = $obj.outerHeight() < Math.max($(document).height(), $(window).height(), document.documentElement.clientHeight);
                //$(window).height();   // if the window size is smaller than the Obj size, then do not animate.

                // if window scrolled down more than startOffset OR obj position is greater than
                // the top position possible (+ offsetY) AND window size must be bigger than Obj size
                if ((pastStartOffset || objFartherThanTopPos) && objBiggerThanWindow) {
                        var newpos = ($(document).scrollTop() - startOffset + opts.offsetY );
                        if (newpos > bottomPos)
                                newpos = bottomPos;
                        if ($(document).scrollTop() < opts.startOffset)// if window scrolled < starting offset, then reset Obj position (opts.offsetY);
                                newpos = parentPaddingTop;

                        $obj.animate({
                                top : newpos
                        }, opts.duration);
                }
        });

        // public methods
        this.reposition = function() {
                // do something ...
                alert("repossesion");
        };

};

jQuery.fn.initMenu = function() {
        return this.each(function() {
                var theMenu = $(this).get(0);
                $('.acitem', this).hide();
                $('li.expand > .acitem', this).show();
                $('li.expand > .acitem', this).prev().addClass('active');

                // 6.2.0.0
                var currentoffender = $('#leftmenuheading h3').text();
                if ((currentoffender != sessionStorage.currentOffender)||(currentoffender==null)) {
           sessionStorage.currentOffender = currentoffender;
                   sessionStorage.expandedMenu = null;
                }

                //
                //open last node if set
                //
                /*
                 var currentoffender = $('#leftmenuheading h3').text();
                 try{
                 if ($('#leftmenuheading h3').text() != sessvars.leftmenustateObj.currentoffender)
                 {
                 sessvars.leftmenustateObj.currentoffender = currentoffender;
                 sessvars.leftmenustateObj.opennodeid      = "";
                 }
                 }
                 catch (err)
                 {
                 }

                 if (menuStateGetOpenNode() != "") {
                 var node = $('#'+sessvars.leftmenustateObj.opennodeid);
                 if (node)
                 {
                 $(node).prev().removeClass('expandable').addClass('active expanded' );
                 $(node).next().show('normal', function() {
                 $(this).prev().removeClass('expandable').addClass('active expanded' );
                 });
                 }
                 }
                 */
                $('li a', this).click(function() {
                        var theElement = $(this).next();
                        var parent = this.parentNode.parentNode;
                        //
                        // set open node
                        //
                        /*
                         if ($(this).hasClass('expandable') || $(this).hasClass('expanded'))
                         {
                         if ($(this).attr("id") == sessvars.leftmenustateObj.opennodeid) {
                         sessvars.leftmenustateObj.opennodeid = "";
                         }
                         else {
                         sessvars.leftmenustateObj.opennodeid = $(this).attr("id");
                         }
                         }
                         */
                        if ($(parent).hasClass('noaccordion')) {
                                if (theElement[0] === undefined) {
                                        window.location.href = this.href;
                                }
                                $(theElement).slideToggle('normal', function() {
                                        if ($(this).is(':visible')) {
                                                $(this).prev().addClass('active');
                                        } else {
                                                $(this).prev().removeClass('active');
                                        }
                                });
                                return false;
                        } else {
                                if (theElement.hasClass('acitem') && theElement.is(':visible')) {
                                        if ($(parent).hasClass('collapsible')) {
                                                $('.acitem:visible', parent).first().slideUp('normal', function() {
                                                        $(this).prev().removeClass('active');
                                                        if ($(this).prev().hasClass('expanded')) {
                                                                $(this).prev().removeClass('expanded').addClass('expandable');
                                                                // Morgan
                                                                sessionStorage.expandedMenu = null;
                                                        }
                                                });
                                        }
                                        return false;
                                }
                                if (theElement.hasClass('acitem') && !theElement.is(':visible')) {
                                        $('.acitem:visible', parent).first().slideUp('normal', function() {

                                                $(this).prev().removeClass('active');

                                                if ($(this).prev().hasClass('expanded')) {
                                                        $(this).prev().removeClass('expanded').addClass('expandable');
                                                        // Morgan
                                                        sessionStorage.expandedMenu = null;
                                                }

                                        });
                                        theElement.slideDown('normal', function() {
                                                $(this).prev().removeClass('expandable').addClass('active expanded');
                                                sessionStorage.expandedMenu = $(this).prev().attr("id");
                                        });

                                        return false;
                                }
                        }
                });
        });
};

(function($) {

        var changeFlags = {}, // Stores a listing of raised changes by their key
        suppressed = false, // whether or not warning should be suppressed
        uniqueIdentifiers = 0, // accumulator for providing page-unique ids for anonymous elements
        activated = false, // whether or not the plugin has already been activated for a given page
        idDataKey = 'safetynet-identifier', // key to use internally for storing ids on .data()
        selection, events, currentJqSupportsLive = Number($.fn.jquery.split('.').slice(0, 2).join('.')) >= 1.4;

        /**
         * Helper which returns whether an object is null
         * or in the case that it's a string or array, if it's empty
         * @param {Object} obj Object to check (could be string too)
         * @returns {Boolean} whether or not item is null or empty
         */
        var isNullOrEmpty = function(obj) {
                return obj === null || ( typeof obj.length !== "undefined" && obj.length === 0);
        };

        /**
         * Helper which returns a unique identifier for a given input
         * Yes, ieally an input should have a name,
         * but this saves the day even when they don't
         * @param {jQuery} selection selection of an input
         * @returns {string} key
         */
        var fieldIdentifierFor = function(sel) {
                sel = $(sel);

                // otherwise, if has an id, use that
                var id = sel.attr('id');
                if ( typeof id !== "undefined" && !isNullOrEmpty(id)) {
                        return id;
                }

                // if field has a name, use that
                var name = sel.attr('name');
                if ( typeof name !== "undefined" && !isNullOrEmpty(name)) {
                        return name;
                }

                // finally, if neither, just make up a new unique
                // key for it and store it for later
                var uid = sel.data(idDataKey);
                if ( typeof uid === "undefined" || uid === null) {
                        uid = uniqueIdentifiers++;
                        sel.data(idDataKey, uid);
                }
                return uid;
        };

        /**
         * Helper which returns the number of properties
         * on an object.  Used to know how many changes are
         * currently cached in the changeFlags object
         * @param {object} obj Any object
         * @returns {Number} the number of properties on the object
         */
        var countProperties = function(obj) {
                // helpful modern browsers can alreay do this.
                if ( typeof obj.__count__ !== "undefined") {
                        return obj.__count__;
                } else {
                        // and others can't.
                        var count = 0;
                        for (var k in obj) {
                                if (obj.hasOwnProperty(k)) {
                                        count++;
                                }
                        }
                        return count;
                }
        };

        /**
         * SafetyNet plugin.  Registers the matched selectors for tracking changes
         * in order to logically display a warning prompt when leaving an un-submitted form.
         * @param {Object} options optional object literal of plugin options
         */
        $.fn.safetynet = function(options) {
                var settings = $.extend({}, $.safetynet.defaults, options || {});
                var binder = settings.live ? 'live' : 'bind';

                selection = this;

                events = settings.netChangerEvents;

                if (activated) {
                        return;
                        throw ('Only one activation of jQuery.safetynet is allowed per page');
                }
                activated = true;

                // throw an exception if netchanger wasn't loadeds
                if ( typeof $.fn.netchanger === "undefined") {
                        throw ('jQuery.safetynet requires a missing dependency, jQuery.netchanger.');
                }

                // throw exception if live set but no jq 1.4 or greater
                if (!currentJqSupportsLive && settings.live) {
                        throw ("Use of the live option requires jQuery 1.4 or greater");
                }

                // set up selected inputs to raise netchanger events
                this.netchanger({
                events: events,
                live: settings.live
                })
                // register an input's change on 'netchange'
                [binder]('netchange', function(e){

                //
                // Changed to ignore items with this attribute - "ignorechangesonclose"
                //
                if ($(this).is("[data-ignorechangesonclose]") && $(this).attr("data-ignorechangesonclose") == 'true') {
                // do nothing
                } else {

                // alert('Field Changed');

                $.safetynet.raiseChange(fieldIdentifierFor(this), e.target);
                }
                })
                // clear an input's change on 'revertchange's
                [binder]('revertchange', function() {
                        $.safetynet.clearChange(fieldIdentifierFor(this));
                });

                // hook onto the onbeforeunload
                // this is a strange pseudo-event that can't be jQuery.fn.bind()'ed to
                window.onbeforeunload = function() {
                        // when suppressed, don't do anything but clear the suppression
                        // quick fix - always return undefined
                        return undefined;

                        if ($.safetynet.suppressed()) {
                                $.safetynet.suppressed(false);
                                return undefined;
                        }
                        // show the popup only if there's changes
                        // returning null from an onbeforeunload is the (strange) way of making it do nothing
                        return $.safetynet.hasChanges() ? settings.message : undefined;
                        //return undefined;
                };
                // set form submissions to suppress warnings
                $(settings.form)[binder]('submit', function() {
                        $.safetynet.suppressed(true);
                });

                return this;
        };

        /**
         * Shortcut alias for $($.safetynet.defaults.fields).safetynet(options);
         * @param {Object} options
         */
        $.safetynet = function(options) {
                $($.safetynet.defaults.fields).safetynet(options);
        };

        $.extend($.safetynet, {
                reBind : function() {
                        // set up selected inputs to raise netchanger events
                        selection.netchanger({
                                events : events
                        });
                },
                /**
                 * Manually registers a change with Safetynet, so that a warning is
                 * prompted when the user navigates away.  This can be useful for custom
                 * widgets like drag-and-drop to register their changed states.
                 * @param {String} key a key is required since changes are tracked per-control
                 *  in order to be able to cancel changes per-control. Key can be literal
                 *  string to associate change with, or a jQuery object to traverse and associate
                 *  changes with each matched element
                 * @param {Object} value optional value to assign to the key being raised
                 */
                raiseChange : function(key, value) {
                        if ( typeof key === "undefined" || isNullOrEmpty(key)) {
                                throw ("key is required when raising a jQuery.safetynet change");
                        } else if ( key instanceof $) {
                                key.each(function() {
                                        changeFlags[fieldIdentifierFor($(this))] = true;
                                });
                        } else {
                                changeFlags[key] = value || true;
                        }
                },
                /**
                 * Manually un-registers a change with Safetynet.
                 * As with automatically raised/cleared changes, if this is the last change to clear,
                 * the warning prompt will no longer be set to display on next page navigation.
                 * @param {String} key A key is required since changes are tracked per-control.
                 * Key can be literal string to associate change with, or a jQuery object to traverse and associate
                 * changes with each matched element
                 */
                clearChange : function(key) {
                        if ( typeof key === "undefined" || isNullOrEmpty(key)) {
                                throw ("key is required when clearing a jQuery.safetynet change");
                        } else if ( key instanceof $) {
                                key.each(function() {
                                        delete changeFlags[fieldIdentifierFor($(this))]
                                });
                        } else {
                                delete changeFlags[key];
                        }
                },
                /**
                 * Manually un-registers all raised changes.
                 * Warning prompt will not display on next page navigation.
                 */
                clearAllChanges : function(key) {
                        changeFlags = {};
                        activated = false;
                },
                /**
                 * Returns and/or sets the suppressed state.
                 * Allows for manually suppressing the save warning, even if there are raised changes.
                 * @param {Boolean} val optional value to set for the suppressed state
                 */
                suppressed : function(val) {
                        if (arguments.length === 1) {
                                suppressed = val;
                        }
                        return suppressed;
                },
                /**
                 * Returns whether there are currently-registered changes.
                 */
                hasChanges : function() {
                        // earlier versions of jQuery did not support 'contain'
                        if ('contains' in $) {
                                // when 'contain' does exist, use it to help verify
                                // that not only are changes raised, but if the changes
                                // are related to specific inputs, that the inputs themselves still
                                // exist
                                var applicableChanges = {};
                                $.each(changeFlags, function(key, value) {
                                        if ( typeof value === "boolean" || $.contains(document.body, value)) {
                                                applicableChanges[key] = value;
                                        }
                                });
                                return countProperties(applicableChanges) > 0;
                        } else {
                                return countProperties(changeFlags) > 0;
                        }
                },
                changedItems : function() {

                        var changedItems = "";
                        $.each(changeFlags, function(key, value) {
                                changedItems = changedItems + "," + key;
                        });
                        return changedItems;

                },
                version : '0.9.5',
                defaults : {
                        // The message to show the user when navigating away from a non-submitted form
                        message : 'Your unsaved changes will be lost.',
                        // Selector of default fields to monitor when using the `$.safetynet()` shortcut alias
                        fields : 'input,select,textarea,fileupload',
                        // Selector of forms on which to bind their `submit` event to suppress prompting
                        form : 'form',
                        // events on which to check for changes to the control
                        netChangerEvents : 'blur,change,keyup,paste',
                        // defaults to live handling when in jq 1.4
                        live : currentJqSupportsLive
                }
        });
})(jQuery);

(function($) {

        // jQuery plugin definition
        $.fn.TextAreaExpander = function(minHeight, maxHeight) {

        //      var hCheck = !($.browser.msie || $.browser.opera || $.browser.mozilla);
                var hCheck = !(is_msie || is_opera || is_mozilla);

                // resize a textarea
                function ResizeTextarea(e) {
                        // event or initialize element?
                        e = e.target || e;
                        // find content length and box width
                        var vlen = e.value.length, ewidth = e.offsetWidth;

                        if (vlen != e.valLength || ewidth != e.boxWidth) {
                                if (hCheck && (vlen < e.valLength || ewidth != e.boxWidth))
                                        e.style.height = "1px";
                                //if (jQuery.browser.mozilla) {
                                if (is_mozilla) {
                                        myversion = new Number(/Firefox[\/\s](\d+\.\d+)/.test(navigator.userAgent));
                                        // If firefox version >= 25 then....
                                        if (RegExp.$1 >= 25) {
                                                //alert("firefox version = " + RegExp.$1);
                                                e.style.overflow = "hidden";
                                                var h = Math.max(e.expandMin, Math.min(e.scrollHeight - 8, e.expandMax));
                                        } else {
                                        // IE11 issue
                                                if (RegExp.$1 > 0) {
                                                        var h = Math.max(e.expandMin, Math.min(e.scrollHeight, e.expandMax));
                                                        e.style.overflow = (e.scrollHeight > h ? "auto" : "auto");
                                                } else {

                                                    var h = Math.max(e.expandMin, Math.min(e.scrollHeight - 8, e.expandMax));
                                                        e.style.resize = 'none';
                                                        e.style.height = e.expandMax + 'px';
                                                        e.style.maxHeight = e.expandMax + 'px';
                                                        e.style.overflowY = (e.scrollHeight > h ? "auto" : "hidden");
                                                }
                                        }
                                } else {

// KB not sure why this needed to change, all seemed to work then it didn't.
                                        var h = Math.max(e.expandMin, Math.min(e.scrollHeight - 8, e.expandMax));
                                                        e.style.resize = 'none';
                                                        e.style.height = e.expandMax + 'px';
                                                        e.style.maxHeight = e.expandMax + 'px';
                                                        e.style.overflowY = (e.scrollHeight > h ? "auto" : "hidden");
/*
                                        var h = Math.max(e.expandMin, Math.min(e.scrollHeight, e.expandMax));
                                        if (e.scrollHeight >= e.expandMax) {//CL Fix for scrollbar in IE
                                                e.style.resize = 'none';
                                                e.style.height = e.expandMax + 'px';
                                                e.style.maxHeight = e.expandMax + 'px';
                                                e.style.overflowY = (e.scrollHeight > h ? "scroll" : "hidden");
                                        } else {
                                                e.style.overflow = (e.scrollHeight > h ? "auto" : "hidden");
                                        }
*/
                                }
                                // DEFECT 4498 - CL
                                //if (jQuery.browser.mozilla == true && RegExp.$1 >= 25) {
                                if (is_mozilla == true && RegExp.$1 >= 25) {
                                        if (e.style.cols == undefined)// This should be undefined until we define it hence this should only be called on the first render.
                                        {
                                                e.style.height = (h + 8) + "px";
                                                e.style.cols = 1000;
                                                // By defining cols I ensure that this is called the first time but assumes we don't use cols anywhere.
                                        } else {

                                                e.style.height = h + "px";
                                                // Kev/Paula:This was the original line with no if condition (i.e. just this line)
                                        }
                                } else {
                                        e.style.height = h + "px";
                                        // Kev/Paula:This was the original line with no if condition (i.e. just this line)
                                }// DEFECT 4498
                                e.valLength = vlen;
                                e.boxWidth = ewidth;
                        }
                        // scroll window by 1 to force floating menu back to position
                        //            window.scrollBy(0,0);
                        window.scrollBy(0, 0);
                        //
                        return true;
                };

                // initialize
                this.each(function() {

                        // is a textarea?
                        if (this.nodeName.toLowerCase() != "textarea")
                                return;

                        // set height restrictions
                        var p = this.className.match(/expand(\d+)\-*(\d+)*/i);
                        this.expandMin = 22 || ( p ? parseInt('0' + p[1], 10) : 0);
                        this.expandMax = maxHeight || ( p ? parseInt('0' + p[2], 10) : 99999);

                        // initial resize
                        ResizeTextarea(this);

                        // zero vertical padding and add events
                        if (!this.Initialized) {
                                this.Initialized = true;
                                $(this).css("padding-top", 4).css("padding-bottom", 4);
                                $(this).bind("keyup", ResizeTextarea).bind("focus", ResizeTextarea);
                        }
                });

                return this;
        };

})(jQuery);

/*
Browser detection for internet explorer
*/
function GetInternetExplorerVersion()
{
        var rv = -1;
        if (navigator.appName == "Microsoft Internet Explorer")
        {
        //alert("a");
                var ua = navigator.userAgent;
                var re = new RegExp("MSIE ([0-9]{1,}[\.0-9]{0,})");
                if (re.exec(ua) != null)
                        rv = parseFloat( RegExp.$1 );
        }
        else if (navigator.appName == "Netscape")
                {
                //alert("b");
                var ua = navigator.userAgent;
                var re = new RegExp("Trident/.*rv:([0-9]{1,}[\.0-9]{0,})");
                if (re.exec(ua) != null)
                        rv = parseFloat( RegExp.$1 );
        }

        return rv;
}

/*
        Masked Input plugin for jQuery
        Copyright (c) 2007-2013 Josh Bush (digitalbush.com)
        Licensed under the MIT license (http://digitalbush.com/projects/masked-input-plugin/#license)
        Version: 1.3.1
*/
(function($) {
        function getPasteEvent() {
    var el = document.createElement('input'),
        name = 'onpaste';
    el.setAttribute(name, '');
    return (typeof el[name] === 'function')?'paste':'input';
}

var pasteEventName = getPasteEvent() + ".mask",
        ua = navigator.userAgent,
        iPhone = /iphone/i.test(ua),
        android=/android/i.test(ua),
        caretTimeoutId;

$.mask = {
        //Predefined character definitions
        definitions: {
                '9': "[0-9]",
                'a': "[A-Za-z]",
                '*': "[A-Za-z0-9]"
        },
        dataName: "rawMaskFn",
        placeholder: '_',
};

$.fn.extend({
        //Helper Function for Caret positioning
        caret: function(begin, end) {
                var range;

                if (this.length === 0 || this.is(":hidden")) {
                        return;
                }

                if (typeof begin == 'number') {
                        end = (typeof end === 'number') ? end : begin;
                        return this.each(function() {
                                if (this.setSelectionRange) {
                                        this.setSelectionRange(begin, end);
                                } else if (this.createTextRange) {
                                        range = this.createTextRange();
                                        range.collapse(true);
                                        range.moveEnd('character', end);
                                        range.moveStart('character', begin);
                                        range.select();
                                }
                        });
                } else {
                        if (this[0].setSelectionRange) {
                                begin = this[0].selectionStart;
                                end = this[0].selectionEnd;
                        } else if (document.selection && document.selection.createRange) {
                                range = document.selection.createRange();
                                begin = 0 - range.duplicate().moveStart('character', -100000);
                                end = begin + range.text.length;
                        }
                        return { begin: begin, end: end };
                }
        },
        unmask: function() {
                return this.trigger("unmask");
        },
        mask: function(mask, settings) {
                var input,
                        defs,
                        tests,
                        partialPosition,
                        firstNonMaskPos,
                        len;

                if (!mask && this.length > 0) {
                        input = $(this[0]);
                        return input.data($.mask.dataName)();
                }
                settings = $.extend({
                        placeholder: $.mask.placeholder, // Load default placeholder
                        completed: null
                }, settings);


                defs = $.mask.definitions;
                tests = [];
                partialPosition = len = mask.length;
                firstNonMaskPos = null;

                $.each(mask.split(""), function(i, c) {
                        if (c == '?') {
                                len--;
                                partialPosition = i;
                        } else if (defs[c]) {
                                tests.push(new RegExp(defs[c]));
                                if (firstNonMaskPos === null) {
                                        firstNonMaskPos = tests.length - 1;
                                }
                        } else {
                                tests.push(null);
                        }
                });

                return this.trigger("unmask").each(function() {
                        var input = $(this),
                                buffer = $.map(
                                mask.split(""),
                                function(c, i) {
                                        if (c != '?') {
                                                return defs[c] ? settings.placeholder : c;
                                        }
                                }),
                                focusText = input.val();

                        function seekNext(pos) {
                                while (++pos < len && !tests[pos]);
                                return pos;
                        }

                        function seekPrev(pos) {
                                while (--pos >= 0 && !tests[pos]);
                                return pos;
                        }

                        function shiftL(begin,end) {
                                var i,
                                        j;

                                if (begin<0) {
                                        return;
                                }

                                for (i = begin, j = seekNext(end); i < len; i++) {
                                        if (tests[i]) {
                                                if (j < len && tests[i].test(buffer[j])) {
                                                        buffer[i] = buffer[j];
                                                        buffer[j] = settings.placeholder;
                                                } else {
                                                        break;
                                                }

                                                j = seekNext(j);
                                        }
                                }
                                writeBuffer();
                                input.caret(Math.max(firstNonMaskPos, begin));
                        }

                        function shiftR(pos) {
                                var i,
                                        c,
                                        j,
                                        t;

                                for (i = pos, c = settings.placeholder; i < len; i++) {
                                        if (tests[i]) {
                                                j = seekNext(i);
                                                t = buffer[i];
                                                buffer[i] = c;
                                                if (j < len && tests[j].test(t)) {
                                                        c = t;
                                                } else {
                                                        break;
                                                }
                                        }
                                }
                        }

                        function keydownEvent(e) {
                                var k = e.which,
                                        pos,
                                        begin,
                                        end;

                                //backspace, delete, and escape get special treatment
                                if (k === 8 || k === 46 || (iPhone && k === 127)) {
                                        pos = input.caret();
                                        begin = pos.begin;
                                        end = pos.end;

                                        if (end - begin === 0) {
                                                begin=k!==46?seekPrev(begin):(end=seekNext(begin-1));
                                                end=k===46?seekNext(end):end;
                                        }
                                        clearBuffer(begin, end);
                                        shiftL(begin, end - 1);

                                        e.preventDefault();
                                } else if (k == 27) {//escape
                                        input.val(focusText);
                                        input.caret(0, checkVal());
                                        e.preventDefault();
                                }
                        }

                        function keypressEvent(e) {
                                var k = e.which,
                                        pos = input.caret(),
                                        p,
                                        c,
                                        next;

                                if (e.ctrlKey || e.altKey || e.metaKey || k < 32) {//Ignore
                                        return;
                                } else if (k) {
                                        if (pos.end - pos.begin !== 0){
                                                clearBuffer(pos.begin, pos.end);
                                                shiftL(pos.begin, pos.end-1);
                                        }

                                        p = seekNext(pos.begin - 1);
                                        if (p < len) {
                                                c = String.fromCharCode(k);
                                                if (tests[p].test(c)) {
                                                        shiftR(p);

                                                        buffer[p] = c;
                                                        writeBuffer();
                                                        next = seekNext(p);

                                                        if(android){
                                                                setTimeout($.proxy($.fn.caret,input,next),0);
                                                        }else{
                                                                input.caret(next);
                                                        }

                                                        if (settings.completed && next >= len) {
                                                                settings.completed.call(input);
                                                        }
                                                }
                                        }
                                        e.preventDefault();
                                }
                        }

                        function clearBuffer(start, end) {
                                var i;
                                for (i = start; i < end && i < len; i++) {
                                        if (tests[i]) {
                                                buffer[i] = settings.placeholder;
                                        }
                                }
                        }

                        function writeBuffer() { input.val(buffer.join('')); }

                        function checkVal(allow) {
                                //try to place characters where they belong
                                var test = input.val(),
                                        lastMatch = -1,
                                        i,
                                        c;

                                for (i = 0, pos = 0; i < len; i++) {
                                        if (tests[i]) {
                                                buffer[i] = settings.placeholder;
                                                while (pos++ < test.length) {
                                                        c = test.charAt(pos - 1);
                                                        if (tests[i].test(c)) {
                                                                buffer[i] = c;
                                                                lastMatch = i;
                                                                break;
                                                        }
                                                }
                                                if (pos > test.length) {
                                                        break;
                                                }
                                        } else if (buffer[i] === test.charAt(pos) && i !== partialPosition) {
                                                pos++;
                                                lastMatch = i;
                                        }
                                }
                                if (allow) {
                                        writeBuffer();
                                } else if (lastMatch + 1 < partialPosition) {
                                        input.val("");
                                        clearBuffer(0, len);
                                } else {
                                        writeBuffer();
                                        input.val(input.val().substring(0, lastMatch + 1));
                                }
                                return (partialPosition ? i : firstNonMaskPos);
                        }

                        input.data($.mask.dataName,function(){
                                return $.map(buffer, function(c, i) {
                                        return tests[i]&&c!=settings.placeholder ? c : null;
                                }).join('');
                        });

                        if (!input.attr("readonly"))
                                input
                                .one("unmask", function() {
                                        input
                                                .unbind(".mask")
                                                .removeData($.mask.dataName);
                                })
                                .bind("focus.mask", function() {
                                        clearTimeout(caretTimeoutId);
                                        var pos,
                                                moveCaret;

                                        focusText = input.val();
                                        pos = checkVal();

                                        caretTimeoutId = setTimeout(function(){
                                                writeBuffer();
                                                if (pos == mask.length) {
                                                        input.caret(0, pos);
                                                } else {
                                                        input.caret(pos);
                                                }
                                        }, 10);
                                })
                                .bind("blur.mask", function() {
                                        checkVal();
                                        if (input.val() != focusText)
                                                input.change();
                                })
                                .bind("keydown.mask", keydownEvent)
                                .bind("keypress.mask", keypressEvent)
                                .bind(pasteEventName, function() {
                                        setTimeout(function() {
                                                var pos=checkVal(true);
                                                input.caret(pos);
                                                if (settings.completed && pos == input.val().length)
                                                        settings.completed.call(input);
                                        }, 0);
                                });
                        checkVal(); //Perform initial check for existing values
                });
        }
});


})(jQuery);


(function(jQuery) {
        // keep reference to the original $.fn.bind, $.fn.unbind and $.fn.find
        jQuery.fn.__bind__ = jQuery.fn.bind;
        jQuery.fn.__unbind__ = jQuery.fn.unbind;
        jQuery.fn.__find__ = jQuery.fn.find;

        var hotkeys = {
                version : '0.7.9',
                override : /keypress|keydown|keyup/g,
                triggersMap : {},

                specialKeys : {
                        27 : 'esc',
                        9 : 'tab',
                        32 : 'space',
                        13 : 'return',
                        8 : 'backspace',
                        145 : 'scroll',
                        20 : 'capslock',
                        144 : 'numlock',
                        19 : 'pause',
                        45 : 'insert',
                        36 : 'home',
                        46 : 'del',
                        35 : 'end',
                        33 : 'pageup',
                        34 : 'pagedown',
                        37 : 'left',
                        38 : 'up',
                        39 : 'right',
                        40 : 'down',
                        109 : '-',
                        112 : 'f1',
                        113 : 'f2',
                        114 : 'f3',
                        115 : 'f4',
                        116 : 'f5',
                        117 : 'f6',
                        118 : 'f7',
                        119 : 'f8',
                        120 : 'f9',
                        121 : 'f10',
                        122 : 'f11',
                        123 : 'f12',
                        191 : '/'
                },

                shiftNums : {
                        "`" : "~",
                        "1" : "!",
                        "2" : "@",
                        "3" : "#",
                        "4" : "$",
                        "5" : "%",
                        "6" : "^",
                        "7" : "&",
                        "8" : "*",
                        "9" : "(",
                        "0" : ")",
                        "-" : "_",
                        "=" : "+",
                        ";" : ":",
                        "'" : "\"",
                        "," : "<",
                        "." : ">",
                        "/" : "?",
                        "\\" : "|"
                },

                newTrigger : function(type, combi, callback) {
                        // i.e. {'keyup': {'ctrl': {cb: callback, disableInInput: false}}}
                        var result = {};
                        result[type] = {};
                        result[type][combi] = {
                                cb : callback,
                                disableInInput : false
                        };
                        return result;
                }
        };
        // add firefox num pad char codes
        //if (jQuery.browser.mozilla){
        // add num pad char codes
        hotkeys.specialKeys = jQuery.extend(hotkeys.specialKeys, {
                96 : '0',
                97 : '1',
                98 : '2',
                99 : '3',
                100 : '4',
                101 : '5',
                102 : '6',
                103 : '7',
                104 : '8',
                105 : '9',
                106 : '*',
                107 : '+',
                109 : '-',
                110 : '.',
                111 : '/'
        });
        //}

        // a wrapper around of $.fn.find
        // see more at: http://groups.google.com/group/jquery-en/browse_thread/thread/18f9825e8d22f18d
        jQuery.fn.find = function(selector) {
                this.query = selector;
                return jQuery.fn.__find__.apply(this, arguments);
        };

        jQuery.fn.unbind = function(type, combi, fn) {
                if (jQuery.isFunction(combi)) {
                        fn = combi;
                        combi = null;
                }
                if (combi && typeof combi === 'string') {
                        var selectorId = ((this.prevObject && this.prevObject.query) || (this[0].id && this[0].id) || this[0]).toString();
                        var hkTypes = type.split(' ');
                        for (var x = 0; x < hkTypes.length; x++) {
                                delete hotkeys.triggersMap[selectorId][hkTypes[x]][combi];
                        }
                }
                // call jQuery original unbind
                return this.__unbind__(type, fn);
        };

        jQuery.fn.bind = function(type, data, fn) {
                // grab keyup,keydown,keypress
                var handle = type.match(hotkeys.override);

                if (jQuery.isFunction(data) || !handle) {
                        // call jQuery.bind only
                        return this.__bind__(type, data, fn);
                } else {
                        // split the job
                        var result = null,
                        // pass the rest to the original $.fn.bind
                        pass2jq = jQuery.trim(type.replace(hotkeys.override, ''));

                        // see if there are other types, pass them to the original $.fn.bind
                        if (pass2jq) {
                                result = this.__bind__(pass2jq, data, fn);
                        }

                        if ( typeof data === "string") {
                                data = {
                                        'combi' : data
                                };
                        }
                        if (data.combi) {
                                for (var x = 0; x < handle.length; x++) {
                                        var eventType = handle[x];
                                        var combi = data.combi.toLowerCase(), trigger = hotkeys.newTrigger(eventType, combi, fn), selectorId = ((this.prevObject && this.prevObject.query) || (this[0].id && this[0].id) || this[0]).toString();

                                        //trigger[eventType][combi].propagate = data.propagate;
                                        trigger[eventType][combi].disableInInput = data.disableInInput;

                                        // first time selector is bounded
                                        if (!hotkeys.triggersMap[selectorId]) {
                                                hotkeys.triggersMap[selectorId] = trigger;
                                        }
                                        // first time selector is bounded with this type
                                        else if (!hotkeys.triggersMap[selectorId][eventType]) {
                                                hotkeys.triggersMap[selectorId][eventType] = trigger[eventType];
                                        }
                                        // make trigger point as array so more than one handler can be bound
                                        var mapPoint = hotkeys.triggersMap[selectorId][eventType][combi];
                                        if (!mapPoint) {
                                                hotkeys.triggersMap[selectorId][eventType][combi] = [trigger[eventType][combi]];
                                        } else if (mapPoint.constructor !== Array) {
                                                hotkeys.triggersMap[selectorId][eventType][combi] = [mapPoint];
                                        } else {
                                                hotkeys.triggersMap[selectorId][eventType][combi][mapPoint.length] = trigger[eventType][combi];
                                        }

                                        // add attribute and call $.event.add per matched element
                                        this.each(function() {
                                                // jQuery wrapper for the current element
                                                var jqElem = jQuery(this);

                                                // element already associated with another collection
                                                if (jqElem.attr('hkId') && jqElem.attr('hkId') !== selectorId) {
                                                        selectorId = jqElem.attr('hkId') + ";" + selectorId;
                                                }
                                                jqElem.attr('hkId', selectorId);
                                        });
                                        result = this.__bind__(handle.join(' '), data, hotkeys.handler)
                                }
                        }
                        return result;
                }
        };
        // work-around for opera and safari where (sometimes) the target is the element which was last
        // clicked with the mouse and not the document event it would make sense to get the document
        hotkeys.findElement = function(elem) {
                if (!jQuery(elem).attr('hkId')) {
                        //if (jQuery.browser.opera || jQuery.browser.safari) {
                        if (is_opera || is_safari) {
                                while (!jQuery(elem).attr('hkId') && elem.parentNode) {
                                        elem = elem.parentNode;
                                }
                        }
                }
                return elem;
        };
        // the event handler
        hotkeys.handler = function(event) {
                var target = hotkeys.findElement(event.currentTarget), jTarget = jQuery(target), ids = jTarget.attr('hkId');

                if (ids) {
                        ids = ids.split(';');
                        var code = event.which, type = event.type, special = hotkeys.specialKeys[code],
                        // prevent f5 overlapping with 't' (or f4 with 's', etc.)
                        character = !special && String.fromCharCode(code).toLowerCase(), shift = event.shiftKey, ctrl = event.ctrlKey,
                        // patch for jquery 1.2.5 && 1.2.6 see more at:
                        // http://groups.google.com/group/jquery-en/browse_thread/thread/83e10b3bb1f1c32b
                        alt = event.altKey || event.originalEvent.altKey, mapPoint = null;

                        for (var x = 0; x < ids.length; x++) {
                                if (hotkeys.triggersMap[ids[x]][type]) {
                                        mapPoint = hotkeys.triggersMap[ids[x]][type];
                                        break;
                                }
                        }

                        //find by: id.type.combi.options
                        if (mapPoint) {
                                var trigger;
                                // event type is associated with the hkId
                                if (!shift && !ctrl && !alt) {// No Modifiers
                                        trigger = mapPoint[special] || (character && mapPoint[character]);
                                } else {
                                        // check combinations (alt|ctrl|shift+anything)
                                        var modif = '';
                                        if (alt)
                                                modif += 'alt+';
                                        if (ctrl)
                                                modif += 'ctrl+';
                                        if (shift)
                                                modif += 'shift+';
                                        // modifiers + special keys or modifiers + character or modifiers + shift character or just shift character
                                        trigger = mapPoint[modif + special];
                                        if (!trigger) {
                                                if (character) {
                                                        trigger = mapPoint[modif + character] || mapPoint[modif + hotkeys.shiftNums[character]]
                                                        // '$' can be triggered as 'Shift+4' or 'Shift+$' or just '$'
                                                        || (modif === 'shift+' && mapPoint[hotkeys.shiftNums[character]]);
                                                }
                                        }
                                }
                                if (trigger) {
                                        var result = false;
                                        for (var x = 0; x < trigger.length; x++) {
                                                if (trigger[x].disableInInput) {
                                                        // double check event.currentTarget and event.target
                                                        var elem = jQuery(event.target);
                                                        if (jTarget.is("input") || jTarget.is("textarea") || jTarget.is("select") || elem.is("input") || elem.is("textarea") || elem.is("select")) {
                                                                return true;
                                                        }
                                                }
                                                // call the registered callback function
                                                result = result || trigger[x].cb.apply(this, [event]);
                                        }
                                        return result;
                                }
                        }
                }
        };
        // place it under window so it can be extended and overridden by others
        window.hotkeys = hotkeys;
        return jQuery;
})(jQuery);

;
(function($) {

        if (/1\.(0|1|2)\.(0|1|2)/.test($.fn.jquery) || /^1.1/.test($.fn.jquery)) {
                alert('blockUI requires jQuery v1.2.3 or later!  You are using v' + $.fn.jquery);
                return;
        }

        $.fn._fadeIn = $.fn.fadeIn;

        var noOp = function() {
        };

        // this bit is to ensure we don't call setExpression when we shouldn't (with extra muscle to handle
        // retarded userAgent strings on Vista)
        var mode = document.documentMode || 0;
        //var setExpr = $.browser.msie && (($.browser.version < 8 && !mode) || mode < 8);
        var setExpr = is_msie && (($.browser.version < 8 && !mode) || mode < 8);
        var ie6 = $.browser.msie && /MSIE 6.0/.test(navigator.userAgent) && !mode;
        var ie6 = is_msie && /MSIE 6.0/.test(navigator.userAgent) && !mode;

        // global $ methods for blocking/unblocking the entire page
        $.blockUI = function(opts) {
                install(window, opts);
        };
        $.unblockUI = function(opts) {
                remove(window, opts);
        };

        // convenience method for quick growl-like notifications  (http://www.google.com/search?q=growl)
        $.growlUI = function(title, message, timeout, onClose) {
                var $m = $('<div class="growlUI"></div>');
                if (title)
                        $m.append('<h1>' + title + '</h1>');
                if (message)
                        $m.append('<h2>' + message + '</h2>');
                if (timeout == undefined)
                        timeout = 3000;
                $.blockUI({
                        message : $m,
                        fadeIn : 700,
                        fadeOut : 1000,
                        centerY : false,
                        timeout : timeout,
                        showOverlay : false,
                        onUnblock : onClose,
                        css : $.blockUI.defaults.growlCSS
                });
        };

        // plugin method for blocking element content
        $.fn.block = function(opts) {
                return this.unblock({
                        fadeOut : 0
                }).each(function() {
                        if ($.css(this, 'position') == 'static')
                                this.style.position = 'relative';
                        //if ($.browser.msie)
                        if (is_msie)
                                this.style.zoom = 1;
                        // force 'hasLayout'
                        install(this, opts);
                });
        };

        // plugin method for unblocking element content
        $.fn.unblock = function(opts) {
                return this.each(function() {
                        remove(this, opts);
                });
        };

        $.blockUI.version = 2.33;
        // 2nd generation blocking at no extra cost!

        // override these in your code to change the default behavior and style
        $.blockUI.defaults = {
                // message displayed when blocking (use null for no message)
                message : '<h1>Please wait...</h1>',

                title : null, // title string; only used when theme == true
                draggable : true, // only used when theme == true (requires jquery-ui.js to be loaded)

                theme : false, // set to true to use with jQuery UI themes

                // styles for the message when blocking; if you wish to disable
                // these and use an external stylesheet then do this in your code:
                // $.blockUI.defaults.css = {};
                css : {
                        padding : 0,
                        margin : 0,
                        width : '30%',
                        top : '40%',
                        left : '35%',
                        textAlign : 'center',
                        color : '#000',
                        border : '3px solid #a5b5c5', //'3px solid #aaa',
                        backgroundColor : '#fff',
                        cursor : 'wait'
                },

                // minimal style set used when themes are used
                themedCSS : {
                        width : '30%',
                        top : '40%',
                        left : '35%'
                },

                // styles for the overlay
                overlayCSS : {
                        backgroundColor : '#000',
                        opacity : 0, // 0.6
                        cursor : 'wait'
                },

                // styles applied when using $.growlUI
                growlCSS : {
                        width : '350px',
                        top : '10px',
                        left : '',
                        right : '10px',
                        border : 'none',
                        padding : '5px',
                        opacity : 0.6,
                        cursor : 'default',
                        color : '#fff',
                        backgroundColor : '#000',
                        '-webkit-border-radius' : '10px',
                        '-moz-border-radius' : '10px',
                        'border-radius' : '10px'
                },

                // IE issues: 'about:blank' fails on HTTPS and javascript:false is s-l-o-w
                // (hat tip to Jorge H. N. de Vasconcelos)
                iframeSrc : /^https/i.test(window.location.href || '') ? 'javascript:false' : 'about:blank',

                // force usage of iframe in non-IE browsers (handy for blocking applets)
                forceIframe : false,

                // z-index for the blocking overlay
                baseZ : 1000,

                // set these to true to have the message automatically centered
                centerX : true, // <-- only effects element blocking (page block controlled via css above)
                centerY : true,

                // allow body element to be stetched in ie6; this makes blocking look better
                // on "short" pages.  disable if you wish to prevent changes to the body height
                allowBodyStretch : true,

                // enable if you want key and mouse events to be disabled for content that is blocked
                bindEvents : true,

                // be default blockUI will supress tab navigation from leaving blocking content
                // (if bindEvents is true)
                constrainTabKey : true,

                // fadeIn time in millis; set to 0 to disable fadeIn on block
                fadeIn : 200,

                // fadeOut time in millis; set to 0 to disable fadeOut on unblock
                fadeOut : 400,

                // time in millis to wait before auto-unblocking; set to 0 to disable auto-unblock
                timeout : 0,

                // disable if you don't want to show the overlay
                showOverlay : true,

                // if true, focus will be placed in the first available input field when
                // page blocking
                focusInput : true,

                // suppresses the use of overlay styles on FF/Linux (due to performance issues with opacity)
                applyPlatformOpacityRules : true,

                // callback method invoked when fadeIn has completed and blocking message is visible
                onBlock : null,

                // callback method invoked when unblocking has completed; the callback is
                // passed the element that has been unblocked (which is the window object for page
                // blocks) and the options that were passed to the unblock call:
                //   onUnblock(element, options)
                onUnblock : null,

                // don't ask; if you really must know: http://groups.google.com/group/jquery-en/browse_thread/thread/36640a8730503595/2f6a79a77a78e493#2f6a79a77a78e493
                quirksmodeOffsetHack : 4
        };

        // private data and functions follow...

        var pageBlock = null;
        var pageBlockEls = [];

        function install(el, opts) {
                var full = (el == window);
                var msg = opts && opts.message !== undefined ? opts.message : undefined;
                opts = $.extend({}, $.blockUI.defaults, opts || {});
                opts.overlayCSS = $.extend({}, $.blockUI.defaults.overlayCSS, opts.overlayCSS || {});
                var css = $.extend({}, $.blockUI.defaults.css, opts.css || {});
                var themedCSS = $.extend({}, $.blockUI.defaults.themedCSS, opts.themedCSS || {});
                msg = msg === undefined ? opts.message : msg;

                // remove the current block (if there is one)
                if (full && pageBlock)
                        remove(window, {
                                fadeOut : 0
                        });

                // if an existing element is being used as the blocking content then we capture
                // its current place in the DOM (and current display style) so we can restore
                // it when we unblock
                if (msg && typeof msg != 'string' && (msg.parentNode || msg.jquery)) {
                        var node = msg.jquery ? msg[0] : msg;
                        var data = {};
                        $(el).data('blockUI.history', data);
                        data.el = node;
                        data.parent = node.parentNode;
                        data.display = node.style.display;
                        data.position = node.style.position;
                        if (data.parent)
                                data.parent.removeChild(node);
                }

                var z = opts.baseZ;

                // blockUI uses 3 layers for blocking, for simplicity they are all used on every platform;
                // layer1 is the iframe layer which is used to supress bleed through of underlying content
                // layer2 is the overlay layer which has opacity and a wait cursor (by default)
                // layer3 is the message content that is displayed while blocking

                //var lyr1 = ($.browser.msie || opts.forceIframe) ? $('<iframe class="blockUI" style="z-index:' + (z++) + ';display:none;border:none;margin:0;padding:0;position:absolute;width:100%;height:100%;top:0;left:0" src="' + opts.iframeSrc + '"></iframe>') : $('<divclass="blockUI" style="display:none"></div>');
                var lyr1 = (is_msie || opts.forceIframe) ? $('<iframe class="blockUI" style="z-index:' + (z++) + ';display:none;border:none;margin:0;padding:0;position:absolute;width:100%;height:100%;top:0;left:0" src="' + opts.iframeSrc + '"></iframe>') : $('<div class="blockUI" style="display:none"></div>');
                var lyr2 = $('<div class="blockUI blockOverlay" style="z-index:' + (z++) + ';display:none;border:none;margin:0;padding:0;width:100%;height:100%;top:0;left:0"></div>');

                var lyr3, s;
                if (opts.theme && full) {
                        s = '<div class="blockUI blockMsg blockPage ui-dialog ui-widget ui-corner-all" style="z-index:' + z + ';display:none;position:fixed">' + '<div class="ui-widget-header ui-dialog-titlebar blockTitle">' + (opts.title || '&nbsp;') + '</div>' + '<div class="ui-widget-content ui-dialog-content"></div>' + '</div>';
                } else if (opts.theme) {
                        s = '<div class="blockUI blockMsg blockElement ui-dialog ui-widget ui-corner-all" style="z-index:' + z + ';display:none;position:absolute">' + '<div class="ui-widget-header ui-dialog-titlebar blockTitle">' + (opts.title || '&nbsp;') + '</div>' + '<div class="ui-widget-content ui-dialog-content"></div>' + '</div>';
                } else if (full) {
                        s = '<div class="blockUI blockMsg blockPage" style="z-index:' + z + ';display:none;position:fixed"></div>';
                } else {
                        s = '<div class="blockUI blockMsg blockElement" style="z-index:' + z + ';display:none;position:absolute"></div>';
                }
                lyr3 = $(s);

                // if we have a message, style it
                if (msg) {
                        if (opts.theme) {
                                lyr3.css(themedCSS);
                                lyr3.addClass('ui-widget-content');
                        } else
                                lyr3.css(css);
                }

                // style the overlay
                //if (!opts.applyPlatformOpacityRules || !($.browser.mozilla && /Linux/.test(navigator.platform)))
                if (!opts.applyPlatformOpacityRules || !(is_mozilla && /Linux/.test(navigator.platform)))
                        lyr2.css(opts.overlayCSS);
                lyr2.css('position', full ? 'fixed' : 'absolute');

                // make iframe layer transparent in IE
                //if ($.browser.msie || opts.forceIframe)
                if (is_msie || opts.forceIframe)
                        lyr1.css('opacity', 0.0);

                //$([lyr1[0],lyr2[0],lyr3[0]]).appendTo(full ? 'body' : el);
                var layers = [lyr1, lyr2, lyr3], $par = full ? $('body') : $(el);
                $.each(layers, function() {
                        this.appendTo($par);
                });

                if (opts.theme && opts.draggable && $.fn.draggable) {
                        lyr3.draggable({
                                handle : '.ui-dialog-titlebar',
                                cancel : 'li'
                        });
                }

                // ie7 must use absolute positioning in quirks mode and to account for activex issues (when scrolling)
                var expr = setExpr && (!$.boxModel || $('object,embed', full ? null : el).length > 0);
                if (ie6 || expr) {
                        // give body 100% height
                        if (full && opts.allowBodyStretch && $.boxModel)
                                $('html,body').css('height', '100%');

                        // fix ie6 issue when blocked element has a border width
                        if ((ie6 || !$.boxModel) && !full) {
                                var t = sz(el, 'borderTopWidth'), l = sz(el, 'borderLeftWidth');
                                var fixT = t ? '(0 - ' + t + ')' : 0;
                                var fixL = l ? '(0 - ' + l + ')' : 0;
                        }

                        // simulate fixed position
                        $.each([lyr1, lyr2, lyr3], function(i, o) {
                                var s = o[0].style;
                                s.position = 'absolute';
                                if (i < 2) {
                                        full ? s.setExpression('height', 'Math.max(document.body.scrollHeight, document.body.offsetHeight) - (jQuery.boxModel?0:' + opts.quirksmodeOffsetHack + ') + "px"') : s.setExpression('height', 'this.parentNode.offsetHeight + "px"');
                                        full ? s.setExpression('width', 'jQuery.boxModel && document.documentElement.clientWidth || document.body.clientWidth + "px"') : s.setExpression('width', 'this.parentNode.offsetWidth + "px"');
                                        if (fixL)
                                                s.setExpression('left', fixL);
                                        if (fixT)
                                                s.setExpression('top', fixT);
                                } else if (opts.centerY) {
                                        if (full)
                                                s.setExpression('top', '(document.documentElement.clientHeight || document.body.clientHeight) / 2 - (this.offsetHeight / 2) + (blah = document.documentElement.scrollTop ? document.documentElement.scrollTop : document.body.scrollTop) + "px"');
                                        s.marginTop = 0;
                                } else if (!opts.centerY && full) {
                                        var top = (opts.css && opts.css.top) ? parseInt(opts.css.top) : 0;
                                        var expression = '((document.documentElement.scrollTop ? document.documentElement.scrollTop : document.body.scrollTop) + ' + top + ') + "px"';
                                        s.setExpression('top', expression);
                                }
                        });
                }

                // show the message
                if (msg) {
                        if (opts.theme)
                                lyr3.find('.ui-widget-content').append(msg);
                        else
                                lyr3.append(msg);
                        if (msg.jquery || msg.nodeType)
                                $(msg).show();
                }

                //if (($.browser.msie || opts.forceIframe) && opts.showOverlay)
                if ((is_msie || opts.forceIframe) && opts.showOverlay)
                        lyr1.show();
                // opacity is zero
                if (opts.fadeIn) {
                        var cb = opts.onBlock ? opts.onBlock : noOp;
                        var cb1 = (opts.showOverlay && !msg) ? cb : noOp;
                        var cb2 = msg ? cb : noOp;
                        if (opts.showOverlay)
                                lyr2._fadeIn(opts.fadeIn, cb1);
                        if (msg)
                                lyr3._fadeIn(opts.fadeIn, cb2);
                } else {
                        if (opts.showOverlay)
                                lyr2.show();
                        if (msg)
                                lyr3.show();
                        if (opts.onBlock)
                                opts.onBlock();
                }

                // bind key and mouse events
                bind(1, el, opts);

                if (full) {
                        pageBlock = lyr3[0];
                        pageBlockEls = $(':input:enabled:visible', pageBlock);
                        if (opts.focusInput)
                                setTimeout(focus, 20);
                } else
                        center(lyr3[0], opts.centerX, opts.centerY);

                if (opts.timeout) {
                        // auto-unblock
                        var to = setTimeout(function() {
                                full ? $.unblockUI(opts) : $(el).unblock(opts);
                        }, opts.timeout);
                        $(el).data('blockUI.timeout', to);
                }
        };

        // remove the block
        function remove(el, opts) {
                var full = (el == window);
                var $el = $(el);
                var data = $el.data('blockUI.history');
                var to = $el.data('blockUI.timeout');
                if (to) {
                        clearTimeout(to);
                        $el.removeData('blockUI.timeout');
                }
                opts = $.extend({}, $.blockUI.defaults, opts || {});
                bind(0, el, opts);
                // unbind events

                var els;
                if (full)// crazy selector to handle odd field errors in ie6/7
                        els = $('body').children().filter('.blockUI').add('body > .blockUI');
                else
                        els = $('.blockUI', el);

                if (full)
                        pageBlock = pageBlockEls = null;

                if (opts.fadeOut) {
                        els.fadeOut(opts.fadeOut);
                        setTimeout(function() {
                                reset(els, data, opts, el);
                        }, opts.fadeOut);
                } else
                        reset(els, data, opts, el);
        };

        // move blocking element back into the DOM where it started
        function reset(els, data, opts, el) {
                els.each(function(i, o) {
                        // remove via DOM calls so we don't lose event handlers
                        if (this.parentNode)
                                this.parentNode.removeChild(this);
                });

                if (data && data.el) {
                        data.el.style.display = data.display;
                        data.el.style.position = data.position;
                        if (data.parent)
                                data.parent.appendChild(data.el);
                        $(el).removeData('blockUI.history');
                }

                if ( typeof opts.onUnblock == 'function')
                        opts.onUnblock(el, opts);
        };

        // bind/unbind the handler
        function bind(b, el, opts) {
                var full = el == window, $el = $(el);

                // don't bother unbinding if there is nothing to unbind
                if (!b && (full && !pageBlock || !full && !$el.data('blockUI.isBlocked')))
                        return;
                if (!full)
                        $el.data('blockUI.isBlocked', b);

                // don't bind events when overlay is not in use or if bindEvents is false
                if (!opts.bindEvents || (b && !opts.showOverlay))
                        return;

                // bind anchors and inputs for mouse and key events
                var events = 'mousedown mouseup keydown keypress';
                b ? $(document).bind(events, opts, handler) : $(document).unbind(events, handler);

                // former impl...
                //     var $e = $('a,:input');
                //     b ? $e.bind(events, opts, handler) : $e.unbind(events, handler);
        };

        // event handler to suppress keyboard/mouse events when blocking
        function handler(e) {
                // allow tab navigation (conditionally)
                if (e.keyCode && e.keyCode == 9) {
                        if (pageBlock && e.data.constrainTabKey) {
                                var els = pageBlockEls;
                                var fwd = !e.shiftKey && e.target == els[els.length - 1];
                                var back = e.shiftKey && e.target == els[0];
                                if (fwd || back) {
                                        setTimeout(function() {
                                                focus(back)
                                        }, 10);
                                        return false;
                                }
                        }
                }
                // allow events within the message content
                if ($(e.target).parents('div.blockMsg').length > 0)
                        return true;

                // allow events for content that is not being blocked
                return $(e.target).parents().children().filter('div.blockUI').length == 0;
        };

        function focus(back) {
                if (!pageBlockEls)
                        return;
                var e = pageBlockEls[back === true ? pageBlockEls.length - 1 : 0];
                if (e)
                        e.focus();
        };

        function center(el, x, y) {
                var p = el.parentNode, s = el.style;
                var l = ((p.offsetWidth - el.offsetWidth) / 2) - sz(p, 'borderLeftWidth');
                var t = ((p.offsetHeight - el.offsetHeight) / 2) - sz(p, 'borderTopWidth');
                if (x)
                        s.left = l > 0 ? (l + 'px') : '0';
                if (y)
                        s.top = t > 0 ? (t + 'px') : '0';
        };

        function sz(el, p) {
                return parseInt($.css(el, p)) || 0;
        };

})(jQuery);

/*! Idle Timer - v1.0.1 - 2014-03-21
 * https://github.com/thorst/jquery-idletimer
 * Copyright (c) 2014 Paul Irish; Licensed MIT */
/*
 mousewheel (deprecated) -> IE6.0, Chrome, Opera, Safari
 DOMMouseScroll (deprecated) -> Firefox 1.0
 wheel (standard) -> Chrome 31, Firefox 17, IE9, Firefox Mobile 17.0

 //No need to use, use DOMMouseScroll
 MozMousePixelScroll -> Firefox 3.5, Firefox Mobile 1.0

 //Events
 WheelEvent -> see wheel
 MouseWheelEvent -> see mousewheel
 MouseScrollEvent -> Firefox 3.5, Firefox Mobile 1.0
 */
(function($) {

        $.idleTimer = function(firstParam, elem) {
                var opts;
                if ( typeof firstParam === "object") {
                        opts = firstParam;
                        firstParam = null;
                } else if ( typeof firstParam === "number") {
                        opts = {
                                timeout : firstParam
                        };
                        firstParam = null;
                }

                // element to watch
                elem = elem || document;

                // defaults that are to be stored as instance props on the elem
                opts = $.extend({
                        idle : false, // indicates if the user is idle
                        timeout : 30000, // the amount of time (ms) before the user is considered idle
                        events : "mousemove keydown wheel DOMMouseScroll mousewheel mousedown touchstart touchmove MSPointerDown MSPointerMove" // define active events
                }, opts);

                var jqElem = $(elem), obj = jqElem.data("idleTimerObj") || {},

                /* (intentionally not documented)
                 * Toggles the idle state and fires an appropriate event.
                 * @return {void}
                 */
                toggleIdleState = function(e) {

                        var obj = $.data(elem, "idleTimerObj") || {};

                        // toggle the state
                        obj.idle = !obj.idle;

                        // store toggle state date time
                        obj.olddate = +new Date();

                        // create a custom event, with state and name space
                        var event = $.Event((obj.idle ? "idle" : "active") + ".idleTimer");

                        // trigger event on object with elem and copy of obj
                        $(elem).trigger(event, [elem, $.extend({}, obj), e]);
                },
                /**
                 * Handle event triggers
                 * @return {void}
                 * @method event
                 * @static
                 */
                handleEvent = function(e) {

                        var obj = $.data(elem, "idleTimerObj") || {};

                        // this is already paused, ignore events for now
                        if (obj.remaining != null) {
                                return;
                        }

                        /*
                         mousemove is kinda buggy, it can be triggered when it should be idle.
                         Typically is happening between 115 - 150 milliseconds after idle triggered.
                         @psyafter & @kaellis report "always triggered if using modal (jQuery ui, with overlay)"
                         @thorst has similar issues on ios7 "after $.scrollTop() on text area"
                         */
                        if (e.type === "mousemove") {
                                // if coord are same, it didn't move
                                if (e.pageX === obj.pageX && e.pageY === obj.pageY) {
                                        return;
                                }
                                // if coord don't exist how could it move
                                if ( typeof e.pageX === "undefined" && typeof e.pageY === "undefined") {
                                        return;
                                }
                                // under 200 ms is hard to do, and you would have to stop, as continuous activity will bypass this
                                var elapsed = (+new Date()) - obj.olddate;
                                if (elapsed < 200) {
                                        return;
                                }
                        }

                        // clear any existing timeout
                        clearTimeout(obj.tId);

                        // if the idle timer is enabled, flip
                        if (obj.idle) {
                                toggleIdleState(e);
                        }

                        // store when user was last active
                        obj.lastActive = +new Date();

                        // update mouse coord
                        obj.pageX = e.pageX;
                        obj.pageY = e.pageY;

                        // set a new timeout
                        obj.tId = setTimeout(toggleIdleState, obj.timeout);

                },
                /**
                 * Restore initial settings and restart timer
                 * @return {void}
                 * @method reset
                 * @static
                 */
                reset = function() {

                        var obj = $.data(elem, "idleTimerObj") || {};

                        // reset settings
                        obj.idle = obj.idleBackup;
                        obj.olddate = +new Date();
                        obj.lastActive = obj.olddate;
                        obj.remaining = null;

                        // reset Timers
                        clearTimeout(obj.tId);
                        if (!obj.idle) {
                                obj.tId = setTimeout(toggleIdleState, obj.timeout);
                        }

                },
                /**
                 * Store remaining time, stop timer
                 * You can pause from an idle OR active state
                 * @return {void}
                 * @method pause
                 * @static
                 */
                pause = function() {

                        var obj = $.data(elem, "idleTimerObj") || {};

                        // this is already paused
                        if (obj.remaining != null) {
                                return;
                        }

                        // define how much is left on the timer
                        obj.remaining = obj.timeout - ((+new Date()) - obj.olddate);

                        // clear any existing timeout
                        clearTimeout(obj.tId);
                },
                /**
                 * Start timer with remaining value
                 * @return {void}
                 * @method resume
                 * @static
                 */
                resume = function() {

                        var obj = $.data(elem, "idleTimerObj") || {};

                        // this isn't paused yet
                        if (obj.remaining == null) {
                                return;
                        }

                        // start timer
                        if (!obj.idle) {
                                obj.tId = setTimeout(toggleIdleState, obj.remaining);
                        }

                        // clear remaining
                        obj.remaining = null;
                },
                /**
                 * Stops the idle timer. This removes appropriate event handlers
                 * and cancels any pending timeouts.
                 * @return {void}
                 * @method destroy
                 * @static
                 */
                destroy = function() {

                        var obj = $.data(elem, "idleTimerObj") || {};

                        //clear any pending timeouts
                        clearTimeout(obj.tId);

                        //Remove data
                        jqElem.removeData("idleTimerObj");

                        //detach the event handlers
                        jqElem.off("._idleTimer");
                },
                /**
                 * Returns the time until becoming idle
                 * @return {number}
                 * @method remainingtime
                 * @static
                 */
                remainingtime = function() {

                        var obj = $.data(elem, "idleTimerObj") || {};

                        //If idle there is no time remaining
                        if (obj.idle) {
                                return 0;
                        }

                        //If its paused just return that
                        if (obj.remaining != null) {
                                return obj.remaining;
                        }

                        //Determine remaining, if negative idle didn't finish flipping, just return 0
                        var remaining = obj.timeout - ((+new Date()) - obj.lastActive);
                        if (remaining < 0) {
                                remaining = 0;
                        }

                        //If this is paused return that number, else return current remaining
                        return remaining;
                };

                // determine which function to call
                if (firstParam === null && typeof obj.idle !== "undefined") {
                        // they think they want to init, but it already is, just reset
                        reset();
                        return jqElem;
                } else if (firstParam === null) {
                        // they want to init
                } else if (firstParam !== null && typeof obj.idle === "undefined") {
                        // they want to do something, but it isnt init
                        // not sure the best way to handle this
                        return false;
                } else if (firstParam === "destroy") {
                        destroy();
                        return jqElem;
                } else if (firstParam === "pause") {
                        pause();
                        return jqElem;
                } else if (firstParam === "resume") {
                        resume();
                        return jqElem;
                } else if (firstParam === "reset") {
                        reset();
                        return jqElem;
                } else if (firstParam === "getRemainingTime") {
                        return remainingtime();
                } else if (firstParam === "getElapsedTime") {
                        return (+new Date()) - obj.olddate;
                } else if (firstParam === "getLastActiveTime") {
                        return obj.lastActive;
                } else if (firstParam === "isIdle") {
                        return obj.idle;
                }

                /* (intentionally not documented)
                 * Handles a user event indicating that the user isn't idle. namespaced with internal idleTimer
                 * @param {Event} event A DOM2-normalized event object.
                 * @return {void}
                 */
                jqElem.on($.trim((opts.events + " ").split(" ").join("._idleTimer ")), function(e) {
                        handleEvent(e);
                });

                // Internal Object Properties, This isn't all necessary, but we
                // explicitly define all keys here so we know what we are working with
                obj = $.extend({}, {
                        olddate : +new Date(), // the last time state changed
                        lastActive : +new Date(), // the last time timer was active
                        idle : opts.idle, // current state
                        idleBackup : opts.idle, // backup of idle parameter since it gets modified
                        timeout : opts.timeout, // the interval to change state
                        remaining : null, // how long until state changes
                        tId : null, // the idle timer setTimeout
                        pageX : null, // used to store the mouse coord
                        pageY : null
                });

                // set a timeout to toggle state. May wish to omit this in some situations
                if (!obj.idle) {
                        obj.tId = setTimeout(toggleIdleState, obj.timeout);
                }

                // store our instance on the object
                $.data(elem, "idleTimerObj", obj);

                return jqElem;
        };

        // This allows binding to element
        $.fn.idleTimer = function(firstParam) {
                if (this[0]) {
                        return $.idleTimer(firstParam, this[0]);
                }

                return this;
        };

})(jQuery);

(function($) {

        /**********************************************************************************

         FUNCTION
         NobleCount

         DESCRIPTION
         NobleCount method constructor

         allows for customization of maximum length and related update/length
         behaviors

         e.g. $(text_obj).NobleCount(characters_remaining_obj);

         REQUIRED: c_obj
         OPTIONAL: options

         **********************************************************************************/

        $.fn.NobleCount = function(c_obj, options) {
                var c_settings;
                var mc_passed = false;

                // if c_obj is not specified, then nothing to do here
                if ( typeof c_obj == 'string') {
                        // check for new & valid options
                        c_settings = $.extend({}, $.fn.NobleCount.settings, options);

                        // was max_chars passed via options parameter?
                        if ( typeof options != 'undefined') {
                                mc_passed = (( typeof options.max_chars == 'number') ? true : false);
                        }

                        // process all provided objects
                        return this.each(function() {
                                var $this = $(this);
                                // attach events to c_obj
                                attach_nobility($this, c_obj, c_settings, mc_passed);
                        });
                }

                return this;
        };

        /**********************************************************************************

         FUNCTION
         NobleCount.settings

         DESCRIPTION
         publically accessible data stucture containing the max_chars and
         event handling specifications for NobleCount

         can be directly accessed by '$.fn.NobleCount.settings = ... ;'

         **********************************************************************************/
        $.fn.NobleCount.settings = {

                on_negative : null, // class (STRING) or FUNCTION that is applied/called
                //      when characters remaining is negative
                on_positive : null, // class (STRING) or FUNCTION that is applied/called
                //      when characters remaining is positive
                on_update : null, // FUNCTION that is called when characters remaining
                //      changes
                max_chars : 140, // maximum number of characters
                block_negative : false, // if true, then all attempts are made to block entering
                //      more than max_characters
                cloak : false, // if true, then no visual updates of characters
                //      remaining (c_obj) occur
                in_dom : false // if true and cloak == true, then number of characters
                //      remaining are stored as the attribute
                //      'data-noblecount' of c_obj

        };

        /**********************************************************************************

         FUNCTION       $.fn.NobleCount.forceupdate

         DESCRIPTION

         **********************************************************************************/
        $.fn.NobleCountForceUpdate = function(c_obj, options) {

                var c_settings;
                var mc_passed = false;

                // if c_obj is not specified, then nothing to do here
                if ( typeof c_obj == 'string') {
                        // check for new & valid options
                        c_settings = $.extend({}, $.fn.NobleCount.settings, options);

                        // was max_chars passed via options parameter?
                        if ( typeof options != 'undefined') {
                                mc_passed = (( typeof options.max_chars == 'number') ? true : false);
                        }

                        // process all provided objects
                        return this.each(function() {
                                var $this = $(this);
                                // attach events to c_obj
                                update_nobility($this, c_obj, c_settings, mc_passed);
                        });
                }

                return this;
        };

        /*
        var max_char    = c_max_chars;
        var char_area   = $(c_obj);

        // first determine if max_char needs adjustment
        if (!mc_passed) {
        var tmp_num = char_area.text();
        var isPosNumber = (/^[1-9]\d*$/).test(tmp_num);

        if (isPosNumber) {
        max_char = tmp_num;
        }
        }

        // initialize display of characters remaining
        // * note: initializing should not trigger on_update
        event_internals(t_obj, char_area, c_settings, max_char, false);
        */
        //////////////////////////////////////////////////////////////////////////////////

        // private functions and settings

        function update_nobility(t_obj, c_obj, c_settings, mc_passed) {
                var max_char = c_settings.max_chars;
                var char_area = $(c_obj);

                // first determine if max_char needs adjustment
                if (!mc_passed) {
                        var tmp_num = char_area.text();
                        var isPosNumber = (/^[1-9]\d*$/).test(tmp_num);

                        if (isPosNumber) {
                                max_char = tmp_num;
                        }
                }

                // initialize display of characters remaining
                // * note: initializing should not trigger on_update

                event_internals(t_obj, char_area, c_settings, max_char, false);

        }

        /**********************************************************************************

         FUNCTION
         attach_nobility

         DESCRIPTION
         performs all initialization routines and display initiation

         assigns both the keyup and keydown events to the target text entry
         object; both keyup and keydown are used to provide the smoothest
         user experience

         if max_chars_passed via constructor
         max_chars = max_chars_passed
         else if number exists within counting_object (and number > 0)
         max_chars = counting_object.number
         else use default max_chars

         PRE
         t_obj and c_obj EXIST
         c_settings and mc_passed initialized

         POST
         maximum number of characters for t_obj calculated and stored in max_char
         key events attached to t_obj

         **********************************************************************************/

        function attach_nobility(t_obj, c_obj, c_settings, mc_passed) {
                var max_char = c_settings.max_chars;
                var char_area = $(c_obj);

                // first determine if max_char needs adjustment
                if (!mc_passed) {
                        var tmp_num = char_area.text();
                        var isPosNumber = (/^[1-9]\d*$/).test(tmp_num);

                        if (isPosNumber) {
                                max_char = tmp_num;
                        }
                }

                // initialize display of characters remaining
                // * note: initializing should not trigger on_update
                event_internals(t_obj, char_area, c_settings, max_char, true);

                // then attach the events -- seem to work better than keypress
                $(t_obj).keydown(function(e) {
                        event_internals(t_obj, char_area, c_settings, max_char, false);

                        // to block text entry, return false
                        if (check_block_negative(e, t_obj, c_settings, max_char) == false) {
                                return false;
                        }
                });

                $(t_obj).keyup(function(e) {
                        event_internals(t_obj, char_area, c_settings, max_char, false);

                        // to block text entry, return false
                        if (check_block_negative(e, t_obj, c_settings, max_char) == false) {
                                return false;
                        }
                });
        }

        /**********************************************************************************

         FUNCTION
         check_block_negative

         DESCRIPTION
         determines whether or not text entry within t_obj should be prevented

         PRE
         e EXISTS
         t_obj VALID
         c_settings and max_char initialized / calculated

         POST
         if t_obj text entry should be prevented FALSE is returned
         otherwise TRUE returned

         TODO
         improve selection detection and permissible behaviors experience
         ALSO
         doesnt CURRENTLY block from the pasting of large chunks of text that
         exceed max_char

         **********************************************************************************/

        function check_block_negative(e, t_obj, c_settings, max_char) {
                if (c_settings.block_negative) {
                        var char_code = e.which;
                        var selected;

                        // goofy handling required to work in both IE and FF
                        if ( typeof document.selection != 'undefined') {
                                selected = (document.selection.createRange().text.length > 0);
                        } else {
                                selected = (t_obj[0].selectionStart != t_obj[0].selectionEnd);
                        }

                        //return false if can't write more
                        if ((!((find_remaining(t_obj, max_char) < 1) && (char_code > 47 || char_code == 32 || char_code == 0 || char_code == 13) && !e.ctrlKey && !e.altKey && !selected)) == false) {

                                // block text entry
                                return false;
                        }
                }

                // allow text entry
                return true;
        }

        /**********************************************************************************

         FUNCTION
         find_remaining

         DESCRIPTION
         determines of the number of characters permitted (max_char), the number of
         characters remaining until that limit has been reached

         PRE
         t_obj and max_char EXIST and are VALID

         POST
         returns integer of the difference between max_char and total number of
         characters within the text entry object (t_obj)

         **********************************************************************************/

        function find_remaining(t_obj, max_char) {
                return max_char - t_obj.val().replace(/\n/g, "\n\r").length;
        }

        /**********************************************************************************

         FUNCTION
         event_internals

         DESCRIPTION
         primarily used for the calculation of appropriate behavior resulting from
         any event attached to the text entry object (t_obj)

         whenever the char_rem and related display and/or DOM information needs
         updating this function is called

         if cloaking is being used, then no visual representation of the characters
         remaining, nor attempt by this plugin to change any of its visual
         characteristics will occur

         if cloaking and in_dom are both TRUE, then the number of characters
         remaining are stored within the HTML 5 compliant attribute of the
         character count remaining object (c_obj) labeled 'data-noblecount'

         PRE
         c_settings, init_disp initialized

         POST
         performs all updates to the DOM visual and otherwise required
         performs all relevant function calls

         **********************************************************************************/

        function event_internals(t_obj, char_area, c_settings, max_char, init_disp) {

                var char_rem = find_remaining(t_obj, max_char);
                // is chararacters remaining positive or negative
                if (char_rem < 0) {
                        toggle_states(c_settings.on_negative, c_settings.on_positive, t_obj, char_area, c_settings, char_rem);
                } else {
                        toggle_states(c_settings.on_positive, c_settings.on_negative, t_obj, char_area, c_settings, char_rem);
                }

                // determine whether or not to update the text of the char_area (or c_obj)
                if (c_settings.cloak) {
                        // this slows stuff down quite a bit; TODO: implement better method of publically accessible data storage
                        if (c_settings.in_dom) {
                                char_area.attr('data-noblecount', char_rem);
                        }
                } else {
                        // show the numbers of characters remaining
                        char_area.text(char_rem);
                }
                // if event_internals isn't being called for initialization purposes and
                // on_update is a properly defined function then call it on this update
                if (!init_disp && jQuery.isFunction(c_settings.on_update)) {
                        c_settings.on_update(t_obj, char_area, c_settings, char_rem);
                }
        }

        /**********************************************************************************

         FUNCTION
         toggle_states

         DESCRIPTION
         performs the toggling operations between the watched positive and negative
         characteristics

         first, enables/triggers/executes the toggle_on behavior/class
         second, disables the trigger_off class

         PRE
         toggle_on, toggle_off
         IF DEFINED,
         must be a string representation of a VALID class
         OR
         must be a VALID function

         POST
         toggle_on objects have been applied/executed
         toggle_off class has been removed (if it is a class)

         **********************************************************************************/

        function toggle_states(toggle_on, toggle_off, t_obj, char_area, c_settings, char_rem) {
                if (toggle_on != null) {
                        if ( typeof toggle_on == 'string') {
                                char_area.addClass(toggle_on);
                        } else if (jQuery.isFunction(toggle_on)) {
                                toggle_on(t_obj, char_area, c_settings, char_rem);
                        }
                }

                if (toggle_off != null) {
                        if ( typeof toggle_off == 'string') {
                                char_area.removeClass(toggle_off);
                        }
                }
        }

})(jQuery);

/**
 * http://www.openjs.com/scripts/events/keyboard_shortcuts/
 * Version : 2.01.B
 * By Binny V A
 * License : BSD
 */
shortcut = {
        'all_shortcuts' : {}, //All the shortcuts are stored in this array
        'add' : function(shortcut_combination, callback, opt) {
                //Provide a set of default options
                var default_options = {
                        'type' : 'keydown',
                        'propagate' : false,
                        'disable_in_input' : false,
                        'target' : document,
                        'keycode' : false
                }
                if (!opt)
                        opt = default_options;
                else {
                        for (var dfo in default_options) {
                                if ( typeof opt[dfo] == 'undefined')
                                        opt[dfo] = default_options[dfo];
                        }
                }

                var ele = opt.target;
                if ( typeof opt.target == 'string')
                        ele = document.getElementById(opt.target);
                var ths = this;
                shortcut_combination = shortcut_combination.toLowerCase();

                //The function to be called at keypress
                var func = function(e) {
                        e = e || window.event;

                        if (opt['disable_in_input']) {//Don't enable shortcut keys in Input, Textarea fields
                                var element;
                                if (e.target)
                                        element = e.target;
                                else if (e.srcElement)
                                        element = e.srcElement;
                                if (element.nodeType == 3)
                                        element = element.parentNode;

                                if (element.tagName == 'INPUT' || element.tagName == 'TEXTAREA')
                                        return;
                        }

                        //Find Which key is pressed
                        if (e.keyCode)
                                code = e.keyCode;
                        else if (e.which)
                                code = e.which;
                        var character = String.fromCharCode(code).toLowerCase();

                        if (code == 188)
                                character = ",";
                        //If the user presses , when the type is onkeydown
                        if (code == 190)
                                character = ".";
                        //If the user presses , when the type is onkeydown

                        var keys = shortcut_combination.split("+");
                        //Key Pressed - counts the number of valid keypresses - if it is same as the number of keys, the shortcut function is invoked
                        var kp = 0;

                        //Work around for stupid Shift key bug created by using lowercase - as a result the shift+num combination was broken
                        var shift_nums = {
                                "`" : "~",
                                "1" : "!",
                                "2" : "@",
                                "3" : "#",
                                "4" : "$",
                                "5" : "%",
                                "6" : "^",
                                "7" : "&",
                                "8" : "*",
                                "9" : "(",
                                "0" : ")",
                                "-" : "_",
                                "=" : "+",
                                ";" : ":",
                                "'" : "\"",
                                "," : "<",
                                "." : ">",
                                "/" : "?",
                                "\\" : "|"
                        }
                        //Special Keys - and their codes
                        var special_keys = {
                                'esc' : 27,
                                'escape' : 27,
                                'tab' : 9,
                                'space' : 32,
                                'return' : 13,
                                'enter' : 13,
                                'backspace' : 8,

                                'scrolllock' : 145,
                                'scroll_lock' : 145,
                                'scroll' : 145,
                                'capslock' : 20,
                                'caps_lock' : 20,
                                'caps' : 20,
                                'numlock' : 144,
                                'num_lock' : 144,
                                'num' : 144,

                                'pause' : 19,
                                'break' : 19,

                                'insert' : 45,
                                'home' : 36,
                                'delete' : 46,
                                'end' : 35,

                                'pageup' : 33,
                                'page_up' : 33,
                                'pu' : 33,

                                'pagedown' : 34,
                                'page_down' : 34,
                                'pd' : 34,

                                'left' : 37,
                                'up' : 38,
                                'right' : 39,
                                'down' : 40,

                                'f1' : 112,
                                'f2' : 113,
                                'f3' : 114,
                                'f4' : 115,
                                'f5' : 116,
                                'f6' : 117,
                                'f7' : 118,
                                'f8' : 119,
                                'f9' : 120,
                                'f10' : 121,
                                'f11' : 122,
                                'f12' : 123
                        }

                        var modifiers = {
                                shift : {
                                        wanted : false,
                                        pressed : false
                                },
                                ctrl : {
                                        wanted : false,
                                        pressed : false
                                },
                                alt : {
                                        wanted : false,
                                        pressed : false
                                },
                                meta : {
                                        wanted : false,
                                        pressed : false
                                } //Meta is Mac specific
                        };

                        if (e.ctrlKey)
                                modifiers.ctrl.pressed = true;
                        if (e.shiftKey)
                                modifiers.shift.pressed = true;
                        if (e.altKey)
                                modifiers.alt.pressed = true;
                        if (e.metaKey)
                                modifiers.meta.pressed = true;

                        for (var i = 0; k = keys[i], i < keys.length; i++) {
                                //Modifiers
                                if (k == 'ctrl' || k == 'control') {
                                        kp++;
                                        modifiers.ctrl.wanted = true;

                                } else if (k == 'shift') {
                                        kp++;
                                        modifiers.shift.wanted = true;

                                } else if (k == 'alt') {
                                        kp++;
                                        modifiers.alt.wanted = true;
                                } else if (k == 'meta') {
                                        kp++;
                                        modifiers.meta.wanted = true;
                                } else if (k.length > 1) {//If it is a special key
                                        if (special_keys[k] == code)
                                                kp++;

                                } else if (opt['keycode']) {
                                        if (opt['keycode'] == code)
                                                kp++;

                                } else {//The special keys did not match
                                        if (character == k)
                                                kp++;
                                        else {
                                                if (shift_nums[character] && e.shiftKey) {//Stupid Shift key bug created by using lowercase
                                                        character = shift_nums[character];
                                                        if (character == k)
                                                                kp++;
                                                }
                                        }
                                }
                        }

                        if (kp == keys.length && modifiers.ctrl.pressed == modifiers.ctrl.wanted && modifiers.shift.pressed == modifiers.shift.wanted && modifiers.alt.pressed == modifiers.alt.wanted && modifiers.meta.pressed == modifiers.meta.wanted) {
                                callback(e);

                                if (!opt['propagate']) {//Stop the event
                                        //e.cancelBubble is supported by IE - this will kill the bubbling process.
                                        e.cancelBubble = true;
                                        e.returnValue = false;
                                        //                  e.preventDefault();

                                        //e.stopPropagation works in Firefox.
                                        if (e.stopPropagation) {
                                                e.stopPropagation();
                                                e.preventDefault();
                                        }
                                        return false;
                                }
                        }
                }
                this.all_shortcuts[shortcut_combination] = {
                        'callback' : func,
                        'target' : ele,
                        'event' : opt['type']
                };
                //Attach the function with the event
                if (ele.addEventListener)
                        ele.addEventListener(opt['type'], func, false);
                else if (ele.attachEvent)
                        ele.attachEvent('on' + opt['type'], func);
                else
                        ele['on' + opt['type']] = func;
        },

        //Remove the shortcut - just specify the shortcut and I will remove the binding
        'remove' : function(shortcut_combination) {
                shortcut_combination = shortcut_combination.toLowerCase();
                var binding = this.all_shortcuts[shortcut_combination];
                delete (this.all_shortcuts[shortcut_combination])
                if (!binding)
                        return;
                var type = binding['event'];
                var ele = binding['target'];
                var callback = binding['callback'];

                if (ele.detachEvent)
                        ele.detachEvent('on' + type, callback);
                else if (ele.removeEventListener)
                        ele.removeEventListener(type, callback, false);
                else
                        ele['on' + type] = false;
        }
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// CUSTOM FUNCTIONS AND VARIABLES
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

//---------------------------------------------------------------------------------
// Global Selector Vars
//---------------------------------------------------------------------------------
var uibanner;
var uip0readonly;
var uiinputs;
var uicheckbox;
var uiradio;
var uiselect;
var uidates;
var uipopuplov;
var uitextareaexp;
var privacy_check_data;

var uiinputs_readonly;
var uicheckbox_disabled;
var uiradio_disabled;
var uiselect_disabled;

var moduleId;

var popupItemsValuesArr;
var popupItemsExist = false;

var xi_input_template_ro = '';
var xi_ids = '';

function forcedLayoutModules(pModuleId) {
        if ((moduleId == 'DYN010') || (moduleId == 'DYN020') ||
        //  (moduleId=='ASS010')
        //  ||
        (moduleId == 'ASS020') || (moduleId == 'ASS030') || (moduleId == 'BCS010') || (moduleId == 'BCS020') || (moduleId == 'REP050')) {
                return true;
        } else {
                return false;
        }
}

//
// Shuttle Region Functions
//
function getAjax(pCollName, p1, p2, p3) {

        // Extensively altered for Defect 4632 - to make it work with APEX 5

        var numRows = document.getElementById("numrows" + pCollName).value;
        var ajaxID = document.getElementById("ajaxID" + pCollName).value;

        // Create the AJAX request and parameters, and execute it on the Page
        var ajaxRequest = new htmldb_Get(null, null, 'APPLICATION_PROCESS=AP_OD_SHUTTLE', 0);

        ajaxRequest.addParam("x01", p1);
        ajaxRequest.addParam("x02", p2);
        ajaxRequest.addParam("x03", p3);
        ajaxRequest.addParam("x08", numRows);
        ajaxRequest.addParam("x09", pCollName);

        gret = ajaxRequest.get();

        return gret;
}

function refreshLeft(pFromSeq, pCollName) {
        var filter;
        if (document.getElementById("leftFilter" + pCollName)) {
                filter = document.getElementById("leftFilter" + pCollName).value;
        }
        var gReturn = getAjax(pCollName, "REFRESHLEFT", pFromSeq, filter);
        gReturn = '<div>' + gReturn + '</div>';
        // Use the AJAX return value
        // document.getElementById("leftDiv"+pCollName).innerHTML = gReturn;

        // parse gReturn and update elements
        $('#selectLeft' + pCollName).empty();
        $(gReturn).find('option').each(function(index) {
                $('#selectLeft' + pCollName).append($(this))
        });

        $(gReturn).find('#prevPageLeft' + pCollName).each(function(index) {
                if (!$(this).attr("disabled")) {
                        $('#prevPageLeft' + pCollName).attr("disabled", false);
                } else {
                        $('#prevPageLeft' + pCollName).attr("disabled", true);
                }
        });

        $(gReturn).find('#nextPageLeft' + pCollName).each(function(index) {
                if (!$(this).attr("disabled")) {
                        $('#nextPageLeft' + pCollName).attr("disabled", false);
                } else {
                        $('#nextPageLeft' + pCollName).attr("disabled", true);
                }
        });

}

function refreshRight(pFromSeq, pCollName) {
        var filter;
        if (document.getElementById("rightFilter" + pCollName)) {
                filter = document.getElementById("rightFilter" + pCollName).value;
        }
        var gReturn = getAjax(pCollName, "REFRESHRIGHT", pFromSeq, filter);
        gReturn = '<div>' + gReturn + '</div>';

        // parse gReturn and update elements
        $('#selectRight' + pCollName).empty();
        $(gReturn).find('option').each(function(index) {
                $('#selectRight' + pCollName).append($(this))
        });

        $(gReturn).find('#prevPageRight' + pCollName).each(function(index) {
                if (!$(this).attr("disabled")) {
                        $('#prevPageRight' + pCollName).attr("disabled", false);
                } else {
                        $('#prevPageRight' + pCollName).attr("disabled", true);
                }
        });

        $(gReturn).find('#nextPageRight' + pCollName).each(function(index) {
                if (!$(this).attr("disabled")) {
                        $('#nextPageRight' + pCollName).attr("disabled", false);
                } else {
                        $('#nextPageRight' + pCollName).attr("disabled", true);
                }
        });
}

function addSelected(pCollName) {
        var selectedSeqs = '';
        var opts = document.getElementById("selectLeft" + pCollName).options;
        for ( i = 0; i < opts.length; i++) {
                if (opts[i].selected) {
                        selectedSeqs += "," + opts[i].value;
                }
        };

        var gReturn = getAjax(pCollName, "MOVE", selectedSeqs);

        // Refresh both sides
        var iMinSeq = document.getElementById("leftMinSeq" + pCollName);
        refreshLeft(iMinSeq.value, pCollName);
        iMinSeq = document.getElementById("rightMinSeq" + pCollName);
        refreshRight(iMinSeq.value, pCollName);

        // Mark a control as modified (so that Close button knows)
        $.safetynet.raiseChange($("#selectLeft" + pCollName));
}

function removeSelected(pCollName) {
        var selectedSeqs;
        var opts = document.getElementById("selectRight" + pCollName).options;
        for ( i = 0; i < opts.length; i++) {
                if (opts[i].selected)
                        selectedSeqs += "," + opts[i].value;
        };
        // Execute AJAX request
        var gReturn = getAjax(pCollName, "MOVE", selectedSeqs);

        // Refresh both sides
        var iMinSeq = document.getElementById("leftMinSeq" + pCollName);
        refreshLeft(iMinSeq.value, pCollName);
        iMinSeq = document.getElementById("rightMinSeq" + pCollName);
        refreshRight(iMinSeq.value, pCollName);

        // Mark a control as modified (so that Close button knows)
        $.safetynet.raiseChange($("#selectLeft" + pCollName));
}

function addAll(pCollName) {
        // Execute AJAX request
        var gReturn = getAjax(pCollName, "ADDALL");

        // Refresh both sides
        var iMinSeq = document.getElementById("leftMinSeq" + pCollName);
        iMinSeq.value = 0;
        refreshLeft(0, pCollName);
        iMinSeq = document.getElementById("rightMinSeq" + pCollName);
        iMinSeq.value = 0;
        refreshRight(0, pCollName);

        // Mark a control as modified (so that Close button knows)
        $.safetynet.raiseChange($("#selectLeft" + pCollName));
}

function removeAll(pCollName) {
        // Execute AJAX request
        var gReturn = getAjax(pCollName, "REMOVEALL");

        // Refresh both sides
        var iMinSeq = document.getElementById("leftMinSeq" + pCollName);
        iMinSeq.value = 0;
        refreshLeft(0, pCollName);
        iMinSeq = document.getElementById("rightMinSeq" + pCollName);
        iMinSeq.value = 0;
        refreshRight(0, pCollName);

        // Mark a control as modified (so that Close button knows)
        $.safetynet.raiseChange($("#selectLeft" + pCollName));
}

function nextLeft(pCollName) {
        var iMinSeq = document.getElementById("leftMinSeq" + pCollName);
        var numRows = document.getElementById("numrows" + pCollName).value;
        iMinSeq.value = parseInt(iMinSeq.value) + parseInt(numRows);
        refreshLeft(iMinSeq.value, pCollName);
}

function prevLeft(pCollName) {
        var iMinSeq = document.getElementById("leftMinSeq" + pCollName);
        var numRows = document.getElementById("numrows" + pCollName).value;
        iMinSeq.value = Math.max(parseInt(iMinSeq.value) - parseInt(numRows), 0);
        refreshLeft(iMinSeq.value, pCollName);
}

function nextRight(pCollName) {
        var iMinSeq = document.getElementById("rightMinSeq" + pCollName);
        var numRows = document.getElementById("numrows" + pCollName).value;
        iMinSeq.value = parseInt(iMinSeq.value) + parseInt(numRows);
        refreshRight(iMinSeq.value, pCollName);
}

function prevRight(pCollName) {
        var iMinSeq = document.getElementById("rightMinSeq" + pCollName);
        var numRows = document.getElementById("numrows" + pCollName).value;
        iMinSeq.value = Math.max(parseInt(iMinSeq.value) - parseInt(numRows), 0);
        refreshRight(iMinSeq.value, pCollName);
}

function searchLeft(pCollName) {
        var iMinSeq = document.getElementById("leftMinSeq" + pCollName);
        iMinSeq.value = 0;
        refreshLeft(0, pCollName);
}

function searchRight(pCollName) {
        var iMinSeq = document.getElementById("rightMinSeq" + pCollName);
        iMinSeq.value = 0;
        refreshRight(0, pCollName);
}

// This can be called from a dynamic action to make the shuttle read only
function setShuttleReadonly(pCollName) {
        setreadonly("#shuttle" + pCollName);
        setreadonly("#leftFilter" + pCollName);
        setreadonly("#rightFilter" + pCollName);
}

// This can be called from a dynamic action to make the shuttle NOT read only
function unsetShuttleReadonly(pCollName) {
        unsetreadonly("#shuttle" + pCollName);
        unsetreadonly("#leftFilter" + pCollName);
        unsetreadonly("#rightFilter" + pCollName);
}

// This can be called from a dynamic action to refresh the shuttle
function refreshShuttle(pCollName) {
        var iMinSeq = document.getElementById("leftMinSeq" + pCollName);
        iMinSeq.value = 0;
        refreshLeft(0, pCollName);
        iMinSeq = document.getElementById("rightMinSeq" + pCollName);
        iMinSeq.value = 0;
        refreshRight(0, pCollName);
}

//
// Shuttle Region Functions END
//

//---------------------------------------------------------------------------------
// Render disabled selects functions
//---------------------------------------------------------------------------------
var defaultROWidth = "60%";

function renderDisabledSelect(selectItemId) {

        var uiselect;
        var uiselect_disabled;

        var xi_input_template_ro = '';
        var xi_src_selected_value = '';
        var xi_src_selected_value_size;
        var xi_src_selected_value_size_max;

        var xi_src_id = '';
        var select_id = '';

        if (selectItemId) {
                uiselect = $("#" + selectItemId);
                uiselect_disabled = uiselect.filter('select').filter(':disabled').filter(':visible').not("[multiple]");
                uiselect_disabled.addClass('input_disabled');
        } else {
                uiselect = $("form select");
                uiselect_disabled = uiselect.filter(':visible').filter(':disabled').not("[multiple]");
                uiselect_disabled.addClass('input_disabled');
        }

        uiselect.attr('disabled', false);

        if (screenReaderUsed()) {
                xi_input_template_ro = '<INPUT class="input_readonly" id=":id" maxLength="4000" readonly="readonly" :srcval value=":value"/>';
        } else {
                xi_input_template_ro = '<INPUT class="input_readonly" id=":id" maxLength="4000" data-mimic_readonly="true" :srcval value=":value"/>';
        }

        xi_ids = '';

        uiselect_disabled.each(function() {

                select_id = $(this).attr("id");

                // KB Correct screen tabbing
                i_tabindex = $(this).attr("tabindex");

                if ( i_tabindex > -2 ) xi_input_template_ro = xi_input_template_ro.replace("/>", ' tabindex="' + i_tabindex + '"' + " />");

                xi_src_selected_value = '';
                xi_src_id = select_id;

                $(this).hide();

                // Module specific tweaks
                if (forcedLayoutModules(moduleId)) {

                        xi_src_selected_value_size_max = 0;
                        $(this).find('option').each(function() {
                                if ($(this).text().length > xi_src_selected_value_size_max) {
                                        xi_src_selected_value_size_max = $(this).text().length;
                                }
                        });
                        xi_src_selected_value_size = xi_src_selected_value_size_max * 2;
                        $(this).after(xi_input_template_ro.replace(':srcval', xi_src_id + '="' + xi_src_selected_value + '"').replace(':id', 'XI_' + select_id).replace(':value', $(this).find('option:selected').text()));
                        if ($(this).css('width') == 'auto') {

                                if (parseInt(xi_src_selected_value_size * 3.5) > 450) {
                                        $('#' + 'XI_' + select_id).css('width', 450);

                                } else {
                                        $('#' + 'XI_' + select_id).css('width', xi_src_selected_value_size * 3.5);
                                }
                        } else {
                                $('#' + 'XI_' + select_id).css('width', $(this).css('width'));
                        }

                } else {

                        if ($(this).find('option:selected').length > 0) {
                                xi_src_selected_value = $(this).find('option:selected').attr("value");
                                $(this).after(xi_input_template_ro.replace(':srcval', xi_src_id + '="' + xi_src_selected_value + '"').replace(':id', 'XI_' + select_id).replace(':value', $(this).find('option:selected').text()).replace(':width', ($(this).css('width').replace("px", "") > 0 ? $(this).css('width') : defaultROWidth)));
                        } else {
                                $(this).after(xi_input_template_ro.replace(':srcval', xi_src_id + '="' + xi_src_selected_value + '"').replace(':id', 'XI_' + select_id).replace(':value', "").replace(':width', ($(this).css('width').replace("px", "") > 0 ? $(this).css('width') : defaultROWidth)));
                        }

                        if ($('#' + 'XI_' + select_id).val() == 'Yes' || $('#' + 'XI_' + select_id).val() == 'No') {
                                $('#' + 'XI_' + select_id).css('width', '21px');
                        } else {
                                if (select_id == 'P1_TIER_LEVEL') {
                                        $('#' + 'XI_' + select_id).css('width', '10px');
                                } else {
                                        $('#' + 'XI_' + select_id).css('width', '85%');
                                }
                        }

                }

                //$("label[for='" + select_id + "']").attr('for', 'XI_' + select_id);
                $("label[for='" + select_id + "']").attr('for', 'XI_' + select_id);

                // added code to ensure first character is not a comma for jQuery 1.9 upgrade
                if (xi_ids == '')
                        xi_ids = '#XI_' + select_id;
                else
                        xi_ids = xi_ids + ',' + '#XI_' + select_id;

                textItemDisableKeysReadOnly("#XI_" + select_id);
        });
}

function renderDisabledSelectSingle(selectItemId) {
        renderDisabledSelect(selectItemId);
}

//---------------------------------------------------------------------------------
// checkgoodbrowser()
//---------------------------------------------------------------------------------
function checkgoodbrowser() {
        return;
        if ($.browser.msie && $.browser.version == "6.0") {
                // ok
        } else {
                alert("OASys does not support this browser.\n\n Please use Internet Explorer 6.");
                window.location = "f?p=200:101";
        }
}

//---------------------------------------------------------------------------------
// navigateCursorItem()
//---------------------------------------------------------------------------------
function navigateCursorItem() {
        if (focusItem) {
                $("#" + focusItem).focus();
        } else {
                // Else go to first item
                $("form").find("input[type=text],textarea,select").filter(":visible:enabled:first").focus();
        }
}

//---------------------------------------------------------------------------------
// navigateCursorLogoutButton()
//---------------------------------------------------------------------------------
function navigateCursorLogoutButton() {
        $("#logout").focus();
}

//---------------------------------------------------------------------------------
// attachMask
//---------------------------------------------------------------------------------
function attachMask(selector, pattern) {
        //attach format mask if not
        if (!voiceRecognitionUsed()) {
                $(selector).mask(pattern, {
                        placeholder : " "
                });
        }
}

//---------------------------------------------------------------------------------
// detachMask
//---------------------------------------------------------------------------------
function detachMask(selector) {
        if (!voiceRecognitionUsed()) {
                $(selector).unmask();
        }
}

//---------------------------------------------------------------------------------
// _unsetreadonly
//---------------------------------------------------------------------------------
function _unsetreadonly(selector) {

        // Popup Lov APEX 18.2
        if ( $(selector + '.popup_lov').size() > 0 )
        {
                $(selector + '.popup_lov').each(function() {
                        var lov_name = selector + '_lov_btn';
                        if ($(lov_name).size() > 0) $(lov_name).show();
                });

                return;

        }

        $(selector).removeAttr("readonly");
        $(selector).removeAttr("data-mimic_readonly");

        if ($(selector).filter('[id^="shuttle"]').length == 0) {
                $("#XI_" + $(selector).attr('id')).remove();
                $("#" + $(selector).attr('id')).removeClass("input_readonly");
                $("#" + $(selector).attr('id')).removeClass("input_disabled");
// Removed as this is causubg presentation issues APEX 18.2
//              $("#" + $(selector).attr('id')).addClass("input_enabled");
        }

        // KB - only remove onclick as all other are already covered within this function.
        if (screenReaderUsed()) {
                $(selector + " [type=checkbox]").removeAttr('onclick','return false;');
        }

        if ($(selector).filter('[id^="shuttle"]').length > 0) {//CARL - Defect 4519
                $(selector).find('.btnshuttle').each(function() {
                        $(this).css('display', '');
                });
        }

        textItemEnableKeysReadOnly(selector);

        $(selector + " [type=radio]," + selector + " [type=checkbox]," + selector + " [type=select-one]," + selector + " [type=button]," + selector + " [type=submit]," + selector + " [type='reset']," + "select " + selector).attr("disabled", false);

        $("textarea" + selector).removeAttr("readonly");

        // Popup Lov APEX 18.2
        $(selector + '.popup_lov').each(function() {
                var lov_name = selector + '_lov_btn';
                if ($(lov_name).size() > 0) $(lov_name).show();
        });

        //Attach date mask
        attachMask(selector + "[data-dateitemtype='date']", "99/99/9999");
}

//---------------------------------------------------------------------------------
// _setreadonly
//---------------------------------------------------------------------------------
function _setreadonly(selector) {

        //Detach date mask
        detachMask(selector + "[data-dateitemtype='date']");

        if ($(selector).filter('[id^="shuttle"]').length > 0) {//CARL - Defect 4519
                $(selector).find('.btnshuttle').each(function() {
                        $(this).css('display', 'none');
                });
        }

        //$(selector).attr("dynreadonly",true);
        if (screenReaderUsed()) {
                $(selector + "[type=text]," + selector + "[type=password]," + "textarea" + selector).attr("readonly", true);
        } else {
                $(selector + "[data-dateitemtype='date']").attr("readonly", false);
                $(selector + "[type=text]," + selector + "[type=password]").attr("data-mimic_readonly", "true");
                textItemDisableKeysReadOnly(selector + "[type=text]," + selector + "[type=password]," + "textarea" + selector);
        }

        $("textarea" + selector).attr("readonly", true);

        // ---------------------------------------------
        // Proposed New Code for defect 2249
        // ---------------------------------------------
        var myString = new String(selector);
        var myRegExp = /#/g;
        var myId = myString.replace(myRegExp, '');
        var elt = document.getElementById(myId);
        var myType = document.getElementById(myId).type;

        //alert('selector = "' + selector + '", nodename = "' + elt.nodeName + '", type = ' + myType + '"');

        // Search in myTypeList for myType
        var myTypeList = new String('select,radio,select-one,select,button,submit,reset');
        if (myTypeList.search(myType) != -1) {
                $(selector).prop("disabled", true);
        }

        if (screenReaderUsed()) {
                $(selector + " [type=checkbox]").addClass("input_disabled").attr('onclick','return false;').attr("readonly", true);
        } else{
                $(selector + " [type=checkbox]").prop("disabled", true);
        }
        // End of New Code for Defect 2249

        // The following code has been replaced for defect 2249.
        // The code that has replaced it is immediately above.

        //      $(selector + " [type=radio]," +
        //        selector + " [type=checkbox]," +
        //        selector + " [type=select-one]," +
        //       selector + " [type=button]," +
        //        selector + " [type=submit]," +
        //        selector + " [type='reset']," +
        //        "select" + selector
        //        ).prop("disabled",true);

        // Popup Lov APEX 18.2
        $(selector + '.popup_lov').each(function() {
                var lov_name = selector + '_lov_btn';
                if ($(lov_name).size() > 0) $(lov_name).hide();
        });

        //Shuttle
        apex.jQuery(selector + "_RESET img").fadeTo("slow", 0.5);
        apex.jQuery(selector + "_MOVE img").fadeTo("opacity", "0.5");
        apex.jQuery(selector + "_MOVE_ALL img").fadeTo("slow", 0.5);
        apex.jQuery(selector + "_REMOVE img").fadeTo("slow", 0.5);
        apex.jQuery(selector + "_REMOVE_ALL img").fadeTo("slow", 0.5);
        apex.jQuery(selector + "_TOP img").fadeTo("slow", 0.5);
        apex.jQuery(selector + "_UP img").fadeTo("slow", 0.5);
        apex.jQuery(selector + "_DOWN img").fadeTo("slow", 0.5);
        apex.jQuery(selector + "_BOTTOM img").fadeTo("slow", 0.5);

        apex.jQuery(selector + "_RESET").unbind("click");
        apex.jQuery(selector + "_MOVE").unbind("click");
        apex.jQuery(selector + "_MOVE_ALL").unbind("click");
        apex.jQuery(selector + "_REMOVE").unbind("click");
        apex.jQuery(selector + "_REMOVE_ALL").unbind("click");
        apex.jQuery(selector + "_TOP").unbind("click");
        apex.jQuery(selector + "_UP").unbind("click");
        apex.jQuery(selector + "_DOWN").unbind("click");
        apex.jQuery(selector + "_BOTTOM").unbind("click");

        $(selector + "_LEFT").addClass("input_readonly");
        $(selector + "_RIGHT").addClass("input_readonly");

// Kelvin Issue with input_readonly
        $(selector).addClass("input_readonly");
}

//---------------------------------------------------------------------------------
// setreadonly
//---------------------------------------------------------------------------------
function setreadonly(obj) {
        //alert('msg from _SetReadOnly');

        apex.jQuery(obj).each(function() {
                items = $(this);
                _setreadonly('#' + items.attr('id'));
                // ---------------------------------------------
                // Proposed New Code for defect 2249
                // ---------------------------------------------
                $(this).children().each(function() {
                        myChild = $(this);
                        if (!( typeof myChild.attr('type') === "undefined")) {
                                // alert('CHILD Type Defined: myChild.attr(id) = "' + myChild.attr('id') + '", "' + myChild.attr('type') + '"');
                                //$(myChild).prop('disabled',true);
                                _setreadonly('#' + myChild.attr('id'));
                        }
                })
                // End of New Code for Defect 2249
                $('#' + items.attr('id') + '_itemtoolbar').hide();
                renderDisabledSelectSingle(items.attr('id'));
        });

}

//---------------------------------------------------------------------------------
// unsetreadonly
//---------------------------------------------------------------------------------
function unsetreadonly(obj) {
        //    navigateCursorLogoutButton();
        apex.jQuery(obj).each(function() {
                items = $(this);
                _unsetreadonly('#' + items.attr('id'));
                $('#XI_' + items.attr('id')).remove
                $('#' + items.attr('id')).show();
                $('#' + items.attr('id') + '_itemtoolbar').show();
        });
        //    navigateFirstItem();
}

//---------------------------------------------------------------------------------
// setHidden
//---------------------------------------------------------------------------------
function setHidden(obj) {
        $(obj).hide();
        $(obj).each(function() {
                items = $(this);
                $("label[for='" + items.attr('id') + "']").css('visibility', 'hidden');
                $('#' + items.attr('id') + '_itemtoolbar').css('visibility', 'hidden');
                $('#' + items.attr('id') + '_itemtoolbar').hide();
        });
}

//---------------------------------------------------------------------------------
// setDisplayed
//---------------------------------------------------------------------------------
function setDisplayed(obj) {
        $(obj).each(function() {
                items = $(this);
                $('#' + items.attr('id')).show();
                if ($('#' + items.attr('id')).filter('select')) {
                        renderDisabledSelectSingle(items.attr('id'));
                } else
                        $("label[for='" + items.attr('id') + "']").show();
                $("label[for='" + items.attr('id') + "']").css('visibility', 'visible');
                $('div#' + items.attr('id') + '_itemtoolbar').show();
                $('#' + items.attr('id') + '_itemtoolbar').css('visibility', 'visible');
        });
}

//---------------------------------------------------------------------------------
// externalEditorChanges
//---------------------------------------------------------------------------------
function externalEditorChanges() {
        try {
                for (edId in tinyMCE.editors) {
                        if (tinyMCE.editors[edId].isDirty()) {
                                return true;
                        }
                }
                return false;
        } catch(err) {
                return false;
        }
}

//---------------------------------------------------------------------------------
// backspace
//---------------------------------------------------------------------------------
function backspace() {
        var currObject = document.activeElement;
        if ((currObject != null) && (currObject.tagName == 'INPUT' && currObject.type == 'text') || (currObject.tagName == 'INPUT' && currObject.type == 'password') || currObject.tagName == 'TEXTAREA') {
                return true;
        } else {
                return false;
        }
}

//---------------------------------------------------------------------------------
// Popup
//---------------------------------------------------------------------------------
function popUp(URL) {
        day = new Date();
        id = day.getTime();
        eval("page" + id + " = window.open(URL, '" + id + "', 'toolbar=0,scrollbars=1,location=0,statusbar=0,menubar=0,resizable=0,width=1024,height=768,left = 4,top = 4');");
}

// Defect 4207 Close popup windows when main window closes
function closePopUp() {
        window.close();
}

//---------------------------------------------------------------------------------
// backButtonOverride
//---------------------------------------------------------------------------------
function backButtonOverride() {
        // Work around a Safari bug
        // that sometimes produces a blank page
        setTimeout("backButtonOverrideBody()", 1);
}

//---------------------------------------------------------------------------------
// backButtonOverrideBody
//---------------------------------------------------------------------------------
function backButtonOverrideBody() {
        // Works if we backed up to get here
        try {
                history.forward();
        } catch (e) {
                // OK to ignore
        }
        // Every quarter-second, try again. The only
        // guaranteed method for Opera, Firefox,
        // and Safari, which don't always call
        // onLoad but *do* resume any timers when
        // returning to a page
        setTimeout("backButtonOverrideBody()", 500);
}


$(document).ready(function() {
        backButtonOverride();
});

//---------------------------------------------------------------------------------
// logApexError
//---------------------------------------------------------------------------------
function logApexError() {
        vError = $(".ErrorPageMessage");
        vError.hide();
        var get = new htmldb_Get(null, $v('pFlowId'), 'APPLICATION_PROCESS=AP_OD_LOGERROR', $v('pFlowStepId'));
        get.addParam('x01', vError.text());
        gReturn = get.get();
        get = null;
        return gReturn;
}

//---------------------------------------------------------------------------------
// errorPageMessage
//---------------------------------------------------------------------------------
function errorPageMessage() {
        // Message for error page
        errorMessage = null;
        errorRef = null;
        accesstag = $("div.ErrorPageMessage");
        if (accesstag.text().indexOf("Access denied by Application security check") > -1) {
                accesstag.hide();
                errorMessage = 'You have insufficient privileges to access this part of OASys';
        } else {
                errorRef = logApexError();
                errorMessage = 'An application error has occurred.&nbsp;&nbsp;Please contact support quoting reference: <br><br>#' + errorRef + '<br><br>Please Logout of OASys.';
        }
        $('#oasysError').html('<div id="messages"><div class="error"><div class="errorimage"><!-- --></div><div class="notification"><h1 class="hidden4jaws">Error Message Notification Section</h1><p>Error(s) have occurred<ul class="htmldbUlErr"><li>' + errorMessage + '</li></ul></p></div></div></div>');
}

//---------------------------------------------------------------------------------
// paginationOnClick()
//---------------------------------------------------------------------------------
function paginationOnClick() {
        $("td.pagination span.fielddata a, td.pagination a").click(function() {
                //  alert("click "+$.safetynet.hasChanges());
                var changesexist = $.safetynet.hasChanges() || externalEditorChanges();
                if (changesexist) {
                        alert("One or more filter criteria have changed. Please click the Search button to refresh.");
                        return false;
                }
        });
}

//---------------------------------------------------------------------------------
// rowHighlight
//---------------------------------------------------------------------------------
function rowHighlight() {
        $("table.reporthighlight tbody tr,table.dynrendertable tbody tr").mouseover(function() {
                var anchorExists = $(this).find("a").attr("href");
                if (anchorExists) {
                        $(this).find('td').addClass("trover");
                }
        }).mouseout(function() {
                var anchorExists = $(this).find("a").attr("href");
                if (anchorExists) {
                        $(this).find('td').removeClass("trover");
                }
        });
        // Activate row selector
        $("table.reporthighlight tbody tr,table.dynrendertable tbody tr").click(function() {
                //$(this).toggleClass("trclick")
                var href = $(this).find("a").attr("href");
                if (href) {
                        window.location = href;
                }
        });
        paginationOnClick();
};

var focusItem;

//---------------------------------------------------------------------------------
// formfocus
//---------------------------------------------------------------------------------
function formfocus() {
        $("form input:radio").addClass("radio");
        $("form input:checkbox").addClass("checkbox");

        $(':text,:password,textarea,select').mouseover(function() {
                $(this).addClass("hover");
        }).mouseout(function() {
                $(this).removeClass("hover");
        });

        $(':input').not(":button").not(":checkbox").not(":radio").not("select").focus(function() {
                $(this).addClass('focus');
                focusItem = $(this).attr('id');
        }).blur(function() {
                $(this).removeClass('focus');
        });
        $(":button").focus(function() {
                $(this).css("border", "1px solid");
                $(this).css("border-color", "#ffcc00 #ffcc00 #ffcc00 #ffcc00");
        }).blur(function() {
                $(this).css("border", "1px solid silver");
                $(this).css("border-color", "#696 #363 #363 #696");
        });

}

//---------------------------------------------------------------------------------
// floatingMenu
//---------------------------------------------------------------------------------
function floatingMenu() {
        if ($('#oasysMainMenuContainer').length)// does non AT menu html exist - if true run float javascript
        {
                $('#leftmenu').stickyfloat({
                        duration : 500
                });
        }
}

//---------------------------------------------------------------------------------
// callHelp
//---------------------------------------------------------------------------------
function callHelp() {

        // NOD-586 - get the current item that has focus
        setFocusFunctions();

        var elementIsActive = null;
        try {
                elementIsActive = focusItem;
                //document.activeElement.id;
        } catch (err) {
                elementIsActive = null;
        }

        var dynField = null;
        var currItem = null;
        var itemContext = '';

        if (elementIsActive) {
                dynField = $("#" + focusItem).attr("data-help_id");
                currItem = $("#" + focusItem).attr("id");
                currItem = currItem.replace("XI_", "");
                if (dynField) {
                        itemContext = '~' + dynField;
                } else {
                        itemContext = '~' + currItem;
                }
        } else  {
           // Defect 4543 Enable Context help for QA pages
       if ( $("[data-help_id*='QA~']").length > 0 ) { // If attribute 'data-help_id' exists on page with substring 'QA' then
         var myAttr = $("[data-help_id*='QA']").eq(0).val(); // Get the first QA question number displayed on page
         var myArr = myAttr.split("~");  // Create array 'myArr' of values delimited by "~"
         itemContext = "~" + myArr[0];   // Put the first value into 'itemContext' (e.g.QA21)
       }
    }

        focusItem = null;

        var ajaxRequest = new htmldb_Get(null, 2000, 'APPLICATION_PROCESS=AP_OD_CALLHELP', 0);

        var url;
        ajaxRequest.addParam('x01', 'H');
        //alert('HELP: '+$('#moduleid').text()+'~'+':CONTEXT'+itemContext)
        //context is MODULE~CONTEXT~FIELDNAME - need to get context fom appctx
        ajaxRequest.addParam('x02', $('#moduleid').text() + '~' + ':CONTEXT' + itemContext);
        var ajaxResult = ajaxRequest.get();
        url = ajaxResult;
        ajaxRequest = null;
        html_PopUp(url, 'Help', 800, 600);

}

//---------------------------------------------------------------------------------
// Code moved fron app_standard_events_pkg - begin
// Defect 4892 - new vars recording if a button was clicked
//---------------------------------------------------------------------------------
var focusItem;
var buttonClicked;
var pageEditing = false;

//---------------------------------------------------------------------------------
// setFocusFunctions
//---------------------------------------------------------------------------------
function setFocusFunctions() {
        var el = document.wwv_flow.elements;

        for (var i = 0; i < el.length; i++) {
                el[i].onfocus = function() {
                        if (this.type != "button") {
                                focusItem = this.id;
                                buttonClicked = null;
                                pageEditing = true;
                        };
                }
        }

        el = $(':button');
        for (var i = 0; i < el.length; i++) {
                el[i].onmouseover = function() {
                        buttonClicked = this.id;
                };
                el[i].onmouseout = function() {
                        buttonClicked = null;
                };
        }
}

//---------------------------------------------------------------------------------
// spellWindow
//---------------------------------------------------------------------------------
function spellWindow(itemId) {
        var spellItemId = focusItem;

        try {
                wasDirtyOnSpell = tinyMCE.activeEditor.isDirty();
                tinyMCE.activeEditor.save();
                tinyMCE.activeEditor.isNotDirty = wasDirtyOnSpell;
        } catch(err) {
        }

        if (itemId) {
                spellItemId = itemId;
                $("#" + spellItemId).focus();
        }

        if (spellItemId != null) {
                f = document.getElementById(spellItemId);

                // Spell checker available on enabled textarea items only
                if (f.tagName.toLowerCase() != "textarea" || f.disabled || f.readOnly) {

                        alert("Spell checker is not available on this field");
                        return;
                }

                // w = open("f?p=EORSPELL:SPELL_LANDING:"+$v('pInstance')+":::1:AI_PARENT_FIELD_NAME:"+f.id,"SpelWin" + f.name,"scrollbars=1,resizable=1,width=1024,height=500" );
                w = open("f?p=EORSPELL:SPELL_LANDING:" + $v('pInstance') + ":::1:AI_PARENT_FIELD_NAME:" + f.id, "Spellwindow", "scrollbars=1,resizable=1,width=1024,height=500");
                //            if ( w.opener == null )
                //            w.opener = self;
                //            w.focus();
        }
}

//---------------------------------------------------------------------------------
// tinyMCEInsert
//---------------------------------------------------------------------------------

// Defect 4554 - Spell check working intermittently in HTML field
// Provide a function that the Apex module SPELL can call to activate field
function tinyMCEFocus(spellItemId) {
                try {
                        tinyMCE.get(spellItemId).focus();
                } catch(err) {
                }
}


function tinyMCEInsert(html) {
        if (focusItem == currentMCEItem) {
                try {
                        var originalText = tinyMCE.activeEditor.getContent();
                        tinyMCE.activeEditor.setContent(html);
                        if(wasDirtyOnSpell || (html != originalText)){
                                tinyMCE.activeEditor.isNotDirty = false;
                                }
                } catch(err) {
                }
        }
}

//---------------------------------------------------------------------------------
// Code moved fron app_standard_events_pkg - end
//---------------------------------------------------------------------------------

//---------------------------------------------------------------------------------
// atWindow
//---------------------------------------------------------------------------------
function atWindow(itemId) {
        var atItemId = focusItem;
        var tinyEd;

        try {
                tinyMCE.activeEditor.save();
                tinyEd = true;
        } catch(err) {
                tinyEd = false;
        }

        if (itemId) {
                atItemId = itemId;
                $('#' + atItemId).focus();
        }

        if (atItemId != null) {
                // Construct URL via AJAX call
                var ajaxRequest = new htmldb_Get(null, 2000, 'APPLICATION_PROCESS=AP_OD_ATWINDOW', 0);
                var url;
                ajaxRequest.addParam('x01', atItemId);
                // Param1: Item ID
                ajaxRequest.addParam('x02', $('#moduleid').text() + '~' + atItemId);
                // Param2: moduleid~itemid
                try {
                        ajaxRequest.addParam('x03', document.getElementById('P0_AUTOTEXT_NAME').value);
                        // Param3: Autotext name override
                } catch(err) {
                }
                var ajaxResult = ajaxRequest.get();
                url = ajaxResult;
                ajaxRequest = null;
                if (url) {
                        // Insert a special character at the current caret position
                        $('#' + atItemId).focus();
                        if (tinyEd) {// TinyMCE
                                var edContent = tinyMCE.activeEditor.getContent();
                                //alert('content[' + edContent.length + ']');
                                if (edContent.length == 0) {
                                        tinyMCE.activeEditor.setContent('~');
                                } else {
                                        tinyMCE.activeEditor.selection.setContent('~');
                                }
                        } else {
                                if (document.selection) {// IE
                                        var sel = document.selection.createRange();
                                        sel.text = '~';
                                } else {// Firefox
                                        var f = document.getElementById(atItemId);
                                        if (f.selectionStart || f.selectionEnd == '0') {
                                                var startPos = f.selectionStart;
                                                var endPos = f.selectionEnd;
                                                f.value = f.value.substring(0, startPos) + '~' + f.value.substring(endPos, f.value.length);
                                        } else {
                                                f.value += '~';
                                        }
                                }
                        }
                        // Open Autotext window
                        html_PopUp(url, 'AutoText', 1024, 768);
                } else {
                        alert('No autotext available for this item');
                }
        }
        return false;
}

//---------------------------------------------------------------------------------
// lastUpdated
//---------------------------------------------------------------------------------
function lastUpdated(tablename) {
        var ajaxRequest = new htmldb_Get(null, 2000, 'APPLICATION_PROCESS=AP_OD_LASTUPDATED', 0);
        var lastUpdated;
        ajaxRequest.addParam('x01', tablename);
        var ajaxResult = ajaxRequest.get();
        lastUpdated = ajaxResult;
        ajaxRequest = null;
        $("form").find("input[type=text],textarea,select").filter(":visible:enabled:first").focus();
        alert(lastUpdated.replace("~", "\n"));
}

//JSON EXAMPLE:
//var autotextitems = [
// { item: "textarea_6_97" },
// { item: "textarea_BCS171" }
//];

//---------------------------------------------------------------------------------
// isAutoTextItem
//---------------------------------------------------------------------------------
function isAutoTextItem(itemId) {

        for (var i = 0; i < autotextitems.length; ++i) {
                var json = autotextitems[i];
                //        var autotitem        = $("#"+json["item"]+"_autotext");
                var autoitemparentid = json["item"];

                if ($.trim(itemId.toLowerCase()) == $.trim(autoitemparentid.toLowerCase())) {
                        $("#" + json["item"]).attr("data-autotextitem", "true");
                        return true;
                }
        }
        return false;
}

//---------------------------------------------------------------------------------
// forceCounterUpdate
//---------------------------------------------------------------------------------
function forceCounterUpdate(selector) {
        $(selector).each(function(index) {
                var countermax = 4000;

                if ($(this).attr("data-countermax")) {
                        countermax = Number($(this).attr("data-countermax"));
                }

                if ($(this).attr('readonly') || $(this).attr('disabled')) {
                        //null
                } else {
                        var cid = $(this).attr("id");
                        var ccid = $(this).attr("id") + '_count';

                        $('#' + cid).NobleCountForceUpdate('#' + ccid, {
                                on_negative : 'on_negative',
                                on_positive : 'on_positive',
                                max_chars : countermax //4000
                        });

                }
        });
}

//---------------------------------------------------------------------------------
// activateRowHighlight
//---------------------------------------------------------------------------------
function activateRowHighlight() {
        $("table.reporthighlight tbody tr,table.dynrendertable tbody tr").mouseover(function() {
                var anchorExists = $(this).find("a").attr("href");
                if (anchorExists) {
                        $(this).find('td').addClass("trover");
                }
        }).mouseout(function() {
                var anchorExists = $(this).find("a").attr("href");
                if (anchorExists) {
                        $(this).find('td').removeClass("trover");
                }
        });

        // Activate row selector
        $('table.reporthighlight tbody tr,table.dynrendertable tbody tr').click(function() {
                //$(this).toggleClass("trclick")
                var href = $(this).find("a").attr("href");
                if (href) {
                        window.location = href;
                }
        });
        paginationOnClick();
}

//---------------------------------------------------------------------------------
// showAtErrorMessageAlert
//---------------------------------------------------------------------------------
function showAtErrorMessageAlert() {
        if ($('.notification').length) {
                if (screenReaderUsed()) {
                        alert("Please be aware that validation errors have occurred. \n\nDetails can be found in the Error Message Notification Section of this page (Heading Level 1).");
                }
        }
}

//---------------------------------------------------------------------------------
// voiceRecognitionUsed()
//---------------------------------------------------------------------------------
function voiceRecognitionUsed() {
        return ($v('P_DH_AT_SOFTWARE').indexOf("VOICE_RECOG") != -1);
}

//---------------------------------------------------------------------------------
// screenReaderUsed()
//---------------------------------------------------------------------------------
function screenReaderUsed() {
        return ($v('P_DH_AT_SOFTWARE').indexOf("SCREEN_READER") != -1);
}

//---------------------------------------------------------------------------------
// Set Key Bindings
//---------------------------------------------------------------------------------
var keymap = [{
        hotkey : "Alt+Q",
        action : "Help"
}, {
        hotkey : "Alt+T",
        action : "Autotext"
}, {
        hotkey : "Alt+S",
        action : "Save"
}, {
        hotkey : "Alt+C",
        action : "Close"
}, {
        hotkey : "Alt+L",
        action : "Spellchecker"
}, {
        hotkey : "Alt+H",
        action : "Tasks"
}, {
        hotkey : "Alt+X",
        action : "Logout"
}, {
        hotkey : "Alt+P",
        action : "Print"
}, {
        hotkey : "Alt+K",
        action : "Key Map"
}];

var allkeys = "Hotkeys available :" + "\n\n";

//---------------------------------------------------------------------------------
// setKeys()
//---------------------------------------------------------------------------------
function setKeys() {
        for (var i = 0; i < keymap.length; ++i) {
                var json = keymap[i];
                var hotkey = json["hotkey"];
                var action = json["action"];
                if (action == "Help") {
                        allkeys = allkeys + hotkey + ": " + action + "\n\n";
                        shortcut.add(hotkey, function() {
                                callHelp();
                                // return false;
                        });
                } else if (action == "Spellchecker") {
                        allkeys = allkeys + hotkey + ": " + action + "\n\n";
                        shortcut.add(hotkey, function() {
                                spellWindow();
                                return false;
                        });
                } else if (action == "Autotext") {
                        allkeys = allkeys + hotkey + ": " + action + "\n\n";
                        shortcut.add(hotkey, function() {
                                atWindow();
                                return false;
                        });
                } else if (action == "Save") {
                        if ($("input.btn[value='Save']").length > 0) {
                                allkeys = allkeys + hotkey + ": " + action + "\n\n";
                                shortcut.add(hotkey, function() {
                                        if ($("input.btn[value='Save']")) {
                                                $("input.btn[value='Save']").click();
                                        }
                                        return false;
                                });
                        }
                } else if (action == "Tasks") {
                        if ($('#main_menu_left_tasks').length > 0) {
                                allkeys = allkeys + hotkey + ": " + action + "\n\n";
                                shortcut.add(hotkey, function() {
                                        if ($('#main_menu_left_tasks')) {
                                                appdosubmit('MOD_TSK010::APP,RB:::HELP_CONTEXT:NONE,');
                                        }
                                        return false;
                                });
                        }
                } else if (action == "Close") {
                        if ($("input.btn[value='Close']").length > 0) {
                                allkeys = allkeys + hotkey + ": " + action + "\n\n";
                                shortcut.add(hotkey, function() {
                                        if ($("input.btn[value='Close']")) {
                                                $("input.btn[value='Close']").click();
                                        }
                                        return false;
                                });
                        }
                } else if (action == "Logout") {
                        if ($("#logout").length > 0) {
                                allkeys = allkeys + hotkey + ": " + action + "\n\n";
                                shortcut.add(hotkey, function() {
                                        if ($("#logout")) {
                                                $("#logout").click();
                                        }
                                        return false;
                                });
                        }
                } else if (action == "Print") {
                        if ($("input.btn[value='Print']").length > 0) {
                                allkeys = allkeys + hotkey + ": " + action + "\n\n";
                                shortcut.add(hotkey, function() {
                                        if ($("input.btn[value='Print']")) {
                                                $("input.btn[value='Print']").click();
                                        }
                                        return false;
                                });
                        }
                } else if (action == "Key Map") {
                        allkeys = allkeys + hotkey + ": " + action + "\n\n";
                        $('body').append('<H3 class="hidden4jaws">Press "' + hotkey + '" to obtain a list of hotkeys</H3>');
                        shortcut.add(hotkey, function() {
                                alert(allkeys);
                                return false;
                        });
                }
        }
}

//---------------------------------------------------------------------------------
// Get CSS property from class
//---------------------------------------------------------------------------------

function getCSSprop(prop, fromClass) {

        // use a dummy div to extract css properties from a class
        // apw: only create the div if not already there
        if (!$('#cssprop').length) {
                $('body').append('<div id="cssprop" style="display:none;"> </div>');
        }

        $('#cssprop').removeAttr("class");
        $('#cssprop').addClass(fromClass);

        try {
                return $('#cssprop').css(prop);
        } finally {
                //      $('#cssprop').remove();
        }
};

// how to call
// e.g. alert(getCSSprop('width', 'span6'));

//---------------------------------------------------------------------------------
// TinyMCE Helper functions
//---------------------------------------------------------------------------------

try {
        tinyMCE.addI18n('en.advanced', {
                "underline_desc" : "Underline (Ctrl+U)",
                "italic_desc" : "Italic (Ctrl+I)",
                "bold_desc" : "Bold (Ctrl+B)",
                dd : "Definition Description",
                dt : "Definition Term ",
                samp : "Code Sample",
                code : "Code",
                blockquote : "Block Quote",
                h6 : "Heading 6",
                h5 : "Heading 5",
                h4 : "Heading 4",
                h3 : "Heading 3",
                h2 : "Heading 2",
                h1 : "Heading 1",
                pre : "Preformatted",
                address : "Address",
                div : "DIV",
                paragraph : "Paragraph",
                block : "Format",
                fontdefault : "Font Family",
                "font_size" : "Font Size",
                "style_select" : "Styles",
                "anchor_delta_height" : "",
                "anchor_delta_width" : "",
                "charmap_delta_height" : "",
                "charmap_delta_width" : "",
                "colorpicker_delta_height" : "",
                "colorpicker_delta_width" : "",
                "link_delta_height" : "",
                "link_delta_width" : "",
                "image_delta_height" : "",
                "image_delta_width" : "",
                "more_colors" : "More Colors...",
                "toolbar_focus" : "Jump to tool buttons - Alt+Q, Jump to editor - Alt-Z, Jump to element path - Alt-X",
                newdocument : "Are you sure you want clear all contents?",
                path : "Path",
                "clipboard_msg" : "Copy/Cut/Paste is not available in Mozilla and Firefox.\nDo you want more information about this issue?",
                "blockquote_desc" : "Block Quote",
                "help_desc" : "Help",
                "newdocument_desc" : "New Document",
                "image_props_desc" : "Image Properties",
                "paste_desc" : "Paste (Ctrl+V)",
                "copy_desc" : "Copy (Ctrl+C)",
                "cut_desc" : "Cut (Ctrl+X)",
                "anchor_desc" : "Insert/Edit Anchor",
                "visualaid_desc" : "show/Hide Guidelines/Invisible Elements",
                "charmap_desc" : "Insert Special Character",
                "backcolor_desc" : "Select Background Color",
                "forecolor_desc" : "Select Text Color",
                "custom1_desc" : "Your Custom Description Here",
                "removeformat_desc" : "Remove Formatting",
                "hr_desc" : "Insert Horizontal Line",
                "sup_desc" : "Superscript",
                "sub_desc" : "Subscript",
                "code_desc" : "Edit HTML Source",
                "cleanup_desc" : "Cleanup Messy Code",
                "image_desc" : "Insert/Edit Image",
                "unlink_desc" : "Unlink",
                "link_desc" : "Insert/Edit Link",
                "redo_desc" : "Redo (Ctrl+Y)",
                "undo_desc" : "Undo (Ctrl+Z)",
                "indent_desc" : "Increase Indent",
                "outdent_desc" : "Decrease Indent",
                "numlist_desc" : "Insert/Remove Numbered List",
                "bullist_desc" : "Insert/Remove Bulleted List",
                "justifyfull_desc" : "Align Full",
                "justifyright_desc" : "Align Right",
                "justifycenter_desc" : "Align Center",
                "justifyleft_desc" : "Align Left",
                "striketrough_desc" : "Strikethrough",
                "help_shortcut" : "Press ALT-F10 for toolbar. Press ALT-0 for help",
                "rich_text_area" : "Rich Text Area",
                "shortcuts_desc" : "Accessability Help",
                toolbar : "Toolbar"
        });
} catch(err) {
        $('body').css('visibility', 'visible');
}

function MCEinitCallback(ed) {
        var s = ed.settings;

        $("#" + ed.id + "_ifr").parent("td").css("border-top", "none");
        $("#" + ed.id + "_ifr").parent("td").css("border-right", "none");
        $("#" + ed.id + "_ifr").parent("td").css("border-left", "none");
        ed.getWin().document.body.style.border = "1px solid " + getCSSprop('border-color', 'inputcssprops');
        //"1px solid #8595b2";

        //ed.getWin().document.body.style.backgroundColor = getCSSprop('background-color', 'inputcssprops');
        $("#" + ed.id + "_tbl").css("width", "100%");
        $("#" + ed.id + "_tbl").css("width", "100%");

        ed.execCommand('mceAutoResize');

        tinymce.dom.Event.add(ed.getWin(), 'focus', function(e) {
                focusItem = ed.id;
                currentMCEItem = ed.id;
        });
}

function MCEeventCallback(ed) {

        if (ed.ctrlKey && ed.keyCode == "82" && ed.type == "keydown")// CTRL+R disable
        {
                return false;
        }

        if (ed.altKey && ed.keyCode == "84" && ed.type == "keydown")// ALT+T autotext
        {
                atWindow();
                return false;
        }
        if (ed.altKey && ed.keyCode == "76" && ed.type == "keydown")// ALT+L spellchecker
        {
                spellWindow();
                return false;
        }

        if (ed.ctrlKey && ed.keyCode == "78" && ed.type == "keydown" || ed.ctrlKey && ed.keyCode == "68" && ed.type == "keydown" || ed.ctrlKey && ed.keyCode == "87" && ed.type == "keydown" || ed.ctrlKey && ed.keyCode == "76" && ed.type == "keydown" || ed.ctrlKey && ed.keyCode == "79" && ed.type == "keydown" || ed.ctrlKey && ed.keyCode == "72" && ed.type == "keydown" || ed.ctrlKey && ed.keyCode == "69" && ed.type == "keydown" || ed.ctrlKey && ed.keyCode == "80" && ed.type == "keydown" || ed.ctrlKey && ed.keyCode == "82" && ed.type == "keydown") {
                //
                return false;
        }

        return true;
}

function MCEROinitCallback(ed) {
        ed.getWin().document.body.style.backgroundColor = getCSSprop('background-color', 'input_readonly');

        if (jQuery.browser.version < 9) {
                ed.getWin().document.body.style.border = "1px solid " + getCSSprop('border-color', 'inputcssprops');
        }
        $("#" + ed.id + "_ifr").parent("td").css("border-top", "none");
        $("#" + ed.id + "_ifr").parent("td").css("border-right", "none");
        $("#" + ed.id + "_ifr").parent("td").css("border-left", "none");

        $("#" + ed.id + "_tbl").css("border", "none");
        $("#" + ed.id + "_ifr").parent("td").css("margin-top", "0");
        $("#" + ed.id + "_ifr").parent("td").css("margin-bottom", "0");
        $("#" + ed.id + "_ifr").parent("table").css("margin-top", "0");
        $("#" + ed.id + "_ifr").parent("table").css("margin-bottom", "0");

        $("#" + ed.id + "_tbl").css("width", "100%");

        if (jQuery.browser.version < 9) {
                ed.execCommand('mceAutoResize');
        }

}

function MCEROeventCallback(ed) {
        if ((ed.shiftKey && ed.keyCode == "9" && ed.type == "keydown") || (ed.keyCode == "9" && ed.type == "keydown"))// shift+tab disable
        {
                return true;
        }
        return false;
}

var currentMCEItem;
var wasDirtyOnSpell;

var MCEvalidElements = //"-p[align|style],"+
"html," + "br," + "u," + "em," + "strong," + "b," + "ul[align]," + "li[align]," + "ol[align]," + "span[*]";

var MCEbuttons =
//                       "bold,italic,underline,|,"+
"bold,italic,underline,fontsizeselect,|," + "justifyleft,justifycenter,justifyright,justifyfull,|," + "bullist,numlist,|,outdent," + "indent,|,undo,redo,|,spellcheck";
//",|,code";

var MCEClass = "mceEditor";

var MCEitems;

var MCEReadOnlyItems;

function disableShortcuts() {
        tinyMCE.get
}

function activateTinyMCE(item) {

        //if (jQuery.browser.version >= 9 || jQuery.browser.mozilla) {
        if (jQuery.browser.version >= 9 || is_mozilla) {

                var MCEbuttons = "bold,italic,underline,fontsizeselect,|," + "alignleft aligncenter alignright,alignjustify,|," + "bullist,numlist,|,outdent," + "indent,|,undo,redo,|,spellchecker";

                var itemButtons;

                if (isAutoTextItem(item)) {

                        itemButtons = MCEbuttons + ",|,autotext";
                } else {
                        itemButtons = MCEbuttons;
                }

                var txtAreaElement = "textarea#" + item;
                // This code is handled in ie6 through the advanced themes used by tinyMce.
                // For ie10 advanced themes is not available hence this quick and dirty solution.
                // P7_SEC_DPA_MESSAGE can be found in the global profile maintenance page.
                var myWidth = 700;
                if (item == 'P7_SEC_DPA_MESSAGE') {
                        myWidth = 480;
                }

                tinymce.init({
                        selector : txtAreaElement,
                        theme : "modern",
                        toolbar_items_size : "small",
                        content_css : "/i/themes/moj_blue_theme/css/content.css",
                        mode : "exact",
                        width : myWidth,
                        valid_elements : MCEvalidElements,
                        toolbar1 : itemButtons,
                        toolbar2 : "",
                        menubar : false,
                        plugins : "autoresize,paste",
                        statusbar : false,
                        extended_valid_elements : "p[*]",
                        //force_br_newlines: true,
                        //force_p_newlines:  false,
                        //forced_root_block: '',
                        paste_text_sticky : true,
                        paste_text_sticky_default : true,
                        //init_instance_callback:MCEinitCallback,
                        handle_event_callback : MCEeventCallback,
                        setup : function(ed) {

                                ed.addButton('spellchecker', {
                                        title : 'Spellchecker',
                                        image : '/i/themes/moj_blue_theme/images/spellcheck_mce.gif',
                                        onclick : function() {
                                                ed.focus();
                                                var thisId = tinyMCE.activeEditor.id;
                                                spellWindow(thisId);
                                        }
                                });

                                ed.addButton('autotext', {
                                        title : 'Autotext',
                                        image : '/i/themes/moj_blue_theme/images/autotext_mce.gif',
                                        onclick : function() {
                                                ed.focus();
                                                var thisId = tinyMCE.activeEditor.id;
                                                atWindow(thisId);
                                        }
                                });

                                ed.on('keydown', function(e) {
                                        $(document).idleTimer("reset");
                                });

                                // Defect 4554 - Spell check working intermittently in HTML field
                                ed.on('focus', function(e) {
                                        focusItem = ed.id;
                                        currentMCEItem = ed.id;
                                });
                        }
                });

        } else {

                var MCEbuttons = "bold,italic,underline,fontsizeselect,|," + "justifyleft,justifycenter,justifyright,justifyfull,|," + "bullist,numlist,|,outdent," + "indent,|,undo,redo,|,spellcheck";
                var itemButtons;

                if (isAutoTextItem(item)) {

                        itemButtons = MCEbuttons + ",autotext";

                } else {
                        itemButtons = MCEbuttons;
                }

                tinyMCE.init({
                        language : "en",
                        mode : "exact",
                        elements : item,
                        theme : "advanced",
                        content_css : "/i/themes/moj_blue_theme/css/content.css",
                        valid_elements : MCEvalidElements,
                        theme_advanced_buttons1 : itemButtons,
                        theme_advanced_buttons2 : "",
                        theme_advanced_toolbar_location : "top",
                        theme_advanced_toolbar_align : "left",
                        theme_advanced_statusbar_location : "none",
                        theme_advanced_resize_horizontal : false,
                        theme_advanced_resizing : true,
                        init_instance_callback : MCEinitCallback,
                        handle_event_callback : MCEeventCallback,
                        plugins : "autoresize,paste",
                        extended_valid_elements : "p[*]",
                        force_p_newlines : true,
                        paste_text_sticky : true,
                        paste_text_sticky_default : true,
                        setup : function(ed) {

                                ed.addButton('spellcheck', {
                                        title : 'Spellcheck',
                                        image : '/i/themes/moj_blue_theme/images/spellcheck_mce.gif',
                                        onclick : function() {
                                                ed.focus();
                                                spellWindow($(this).attr("id"));
                                        }
                                });

                                ed.addButton('autotext', {
                                        title : 'Autotext',
                                        image : '/i/themes/moj_blue_theme/images/autotext_mce.gif',
                                        onclick : function() {
                                                ed.focus();
                                                atWindow($(this).attr("id"));
                                        }
                                });

                                ed.onKeyDown.add(function(ed, e) {
                                        $(document).idleTimer("reset");
                                });

                        }
                });

        }

}

function activateTinyMCEReadOnly(item) {

        //if (jQuery.browser.version >= 9 || jQuery.browser.mozilla) {
        if (jQuery.browser.version >= 9 || is_mozilla) {

                var txtAreaElement = "textarea#" + item;

                tinyMCE.init({
                        mode : "exact",
                        selector : txtAreaElement,
                        theme : "modern",
                        content_css : "/i/themes/moj_blue_theme/css/content.css",
                        width : 700,
                        toolbar1 : "",
                        toolbar2 : "",
                        toolbar : false,
                        menubar : false,
                        statusbar : false,
                        plugins : "autoresize",
                        extended_valid_elements : "p[*]",
                        //force_br_newlines: true,
                        //force_p_newlines:  false,
                        //forced_root_block: '',
                        readonly : true,
                        plugins : "autoresize",
                        init_instance_callback : MCEROinitCallback,
                        handle_event_callback : MCEROeventCallback
                });

        } else {

                tinyMCE.init({
                        mode : "exact",
                        elements : item,
                        theme : "advanced",
                        theme_advanced_buttons1 : "",
                        theme_advanced_buttons2 : "",
                        theme_advanced_toolbar_location : "none",
                        theme_advanced_toolbar_align : "left",
                        theme_advanced_statusbar_location : "none",
                        theme_advanced_resize_horizontal : false,
                        theme_advanced_resizing : true,
                        plugins : "autoresize",
                        extended_valid_elements : "p[*]",
                        force_p_newlines : true,
                        readonly : false,
                        plugins : "autoresize",
                        init_instance_callback : MCEROinitCallback,
                        handle_event_callback : MCEROeventCallback
                });

        }

}

function setTinyMCEItems(items, itemsreadonly) {
        MCEitems = items;
        MCEReadOnlyItems = itemsreadonly;
}

function attachTinyMCE() {
        // Non readonly items
        if (MCEitems != null) {
                var splitresult = MCEitems.split(",");
                for ( i = 0; i < splitresult.length; i++) {
                        activateTinyMCE(splitresult[i]);
                } // end loop
        }
        // readonly items
        if (MCEReadOnlyItems != null) {
                var splitresultro = MCEReadOnlyItems.split(",");
                for ( i = 0; i < splitresultro.length; i++) {
                        activateTinyMCEReadOnly(splitresultro[i]);
                } // end loop
        }

}

//---------------------------------------------------------------------------------
// attachItemToolbar
//---------------------------------------------------------------------------------
function attachItemToolbar() {
        uitextareaexp.each(function() {
                var thisId = $(this).attr("id");
                var countermax = 4000;
                var addInfo = "<span class='hidden4jaws'> - additional information spellcheck available";
                var addInfoAt = " autotext available";
                var addInfoClose = "</span>";

                if ($(this).attr("data-noItemToolbar")) {
                        return;
                }

                if ($(this).attr("data-countermax")) {
                        countermax = $(this).attr("data-countermax");
                }
                if ($(this).attr('readonly') || $(this).attr('disabled') || $(this).attr('data-mimic_readonly') || $(this).attr('data-toolbar') == "false") {
                        //null
                } else {
                        var toolbarHtml = '<div id ="' + thisId + '_itemtoolbar" class="itemtoolbar" style="display:block;">' + '<a id ="' + thisId + '_spell" style="text-decoration:none;" href="javascript:return false;" onclick="spellWindow(' + "'" + thisId + "'" + '); return false;"><img alt="Spell Checker Available"src="/i/themes/moj_blue_theme/images/spellcheck_on.gif" style="background-color:transparent;vertical-align:middle; margin-right:2px;"/></a>';

                        if (isAutoTextItem(thisId)) {
                                toolbarHtml = toolbarHtml + '<a id ="' + thisId + '_autotext" style="text-decoration:none;" href="javascript:return false;" onclick="atWindow   (' + "'" + thisId + "'" + ');return false;"> <img alt="Autotext Available" src="/i/themes/moj_blue_theme/images/autotext_on.gif" style="background-color:transparent;vertical-align:middle; margin-right:2px;"/> </a>'
                                addInfo = addInfo + addInfoAt;
                        }
                        toolbarHtml = toolbarHtml + '<span id="' + thisId + '_count"></span>&nbsp;remaining</div>';
                        addInfo = addInfo + addInfoClose;

                        $(this).after(toolbarHtml);

                        var currLabelText = $("label[for='" + thisId + "']").html();
                        $("label[for='" + thisId + "']").html(currLabelText + addInfo);

                        var cid = thisId;
                        var ccid = thisId + '_count';
                        $('#' + cid).NobleCount('#' + ccid, {
                                on_negative : 'on_negative',
                                on_positive : 'on_positive',
                                max_chars : countermax
                        });

                }
        });
        //    $("div.itemtoolbar").show();
}

//---------------------------------------------------------------------------------
// disableFunctionKeys
//---------------------------------------------------------------------------------
/*
112:'f1',
113:'f2',
114:'f3',
115:'f4',
116:'f5',
117:'f6',
118:'f7',
119:'f8',
120:'f9',
121:'f10',
122:'f11',
123:'f12',
8  :'Backspace'
*/

//---------------------------------------------------------------------------------
// disableSpecialKeys
//---------------------------------------------------------------------------------
function disableSpecialKeys() {
        document.onkeydown = function(e) {
                //debug return true;

                var keycode;
                if (window.event)
                        keycode = window.event.keyCode;
                else if (e)
                        keycode = e.which;

                //if ($.browser.msie) {
                if (is_msie) {
                        // Allow ctrl+c ctrl+v ctrl+a ctrl+x
                        if ((window.event.ctrlKey && window.event.keyCode == 88) || (window.event.ctrlKey && window.event.keyCode == 65) || (window.event.ctrlKey && window.event.keyCode == 67) || (window.event.ctrlKey && window.event.keyCode == 86)) {
                                return true;
                        }

                        if (window.event.altKey && window.event.keyCode == 37) {
                                alert('Alt+Leftarrow - This key combination is not allowed here');
                                return false;
                        }

                        if ((window.event.ctrlKey && window.event.keyCode > 40) || (window.event.keyCode >= 112 && window.event.keyCode <= 123)) {
                                window.event.keyCode = 505;
                                //return false;
                        }

                        // Backspace
                        var targetId = event.srcElement.id;

                        if (window.event.keyCode == 8 && (event.srcElement.type != "text" && event.srcElement.type != "textarea" && event.srcElement.type != "password" || $('#' + targetId).is('[readonly]'))) {
                                window.event.keyCode = 505;
                        }

                        if (window.event && window.event.keyCode == 505) {// New action for F5 and F11
                                return false;
                                // Must return false or the browser will refresh anyway
                        }

                        if (window.event.keyCode == 13 && event.shiftKey) {// No action for Enter and ShiftKey
                                return false;
                                // Must return false for this combination
                        }

                } else {

                        // Allow ctrl+c ctrl+v ctrl+a ctrl+x
                        if ((e.ctrlKey && keycode == 88) || (e.ctrlKey && keycode == 65) || (e.ctrlKey && keycode == 67) || (e.ctrlKey && keycode == 86)) {
                                return true;
                        }

                        if (e.altKey && keycode == 37) {
                                alert('Alt+Leftarrow - This key combination is not allowed here');
                                keycode = 505;
                        }

                        if ((e.ctrlKey && keycode > 40) || (keycode >= 112 && keycode <= 123)) {
                                keycode = 505;
                                //return false;
                        }

                        // Backspace
                        var targetId = e.target.id;

                        if (keycode == 8 && (e.target.type != "text" && e.target.type != "textarea" && e.target.type != "password" || $('#' + targetId).is('[readonly]'))) {
                                keycode = 505;
                        }

                        if (e.shiftKey && keycode == 13 ) { // No action for Enter and ShiftKey
                                return false;
                        }


                        if (e && keycode == 505) {// New action for F5 and F11
                                if (e.preventDefault) {
                                        //alert('Disabled in other Browsers');
                                        e.preventDefault();
                                        e.stopPropagation();
                                }
                        }

                }
        }
}

//---------------------------------------------------------------------------------
// createFirstNavigableItem
//---------------------------------------------------------------------------------
function createFirstNavigableItem() {

        var firstNavItemLink = "<a class='noheight' :attr id='firstNavItem' href='#'>Hidden first navigation item<img src='/i/themes/moj_blue_theme/images/1px_trans.gif' alt='firstNavItem'></a>";
        if ($("#searchform").length > 0) {
                $("#searchform").prepend(firstNavItemLink.replace(":attr", ""));
        } else {
                if ( moduleId == 'OFF030' || moduleId == 'ASS010') {
                        $(".RegionWrapper").filter(":first").prepend(firstNavItemLink.replace(":attr", "tabindex=1"));
                } else {
                        $(".RegionWrapper").filter(":first").prepend(firstNavItemLink.replace(":attr", ""));
                }
        }

}

//---------------------------------------------------------------------------------
// navigateFirstItem()
//---------------------------------------------------------------------------------
function navigateFirstItem() {
        $("#firstNavItem").focus();
}

function dragon() {
        $('img[id^="DRAGON_"]').each(function() {// selector starts with DRAGON_hot
                var thisId = $(this).attr('id');
                $(this).wrap('<div id="' + thisId + '_div' + '" style="' + $(this).attr("style") + '">');
                $(this).removeAttr("style");
                $(this).attr('id', thisId + '_img');
                $('#' + $(this).attr('id') + '_div').bgiframe();
                return null;
        });
}

function getTableThText(tableSelector, headerColumnNo) {
        return $(tableSelector).find("th:eq(" + headerColumnNo + ")").text();
}

function getTableTdText(tableSelector, headerColumnNo) {
        return $(tableSelector).find("td:eq(" + headerColumnNo + ")").text();
}

function getTableLabelText(tableSelector, headerColumnNo) {
        return $(tableSelector).find("label:eq(" + headerColumnNo + ")").text();
}

function getTableFirstColText(tableSelector, headerColumnNo) {
        return $(tableSelector).find("td:eq(" + headerColumnNo + ")").text();
}

function screenReaderExtraMarkup() {

        // AT Screen Reader Only Markup

        if (screenReaderUsed()) {

                /*
                 *  This is a test for AT to add title attribute for acronyms
                 */

                var acronymArray = new Array('LAO', 'RFI', 'INTBDTTO', 'PNC');
                var acronymArrayAt = new Array('L A O', 'R F I', 'I N T B D T T O', 'P N C');

                for ( i = 0; i < acronymArray.length; i++) {

                        $('input.btn').each(function() {
                                if ($(this).attr('value').indexOf(acronymArray[i]) != -1) {
                                        $(this).attr('title', $(this).attr('value').replace(acronymArray[i], acronymArrayAt[i]));
                                                //alert($(this).attr('title'));
                                }
                        });

                }

                /*
                 *  Insert hidden div for current page information e.g.
                 <div id="currentpageinfo" class="hidden4jaws">
                 <H1>Current Page Information</H1>
                 Page title is
                 This page is readonly.
                 This page contains disabled form items.
                 Following Sections are marked as complete: 3 - Accommodation, 8 - Drug Misuse.
                 </div>
                 *
                 */

                /*
                 *  Find H1 tags
                 */

                var currentPageTitle = "";
                var currentPageInfoPre = '<div id="currentpageinfo" class="hidden4jaws"><H1>Current Page Information</H1>';
                var currentPageInfoBody = '';
                var currentPageInfoPost = '</div>';
                var currentPageInfoNl = "<br>";
                var sectionsComplete = $('.sectioncompleteicon');
                var sectionsCompleteTxt = "";

                /* Get Page Title */
                currentPageTitle = $(document).attr("title");
                currentPageTitle = currentPageTitle.replace("OASys-R", "");
                currentPageTitle = currentPageTitle.replace("OASys", "");
                currentPageTitle = currentPageTitle.replace("Restricted", "");
                currentPageTitle = jQuery.trim(currentPageTitle);

                currentPageInfoBody = currentPageInfoBody + "Page Context is: " + currentPageTitle + "." + currentPageInfoNl;

                /* Check if page is readonly*/
                if (uip0readonly.length > 0 && (uip0readonly.val() != "N")) {
                        currentPageInfoBody = currentPageInfoBody + "This page is readonly." + currentPageInfoNl;
                }

                /* Check if page contains disabled form items */
                if ($(':input:disabled:visible').length > 0) {
                        currentPageInfoBody = currentPageInfoBody + "This page contains disabled fields." + currentPageInfoNl;
                }

                /* If left section menu is present list completed sections */
                if (sectionsComplete.length > 0) {
                        sectionsComplete.each(function() {

                                if (sectionsCompleteTxt.length > 0) {
                                        sectionsCompleteTxt = sectionsCompleteTxt + $(this).next().text() + ", ";
                                } else {
                                        sectionsCompleteTxt = sectionsCompleteTxt + $(this).next().text() + ", ";
                                }
                        });
                        currentPageInfoBody = currentPageInfoBody + "Following Sections are marked as complete: " + currentPageInfoNl + sectionsCompleteTxt;
                }

                currentPageInfoBody = currentPageInfoBody + "Press Alt+K for list of available hotkeys";

                $(currentPageInfoPre + currentPageInfoBody + currentPageInfoPost).insertBefore('#contentwrapper');


                // Additional Markup to correct redener issues KB
                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'SEC13' ) {
                        //processAtAddTableHeaderRow();
                        //processAtAddInsertTableHeaderRow();
                        processAtTables();
                }
                if ( moduleId == 'ASS020' ) {
                        processAtLabelCheckbox();
                }
                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'SEC2' ) {
                        processAtLabelCheckbox();
                }

                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'SEC4' ) {
                        processAtLabelCheckbox();
                }

                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'SEC8' ) {
                        processAtAddTableHeaderRow();
                        processAtLabelCheckbox();
                }

                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'ROSHA1' ) {
                        processAtLabelSelect();
                        //processAtAddTableHeaderRow();
                }

                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'SAQ' ) {
                        processAtLabelSelect();
                        //processAtAddTableHeaderRow();
                }

                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'ROSHS' ) {
                        processAtLabelSelect();
                        //processAtAddTableHeaderRow();
                }

                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'RMP' ) {
                        processAtCheckbox();
                }

                ScreenReaderFooter();

        }

}// screenReaderExtraMarkup
// ------------------------------------------------------------------------------------------------------
// KB 04/08/2022 -
// ------------------------------------------------------------------------------------------------------
function processAtTablesTwoColumns(p_column1, p_column2)
{
        var prevFirstColText = "";
        var currentTable;
        var currentTR;
        var currentTD;
        var currentTDItem;
        var currentTDItemLabel;

        // KB Correction for inner tables headers.
        $('table').each(function() {

                currentTable = $(this);

                var i = 0;
                var noOfColumns = currentTable.find("th").length;
                var noOflegColumns = currentTable.find("legend").length;
                var noOfTDColumns = currentTable.find("td").length;

                if (noOfColumns > 2) {

                        // Get the header information, this is only used when the header is NOT associated SCOPE
                        var MyHeaders = [];
                        var MyHeaderTable = currentTable.clone(true);

                        MyHeaderTable.find("th").each(function() {

                                MyHeaders[i] = $(this).text();
                                i ++;

                        });

                        $(this).find("tr").each(function() {

                                currentTR = $(this);

                                noOfTDColumns = currentTR.find("td").length;

                                if ( noOfTDColumns > 2 ) {

                                        i_td_counter = 0;

                                        currentTR.find("td").each(function() {

                                                currentTD = $(this);

                                                if ( p_column1 == 1 && i_td_counter == 1 ) {
                                                        id = $(this).find("select").attr("id");
                                                        $( '#' + id ).attr('alt', MyHeaders[i_td_counter]);
                                                }
                                                if ( p_column2 == 1 && i_td_counter == 2 ) {
                                                        id = $(this).find("select").attr("id");
                                                        $( '#' + id ).attr('alt', MyHeaders[i_td_counter]);
                                                }

                                                i_td_counter += 1;
                                        });
                                }
                        });
                }

        // -----------------------------
        });
}
// ------------------------------------------------------------------------------------------------------
// KB 04/08/2022 -
// ------------------------------------------------------------------------------------------------------
function processAtCheckbox()
{
        var prevFirstColText = "";
        var currentTable;
        var currentTR;
        var currentTD;
        var currentTDItem;
        var currentTDItemLabel;

        // KB Correction for inner tables headers.
        $('table').each(function() {
                currentTable = $(this);

                currentTable.find("tr").each(function() {

                        currentTR = $(this);

                        i_counter = 0;
                        i_foundCheckbox = 0;
                        i_CheckboxId = 0;

                        currentTR.find("td").each(function() {
                                currentTD = $(this);

                                if (i_counter == 0) {
                                        currentTDItemLabel = currentTD.html();
                                }

                                noOfCheckboxs = currentTD.has("input[type=checkbox]").not(':hidden').length;

                                if ( noOfCheckboxs == 1 ) {
                                        currentTDItem = currentTD.find(":input[id!='itm'],:input[id!='textarea']").not(':hidden').attr("id");

                                        if (currentTDItem != undefined) {
                                                i_CheckboxId = currentTDItem;
                                                currentTDItemLabel = $("label[for='" + i_CheckboxId + "']");
                                                currentTDItemLabel.remove();
                                        }

                                        i_foundCheckbox = 1;
                                }

                                i_counter++;
                        });

                        i_counter = 0;

                        if ( i_foundCheckbox == 1 )
                        {
                                currentTR.find("td").each(function() {
                                        currentTD = $(this);

                                        if (i_counter == 0) {
                                                currentTD.replaceWith("<td class='dynformlabel'><label for='" + i_CheckboxId + "'>" + currentTD.html() + "</label></td>");
                                        }

                                        i_counter++;
                                });
                        }

                });

        // -----------------------------
        });
}
// ------------------------------------------------------------------------------------------------------
// KB 04/08/2022 -  BAD BAD BAD
// ------------------------------------------------------------------------------------------------------
function processAtLableBeforeCheckbox()
{
        var prevFirstColText = "";
        var currentTable;
        var currentTR;
        var currentTD;
        var currentTDItem;
        var currentTDItemLabel;

        // KB Correction for inner tables headers.
        $('table').each(function() {
                currentTable = $(this);

                currentTable.find("tr").each(function() {

                        currentTR = $(this);

                        i_counter = 0;
                        i_foundCheckbox = 0;
                        i_CheckboxId = 0;

                        currentTR.find("td").each(function() {
                                currentTD = $(this);

                                if (i_counter == 0) {
                                        currentTDItemLabel = currentTD.html();
                                }

                                noOfCheckboxs = currentTD.has("input[type=checkbox]").not(':hidden').length;

                                if ( noOfCheckboxs == 1 ) {
                                        currentTDItem = currentTD.find(":input[id!='itm'],:input[id!='textarea']").not(':hidden').attr("id");

                                        if (currentTDItem != undefined) {
                                                i_CheckboxId = currentTDItem;
                                                currentTDItemLabel = $("label[for='" + i_CheckboxId + "']");
                                                $( "<label for=" + i_CheckboxId + ">" + currentTDItemLabel.html() + "&nbsp;</label>" ).insertBefore( '#' + i_CheckboxId );
                                                currentTDItemLabel.remove();
                                        }

                                        i_foundCheckbox = 1;
                                }

                                i_counter++;
                        });

                });

        // -----------------------------
        });
}
// ------------------------------------------------------------------------------------------------------
// KB 04/08/2022 - Stop reading label twice.
// ------------------------------------------------------------------------------------------------------
function processAtLabelCheckbox()
{
        var prevFirstColText = "";
        var currentTable;
        var currentTR;
        var currentTD;
        var currentTDItem;
        var currentTDItemLabel;

        $("input[type=checkbox]").each( function() {
                i_CheckboxId = $(this).attr("id");
                $( this ).attr('aria-labelledby', 'lb_' + $(this).attr("id") );
                currentTDItemLabel = $("label[for='" + i_CheckboxId + "']");
                currentTDItemLabel.attr('id','lb_' + i_CheckboxId );
                currentTDItemLabel.attr('aria-hidden',"true");
        });

}
// ------------------------------------------------------------------------------------------------------
// KB 12/08/2022 - change first row to be table header
// ------------------------------------------------------------------------------------------------------
function processAtAddTableHeaderRow()
{
        var currentTable;
        var currentTR;
        var currentTD;
        var currentTDItem;
        var currentTDItemLabel;
        var rowNumber;

        // KB Correction for inner tables headers.
        $('table').each(function() {

                currentTable = $(this);

                //alert(currentTable.text());

                var noOfColumns = currentTable.find("th").length;


                if (noOfColumns > 2) {

                        // -----------------------------------------
                        $(this).find("tr").each(function() {
                                rowNumber = 0;
                                currentTR = $(this);
                                noOfColumns = currentTR.find("td").length;

                                if (noOfColumns > 2) {
                                        currentTR.find("td").each(function() {

                                                if ( rowNumber == 0 ) {
                                                        currentTD = $(this);
                                                        myString = currentTD.html();
                                                        currentTD.replaceWith( '<th class="dynformlabel" scope="row">' + myString + '</th>' );

                                                }
                                                rowNumber++;
                                        });
                                }
                        });
                }

        });

}
// ------------------------------------------------------------------------------------------------------
// KB 12/08/2022 - insert hiden for JAWS header row
// ------------------------------------------------------------------------------------------------------
function processAtAddInsertTableHeaderRow()
{
        var currentTable;
        var currentTR;
        var currentTD;
        var currentTDItem;
        var currentTDItemLabel;
        var preTDItemLabel;
        var rowNumber;

        // KB Correction for inner tables headers.
        $('table').each(function() {

                currentTable = $(this);

                var noOfColumns = currentTable.find("th").length;

                if (noOfColumns > 2) {

                        // -----------------------------------------
                        $(this).find("tr").each(function() {
                                rowNumber = 0;
                                currentTR = $(this);
                                noOfColumns = currentTR.find("td").length;

                                if (noOfColumns > 2) {
                                        currentTR.find("td").each(function() {

                                                if ( rowNumber == 0 ) {
                                                        currentTD = $(this);
                                                        myString = currentTD.html();
                                                        if (myString == " " )
                                                        {
                                                                preTDItemLabel = "<span class='hidden4jaws'>" + preTDItemLabel + "</span>";
                                                                currentTD.replaceWith( '<th class="dynformlabel" scope="row">' + preTDItemLabel + '</th>' );

                                                        } else {
                                                                preTDItemLabel = myString;
                                                                currentTD.replaceWith( '<th class="dynformlabel" scope="row">' + myString + '</th>' );
                                                        }

                                                }
                                                rowNumber++;
                                        });
                                }
                        });
                }

        });

}
// ------------------------------------------------------------------------------------------------------
// KB 12/08/2022 - Additonal information for dropdowns within a grid
// ------------------------------------------------------------------------------------------------------
function processAtLabelSelect()
{
        var currentTable;
        var currentTR;
        var currentTD;
        var currentTDItem;
        var currentTDItemLabel;
        var preTDItemLabel;
        var rowNumber;

        // KB Correction for inner tables headers.
        $('table').each(function() {

                currentTable = $(this);
                // Get the header information, this is only used when the header is NOT associated SCOPE

                var MyHeaders = [];
                var MyHeaderTable = currentTable.clone(true);

                if ( MyHeaderTable.find('table').length > 0 )
                {
                        MyHeaderTable.find('table').remove();
                }

                var i=0;

                MyHeaderTable.find("th").each(function() {

                        MyHeaders[i] = $(this).text();
                        i ++;

                });

                if (i > 0) {

                        // -----------------------------------------
                        $(this).find("tr").each(function() {
                                rowNumber = 0;
                                currentTR = $(this);
                                noOfColumns = currentTR.find("td").length;

                                currentTR.find("td").each(function() {
                                        if ( rowNumber == 0 ) {
                                                currentTD = $(this);
                                                myString = currentTD.html();
                                        }

                                        $(this).find("select").each(function() {
                                                currentID = $( this ).attr('id');
                                                $( "<label class='hidden4jaws' for=" + currentID + ">" + myString + ". " + MyHeaders[rowNumber] + "</label>" ).insertBefore( '#' + currentID );
                                        });

                                        rowNumber++;
                                });
                        });
                }

        });

}
// ------------------------------------------------------------------------------------------------------
// KB 06/11/2018 - Add additional meta data to tables for screen users
// ------------------------------------------------------------------------------------------------------
function  processAtTables()
{

        var prevFirstColText = "";
        var currentTable;
        var currentTR;
        var currentTD;
        var currentTDItem;
        var currentTDItemLabel;

        // KB Correction for inner tables headers.
        $('table').each(function() {

                currentTable = $(this);

                var noOfColumns = currentTable.find("th").length;
                var noOflegColumns = currentTable.find("legend").length;
                var noOfTDColumns = currentTable.find("td").length;


                if (noOfColumns > 0) {

                        var i = 0;
                        // Get the header information, this is only used when the header is NOT associated SCOPE
                        var MyHeaders = [];
                        var MyHeaderTable = currentTable.clone(true);

                        if ( MyHeaderTable.find('table').length > 0 )
                        {
                                MyHeaderTable.find('table').remove();
                        }


                        MyHeaderTable.find("th").each(function() {

                                MyHeaders[i] = $(this).text();
                                i ++;

                        });

                        var buttonFound = $(this).find("tr :button").length;

                        // -----------------------------------------
                        $(this).find("tr").each(function() {

                                // No headers so no work to do.
                                if (i == 0) return false;

                                // -----------------------------------------
                                currentTR = $(this);
                                var j = 0;

                                var buttonLabel = "";

                                currentTR.find("td").each(function() {


                                        blnHidden = false;

                                        currentTD = $(this);

                                        headerid = $(this).attr('headers');

                                        if (headerid != undefined)
                                        {
                                                headerText = document.getElementById(headerid).innerHTML;
                                                headerText = headerText.replace(/<br>/gi,' ');
                                        } else {
                                                headerText = MyHeaders[j];
                                        }


                                        // confirm that the current row does NOT contain a table
                                        if ( currentTD.find('table').length ) return false;

                                        if ( MyHeaders[0] == '' ) return false;


                                        // Correction to stop header being duplicated

                                        if ( currentTD.text().length == 0 && currentTD.children().length == 0 ) {
                                                j++;
                                                return true;
                                        }

                                        currentTDItem = currentTD.find(":input[id!='itm'],:input[id!='textarea']").not(':hidden').attr("id");


                                        if (currentTDItem != undefined) {
                                                if ( $('#' + currentTDItem).attr('type') == 'hidden') blnHidden = true;
                                        }

                                        if ( buttonFound && currentTD.text().trim() != '') buttonLabel = buttonLabel + ',' + headerText + ', ' + currentTD.text();

                                        // KB - amended to calculate the length correctly.
                                        strLength = currentTD.text().trim();

                                        if (currentTDItem == undefined) {
                                                if ( MyHeaders[0] != '' ) {
                                                         currentTD.prepend( '<span class="hidden4jaws">, ' + MyHeaders[j] + ',&nbsp;</span>');
                                                }
                                        }

                                        if (strLength.length > 0 && j == 0) {
                                                prevFirstColText = currentTD.text();
                                        }

                                        if (blnHidden == false) {
                                                if (currentTDItem != undefined) {
                                                        if (j > -1) {


                                                                currentTDItemLabel = $("label[for='" + currentTDItem + "']");

                                                                if (currentTDItemLabel.length > 0) {
                                                                        currentTDItemLabel.attr("class", "hidden4jaws");
                                                                        if (headerText != undefined)
                                                                        {
                                                                                if ( currentTDItem.match(/itm*/) ) {

                                                                                        if ( $('#' + currentTDItem).prop('type') == 'checkbox' ) {
                                                                                                var mynew = prevFirstColText.replace(',',' ');
                                                                                                mynew = mynew.substring(mynew.indexOf(',') +1);
                                                                                                currentTDItemLabel.text( mynew + ", " + headerText);
                                                                                        } else {
                                                                                                currentTDItemLabel.text(prevFirstColText + ", " + headerText);
                                                                                        }

                                                                                } else {
                                                                                        $('#' + currentTDItem).attr('alt',prevFirstColText + "," + headerText + ", " + currentTDItemLabel.text());
                                                                                        currentTDItemLabel.remove();
                                                                                }
                                                                        } else {
                                                                                // Get the controls type, CHECKBOX special case.
                                                                                if ( $('#' + currentTDItem).prop('type') == 'checkbox' )
                                                                                {
                                                                                                var mynew = prevFirstColText.replace(',',' ');
                                                                                                mynew = mynew.substring(mynew.indexOf(',') +1);
                                                                                        $('#' + currentTDItem).attr('alt',mynew );
                                                                                        // $('#' + currentTDItem).attr('alt',prevFirstColText );
                                                                                } else {
                                                                                        $('#' + currentTDItem).attr('alt',prevFirstColText + "," + currentTDItemLabel.text());
                                                                                }
                                                                                currentTDItemLabel.remove();
                                                                        }
                                                                } else {
                                                                        if ($("textarea#" + currentTDItem).length > 0) {
                                                                                $('#' + currentTDItem).attr('alt',prevFirstColText + ',' + headerText + ', Enter notes.');
                                                                        } else {
                                                                                if ( buttonFound )
                                                                                {
                                                                                        // Change symboles to words
                                                                                        buttonLabel = buttonLabel.replace('<','less than ');
                                                                                        headerText = headerText.replace('<','less than ');
                                                                                        if ( !$("#" + currentTDItem).attr('alt') )
                                                                                                $("#" + currentTDItem).attr("alt",buttonLabel + ", " + headerText);
                                                                                } else {
                                                                                        $('#' + currentTDItem).attr('alt',prevFirstColText + ',' + headerText);
                                                                                }
                                                                        }
                                                                }
                                                        }
                                                }
                                        }
                                        j++;

                                });
                                // -----------------------------------------

                        });

                        // -----------------------------------------
                } else if (noOfTDColumns > 0) {

                        //var i = 0;

                        //while (i < noOfTDColumns) {
                        //      i++;
                        //}
                        // -----------------------------------------
                        $(this).find("tr").each(function() {

                                // -----------------------------------------
                                currentTR = $(this);
                                //
                                var j = 0;
                                var firstTDText = '';
                                currentTR.find("td").each(function() {
                                        currentTD = $(this);
                                        if (currentTD.text().length > 0 && j == 0) {

                                                firstTDText = currentTD.text();
                                        } else {
                                                var k = 0;
                                                currentTD.find(":input:visible").each(function() {
                                                        var currentTDInput = $(this);

                                                        var currentTDInputID = currentTDInput.attr("id");

                                                        currentTDItemLabel = $("label[for='" + currentTDInputID + "']");
                                                        var currentTDItemLabelText = currentTDItemLabel.text();
                                                        // The label text
                                                        if (currentTDItemLabelText != undefined && k > 0) {
                                                                // KB
                                                                if (currentTDInputID.match(/LOVDSC_/g) == null) {
                                                                        $('<label  class="hidden4jaws" for="' + currentTDInputID + '">' + firstTDText + '</label>').insertBefore("#" + currentTDInputID);
                                                                } else {
                                                                        $('<label  class="hidden4jaws" for="' + currentTDInputID + '">' + firstTDText + ' Description</label>').insertBefore("#" + currentTDInputID);
                                                                }
                                                        }

                                                        k++;
                                                });

                                        }

                                        j++;
                                });
                                // -----------------------------------------

                        });
                }
        });


}
// ------------------------------------------------------------------------------------------------------
// KB 06/11/2018 - Add additional meta data to tables for screen users
// ------------------------------------------------------------------------------------------------------
function ScreenReaderFooter()
{
        // KB - Now add additional information to the paging panel.

        var Allpagination = $(".fielddata");

        if (Allpagination.length > 0)
        {

                Allpagination.each(function() {

                         $(this).find('a').each( function(index) {
                                $(this).prepend('<span class="hidden4jaws">GO TO PAGE&nbsp;</span>');
                         });

                         $(this).find('b').each( function(index) {
                                $(this).prepend('<span class="hidden4jaws">YOU ARE ON PAGE&nbsp;</span>');
                         });
                });

        }

}
// ------------------------------------------------------------------------------------------------------
// KB 06/11/2018 - Add additional meta data to tables for screen users
// ------------------------------------------------------------------------------------------------------
function screenReaderCorrectGridView()
{
                if (screenReaderUsed() )
                {
                        // processAtTables();
                        ScreenReaderFooter();
                }
}
//---------------------------------------------------------------------------------
// searchFormToggleCE - toggle hide show search form
//---------------------------------------------------------------------------------

function searchFormToggleCE() {

        var srcRef = $('#searchregionce');
        var srcValue = $(srcRef).attr('src');

        if (srcValue.indexOf("Expanded") != -1) {
                $('#searchbuttons').fadeOut(function() {

                        $('.formlayout').slideUp();
                        $('#searchforminner').slideUp('fast');

                });
                $(srcRef).attr('src', srcValue.replace("Expanded", "Contracted"));
        } else {
                $('#searchforminner').show();
                $('.formlayout').fadeIn('slow', function() {
                        // do nothing
                });
                $('#searchbuttons').fadeIn('slow');
                $(srcRef).attr('src', srcValue.replace("Contracted", "Expanded"));
                navigateFirstItem();

        }

}

function isFormReadOnly() {
        return (uip0readonly.length > 0 && (uip0readonly.val() == "Y" || uip0readonly.val() == "R" || uip0readonly.val() == "O")
        );
}

// Defect 4363. When applied to Date fields, this function needs to additionally prevent propagation of the event to other listeners
// since otherwise the date handler function will respond. (Only the delete key seems to get through).
function textItemDisableKeysReadOnly(selector) {

        $(selector).keydown(function(event) {
                //alert(event.keyCode);
                //if ( event.keyCode==37 || event.keyCode==39 || event.keyCode==9 || event.keyCode==36 || event.keyCode==35 || (window.event.ctrlKey && window.event.keyCode == 67) )
                if (event.keyCode == 37 || event.keyCode == 39 || event.keyCode == 9 || event.keyCode == 36 || event.keyCode == 35 || (event.ctrlKey && event.keyCode == 67)) {
                        // do nothing
                } else {
                        event.preventDefault();
                        event.stopImmediatePropagation(); // Added for Defect 4363
                }
        });
}

function textItemEnableKeysReadOnly(selector) {
        $(selector).unbind('keydown');
}

function displayPageLoadTime() {
        var startTime = new Date();
        $(window).load(function() {
                var completeTime = new Date();
                var diff = completeTime - startTime;

                var bannerHtml = $('#oasysmodebanner H1').html();

                if ($('#oasysmodebanner H1').is(':visible') && bannerHtml.toLowerCase().indexOf("development") > -1) {
                        $('#oasysmodebanner').html($('#oasysmodebanner H1').html() + ' ' + '<span style="text-align:right;"> [Page Render Time : ' + diff + " ms]" + '</span>');
                }

        });
}

function configurePopupLovs() {

        // Make popuplov items readonly
        uipopuplov.attr("disabled", false);
        uipopuplov.attr("readonly", true);
        //uipopuplov.css("background-color","#f1f0f0");
        uipopuplov.addClass("input_readonly");

        // set title for popup lov items - tooltip
        $('input.popup_lov').each(function() {
                $(this).attr('title', $(this).val());

                //set title on re-focus popup lov items - tooltip
                $(this).hover(function() {
                        var thisValue = $(this).val();
                        $(this).attr('title', thisValue);
                });
        });

        // Update alt attribute for each LOV button
        var lovItemName = "";
        $("div.apex-item-group--popup-lov").each(function() {
                lovItemName = $(this).find("input:first:visible").attr("id");
                $(this).find("img:first").attr("alt", "List of values for " + $("label[for='" + lovItemName + "']").text());
                $(this).find("img:first").attr("title", "List of values for " + $("label[for='" + lovItemName + "']").text());
        });

}

var IamDone = 0;

// Defect 4628. Copied offence_code_plugin.js into this file
//              as I can't get apex_javascript.add_library in OFENCE_CODE_PLUGIN_PKB to work
// NOD-103 : amended process to take into account both fields.

// Populate the associated description for an offence (group) code or subcode item
// based on the Offence LOV plug-in item type
function getOffenceDesc
    ( pThisItemId   // The ID of the item containing the code for which description is required
    , pLevel        // 1 = group code, 2 = subcode
    , pOtherItemId  // The ID of the associated group code or subcode item
    , pAjaxId       // AJAX Identifier from plug-in
    )
{

        // Create the AJAX request and parameters, and execute it
    var ajaxRequest = new htmldb_Get(null,$v('pFlowId'),'PLUGIN='+pAjaxId,0);
    ajaxRequest.addParam('x01','GETDESC');
    ajaxRequest.addParam('x02',pLevel);
    if (1 == pLevel) // Called for offence group: just pass offence group code
    {
        ajaxRequest.addParam('x03',$v(pThisItemId));
        ajaxRequest.addParam('x04',$v(pOtherItemId));
    }
    else if (2 == pLevel) // Called for suboffence: pass offence group code and subcode
    {
        ajaxRequest.addParam('x03',$v(pOtherItemId));
        ajaxRequest.addParam('x04',$v(pThisItemId));
    }
    var gReturn = ajaxRequest.get();

    // Use the AJAX return value to populate the associated description text
    var descItem = $x('LOVDSC_'+pThisItemId);
    descItem.value = gReturn;

    if (1 == pLevel) // Changed offence group: clear dependent subcode
    {
        if ( IamDone == 0)
        {
             $s(pOtherItemId, "");
        }
    } else {
        if ( gReturn != "(unknown code)" && IamDone == 0)
        {
                IamDone = 1;
                $s(pOtherItemId,$v(pOtherItemId))
                IamDone = 0;
        }

//alert("gReturn : " + gReturn + " IamDone : " + IamDone + "  pLevel : " +  pLevel );
//alert("$v(pOtherItemId) : " + $v(pOtherItemId) + " $v(pThisItemId) : " + $v(pThisItemId) );
        if ( gReturn != "(unknown code)" &&
             IamDone == 0 &&
             ( ($v(pOtherItemId) == '' && $v(pThisItemId) == '') ||
               ($v(pOtherItemId) != '' && $v(pThisItemId) != '') ) )
//        if ( gReturn != "(unknown code)" && gReturn != "" && IamDone == 0 )
        {
                if ($("#moduleid").text() == 'ASS190') {
                        $('#P5_OFFENCE_CHANGED').val('Y');
                        appdosubmit('SAVEKB');
                }
                if ($("#moduleid").text() == 'RSR010') {
                        $('#P5_OFFENCE_CHANGED').val('Y');
                        appdosubmit('SAVEKB');
                }
        }


    }
}

// Open the Offence LOV popup window to set the specified offence (group) code and subcode
function offenceLovWindow
    ( pCodeItemId    // The Id of the offence (group) code item
    , pSubcodeItemId // The Id of the offence subcode item
    , pLevel         // 1 = group code, 2 = subcode
    , pAjaxId        // AJAX Identifier from plug-in
    )
{
        if ( ! confirm_network() ) {
            cancelEvent(event);
            return false;
        }

        if ($x(pCodeItemId).disabled || $x(pCodeItemId).readOnly) {return false;}

    // Define URL to navigate to Offence LOV window
    // NOD-103 : KB 06/07/2018 - added additional argument P2_SELECTED_OFFENCE_SUB_CODE to be passed

    var my_pSubcodeItemId =  $v(pSubcodeItemId);

    if ( !my_pSubcodeItemId ) my_pSubcodeItemId = "-1";

    var url = "f?p=EORLOV010:LOV010_LANDING:"+$v('pInstance')+":::RP,0,2:P2_CALLING_CODE_ITEM,P2_CALLING_SUBCODE_ITEM,P2_SELECTED_OFFENCE_GROUP_CODE,P2_LEVEL,P2_SELECTED_OFFENCE_SUB_CODE:"
              + pCodeItemId + "," + pSubcodeItemId + "," + $v(pCodeItemId) + "," + pLevel + "," + my_pSubcodeItemId;

    // Create an AJAX request to prepare the URL (add checksum to it)
    var ajaxRequest = new htmldb_Get(null,$v('pFlowId'),'PLUGIN='+pAjaxId,0);
    ajaxRequest.addParam('x01','PREPAREURL');
    ajaxRequest.addParam('x02',url);
    var preparedUrl = ajaxRequest.get();

    // Open the URL in a popup window
    var w = open(preparedUrl,"LOVWindow","toolbar=0,scrollbars=1,resizable=0,width=1024,height=550");
    if ( w.opener == null )
        {
            w.opener = self;
        }
    w.focus();
}
// End defect 4628



function disableRbac() {

        // Disable Fields and labels for RBAC
        if (isFormReadOnly()) {

                // alert("Form is readonly");

                uiinputs.not(":button").not(":checkbox").not(":radio").not("select").not("[data-notreadonly='false']").filter("[readonly]").attr("readonly", false);
                uiinputs.not(":button").not(":checkbox").not(":radio").not("select").not("[data-notreadonly='true']").attr("readonly", true).addClass("input_readonly");

                //uicheckbox.not("[data-notreadonly='true']").attr("disabled", true);
                // KB
                if (screenReaderUsed()) {
                        uicheckbox.not("[data-notreadonly='true']").addClass("input_disabled").attr('onclick','return false;').attr("readonly", true);
                } else{
                        uicheckbox.not("[data-notreadonly='true']").attr("disabled", true);
                }

                uiradio.not("[data-notreadonly='true']").attr("disabled", true);

                $("textarea").not("[data-notreadonly='true']").attr("readonly", true);

                uiinputs.filter("[data-notreadonly='true']").attr("readonly", false);
                uiinputs.filter("[data-notreadonly='true']").removeClass("input_readonly");

                $("table .reporthighlight").attr("class", "reportstandard");

                // Popup Lov APEX 18.2
                $('.apex-item-popup-lov-button').each(function() {
                        $(this).hide();
                        //$('#' + $(this).attr('id') + '_fieldset').find('a').hide();
                });

                // Disable NEW shuttle widgets when readonly flag set
                $("span[id^=shuttle]").find(':button:visible[id^=select]').attr("disabled", true);
                $("span[id^=shuttle]").find(':button:visible[id^=remove]').attr("disabled", true);
                $("span[id^=shuttle]").find('.selectlist').attr("disabled", true);
                $("span[id^=shuttle]").find('.selectlist').addClass("input_readonly");

                // disable default label click for select label tags
                uiselect.not("[data-notreadonly='true']").each(function() {
                        $(this).attr("disabled", true);
                });

                // Handle disabled selects
                renderDisabledSelect();

        } else {

                // Capture popup_lov items before submit snapshot
                var tmplovstr = '';

                if (uipopuplov.size() > 0) // APEX 18.2
                {
                        $('.popup_lov').each(function() {
                                popupItemsExist = true;
                                var thisId = $(this).attr('id') + '_HIDDENVALUE';
                                tmplovstr = tmplovstr + '~' + thisId + '|' + $v(thisId);
                        });

                } else {

                        $('.popup_lov').each(function() {
                                popupItemsExist = true;
                                var thisId = $(this).attr('id');
                                tmplovstr = tmplovstr + '~' + thisId + '|' + $v(thisId);
                        });

                }

                if (popupItemsExist == true) {
                        tmplovstr = tmplovstr.substr(1);
                        popupItemsValuesArr = tmplovstr.split('~');
                }
        }

        $("td.pagination span.fielddata a, td.pagination a").click(function() {
                var changesexist = $.safetynet.hasChanges() || externalEditorChanges();
                if (changesexist) {
                        alert("One or more filter criteria have changed. Please click the Search button to refresh.");
                        return false;
                }
        });

        // Handle disabled selects
        renderDisabledSelect();

        // swap readonly attribute for mimic_readonly
        if (screenReaderUsed()) {
                // Do Nothing
        } else {
                // Defect 4363. Don't exclude dates when adding class input_readonly to read only fields
                // Defect Capita 2337. Don't exclude textarea fields
                // was: uiinputs.not("textarea").not(":button").not(":checkbox").not(":radio").not("select").not("[data-notreadonly='true']").not("[data-dateitemtype='date']").filter("[readonly]").attr("data-mimic_readonly", "true");
                // was: uiinputs.not("textarea").not(":button").not(":checkbox").not(":radio").not("select").not("[data-notreadonly='true']").filter("[data-mimic_readonly='true']").attr("readonly", false);
                // was: uiinputs.not("textarea").not(":button").not(":checkbox").not(":radio").not("select").not("[data-notreadonly='true']").filter("[data-mimic_readonly='true']").addClass("input_readonly");

                uiinputs.not(":button").not(":checkbox").not(":radio").not("select").not("[data-notreadonly='true']").filter("[readonly]").attr("data-mimic_readonly", "true");
                uiinputs.not("textarea").not(":button").not(":checkbox").not(":radio").not("select").not("[data-notreadonly='true']").filter("[data-mimic_readonly='true']").attr("readonly", false);
                uiinputs.not(":button").not(":checkbox").not(":radio").not("select").not("[data-notreadonly='true']").filter("[data-mimic_readonly='true']").addClass("input_readonly");

                // MWB to apply css to data-mimic_readonly RAD QC 2269
                textItemDisableKeysReadOnly("input[data-mimic_readonly='true']");
        }

}

function customVal(itemId, pseudoSelector) {

        var itemHandle = $('#' + itemId);
        var xiItemHandle = $('#XI_' + itemId);
        var retValue = "";

        if (pseudoSelector.length > 0) {
                itemHandle = $('#' + itemId).filter(pseudoSelector);
                xiItemHandle = $('#XI_' + itemId).filter(pseudoSelector);
        }

        if (itemHandle.length > 0) {

                retValue = itemHandle.val();

        } else if (xiItemHandle.length > 0) {

                retValue = $('#' + itemId).val();
                //xiItemHandle.attr(itemId);

        }

        return retValue;

}

function customSetVal(itemId, val) {

        var itemHandle = $('#' + itemId);
        var xiItemHandle = $('#XI_' + itemId);

        if (itemHandle.length > 0) {

                itemHandle.val(val);

        }

        if (xiItemHandle.length > 0) {
                xiItemHandle.val($("#" + itemId + " option:selected").text());
        }
}

// Used in PSR Views (REP020) to check privacy when user clicks on report row to see if allowed to follow link
// (needs to be done on click as privacy check too slow to run for every row in report)
function checkPrivacyDisable() {
        if (privacy_check_data.length > 0) {
                privacy_check_data.unbind('click');
                privacy_check_data.find("td a").click(function(e) {
                        e.preventDefault();
                });
                privacy_check_data.click(function(e) {
                        checkPrivacyClick(this, e);
                });
        }
}

function checkPrivacy(offenderPk, e, nam) {

        var ajaxRequest = new htmldb_Get(null, 2000, 'APPLICATION_PROCESS=AP_OD_PRIVACY_CHECK', 0);
        var privacyCheckOk;

        ajaxRequest.addParam('x01', offenderPk);

        var ajaxResult = ajaxRequest.get();
        privacyCheckOk = ajaxResult;
        ajaxRequest = null;

        if (privacyCheckOk != 1) {
        //alert(nam);
                if (nam == 'CREATE_BCS') {
                        alert("You do not have the correct level of access to create a BCS for this offender");
                } else if (nam == 'OFF') {
                        alert("You do not have the correct level of access to this offender");
                } else {
                        alert("You do not have the correct level of access to view this offender\'s assessment");
                }
                e.preventDefault();
                e.stopImmediatePropagation();
                return false;
        }

        return true;
}
function checkPrivacyClick(row, e) {

        // Defect 2518 - do not checkPrivacy when the report header/sort buttons are clicked
        if ($(row).children().children().hasClass("rpt-sort")) { return true; }

        var offenderPk = $(row).find("td input[privacy_check_offender_id]").val();

        // Defect 4629. The check - above - on the header row was not working for Apex 5. Add this line
        if( typeof offenderPk == 'undefined' ) {return true;}

        return checkPrivacy(offenderPk, e);

}

//---------------------------------------------------------------------------------
// appevent
//---------------------------------------------------------------------------------
function appevent(e, req, msg, alertonly, privacy_check_offender_pk, nam) {

        // when called from report region disable row click
        var e = e || window.event;
        e.cancelBubble = true;
        if (e.stopPropagation) {
                e.stopPropagation()
        };

        if (privacy_check_offender_pk) {
                if (checkPrivacy(privacy_check_offender_pk, e, nam) == false) {
                        return false;
                }
        }

        if (msg != "") {
                if (alertonly) {

                        alert(msg);

                } else {

                        var conf = msg;
                        if (conf == null) {
                                conf = confirm("Would you like to perform this action?");
                        } else {
                                conf = confirm(msg);
                        }

                        if (conf == true) {
                                appdosubmit(req);
                        }

                }

        } else {
                appdosubmit(req);
        };
}

//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------
// Start up and the ready stuff
//---------------------------------------------------------------------------------
//---------------------------------------------------------------------------------

// checkgoodbrowser();
disableSpecialKeys();

//---------------------------------------------------------------------------------
// Bind Our Submit processing to Before Submit Event  - 4.2 upgrade
//---------------------------------------------------------------------------------
apex.jQuery(document).bind("apexbeforepagesubmit", function(event, pRequest) {
        bindappdosubmit(event, pRequest);
});

//---------------------------------------------------------------------------------
// Bind to handle paginate event (AT Issue)
//---------------------------------------------------------------------------------

apex.jQuery(document).on("apexafterrefresh", function(e) {
        screenReaderCorrectGridView();
//    console.log(e.type);
//    console.log(e.target);
});

//---------------------------------------------------------------------------------
//
//---------------------------------------------------------------------------------
//
    function validatedate(inputText,quNo) {
        //alert("quNo : " + quNo);

        // British Date format : range  1900 - 2099
        //var dateformat = /^(0?[1-9]|[12][0-9]|3[01])[\/](0?[1-9]|1[012])[\/](19|20)\d{2}$/;
        var dateformat = /^(0?[1-9]|[12][0-9]|3[01])[\/](0?[1-9]|1[012])[\/]\d{4}$/;

        // Match the date format through regular expression
        if (inputText.match(dateformat)) {
            // Extract the string into month, date and year
            var pdate = inputText.split('/');
            //
            var dd = parseInt(pdate[0]);
            var mm = parseInt(pdate[1]);
            var yy = parseInt(pdate[2]);

            //alert("mm : " + mm + " dd : " + dd + " yy : " + yy)
            // Create list of days of a month [assume there is no leap year by default]
            var ListofDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
            if (mm == 1 || mm > 2) {
                if (dd > ListofDays[mm - 1]) {
                    showErrorMessage(quNo +' Date of first sanction : Invalid date format');
                    return false;
                }
            }
            if (mm == 2) {
                var lyear = false;
                if ((!(yy % 4) && yy % 100) || !(yy % 400)) {
                    lyear = true;
                }
                if ((lyear == false) && (dd >= 29)) {
                    showErrorMessage(quNo +' Date of first sanction : Invalid date format');
                    return false;
                }
                if ((lyear == true) && (dd > 29)) {
                    showErrorMessage(quNo +' Date of first sanction : Invalid date format');
                    return false;
                }
            }
            return true;
        }
        else {
                    showErrorMessage(quNo +' Date of first sanction : Invalid date format');
                    return false;
        }
    }
//
    function CalculateDateDifference(Date1, Date2,quNo) {
        //
        var pdate = Date1.split('/');
        var today = Date.now();

        //
        var dd = parseInt(pdate[0]);
        var mm = parseInt(pdate[1]) - 1;
        var yy = parseInt(pdate[2]);

        var date1 = new Date(yy, mm, dd);
        var date1a = new Date(yy + 1, mm, dd);

        var pdate = Date2.split('/');
        //
        var dd = parseInt(pdate[0]);
        var mm = parseInt(pdate[1]) - 1;
        var yy = parseInt(pdate[2]);

        //
        var dt_in_three_momths = new Date(Date.now());
        dt_in_three_momths.setMonth( dt_in_three_momths.getMonth() + 3 );
        //

        var date2 = new Date(yy, mm, dd);

        if (date2 <= date1a) {
            showErrorMessage(quNo +" Date of first sanction : must be greater than the offender's DOB");
            return -1;
        } else if (date2 > dt_in_three_momths) {
            showErrorMessage(quNo +" Date of first sanction : must not be greater than 3 months in the future");
            return -1;
        }

        var result = getDateDifference(date1, date2);

        removeErrorMessage();

        return result.years;
    }
//
    function getDateDifference(startDate, endDate) {
     //   if (startDate > endDate) {
     //       console.error('Start date must be before end date');
     //       return null;
     //   }
        var startYear = startDate.getFullYear();
        var startMonth = startDate.getMonth();
        var startDay = startDate.getDate();

        var endYear = endDate.getFullYear();
        var endMonth = endDate.getMonth();
        var endDay = endDate.getDate();

        // We calculate February based on end year as it might be a leep year which might influence the number of days.
        var february = (endYear % 4 == 0 && endYear % 100 != 0) || endYear % 400 == 0 ? 29 : 28;
        var daysOfMonth = [31, february, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

        var startDateNotPassedInEndYear = (endMonth < startMonth) || endMonth == startMonth && endDay < startDay;
        var years = endYear - startYear - (startDateNotPassedInEndYear ? 1 : 0);

        var months = (12 + endMonth - startMonth - (endDay < startDay ? 1 : 0)) % 12;

        // (12 + ) % 12 makes sure index is always between 0 and 11
        var days = startDay <= endDay ? endDay - startDay : daysOfMonth[(12 + endMonth - 1) % 12] - startDay + endDay;

        return {
            years: years,
            months: months,
            days: days
        };
    }
//
    function showErrorMessage(p_message) {

        // confir message has not already been displayed
        //alert('found : #' + $('.htmldbStdErr').html() + '# p_message [' + p_message + ']' );
        if ( typeof $('.htmldbStdErr').html() === "undefined" ) {
        //alert('X');

           var i_message = '<div id="messages">';
           i_message = i_message + '<div class="javascriptG">';
           i_message = i_message + '<a class="messageclose" onclick="$x_Remove(\'messages\')" href="#"><img alt="Close Message" src="/i/delete.gif"><span style="display: none;">Close Message</span></a>';
           i_message = i_message + '<div class="error">';
           i_message = i_message + '<div class="errorimage"><!-- --></div>';
           i_message = i_message + '<div class="notification">';
           i_message = i_message + '<h1 class="hidden4jaws">Error Message Notification Section</h1>';
           i_message = i_message + '<p>Error(s) have occurred<ul class="htmldbUlErr"><li class="htmldbStdErr">' + p_message + '</li></ul><p></p>';
           i_message = i_message + '</div>';
           i_message = i_message + '</div>';
           i_message = i_message + '</div>';
           i_message = i_message + '</div>';

           $('.messages').prepend(i_message);

           showAtErrorMessageAlert();


        } else {

            if ( typeof $('.javascriptG').html() === "undefined" ) {

                var process = 0;

                $('.htmldbUlErr').find( "li" ).each(function( index ) {
                   var i_number = Number($( this ).text().substr(0,4));
                   var i_find   = Number('1.7');
                   //alert('1#' + i_number + '#');

                   if (i_number == i_find)
                   {
                        //alert('1');
                        $(this).text(p_message);
                        showAtErrorMessageAlert();
                        process = 1;
                   }

                });

                if (process != 1 ) {

                        $('.htmldbUlErr').find( "li" ).each(function( index ) {
                           var i_number = new Number($( this ).text().substr(0,4));
                           var i_find   = new Number('1.7');
                           //alert('2#' + i_number + '#');

                           if (i_number < i_find) {
                                $('<li>' + p_message + '</li>').insertBefore(this);
                                showAtErrorMessageAlert();
                                exit;
                           }

                        });

                }

            } else {
                //alert('2 $(li.htmldbStdErr).innerHTML() #' + $('li.htmldbStdErr').text() + '#');
                $('li.htmldbStdErr').text(p_message);
                showAtErrorMessageAlert();
                //alert('3');
            }

        }

    }
//
    function removeErrorMessage() {
        if ( typeof $('.javascriptG').html() === "undefined" ) {
           //
        } else {
           $('.messages').empty();
        }
    }
//---------------------------------------------------------------------------------
// Update screen for browsers NOT IE or FIREFOX
//---------------------------------------------------------------------------------
        function UpdateScreen() {

                if (is_msie == false && is_trident == false && is_firefox == false) {
                        $('input[name=text], textarea').each(
                            function(index){

                                if ( $('#moduleid').text() != 'REP050' && $('#moduleid').text() != 'DYN020') {
//console.log( " before cols " + $(this).attr("cols") );
                                        if ( $(this).attr("cols") > 113 ) $(this).attr("cols","113");
//console.log( " after cols " + $(this).attr("cols") );
                                        if ( $('#moduleid').text() == 'CMS010' ) {
                                                if ( $(this).attr("cols") == 60 ) $(this).attr("cols","55");
                                        }
                                } else {
                                        if ( $(this).attr("cols") == 100 ) $(this).attr("cols","93");
                                        if ( $(this).attr("cols") == 167 ) $(this).attr("cols","144");
                                        if ( $(this).attr("cols") == 150 ) $(this).attr("cols","144");
                                        if ( $('#moduleid').text() == 'DYN020' ) {
                                                if ( $(this).attr("cols") == 118 ) $(this).attr("cols","144");
                                        }
                                        if ( $('#moduleid').text() == 'CMS010' ) {
                                                if ( $(this).attr("cols") == 60 ) $(this).attr("cols","55");
                                        }
                                }

                                if ( $(this).attr("id") == "P0_PURPOSE_OF_SENTENCING" ) $(this).attr("cols","88");
                            }
                        );

                        if ( $('#moduleid').text() == 'DYN020' ) {
                                $("input:text").each(function() {
                                        lv_size = $(this).prop('size');
                                        if ( lv_size == 150 )
                                        {
                                                $(this).attr('size',142);
                                        }
                                });
                        }
                        if ( $('#moduleid').text() == 'OFF030' ) {
                                $("input:text").each(function() {
                                        lv_size = $(this).prop('size');
                                        if ( lv_size == 42 )
                                        {
                                                $(this).attr('size',38);
                                        }
                                        if ( lv_size == 30 )
                                        {
                                                $(this).attr('size',27);
                                        }
                                        if ( lv_size == 35 )
                                        {
                                                $(this).attr('size',30);
                                        }
                                        if ( lv_size == 145 )
                                        {
                                                $(this).attr('size',120);
                                        }
                                });
                                $("textarea").each(function() {
                                        lv_cols = $(this).prop('cols');
                                        if ( lv_cols == 47 )
                                        {
                                                $(this).attr('cols',39);
                                        }
                                        if ( lv_cols == 80 )
                                        {
                                                $(this).attr('cols',70);
                                        }
                                });
                        }

                        if ( $('#moduleid').text() == 'ASS010' ) {
                                $("input:text").each(function() {
                                        lv_size = $(this).prop('size');
                                        if ( lv_size == 30 )
                                        {
                                                $(this).attr('size',27);
                                        }
                                        if ( lv_size == 28 )
                                        {
                                                $(this).attr('size',27);
                                        }
                                });
                        }
                        if ( $('#moduleid').text() == 'PRO060' || $('#moduleid').text() == 'PRO100') {
                                $("input:text").each(function() {
                                        lv_size = $(this).prop('size');

                                        if ( lv_size == 30 )
                                        {
                                                $(this).attr('size',27);
                                        }
                                        if ( lv_size == 50 )
                                        {
                                                $(this).attr('size',43);
                                        }
                                });
                        }
                        if ( $('#moduleid').text() == 'PRO010' ) {
                                $("textarea").each(function() {
                                        lv_cols = $(this).prop('cols');
                                        if ( lv_cols == 100 )
                                        {
                                                $(this).attr('cols',82);
                                        }
                                });
                                $("#P7_PSR_CREATION_CONDS").css('width','518px');
                        }
                        if ( $('#moduleid').text() == 'OFF020' ) {
                                $("input:text").each(function() {
                                        lv_size = $(this).prop('size');

                                        if ( lv_size == 53 )
                                        {
                                                $(this).attr('size',51);
                                        }
                                });
                        }
                        if ( $('#moduleid').text() == 'CMS010' ) {
                                $("input:text").each(function() {
                                        lv_size = $(this).prop('size');

                                        if ( lv_size == 60 )
                                        {
                                                $(this).attr('size',55);
                                        }
                                });
                        }
                        if ( $('#moduleid').text() == 'TRF010' ) {
                                $("input:text").each(function() {
                                        lv_size = $(this).prop('size');

                                        if ( lv_size == 30 )
                                        {
                                                $(this).attr('size',26);
                                        }
                                });
                        }
// two areas outstanding SDR and DRUGS
                }

        }
//---------------------------------------------------------------------------------
//
//---------------------------------------------------------------------------------
        function tinymce_hlp010() {

                var MCEbuttons       = "bold italic underline | " +
                        "alignleft aligncenter alignright " +
                        "alignjustify | bullist numlist |" +
                        " indent | undo redo | spellchecker | image";

                if ( $("textarea").length == 0 ) return;

                tinymce.init(
                {
                        selector: "textarea.textarea",
                        theme : "modern",
                        mode : "exact",
                        width: 920,
                        toolbar1 : MCEbuttons,
                        toolbar2:"",
                        plugins : "autoresize,paste,legacyoutput,table,image,lists",
                        autoresize_min_height : 200,
                        autoresize_bottom_margin: 5,
                        statusbar: false,
                        extended_valid_elements: "p[*]",
                        force_br_newlines: true,
                        force_p_newlines:  false,
                        forced_root_block: '',
                        setup   : function(ed) {

                        ed.addButton('spellchecker', {
                                title : 'Spellchecker',
                                image : '/i/themes/moj_blue_theme/images/spellcheck_mce.gif',
                                onclick : function() {
                                ed.focus();
                                        var thisId = tinyMCE.activeEditor.id;
                                        spellWindow(thisId);
                                }
                        });

                        ed.addButton('autotext', {
                                title : 'Autotext',
                                image : '/i/themes/moj_blue_theme/images/autotext_mce.gif',
                                onclick : function() {
                                        ed.focus();
                                        atWindow($(this).attr("id"));
                                }
                        });
                        ed.on('keydown', function(e) {
                                $(document).idleTimer("reset");
                        });
                }
        });

        }
//---------------------------------------------------------------------------------
// Function for RSR
//---------------------------------------------------------------------------------
// Determine if 1_43 should be shown or hidden.
// ===========================================
function ShowHide_QU_1_43(call_type)
{
    if (call_type === undefined) {
    call_type = 'STATIC';
  }
    //console.log('call_type : ' + call_type);
    /*
    â€¢    1.38 is blank
    â€¢    1.38 date is in the future
    â€¢    The offender is in custody (OASYS_SET.PRISON_IND = 'C')  NOTE: this is being taken from the new field being stored on the OASYS_SET table
    â€¢    The offender's gender is NOT MALE (work this out using field GENDER_ELM on the OASYS_SET record
    â€¢    The total count for contact adult (1.34), contact child (1.35) and non-contact offences (1.37) = 0  NOTE: a blank answer or question not on screen counts as ZERO
        AND
        Date of most recent sanction involving a sexual/sexually motivated offence (1.33) is NULL  NOTE: if 1.33 is not on screen this counts as NULL
        AND
        Does the current offence involve actual/attempted contact against a victim who was a stranger? (1.42) is NOT 'Yes'  NOTE: if 1.42 is not on screen this counts as NULL

    */
//console.log( ' $(#AFTER_6_39).val() #' + $('#AFTER_6_39').val() +'#');
    if ( $('#AFTER_6_39').val() === undefined ) {
        return false;
    }
    if ( $('#AFTER_6_39').val() == 'N') {
        return false;
    }

    if ( $('#AFTER_6_49').val() === undefined ) {
        return false;
    }
/*
    if ( $('#AFTER_6_49').val() == 'N') {
        return false;
    }
*/
// 1.42 becomes 1.44 - 1.35 becomes 1.45 - 1.36 becomes 1.46 when AFTER_6_49

    var hide = false;

    if (call_type == 'DYNAMIC') {
//console.log('RIGHT');
        var lv_1_38 = $('#itm_1_38').val();
        var prison_ind = $('#P5_PRISON_IND').val();
        var gender_male = $('#P5_GENDER_MALE').val();
//console.log('gender_male #' + gender_male + '#');

        var sexually_motivated = '';
        sexually_motivated = $('#itm_1_30').children("option").filter(":selected").text().toUpperCase();
                if ( sexually_motivated == '' ) sexually_motivated = $('#itm_1_30').val().toUpperCase();
                if ( sexually_motivated == ' ' ) sexually_motivated = 'YES';

        var sexual_motivated_date = $('#itm_1_33').val();

//console.log('#itm_1_33 #' + $('#itm_1_33').html() +'#');
//console.log('sexual_motivated_date #' + sexual_motivated_date +'#');
        var contact_adult = $('#itm_1_34').val();
                if ( $('#AFTER_6_49').val() == 'N') {
             var contact_child = $('#itm_1_35').val();
                } else {
             var contact_child = $('#itm_1_45').val();
                }
        var contact_offence = $('#itm_1_37').val();
        var sexual_motivated = 'YES';
        var contact_stranger = '';

                if ($("#itm_1_41").is(":visible")){
//console.log('VISIBLE');
                sexual_motivated = $('#itm_1_41').children("option").filter(":selected").text().toUpperCase();
                                if ( sexual_motivated != 'YES' ) {
                     contact_stranger = 'NO';
                } else {
                                     if ( $('#AFTER_6_49').val() == 'N') {
                          contact_stranger = $('#itm_1_42').children("option").filter(":selected").text().toUpperCase();
                                     } else {
                          contact_stranger = $('#itm_1_44').children("option").filter(":selected").text().toUpperCase();
                                     }
                }

                } else {
//console.log('HIDDEN');
                       if ( $('#AFTER_6_49').val() == 'N') {
                    contact_stranger = $('#itm_1_42').children("option").filter(":selected").text().toUpperCase();
                       } else {
                    contact_stranger = $('#itm_1_44').children("option").filter(":selected").text().toUpperCase();
                       }
                }

//console.log('sexual_motivated #' + sexual_motivated + '#');

//console.log('contact_stranger #' + contact_stranger + '#');
     } else {
//console.log('WRONG');
        var lv_1_38 = $('#P5_QU_1_38').val();
        var prison_ind = $('#P5_PRISON_IND').val();
        var gender_male = $('#P5_GENDER_MALE').val();
        var sexually_motivated = $('#P5_QU_1_30').val();
        var sexual_motivated_date = $('#P5_QU_1_33').val();
        var contact_adult = $('#P5_QU_1_34').val();
                if ( $('#AFTER_6_49').val() == 'N') {
             var contact_child = $('#P5_QU_1_35').val();
                } else {
             var contact_child = $('#P5_QU_1_45').val();
                }
        var contact_offence = $('#P5_QU_1_37').val();
        var sexual_motivated = $('#P5_QU_1_41').val();
        if ( $('#AFTER_6_49').val() == 'N') {
             var contact_stranger = $('#P5_QU_1_42').val();
        } else {
             var contact_stranger = $('#P5_QU_1_44').val();
        }
    }

    var lv_1_38_blank = lv_1_38;
    lv_1_38_blank = lv_1_38_blank.replace(/ /g, '');
    lv_1_38_blank = lv_1_38_blank.replace(/\/\//g, '');
    var dateParts = lv_1_38.split("/");
    sexual_motivated_date = sexual_motivated_date.replace(/ /g, '');
    sexual_motivated_date = sexual_motivated_date.replace(/\/\//g, '');
    contact_adult = contact_adult.replace(/0/g, '');
    contact_child = contact_child.replace(/0/g, '');
    contact_offence = contact_offence.replace(/0/g, '');

    var date_now = new Date();
    var date_entered = '';
    try {
        date_entered = new Date(+dateParts[2], dateParts[1] - 1, +dateParts[0]);
    } catch(e){
        date_entered = date_now;
    }

    if ( sexually_motivated != 'YES' ){
//console.log('CLEAR sexually_motivated #' + sexually_motivated + '#');
         contact_adult = '';
         contact_child = '';
         contact_offence = '';
         sexual_motivated_date = '';
         contact_stranger = '';
    }

    if ( sexual_motivated != 'YES' ){
//console.log('CLEAR sexual_motivated #' + sexual_motivated + '#');
         contact_stranger = '';
    }

//  console.log(' date_now ' + date_now + ' date_entered ' + date_entered);
//  console.log(' lv_1_38 ' + lv_1_38 + ' prison_ind ' + prison_ind + ' gender_male ' + gender_male);
//  console.log(' lv_1_38_blank         #' + lv_1_38_blank + '#');
//  console.log(' contact_adult         #' + contact_adult + '#');
//  console.log(' contact_child         #' + contact_child + '#');
//  console.log(' contact_offence       #' + contact_offence + '#');
//  console.log(' sexual_motivated_date #' + sexual_motivated_date + '#');
//  console.log(' contact_stranger      #' + contact_stranger + '#');
//  console.log(' sexually_motivated    #' + sexually_motivated +'#');

    //if (lv_1_38 == '') {
    if (lv_1_38_blank == '') {
//      console.log('1');
        return false;
    } else if ( date_now < date_entered ) {
//      console.log('2');
        return false;
    } else if (prison_ind == 'C' ) {
//      console.log('3');
        return false;
    } else if (gender_male == 'N' ) {
//      console.log('4');
        return false;
    }  else if (contact_adult == '' &&  contact_child == '' && contact_offence == '' ) { //      The total count for contact adult
            //if ( sexual_motivated_date == '' && contact_stranger == '' ) {
            if ( sexual_motivated_date == '' && contact_stranger != 'YES' ) {
//              console.log('5');
                return false;
            }
    }

    return true;

}

// Determin the most recent date
// ===========================================
function get_most_recent(value1, value2)
{

//console.log('get_most_recent value1 : ' + value1 + ' value2 : ' + value2);

    if (value1 === undefined) {
        value1 = '#P5_5_YEARS';
    }
    if (value2 === undefined) {
        value2 = '#P5_QU_1_38';
    }

    var lv_5_YEARS         = $(value1).val();
    var dateParts_5_YEARS  = lv_5_YEARS.split("/");
    var lv_1_38            = $(value2).val();
    //var dateParts_1_38     = lv_1_38.split("/");
    var lv_1_38_blank      = lv_1_38;
//console.log( 'lv_5_YEARS #' + lv_5_YEARS+'#');
//console.log( 'lv_1_38_blank #' + lv_1_38_blank+'#');
if (typeof lv_1_38_blank === "undefined") {
        lv_1_38_blank = '';
}
        if ( lv_1_38_blank  != '' ) {
    lv_1_38_blank          = lv_1_38_blank.replace(/ /g, '');
    lv_1_38_blank          = lv_1_38_blank.replace(/\/\//g, '');
}
    var lv_1_38_valid_date = false;

    if ( lv_1_38_blank  != '' ) {
        try {
            var dateParts_1_38     = lv_1_38.split("/");
            date_entered_1_38    = new Date(+dateParts_1_38[2], dateParts_1_38[1] - 1, +dateParts_1_38[0]);
            date_entered_5_YEARS = new Date(+dateParts_5_YEARS[2], dateParts_5_YEARS[1] - 1, +dateParts_5_YEARS[0]);
            lv_1_38_valid_date = true;
        } catch(e){
            lv_1_38_valid_date = false;
        }
    }

    if ( lv_1_38_blank  == '' ) { //|| ( lv_1_38_valid_date == false ) {
//console.log('1');
         return lv_5_YEARS;
    } else if ( lv_1_38_valid_date == false ) {
//console.log('2');
         return lv_5_YEARS;
    } else {
         if ( date_entered_1_38 > date_entered_5_YEARS ) {
//console.log('3');
              return lv_1_38;
         } else {
//console.log('4');
              return lv_5_YEARS;
         }
    }
//console.log('5');

}
//---------------------------------------------------------------------------------
// Start Form Input Focus
//---------------------------------------------------------------------------------
$(document).ready(function() {
        try {
                // Add network check to pages with identified cascading dropdowns (CL)
                const allSelectModules = [ 'ASS010','ASS140','LOV010','OFF010','OFF020','OFF030','REP020','SPL020','TSK010','TSK020','ASS050','BCS050','BCS060','REP050','TRF010' ];
                moduleId = $('#moduleid').text();
                if ( allSelectModules.indexOf(moduleId) > -1 )
                {
                   var allSelect = document.getElementsByClassName('selectlist apex-item-select');
                   for (var i=0; i < allSelect.length; i++) {
                      allSelect[i].addEventListener('change',function(){
                         confirm_network();
                      });
                   }
                }
                // Handle Timeout
                if ('null' != sessionStorage.TimedOut)
                //if ( sessionStorage.TimedOut !== null )
                {

                        if (sessionStorage.TimedOut == 'Y')
                        {
                                // This will not close any open windows :(

                                sessionStorage.TimedOut = 'N';
                                window.location.href=sessionStorage.TimedOutURL;
                                try
                                {
                                   w.close();
                                }
                                catch(err)
                                {
                                }
                        }
                }

                // Start KB for browsers
                detectBrowser();
                UpdateScreen();
                if (moduleId == 'HLP010') tinymce_hlp010();
                // End KB for browsers

                document.oncontextmenu = function() {
                        return false;
                };

                displayPageLoadTime();

                // MWB try catch around menubar call as oasysmainmenu does not always exist (eg popup) which then prevents following functions in IE10
                try {
                        $("#oasysmainmenu").menubar();
                        //
                        // APW - to solve IE6 z-index bug where select list is displayed over menu list
                        $('.ui-menu').bgiframe();
                } catch(err) {
                }

                // Show banner
                if (uibanner) {
                        uibanner.show();
                }

                // disable browser status bar messages on url hover
                $('a').mouseover(function() {
                        window.status = "";
                        return true;
                });

                setKeys();

                // Lets find all the om objects we need
                uibanner = $('#oasysmodebanner');
                uip0readonly = $('#P0_READONLY');
                uiinputs = $('form :input');
                uicheckbox = $("form input:checkbox");
                uiradio = $("form input:radio");
                uiselect = $("form select");
                uidates = $("input[data-dateitemtype='date']");
                // use report region static id "privacy_check_data" for regions that require data check
                privacy_check_data = $("#privacy_check_data table.reporthighlight tr");

                uitextarea = uiinputs.filter("textarea");
                uitextareaexp = uitextarea.filter("[class*=expand]");

                var uileftmenu = $('#leftmenuul');

                // Set classes for radio and checkbox
                uiradio.addClass("radio");
                uicheckbox.addClass("checkbox");

                // Process left menu if present
                uileftmenu.initMenu();
                uileftmenu.show();

                // KB
                if (document.getElementById(sessionStorage.expandedMenu) != null) {
                document.getElementById(sessionStorage.expandedMenu).click(); }

                moduleId = $('#moduleid').text();

                i_ASS_ITEM_CODE = $('#ASS_ITEM_CODE').text();
                if ( i_ASS_ITEM_CODE == null)  i_ASS_ITEM_CODE = 'DUMMY';

                //const source_page = ["SEC13", "OFFENIN", "RSR", "TRN040"];
                //if ( source_page.indexOf(i_ASS_ITEM_CODE) == -1 && source_page.indexOf(moduleId) == -1 )

                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'ROSHA1' )
                {
                        $("textarea[class*=expand]").css("width","98%");
                }

                if ( moduleId == 'DYN010' && i_ASS_ITEM_CODE == 'SEC8' )
                {
                        $("textarea[class*=expand]").attr('cols', '120');
                }


                // The following has been added for the APEX 18.2 Upgrade
                if ( moduleId == 'OFFENIN' )
                {

                        uipopuplov = $("td.lov").find('input');

                        $(uipopuplov).attr('class', 'popup_lov');

                        // set popup LOV render attributes
                        if (uipopuplov.size() > 0)
                        {
                                //alert('Route 1');
                                configurePopupLovs();
                        }

                } else {

                        if ( moduleId == 'ASS030' )
                        {

                                // This code has been added as there is an issue with uipopuplov not being set to NULL for ASS030
                                // Note you cannot use the configurePopupLovs as this will break the page and the offence are not saved.
                                uipopuplov = $("td.lov").find('input');

                                $(uipopuplov).attr('class', 'popup_lov');
                                uipopuplovKB = $("input.popup_lov"); // APEX 18.2
                                uipopuplovKB.attr("disabled", false);
                                uipopuplovKB.attr("readonly", true);
                                uipopuplovKB.addClass("input_readonly");
                                // set title for popup lov items - tooltip
                                $('input.popup_lov').each(function() {
                                        $(this).attr('title', $(this).val());

                                        //set title on re-focus popup lov items - tooltip
                                        $(this).hover(function() {
                                                var thisValue = $(this).val();
                                                $(this).attr('title', thisValue);
                                        });
                                });

                                // Update alt attribute for each LOV button
                                $("div.apex-item-group--popup-lov").each(function() {
                                        lovItemName = $(this).find("input:first:visible").attr("id");
                                        $(this).find("img:first").attr("alt", "List of values for " + $("label[for='" + lovItemName + "']").text());
                                        $(this).find("img:first").attr("title", "List of values for " + $("label[for='" + lovItemName + "']").text());
                                });

                        } else {
                                uipopuplov = $("input.popup_lov"); // APEX 18.2

                                // set popup LOV render attributes APEX 18.2
                                if (uipopuplov.size() > 0 )
                                {
                                        //alert('Route 3');
                                        configurePopupLovs();
                                }
                        }


                }


                //moduleId = $('#moduleid').text();
                //i_ASS_ITEM_CODE = $('#ASS_ITEM_CODE').text();

                uiinputs_readonly = uiinputs.not(":button").not(":checkbox").not(":radio").not("select").find("[readonly]");

                uicheckbox_disabled = uicheckbox.not("[disabled='false']");
                uiradio_disabled = uiradio.not("[disabled='false']");

                uiinputs_readonly.addClass('input_readonly');
                uicheckbox_disabled.addClass('input_disabled');
                uiradio_disabled.addClass('input_disabled');

                // disable default label click for select label tags
                uiselect.each(function() {
                        var currentid = $(this).attr("id");
                        $("label[for='" + currentid + "']").click(function() {
                                return false;
                        });
                });
                // Add extra markup for screenreader
                screenReaderExtraMarkup();

                disableRbac();

                // Add extra markup for screenreader
                //screenReaderExtraMarkup();

                // Attach date mask
                attachMask("input[data-dateitemtype='date']", "99/99/9999");

                // Initialize all expanding textareas
                $("textarea[class*=expand]").TextAreaExpander();

                // Supplier Defect 4139 - maxlength fix for IE8 and older
                //if (jQuery.browser.msie && jQuery.browser.version < 9) {
                if (is_msie && jQuery.browser.version < 9) {
                        $('textarea[maxlength]').keyup(function() {
                                var text = $(this).val();
                                var limit = $(this).attr('maxlength');
                                if (text.length > limit) {
                                        $(this).val(text.substr(0, limit));
                                }
                        });
                };

                // Handle privacy check tables if they exist
                // Used in REP020 (PSR Views) so that privacy check (slow) is done on click rather than for every line in report
                // Needs to be done before activateRowHighlight so that this introduces the earlier on click event handler
                checkPrivacyDisable();

                // Activate row selector bar for APEX report regions
                activateRowHighlight();

                // Detect user changes
                $(uiinputs).safetynet();

                //Suppress default safety net messages
                $.safetynet.suppressed(true);

                //call attach item toolbar logic at end of page
                $('body').append('<script>' + 'attachTinyMCE(); try{ attachItemToolbar()} catch(err) {} ' + '</script>');

                //if validation error (not info message) displayed then ensure all inputs are set as updated to ensure changes saved.
                if ($("#messages").length > 0 && $(".errorimage").length > 0) {
                        $('input[type=text],input[type=checkbox],input[type=radio],select,textarea').each(function(index) {
                                $.safetynet.raiseChange($(this).attr("id"));
                        });
                }

                // css fix for formlayout - resort to javascript because IE6 css selector broken
                if (forcedLayoutModules(moduleId)) {
                        $('.formlayout').each(function() {
                                $(this).css("width", "100%");
                        });
                }

                if ( moduleId == 'ASS040' ) {

                        $('#P1_MESSAGE_LABEL').html($('#P1_OPD_SHOW_MESSAGE_TXT').val() );
                        $('#P1_OVERRIDE_MESSAGE_LABEL').html($('#P1_OPD_SHOW_MESSAGE_TXT').val());


                        if ( $('#P1_OPD_SHOW_MESSAGE').val() == 'N' )
                        {
                                if ( $('#P1_OPD_SHOW_SCREEN_IN').val() == 'N' )
                                {
                                        $("#P1_OPD_SCREEN_IN_OVERRIDE").parents("tr").hide();
                                        $("#P1_OPD_SCREEN_IN_OVERRIDE_REASON").parents("tr").hide();
                                }
                                if ( $('#P1_OPD_SHOW_SCREEN_OUT').val() == 'N' )
                                {
                                        $("#P1_OPD_SCREEN_OUT_OVERRIDE").parents("tr").hide();
                                        $("#P1_OPD_SCREEN_OUT_OVERRIDE_REASON").parents("tr").hide();
                                }

                                if ( $('#P1_OPD_SCREEN_IN_OVERRIDE').find(":selected").text() == 'No' )
                                {
                                        $("#P1_OPD_SCREEN_IN_OVERRIDE_REASON").parents("tr").hide();
                                }
                                if ( $('#P1_OPD_SCREEN_IN_OVERRIDE').find(":selected").text() == 'Yes' )
                                {
                                        $("#P1_OPD_SCREEN_IN_OVERRIDE_REASON").parents("tr").show();
                                }

                                if ( $('#P1_OPD_SCREEN_OUT_OVERRIDE').find(":selected").text() == 'No' )
                                {
                                        $("#P1_OPD_SCREEN_OUT_OVERRIDE_REASON").parents("tr").hide();
                                }

                                if ( $('#P1_OPD_SCREEN_OUT_OVERRIDE').find(":selected").text() == 'Yes' )
                                {
                                        $("#P1_OPD_SCREEN_OUT_OVERRIDE_REASON").parents("tr").show();
                                }
                        }

                }

                // ready to make body visible, so do it
                $('body').css('visibility', 'visible');

                // Show alert for AT users when errors have occurred
                showAtErrorMessageAlert();

                // Defect 4207. For all pop-ups, close the pop-up when the originating window
                //              closes for any reason (logouts, timeouts or change of page)
                try
                {
                  if( window.opener )
                  {
                          window.opener.addEventListener( "beforeunload", closePopUp, false );
                  }
                }
                catch (err) {}

                // Start form focus tracker
                formfocus();

                //create dummy nav item
                createFirstNavigableItem();

                // Set cursor focus to first input
                navigateFirstItem();

                // If a search report region has too many rows then call function to raise alert. The tooManyResults div and the function
                // are written by the Too Many Results plug-in region only if the there are too many results
                if ($("#tooManyResults").length > 0) {
                        tooManyResults();
                }


                // KB 01/11/2018 NOD-122
        if (screenReaderUsed() )
        {
                if (sessionStorage.at_setfocus != null)
                {

                        if ( sessionStorage.at_setfocus.indexOf('TABSET') == 0 )
                        {

                                $(this).find('a').filter('[href="javascript:appdosubmit(\'' + sessionStorage.at_setfocus + '\');"]').each( function(index) {
                                        $(this).focus();
                                });

                        }
                        // Set focus on the selected tab data

                        sessionStorage.at_setfocus = null;

                }

                // Not sure we should be doing this as none of the other screen position the cursor at the first field
                if ( moduleId == 'OFF050' )
                {
                        var blnFoundTable = false;
                        var curTable = null;
                        $("table").each( function() {
                                curTable = $(this);

                                if ( curTable.find('thead tr th').length > 0 )
                                {
                                        blnFoundTable = true;
                                        $(this).focus();
                                        return false;
                                }

                        });

                        if ( !blnFoundTable )
                        {
                                $("#P900_SURNAME").focus();
                        }
                }

        }

// KB 18/08/2020 NOD-289
// The following new field have associated help, which must be available.

        if (moduleId == 'DYN010') {

                if (!screenReaderUsed())
                {
                        $('#textarea_D1').attr("readonly", true).attr("class", "expand  input_readonly").attr("data-mimic_readonly","true");
                        $('#textarea_D2').attr("readonly", true).attr("class", "expand  input_readonly");
                        $('#textarea_D5').attr("readonly", true).attr("class", "expand  input_readonly").attr("data-mimic_readonly","true");
                        $('#textarea_D6').attr("readonly", true).attr("class", "expand  input_readonly");
                        $('#textarea_D3').attr("readonly", true).attr("class", "expand  input_readonly");
                        $('#textarea_D4').attr("readonly", true).attr("class", "expand  input_readonly");
                        $('#P5_REOFF_NEXT_2').attr("readonly", true).attr("class", "text_field input_readonly");
                }

                $('#textarea_D1_itemtoolbar').remove();
                $('#textarea_D2_itemtoolbar').remove();
                $('#textarea_D3_itemtoolbar').remove();
                $('#textarea_D4_itemtoolbar').remove();
                $('#textarea_D5_itemtoolbar').remove();
                $('#textarea_D6_itemtoolbar').remove();

        }

        if ( i_ASS_ITEM_CODE == 'OGRS3') {

                $('#itm_1_8_2').blur(function () {
                        if ( $(this).val() != '' ) {
                                if (validatedate($(this).val(),'1.8')) {
                                        var NumberOfYears = CalculateDateDifference($('#P2_OFFENDER_DOB').val(), $('#itm_1_8_2').val(),'1.8');
                                        if ( NumberOfYears > -1 ) $('#itm_1_8').val(NumberOfYears);
                                }
                        } else {
                                $('#itm_1_8').val('');
                        }
                        if (uip0readonly.length > 0 && (uip0readonly.val() == "N"))
                        {
                            // set item as changed if NOT in read-only.
                            //$.safetynet.raiseChange($('#itm_1_8'));
                            $.safetynet.raiseChange('#itm_1_8');
                        }

                });

        }

        if (moduleId == 'ASS190' || moduleId == 'RSR010') {

                $('#P5_QU_1_7_2').blur(function () {
                        if ( $(this).val() != '' ) {
                                if (validatedate($(this).val(),'1.7')) {
                                        var NumberOfYears = CalculateDateDifference($('#P5_OFFENDER_DOB').val(), $('#P5_QU_1_7_2').val(),'1.7');
                                        if ( NumberOfYears > -1 ) $('#P5_QU_1_7').val(NumberOfYears);
                                }
                        } else {
                                $('#P5_QU_1_7').val('');
                        }
                });
                $('#P5_QU_1_8_2').blur(function () {
                        if ( $(this).val() != '' ) {
                                if (validatedate($(this).val(),'1.8')) {
                                        var NumberOfYears = CalculateDateDifference($('#P5_OFFENDER_DOB').val(), $('#P5_QU_1_8_2').val(),'1.8');
                                        if ( NumberOfYears > -1 ) $('#P5_QU_1_8').val(NumberOfYears);
                                }
                        } else {
                                $('#P5_QU_1_8').val('');
                        }
                });
        }

        //
        // NOD-808 : Multiple tabs fix
        //      alert(moduleId);
        //if ( moduleId != 'SPELL' && moduleId != 'LOV010') { // to fix issue
        //      noMulTabs.detect();
        //}

UpdateScreen();
//

        } catch(err) {
                $('body').css('visibility', 'visible');
        }

        //
        // End Javascript
        //
});
