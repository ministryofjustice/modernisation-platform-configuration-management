#  FMRWEB.RES is the key definition file for webforms. The syntax is:
#
#    JFN : JMN : URKS : FFN : URFD   (whitespace ignored)
#
#      JFN = Java function number
#      JMN = Java modifiers number
#     URKS = User-readable key sequence (double-quoted)
#      FFN = Forms function number
#     URFD = User-readable function description (double-quoted)
#
#  JAVA FUNCTION NUMBER
#         33 = PageUp
#         34 = PageDown
#         35 = End
#         36 = Home
#         37 = LeftArrow
#         38 = UpArrow
#         39 = RightArrow
#         40 = DownArrow
#    65 - 90 = Ctrl+A thru Ctrl+Z (These will always have the control
#              modifier explicitly included, as well as any other
#              modifiers that might be used.)
#  112 - 123 = F1 thru F12
#          9 = Tab (Ctrl+I, without the control modifier)
#         10 = Return (Ctrl+J, without the control modifier)
#
#  JAVA MODIFIERS NUMBER
#  Equal to the sum of the values for the modifier keys:
#    0 = None
#    1 = Shift
#    2 = Control
#    4 = Meta
#    8 = Alt
#
#  FORMS FUNCTION NUMBER
#  The Forms function numbers match the function numbers found in a
#  typical Forms key binding file.
#
#  USER-READABLE STRINGS 
#  The double-quoted strings appear when users click [Show Keys], and
#  are used for this purpose only. These strings can be translated as
#  needed. Note that the strings do not affect what actually happens
#  when end users press a particular key sequence.
#  

112  : 0 : "F1"             : 30 : "Help"
113  : 0 : "F2"             : 3  : "Clear Field"
114  : 0 : "F3"             : 62 : "Clear Record"
115  : 0 : "F4"		    : 69 : "Clear Block"
116  : 0 : "F5"             : 29 : "List of Values"
117  : 0 : "F6"             : 65 : "Insert Record"
118  : 0 : "F7"             : 76 : "Enter Query"
119  : 0 : "F8"             : 77 : "Perform Query"
120  : 0 : "F9"  	    : 36 : "Save"
121  : 0 : "F10"            : 81 : "Previous Workflow"
122  : 0 : "F11"            : 82 : "Next Workflow"
123  : 0 : "F12"            : 32 : "Exit"
87   : 2 : "Ctrl+W"         : 81 : "Workflow Menu"
68   : 2 : "Ctrl+D"         : 63 : "Delete Record"
69   : 2 : "Ctrl+E"         : 22 : "Edit"
72   : 2 : "Ctrl+H"         : 80 : "Count Query"
73   : 2 : "Ctrl+I"         : 65 : "Insert Record"
75   : 2 : "Ctrl+K"         : 35 : "Show Keys"
76   : 2 : "Ctrl+L"         : 29 : "List of Values"
80   : 2 : "Ctrl+P"         : 79 : "Print"
81   : 2 : "Ctrl+Q"         : 32 : "Exit"
82   : 2 : "Ctrl+R"         : 78 : "Display Error"
83   : 2 : "Ctrl+S"  	    : 36 : "Save"
84   : 2 : "Ctrl+T"         : 95 : "List Tab Pages"
83   : 8 : "Alt+S"	    : 82 : "Other Screens"
76   : 8 : "Alt+L"          : 82 : "Spell Check"
85   : 8 : "Alt+U"          : 83 : "Switch User Account"
115  : 2 : "Ctrl+F4"        : 74 : "Clear Form"
117  : 2 : "Ctrl+F6"        : 63 : "Delete Record"
33   : 2 : "Ctrl+PageUP"    : 72 : "Previous Block"
38   : 2 : "Ctrl+UpArrow"   : 72 : "Previous Block"
34   : 2 : "Ctrl+PageDown"  : 71 : "Next Block"
40   : 2 : "Ctrl+DownArrow" : 71 : "Next Block"
9    : 0 : "Tab"            : 1  : "Next Item"
114  : 1 : "Shift+F3"       : 61 : "Next Primary Key"
40   : 1 : "Shift+Down"     : 67 : "Next Record"
9    : 1 : "Shift+Tab"      : 2  : "Previous Field"
38   : 1 : "Shift+Up"       : 68 : "Previous Record"
10   : 0 : "Return"         : 27 : "Enter"
34   : 0 : "PageDown"       : 13 : "Scroll Down"
33   : 0 : "PageUp"         : 12 : "Scroll Up"
38   : 0 : "Up"             : 6  : "Up"
40   : 0 : "Down"           : 7  : "Down"
