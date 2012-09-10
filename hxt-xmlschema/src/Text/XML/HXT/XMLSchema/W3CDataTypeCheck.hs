{- |
   Module     : Text.XML.HXT.XMLSchema.W3CDataTypeCheck
   Copyright  : Copyright (C) 2005-2012 Uwe Schmidt
   License    : MIT

   Maintainer : Uwe Schmidt (uwe@fh-wedel.de)
   Stability  : experimental
   Portability: portable
   Version    : $Id$

   Contains functions to check basic W3C datatypes and params.
-}

module Text.XML.HXT.XMLSchema.W3CDataTypeCheck

  ( module Text.XML.HXT.XMLSchema.DataTypeLibW3CNames
  , ParamList
  , datatypeAllowsW3C
  )

where

import Text.XML.HXT.XMLSchema.W3CDataTypeCheckUtils
import Text.XML.HXT.XMLSchema.DataTypeLibW3CNames

import Text.Regex.XMLSchema.String    ( Regex
                                      , matchRE
                                      , parseRegex
                                      , isZero
                                      )

import Text.XML.HXT.DOM.QualifiedName ( isWellformedQualifiedName
                                      , isNCName
                                      )
import Text.XML.HXT.DOM.Util          ( normalizeWhitespace
                                      , normalizeBlanks
                                      , escapeURI
                                      )

import Data.Char                      ( isAlpha
                                      , isDigit
                                      , toUpper
                                      )
import Data.Maybe                     ( fromMaybe )
import Data.Ratio                     ( numerator
                                      , denominator
                                      , (%)
                                      )
import Data.Time

import Network.URI                    ( isURIReference )

-- ----------------------------------------

-- | Tests whether a pattern is valid
patternValid :: ParamList -> CheckA String String
patternValid params
  = foldr (>>>) ok . map paramPatternValid $ params
    where
    paramPatternValid (pn, pv)
      | pn == xsd_pattern = assert (patParamValid pv) $ errorMsgParam pn pv
      | otherwise         = ok

-- | Helper function to test pattern params
patParamValid :: String -> String -> Bool
patParamValid regex a
  | isZero ex = False
  | otherwise = matchRE ex a
  where
  ex = parseRegex regex

-- ----------------------------------------

-- | Function table for decimal tests
fctTableDecimal :: [(String, String -> Rational -> Bool)]
fctTableDecimal
  = [ (xsd_maxExclusive,   cvd (>))
    , (xsd_minExclusive,   cvd (<))
    , (xsd_maxInclusive,   cvd (>=))
    , (xsd_minInclusive,   cvd (<=))
    , (xsd_totalDigits,    cvi (\ l v ->    totalDigits v == l))
    , (xsd_fractionDigits, cvi (\ l v -> fractionDigits v == l))
    ]
    where
    cvd :: (Rational -> Rational -> Bool) -> (String -> Rational -> Bool)
    cvd op = \ x y -> isDecimal x && readDecimal x `op` y

    cvi :: (Int -> Rational -> Bool) -> (String -> Rational -> Bool)
    cvi op = \ x y -> isNumber x && read x `op` y

-- | Tests whether a decimal is valid
decimalValid :: ParamList -> CheckA Rational Rational
decimalValid params
  = foldr (>>>) ok . map paramDecimalValid $ params
    where
    paramDecimalValid (pn, pv)
      = assert
        ((fromMaybe (const . const $ True) . lookup pn $ fctTableDecimal) pv)
        (errorMsgParam pn pv . showDecimal)

-- ----------------------------------------

-- | Function table for integer tests
fctTableInteger :: [(String, String -> Integer -> Bool)]
fctTableInteger
  = [ (xsd_maxExclusive, cvi (>))
    , (xsd_minExclusive, cvi (<))
    , (xsd_maxInclusive, cvi (>=))
    , (xsd_minInclusive, cvi (<=))
    , (xsd_totalDigits,  cvi (\ l v -> totalD v == toInteger l))
    ]
    where
    cvi :: (Integer -> Integer -> Bool) -> (String -> Integer -> Bool)
    cvi op = \ x y -> isNumber x && read x `op` y

    totalD i =  toInteger . length . show . abs $ i

