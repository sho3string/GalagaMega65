; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Shell: User interface and core automation
;
; The intention of the Shell is to provide a uniform user interface and core
; automation for all MiSTer2MEGA65 projects.
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

                ; keep core in reset state
START_SHELL     MOVE    M2M$CSR, R0             ; keep core in reset state ..
                MOVE    M2M$CSR_RESET, @R0      ; .. and clear all other flags

                ; initialize screen library and show welcome screen:
                ; draw frame and print text
                RSUB    SCR$INIT, 1             ; retrieve VHDL generics
                RSUB    SCR$CLR, 1              ; clear screen                                
                MOVE    SCR$OSM_M_X, R8         ; retrieve frame coordinates
                MOVE    @R8, R8
                MOVE    SCR$OSM_M_Y, R9
                MOVE    @R9, R9
                MOVE    SCR$OSM_M_DX, R10
                MOVE    @R10, R10
                MOVE    SCR$OSM_M_DY, R11
                MOVE    @R11, R11
                RSUB    SCR$PRINTFRAME, 1       ; draw frame
                MOVE    M2M$RAMROM_DEV, R0      ; Device = config data
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; Selector = Welcome screen
                MOVE    M2M$CFG_WELCOME, @R0
                MOVE    M2M$RAMROM_DATA, R8     ; R8 = welcome screen string
                RSUB    SCR$PRINTSTR, 1

                ; switch on main OSM
                RSUB    SCR$OSM_M_ON, 1

                ; initialize all other libraries as late as here, so that
                ; error messages (if any) can be printed on screen because the
                ; screen is already initialized using the sequence above
                RSUB    KEYB$INIT, 1            ; keyboard library
                RSUB    HELP_MENU_INIT, 1       ; menu library                

                ; Wait for "Space to continue"
                ; TODO: The whole startup behavior of the Shell needs to be
                ; more flexible than this, see also README.md
START_SPACE     RSUB    KEYB$SCAN, 1
                RSUB    KEYB$GETKEY, 1
                CMP     M2M$KEY_SPACE, R8
                RBRA    START_SPACE, !Z         ; loop until Space was pressed

                ; Hide OSM and "un-reset" (aka start) the core
                ; SCR$OSM_OFF also connects keyboard and joysticks to the core
                RSUB    SCR$OSM_OFF, 1
                MOVE    M2M$CSR, R0
                AND     M2M$CSR_UN_RESET, @R0

                ; Main loop:
                ;
                ; The core is running and QNICE is waiting for triggers to
                ; react. Such triggers could be for example the "Help" button
                ; which is meant to open the options menu but also triggers
                ; from the core such as data requests from disk drives.
                ;
                ; The latter one could also be done via interrupts, but we
                ; will try to keep it simple in the first iteration and only
                ; increase complexity by using interrupts if neccessary.
MAIN_LOOP       RSUB    CHECK_DEBUG, 1          ; (Run/Stop+Cursor Up) + Help

                RSUB    KEYB$SCAN, 1            ; scan for single key presses
                RSUB    KEYB$GETKEY, 1

                RSUB    HELP_MENU, 1            ; check/manage help menu

                RBRA    MAIN_LOOP, 1

; ----------------------------------------------------------------------------
; Help menu / Options menu
; ----------------------------------------------------------------------------

                ; Check if Help is pressed and if yes, run the Options menu
