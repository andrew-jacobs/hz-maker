;===============================================================================
;  _   _ _____     __  __       _             
; | | | |__  /    |  \/  | __ _| | _____ _ __ 
; | |_| | / /_____| |\/| |/ _` | |/ / _ \ '__|
; |  _  |/ /|_____| |  | | (_| |   <  __/ |   
; |_| |_/____|    |_|  |_|\__,_|_|\_\___|_|   
;                                             
; A PIC Based Micro-Processor Clock Source and EconoReset
;-------------------------------------------------------------------------------
; Copyright (C)2016 Andrew John Jacobs
; All rights reserved.
;
; This work is made available under the terms of the Creative Commons
; Attribution-NonCommercial-ShareAlike 4.0 International license. Open the
; following URL to see the details.
; 
; http://creativecommons.org/licenses/by-nc-sa/4.0/
;-------------------------------------------------------------------------------
                
                include "p16f18313.inc"
                
                errorlevel -302
                
;===============================================================================
; Fuse Configuration
;-------------------------------------------------------------------------------

 __CONFIG _CONFIG1, _FEXTOSC_HS & _RSTOSC_HFINT1 & _CLKOUTEN_OFF & _CSWEN_ON & _FCMEN_ON
 __CONFIG _CONFIG2, _MCLRE_ON & _PWRTE_OFF & _WDTE_ON & _LPBOREN_OFF & _BOREN_OFF & _BORV_LOW & _PPS1WAY_ON & _STVREN_ON & _DEBUG_OFF
 __CONFIG _CONFIG3, _WRT_OFF & _LVP_OFF
 __CONFIG _CONFIG4, _CP_OFF & _CPD_OFF
 
;===============================================================================
; Hardware Configuration
;-------------------------------------------------------------------------------

; Internal/External Clock Frequency during normal operation

OSC             equ     .8000000                ; 8Mhz Crystal or FRC
PLL             equ     .4                      ; With 4x PLL
             
FOSC            equ     OSC * PLL
            
;-------------------------------------------------------------------------------

; Target CPU clock speed and reset pulse length
            
CPU_MHZ         equ     .2000000                ; PHI2: 1, 2, 4 or 8Mhz
RESET_MS        equ     .150                    ; Reset pulse lengtb (mSec)

FACTOR          =       FOSC / CPU_MHZ
CLK_DIV         =       -1
         
                while   FACTOR
FACTOR          =       FACTOR / 2
CLK_DIV         =       CLK_DIV + 1
                endw

;-------------------------------------------------------------------------------

; Target ACIA clock frequency

ACIA_MHZ        equ     .1843200                ; 1.8432Mhz
        
NCO_INCR        equ     ((ACIA_MHZ >> .10) << .20) / (FOSC >> .10)
        
;-------------------------------------------------------------------------------

; Timer2 is used to generate the reset delay
        
TMR2_HZ         equ     .1000                   ; 1000Hz
TMR2_PRE        equ     .16
TMR2_POST       equ     .4
       
TMR2_PR         equ     FOSC / (.4 * TMR2_PRE * TMR2_POST * TMR2_HZ)
     
                if      TMR2_PR & h'ffffff00'
                error   "Timer2 period does not fit in 8-bits
                endif
     
;-------------------------------------------------------------------------------

; Pin assignments
                
PHI2_TRIS       equ     TRISA
PHI2_LAT        equ     LATA
PHI2_PIN        equ     .0
PHI2_PPS        equ     RA0PPS
        
ACIA_TRIS       equ     TRISA
ACIA_LAT        equ     LATA
ACIA_PIN        equ     .1
ACIA_PPS        equ     RA1PPS

RESB_TRIS       equ     TRISA
RESB_LAT        equ     LATA
RESB_PIN        equ     .2
 
;===============================================================================
; Interrupt Handler
;-------------------------------------------------------------------------------
    
.Interrupt      code    h'0004'

                banksel PIR3
                btfss   PIR3,OSFIF              ; Has the oscillator failed?
                bra     OscFailHandled          ; No
                bcf     PIR3,OSFIF              ; Yes, clear the condition
                
                movlw   b'00000000'
                banksel OSCCON1                 ; Switch to 32Mhz INTOSC
                movwf   OSCCON1
                
                banksel PIE3                    ; Disable failure detection
                bcf     PIE3,OSFIE
OscFailHandled:
                retfie                          ; Done
                
;===============================================================================
; Power On Reset
;-------------------------------------------------------------------------------
                
.ResetVector    code    h'0000'
    
                goto    PowerOnReset            ; Go to real start up
                
;-------------------------------------------------------------------------------
             
                code
PowerOnReset:
                banksel ANSELA                  ; Turn analog off
                clrf    ANSELA
                
; Set pin directions and hold CPU in reset
                
                banksel TRISA
                bcf     PHI2_TRIS,PHI2_PIN
                bcf     ACIA_TRIS,ACIA_PIN
                bcf     RESB_TRIS,RESB_PIN
                banksel LATA
                bcf     RESB_LAT,RESB_PIN

; Configure pins for CLKR and NCO outputs
                
                banksel PPSLOCK
                movlw   h'55'                   ; Unlock PPS module
                movwf   PPSLOCK
                movlw   h'aa'
                movwf   PPSLOCK
                bcf     PPSLOCK,PPSLOCKED
                
                banksel PHI2_PPS 
                movlw   b'00011110'             ; Configure modules
                movwf   PHI2_PPS
                movlw   b'00011101'
                movwf   ACIA_PPS
                
                banksel PPSLOCK
                bsf     PPSLOCK,PPSLOCKED       ; And lock
                
; Enable oscillator fail interrupt
                
                banksel PIE3
                bsf     PIE3,OSFIE
                
                bsf     INTCON,PEIE
                bsf     INTCON,GIE
                
; Try to switch to the external 8Mhz crystal with 4x PLL
                
                movlw   b'00010000'
                banksel OSCCON1
                movwf   OSCCON1
                
                ifndef  __DEBUG
                clrwdt
                banksel OSCCON3
WaitTillStable:
                btfss   OSCCON3,ORDY
                bra     WaitTillStable
                endif
                
; Configure CLKR for target CPU speed and enable
                
                movlw   b'00010000'|CLK_DIV
                banksel CLKRCON
                movwf   CLKRCON
                bsf     CLKRCON,CLKREN
                
; Configure NCO to output the ACIA clock frequency
                
                banksel NCO1CON
                clrf    NCO1CON
                movlw   b'00000001'
                movwf   NCO1CLK
                
                clrf    NCO1ACCL
                clrf    NCO1ACCH
                clrf    NCO1ACCU                
                
                movlw   low (NCO_INCR)
                movwf   NCO1INCL
                movlw   high (NCO_INCR)
                movwf   NCO1INCH
                movlw   upper (NCO_INCR)
                movwf   NCO1INCU
                
                bsf     NCO1CON,N1EN
                
; Configure Timer2 to count milliseconds
                
                movlw   b'00011010'             ; Must match parameters
                banksel T2CON
                movwf   T2CON
                movlw   low TMR2_PR
                movwf   PR2
                clrf    TMR2
                bsf     T2CON,TMR2ON
                
; Wait 10mSec by counting Timer2 roll overs
                
                movlw   RESET_MS
                banksel PIR1
ClearTimerFlag:
                bcf     PIR1,TMR2IF
WaitForTimer:
                clrwdt
                btfss   PIR1,TMR2IF
                bra     WaitForTimer
                addlw   -.1
                btfss   STATUS,Z
                bra     ClearTimerFlag
                
; Release the CPU from reset and allow to run until next reset
                
                banksel RESB_LAT
                bsf     RESB_LAT,RESB_PIN
WaitForReset:
                clrwdt
                bra     WaitForReset
                
		end