-- | Tests whether an integer is valid
integerValid :: DatatypeName -> ParamList -> CheckA Integer Integer
integerValid datatype params
  = assertInRange
    >>>
    (foldr (>>>) ok . map paramIntegerValid $ params)
    where
    assertInRange :: CheckA Integer Integer
    assertInRange
      = assert
        (fromMaybe (const True) . lookup datatype $ integerRangeTable)
        (\ v -> ( "Datatype " ++ show datatype ++
                  " with value = " ++ show v ++
                  " not in integer value range."
                )
        )
    paramIntegerValid (pn, pv)
      = assert
        ((fromMaybe (const . const $ True) . lookup pn $ fctTableInteger) pv)
        (errorMsgParam pn pv . show)

-- | Table for range tests on integer values
integerRangeTable :: [(String, Integer -> Bool)]
integerRangeTable = [ (xsd_integer,            const True)
                    , (xsd_nonPositiveInteger, (<=0)   )
                    , (xsd_negativeInteger,    ( <0)   )
                    , (xsd_nonNegativeInteger, (>=0)   )
                    , (xsd_positiveInteger,    ( >0)   )
                    , (xsd_long,               inR 9223372036854775808)
                    , (xsd_int,                inR 2147483648)
                    , (xsd_short,              inR 32768)
                    , (xsd_byte,               inR 128)
                    , (xsd_unsignedLong,       inP 18446744073709551616)
                    , (xsd_unsignedInt,        inP 4294967296)
                    , (xsd_unsignedShort,      inP 65536)
                    , (xsd_unsignedByte,       inP 256)
                    ]
                    where
                    inR b i = (0 - b) <= i && i < b
                    inP b i = 0 <= i       && i < b

-- ----------------------------------------

-- | Function table for floating tests
fctTableFloating :: (Floating n, Read n, Ord n) => [(String, String -> n -> Bool)]
fctTableFloating
  = [ (xsd_maxExclusive, cvf (>))
    , (xsd_minExclusive, cvf (<))
    , (xsd_maxInclusive, cvf (>=))
    , (xsd_minInclusive, cvf (<=))
    ]
    where
    cvf :: (Floating n, Read n) => (n -> n -> Bool) -> (String -> n -> Bool)
    cvf op = \ x y -> isFloating x && readFloating x `op` y

readFloating :: (Floating n, Read n) => String -> n
readFloating  "INF" =  1.0 / 0.0
readFloating "-INF" = -1.0 / 0.0
readFloating  "NaN" =  0.0 / 0.0
readFloating s      =  read s

-- | Tests whether an floating value is valid
floatingValid :: (Floating n, Ord n, Read n, Show n) => DatatypeName -> ParamList -> CheckA n n
floatingValid _datatype params
  = (foldr (>>>) ok . map paramFloatingValid $ params)
    where
    paramFloatingValid (pn, pv)
      = assert
        ((fromMaybe (const . const $ True) . lookup pn $ fctTableFloating) pv)
        (errorMsgParam pn pv . show)

floatValid :: DatatypeName -> ParamList -> CheckA Float Float
floatValid = floatingValid

doubleValid :: DatatypeName -> ParamList -> CheckA Double Double
doubleValid = floatingValid

-- ----------------------------------------

-- | Tests whether a string matches a name list
isNameList :: (String -> Bool) -> String -> Bool
isNameList p w
  = not (null ts) && all p ts
    where
    ts = words w

-- ----------------------------------------

-- | Creates a regex from a string
rex :: String -> Regex
rex regex
  | isZero ex = error $ "syntax error in regexp " ++ show regex ++ "."
  | otherwise = ex
  where
  ex = parseRegex regex

-- ----------------------------------------

-- | Creates a language regex
rexLanguage :: Regex
rexLanguage = rex "[A-Za-z]{1,8}(-[A-Za-z]{1,8})*"

-- | Creates a hex binary regex
rexHexBinary :: Regex
rexHexBinary = rex "([A-Fa-f0-9]{2})*"

-- | Creates a base64 binary regex
rexBase64Binary :: Regex
rexBase64Binary = rex $
                  "(" ++ b64 ++ "{4})*((" ++ b64 ++ "{2}==)|(" ++ b64 ++ "{3}=)|)"
                  where
                  b64     = "[A-Za-z0-9+/]"

-- | Creates a boolean regex
rexBoolean :: Regex
rexBoolean = rex "true|false|1|0"

-- | Creates a decimal regex
rexDecimal :: Regex
rexDecimal = rex "(\\+|-)?(([0-9]+(\\.[0-9]*)?)|(\\.[0-9]+))"

-- | Creates an integer regex
rexInteger :: Regex
rexInteger = rex "(\\+|-)?[0-9]+"

rexFloating :: Regex
rexFloating = rex "(-?INF)|NaN|(\\+|-)?([0-9]+(.[0-9]*)?|.[0-9]+)([Ee](\\+|-)?[0-9]+)?"