HELP_MENU       INCRB
                CMP     M2M$KEY_HELP, R8        ; help key pressed?
                RBRA    _HLP_RET, !Z                

                ; TODO: We might want to pause/unpause the core while
                ; the Options menu is running

                ; TODO: Search for TODO ERROR MESSAGE in this file and
                ; implement error messages that are visible on screen as
                ; well as via the serial debug line

                ; TODO: Instead of using the data from config.vhd to do the
                ; initial standard selections, use persistent data from
                ; M2M$CFM_DATA. And make sure that M2M$CFM_DATA is initialized
                ; at the very beginning using HELP_MENU_INIT

                ; Copy menu items from config.vhd to heap
                MOVE    M2M$RAMROM_DEV, R0
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R0    ; R0: config selector
                MOVE    M2M$CFG_OPTM_ITEMS, @R0 ; select menu items
                MOVE    M2M$RAMROM_DATA, R8     ; copy men. items to heap
                MOVE    HEAP, R9
                ADD     OPTM_STRUCTSIZE, R9
                MOVE    R9, R1                  ; R1: points to item string
                SYSCALL(strcpy, 1)

                ; R2 = first free word behind the menu items
                MOVE    R9, R2
                MOVE    R9, R8
                SYSCALL(strlen, 1)              ; R9 = string length
                ADD     R9, R2
                ADD     1, R2                   ; zero terminator

                ; R3 = menu size
                MOVE    OPTM_ICOUNT, R3
                MOVE    @R3, R3

                ; Copy menu data structure from ROM to RAM (heap)
                MOVE    OPT_MENU_DATA, R8
                MOVE    HEAP, R9
                MOVE    OPTM_STRUCTSIZE, R10
                SYSCALL(memcpy, 1)

                ; Modify the menu data structure, so that it points to the 
                ; data from config.vhd
                MOVE    HEAP, R8                ; Set menu size
                ADD     OPTM_IR_SIZE, R8
                MOVE    R3, @R8                 ; R3: menu item counter
                MOVE    HEAP, R8                ; Set menu item string
                ADD     OPTM_IR_ITEMS, R8
                MOVE    R1, @R8                 ; R1: item string

                ; Copy the menu groups to the heap and modify the menu data
                ; structure accordingly.
                ; R2 contains the first free word on the heap behind the item
                ; string, so we will copy to that point and then increase
                ; R2 by R3 (menu item counter)
                ; R0 is used to switch the config selector
                MOVE    M2M$CFG_OPTM_GROUPS, @R0
                MOVE    M2M$RAMROM_DATA, R8
                MOVE    R2, R9                  ; R2: first free word
                ADD     R3, R2                  ; R2: next free word
                MOVE    R3, R10                 ; R3: amount of menu items
                SYSCALL(memcpy, 1)
                MOVE    HEAP, R8                ; store pointer to record
                ADD     OPTM_IR_GROUPS, R8
                MOVE    R9, @R8
                MOVE    R9, R7                  ; R7: pointer to menu groups

;;;                ; Get the standard selectors (which menu items are selcted by
;;;                ; default) from config.vhd and store them in M2M$CFM_DATA                
;;;                MOVE    M2M$CFM_ADDR, R0        ; R0: select "bank"
;;;                MOVE    0, @R0
;;;                MOVE    M2M$CFM_DATA, R1        ; R1: write data
;;;                MOVE    M2M$RAMROM_4KWIN, R2
;;;                MOVE    M2M$CFG_OPTM_STDSEL, @R2
;;;                MOVE    M2M$RAMROM_DATA, R2     ; R2: read config.vhd data
;;;                MOVE    OPTM_ICOUNT, R3         ; R3: amount of menu items
;;;                MOVE    @R3, R3
;;;                XOR     R4, R4                  ; R4: bit counter for R0
;;;                XOR     R5, R5                  ; R5: bit pattern
;;;
;;;_HLP_S1         MOVE    @R2++, R6               ; get bit from config.vhd
;;;                AND     0xFFFD, SR              ; clear X
;;;                SHL     R4, R6                  ; shift bit to correct pos.
;;;                OR      R6, R5                  ; R5: target pattern
;;;                ADD     1, R4                   ; next bit
;;;                CMP     16, R4                  ; next bank for M2M$CFM_ADDR?
;;;                RBRA    _HLP_S2, !Z             ; no: check if done
;;;                MOVE    R5, @R1                 ; store bit pattern in ..CFM..
;;;                XOR     R4, R4                  ; reset bit pattern counter
;;;                XOR     R5, R5                  ; reset bit pattern
;;;                ADD     1, @R0                  ; next "bank"
;;;_HLP_S2         SUB     1, R3                   ; one less menu item to go

;;;==> comment this out ...
                ; Copy the standard selectors (which menu items are selected
                ; by default) and modify the menu data structure
                MOVE    M2M$CFG_OPTM_STDSEL, @R0
                MOVE    M2M$RAMROM_DATA, R8
                MOVE    R2, R9                  ; R9: free word behind groups
                ADD     R3, R2                  ; R2: free wrd beh. selectors
                MOVE    R3, R10                 ; R10: menu items counter
                SYSCALL(memcpy, 1)
                MOVE    HEAP, R8
                ADD     OPTM_IR_STDSEL, R8
                MOVE    R9, @R8

                ; Copy the standard selectors (which menu items are selected
                ; by default) from the QNICE M2M$CFM_DATA register to the
                ; heap and modify the menu data structure accordingly
