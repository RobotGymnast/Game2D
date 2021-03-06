{-# LANGUAGE NoImplicitPrelude
           , FlexibleInstances
           , FlexibleContexts
           , UndecidableInstances
           , MultiParamTypeClasses
           , TemplateHaskell
           #-}
-- | Static size, homogenous Vector type
module Game.Vector ( Vector (..)
                   , Dimension (..)
                   , Direction
                   , dimensions
                   , component
                   , component'
                   , setV
                   , singleV
                   , vector
                   , magnitude
                   , normalize
                   , dot
                   , test
                   ) where

import Summit.Prelewd
import Summit.Data.Member
import Summit.Test

import Data.Maybe
import Data.Tuple

import Text.Show

-- | Physical dimensions in the game
data Dimension = Width | Height
    deriving (Show, Eq, Ord, Enum, Bounded)

type Direction = (Dimension, Bool)

instance Arbitrary Dimension where
    arbitrary = elements [minBound..maxBound]

-- | Vector associating each dimension to a vector component
dimensions :: Vector Dimension
dimensions = Vector Width Height

-- | Homogenous vector. When possible, use predefined functions, rather than the Vector data constructor.
-- Code should strive to be generic with respect to the number of dimensions in a Vector.
data Vector a = Vector a a
    deriving (Eq, Show)

instance Num a => Num (Vector a) where
    (+) = liftA2 (+)
    (*) = liftA2 (*)
    negate = map negate
    abs = map abs
    signum = map signum
    fromInteger = pure . fromInteger

instance Fractional a => Fractional (Vector a) where
    recip = map recip
    fromRational = pure . fromRational

instance Real a => Ord (Vector a) where
    compare = compare `on` (dot <*> \x->x)

instance Applicative Vector where
    pure x = Vector x x 
    (Vector fx fy) <*> (Vector x y) = Vector (fx x) (fy y)

instance Functor Vector where fmap = liftA

instance Foldable Vector where
    foldr f b (Vector x y) = foldr f b [x, y]

instance Ord a => Member Vector a

instance Applicative f => Sequential Vector f a where
    sequence (Vector x y) = Vector <$> x <*> y

instance Applicative f => Traversable Vector f a b

instance Arbitrary a => Arbitrary (Vector a) where
    arbitrary = sequence $ pure arbitrary

-- | Get a single component from a vector
component :: Dimension -> Vector a -> a
component d = fromJust . foldr (\(d', x) a -> a <|> mcond (d == d') x) Nothing . liftA2 (,) dimensions

-- | Transform a single component from a vector
component' :: Dimension -> (a -> a) -> Vector a -> Vector a
component' = transform <$> component <*> setV

-- | Set one dimension of a vector
setV :: Dimension -> a -> Vector a -> Vector a
setV d x = liftA2 (\d' -> iff (d == d') x) dimensions

-- | Construct a vector with one element different from the others
singleV :: a -> Dimension -> a -> Vector a
singleV zero d x = setV d x $ pure zero

-- | Construct a vector from a Dimension-value mapping
vector :: Foldable t => a -> t (Dimension, a) -> Vector a
vector = foldr (uncurry setV) . pure

-- | Magnitude of a vector
magnitude :: Floating a => Vector a -> a
magnitude v = sqrt $ dot v v

-- | Redcue a vector's magnitude to 1
normalize :: (Eq a, Floating a) => Vector a -> Vector a
normalize 0 = 0
normalize v = v <&> (/ magnitude v)

-- | Dot product
dot :: Num a => Vector a -> Vector a -> a
dot = sum <$$> (*)

test :: Test
test = $(testGroupGenerator)

prop_dimExists :: Dimension -> Bool
prop_dimExists = (`elem` dimensions)

prop_index :: Vector Integer -> Bool
prop_index v = and $ fmap index $ indices v
    where
        index i = (v ! fromIntegral i) == (toList v ! fromIntegral i)

prop_ordAssoc :: (Vector Integer, Vector Integer, Vector Integer) -> Bool
prop_ordAssoc (x, y, z) = min (min x y) z == min x (min y z)

prop_shortMult :: (Vector Integer, Vector Integer, Integer) -> Bool
prop_shortMult (x, y, c) = fmap (c*) (min x y) == (min `on` fmap (c*)) x y

prop_dotCommute :: (Vector Integer, Vector Integer) -> Bool
prop_dotCommute (x, y) = dot x y == dot y x

prop_dotMult :: (Vector Integer, Vector Integer, Integer) -> Bool
prop_dotMult (v, w, c) = c * dot v w == dot ((c *) <$> v) w

prop_dotAssoc :: (Vector Integer, Vector Integer, Vector Integer) -> Bool
prop_dotAssoc (x, y, z) =  (dot x (y <&> (+) <*> z)) == dot x y + dot x z
                        && (dot (x <&> (+) <*> y) z) == dot x z + dot y z

prop_triangle :: (Vector Double, Vector Double, Vector Double) -> Bool
prop_triangle (x, y, z) = magnitude (x - y) + magnitude (x - z) >= magnitude (y - z)

prop_doubleSet :: (Vector Integer, Dimension, Integer) -> Bool
prop_doubleSet (v, d, x) = let set = setV d x v
                           in set == setV d x set

indices :: Vector a -> [Integer]
indices v = [0 .. length v - 1]