-- | Tests whether a string matches a language value
isLanguage :: String -> Bool
isLanguage = matchRE rexLanguage

-- | Tests whether a string matches a hex binary
isHexBinary :: String -> Bool
isHexBinary = matchRE rexHexBinary

-- | Tests whether a string matches a base64 binary
isBase64Binary :: String -> Bool
isBase64Binary = matchRE rexBase64Binary

-- | Tests whether a string matches a decimal
isDecimal :: String -> Bool
isDecimal = matchRE rexDecimal

-- | Tests whether a string matches an integer
isInteger :: String -> Bool 
isInteger = matchRE rexInteger

isFloating :: String -> Bool
isFloating = matchRE rexFloating

-- ----------------------------------------

type Duration = NominalDiffTime

rexDuration :: Regex
rexDuration
    = rex $ sign ++ "P" ++ alt (ymd ++ opt tim) tim
    where
      sign = "-?"
      ymd = alt (y ++ opt md) md
      md  = alt (m ++ opt  d)  d
      y   = n ++ "Y"
      m   = n ++ "M"
      d   = n ++ "D"

      tim = "T" ++ hms      
      hms = alt (h  ++ opt ms) ms
      ms  = alt (m' ++ opt  s)  s
      h   = n ++ "H"
      m'  = n ++ "M"
      s   = n'n ++ "S"

      n   = "[0-9]+"
      n'n = n ++ opt ("[.]" ++ n)

      opt x     = "(" ++ x ++ ")?"
      alt s1 s2 = "((" ++ s1 ++ ")|(" ++ s2 ++ "))"

isDuration :: String -> Bool
isDuration = matchRE rexDuration

readDuration :: String -> Duration
readDuration ('-' : s) = negate $ readDuration s
readDuration s0@('P' : s)
    = readYearMonthDay s1 + readHourMinSec (drop 1 s2)
    where
      (s1, s2) = span (/= 'T') s

      errDur = error $ "readDuration: wrong argument " ++ show s0

      readDur = fromInteger . read

      readYearMonthDay ""
          = fromInteger 0
      readYearMonthDay x
          | head x2 == 'Y'
              = (365 * 24 * 60 * 60) * readDur x1 + readYearMonthDay (tail x2)
          | head x2 == 'M'
              = ( 30 * 24 * 60 * 60) * readDur x1 + readYearMonthDay (tail x2)
          | head x2 == 'D'
              = (      24 * 60 * 60) * readDur x1
          | otherwise
              = errDur
          where
            (x1, x2) = span isDigit x


      readHourMinSec ""
          = fromInteger 0
      readHourMinSec x
          | head x2 == 'H'
              = (60 * 60) * readDur x1 + readHourMinSec (tail x2)
          | head x2 == 'M'
              = (     60) * readDur x1 + readHourMinSec (tail x2)
          | head x2 == 'S'
              = fromRational $ readDecimal x1

          | otherwise
              = errDur
          where
            (x1, x2) = span (not . isAlpha) x
readDuration s0
    = error $ "readDuration: illegal argument " ++ show s0

showDuration :: Duration -> String
showDuration d
    | d < fromInteger 0
        = '-' : (showDuration $ negate d)
    | otherwise
        = addP . years $ d
    where
      addP "" = "P0D"
      addP s  = 'P' : s

      addT "" = ""
      addT s  = 'T' : s

      times scale unit next x
          | r == 0 = res
          | otherwise = show r ++ [unit] ++ res
          where
            r :: Integer
            r = truncate $ x / scale
            y = x - fromInteger r * scale
            res = next y

      years   = times (365 * 24 * 60 * 60) 'Y' months
      months  = times  (30 * 24 * 60 * 60) 'M' days
      days    = times       (24 * 60 * 60) 'D' $ addT . hours
      hours   = times            (60 * 60) 'H' minutes
      minutes = times                   60 'M' seconds
      seconds d'
          | d' == fromInteger 0 = ""
          | otherwise           = map toUpper . show $ d'

-- | Function table for integer tests
--
-- TODO: the 4 comparison operators can not be implemented ba the relatinal ops of Duration,
-- in the standard ("http://www.w3.org/TR/xmlschema-2/#duration")
-- there is a description of comparing durations: they must be compared
-- combining with 4 special dates and if all comparisons reflect the required relation,
-- the restriction is considdered as valid.

fctTableDuration :: [(String, String -> Duration -> Bool)]
fctTableDuration
  = [ (xsd_maxExclusive, cvi (>))
    , (xsd_minExclusive, cvi (<))
    , (xsd_maxInclusive, cvi (>=))
    , (xsd_minInclusive, cvi (<=))
    ]
    where
    cvi :: (Duration -> Duration -> Bool) -> (String -> Duration -> Bool)
    cvi op = \ x y -> isDuration x && readDuration x `op` y

-- | Tests whether an duration value is valid
durationValid :: ParamList -> CheckA Duration Duration
durationValid params
  = (foldr (>>>) ok . map paramDurationValid $ params)
    where
    paramDurationValid (pn, pv)
      = assert
        ((fromMaybe (const . const $ True) . lookup pn $ fctTableDuration) pv)
        (errorMsgParam pn pv . showDuration)

-- ----------------------------------------

rexDateTime, rexDate, rexTime :: Regex
(rexDateTime, rexDate, rexTime)
    = (rex dateTime, rex date, rex time)
    where
      date     = ymd'               ++ tz
      dateTime = ymd' ++ "T" ++ hms ++ tz
      time     =                hms ++ tz

      ymd   = "-?" ++ y4 ++ "-" ++ m2 ++ "-" ++ t2
      ymd'  = y42 ++ ymd

      hms   = alt (h2 ++ ":" ++ i2 ++ ":" ++ s2 ++ fr)
                  ("24:00:00" ++ opt ".0+")             -- 24:00 is legal

      tz    = opt (alt tz0 "Z")
      tz0   = (alt "\\-" "\\+") ++ tz1
      tz1   = alt (h13 ++ ":" ++ i2) "14:00:00"

      m2    = alt "0[1-9]" "1[0-2]"			-- Month
      t2    = alt "0[1-9]" (alt "[12][0-9]" "3[01]")    -- Tag
      h2    = alt "[01][0-9]" "2[0-3]"                  -- Hour
      i2    = "[0-5][0-9]"                              -- mInute
      s2    = i2                                        -- Seconds

      y4    = "[0-9]{4}"

      y42   = opt "[1-9][0-9]*"
      fr    = opt ".[0-9]+"

      h13   = alt "0[0-9]" "1[0-3]"

      opt x     = "(" ++ x ++ ")?"
      alt x y   = "((" ++ x ++ ")|(" ++ y ++ "))"

-- ----------------------------------------

-- | Transforms a base64 value
normBase64 :: String -> String
normBase64 = filter isB64
             where
             isB64 c = ( 'A' <= c && c <= 'Z')
                       ||
                       ( 'a' <= c && c <= 'z')
                       ||
                       ( '0' <= c && c <= '9')
                       ||
                       c == '+'
                       ||
                       c == '/'
                       ||
                       c == '='

-- ----------------------------------------

-- | Reads a decimal from a string
readDecimal :: String -> Rational
readDecimal ('+':s) = readDecimal' s
readDecimal ('-':s) = negate $ readDecimal' s
readDecimal      s  = readDecimal' s

-- | Helper function to read a decimal from a string
readDecimal' :: String -> Rational
readDecimal' s
  | f == 0    = (n % 1)
  | otherwise = (n % 1) + (f % (10 ^ (toInteger $ length fs)))
  where
  (ns, fs') = span (/= '.') s
  fs = drop 1 fs'

  f :: Integer
  f | null fs   = 0
    | otherwise = read fs
  n :: Integer
  n | null ns   = 0
    | otherwise = read ns

-- | Reads total digits of a rational
totalDigits :: Rational -> Int
totalDigits r
  | r == 0    = 0
  | r < 0     = totalDigits' . negate  $ r
  | otherwise = totalDigits'           $ r

-- | Helper function to read total digits of a rational
totalDigits' :: Rational -> Int
totalDigits' r
  | denominator r == 1 = length . show . numerator  $ r
  | r < (1%1)          = (\ x -> x-1) . totalDigits' . (+ (1%1))    $ r
  | otherwise          = totalDigits' . (* (10 % 1)) $ r

-- | Reads fraction digits of a rational
fractionDigits :: Rational -> Int
fractionDigits r
  | denominator r == 1 = 0
  | otherwise          = (+1) . fractionDigits . (* (10 % 1)) $ r

-- | Transforms a decimal into a string
showDecimal :: Rational -> String
showDecimal d
  | d < 0     = ('-':) . showDecimal' . negate    $ d
  | d < 1     = drop 1 . showDecimal' . (+ (1%1)) $ d
  | otherwise =          showDecimal'             $ d

-- | Helper function to transform a decimal into a string
showDecimal' :: Rational -> String
showDecimal' d
  | denominator d == 1 = show . numerator $ d
  | otherwise          = times10 0        $ d
  where
  times10 i' d'
    | denominator d' == 1 = let
                            (x, y) = splitAt i' . reverse . show . numerator $ d'
                            in
                            reverse y ++ "." ++ reverse x
    | otherwise           = times10 (i' + 1) (d' * (10 % 1))

-- ----------------------------------------

-- | Tests whether value matches a given datatype and parameter list

datatypeAllowsW3C :: DatatypeName -> ParamList -> String -> Maybe String
datatypeAllowsW3C d params value
  = performCheck check value
    where
    validString normFct
      = validPattern
        >>> arr normFct
        >>> validLength

    validNormString
      = validString normalizeWhitespace

    validPattern
      = patternValid params

    validLength
      = stringValid d 0 (-1) params

    validList
      = validPattern
        >>> arr normalizeWhitespace
        >>> validListLength

    validListLength
      = listValid d params

    validName isN
      = assertW3C isN

    validNCName
      = validNormString
        >>> validName isNCName

    validQName
      = validNormString
        >>> validName isWellformedQualifiedName

    validDecimal
      = validPattern
        >>> arr normalizeWhitespace
        >>> assertW3C isDecimal
        >>> checkWith readDecimal (decimalValid params)

    validInteger inRange
      = validPattern
        >>> arr normalizeWhitespace
        >>> assertW3C isInteger
        >>> checkWith read (integerValid inRange params)

    validFloating validFl
        = validPattern
          >>> assertW3C isFloating
          >>> checkWith readFloating (validFl d params)

    validBoolean
        = validNormString
          >>> validPattern
          >>> assertW3C (matchRE rexBoolean)

    validDuration
      = validPattern
        >>> arr normalizeWhitespace
        >>> assertW3C isDuration
        >>> checkWith readDuration (durationValid params)

    check :: CheckA String String
    check = fromMaybe notFound . lookup d $ checks

    notFound = failure $ errorMsgDataTypeNotAllowed d params

    checks :: [(String, CheckA String String)]
    checks = [ (xsd_string,             validString id)
             , (xsd_normalizedString,   validString normalizeBlanks)

             , (xsd_token,              validNormString)
             , (xsd_language,           validNormString >>> assertW3C isLanguage)

             , (xsd_NMTOKEN,            validNormString >>> validName isNmtoken)
             , (xsd_NMTOKENS,           validList       >>> validName (isNameList isNmtoken))

             , (xsd_Name,               validNormString >>> validName isName)
             , (xsd_NCName,             validNCName)
             , (xsd_ID,                 validNCName)
             , (xsd_IDREF,              validNCName)
             , (xsd_IDREFS,             validList       >>> validName (isNameList isNCName))
             , (xsd_ENTITY,             validNCName)
             , (xsd_ENTITIES,           validList       >>> validName (isNameList isNCName))

             , (xsd_anyURI,             validName isURIReference >>> validString escapeURI)
             , (xsd_QName,              validQName)
             , (xsd_NOTATION,           validQName)

             , (xsd_hexBinary,          validString id         >>> assertW3C isHexBinary)
             , (xsd_base64Binary,       validString normBase64 >>> assertW3C isBase64Binary)

             , (xsd_boolean,            validBoolean)
             , (xsd_decimal,            validDecimal)
             , (xsd_double,             validFloating doubleValid)
             , (xsd_float,              validFloating floatValid)

             , (xsd_integer,            validInteger xsd_integer)
             , (xsd_nonPositiveInteger, validInteger xsd_nonPositiveInteger)
             , (xsd_negativeInteger,    validInteger xsd_negativeInteger)
             , (xsd_nonNegativeInteger, validInteger xsd_nonNegativeInteger)
             , (xsd_positiveInteger,    validInteger xsd_positiveInteger)
             , (xsd_long,               validInteger xsd_long)
             , (xsd_int,                validInteger xsd_int)
             , (xsd_short,              validInteger xsd_short)
             , (xsd_byte,               validInteger xsd_byte)
             , (xsd_unsignedLong,       validInteger xsd_unsignedLong)
             , (xsd_unsignedInt,        validInteger xsd_unsignedInt)
             , (xsd_unsignedShort,      validInteger xsd_unsignedShort)
             , (xsd_unsignedByte,       validInteger xsd_unsignedByte)

             , (xsd_duration,           validDuration)
             ]
    assertW3C p = assert p errW3C
    errW3C      = errorMsgDataDoesNotMatch d

-- ----------------------------------------