;;;==> ... and continue here

                ; Copy positions of separator lines & modify men. dta. struct.
                MOVE    M2M$CFG_OPTM_LINES, @R0
                MOVE    M2M$RAMROM_DATA, R8
                MOVE    R2, R9                  ; R9: free word beh. selectors
                MOVE    R3, R10                 ; R10: menu items counter
                SYSCALL(memcpy, 1)
                MOVE    HEAP, R8
                ADD     OPTM_IR_LINES, R8
                MOVE    R9, @R8

                ; run the menu
                RSUB    OPTM_SHOW, 1            ; fill VRAM
                RSUB    SCR$OSM_O_ON, 1         ; make overlay visible
                MOVE    OPTM_SELECTED, R9       ; use recently selected line
                MOVE    @R9, R8
                RSUB    OPTM_RUN, 1             ; run menu
                RSUB    SCR$OSM_OFF, 1          ; make overlay invisible

                ; Smart handling of last-recently-selected: only remember
                ; LRS when the menu is closed via pressing the Help key again.
                ; Otherwise (when using "Close Menu" or something like this),
                ; restart from the default start position
                MOVE    R7, R10
                ADD     R8, R10
                CMP     OPTM_CLOSE, @R10
                RBRA    _HLP_RESETPOS, Z
                MOVE    R8, @R9                 ; remember recently sel. line
                RBRA    _HLP_RET, 1
_HLP_RESETPOS   MOVE    OPTM_START, R0
                MOVE    @R0, @R9

_HLP_RET        DECRB
                RET

                ; init/configure the menu library
HELP_MENU_INIT  SYSCALL(enter, 1)

                MOVE    HEAP, R8
                MOVE    SCR$OSM_O_X, R9
                MOVE    @R9, R9
                MOVE    SCR$OSM_O_Y, R10
                MOVE    @R10, R10
                MOVE    SCR$OSM_O_DX, R11
                MOVE    @R11, R11
                MOVE    SCR$OSM_O_DY, R12
                MOVE    @R12, R12
                RSUB    OPTM_INIT, 1

                ; extract the amount of menu items (including empty lines and
                ; headlines) from config.vhd
                MOVE    M2M$RAMROM_DEV, R0      ; Device=config.vhd
                MOVE    M2M$CONFIG, @R0
                MOVE    M2M$RAMROM_4KWIN, R1    ; Selector=amount of items
                MOVE    M2M$CFG_OPTM_ICOUNT, @R1
                MOVE    M2M$RAMROM_DATA, R0
                MOVE    @R0, R7                 ; R7=amount of items
                MOVE    OPTM_ICOUNT, R0
                MOVE    R7, @R0

                ; check, if menu size in config.vhd is between 1 and 254
                MOVE    1, R9
                MOVE    R7, R8
                MOVE    255, R10
                SYSCALL(in_range_u, 1)          ; R9 <= R8 < R10?
                RBRA    _HLP_ITEM, C           ; yes: search start item
                MOVE    ERR_F_MENUSIZE, R8      ; no: fatal error and end
                RBRA    FATAL, 1

                ; extract the initially selected item from config.vhd
_HLP_ITEM       XOR     R0, R0                  ; R1=position of start item
                MOVE    M2M$CFG_OPTM_START, @R1 ; Selector=start flag
                MOVE    M2M$RAMROM_DATA, R2
_HLP_SEARCH     CMP     R0, R7
                RBRA    _HLP_ERROR, Z
                CMP     @R2++, 0
                RBRA    _HLP_START, !Z
                ADD     1, R0
                RBRA    _HLP_SEARCH, 1

                ; No start flag found
_HLP_ERROR      MOVE    ERR_F_MENUSTART, R8
                RBRA    FATAL, 1

                ; store initially selected item (start flag)
_HLP_START      MOVE    OPTM_START, R8
                MOVE    OPTM_SELECTED, R9
                MOVE    R0, @R8
                MOVE    R0, @R9

                ; Get the standard selectors (which menu items are selcted by
                ; default) from config.vhd and store them in M2M$CFM_DATA                
                MOVE    M2M$CFM_ADDR, R0        ; R0: select "bank"
                MOVE    M2M$CFM_DATA, R1        ; R1: write data
                MOVE    1, @R0
                MOVE    0, @R1
                MOVE    0, @R0
                MOVE    0, @R1
                MOVE    M2M$RAMROM_4KWIN, R2
                MOVE    M2M$CFG_OPTM_STDSEL, @R2
                MOVE    M2M$RAMROM_DATA, R2     ; R2: read config.vhd data
                MOVE    OPTM_ICOUNT, R3         ; R3: amount of menu items
                MOVE    @R3, R3
                XOR     R4, R4                  ; R4: bit counter for R0
                XOR     R5, R5                  ; R5: bit pattern

