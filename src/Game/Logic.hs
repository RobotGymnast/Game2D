module Game.Logic ( GameObject (..)
                  , ObjectType (..)
                  , GameState (..)
                  , Input (..)
                  , Direction(..)
                  , initState
                  , update
                  ) where

import Prelude ()
import Util.Prelewd

import Util.Types

type Position = Vector Double
type Size = Vector Double
type Velocity = Vector Double

data ObjectType = Block
                | Platform
    deriving (Eq)

data GameObject = GameObject { objType :: ObjectType
                             , posn :: Position
                             , vcty :: Velocity
                             , size :: Size
                             }

data GameState = GameState { objects :: [GameObject]
                           }

data Direction = Up | Down | Left | Right
    deriving (Eq)

data Input = Move ObjectType Direction
    deriving (Eq)

-- | Fold right-to-left and generate a list.
foldCons :: (b -> a -> (b, a))
         -> b
         -> [a]
         -> (b, [a])
foldCons f x0 = foldr (\x (b, l) -> (:l) <$> f b x) (x0, []) 

-- | Start state of the game world
initState :: GameState
initState = GameState [ GameObject Block (Vector 0 0) (Vector 1 10) (Vector 1 1)
                      , GameObject Platform (Vector 0 (-1.5)) (Vector 0 0) (Vector 4 1)
                      ]

collisionHandler :: GameObject       -- ^ Object to update
                 -> GameObject       -- ^ Object it collided with
                 -> Vector Collision -- ^ Description of the specific collision
                 -> GameObject       -- ^ Updated object
collisionHandler g1 g2 _ = if' (objType g2 == Platform) (`bump` g2) g1

-- | `bump p q` returns `p`, readjusted in position to not overlap `q`.
bump :: GameObject -> GameObject -> GameObject
bump p1 p2 = let
                allBumps = bumps1 <$> posn p1 <*> size p1 <*> posn p2 <*> size p2
                -- The bumps as vectors
                vBumps = concat $ fmap . singleV <$> vector [0..] <*> allBumps
                bumpVector = foldr1 shorter $ filter ((>= 0) . dot (vcty p1)) vBumps
             in p1 { posn = posn p1 <&> (-) <*> bumpVector
                   -- Velocity in the bumped direction becomes 0
                   , vcty = (\b k -> iff (b == 0) k 0) <$> bumpVector <*> vcty p1
                   }
    where
        bumps1 :: Double -> Double -> Double -> Double -> [Double]
        bumps1 x1 w1 x2 w2 = [ (x1 + w1) - x2, x1 - (x2 + w2) ]

type Collision = (Bool, Bool) -- ^ Overlap on low and high object borders, respectively.

collision :: GameObject -> GameObject -> Maybe (Vector Collision)
collision g1 g2 = sequenceA $ collision1 <$> posn g1 <*> size g1 <*> posn g2 <*> size g2
    where
        -- 1D collision info
        collision1 :: Double -> Double -> Double -> Double -> Maybe Collision
        collision1 x1 w1 x2 w2 = (x1 <= x2, x1 + w1 >= x2 + w2) `mcond` colliding x1 w1 x2 w2

        colliding :: Double -> Double -> Double -> Double -> Bool
        colliding x1 w1 x2 w2 =  x1 + w1 >= x2
                              && x2 + w2 >= x1

tryCollide :: GameObject -- ^ Object to update
           -> GameObject -- ^ Object it collided with
           -> GameObject -- ^ Updated object
tryCollide = maybe $$ const $* collisionHandler $* collision

step :: DeltaT -> GameObject -> GameObject
step t = updateVcty . updatePosn
    where
        updatePosn g = g { posn = posn g <&> (+) <*> fmap (*t) (vcty g) }
        updateVcty g
            | objType g == Block    = g { vcty = vcty g <&> (+) <*> fmap (*t) a_g }
            | otherwise             = g
        a_g = Vector 0 (-9.81)

updatePhysics :: DeltaT -> GameState -> GameState
updatePhysics t g = g { objects = step t <$> objects g }

updateInputs :: [Input] -> GameState -> GameState
updateInputs is g = g { objects = foldr updateInput (objects g) is }
    where
        updateInput :: Input -> [GameObject] -> [GameObject]
        updateInput (Move t d) = fmap $ bool <*> moveObj d <*> (==t) . objType
        updateInput _ = id

        moveObj :: Direction -> GameObject -> GameObject
        moveObj d o = o { posn = move d <&> (+) <*> posn o }

        move Up = Vector 0 0.3
        move Right = Vector 0.3 0
        move Down = negate <$> move Up
        move Left = negate <$> move Right

updateBumps :: GameState -> GameState
updateBumps g = g { objects = foldr bumpCons [] $ objects g }
    where
        -- | Cons the object on to the list, as well as bump every other object with it.
        bumpCons obj = (\(x, l) -> x : l) . foldCons collide2 obj
        collide2 o1 o2 = (tryCollide o1 o2, tryCollide o2 o1)

update :: [Input] -> DeltaT -> GameState -> GameState
update is t = updateBumps . updateInputs is . updatePhysics t
