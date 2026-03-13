#Requires AutoHotkey v2.0.0+
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
    static _ := this._init()
    static _init()    {
        global
        PHPSPRINTF_VERSION := "1.1.1"
    }
}
phpVsprintf(formatStr, values) => phpSprintf(formatStr, values*)
phpSprintf(formatStr, values*)    {
    ;  %[argnum$][flags][width][.precision]specifier
    static sprintfTokenCoreRegEx := "(?:(?<argnum>0*\d+)\$)?"
        . "(?<flags>(?:(?:[-+ 0])|(?:'.))*)"
        . "(?<width>(?:\*(?<widthArgnum>0*\d+)\$)|\*|\d+)?"
        . "(?<precisionPart>\.(?<precision>\*(?<precisionArgnum>0*\d+)\$|\*|\d*)?)?"
    static sprintfTokenPrefixRegEx := "S)\A%" . sprintfTokenCoreRegEx
    static sprintfTokenRegEx := sprintfTokenPrefixRegEx . "(?<specifier>[sducoxXbeEfFgGhH])"
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
        throw valueError("Missing format specifier at end of string", -2)
    ;-----------------------------------------------------
    segments := []
    for fragment in fragments    {
        if (subStr(fragment, 1, 2) == "%%")    {
            segments.push({type: "literal", text: "%" . subStr(fragment, 3)})
            continue
        }
        if (subStr(fragment, 1, 1) !== "%")    {
            segments.push({type:"literal", text:fragment})
            continue
        }
        if (!regExMatch(fragment, sprintfTokenRegEx, &m))    {
            if (regExMatch(fragment, sprintfTokenPrefixRegEx, &mBad))    {
                badSpecifier := subStr(fragment, mBad.Len[0] + 1, 1)
                if (badSpecifier !== "")
                    throw valueError('Unknown format specifier "' . badSpecifier . '"', -2)
            }
            throw valueError("Unknown format specifier", -2)
        }
        argnum := m["argnum"]
        if (argnum !== "")    {
            argnum := integer(argnum)
            if !(0 < argnum && argnum < 2147483647)
                throw valueError("Argument number specifier must be greater than zero and less than 2147483647", -2)
        }
        flags := m["flags"]
        width       := m["width"]
        widthArgnum := m["widthArgnum"]
        if (widthArgnum !== "")    {
            widthArgnum := integer(widthArgnum)
            if !(0 < widthArgnum && widthArgnum < 2147483647)
                throw valueError("Width argument number specifier must be greater than zero and less than 2147483647", -2)
        }
        if (width !== "" && widthArgnum == "" && isInteger(width))    {
            width := integer(width)
            if !(0 <= width && width < 2147483647)
                throw valueError("Width must be between 0 and 2147483647", -2)
        }
        precisionPart       := m["precisionPart"]
        precision           := m["precision"]
        precisionArgnum     := m["precisionArgnum"]
        if (precisionArgnum !== "")    {
            precisionArgnum := integer(precisionArgnum)
            if !(0 < precisionArgnum && precisionArgnum < 2147483647)
                throw valueError("Precision argument number specifier must be greater than zero and less than 2147483647", -2)
        }
        hasPrecision        := (precisionPart !== "")
        isEmptyPrecision    := (precisionPart == ".")
        isNumericPrecision  := (precision !== "" && precisionArgnum == "" && isInteger(precision))
        if (isNumericPrecision)    {
            precision := integer(precision)
            if !(0 <= precision && precision < 2147483647)
                throw valueError("Precision must be between 0 and 2147483647", -2)
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
        literalTail := subStr(fragment, m.Len[0] + 1)
        if (literalTail !== "")
            segments.push({type:"literal", text:literalTail})
    }
    ;-----------------------------------------------------
    result := ""
    nextImplicitArgIndex := 0
    for segment in segments    {
        switch (segment.type)
        {
            case "token":
                result .= _PhpFormatPrinter.sprintfRenderToken(segment, values, &nextImplicitArgIndex)
            default:
                result .= segment.text            
        }
    }
    return result
}
class _PhpFormatPrinter
{
    ;  WARNING: Backward compatibility is not guaranteed for any methods or properties in this class.
    static sprintfRenderToken(segment, values, &nextImplicitArgIndex)    {
        flagInfo := this._sprintfParseFlags(segment.flags)
        width := segment.width
        if (segment.widthArgnum !== "")    {
            widthIndex := segment.widthArgnum
            if (!values.has(widthIndex))
                throw unsetItemError(widthIndex . " arguments are required, " . values.Length . " given", -2)
            width := values[widthIndex]
            if (!isInteger(width))
                throw valueError("Width must be an integer", -2)
            width := integer(width)
            if !(0 <= width && width < 2147483647)
                throw valueError("Width must be between 0 and 2147483647", -2)
        }  else if (segment.width == "*")    {
            widthIndex := ++nextImplicitArgIndex
            if (!values.has(widthIndex))
                throw unsetItemError(widthIndex . " arguments are required, " . values.Length . " given", -2)
            width := values[widthIndex]
            if (!isInteger(width))
                throw valueError("Width must be an integer", -2)
            width := integer(width)
            if !(0 <= width && width < 2147483647)
                throw valueError("Width must be between 0 and 2147483647", -2)
        }
        precision := segment.precision
        if (segment.precisionArgnum !== "")    {
            precisionIndex := segment.precisionArgnum
            if (!values.has(precisionIndex))
                throw unsetItemError(precisionIndex . " arguments are required, " . values.Length . " given", -2)
            precision := values[precisionIndex]
            if (!isInteger(precision))
                throw valueError("Precision must be an integer", -2)
            precision := integer(precision)
        }  else if (segment.precision == "*")    {
            precisionIndex := ++nextImplicitArgIndex
            if (!values.has(precisionIndex))
                throw unsetItemError(precisionIndex . " arguments are required, " . values.Length . " given", -2)
            precision := values[precisionIndex]
            if (!isInteger(precision))
                throw valueError("Precision must be an integer", -2)
            precision := integer(precision)
        }
        valueIndex := (segment.argnum !== "" ? segment.argnum : ++nextImplicitArgIndex)
        if (!values.has(valueIndex))
            throw unsetItemError(valueIndex . " arguments are required, " . values.Length . " given", -2)
        value := values[valueIndex]
        switch segment.specifier, true
        {
            case "s":
                if (segment.hasPrecision && precision < 0)
                    throw valueError("Precision " . precision . " is only supported for %g, %G, %h and %H", -2)
                text := string(value)
                return this._sprintfAppendString(text
                    ,width
                    ,flagInfo.alignment
                    ,flagInfo.padding
                    ,false
                    ,false
                    ,precision
                    ,segment.hasPrecision)
            case "c":
                return this._sprintfAppendChar(value)
            case "d", "u", "o", "x", "X", "b":
                return this._sprintfAppendInteger(value, segment.specifier, width, precision, segment.hasPrecision, flagInfo)
            case "e", "E", "f", "F", "g", "G", "h", "H":
                text := this._sprintfAppendDouble(value, segment.specifier, precision, segment.hasPrecision, &isNegative)
                return this._sprintfAppendString(text, width, flagInfo.alignment, flagInfo.padding, isNegative, flagInfo.alwaysSign)
            default:
                return segment.rawToken
        }
    }
    ;-------------------------------------------------------------------------------------------
    static _sprintfParseFlags(flags)    {
        alignment   := "right"
        padding     := " "
        alwaysSign  := false
        i := 1
        while (i <= strLen(flags))    {
            ch := subStr(flags, i, 1)
            switch ch, true
            {
                case "-":
                    alignment := "left"
                case "+":
                    alwaysSign := true
                case "'":
                    if (i == strLen(flags))
                        throw valueError("Unknown format specifier", -2)
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
    static _sprintfAppendString(text, width, alignment, padding, isNegative := false, alwaysSign := false, maxWidth := "", applyPrecision := false)    {
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
        loop padLen
            padText .= padding
        if (alignment == "left")
            return sign . body . padText
        if (padding == "0")
            return sign . padText . body
        return padText . sign . body
    }
    ;-------------------------------------------------------------------------------------------
    static _sprintfAppendChar(value)    {
        if (!isInteger(value))
            value := integer(value)
        if !(0 <= value && value <= 0x10FFFF)
            throw valueError("Character code must be between 0 and 1114111", -2)
        return chr(value) ;  chr(integer(value) & 0xFF)
    }
    ;-------------------------------------------------------------------------------------------
    static _sprintfAppendInteger(value, specifier, width, precision, hasPrecision, flagInfo)    {
        if (!isInteger(value))
            value := integer(value)
        isNegative := false
        text := ""
        switch specifier, true
        {
            case "d":
                text := string(value)
                if (subStr(text, 1, 1) == "-")    {
                    isNegative := true
                    text := subStr(text, 2)
                }
            case "u":
                hex         := this._sprintfIntToWordHex(value)
                text        := this._sprintfHexToUnsignedDecimal(hex)
            case "o":
                hex         := this._sprintfIntToWordHex(value)
                bin         := this._sprintfHexToBinary(hex)
                oct         := this._sprintfBinaryToOctal(bin)
                text        := this._sprintfWordDigitsToCanonical(oct)
            case "x", "X":
                hex         := this._sprintfIntToWordHex(value)
                text        := this._sprintfWordDigitsToCanonical(hex)
                if (specifier == "X")
                    text := strUpper(text)
            case "b":
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
    static _sprintfGetWordByteWidth()    {
        return 8 ;  A_PtrSize
    }
    static _sprintfIntToWordHex(value)    {
        byteWidth := this._sprintfGetWordByteWidth()
        value := integer(value)
        buf := buffer(byteWidth, 0)
        if (byteWidth == 4)
            numPut("Int", value, buf)
        else
            numPut("Int64", value, buf)
        hex := ""
        loop byteWidth    {
            b := numGet(buf, byteWidth - A_Index, "UChar")
            hex .= format("{:02x}", b)
        }
        return hex
    }
    static _sprintfHexToUnsignedDecimal(hex)    {
        dec := "0"
        for ch in strSplit(strLower(hex))    {
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
    static _sprintfDecimalMulAdd(dec, mul, add)    {
        carry := add
        out := ""
        i := strLen(dec)
        while (i >= 1)    {
            n := integer(subStr(dec, i, 1))
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
    static _sprintfHexToBinary(hex)    {
        static hexMap := map("0","0000", "1", "0001", "2", "0010", "3", "0011"
            ,"4","0100", "5", "0101", "6", "0110", "7", "0111"
            ,"8","1000", "9", "1001", "a", "1010", "b", "1011"
            ,"c","1100", "d", "1101", "e", "1110", "f", "1111")
        bin := ""
        for ch in strSplit(strLower(hex))
            bin .= hexMap[ch]
        return bin
    }
    static _sprintfBinaryToOctal(bin)    {
        static chunkMap := map("000","0", "001","1", "010","2", "011","3"
            ,"100","4", "101","5", "110","6", "111","7")
        rem := mod(strLen(bin), 3)
        if (rem)
            bin := subStr("000", 1, 3 - rem) . bin
        oct := ""
        loop strLen(bin) // 3    {
            chunk := subStr(bin, (A_Index - 1) * 3 + 1, 3)
            oct .= chunkMap[chunk]
        }
        return oct
    }
    static _sprintfWordDigitsToCanonical(digits)    {
        digits := lTrim(digits, "0")
        return (digits == "" ? "0" : digits)
    }
    static _toBaseN(value, base)    { ;  Unused
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
    static _sprintfAppendDouble(value, specifier, precision, hasPrecision, &isNegative := false)    {
        static FLOAT_PRECISION      := 6
            ,MAX_FLOAT_PRECISION    := 53
        originalPrecision := precision
        if (hasPrecision && precision < 0)    {
            switch specifier, true
            {
                case "g", "G", "h", "H":
                    hasPrecision := false
                default:
                    throw valueError("Precision " . precision . " is only supported for %g, %G, %h and %H", -2)
            }
        }
        if (!hasPrecision)
            precision := FLOAT_PRECISION
        else if (MAX_FLOAT_PRECISION < precision)
            precision := MAX_FLOAT_PRECISION
        switch specifier, true
        {
            case "g", "G", "h", "H":
                if (precision == 0)
                    precision := 1
        }
        isNegative := false
        text := ""
        if (type(value) == "Float")    {
            if (value !== value)
                return "NaN"
            if (value == this._getPosInf())
                return "INF"
            if (value == this._getNegInf())    {
                isNegative := true
                return "INF"
            }
        }
        switch specifier, true
        {
            case "f", "F":
                text := format("{:." . precision . "f}", value)
            case "e":
                text := format("{:." . precision . "e}", value)
            case "E":
                text := strUpper(format("{:." . precision . "e}", value))
            case "g", "h":
                text := format("{:." . precision . "g}", value)
            case "G", "H":
                text := strUpper(format("{:." . precision . "g}", value))
        }
        text := regExReplace(text, "([eE][+-])0+(\d)", "${1}${2}")
        if (hasPrecision && originalPrecision == 0)    {
            switch specifier, true
            {
                case "g", "G", "h", "H":
                    text := regExReplace(text, "\A([+-]?\d)([eE][+-]\d+)\z", "${1}.0${2}")
            }
        }
        if (subStr(text, 1, 1) == "-")    {
            isNegative := true
            text := subStr(text, 2)
        }
        return text
    }
    static _getPosInf()    { ;  inf
        static v := ""
        if (v == "")    {
            buf := buffer(8)
            numPut("Int64", 0x7FF0000000000000, buf)
            v := numGet(buf, 0, "Double")
        }
        return v
    }
    static _getNegInf()    { ;  -inf
        static v := ""
        if (v == "")    {
            buf := buffer(8)
            numPut("Int64", 0xFFF0000000000000, buf)
            v := numGet(buf, 0, "Double")
        }
        return v
    }
}