{-# LANGUAGE MultiParamTypeClasses, FunctionalDependencies, UndecidableInstances, FlexibleInstances, FlexibleContexts #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Text.Trifecta.Parser.Class
-- Copyright   :  (c) Edward Kmett 2011
-- License     :  BSD3
-- 
-- Maintainer  :  ekmett@gmail.com
-- Stability   :  experimental
-- Portability :  non-portable
-- 
-----------------------------------------------------------------------------
module Text.Trifecta.Parser.Class 
  ( MonadParser(..)
  , satisfyAscii
  , restOfLine
  , (<?>)
  , skipping
  , slicedWith
  , sliced
  , rend
  ) where

import Control.Applicative
import Control.Monad (MonadPlus(..))
import Control.Monad.Trans.Class
import Control.Monad.Trans.State.Lazy as Lazy
import Control.Monad.Trans.State.Strict as Strict
import Control.Monad.Trans.Writer.Lazy as Lazy
import Control.Monad.Trans.Writer.Strict as Strict
import Control.Monad.Trans.RWS.Lazy as Lazy
import Control.Monad.Trans.RWS.Strict as Strict
import Control.Monad.Trans.Reader
import Control.Monad.Trans.Identity
import Data.Functor.Yoneda
import Data.Word
import Data.ByteString as Strict
import Data.ByteString.Internal (w2c)
import Data.Semigroup
import Data.Set as Set
import Text.Trifecta.Rope.Delta
import Text.Trifecta.Rope.Prim
import Text.Trifecta.Parser.It
import Text.Trifecta.Parser.Token.Highlight
import Text.Trifecta.Diagnostic.Rendering.Prim
-- import Control.Monad.Trans.Maybe.Strict as Strict
-- import Control.Monad.Trans.Either.Strict as Strict
-- import Control.Monad.Codensity

infix 0 <?>

class ( Alternative m, MonadPlus m) => MonadParser m where
  -- | Take a parser that may consume input, and on failure, go back to where we started and fail as if we didn't consume input.
  try :: m a -> m a
  -- Used to implement (<?>), runs the parser then sets the 'expected' tokens to the list supplied
  labels     :: m a -> Set String -> m a
  -- | Lift an operation from the primitive It monad
  liftIt     :: It Rope a -> m a
 
  -- | mark the current location so it can be used in constructing a span, or for later seeking
  mark       :: m Delta
  -- | Used to emit an error on an unexpected token
  unexpected :: MonadParser m => String -> m a

  -- | Retrieve the contents of the current line (from the beginning of the line)
  line       :: m ByteString

  -- | A version of many that discards its input. Specialized because it can often be implemented more cheaply.
  skipMany   :: m a -> m ()
  skipMany p = () <$ many p 

  -- actions that definitely commit

  -- | Seek back to previously marked location
  release  :: Delta -> m ()

  -- | Parse a single character of the input, with UTF-8 decoding
  satisfy  :: (Char -> Bool) -> m Char

  -- | Parse a single byte of the input, without UTF-8 decoding
  satisfy8 :: (Word8 -> Bool) -> m Word8

  -- | @highlightToken@ is called internally in the token parsers.
  -- It delimits ranges of the input recognized by certain parsers that 
  -- are useful for syntax highlighting. An interested monad could
  -- choose to listen to these events and construct an interval tree
  -- for later pretty printing purposes.
  highlightToken :: TokenHighlight -> m a -> m a
  highlightToken _ m = m

instance MonadParser m => MonadParser (Lazy.StateT s m) where
  try (Lazy.StateT m) = Lazy.StateT $ try . m
  labels (Lazy.StateT m) ss = Lazy.StateT $ \s -> labels (m s) ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (Lazy.StateT m) = Lazy.StateT $ \e -> highlightToken t (m e) 

instance MonadParser m => MonadParser (Strict.StateT s m) where
  try (Strict.StateT m) = Strict.StateT $ try . m
  labels (Strict.StateT m) ss = Strict.StateT $ \s -> labels (m s) ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (Strict.StateT m) = Strict.StateT $ \e -> highlightToken t (m e) 

instance MonadParser m => MonadParser (ReaderT e m) where
  try (ReaderT m) = ReaderT $ try . m
  labels (ReaderT m) ss = ReaderT $ \s -> labels (m s) ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (ReaderT m) = ReaderT $ \e -> highlightToken t (m e) 

instance (MonadParser m, Monoid w) => MonadParser (Strict.WriterT w m) where
  try (Strict.WriterT m) = Strict.WriterT $ try m
  labels (Strict.WriterT m) ss = Strict.WriterT $ labels m ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (Strict.WriterT m) = Strict.WriterT $ highlightToken t m

instance (MonadParser m, Monoid w) => MonadParser (Lazy.WriterT w m) where
  try (Lazy.WriterT m) = Lazy.WriterT $ try m
  labels (Lazy.WriterT m) ss = Lazy.WriterT $ labels m ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (Lazy.WriterT m) = Lazy.WriterT $ highlightToken t m

instance (MonadParser m, Monoid w) => MonadParser (Lazy.RWST r w s m) where
  try (Lazy.RWST m) = Lazy.RWST $ \r s -> try (m r s)
  labels (Lazy.RWST m) ss = Lazy.RWST $ \r s -> labels (m r s) ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (Lazy.RWST m) = Lazy.RWST $ \r s -> highlightToken t (m r s)

instance (MonadParser m, Monoid w) => MonadParser (Strict.RWST r w s m) where
  try (Strict.RWST m) = Strict.RWST $ \r s -> try (m r s)
  labels (Strict.RWST m) ss = Strict.RWST $ \r s -> labels (m r s) ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (Strict.RWST m) = Strict.RWST $ \r s -> highlightToken t (m r s)

instance MonadParser m => MonadParser (IdentityT m) where
  try (IdentityT m) = IdentityT $ try m
  labels (IdentityT m) = IdentityT . labels m
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (IdentityT m) = IdentityT $ highlightToken t m

instance MonadParser m => MonadParser (Yoneda m) where
  try = lift . try . lowerYoneda
  labels m ss = lift $ labels (lowerYoneda m) ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
  highlightToken t (Yoneda m) = Yoneda $ \f -> highlightToken t (m f)

{-
instance MonadParser m => MonadParser (Codensity m) where
  try = lift . try . lowerCodensity
  labels m ss = lift $ labels (lowerCodensity m) ss
  line = lift line
  liftIt = lift . liftIt
  mark = lift mark 
  release = lift . release
  unexpected = lift . unexpected
  satisfy = lift . satisfy
  satisfy8 = lift . satisfy8
-}
-- instance (MonadParser m, Monoid w) => MonadParser (MaybeT m) where
-- instance (Error e, MonadParser m, Monoid w) => MonadParser (ErrorT e m) where

satisfyAscii :: MonadParser m => (Char -> Bool) -> m Char
satisfyAscii p = w2c <$> satisfy8 (\w -> w <= 0x7f && p (w2c w))
{-# INLINE satisfyAscii #-}


-- useful when we've just recognized something out of band using access to the current line 
skipping :: MonadParser m => Delta -> m ()
skipping d = do
  m <- mark
  release (m <> d)
{-# INLINE skipping #-}

-- | grab the remainder of the current line
restOfLine :: MonadParser m => m ByteString
restOfLine = do
  m <- mark
  Strict.drop (columnByte m) <$> line
{-# INLINE restOfLine #-}

-- | label a parser with a name
(<?>) :: MonadParser m => m a -> String -> m a
p <?> msg = labels p (Set.singleton msg)

-- | run a parser, grabbing all of the text between its start and end points
slicedWith :: MonadParser m => (a -> Strict.ByteString -> r) -> m a -> m r
slicedWith f pa = do
  m <- mark
  a <- pa
  r <- mark
  liftIt $ f a <$> sliceIt m r
{-# INLINE slicedWith #-}

-- | run a parser, grabbing all of the text between its start and end points and discarding the original result
sliced :: MonadParser m => m a -> m ByteString
sliced = slicedWith (\_ bs -> bs)
  
rend :: MonadParser m => m Rendering
rend = rendering <$> mark <*> line
{-# INLINE rend #-}


