module Game.Collision ( collide
                      ) where

import Prelude ()
import Util.Prelewd

import Game.Object

collide :: GameObject       -- ^ GameObject to update
        -> GameObject       -- ^ GameObject it collided with
        -> GameObject       -- ^ Updated object
collide = const