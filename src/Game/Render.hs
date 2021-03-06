{-# LANGUAGE NoImplicitPrelude
           , FlexibleInstances
           #-}
-- | Render the game state
module Game.Render ( Drawable (..)
                   ) where

import Summit.IO
import Summit.Prelewd
import Summit.Subset.Num

import Game.Physics
import Game.Object
import Game.Vector
import Physics.Types
import Util.ID

import Wrappers.OpenGL hiding (Size, Position)

-- | Convert the game's vector to an OpenGL coordinate
toGLVertex :: Position -> Vertex2 GLdouble
toGLVertex p = on Vertex2 realToFrac (component Width p) (component Height p)

-- | Things which can be drawn
class Drawable d where
    -- | Render the object to the screen
    draw :: d -> IO ()

instance Drawable (Named GameObject) where
    draw = traverse_ draw

instance Drawable GameObject where
    draw g = drawQuad objColor g
        where
            objColor
                | isBlock g = blue
                | isPlayer g = green
                | otherwise = red

-- | `draw c o` draws `o` as a quadrilateral, based on its position and size.
drawQuad :: Color4 GLdouble -> GameObject -> IO ()
drawQuad c o = let
            p = posn $ phys o
            Vertex2 x y = toGLVertex p
            Vertex2 x' y' = toGLVertex p <&> (+) <*> toGLVertex (fromPos <$> size (phys o))
        in io
         $ renderPrimitive Quads
         $ runIO
         $ drawColored c
          [ Vertex2 x  y
          , Vertex2 x  y'
          , Vertex2 x' y'
          , Vertex2 x' y
          ]
