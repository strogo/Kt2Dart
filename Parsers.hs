{-# LANGUAGE FlexibleContexts #-}

module Parsers where

import Data.Char
import Data.List
import Control.Monad
import Control.Applicative

alpha :: String
alpha = ['a'..'z'] ++ ['A'..'Z']

nums :: String
nums = ['0' .. '9']

-----------------------------------------------------
--------------- my parser combinator ----------------
-----------------------------------------------------

newtype Parser val = Parser { parse :: String -> [(val, String)]  }

parseCode :: Parser a -> String -> a
parseCode m s = case parse m s of
  [(res, [])] -> res
  _           -> error "Hugh?"
--

instance Functor Parser where
  fmap f (Parser ps) = Parser $ \p -> [ (f a, b) | (a, b) <- ps p ]
--

instance Applicative Parser where
  pure = return
  (Parser p1) <*> (Parser p2) = Parser $ \p ->
    [ (f a, s2) | (f, s1) <- p1 p, (a, s2) <- p2 s1 ]
--

instance Monad Parser where
  return a = Parser $ \s -> [(a, s)]
  p >>= f  = Parser $ concatMap (\(a, s1) -> f a `parse` s1) . parse p
--

instance MonadPlus Parser where
  mzero     = Parser $ const []
  mplus p q = Parser $ \s -> parse p s ++ parse q s
--

instance Alternative Parser where
  empty   = mzero
  p <|> q = Parser $ \s -> case parse p s of
    [] -> parse q s
    rs -> rs
--

item :: Parser Char
item = Parser $ \s -> case s of
  [     ] -> [      ]
  (h : t) -> [(h, t)]
--

satisfy :: (Char -> Bool) -> Parser Char
satisfy p = item >>= \c -> if p c then return c else empty

chainl1 :: Parser a -> Parser (a -> a -> a) -> Parser a
chainl1 p op = do
  a <- p
  rest a
  where
    rest a = (do
      f <- op
      b <- p
      rest $ f a b)
      <|> return a
--

chainr1 :: Parser a -> Parser (a -> a -> a) -> Parser a
chainr1 p op = scan
  where
    scan = do
      a <- p
      rest a
    rest a = (do
      f <- op
      b <- scan
      rest $ f a b)
      <|> return a
--

option1 :: Parser a -> Parser (a -> a -> a) -> Parser a
option1 p op = do
  a <- p
  (do
      f <- op
      b <- p
      return $ f a b)
    <|> return a
--

chainl :: Parser a -> Parser (a -> a -> a) -> a -> Parser a
chainl p op = (chainl1 p op <|>) . return

op :: String -> a -> Parser a
op = op1 . stringP

op1 :: Parser a -> b -> Parser b
op1 s = (s >>) . return

bracketsP :: Parser b -> Parser b
bracketsP m = do
  reservedP "("
  n <- m
  reservedP ")"
  return n
--

oneOf :: String -> Parser Char
oneOf = satisfy . flip elem

charP :: Char -> Parser Char
charP = satisfy . (==)

natP :: Parser Int
natP = read <$> some digitP

digitP :: Parser Char
digitP = satisfy isDigit

reservedP :: String -> Parser String
reservedP = tokenP . stringP

spacesP :: Parser String
spacesP = many $ oneOf " \n\r\t"

stringP :: String -> Parser String
stringP [      ] = return []
stringP (c : cs) = do
  charP c
  stringP cs
  return $ c : cs
--

tokenP :: Parser a -> Parser a
tokenP p = do
  a <- p
  spacesP
  return a
--

nameP :: Parser String
nameP = do
  n <- some $ oneOf $ '_' : '@' : (alpha ++ nums)
  spacesP
  return n
--

numberP :: Parser String
numberP = do
  s <- stringP "-" <|> return []
  cs <- some digitP
  spacesP
  return $ s ++ cs
--

allNameP :: Parser String
allNameP = nameP <|> numberP