_HLP_S1         MOVE    @R2++, R6               ; get bit from config.vhd
                AND     0xFFFD, SR              ; clear X
                SHL     R4, R6                  ; shift bit to correct pos.
                OR      R6, R5                  ; R5: target pattern
                ADD     1, R4                   ; next bit
                CMP     16, R4                  ; next bank for M2M$CFM_ADDR?
                RBRA    _HLP_S2, !Z             ; no: check if done
                MOVE    R5, @R1                 ; store bit pattern in ..CFM..
                XOR     R4, R4                  ; reset bit pattern counter
                XOR     R5, R5                  ; reset bit pattern
                ADD     1, @R0                  ; next "bank"
_HLP_S2         SUB     1, R3                   ; one less menu item to go
                RBRA    _HLP_S1, !Z
                CMP     0, R4                   ; something to write to @R1?
                RBRA    _HLP_S3, Z              ; no: do not destroy @R1
                MOVE    R5, @R1                 ; yes: update @R1

_HLP_S3         SYSCALL(leave, 1)
                RET

; Menu initialization record (needed by OPTM_INIT)
; Will be copied to the HEAP, together with the configuration data from
; config.vhd and then modified to point to the right addresses on the heap
OPT_MENU_DATA   .DW     SCR$CLR, SCR$PRINTFRAME, SCR$PRINTSTR, SCR$PRINTSTRXY
                .DW     OPT_PRINTLINE, OPTM_SELECT, OPT_MENU_GETKEY
                .DW     OPTM_CALLBACK,
                .DW     M2M$OPT_SEL, 0          ; selection char + zero term.
                .DW     0, 0, 0, 0, 0           ; will be filled dynamically

; Draws a horizontal line/menu separator at the y-pos given in R8, dx in R9
OPT_PRINTLINE   INCRB

                MOVE    SP, R0                  ; R0: use to restore stack
                MOVE    R8, R1                  ; R1: y-pos
                MOVE    OPTM_DX, R2             ; R2: width minus left/right..
                MOVE    @R2, R2                 ; ..boundary
                SUB     2, R2                   

                SUB     R2, SP                  ; memory for string
                SUB     3, SP                   ; 3: l/r boundary + zero term.
                MOVE    SP, R3
                MOVE    R3, R4                  ; remember for printing

                MOVE    M2M$NC_VE_LEFT, @R3++                
_PRINTLN_L      MOVE    M2M$NC_SH, @R3++
                SUB     1, R2
                RBRA    _PRINTLN_L, !Z
                MOVE    M2M$NC_VE_RIGHT, @R3++
                MOVE    0, @R3

                MOVE    R4, R8
                MOVE    OPTM_X, R9
                MOVE    @R9, R9
                MOVE    R1, R10
                RSUB    SCR$PRINTSTRXY, 1                

                MOVE    R0, SP
                DECRB
                RET

; Selects/unselects menu item in R8 (counting from 0 and counting also
; non-selectable menu entries such as lines)
; R9=0: unselect   R9=1: select
OPTM_SELECT     INCRB

                MOVE    OPTM_X, R0              ; R0: x start coordinate
                MOVE    @R0, R0
                ADD     1, R0
                MOVE    OPTM_Y, R1              ; R1: y start coordinate
                MOVE    @R1, R1
                ADD     1, R1
                ADD     R8, R1
                MOVE    OPTM_DX, R2             ; R2: width of selection
                MOVE    @R2, R2
                SUB     2, R2

                CMP     R9, 0                   ; R3: attribute to apply
                RBRA    _OPTM_FPS_1, Z
                MOVE    M2M$SA_COL_STD_INV, R3
                RBRA    _OPTM_FPS_2, 1
_OPTM_FPS_1     MOVE    M2M$SA_COL_STD, R3

