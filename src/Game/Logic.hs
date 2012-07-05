module Game.Logic ( GameObject (..)
                  , phys'
                  , isPlatform
                  , isBlock
                  , isPlayer
                  , GameState (..)
                  , objects'
                  , Input (..)
                  , Direction(..)
                  , initState
                  , update
                  ) where

import Prelude ()
import Util.Prelewd

import Data.Tuple
import Text.Show

import Types

import Game.Physics

-- | An object in the game world
data GameObject
    = Block    { phys :: Physics }
    | Platform { phys :: Physics }
    | Player   { phys :: Physics }

phys' :: (Physics -> Physics) -> GameObject -> GameObject
phys' f g = g { phys = f (phys g) }

isBlock :: GameObject -> Bool
isBlock (Block {}) = True
isBlock _ = False

isPlatform :: GameObject -> Bool
isPlatform (Platform {}) = True
isPlatform _ = False

isPlayer :: GameObject -> Bool
isPlayer (Player {}) = True
isPlayer _ = False

data GameState = GameState { objects :: [GameObject]
                           }

objects' :: ([GameObject] -> [GameObject]) -> GameState -> GameState
objects' f g = g { objects = f (objects g) }

-- | Cardinal directions
data Direction = Up | Down | Left | Right
    deriving (Eq, Show)

-- | Input events understood by the game
data Input = Jump
           | Move Direction
    deriving (Eq, Show)

-- | Start state of the game world
initState :: GameState
initState = GameState [ Block $ Physics (Vector 1 1) (Vector 0 0) (Vector 0 0) [gravity]
                      , Platform $ Physics (Vector 4 1) (Vector (-3) (-1)) (Vector 0 0) []
                      , Player $ Physics (Vector 1 2) (Vector (-3) 0) (Vector 0 0) [gravity]
                      ]

collisionHandler :: Position         -- ^ Original position of first object
                 -> Position         -- ^ Original position of second object
                 -> GameObject       -- ^ Object to update
                 -> GameObject       -- ^ Object it collided with
                 -> GameObject       -- ^ Updated object
collisionHandler p1 p2 g1 g2 = if' (isBlock g1 || isPlatform g2) (bumpObj p2 g2 p1) g1

bumpObj :: Position -> GameObject -> Position -> GameObject -> GameObject
bumpObj p2 g2 p1 = phys' $ bump p2 (phys g2) p1

-- | If the objects collide, call the appropriate handlers; otherwise just return
tryCollide :: Position   -- ^ Original position of the object to bump
           -> Position   -- ^ Original position of the object it collided with
           -> GameObject -- ^ Object to bump
           -> GameObject -- ^ Object it collided with
           -> GameObject -- ^ Updated object
tryCollide p1 p2 g1 g2 = bool g1 (collisionHandler p1 p2 g1 g2) $ overlaps (phys g1) (phys g2)

updateInputs :: [Input] -> GameState -> GameState
updateInputs is = objects' $ \o -> foldr (fmap . updateInput) o is
    where
        -- Update a game object with a given input command
        updateInput :: Input -> GameObject -> GameObject
        updateInput Jump = jumpIfPlayer
        updateInput (Move d) = moveIfPlayer d

        jumpIfPlayer :: GameObject -> GameObject
        jumpIfPlayer g = if' (isPlayer g) (phys' $ propels' (jump ++)) g

        moveIfPlayer :: Direction -> GameObject -> GameObject
        moveIfPlayer d g = if' (isPlayer g) (phys' $ propels' (move d ++)) g

        jump = [Propel (Vector 0 80) (Just 0.1)]

        move Left  = [Propel (Vector (-40) 0) (Just 0.1)]
        move Right = [Propel (Vector   40  0) (Just 0.1)]
        move _ = []
        
-- | Ensure no objects are colliding
updateBumps :: [(Position, GameObject)] -- ^ [(originalPos, obj)]
            -> [GameObject]             -- ^ Updated objects
updateBumps = (snd <$>) . foldr bumpCons []
    where
        -- | Cons the object on to the list, as well as bump every other object with it.
        bumpCons obj = (\(x, l) -> x : l) . mapAccumR collide2 obj
        collide2 (p1, o1) (p2, o2) = ((p1, tryCollide p1 p2 o1 o2), (p2, tryCollide p2 p1 o2 o1))

update :: [Input] -> Time -> GameState -> GameState
update is t = updateInputs is . objects' bumpObjects
    where
        bumpObjects :: [GameObject] -> [GameObject]
        bumpObjects o = updateBumps $ zip (posn . phys <$> o) $ phys' (updatePhysics t) <$> o
