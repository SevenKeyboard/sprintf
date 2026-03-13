#Requires AutoHotkey v1.1.35+
;==============================================================
; phpSprintf — PHP-style formatted string builder
;
; GitHub: https://github.com/SevenKeyboard/sprintf
; Author: SevenKeyboard Ltd. (2026)
; License: MIT License
;
; Documentation / References:
;   sprintf
;     https://www.php.net/manual/en/function.sprintf.php
;   formatted_print.c
;     https://github.com/php/php-src/blob/master/ext/standard/formatted_print.c
;==============================================================
class VersionManager_phpSprintf
{
    static _ := VersionManager_phpSprintf._init()
    _init()    {
        global
        PHPSPRINTF_VERSION := "1.1.1"
    }
}
phpVsprintf(formatStr, values)    {
    return phpSprintf(formatStr, values*)
}
phpSprintf(formatStr, values*)    {
    ;  %[argnum$][flags][width][.precision]specifier
    static sprintfTokenCoreRegEx := "(?:(?<argnum>0*\d+)\$)?"
        . "(?<flags>(?:(?:[-+ 0])|(?:'.))*)"
        . "(?<width>(?:\*(?<widthArgnum>0*\d+)\$)|\*|\d+)?"
        . "(?<precisionPart>\.(?<precision>\*(?<precisionArgnum>0*\d+)\$|\*|\d*)?)?"
    static sprintfTokenPrefixRegEx := "OS)\A%" . sprintfTokenCoreRegEx
    static sprintfTokenRegEx := sprintfTokenPrefixRegEx . "(?<specifier>[sducoxXbeEfFgGhH])"
    prevBacthLines      := A_BatchLines
    setBatchLines -1
    prevCritical        := A_IsCritical
    critical
    prevFormatFloat     := A_FormatFloat 
    prevFormatInteger   := A_FormatInteger
    setFormat % "FloatFast", % 0.17 ;  The default format specifier for floating-point numbers is now .17g (was 0.6f), which is more compact and more accurate in many cases.
    setFormat % "IntegerFast", % "D"
    try  {
        fragments := []
        pendingPercent := false
        for i,fragment in strSplit(formatStr, "%")    {
            if (i == 1)    { ;  leading literal before first %
                if (fragment !== "")
                    fragments.push(fragment)
                continue
            }
            if (fragment == "")    {
                if (pendingPercent)    {
                    fragments.push("%%")
                    pendingPercent := false
                } else {
                    pendingPercent := true
                }
                continue
            }
            if (pendingPercent)    {
                fragments.push("%%" . fragment)
                pendingPercent := false
            }  else  {
                fragments.push("%" . fragment)
            }
        }
        if (pendingPercent)
            throw exception("Missing format specifier at end of string", -1)
        ;-----------------------------------------------------
        segments := []
        for _,fragment in fragments    {
            if (subStr(fragment, 1, 2) == "%%")    {
                segments.push({type: "literal", text: "%" . subStr(fragment, 3)})
                continue
            }
            if (subStr(fragment, 1, 1) !== "%")    {
                segments.push({type:"literal", text:fragment})
                continue
            }
            if (!regExMatch(fragment, sprintfTokenRegEx, m))    {
                if (regExMatch(fragment, sprintfTokenPrefixRegEx, mBad))    {
                    badSpecifier := subStr(fragment, mBad.len(0) + 1, 1)
                    if (badSpecifier !== "")
                        throw exception("Unknown format specifier """ . badSpecifier . """", -1)
                }
                throw exception("Unknown format specifier", -1)
            }
            argnum := m["argnum"]
            if (argnum !== "")    {
                argnum := argnum + 0
                if !(0 < argnum && argnum < 2147483647)
                    throw exception("Argument number specifier must be greater than zero and less than 2147483647", -1)
            }
            flags := m["flags"]
            width       := m["width"]
            widthArgnum := m["widthArgnum"]
            if (widthArgnum !== "")    {
                widthArgnum := widthArgnum + 0
                if !(0 < widthArgnum && widthArgnum < 2147483647)
                    throw exception("Width argument number specifier must be greater than zero and less than 2147483647", -1)
            }
            if (width !== "" && widthArgnum == "" && _PhpFormatPrinter._isInteger(width))    {
                width := width + 0
                if !(0 <= width && width < 2147483647)
                    throw exception("Width must be between 0 and 2147483647", -1)
            }
            precisionPart       := m["precisionPart"]
            precision           := m["precision"]
            precisionArgnum     := m["precisionArgnum"]
            if (precisionArgnum !== "")    {
                precisionArgnum := precisionArgnum + 0
                if !(0 < precisionArgnum && precisionArgnum < 2147483647)
                    throw exception("Precision argument number specifier must be greater than zero and less than 2147483647", -1)
            }
            hasPrecision        := (precisionPart !== "")
            isEmptyPrecision    := (precisionPart == ".")
            isNumericPrecision  := (precision !== "" && precisionArgnum == "" && _PhpFormatPrinter._isInteger(precision))
            if (isNumericPrecision)    {
                precision := precision + 0
                if !(0 <= precision && precision < 2147483647)
                    throw exception("Precision must be between 0 and 2147483647", -1)
            }
            specifier := m["specifier"]
            segments.push({type:"token"
                ,rawToken:m[0]
                ,argnum:argnum
                ,flags:flags
                ,width:width
                ,widthArgnum:widthArgnum
                ,precisionPart:precisionPart
                ,precision:precision
                ,precisionArgnum:precisionArgnum
                ,hasPrecision:hasPrecision
                ,isEmptyPrecision:isEmptyPrecision
                ,isNumericPrecision:isNumericPrecision
                ,specifier:specifier})
            literalTail := subStr(fragment, m.len(0) + 1)
            if (literalTail !== "")
                segments.push({type:"literal", text:literalTail})
        }
        ;-----------------------------------------------------
        result := ""
        nextImplicitArgIndex := 0
        for _,segment in segments    {
            switch (segment.type)
            {
                case "token":
                    result .= _PhpFormatPrinter.sprintfRenderToken(segment, values, nextImplicitArgIndex)
                default:
                    result .= segment.text            
            }
        }
        return result
    }  catch err  {
        throw err
    }  finally  {
        setFormat % "FloatFast", % prevFormatFloat
        setFormat % "IntegerFast", % prevFormatInteger
        critical % prevCritical
        setBatchLines % prevBacthLines
    }
}
class _PhpFormatPrinter
{
    ;  WARNING: Backward compatibility is not guaranteed for any methods or properties in this class.
    sprintfRenderToken(segment, values, byRef nextImplicitArgIndex)    {
        flagInfo := this._sprintfParseFlags(segment.flags)
        width := segment.width
        if (segment.widthArgnum !== "")    {
            widthIndex := segment.widthArgnum
            if (!values.hasKey(widthIndex))
                throw exception(widthIndex . " arguments are required, " . values.length() . " given", -1)
            width := values[widthIndex]
            if (!this._isInteger(width))
                throw exception("Width must be an integer", -1)
            width := width + 0
            if !(0 <= width && width < 2147483647)
                throw exception("Width must be between 0 and 2147483647", -1)
        }  else if (segment.width == "*")    {
            widthIndex := ++nextImplicitArgIndex
            if (!values.hasKey(widthIndex))
                throw exception(widthIndex . " arguments are required, " . values.length() . " given", -1)
            width := values[widthIndex]
            if (!this._isInteger(width))
                throw exception("Width must be an integer", -1)
            width := width + 0
            if !(0 <= width && width < 2147483647)
                throw exception("Width must be between 0 and 2147483647", -1)
        }
        precision := segment.precision
        if (segment.precisionArgnum !== "")    {
            precisionIndex := segment.precisionArgnum
            if (!values.hasKey(precisionIndex))
                throw exception(precisionIndex . " arguments are required, " . values.length() . " given", -1)
            precision := values[precisionIndex]
            if (!this._isInteger(precision))
                throw exception("Precision must be an integer", -1)
            precision := precision + 0
        }  else if (segment.precision == "*")    {
            precisionIndex := ++nextImplicitArgIndex
            if (!values.hasKey(precisionIndex))
                throw exception(precisionIndex . " arguments are required, " . values.length() . " given", -1)
            precision := values[precisionIndex]
            if (!this._isInteger(precision))
                throw exception("Precision must be an integer", -1)
            precision := precision + 0
        }
        valueIndex := (segment.argnum !== "" ? segment.argnum : ++nextImplicitArgIndex)
        if (!values.hasKey(valueIndex))
            throw exception(valueIndex . " arguments are required, " . values.length() . " given", -1)
        value := values[valueIndex]
        prevStringCaseSense := A_StringCaseSense 
        stringCaseSense % "On"
        switch segment.specifier
        {
            case "s":                                       action := 0
            case "c":                                       action := 1
            case "d", "u", "o", "x", "X", "b":              action := 2
            case "e", "E", "f", "F", "g", "G", "h", "H":    action := 3
            default:                                        action := 4
        }
        stringCaseSense % prevStringCaseSense
        switch action
        {
            case 0:
                if (segment.hasPrecision && precision < 0)
                    throw exception("Precision " . precision . " is only supported for %g, %G, %h and %H", -1)
                text := value . ""
                return this._sprintfAppendString(text
                    ,width
                    ,flagInfo.alignment
                    ,flagInfo.padding
                    ,false
                    ,false
                    ,precision
                    ,segment.hasPrecision)
            case 1:
                return this._sprintfAppendChar(value)
            case 2:
                return this._sprintfAppendInteger(value, segment.specifier, width, precision, segment.hasPrecision, flagInfo)
            case 3:
                text := this._sprintfAppendDouble(value, segment.specifier, precision, segment.hasPrecision, &isNegative)
                return this._sprintfAppendString(text, width, flagInfo.alignment, flagInfo.padding, isNegative, flagInfo.alwaysSign)
            default:
                return segment.rawToken
        }
    }
    ;-------------------------------------------------------------------------------------------
    _sprintfParseFlags(flags)    {
        alignment   := "right"
        padding     := " "
        alwaysSign  := false
        i := 1
        while (i <= strLen(flags))    {
            ch := subStr(flags, i, 1)
            switch ch
            {
                case "-":
                    alignment := "left"
                case "+":
                    alwaysSign := true
                case "'":
                    if (i == strLen(flags))
                        throw exception("Unknown format specifier", -1)
                    padding := subStr(flags, i + 1, 1)
                    i += 1
                case "0":
                    if (padding == " ")
                        padding := "0"
            }
            i += 1
        }
        return {alignment:alignment
            ,padding:padding
            ,alwaysSign:alwaysSign}
    }
    ;-------------------------------------------------------------------------------------------
    _sprintfAppendString(text, width, alignment, padding, isNegative := false, alwaysSign := false, maxWidth := "", applyPrecision := false)    {
        ;  precision-like cutoff for %s etc.
        if (applyPrecision && maxWidth !== "" && 0 <= maxWidth)
            text := subStr(text, 1, maxWidth)
        sign := ""
        body := text
        ;  extract/normalize sign first
        if (subStr(body, 1, 1) == "-")    {
            sign := "-"
            body := subStr(body, 2)
        }  else if (subStr(body, 1, 1) == "+")    {
            sign := "+"
            body := subStr(body, 2)
        }
        if (isNegative)
            sign := "-"
        else if (alwaysSign)
            sign := "+"
        visibleLen := strLen(sign) + strLen(body)
        if (width == "" || width <= visibleLen)
            return sign . body
        padLen := width - visibleLen
        padText := ""
        loop % padLen
            padText .= padding
        if (alignment == "left")
            return sign . body . padText
        if (padding == "0")
            return sign . padText . body
        return padText . sign . body
    }
    ;-------------------------------------------------------------------------------------------
    _sprintfAppendChar(value)    {
        if (!this._isInteger(value))
            value := value + 0
        if !(0 <= value && value <= 0x10FFFF)
            throw exception("Character code must be between 0 and 1114111", -1)
        return chr(value) ;  chr(value & 0xFF)
    }
    ;-------------------------------------------------------------------------------------------
    _sprintfAppendInteger(value, specifier, width, precision, hasPrecision, flagInfo)    {
        if (!this._isInteger(value))
            value := value + 0
        isNegative := false
        text := ""
        prevStringCaseSense := A_StringCaseSense 
        stringCaseSense % "On"
        switch specifier
        {
            case "d":       action := 0
            case "u":       action := 1
            case "o":       action := 2
            case "x", "X":  action := 3
            case "b":       action := 4
        }
        stringCaseSense % prevStringCaseSense
        switch action
        {
            case 0:
                text := value . ""
                if (subStr(text, 1, 1) == "-")    {
                    isNegative := true
                    text := subStr(text, 2)
                }
            case 1:
                hex         := this._sprintfIntToWordHex(value)
                text        := this._sprintfHexToUnsignedDecimal(hex)
            case 2:
                hex         := this._sprintfIntToWordHex(value)
                bin         := this._sprintfHexToBinary(hex)
                oct         := this._sprintfBinaryToOctal(bin)
                text        := this._sprintfWordDigitsToCanonical(oct)
            case 3:
                hex         := this._sprintfIntToWordHex(value)
                text        := this._sprintfWordDigitsToCanonical(hex)
                if (specifier == "X")
                    text := format("{:U}", text)
            case 4:
                hex         := this._sprintfIntToWordHex(value)
                bin         := this._sprintfHexToBinary(hex)
                text        := this._sprintfWordDigitsToCanonical(bin)
        }
        if (hasPrecision)    {
            if (precision == 0 && text == "0")    {
                text := ""
            }  else if (strLen(text) < precision)    {
                padLen := precision - strLen(text)
                zeroPad := format("{:0" . padLen . "}", "")
                text := zeroPad . text
            }
        }
        padding := flagInfo.padding
        if (hasPrecision)
            padding := " "
        return this._sprintfAppendString(text
            ,width
            ,flagInfo.alignment
            ,padding
            ,isNegative
            ,specifier == "d" ? flagInfo.alwaysSign : false)
    }
    _sprintfGetWordByteWidth()    {
        return 8 ;  A_PtrSize
    }
    _sprintfIntToWordHex(value)    {
        byteWidth := this._sprintfGetWordByteWidth()
        value := value + 0
        varSetCapacity(buf, byteWidth, 0)
        if (byteWidth == 4)
            numPut(value, &buf, "Int")
        else
            numPut(value, &buf, "Int64")
        hex := ""
        loop % byteWidth    {
            b := numGet(&buf, byteWidth - A_Index, "UChar")
            hex .= format("{:02x}", b)
        }
        return hex
    }
    _sprintfHexToUnsignedDecimal(hex)    {
        dec := "0"
        for _,ch in strSplit(format("{:L}", hex))    {
            digit := ch == "0" ? 0
                : ch == "1" ? 1
                : ch == "2" ? 2
                : ch == "3" ? 3
                : ch == "4" ? 4
                : ch == "5" ? 5
                : ch == "6" ? 6
                : ch == "7" ? 7
                : ch == "8" ? 8
                : ch == "9" ? 9
                : ch == "a" ? 10
                : ch == "b" ? 11
                : ch == "c" ? 12
                : ch == "d" ? 13
                : ch == "e" ? 14
                : 15
            dec := this._sprintfDecimalMulAdd(dec, 16, digit)
        }
        dec := lTrim(dec, "0")
        return (dec == "" ? "0" : dec)
    }
    _sprintfDecimalMulAdd(dec, mul, add)    {
        carry := add
        out := ""
        i := strLen(dec)
        while (i >= 1)    {
            n := subStr(dec, i, 1) + 0
            total := n * mul + carry
            out := mod(total, 10) . out
            carry := total // 10
            i -= 1
        }
        while (carry > 0)    {
            out := mod(carry, 10) . out
            carry := carry // 10
        }
        return out
    }
    _sprintfHexToBinary(hex)    {
        static hexMap := object("_0","0000", "_1","0001", "_2","0010", "_3","0011"
            ,"_4","0100", "_5","0101", "_6","0110", "_7","0111"
            ,"_8","1000", "_9","1001", "_a","1010", "_b","1011"
            ,"_c","1100", "_d","1101", "_e","1110", "_f","1111")
        bin := ""
        for _,ch in strSplit(format("{:L}", hex))
            bin .= hexMap["_" . ch]
        return bin
    }
    _sprintfBinaryToOctal(bin)    {
        static chunkMap := object("_000","0", "_001","1", "_010","2", "_011","3"
            ,"_100","4", "_101","5", "_110","6", "_111","7")
        rem := mod(strLen(bin), 3)
        if (rem)
            bin := subStr("000", 1, 3 - rem) . bin
        oct := ""
        loop % strLen(bin) // 3    {
            chunk := "_" . subStr(bin, (A_Index - 1) * 3 + 1, 3)
            oct .= chunkMap[chunk]
        }
        return oct
    }
    _sprintfWordDigitsToCanonical(digits)    {
        digits := lTrim(digits, "0")
        return (digits == "" ? "0" : digits)
    }
    _toBaseN(value, base)    { ;  Unused
        digits := "0123456789abcdef"
        if (value == 0)
            return "0"
        text := ""
        while (value > 0)    {
            rem := mod(value, base)
            text := subStr(digits, rem + 1, 1) . text
            value := value // base
        }
        return text
    }
    ;-------------------------------------------------------------------------------------------
    _sprintfAppendDouble(value, specifier, precision, hasPrecision, byRef isNegative := false)    {
        static FLOAT_PRECISION      := 6
            ,MAX_FLOAT_PRECISION    := 53
        originalPrecision := precision
        if (hasPrecision && precision < 0)    {
            if (specifier == "g" || specifier == "G" || specifier == "h" || specifier == "H")
                hasPrecision := false
            else
                throw exception("Precision " . precision . " is only supported for %g, %G, %h and %H", -1)
        }
        if (!hasPrecision)
            precision := FLOAT_PRECISION
        else if (MAX_FLOAT_PRECISION < precision)
            precision := MAX_FLOAT_PRECISION
        if (specifier == "g" || specifier == "G" || specifier == "h" || specifier == "H")    {
            if (precision == 0)
                precision := 1
        }
        isNegative := false
        text := ""
        ;  In v1, this is a compatibility check, not a strict IEEE bit-pattern test.
        ;  A textual value like "1.#INF00" may compare the same as actual infinity.
        if (value == this._getPosInf())
            return "INF"
        if (value == this._getNegInf())    {
            isNegative := true
            return "INF"    
        }
        prevStringCaseSense := A_StringCaseSense 
        stringCaseSense % "On"
        switch specifier
        {
            case "f", "F":      action := 0
            case "e":           action := 1
            case "E":           action := 2
            case "g", "h":      action := 3
            case "G", "H":      action := 4
        }
        stringCaseSense % prevStringCaseSense
        switch action
        {
            case 0:
                text := format("{:." . precision . "f}", value)
            case 1:
                text := format("{:." . precision . "e}", value)
            case 2:
                text := format("{:U}", (format("{:." . precision . "e}", value)))
            case 3:
                text := format("{:." . precision . "g}", value)
            case 4:
                text := format("{:U}", (format("{:." . precision . "g}", value)))
        }
        text := regExReplace(text, "([eE][+-])0+(\d)", "${1}${2}")
        if (hasPrecision && originalPrecision == 0)    {
            if (specifier == "g" || specifier == "G" || specifier == "h" || specifier == "H")
                text := regExReplace(text, "\A([+-]?\d)([eE][+-]\d+)\z", "${1}.0${2}")
        }
        if (subStr(text, 1, 1) == "-")    {
            isNegative := true
            text := subStr(text, 2)
        }
        return text
    }
    _getPosInf()    { ;  1.#INF00
        static v := ""
        if (v == "")    {
            varSetCapacity(buf, 8)
            numPut(0x7FF0000000000000, &buf, "Int64")
            v := numGet(&buf, 0, "Double")
        }
        return v
    }
    _getNegInf()    { ;  1.#QNAN0
        static v := ""
        if (v == "")    {
            varSetCapacity(buf, 8)
            numPut(0xFFF0000000000000, &buf, "Int64")
            v := numGet(&buf, 0, "Double")
        }
        return v
    }
    ;-------------------------------------------------------------------------------------------
    _isInteger(value)    {
        if value is integer
            return true
        else
            return false
    }
}