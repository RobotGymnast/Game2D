{-# LANGUAGE NoImplicitPrelude
           , TupleSections
           #-}
-- | Transform one physics state to the next
module Game.Update.Physics ( update
                           ) where

import Summit.Data.Map
import Summit.Prelewd hiding (filter)
import Summit.Subset.Num

import Game.Movement
import Game.Physics
import Game.Object
import Game.Vector
import Physics.Types
import Util.ID
import Util.Unit

modPhys :: (Physics -> (r, Physics)) -> GameObject -> (r, GameObject)
modPhys f obj = f (phys obj) <&> (\p -> phys' (\_-> p) obj)

-- | Put each component in its own vector, in the correct location
isolate :: a -> Vector a -> Vector (Vector a)
isolate zero = liftA2 (singleV zero) dimensions

-- | Update a single object's physics
update :: Time                      -- ^ Delta t
       -> Map ID Physics            -- ^ All the objects
       -> ID                        -- ^ ID of the object to update
       -> GameObject
       -> (Map ID Collisions, GameObject)
update t others i = modPhys $ updateVcty >>> updatePosn
    where
        updateVcty p = p { vcty = vcty p + ((fromNat t &*) <$> accl p) }
        updatePosn p = foldl' moveAndCollide (mempty, p) $ isolate 0 $ vcty p

        moveAndCollide (allCollides, p) mv = let
                    shift = (fromNat t &*) <$> mv
                    (deltaP, collides) = move shift p (delete i others <?> others)
                in ( allCollides <> filter (not.null) collides
                   , makeMove deltaP p
                   )

        makeMove :: Position -> Physics -> Physics
        makeMove = posn' . (+)