_OPTM_FPS_2     MOVE    SCR$SYS_DX, R8          ; R10: start address in ..
                MOVE    @R8, R8
                MOVE    R1, R9                  ; .. attribute VRAM
                SYSCALL(mulu, 1)
                ADD     R0, R10
                ADD     M2M$RAMROM_DATA, R10

                MOVE    M2M$RAMROM_DEV, R4      ; switch to ATTR data, win 0
                MOVE    M2M$VRAM_ATTR, @R4
                MOVE    M2M$RAMROM_4KWIN, R4
                MOVE    0, @R4

                XOR     R4, R4
_OPTM_FPS_L     CMP     R2, R4
                RBRA    _OPTM_FPS_RET, Z
                MOVE    R3, @R10++
                ADD     1, R4
                RBRA    _OPTM_FPS_L, 1

_OPTM_FPS_RET   DECRB
                RET                

; Waits until one of the four Option Menu keys is pressed
; and returns the OPTM_KEY_* code in R8
OPT_MENU_GETKEY INCRB
_OPTMGK_LOOP    RSUB    KEYB$SCAN, 1            ; wait until key is pressed
                RSUB    KEYB$GETKEY, 1
                CMP     0, R8
                RBRA    _OPTMGK_LOOP, Z

                CMP     M2M$KEY_UP, R8          ; up
                RBRA    _OPTM_GK_1, !Z
                MOVE    OPTM_KEY_UP, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_1      CMP     M2M$KEY_DOWN, R8        ; down
                RBRA    _OPTM_GK_2, !Z
                MOVE    OPTM_KEY_DOWN, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_2      CMP     M2M$KEY_RETURN, R8      ; return (select)
                RBRA    _OPTM_GK_3, !Z
                MOVE    OPTM_KEY_SELECT, R8
                RBRA    _OPTMGK_RET, 1

_OPTM_GK_3      CMP     M2M$KEY_HELP, R8        ; help (close menu)
                RBRA    _OPTMGK_LOOP, !Z        ; other key: ignore
                MOVE    OPTM_KEY_CLOSE, R8

_OPTMGK_RET     DECRB
                RET

; Callback function that is called during the execution of the menu (OPTM_RUN)
; R8: selected menu group (as defined in OPTM_IR_GROUPS)
; R9: selected item within menu group
;     in case of single selected items: 0=not selected, 1=selected
OPTM_CALLBACK   RET         

; ----------------------------------------------------------------------------
; Debug mode:
; Hold "Run/Stop" + "Cursor Up" and then while holding these, press "Help"
; ----------------------------------------------------------------------------

                ; Debug mode: Exits the main loop and starts the QNICE
                ; Monitor which can be used to debug via UART and a
                ; terminal program. You can return to the Shell by using
                ; the Monitor C/R command while entering the start address
                ; that is shown in the terminal (using the "puthex" below).
CHECK_DEBUG     INCRB
                MOVE    M2M$KEY_UP, R0
                OR      M2M$KEY_RUNSTOP, R0
                OR      M2M$KEY_HELP, R0
                MOVE    M2M$KEYBOARD, R1        ; read keyboard status
                MOVE    @R1, R2
                NOT     R2, R2                  ; convert low active to hi
                AND     R0, R2
                CMP     R0, R2                  ; key combi pressed?
                DECRB
                RBRA    START_MONITOR, Z        ; yes: enter debug mode
                RET                             ; no: return to main loop
                
START_MONITOR   MOVE    DBG_START1, R8          ; print info message via UART
                SYSCALL(puts, 1)
                MOVE    START_SHELL, R8         ; show how to return to ..
                SYSCALL(puthex, 1)              ; .. the shell
                MOVE    DBG_START2, R8
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)                ; small/irrelevant stack leak

; ----------------------------------------------------------------------------
; Fatal error:
; Output message to the screen and to the serial terminal and then quit.
; R8: Pointer to error message from strings.asm
; ----------------------------------------------------------------------------

FATAL           MOVE    R8, R0
                RSUB    SCR$CLR, 1
                MOVE    1, R8
                MOVE    1, R9
                RSUB    SCR$GOTOXY, 1
                MOVE    ERR_FATAL, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(puts, 1)
                MOVE    R0, R8
                RSUB    SCR$PRINTSTR, 1
                SYSCALL(puts, 1)
                SYSCALL(exit, 1)

; ----------------------------------------------------------------------------
; Strings and Libraries
; ----------------------------------------------------------------------------

; hardcoded Shell strings
#include "strings.asm"

; framework libraries
#include "dirbrowse.asm"
#include "keyboard.asm"
#include "menu.asm"
#include "screen.asm"
#include "tools.asm"
