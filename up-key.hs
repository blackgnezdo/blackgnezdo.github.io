-- make | ~/up-key && make update-plist && make package && doas make install
{-# LANGUAGE BangPatterns #-}

import Data.List
import System.IO.Error
import System.Process

accumulate f !v = do
  catchIOError (do
    r <- getLine
    putStrLn r
    accumulate f (f v r))
    (const $ pure v)

main = do
  val <- accumulate lookForId Empty
  case val of
    Match s -> updateMakeFile s >>= print
    v -> print v

data State = Empty | Ready | Match String deriving Show

lookForId Empty s =
  if "Ready component graph:" `isPrefixOf` s then Ready else Empty
lookForId Ready s =
  Match $ reverse $ takeWhile (/= '-') $ reverse s
lookForId m _ = m

updateMakeFile s =
  rawSystem "perl" [
    "-i",
    "-pne",
    "s/^(MODGHC_PACKAGE_KEY\\s*=\\s*)\\S+$/${1}" ++ s ++ "/",
    "Makefile"
  ]
