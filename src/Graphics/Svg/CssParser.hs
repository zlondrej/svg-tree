{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternGuards #-}
module Graphics.Svg.CssParser
    ( CssElement( .. )
    , complexNumber
    , declaration
    , ruleSet
    , styleString
    , dashArray
    , numberList
    , num
    , cssRulesOfText
    )
    where

#if !MIN_VERSION_base(4,8,0)
import Control.Applicative( (<*>), (<*), (*>)
                          , (<$>), (<$)
                          , pure
                          )
#endif

import Control.Applicative( (<|>)
                          , many
                          )
import Data.Attoparsec.Text
    ( Parser
    , double
    , string
    , skipSpace
    , letter
    , char
    , digit
    , sepBy1
    , (<?>)
    , skipMany
    , notChar
    , parseOnly
    , satisfy
    )
import qualified Data.Attoparsec.Text as AT

import Data.Attoparsec.Combinator
    ( option
    , sepBy
    , many'
    , many1
    , choice
    )

import Numeric ( readHex )
import Data.Char ( chr, isAscii, isHexDigit )
import Codec.Picture( PixelRGBA8( .. ) )
import Graphics.Svg.Types
import Graphics.Svg.NamedColors( svgNamedColors )
import Graphics.Svg.ColorParser( colorParser )
import Graphics.Svg.CssTypes
import qualified Data.Text as T
import qualified Data.Map as M
{-import Graphics.Rasterific.Linear( V2( V2 ) )-}
{-import Graphics.Rasterific.Transformations-}

num :: Parser Double
num = realToFrac <$> (skipSpace *> plusMinus <* skipSpace)
  where doubleNumber = char '.' *> (scale <$> double)
                    <|> double

        scalingCoeff n = 10 ^ digitCount
          where digitCount :: Int
                digitCount = ceiling . logBase 10 $ abs n

        scale n = n / scalingCoeff n

        plusMinus = negate <$ string "-" <*> doubleNumber
                 <|> string "+" *> doubleNumber
                 <|> doubleNumber


-- https://www.w3.org/TR/css-syntax-3/#ident-token-diagram
ident :: Parser T.Text
ident = T.append <$> idstart <*> idtail
  where
    ts = fmap T.singleton
    -- https://www.w3.org/TR/css-syntax-3/#would-start-an-identifier
    idstart :: Parser T.Text
    idstart = choice
      [ T.append <$> ts hyphen
                 <*> ts (namestartcp <|> hyphen <|> escsequence)
      , ts namestartcp
      , ts escsequence
      ]
    idtail :: Parser T.Text
    idtail = T.pack <$> many' (namecp <|> escsequence)
    underscore :: Parser Char
    underscore = char '_'
    hyphen :: Parser Char
    hyphen = char '-'
    -- https://www.w3.org/TR/css-syntax-3/#name-start-code-point
    namestartcp :: Parser Char
    namestartcp = letter <|> underscore <|> nonAscii
    -- https://www.w3.org/TR/css-syntax-3/#name-code-point
    namecp :: Parser Char
    namecp = namestartcp <|> digit <|> hyphen
    nonAscii :: Parser Char
    nonAscii = satisfy $ not . isAscii
    -- https://www.w3.org/TR/css-syntax-3/#escape-diagram
    escsequence :: Parser Char
    escsequence = char '\\' *>
      ((hexUcode "" <* skipOptionalWhitespace) <|> notNewLineOrHex)
    notNewLineOrHex :: Parser Char
    notNewLineOrHex = satisfy (\c -> c /= '\n' && not (isHexDigit c))
    hexUcode :: String -> Parser Char
    hexUcode xs = case xs of
      [] -> hex >>= \c -> hexUcode [c]
      _   | length xs == 6 -> pure $ fromUcode xs
          | otherwise -> (hex >>= (hexUcode . (:xs))) <|> (pure $ fromUcode xs)
    hex = satisfy isHexDigit
    fromUcode :: String -> Char
    fromUcode = chr . fst . head . readHex . reverse
    -- https://www.w3.org/TR/css-syntax-3/#whitespace-diagram
    whitespace :: Parser Char
    whitespace = satisfy (`elem` (" \n\t" :: String))
    skipOptionalWhitespace :: Parser ()
    skipOptionalWhitespace = option () (() <$ whitespace)

str :: Parser T.Text
str = char '"' *> AT.takeWhile (/= '"') <* char '"' <* skipSpace
   <?> "str"

between :: Char -> Char -> Parser a -> Parser a
between o e p =
  (skipSpace *>
      char o *> skipSpace *> p
           <* skipSpace <* char e <* skipSpace)
           <?> ("between " ++ [o, e])

bracket :: Parser a -> Parser a
bracket = between '[' ']'


comment :: Parser ()
comment = string "/*" *> toStar *> skipSpace
  where
    toStar = skipMany (notChar '*') *> char '*' *> testEnd
    testEnd = (() <$ char '/') <|> toStar

cleanSpace :: Parser ()
cleanSpace = skipSpace <* many comment

-- | combinator: '+' S* | '>' S*
combinator :: Parser CssSelector
combinator = parse <* cleanSpace where
  parse = Nearby <$ char '+'
       <|> DirectChildren <$ char '>'
       <?> "combinator"

-- unary_operator : '-' | '+' ;

commaWsp :: Parser Char
commaWsp = skipSpace *> option ',' (char ',') <* skipSpace

ruleSet :: Parser CssRule
ruleSet = cleanSpace *> rule where
  rule = CssRule
      <$> selector `sepBy1` commaWsp
      <*> (between '{' '}' styleString)
      <?> "cssrule"

styleString :: Parser [CssDeclaration]
styleString = ((cleanSpace *> declaration) `sepBy` semiWsp) <* mayWsp
           <?> "styleString"
  where semiWsp = skipSpace *> char ';' <* skipSpace
        mayWsp = option ';' semiWsp

selector :: Parser [CssSelector]
selector = (:)
        <$> (AllOf <$> simpleSelector <* skipSpace <?> "firstpart:(")
        <*> ((next <|> return []) <?> "secondpart")
        <?> "selector"
  where
    combOpt :: Parser ([CssSelector] -> [CssSelector])

    combOpt = cleanSpace *> option id ((:) <$> combinator)
    next :: Parser [CssSelector]
    next = id <$> combOpt <*> selector

simpleSelector :: Parser [CssDescriptor]
simpleSelector = (:) <$> elementName <*> many whole
              <|> (many1 whole <?> "inmany")
              <?> "simple selector"
 where
  whole = pseudo <|> hash <|> classParser <|> attrib
       <?> "whole"
  pseudo = char ':' *> (OfPseudoClass <$> ident)
        <?> "pseudo"
  hash = char '#' *> (OfId <$> ident)
      <?> "hash"
  classParser = char '.' *> (OfClass <$> ident)
              <?> "classParser"

  elementName = el <* skipSpace <?> "elementName"
    where el = (OfName <$> ident)
            <|> AnyElem <$ char '*'

  attrib = bracket
    (WithAttrib <$> ident <*> (char '=' *> skipSpace *> (ident <|> str))
           <?> "attrib")

declaration :: Parser CssDeclaration
declaration =
  CssDeclaration <$> property
                 <*> (char ':'
                      *> cleanSpace
                      *> many1 expr
                      <* prio
                      )
                 <?> "declaration"
  where
    property = (ident <* cleanSpace) <?> "property"
    prio = option "" $ string "!important"

operator :: Parser CssElement
operator = skipSpace *> op <* skipSpace
  where
    op = CssOpSlash <$ char '/'
      <|> CssOpComa <$ char ','
      <?> "operator"

expr :: Parser [CssElement]
expr = ((:) <$> term <*> (concat <$> many termOp))
    <?> "expr"
  where
    op = option (:[]) $ (\a b -> [a, b]) <$> operator
    termOp = ($) <$> op <*> term

dashArray :: Parser [Number]
dashArray = skipSpace *> (complexNumber `sepBy1` commaWsp)

numberList :: Parser [Double]
numberList = skipSpace *> (num `sepBy1` commaWsp)

complexNumber :: Parser Number
complexNumber = do
    n <- num
    (Percent (n / 100) <$ char '%')
        <|> (Em n <$ string "em")
        <|> (Mm n <$ string "mm")
        <|> (Cm n <$ string "cm")
        <|> (Point n <$ string "pt")
        <|> (Pc n <$ string "pc")
        <|> (Px n <$ string "px")
        <|> (Inches n <$ string "in")
        <|> pure (Num n)

term :: Parser CssElement
term = checkRgb <$> function
    <|> (CssNumber <$> complexNumber)
    <|> (CssString <$> str)
    <|> (checkNamedColor <$> ident)
    <|> (CssColor <$> colorParser)
  where
    comma = skipSpace *> char ',' <* skipSpace
    checkNamedColor n
        | Just c <- M.lookup n svgNamedColors = CssColor c
        | otherwise = CssIdent n

    ref = char '#' *> ident

    checkRgb (CssFunction "rgb"
                [CssNumber r, CssNumber g, CssNumber b]) =
        CssColor $ PixelRGBA8 (to r) (to g) (to b) 255
       where clamp = max 0 . min 255
             to (Num n) = floor $ clamp n
             to (Px n) = floor $ clamp n
             to (Percent p) = floor . clamp $ p * 255
             to (Em c) = floor $ clamp c
             to (Pc n) = floor $ clamp n
             to (Mm n) = floor $ clamp n
             to (Cm n) = floor $ clamp n
             to (Point n) = floor $ clamp n
             to (Inches n) = floor $ clamp n

    checkRgb a = a
    functionParam = (CssReference <$> ref) <|> term

    function = CssFunction
       <$> ident <* char '('
       <*> (functionParam `sepBy` comma) <* char ')' <* skipSpace

-- | Parse CSS text into rules.
cssRulesOfText :: T.Text -> [CssRule]
cssRulesOfText txt = case parseOnly (many1 ruleSet) $ txt of
    Left _ -> []
    Right rules -> rules

