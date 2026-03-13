#Requires AutoHotkey v2.0
#SingleInstance Force
#Include ..\phpSprintf.ahk

;==============================================================
; Basic literals / percent
;==============================================================
msgBox(phpSprintf("Hello, world!"))                         ;  "Hello, world!"
msgBox(phpSprintf("100%% done"))                            ;  "100% done"
msgBox(phpSprintf("[%s]", "Seven"))                         ;  "[Seven]"
msgBox(phpSprintf("[%10s]", "Seven"))                       ;  "[     Seven]"
msgBox(phpSprintf("[%-10s]", "Seven"))                      ;  "[Seven     ]"
msgBox(phpSprintf("[%'.10s]", "Seven"))                     ;  "[.....Seven]"

;==============================================================
; Integer specifiers
;==============================================================
msgBox(phpSprintf("[%d]", 42))                              ;  "[42]"
msgBox(phpSprintf("[%+d]", 42))                             ;  "[+42]"
msgBox(phpSprintf("[%08d]", 42))                            ;  "[00000042]"
msgBox(phpSprintf("[%8.5d]", 42))                           ;  "[   00042]"
                                                                ;  Actual PHP output: "[      42]"
msgBox(phpSprintf("[%u]", -1))                              ;  "[18446744073709551615]"
                                                                ;  Actual PHP behavior: platform-dependent.
                                                                ;  On 32-bit PHP, this is typically "[4294967295]".
                                                                ;  On 64-bit PHP, this is typically "[18446744073709551615]".
                                                                ;  This implementation always formats unsigned integers from AHK's Int64-based value model.
msgBox(phpSprintf("[%x]", 255))                             ;  "[ff]"
msgBox(phpSprintf("[%X]", 255))                             ;  "[FF]"
msgBox(phpSprintf("[%o]", 511))                             ;  "[777]"
msgBox(phpSprintf("[%b]", 13))                              ;  "[1101]"

;==============================================================
; Character
;==============================================================
msgBox(phpSprintf("[%c]", 65))                              ;  "[A]"
msgBox(phpSprintf("[%c]", 10))                              ;  "[`n]"
msgBox(phpSprintf("[%c]", 233))                             ;  "[é]"
                                                                ;  Actual PHP behavior: a raw byte 0xE9 is emitted.
                                                                ;  Depending on the display environment, it may or may not appear as "é".
msgBox(phpSprintf("[%c]", 0x1F600))                         ;  "[😀]"
                                                                ;  Actual PHP behavior: a raw byte 0x00 is emitted.
                                                                ;  It does not produce "😀"; the output depends on how that NUL byte is handled by the display environment.

;==============================================================
; Float specifiers
;==============================================================
msgBox(phpSprintf("[%f]", 3.1415926535))                    ;  "[3.141593]"
msgBox(phpSprintf("[%.2f]", 3.1415926535))                  ;  "[3.14]"
msgBox(phpSprintf("[%e]", 1234.5))                          ;  "[1.234500e+3]"
msgBox(phpSprintf("[%E]", 1234.5))                          ;  "[1.234500E+3]"
msgBox(phpSprintf("[%g]", 1234.5))                          ;  "[1234.5]"
msgBox(phpSprintf("[%G]", 1234.5))                          ;  "[1234.5]"
msgBox(phpSprintf("[%h]", 1234.5))                          ;  "[1234.5]"
msgBox(phpSprintf("[%H]", 1234.5))                          ;  "[1234.5]"
msgBox(phpSprintf("[%+08.2f]", 12.3))                       ;  "[+0012.30]"
;  In this implementation, %g and %h behave the same, and %G and %H behave the same,
;  because locale-aware float formatting is not distinguished.

