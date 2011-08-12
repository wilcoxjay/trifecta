module Text.Trifecta.Parser
  ( module Text.Trifecta.Parser.Prim
  , module Text.Trifecta.Parser.Class
  , module Text.Trifecta.Parser.Char
  , module Text.Trifecta.Parser.Combinators
  , module Text.Trifecta.Parser.Token
  , module Text.Trifecta.Parser.Result
  -- * traditional numeric literals that would be in Token
  , decimal
  , hexadecimal
  , octal
  -- * expressive diagnostics
  , caret
  , careted
  , span
  , spanned
  , fixit
  ) where

import Text.Trifecta.Parser.Prim
import Text.Trifecta.Parser.Class
import Text.Trifecta.Parser.Char
import Text.Trifecta.Parser.Combinators
import Text.Trifecta.Parser.Literals
import Text.Trifecta.Parser.Token
import Text.Trifecta.Parser.Result

import Text.Trifecta.Diagnostic.Rendering.Caret (caret, careted)
import Text.Trifecta.Diagnostic.Rendering.Span  (span, spanned)
import Text.Trifecta.Diagnostic.Rendering.Fixit (fixit)

import Prelude ()
