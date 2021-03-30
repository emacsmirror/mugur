;;; mugur.el --- A high-level configurator for the ErgoDox EZ keyboard -*- lexical-binding: t -*-

;; Copyright (C) 2020 Mihai Olteanu

;; Author: Mihai Olteanu <mihai_olteanu@fastmail.fm>
;; Version: 1.0
;; Package-Requires: ((emacs "26.1") (s "1.12.0") (anaphora "1.0.4"))
;; Keywords: multimedia
;; URL: https://github.com/mihaiolteanu/mugur

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Generate all the keymaps, enums, arrays, make files and everything needed for
;; building a hex file and flashing a qmk powered keyboard.  See the github
;; README for details and usage.

;;; Code:

(require 's)
(require 'anaphora)

(defgroup mugur ()
  "ErgoDox EZ keyboard configurator"
  :group 'tools
  :prefix "mugur-")

(defcustom mugur-qmk-path nil
  "Path to the qmk firmware source code."
  :type '(string :tag "path")
  :group 'mugur)

(defun mugur--qmk-keycode (key)
  "Transform the mugur `KEY' into the qmk keycode equivalent."
  (pcase key
    ;; Digits from '0' to '9'.
    ((and (pred integerp)
          (guard (<= 0 key 9)))
     (format "KC_%s" (number-to-string key)))
    
    ;; Key of the form (a) or (C-a)
    ((and (pred listp)
          (guard (= (length key) 1)))
     (mugur--qmk-keycode (car key)))

    ;; Mod Tap (https://docs.qmk.fm/#/mod_tap)
    ((and (pred listp)
          (guard (mugur--qmk-mod-tap key)))
     (mugur--qmk-mod-tap key))

    ;; Modifier Keys (https://docs.qmk.fm/#/feature_advanced_keycodes)
    ((pred mugur--qmk-modifier) (mugur--qmk-modifier key))
        
    ;; Letters from 'a' to 'z'
    ((and (pred symbolp)
          (guard (and (= (length (symbol-name key)) 1)
                      (<= ?a
                          (string-to-char (symbol-name key))
                          ?z))))
     (format "KC_%s" (upcase (symbol-name key))))

    ;; Function keys from f1 to f24.
    ((and (pred symbolp)
          (guard (s-match (rx bol
                              (or (seq "f1" digit)
                                  (seq "f2" (in "0-4"))
                                  (seq "f"  digit))                    
                              eol)
                          (symbol-name key))))
     (format "KC_%s" (upcase (symbol-name key))))

    ;; Punctuation.
    ((or 'ENT        'enter  ) "enter"      ) ;Return (Enter)
    ((or 'ESC        'escape ) "escape"     ) ;Escape
    (    'bspace               "bspace"     ) ;Delete (Backspace)
    ((or 'TAB        'tab    ) "tab"        ) ;Tab
    ((or 'SPC        'space  ) "space"      ) ;Spacebar
    (    '-                    "minus"      ) ;- and _
    (    '=                    "equal"      ) ;= and +
    ((or 'lbracket   "["     ) "lbracket"   ) ;[ and {
    ((or 'rbracket   "]"     ) "rbracket"   ) ;] and }
    ((or 'bslash     "\\"    ) "bslash"     ) ;\ and |
    (    'nonus-hash           "nonus_HASH" ) ;Non-US # and ~
    ((or 'scolon     ";"     ) "scolon"     ) ;; and :
    ((or 'quote      "'"     ) "quote"      ) ;' and
    ((or 'grave      "`"     ) "grave"      ) ;` and ~, JIS Zenkaku/Hankaku
    ((or 'comma      ","     ) "comma"      ) ;, and <
    ((or 'dot        "."     ) "dot"        ) ;. and >
    ((or 'slash      "/"     ) "slash"      ) ;/ and ?

    ;; Lock keys.
    ((or 'KLCK 'CAPS 'capslock       ) "capslock"       ) ;Caps Lock
    ((or 'SLCK 'BRMD 'scrollock      ) "scrollock"      ) ;Scroll Lock, Brightness Down (macOS)
    ((or 'NLCK       'numlock        ) "numlock"        ) ;Keypad Num Lock and Clear
    ((or 'LCAP       'locking_caps   ) "locking_caps"   ) ;Locking Caps Lock
    ((or 'LNUM       'locking_num    ) "locking_num"    ) ;Locking Num Lock
    ((or 'LSCR       'locking_scroll ) "locking_scroll" ) ;Locking Sroll Lock

    ;; Modifiers.
    ((or 'C      'LCTL   'LCTRL       ) "lctl"   ) ;Left Control
    ((or 'M      'LALT   'LOPT        ) "lalt"   ) ;Left Alt
    ((or 'S      'LSHIFT 'LSFT        ) "lsft"   ) ;Left Shift
    ((or 'G      'LGUI   'LCMD  'LWIN ) "lgui"   ) ;Left GUI (Windows/Command/Meta key)
    ((or 'RCTL   'RCTRL               ) "rctrl"  ) ;Right Control
    ((or 'RALT   'ROPT   'ALGR        ) "ralt"   ) ;Right Alt (Option/AltGr)
    ((or 'RSHIFT 'RSFT                ) "rshift" ) ;Right Shift
    ((or 'RGUI   'RCMD   'RWIN        ) "rgui"   ) ;Right GUI (Windows/Command/Meta key)

    ;; International.
    ((or 'ro 'int1) "int1")             ;JIS \ and _
    ((or 'kana 'int2) "int2")           ;JIS Katakana/Hiragana
    ((or 'jyen 'int3) "int3")           ;JIS ¥ and |
    ((or 'henk 'int4) "int4")           ;JIS Henkan
    ((or 'mhen 'int5) "int5")           ;JIS Muhenkan
    (    'int6 "int6")                  ;JIS Numpad ,
    (    'int7 "int7")                  ;International 7
    (    'int8 "int8")                  ;International 8
    (    'int9 "int9")                  ;International 9
    ((or 'lang1 'haen) "lang1")         ;Hangul/English
    ((or 'lang2 'hanj) "lang2")         ;Hanja
    (    'lang3 "lang3")                ;JIS Katakana
    (    'lang4 "lang4")                ;JIS Hiragana
    (    'lang5 "lang5")                ;JIS Zenkaku/Hankaku
    (    'lang6 "lang6")                ;Language 6
    (    'lang7 "lang7")                ;Language 7
    (    'lang8 "lang8")                ;Language 8
    (    'lang9 "lang9")                ;Language 9
    
    ;; Commands
    ((or 'PSCR        'PSCREEN             ) "pscreen"     ) ;Print Screen
    ((or 'BRK         'BRMU         'PAUSE ) "pause"       ) ;Pause, Brightness Up (macOS) 
    ((or 'INS         'INSERT              ) "insert"      ) ;Insert
    (    'HOME                               "home"        ) ;Home
    (    'PGUP                               "pgup"        ) ;Page Up
    ((or 'DEL         'DELETE              ) "delete"      ) ;Forward Delete
    (    'END                                "end"         ) ;End
    ((or 'PGDN        'PGDOWN              ) "pgdown"      ) ;Page Down
    (    'RIGHT                              "right"       ) ;Right Arrow
    (    'LEFT                               "left"        ) ;Left Arrow
    (    'DOWN                               "down"        ) ;Down Arrow
    (    'UP                                 "up"          ) ;Up Arrow
    ((or 'APP         'APPLICATION         ) "application" ) ;Application (Windows Context Menu Key)
    (    'POWER                              "power"       ) ;System Power
    ((or 'EXEC        'EXECUTE             ) "execute"     ) ;Execute
    (    'HELP                               "help"        ) ;Help
    (    'MENU                               "menu"        ) ;Menu
    ((or 'SLCT        'SELECT              ) "select"      ) ;Select
    (    'stop                               "stop"        ) ;Stop
    ((or 'AGIN        'AGAIN               ) "again"       ) ;Again
    (    'UNDO                               "undo"        ) ;Undo
    (    'CUT                                "cut"         ) ;Cut
    (    'COPY                               "copy"        ) ;Copy
    ((or 'PSTE        'PASTE               ) "paste"       ) ;Paste
    (    'FIND                               "find"        ) ;Find
    (    '_MUTE                              "_mute"       ) ;Mute
    (    '_VOLUP                             "_volup"      ) ;Volume Up
    (    '_VOLDOWN                           "_voldown"    ) ;Volume Down
    ((or 'ERAS        'ALT_ERASE           ) "alt_erase"   ) ;Aternate Erase
    (    'SYSREQ                             "sysreq"      ) ;SysReq/Attention
    (    'CANCEL                             "cancel"      ) ;Cancel
    ((or 'CLR         'CLEAR               ) "clear"       ) ;Clear
    (    'PRIOR                              "prior"       ) ;Prior
    (    'RETURN                             "return"      ) ;Return
    (    'SEPARATOR                          "separator"   ) ;Separator
    (    'OUT                                "out"         ) ;Out
    (    'OPER                               "oper"        ) ;Open
    (    'CLEAR_AGAIN                        "clear_again" ) ;Clear/Again
    (    'CRSEL                              "crsel"       ) ;CrSel/Props
    (    'EXSEL                              "exsel"       ) ;ExSel

    ;; Media Keys.
    ((or 'pwr  'system-power     ) "system_power"       ) ;System Power Down
    ((or 'slep 'system-sleep     ) "system_sleep"       ) ;System Sleep
    ((or 'wake 'system-wake      ) "system_wake"        ) ;System Wake
    ((or 'mute 'audio-mute       ) "audio_mute"         ) ;Mute
    ((or 'volu 'vol-up           ) "audio_vol_up"       ) ;Volume Up
    ((or 'vold 'vol-down         ) "audio_vol_down"     ) ;Volume Down
    ((or 'mnxt 'next-track       ) "media_next_track"   ) ;Next Track
    ((or 'mprv 'prev-track       ) "media_prev_track"   ) ;Previous Track
    ((or 'mstp 'media-stop       ) "media_stop"         ) ;Stop Track
    ((or 'mply 'media-play-pause ) "media_play_pause"   ) ;Play/Pause Track
    ((or 'msel 'media-select     ) "media_select"       ) ;Launch Media Player
    ((or 'ejct 'media-eject      ) "media_eject"        ) ;Eject
    (    'mail                     "mail"               ) ;Launch Mail
    ((or 'calc 'calculator       ) "calculator"         ) ;Launch Calculator
    ((or 'mycm 'my-computer      ) "my_computer"        ) ;Launch My Computer
    ((or 'wsch 'www-search       ) "www_search"         ) ;Browser Search
    ((or 'whom 'www-home         ) "www_home"           ) ;Browser Home
    ((or 'wbak 'www-back         ) "www_back"           ) ;Browser Back
    ((or 'wfwd 'www-forward      ) "www_forward"        ) ;Browser Forward
    ((or 'wstp 'www-stop         ) "www_stop"           ) ;Browser Stop
    ((or 'wref 'www-refresh      ) "www_refresh"        ) ;Browser Refresh
    ((or 'wfav 'www-favorites    ) "www_favorites"      ) ;Browser Favorites
    ((or 'mffd 'fast-forward     ) "media_fast_forward" ) ;Next Track
    ((or 'mrwd 'rewind           ) "media_rewind"       ) ;Previous Track
    ((or 'briu 'brigthness-up    ) "brigthness_up"      ) ;Brightness Up
    ((or 'brid 'brigthness-down  ) "brigthness_down"    ) ;Brightness Down

    ;; Number Pad.
    ((or 'psls 'kp_slash    ) "kp_slash"    ) ; Keypad /
    ((or 'past 'kp_asterisk ) "kp_asterisk" ) ; Keypad *
    ((or 'pmns 'kp_minus    ) "kp_minus"    ) ; Keypad -
    ((or 'ppls 'kp_plus     ) "kp_plus"     ) ; Keypad +
    ((or 'pent 'kp_enter    ) "kp_enter"    ) ; Enter
    ((or 'p1   'kp_1        ) "kp_1"        ) ; Keypad 1 and End
    ((or 'p2   'kp_2        ) "kp_2"        ) ; Keypad 2 and Down Arrow
    ((or 'p3   'kp_3        ) "kp_3"        ) ; Keypad 3 and Page Down
    ((or 'p4   'kp_4        ) "kp_4"        ) ; Keypad 4 and Left Arrow 
    ((or 'p5   'kp_5        ) "kp_5"        ) ; Keypad 5
    ((or 'p6   'kp_6        ) "kp_6"        ) ; Keypad 6 and Right Arrow
    ((or 'p7   'kp_7        ) "kp_7"        ) ; Keypad 7 and Home
    ((or 'p8   'kp_8        ) "kp_8"        ) ; Keypad 8 and Up Arrow
    ((or 'p9   'kp_9        ) "kp_9"        ) ; Keypad 9 and Page Up
    ((or 'p0   'kp_0        ) "kp_0"        ) ; Keypad 0 and Insert
    ((or 'pdot 'kp_dot      ) "kp_dot"      ) ; Keypad . and Delete
    ((or 'peql 'kp_equal    ) "kp_equal"    ) ; Keypad = 
    ((or 'pcmm 'kp_comma    ) "kp_comma"    ) ; Keypad ,
    ('kp_equal_as400 "kp_equal_as400"       ) ; Keypad = on AS/400 keyboards

    ;; Special Keys
    ((or 'no '---) "KC_NO")             ;Ignore this key (NOOP)
    ((or 'trns 'nil) "KC_TRANSPARENT")  ;Use the next lowest non-transparent key

    ;; Quantum Keycodes (https://docs.qmk.fm/#/quantum_keycodes)
    ('reset        "RESET")             ;Put the keyboard into bootloader mode for flashing
    ('debug        "DEBUG")             ;Toggle debug mode
    ('eeprom-reset "EEPROM_RESET")      ;Reinitializes the keyboard’s EEPROM (persistent memory)
    
    ;; Dynamic Macros (https://docs.qmk.fm/#/feature_dynamic_macros)
    ((or 'DYN_REC_START1  'DM_REC1) "KC_DYN_REC_START1") ;Start recording Macro 1
    ((or 'DYN_REC_START2  'DM_REC2) "KC_DYN_REC_START1") ;Start recording Macro 2
    ((or 'DYN_MACRO_PLAY1 'DM_PLY1) "KC_DYN_MACRO_PLAY1") ;Replay Macro 1
    ((or 'DYN_MACRO_PLAY2 'DM_PLY2) "KC_DYN_MACRO_PLAY1") ;Replay Macro 2
    ((or 'DYN_REC_STOP    'DM_RSTP) "KC_DYN_REC_STOP")       ;Finish the macro that is currently being recorded.

    ;; Grave Escape (https://docs.qmk.fm/#/feature_grave_esc)
    ((or 'gesc 'GRAVE_ESC) "KC_GESC")          ;Escape when pressed, ` when Shift or GUI are held

    ;; Leader Key (https://docs.qmk.fm/#/feature_leader_key)
    ('lead "KC_LEADER")

    ;; Macros
    ;; tbd

    ;; Mouse Keys (https://docs.qmk.fm/#/feature_mouse_keys)
    ((or 'ms_up       'ms_u) "ms_up")   ;Move cursor up
    ((or 'ms_down     'ms_d) "ms_down") ;Move cursor down
    ((or 'ms_left     'ms_l) "ms_left") ;Move cursor left
    ((or 'ms_right    'ms_r) "ms_right") ;Move cursor right
    ((or 'ms_btn1     'btn1) "ms_btn1")  ;Press button 1
    ((or 'ms_btn2     'btn2) "ms_btn2") ;Press button 2
    ((or 'ms_btn3     'btn3) "ms_btn3") ;Press button 3
    ((or 'ms_btn4     'btn4) "ms_btn4") ;Press button 4
    ((or 'ms_btn5     'btn5) "ms_btn5") ;Press button 5
    ((or 'ms_btn6     'btn6) "ms_btn6") ;Press button 6
    ((or 'ms_btn7     'btn7) "ms_btn7") ;Press button 7
    ((or 'ms_btn8     'btn8) "ms_btn8") ;Press button 8
    ((or 'ms_wh_up    'wh_u) "ms_wh_up") ;Move wheel up
    ((or 'ms_wh_down  'wh_d) "ms_wh_down") ;Move wheel down
    ((or 'ms_wh_left  'wh_l) "ms_wh_left") ;Move wheel left
    ((or 'ms_wh_right 'wh_r) "ms_wh_right") ;Move wheel right
    ((or 'ms_accel0   'acl0) "ms_accel0")   ;Set speed to 0
    ((or 'ms_accel1   'acl1) "ms_accel1")   ;Set speed to 1
    ((or 'ms_accel2   'acl2) "ms_accel2")   ;Set speed to 2
    
    ;; Space Cadet (https://docs.qmk.fm/#/feature_space_cadet)
    ('lspo   "KC_LSPO")                 ;Left Shift when held, ( when tapped
    ('rspc   "KC_RSPC")                 ;Right Shift when held, ) when tapped
    ('lcpo   "KC_LCPO")                 ;Left Control when held, ( when tapped
    ('rcpc   "KC_RCPC")                 ;Right Control when held, ) when tapped
    ('lapo   "KC_LAPO")                 ;Left Alt when held, ( when tapped
    ('rapc   "KC_RAPC")                 ;Right Alt when held, ) when tapped
    ('sftent "KC_SFTENT")               ;Right Shift when held, Enter when tapped

    ;; US ANSI Shifted Symbols (https://docs.qmk.fm/#/keycodes_us_ansi_shifted)
    ((or 'tilde '~)                     "tilde")
    ((or 'exclaim '!)                     "exclaim")
    ((or 'at '@ )                     "at")
    ((or 'hash "#")         "hash")
    ((or 'dollar '$)                     "dollar")
    ((or 'percent '%)                     "percent")
    ((or 'circumflex '^)                     "circumflex")
    ((or 'ampersand '&)                     "ampersand")
    ((or 'asterisk '*)                     "asterisk")
    ((or 'lparen "(")       "left_paren")
    ((or 'rparen ?))       "right_paren")
    ((or 'under '_)                     "underscore")
    ((or 'plus '+)                     "plus")
    ((or 'left_curly '{)                     "left_curly_brace")
    ((or 'right_curly '})                     "right_curly_brace")
    ((or 'pipe '|)                     "pipe")
    ((or 'colon ':)                     "colon")
    ((or 'double_quote "\"") "double_quote")
    ((or 'left_angle '<)                     "left_angle_bracket")
    ((or 'right_angle '>)                     "right_angle_bracket")
    ((or 'question ??)     "question")

    ;; RGB Ligthing (https://docs.qmk.fm/#/feature_rgblight)
    ('rgb_tog "rgb_tog")                ;Toggle RGB lighting on or off
    ((or 'rgb_mode_forward 'rgb_mod)           "rgb_mod") ;Cycle through modes, reverse direction when Shift is held 
    ((or 'rgb_mode_reverse 'rgb_mod)           "rgb_rmod") ;Cycle through modes in reverse, forward direction when Shift is held
    ('rgb_hui           "rgb_hui")                         ;Increase hue, decrease hue when Shift is held
    ('rgb_hud           "rgb_hud")                         ;Decrease hue, increase hue when Shift is held
    ('rgb_sai           "rgb_sai")                         ;Increase saturation, decrease saturation when Shift is held
    ('rgb_sad           "rgb_sad")                         ;Decrease saturation, increase saturation when Shift is held
    ('rgb_vai           "rgb_vai")                         ;Increase value (brightness), decrease value when Shift is held
    ('rgb_vad           "rgb_vad")                         ;Decrease value (brightness), increase value when Shift is held
    ((or 'rgb_mode_plain 'rgb_m_p)    "rgb_mode_plain") ;Static (no animation) mode
    ((or 'rgb_mode_breathe 'rgb_m_b)  "rgb_mode_breathe") ;Breathing animation mode
    ((or 'rgb_mode_rainbow 'rgb_m_r)  "rgb_mode_rainbow") ;Rainbow animation mode
    ((or 'rgb_mode_swirl 'rgb_m_sw)    "rgb_mode_swirl")   ;Swirl animation mode
    ((or 'rgb_mode_snake 'rgb_m_sn)    "rgb_mode_snake")   ;Snake animation mode
    ((or 'rgb_mode_knight 'rgb_m_k)   "rgb_mode_knight")               ;"Knight Rider" animation mode
    ((or 'rgb_mode_xmas 'rgb_m_x)     "rgb_mode_xmas")                 ;Christmas animation mode
    ((or 'rgb_mode_gradient 'rgb_m_g ) "rgb_mode_gradient")            ;Static gradient animation mode
    ((or 'rgb_mode_rgbtest 'rgb_m_t)  "rgb_mode_rgbtest")              ;Red, Green, Blue test animation mode
    
    ))

(defmemoize mugur--qmk-modifier (key)
  (aand
   (and (listp key)
        (symbolp (car key))
        (symbol-name (car key)))   
   (let ((case-fold-search nil))
     (s-match (rx bol
                  (one-or-more (or "C-" "M-" "S-" "G-"))
                  (one-or-more anything)
                  eol)
              it))
   ;; Ok, it means we have a key like '(C-M-x), for example.
   (s-split "-" (car it))
   (let ((find-key (mugur--qmk-keycode (intern (car (last it))))))
     (and find-key
          ;; Transform it to '("C" "M" "KC_X")
          (append (butlast it) (list find-key))))
   ;; qmk uses A for alt, but mugur uses the emacs M
   (substitute "A" "M" it :test #'string-equal)
   ;; Now we have '("C" "A" "KC_X"), transform it to C(A(KC_X))
   (reduce (lambda (cur total)                  
             (format "%s(%s)" total cur))
           (reverse it))))

(defun mugur--qmk-mod-tap (key)
  (and (listp key)
       (= (length (intersection (butlast key) '(C M S G)))
          (length (butlast key)))
       (let ((kc (mugur--qmk-keycode (car (last key))))
             (metas (sort (butlast key)
                          (lambda (a b) (string< (symbol-name a)
                                            (symbol-name b))))))
         (and kc
              (pcase metas
                ('(C)       (format "LCTL_T(%s)" kc)) ;Control when held, kc when tapped
                ('(G)       (format "LGUI_T(%s)" kc)) ;GUI when held, kc when tapped
                ('(M)       (format "LALT_T(%s)" kc)) ;Alt when held, kc when tapped
                ('(S)       (format "LSFT_T(%s)" kc)) ;Shift when held, kc when tapped

                ('(G S)     (format "SGUI_T(%s)" kc)) ;Shift and GUI when held, kc when tapped
                ('(C M)     (format "LCA_T(%s)"  kc)) ;Control and Alt when held, kc when tapped
                ('(M S)     (format "LSA_T(%s)"  kc)) ;Shift and Alt when held, kc when tapped
                ('(C S)     (format "RCS_T(%s)"  kc)) ;Control and Shift when held, kc when tapped

                ('(C G M)   (format "LCAG_T(%s)" kc)) ;Control, Alt and GUI when held, kc when tapped
                ('(C M S)   (format "MEH_T(%s)"  kc)) ;Control, Shift and Alt when held, kc when tapped

                ('(C G M S) (format "HYPR_T(%s)" kc)) ;Control, Shift, Alt and GUI when held, kc when tapped
                )))))


(defconst mugur--supported-keycodes
  '(("Letters and Numbers"
     (a) (b) (c) (d) (e) (f) (g) (h) (i) (j) (k) (l) (m)
     (n) (o) (p) (q) (r) (s) (t) (u) (v) (w) (x) (y) (z)
     (1) (2) (3) (4) (5) (6) (7) (8) (9) (0))
    
    ("Function Keys"
     (f1)  (f2)  (f3)  (f4)  (f5)  (f6)  (f7)  (f8)  (f9)  (f10)
     (f11) (f12) (f13) (f14) (f15) (f16) (f17) (f18) (f19) (f20)
     (f21) (f22) (f23) (f24))

    ("Punctuation"
     (ENT "enter") (enter) (ESC "escape") (escape) (bspace)
     (TAB "tab") (tab) (SPC "space") (space)
     (- "minus") (= "equal")
     (lbracket "lbracket") ("[" "lbracket")
     (rbracket "rbracket") ("]" "rbracket")
     (bslash) ("\\" "bslash")
     (nonus-hash "nonus_hash")
     (scolon "scolon") (";" "scolon") (quote) ("'" "quote")
     (grave "grave") ("`" "grave")
     (comma "comma") ("," "comma") (dot "dot") ("." "dot")
     (slash) ("/" "slash"))
    
    ("Shifted Keys"
     (~ "tilde") (! "exclaim") (@ "at")
     (hash) ("#" "hash") ($ "dollar") (% "percent")
     (^ "circumflex") (& "ampersand") (* "asterisk")
     (lparen "left_paren") (rparen "right_paren")
     ("(" "left_paren") (")" "right_paren")
     (_ "underscore") (+ "plus")
     ({ "left_curly_brace") (} "right_curly_brace")
     (| "pipe") (: "colon") ("\"" "double_quote") (double_quote)
     (< "left_angle_bracket") (> "right_angle_bracket")
     (question) ("?" "question"))
    
    ("Modifiers"
     (C "lctl") (M "lalt")
     (S "lsft") (G "lgui")
     (C-M "lca") (C-M-S "meh") (C-M-G "hypr"))

    ("Quantum Keycodes"
     (reset) (debug) (eeprom-reset "eeprom_reset"))
    
    ("Commands"
     (pscreen) (pause) (insert) (home)
     (prior "pgup") (delete) (end) (next "pgdown")
     (right) (left) (down) (up))

    ("Media Keys"
     (vol-up "audio_vol_up") (vol-down "audio_vol_down")
     (mute "audio_mute") (stop "media_stop"))

    ("Mouse Keys"
     (ms_up) (ms_down) (ms_left) (ms_right)
     (ms_btn1) (ms_btn2) (ms_btn3) (ms_btn4) (ms_btn5)
     (ms_wh_up) (ms_wh_down) (ms_wh_left) (ms_wh_right)
     (ms_accel1) (ms_accel2) (ms_accel3))

    ("RGB Lighting"
     (rgb_tog) (rgb_mod) (rgb_rmod)
     (rgb_hui) (rgb_hud) (rgb_sai) (rgb_sad) (rgb_vai) (rgb_vad)
     (rgb_mode_plain) (rgb_mode_breathe) (rgb_mode_rainbow)
     (rgb_mode_swirl) (rgb_mode_snake) (rgb_mode_knight)
     (rgb_mode_xmas) (rgb_mode_gradient) (rgb_mode_rgbtest))
    
    ("Special Keys"
     (--- "_x_") (() "___"))))

(defconst mugur--keycodes nil
  "Hash table with all the user available keycodes.
If the keycode only one has entry, then the qmk equivalent has
the same form.")

(defun mugur--keycode-string (keycode)
  "Transform the KEYCODE based on the supported keycodes."
  (if (= (length keycode) 2)
      (upcase (cadr keycode))
    (if (numberp (car keycode))
        (number-to-string (car keycode))
      (symbol-name (car keycode)))))

(defun mugur--set-keycodes ()
  "Add all the keycodes into a hashtable."
  (setf mugur--keycodes (make-hash-table :test 'equal))
  (dolist (categories mugur--supported-keycodes)
    (dolist (entry (cdr categories))
      (puthash (car entry)
               (upcase (mugur--keycode-string entry))
               mugur--keycodes))))

(defun mugur--keycode-raw (key)
  "Return the raw keycode for KEY."
  (if mugur--keycodes
      (awhen (gethash key mugur--keycodes)
        it)
    ;; First call, update the hash table.
    (mugur--set-keycodes)
    (mugur--keycode-raw key)))

(defun mugur--key-in-category-p (category key)
  "Return t if KEY is in the given CATEGORY."
  (cl-find key
           (cdr (cl-find category
                         mugur--supported-keycodes
                         :test #'string-equal :key #'car))
           :key #'car))

(defun mugur--letter-or-number-p (key)
  "Is KEY a letter or a number?"
  (mugur--key-in-category-p "Letters and Numbers" key))

(defun mugur--function-p (key)
  "Is KEY a function key, like F12?"
  (mugur--key-in-category-p "Function Keys" key))

(defun mugur--punctuation-p (key)
  "Is KEY a punctuation key?"
  (mugur--key-in-category-p "Punctuation" key))

(defun mugur--shifted-p (key)
  "Is KEY a shifted key?"
  (mugur--key-in-category-p "Shifted Keys" key))

(defun mugur--modifier-key-p (key)
  "Is KEY a modifier key, like C, M or G?"
  (mugur--key-in-category-p "Modifiers" key))

(defun mugur--quantum-p (key)
  "Is KEY a quantum key?"
  (mugur--key-in-category-p "Quantum Keycodes" key))

(defun mugur--command-p (key)
  "Is KEY a command key?"
  (mugur--key-in-category-p "Commands" key))

(defun mugur--media-p (key)
  "Is KEY a media key?"
  (mugur--key-in-category-p "Media Keys" key))

(defun mugur--mouse-p (key)
  "Is KEY a mouse key?"
  (mugur--key-in-category-p "Mouse Keys" key))

(defun mugur--rgb-p (key)
  "Is KEY an rgb key?"
  (mugur--key-in-category-p "RGB Lighting" key))

(defun mugur--special-key-p (key)
  "Is KEY one of empty or transparent keys?"
  (mugur--key-in-category-p "Special Keys" key))

(defun mugur--available-x-code-p (key)
  "Return t if KEY has an X_ entry in the send_string_keycodes."
  (or (mugur--letter-or-number-p key)
      (mugur--function-p key)
      (mugur--punctuation-p key)
      (mugur--modifier-key-p key)
      (mugur--command-p key)))

(cl-defun mugur--keycode (key &key (ss nil) (mod nil))
  "Return the KEY keycode usable in the C keymap array."
  (awhen (mugur--keycode-raw key)
    (if (or (mugur--rgb-p key)
            (mugur--special-key-p key)
            (mugur--quantum-p key))
        it
      (if (mugur--modifier-key-p key)
          (if ss
              (concat "SS_" it)
            (if mod
                (concat "MOD_" it)
              it))
        (if ss
            ;; Tap the X code, if available, or just send the string otherwise.
            (if (mugur--available-x-code-p key)
                (format "SS_TAP(X_%s)" it)
              (format "\"%s\""
                      (if (symbolp key)
                          (symbol-name key)
                        key)))
          (concat "KC_" it))))))

(cl-defun mugur--key-or-sequence (key &key (ss nil))
  "Generate simple keys or key sequences, like M-x or C-M-a.
If SS is t, generate the key sequence as needed by SEND_STRING
macros."
  (cond ((awhen (mugur--keycode key :ss ss)
           (if (mugur--modifier-key-p key)
               (concat "KC_" it)
             it)))
        ((s-contains? "-" (if (symbolp key)
                              (symbol-name key)
                            ""))
         (let* ((s (s-split "-" (symbol-name key)))
                (prefix (s-join "-" (butlast s))))
           (if (mugur--modifier-key-p (intern prefix))
               (mugur--modifier+key (intern prefix)
                                    (intern (car (last s)))
                                    :ss ss)
             nil)))
        ((and (stringp key) ss) (format "\"%s\"" key))
        (t nil)))

(defun mugur-doc-keycodes ()
  "Display all the supported keycodes in a new buffer."
  (interactive)
  (let ((b (get-buffer-create "keycodes.org")))
    (with-current-buffer b
      (org-mode)
      (erase-buffer)
      (dolist (category mugur--supported-keycodes)
        (insert (format "* %s\n\n" (car category)))
        (let ((max (cl-loop for entry in (cdr category)
                            maximize (length (mugur--keycode-string entry)))))
          (dolist (entry (cdr category))
            (insert (format (concat "\t%-" (number-to-string max)
                                    "S --> %s\n")
                            (car entry) (mugur--keycode-string entry)))))
        (insert "\n"))
      (goto-char (point-min)))
    (switch-to-buffer b)))

(defun mugur--modtap (mod key)
  "MOD when held, KEY when tapped."
  (s-format "MT($0, $1)" 'elt
            (list (mugur--keycode mod :mod t)
                  (mugur--keycode key))))

(cl-defun mugur--modifier+key (mod key &key (ss nil))
  "Hold MOD and press KEY."
  (s-format "$0($1)" 'elt
            (list (mugur--keycode mod :ss ss)
                  (if ss
                      (mugur--keycode key :ss t)
                    (mugur--keycode key)))))

(defun mugur--one-shot-mod (mod)
  "Hold down MOD for one key press only."
  (format "OSM(%s)" (mugur--keycode mod :mod t)))

(defun mugur--one-shot-layer (layer)
  "Switch to LAYER for one key press only."
  (format "OSL(%s)" (upcase (symbol-name layer))))


;;;; Macros
(cl-defstruct mugur--macro
  name expansion)

(defun mugur--macro-transform-keys (keys)
  "Asume KEYS are part of a macro and transform them."
  (mapcar (lambda (key)
       (mugur--key-or-sequence key :ss t))
     keys))

(defun mugur--macro-define (entry)
  "Prepare ENTRY for a qmk macro."
  (cl-reduce
   (lambda (item1 item2)
     (concat item1 " " item2))
   (mugur--macro-transform-keys entry)))

(defun mugur--macro (entry)
  "Create a `mugur--macro' from the ENTRY definition."
  (let ((expansion (mugur--macro-define entry)))
    (make-mugur--macro
     :name (format "SS_MACRO_%s" (upcase (md5 expansion)))
     :expansion (mugur--macro-define entry))))

(defun mugur--extract-macros (keys)
  "Extract all key definition from KEYS that look like macros."
  (cl-remove-duplicates
   (remove
    nil
    (mapcar (lambda (key)
         (let ((tr (mugur--transform-key key)))
           (if (s-contains-p "SS_MACRO_" tr)
               (mugur--macro key)
             nil)))
       keys))
   :key #'mugur--macro-name
   :test #'string-equal))


;;;; Combos
(cl-defstruct mugur--combo
  name keys expansion)

(defun mugur--combo-define (combo)
  "Define a new combo from COMBO.
A combo has two keys followed by anything that can be a key
definition."
  (let* ((keycodes (mapcar #'mugur--keycode (butlast combo)))
         (last (last combo))
         (ss (mugur--macro-transform-keys
              (if (listp (car last))
                  (car last)
                last))))
    (list keycodes ss)))

(defun mugur--combo (combo name)
  "Create a new `mugur--combo' named NAME from COMBO."
  (let ((c (mugur--combo-define combo)))
    (make-mugur--combo
     :name name
     :keys (cl-reduce (lambda (item1 item2)
                        (concat item1 ", " item2))
                      (car (butlast c)))
     :expansion (car (last c)))))


;; Tap Dance
(cl-defstruct mugur--tapdance
  name key-name key1 key2)

(defun mugur--tapdance-pp (key1 key2)
  "Does KEY1 followed by KEY2 look like a tapdance?"
  (and (and key1 key2)
       (and (not (mugur--modifier-key-p key1))
            (mugur--keycode key1))
       (and (not (mugur--modifier-key-p key2))
            (or (mugur--keycode key2)
                (symbolp key2)))
       t))

(defun mugur--tapdance (keys)
  "Create a new tapdance out of KEYS."
  (when (= (length keys) 2)
    (let ((key1 (car keys))
          (key2 (cadr keys)))
      (when (mugur--tapdance-pp key1 key2)
        (make-mugur--tapdance
         :name (format "TD_%s_%s"
                       (mugur--keycode-raw key1)
                       (or (mugur--keycode-raw key2)
                           (upcase (symbol-name key2))))
         :key-name (format "TD(TD_%s_%s)"
                           (mugur--keycode-raw key1)
                           (or (mugur--keycode-raw key2)
                               (upcase (symbol-name key2))))
         :key1 (mugur--keycode key1)
         :key2 (or (mugur--keycode key2)
                   (upcase (symbol-name key2))))))))

(defun mugur--tapdance-extract (keys)
  "Extract all tapdances from KEYS."
  (cl-remove-duplicates
   (remove nil
           (mapcar (lambda (key)
                (aif (mugur--tapdance key)
                    it
                  nil))
              keys))
   :key #'mugur--tapdance-key-name
   :test #'string-equal))


;;;; Layer Switching
(defun mugur--layer-switching-codes ()
  "Return a list of available layer switching codes."
  '(((df layer)  "Set the base (default) layer.")
    ((mo layer)  "Momentarily turn on layer when pressed (requires KC_TRNS on destination layer).")
    ((osl layer) "Momentarily activates layer until a key is pressed. See One Shot Keys for details.")
    ((tg layer)  "Toggle layer on or off.")
    ((to layer)  "Turns on layer and turns off all other layers, except the default layer.")
    ((tt layer)  "Normally acts like MO unless it's tapped multiple times, which toggles layer on.")
    ((lm layer mod) "Momentarily turn on layer (like MO) with mod active as well.")
    ((lt layer kc) "Turn on layer when held, kc when tapped")))

(defun mugur--layer-switch-p (key)
  "Is this KEY a layer switch definiton?"
  (cl-member key (mugur--layer-switching-codes)
             :key #'caar))

(defun mugur--layer-switch (action layer &optional key-or-mod)
  "Generate code to switch to the given LAYER.
ACTION is one of `mugur--layer-switching-codes', and KEY-OR-MOD
can be a normal key or a modifier."
  (if key-or-mod
      (format "%s(%s, %s)"
              (upcase (symbol-name action))
              (upcase (symbol-name layer))
              (mugur--keycode key-or-mod))
    (format "%s(%s)"
            (upcase (symbol-name action))
            (upcase (symbol-name layer)))))

(defun mugur-doc-layer-switching ()
  "Display all the layer switching codes in a new buffer."
  (interactive)
  (with-current-buffer (get-buffer-create "layer-switching-codes")
    (org-mode)
    (local-set-key (kbd "q") 'kill-current-buffer)
    (insert "* Layer Switching Codes\n\n")
    (mapc (lambda (code)
         (insert (format "%-15s - %s\n" (car code) (cadr code))))
       (mugur--layer-switching-codes))
    (switch-to-buffer (get-buffer-create "layer-switching-codes"))))


;; fns, keys definitions containing an fbound emacs symbol.  An fbound emacs
;; symbol as a key definition will be bound to one of the available keys.
(cl-defstruct mugur--fn
  kbd fn)

(defconst mugur--fns nil
  "List of key definitions containing functions.")

(defconst mugur--available-keys nil
  "List of available keys for fns functionality.")

(defun mugur--fns-reset ()
  "Prepare for another keymap definition."
  (setf mugur--fns nil)
  (setf mugur--available-keys
        '((C-f3) (C-f4) (C-f5) (C-f6) (C-f7) (C-f8)
          (C-f9) (C-f10) (C-f11) (C-f12))))

(defun mugur--fn-pp (fn)
  "Is FN a key definition for an EMACS function?"
  (and (symbolp fn)
       (fboundp fn)))

(defun mugur--fn (fn)
  "Create a new FN object.
Reduce the number of available keys if the FN is new."
  (if mugur--available-keys
      (let ((kbd (car mugur--available-keys))
            (prev-count (length mugur--fns)))
        (cl-pushnew
         (make-mugur--fn :kbd kbd :fn fn)
         mugur--fns
         :test #'equal
         :key #'mugur--fn-fn)
        (when (> (length mugur--fns)
                 prev-count)
          (setf mugur--available-keys
                (cdr mugur--available-keys)))
        (cl-find fn mugur--fns
                 :key #'mugur--fn-fn
                 :test #'equal))
    (error "No more keys available for assigning Emacs
    functions")))

(defun mugur--available-keys ()
  "Return the remaining keys available for fns."
  mugur--available-keys)

(defun mugur--fns ()
  "Return the already defined fns."
  (copy-sequence mugur--fns))

(defun mugur--keybindings (fns)
  "Bind-key all fbound symbols in FNS to their respective key.
This function only returns these `bind-key' forms as a string but
does not eval them."
  (with-temp-buffer
    (cl-dolist (fn fns)
      (insert (format "(bind-key (kbd \"<%s>\") '%s)\n"
                      (symbol-name
                       (car (mugur--fn-kbd
                           fn)))
                      (mugur--fn-fn fn))))
    (buffer-string)))

(defun mugur--create-keybindings-file (keymap)
  "Create the file holding all the `bind-key' forms for KEYMAP."
  (with-temp-file (concat (file-name-directory
                           (locate-library "mugur"))
                          "keybindings.el")
    (insert (mugur--keybindings
             (mugur--keymap-fns
              keymap)))))

(defun mugur-load-keybindings ()
  "Load the last generated keybindingd.el file."
  (interactive)
  (let ((kbds (concat (file-name-directory (locate-library "mugur"))
                      "keybindings.el")))
    (when (file-exists-p kbds)
      (load-file kbds))))

;;;; Keymaps, Layers and Transformations.
(defun mugur--transform-key (key)
  "Transform a user-supplied KEY to the qmk equivalent.
This is the workhorse of this package.  It transforms each KEY, as
supplied by the user in the `mugur-keymap' layers into an object
that can be used to generate the qmk equivalent."
  (pcase key
    (`() (mugur--keycode '()))
    ((and `(,key)
          (guard (mugur--key-or-sequence key)))
     (mugur--key-or-sequence key))
    ((and `(,fn)
          (guard (mugur--fn-pp fn)))
     (mugur--transform-key
      (mugur--fn-kbd (mugur--fn fn))))
    ((and `(,modifier ,key)
          (guard (mugur--modifier-key-p modifier)))
     (mugur--modtap modifier key))
    ((and `(,key1 ,key2)
          (guard (mugur--tapdance key)))
     (mugur--tapdance-key-name (mugur--tapdance (list key1 key2))))
    (`(osm ,mod) (mugur--one-shot-mod mod))
    (`(osl ,layer) (mugur--one-shot-layer layer))
    ((and `(,action ,layer)
          (guard (mugur--layer-switch-p action)))
     (mugur--layer-switch action layer))
    ((and `(,action ,layer ,key-or-mod)
          (guard (mugur--layer-switch-p action)))
     (mugur--layer-switch action layer key-or-mod))
    (_ (mugur--macro-name (mugur--macro key)))))

(defun mugur--transform-keys (keys)
  "Transform each key in the KEYS list."
  (mapcar #'mugur--transform-key keys))

(cl-defstruct mugur--layer
  name
  index
  keys
  leds
  orientation)

(cl-defstruct mugur--keymap
  tapping-term
  combo-term
  rgblight-enable
  rgblight-animations
  force-nkro
  layers
  combos
  macros
  tapdances
  fns)

(cl-defun mugur--new-layer (name index keys &key (leds nil) (orientation 'horizontal))
  "Create a new layer named NAME.
A layer also has an INDEX a list of KEYS, and ORIENTATION and
optional a LEDs specification which is a list of length 3
containing ones and zeroes."
  (make-mugur--layer
   :name name
   :index index
   :keys keys
   :leds leds
   :orientation orientation))

(cl-defun mugur--new-keymap (&key layers
                                  (tapping-term nil) (combo-term nil)
                                  (force-nkro t)
                                  (rgblight-enable nil) (rgblight-animations nil)
                                  (combos nil) (macros nil) (tapdances nil)
                                  (fns nil))
  "Create a new keymap with NAME, KEYBOARD type and LAYERS."
  (make-mugur--keymap
   :tapping-term tapping-term
   :combo-term combo-term
   :rgblight-enable rgblight-enable
   :rgblight-animations rgblight-animations
   :force-nkro force-nkro
   :layers layers
   :combos combos
   :macros macros
   :tapdances tapdances
   :fns fns))

(defconst mugur--keymap nil
  "The user defined keymaps.")

(defun mugur--keymap ()
  "Return the user defined keymap."
  mugur--keymap)

(defun mugur--keymap-set (keymap)
  "Remember the KEYMAP for later use."
  (setf mugur--keymap keymap))

(defun mugur--leds (layer)
  "Extract the leds specification from LAYER.
The leds specification can be given as a second or third argument
in every layer.  If no leds specification exists, return nil."
  (if (> (length layer) 2)
      (if (and (listp (cadr layer))
               (= (length (cadr layer)) 3))
          (cadr layer)
        (if (and (listp (caddr layer))
                 (= (length (caddr layer)) 3))
            (caddr layer)
          nil))))

(defun mugur--orientation (layer)
  "Return the LAYER orientaton.
The orientation can optionally be given in every layer as a
second or third argument."
  (if (> (length layer) 2)
      (if (symbolp (cadr layer))
          (cadr layer)
        (if (symbolp (caddr layer))
            (caddr layer)
          nil))))

(defun mugur--keys (layer)
  "Return the keys list for this LAYER."
  (car (last layer)))

(defun mugur--replace-custom-keys (custom-keys keys)
  "Replace all entries from CUSTOM-KEYS in KEYS."
  (if custom-keys
      (let ((names (mapcar #'car custom-keys)))
        (mapcar (lambda (key)
             (if (member (car key) names)
                 (cadr (cl-find (car key) custom-keys :key #'car))
               key))
           keys))
    ;; Nothing to replace.
    keys))

;;;###autoload
(cl-defun mugur-keymap (&key (tapping-term 180)
                             (combo-term 100)
                             (rgblight-enable nil)
                             (rgblight-animations nil)
                             (force-nkro t)
                             (layers nil)
                             (combos nil)
                             (with-keys nil))
  "Define a qmk keymap named NAME for keyboard KEYBOARD."
  ;; Prepare for any mugur-key specifying emacs functions.
  (mugur--fns-reset)
  (mugur--keymap-set
   (mugur--new-keymap
    :tapping-term tapping-term
    :combo-term combo-term
    :rgblight-enable rgblight-enable
    :rgblight-animations rgblight-animations
    :force-nkro force-nkro
    :layers
    (let ((index 0))
      (mapcar (lambda (layer)
           (let ((name (car layer))
                 (leds (mugur--leds layer))
                 (keys (mugur--keys layer))
                 (orientation (mugur--orientation layer)))
             (setf index (+ 1 index))
             (mugur--new-layer (upcase name) index
                               (mugur--transform-keys
                                (mugur--replace-custom-keys with-keys keys))
                               :leds leds
                               :orientation orientation)))
         layers))
    
    :combos
    (let ((index 0))
      (mapcar (lambda (combo)
           (setf index (+ 1 index))
           (mugur--combo combo (format "COMBO_%s" index)))
         combos))

    :macros
    (cl-remove-duplicates
     (apply #'append
            (mapcar (lambda (layer)
                 (mugur--extract-macros
                  (mugur--replace-custom-keys
                   with-keys (mugur--keys layer))))
               layers))
     :key #'mugur--macro-name
     :test #'string-equal)

    :tapdances
    (cl-remove-duplicates
     (apply #'append
            (mapcar (lambda (layer)
                 (mugur--tapdance-extract
                  (mugur--replace-custom-keys
                   with-keys (mugur--keys layer))))
               layers))
     :key #'mugur--tapdance-name
     :test #'string-equal)

    :fns
    (mugur--fns))))

;;;; C Code Generators
(defun mugur--c-custom-keycodes (macros)
  "Use MACROS to generate the custom_keycodes enum."
  (with-temp-buffer
    (insert "enum custom_keycodes {\n\tEPRM = SAFE_RANGE,\n")
    (cl-dolist (keycode macros)
      (insert (format "\t%s,\n"
                      (upcase (mugur--macro-name keycode)))))
    (insert "};\n\n")
    (buffer-string)))

(defun mugur--c-process-record-user (macros)
  "Use MACROS to generate the process_record_user function.
Each macro in MACROS is a switch case in this qmk function."
  (with-temp-buffer
    (insert "bool process_record_user(uint16_t keycode, keyrecord_t *record) {\n")
    (insert "\tif (record->event.pressed) {\n")
    (insert "\t\tswitch (keycode) {\n")
    (insert "\t\tcase EPRM:\n")
    (insert "\t\t\teeconfig_init();\n")
    (insert "\t\t\treturn false;\n")
    (cl-dolist (macro macros)
      (insert (format "\t\tcase %s:\n" (mugur--macro-name macro)))
      (insert (format "\t\t\tSEND_STRING(%s);\n" (mugur--macro-expansion macro)))
      (insert "\t\t\treturn false;\n"))
    (insert "\t\t}\n\t}\n\treturn true;\n}\n\n")
    (buffer-string)))

(defun mugur--c-tapdance-enum (tapdances)
  "Use TAPDANCES to generate all the tapdance enum entries."
  (with-temp-buffer
    (insert "enum {\n")
    (cl-dolist (tapdance tapdances)
      (insert (format "\t%s,\n" (mugur--tapdance-name tapdance))))
    (insert "};\n\n")
    (buffer-string)))

(defun mugur--c-tapdance-actions (tapdances)
  "Use TAPDANCES to generate the tap_dance_actions array."
  (with-temp-buffer
    (insert "qk_tap_dance_action_t tap_dance_actions[] = {\n")
    (cl-dolist (tapdance tapdances)
      (insert
       (if (s-contains-p "KC_" (mugur--tapdance-key2 tapdance))
           (format "\t[%s] = ACTION_TAP_DANCE_DOUBLE(%s, %s),\n"
                      (mugur--tapdance-name tapdance)
                      (mugur--tapdance-key1 tapdance)
                      (mugur--tapdance-key2 tapdance))
         ;; This is a layer, not a key
         (format "\t[%s] = ACTION_TAP_DANCE_LAYER_TOGGLE(%s, %s),\n"
                      (mugur--tapdance-name tapdance)
                      (mugur--tapdance-key1 tapdance)
                      (mugur--tapdance-key2 tapdance)))))
    (insert "};\n\n")
    (buffer-string)))

(defun mugur--c-combos-combo-events (combos)
  "Use COMBOS to generate the combo_event enum."
  (with-temp-buffer
    (insert "enum combo_events {\n")
    (cl-dolist (combo combos)
      (insert (format "\t%s,\n" (upcase (mugur--combo-name combo)))))
    (insert "};\n\n")
    (buffer-string)))

(defun mugur--c-combos-progmem (combos)
  "Use COMBOS to generate the progmem arrays."
  (with-temp-buffer
    (cl-dolist (combo combos)
      (insert
       (format "const uint16_t PROGMEM %s_combo[] = {%s, COMBO_END};\n"
               (mugur--combo-name combo) (mugur--combo-keys combo))))
    (insert "\n")
    (buffer-string)))

(defun mugur--c-combos-key-combos (combos)
  "Use COMBOS to generate the key_combos array."
  (with-temp-buffer
    (insert "combo_t key_combos[COMBO_COUNT] = {\n")
    (cl-dolist (combo combos)
      (insert (format "\t[%s] = COMBO_ACTION(%s_combo),\n"
                      (upcase (mugur--combo-name combo))
                      (mugur--combo-name combo))))
    (insert "};\n\n")
    (buffer-string)))

(defun mugur--c-combos-process-combo-event (combos)
  "Use COMBOS to generate the process_combo_event function."
  (with-temp-buffer
    (insert "void process_combo_event(uint8_t combo_index, bool pressed) {\n")
    (insert "\tswitch(combo_index) {\n")
    (cl-dolist (combo combos)
      (insert (format "\tcase %s:\n" (upcase (mugur--combo-name combo))))
      (insert "\t\tif (pressed) {\n")
      (insert (format "\t\t\tSEND_STRING%s;\n" (mugur--combo-expansion combo)))
      (insert "\t\t}\n")
      (insert "\t\tbreak;\n"))
    (insert "\t}\n")
    (insert "}\n\n")
    (buffer-string)))

(defun mugur--c-layer-codes (layers)
  "Use LAYERS to generate the layer_codes enum.
Each entry in the enum represents the layer name."
  (with-temp-buffer
    (let ((layers (mapcar #'mugur--layer-name layers)))
      (insert "enum layer_codes {\n")
      (cl-dolist (layer layers)
        (insert (format "\t%s,\n" layer)))
      (insert "};\n\n"))
    (buffer-string)))

(defun mugur--c-matrix-init-user ()
  "Generate the keymap.c matrix_init_user functions.
This qmk function runs just one time when the keyboard inits."
  "void matrix_init_user(void) {
#ifdef RGBLIGHT_COLOR_LAYER_0
  rgblight_setrgb(RGBLIGHT_COLOR_LAYER_0);
#endif
};

")

(defun mugur--c-layer-state-set-user (keymap)
  "Generate the keymap.c layer_state_set_user function using KEYMAP.
This qmk function runs whenever there is a layer state change."
  (with-temp-buffer
    (insert "layer_state_t layer_state_set_user(layer_state_t state) {\n")
    (insert "\tergodox_board_led_off();\n")
    (insert "\tergodox_right_led_1_off();\n")
    (insert "\tergodox_right_led_2_off();\n")
    (insert "\tergodox_right_led_3_off();\n\n")
    (insert "\tuint8_t layer = biton32(state);\n")
    (insert "\tswitch(layer) {\n")
    (cl-dolist (layer (mugur--keymap-layers keymap))
      (insert (format "\t\tcase %s:\n" (mugur--layer-name layer)))
      (awhen (mugur--layer-leds layer)
        (cl-dotimes (i (length it))
          (when (= (nth i it) 1)
            (insert (format "\t\t\tergodox_right_led_%s_on();\n" i)))))
      (insert "\t\t\tbreak;\n"))
    (insert "\t}\n")
    (insert "\treturn state;\n")
    (insert "};\n\n")
    (buffer-string)))

(defconst mugur--layout-vertical
  "
$1,  $2,  $3,  $4,  $5,  $6,  $7,
$8,  $9,  $10, $11, $12, $13, $14,
$15, $16, $17, $18, $19, $20,
$21, $22, $23, $24, $25, $26, $27,
$28, $29, $30, $31, $32,
                         $33, $34,
                              $35,
                    $36, $37, $38,

$39, $40, $41, $42, $43, $44, $45,
$46, $47, $48, $49, $50, $51, $52,
     $53, $54, $55, $56, $57, $58,
$59, $60, $61, $62, $63, $64, $65,
$66, $67, $68, $69, $70,
                         $71, $72,
                              $73,
                    $74, $75, $76")

(defconst mugur--layout-horizontal
  "
 $1,  $2,  $3,  $4,  $5,  $6,  $7,
 $15, $16, $17, $18, $19, $20, $21,
 $29, $30, $31, $32, $33, $34,
 $41, $42, $43, $44, $45, $46, $47,
 $55, $56, $57, $58, $59,
                          $65, $66,
                               $69,
                     $71, $72, $73,

 $8,  $9,  $10, $11, $12, $13, $14,
 $22, $23, $24, $25, $26, $27, $28,
      $35, $36, $37, $38, $39, $40,
 $48, $49, $50, $51, $52, $53, $54,
           $60, $61, $62, $63, $64,
                          $67, $68,
                               $70,
                     $74, $75, $76")

(defun mugur--vertical-orientation-p (layer)
  "Does this LAYER have vertical orientation?"
  (equal (mugur--layer-orientation layer)
     'vertical))

(defun mugur--c-keymaps (keymap)
  "Generate the qmk keymaps matrix based on KEYMAP.
The keymaps matrix contains all the layers and keys."
  (with-temp-buffer
    (insert "const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {\n\n")
    (insert
     (cl-reduce
      (lambda (item1 item2)
        (concat item1 ", \n\n" item2))
      (mapcar (lambda (layer)
           (s-format (format "[$0] = LAYOUT_ergodox(\n%s)"
                             (if (mugur--vertical-orientation-p layer)
                                 (s-trim mugur--layout-vertical)
                               (s-trim mugur--layout-horizontal)))
                     'elt
                     (cons (mugur--layer-name layer)
                           (mugur--layer-keys layer))))
         (mugur--keymap-layers keymap))))
    (insert "\n};\n\n\n")
    (buffer-string)))

(defun mugur--c-file-path (file)
  "Build the qmk C FILE path based on KEYMAP and KEYBOARD."
  (let ((mugur-path
         (concat (file-name-as-directory mugur-qmk-path)
                 (file-name-as-directory "keyboards/ergodox_ez/keymaps")
                 (file-name-as-directory "mugur"))))
    (unless (file-directory-p mugur-path)
      (make-directory mugur-path))
    (concat mugur-path file)))

(defun mugur--generate-keymap-file (keymap)
  "Generate the qmk keymap.c file for KEYMAP."
  (let ((layers (mugur--keymap-layers keymap))
        (macros (mugur--keymap-macros keymap))
        (tapdances (mugur--keymap-tapdances keymap))
        (combos (mugur--keymap-combos keymap)))
    (with-temp-file (mugur--c-file-path "keymap.c")
      (insert "#include QMK_KEYBOARD_H\n")
      (insert "#include \"version.h\"\n\n")
      (insert "#define ___ KC_TRNS\n")
      (insert "#define _X_ KC_NO\n\n")
      (insert (mugur--c-layer-codes layers))
      (insert (mugur--c-custom-keycodes macros))
      (when tapdances
        (insert (mugur--c-tapdance-enum tapdances))
        (insert (mugur--c-tapdance-actions tapdances)))
      (when combos
        (insert (mugur--c-combos-combo-events combos))
        (insert (mugur--c-combos-progmem combos))
        (insert (mugur--c-combos-key-combos combos))
        (insert (mugur--c-combos-process-combo-event combos)))
      (insert (mugur--c-keymaps keymap))
      (insert (mugur--c-process-record-user macros))
      (insert (mugur--c-matrix-init-user))
      (insert (mugur--c-layer-state-set-user keymap)))))

(defun mugur--generate-config-file (keymap)
  "Generate the qmk config.h file for KEYMAP."
  (with-temp-file (mugur--c-file-path "config.h")
    (insert "#undef TAPPING_TERM\n")
    (insert (format "#define TAPPING_TERM %s\n" (mugur--keymap-tapping-term keymap)))
    (insert (format "#define COMBO_TERM %s\n" (mugur--keymap-combo-term keymap)))
    (when (mugur--keymap-force-nkro keymap)
      (insert "#define FORCE_NKRO\n"))
    (unless (mugur--keymap-rgblight-animations keymap)
      (insert "#undef RGBLIGHT_ANIMATIONS\n"))
    (awhen (mugur--keymap-combos keymap)
      (insert (format "#define COMBO_COUNT %s\n"
                      (length it))))))

(defun mugur--generate-rules-file (keymap)
  "Generate the qmk rules.mk file for KEYMAP."
  (with-temp-file (mugur--c-file-path "rules.mk")
    (when (mugur--keymap-tapdances keymap)
      (insert "TAP_DANCE_ENABLE = yes\n"))
    (when (mugur--keymap-combos keymap)
      (insert "COMBO_ENABLE = yes\n"))
    (when (mugur--keymap-force-nkro keymap)
      (insert "FORCE_NKRO = yes\n"))
    (insert (format "RGBLIGHT_ENABLE = %s\n"
                    (if (mugur--keymap-rgblight-enable keymap)
                        "yes"
                      "no")))))

;;;###autoload
(defun mugur-generate (&optional keymap)
  "Generate all the qmk files for the selected KEYMAP.
The files include keymap.c, config.h and rules.mk."
  (interactive)
  (unless keymap
    (setf keymap (mugur--keymap)))
  (mugur--generate-keymap-file keymap)
  (mugur--generate-config-file keymap)
  (mugur--generate-rules-file  keymap))

;;;###autoload
(defun mugur-make (&optional keymap)
  "Call make on the selected KEYMAP.
Opens a new `compilation-mode' buffer to view the results."
  (interactive)
  (unless keymap
    (setf keymap (mugur--keymap)))
  (progn
    (let ((b (generate-new-buffer "make mykeyboard")))
      (with-current-buffer b
        (compilation-mode)
        (local-set-key (kbd "q") 'kill-current-buffer)
        (start-process "make" b "make"
                       "-C"
                       mugur-qmk-path
                       "ergodox_ez:mugur"))
      (switch-to-buffer "make mykeyboard"))))

;;;###autoload
(defun mugur-flash (&optional keymap)
  "Flash the KEYMAP."
  (interactive)
  (unless keymap
    (setf keymap (mugur--keymap)))
  (let ((hex (format "%s/.build/ergodox_ez_mugur.hex"
                     mugur-qmk-path)))
    (progn (start-process "flashing"
                          "flash mykeyboard"
                          "wally-cli"
                          hex)
           (switch-to-buffer "flash mykeyboard")))
  (mugur--create-keybindings-file keymap)
  (mugur-load-keybindings))

;;;###autoload
(defun mugur-build (&optional keymap)
  "Build the KEYMAP (generate and make)."
  (interactive)
  (unless keymap
    (setf keymap (mugur--keymap)))
  (mugur-generate keymap)
  (mugur-make keymap))

(provide 'mugur)

;;; mugur.el ends here