;==============================================================
; Positional arguments
;==============================================================
msgBox(phpSprintf("[%2$s %1$s]", "world", "Hello"))         ;  "[Hello world]"
msgBox(phpSprintf("[%2$10s]", "A", "B"))                    ;  "[         B]"
msgBox(phpSprintf("[%2$*3$s]", "A", "B", 5))                ;  "[    B]"
msgBox(phpSprintf("[%3$*2$.*1$f]", 2, 8, 9.8765))           ;  "[    9.88]"

;==============================================================
; Star width / precision
;==============================================================
msgBox(phpSprintf("[%*s]", 10, "cat"))                      ;  "[       cat]"
msgBox(phpSprintf("[%.*f]", 3, 12.34567))                   ;  "[12.346]"
msgBox(phpSprintf("[%*.*f]", 8, 2, 12.34567))               ;  "[   12.35]"
msgBox(phpSprintf("[%2$*.*f]", 8, 2, 9.8765))               ;  "[    2.00]"

;==============================================================
; Real-world style examples
;==============================================================
msgBox(phpSprintf("%d files deleted.", 12))                 ;  "12 files deleted."
msgBox(phpSprintf("%2$s, %1$s!", "world", "Hello"))         ;  "Hello, world!"
msgBox(phpSprintf("[%.0f]", 3.9))                           ;  "[4]"

;==============================================================
; String precision / multibyte text
;==============================================================
msgBox(phpSprintf("[%.3s]", "가나다라마"))                  ;  "[가나다]"
                                                                ;  Actual PHP output: "[가]"
                                                                ;  PHP applies %s precision by byte length,
                                                                ;  while this implementation applies it by character count.

;==============================================================
; Mixed / advanced examples
;==============================================================
msgBox(phpSprintf("[%2$'.*1$s]", 10, "cat"))                ;  "[.......cat]"
msgBox(phpSprintf("[%1$+'.8d]", 42))                        ;  "[.....+42]"
msgBox(phpSprintf("[%1$+.8d]", 42))                         ;  "[+00000042]"
                                                                ;  Actual PHP output: "[+42]"
msgBox(phpSprintf("[%2$*3$.*4$X]", 111, 255, 8, 4))         ;  "[    00FF]"
                                                                ;  Actual PHP output: "[        ]"
msgBox(phpSprintf("[%2$*3$.*4$b]", 111, 13, 10, 8))         ;  "[  00001101]"
                                                                ;  Actual PHP output: "[          ]"
msgBox(phpSprintf("[%2$*3$.*4$o]", 111, 9, 8, 4))           ;  "[    0011]"
                                                                ;  Actual PHP output: "[        ]"
;  This implementation applies integer precision consistently to %d, %X, %b, and %o.
;  PHP behaves differently for these cases.
;  These examples demonstrate an intentional extension beyond PHP's behavior.

;==============================================================
; Error handling
;==============================================================
try phpSprintf("[%s %s]", "only-one")
catch as err
    msgBox("Error: " . err.Message)                      ;  "Error: 2 arguments are required, 1 given"
                                                                ;  Actual PHP exception: "ArgumentCountError: 3 arguments are required, 2 given"
try phpSprintf("[%q]", 123)
catch as err
    msgBox("Error: " . err.Message)                      ;  "Error: Unknown format specifier `"q`""

try phpSprintf("[%*s]", "wide", "cat")
catch as err
    msgBox("Error: " . err.Message)                      ;  "Error: Width must be an integer"

try phpSprintf("[%.*f]", "prec", 1.23)
catch as err
    msgBox("Error: " . err.Message)                      ;  "Error: Precision must be an integer"

try phpSprintf("[%.*s]", -1, "ABCDE")
catch as err
    msgBox("Error: " . err.Message)                      ;  "Error: Precision -1 is only supported for %g, %G, %h and %H"

try phpSprintf("[%")
catch as err
    msgBox("Error: " . err.Message)                      ;  "Error: Missing format specifier at end of string"
                                                                ;  Actual PHP exception: "ArgumentCountError: 2 arguments are required, 1 given"