{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}
-- | This module define all the types used in the definition
-- of a svg scene.
--
-- Most of the types are lensified.
module Graphics.Svg.Types
    ( -- * Basic building types
      Coord
    , Origin( .. )
    , Point
    , RPoint
    , Path( .. )
    , Transformation( .. )
      -- ** Building helpers
    , toPoint
    , serializeNumber
    , serializeTransformation
    , serializeTransformations

      -- * Drawing control types
    , Cap( .. )
    , LineJoin( .. )
    , Tree( .. )
    , Number( .. )
    , Spread( .. )
    , Texture( .. )
    , Element( .. )
    , FillRule( .. )
    , FontStyle( .. )

    , WithDefaultSvg( .. )

      -- * Main type
    , Document( .. )
    , documentSize

      -- * Drawing attributes
    , DrawAttributes( .. )
    , HasDrawAttributes( .. )
    , WithDrawAttributes( .. )

      -- * SVG drawing primitives
      -- ** Rectangle
    , Rectangle( .. )
    , HasRectangle( .. )

      -- ** Line
    , Line( .. )
    , HasLine( .. )

      -- ** Polygon
    , Polygon( .. )
    , HasPolygon( .. )

      -- ** Polyline
    , PolyLine( .. )
    , HasPolyLine( .. )

      -- ** Path
    , PathPrim( .. )
    , HasPathPrim( .. )

      -- ** Circle
    , Circle( .. )
    , HasCircle( .. )

      -- ** Ellipse
    , Ellipse( .. )
    , HasEllipse( .. )

      -- ** Use
    , Use( .. )
    , HasUse( .. )

      -- * Grouping primitives
      -- ** Group
    , Group( .. )
    , HasGroup( .. )

      -- ** Symbol
    , Symbol( .. )
    , groupOfSymbol

      -- * Text related types
      -- ** Text
    , Text( .. )
    , HasText( .. )
    , TextAnchor( .. )

      -- ** Text path
    , TextPath( .. )
    , HasTextPath( .. )

    , TextPathSpacing( .. )
    , TextPathMethod( .. )

      -- ** Text span.
    , TextSpanContent( .. )

    , TextSpan( .. )
    , HasTextSpan( .. )

    , TextInfo( .. )
    , HasTextInfo( .. )

    , TextAdjust( .. )

      -- * Marker definition
    , MarkerAttribute( .. )
    , Marker( .. )
    , MarkerOrientation( .. )
    , MarkerUnit( .. )
    , HasMarker( .. )

      -- * Gradient definition
    , GradientUnits( .. )
    , GradientStop( .. )
    , HasGradientStop( .. )

      -- ** Linear Gradient
    , LinearGradient( .. )
    , HasLinearGradient( .. )

      -- ** Radial Gradient
    , RadialGradient( .. )
    , HasRadialGradient( .. )

      -- * Pattern definition
    , Pattern( .. )
    , PatternUnit( .. )
    , HasPattern( .. )


      -- * MISC functions
    , isPathArc
    , isPathWithArc
    , nameOfTree
    , zipTree
    ) where

import Data.Function( on )
import Data.List( inits )
import qualified Data.Map as M
import Data.Monoid( Monoid( .. ), Last( .. ), (<>) )
import Data.Foldable( Foldable )
import qualified Data.Foldable as F
import qualified Data.Text as T
import Codec.Picture( PixelRGBA8( .. ) )
import Control.Lens( Lens'
                   , lens
                   , makeClassy
                   , makeLenses
                   , view
                   , (^.)
                   , (&)
                   , (.~)
                   )
import Graphics.Svg.CssTypes
import Linear hiding ( angle )

import Text.Printf

-- | Basic coordiante type.
type Coord = Float

-- | Real Point, fully determined and not
-- dependant of the rendering context.
type RPoint = V2 Coord

-- | Possibly context dependant point.
type Point = (Number, Number)

-- | Tell if a path command is absolute (in the current
-- user coordiante) or relative to the previous poitn.
data Origin
  = OriginAbsolute -- ^ Next point in absolute coordinate
  | OriginRelative -- ^ Next point relative to the previous
  deriving (Eq, Show)

-- | Path command definition.
data Path
      -- | 'M' or 'm' command
    = MoveTo Origin [RPoint]
      -- | Line to, 'L' or 'l' Svg path command.
    | LineTo Origin [RPoint]

      -- | Equivalent to the 'H' or 'h' svg path command.
    | HorizontalTo  Origin [Coord]
      -- | Equivalent to the 'V' or 'v' svg path command.
    | VerticalTo    Origin [Coord]

    -- | Cubic bezier, 'C' or 'c' command
    | CurveTo  Origin [(RPoint, RPoint, RPoint)]
    -- | Smooth cubic bezier, equivalent to 'S' or 's' command
    | SmoothCurveTo  Origin [(RPoint, RPoint)]
    -- | Quadratic bezier, 'Q' or 'q' command
    | QuadraticBezier  Origin [(RPoint, RPoint)]
    -- | Quadratic bezier, 'T' or 't' command
    | SmoothQuadraticBezierCurveTo  Origin [RPoint]
      -- | Eliptical arc, 'A' or 'a' command.
    | ElipticalArc  Origin [(Coord, Coord, Coord, Coord, Coord, RPoint)]
      -- | Close the path, 'Z' or 'z' svg path command.
    | EndPath
    deriving (Eq, Show)

-- | Little helper function to build a point.
toPoint :: Number -> Number -> Point
toPoint = (,)

-- | Tell if the path command is an ElipticalArc.
isPathArc :: Path -> Bool
isPathArc (ElipticalArc _ _) = True
isPathArc _ = False

-- | Tell if a full path contain an ElipticalArc.
isPathWithArc :: Foldable f => f Path -> Bool
isPathWithArc = F.any isPathArc


-- | Describe how the line should be terminated
-- when stroking them. Describe the values of the
-- `stroke-linecap` attribute.
-- See `_strokeLineCap`
data Cap
  = CapRound -- ^ End with a round (`round` value)
  | CapButt  -- ^ Define straight just at the end (`butt` value)
  | CapSquare -- ^ Straight further of the ends (`square` value)
  deriving (Eq, Show)

-- | Define the possible values of the `stroke-linejoin`
-- attribute.
-- see `_strokeLineJoin`
data LineJoin
    = JoinMiter -- ^ `miter` value
    | JoinBevel -- ^ `bevel` value
    | JoinRound -- ^ `round` value
    deriving (Eq, Show)

-- | Describe the different value which can be used
-- in the `fill` or `stroke` attributes.
data Texture
  = ColorRef   PixelRGBA8 -- ^ Direct solid color (#rrggbb, #rgb)
  | TextureRef String     -- ^ Link to a complex texture (url(#name))
  | FillNone              -- ^ Equivalent to the `none` value.
  deriving (Eq, Show)

-- | Describe the possile filling algorithms.
-- Map the values of the `fill-rule` attributes.
data FillRule
    = FillEvenOdd -- ^ Correspond to the `evenodd` value.
    | FillNonZero -- ^ Correspond to the `nonzero` value.
    deriving (Eq, Show)

-- | Describe the content of the `transformation` attribute.
-- see `_transform` and `transform`.
data Transformation
    = -- | Directly encode the translation matrix.
      TransformMatrix Coord Coord Coord
                      Coord Coord Coord
      -- | Translation along a vector
    | Translate Float Float
      -- | Scaling on both axis or on X axis and Y axis.
    | Scale Float (Maybe Float)
      -- | Rotation around `(0, 0)` or around an optional
      -- point.
    | Rotate Float (Maybe (Float, Float))
      -- | Skew transformation along the X axis.
    | SkewX Float
      -- | Skew transformation along the Y axis.
    | SkewY Float
      -- | Unkown transformation, like identity.
    | TransformUnknown
    deriving (Eq, Show)

-- | Convert the Transformation to a string which can be
-- directly used in a svg attributes.
serializeTransformation :: Transformation -> String
serializeTransformation t = case t of
  TransformUnknown -> ""
  TransformMatrix a b c d e f ->
      printf "matrix(%g, %g, %g, %g, %g, %g)" a b c d e f
  Translate x y -> printf "translate(%g, %g)" x y
  Scale x Nothing -> printf "scale(%g)" x
  Scale x (Just y) -> printf "scale(%g, %g)" x y
  Rotate angle Nothing -> printf "rotate(%g)" angle
  Rotate angle (Just (x, y))-> printf "rotate(%g, %g, %g)" angle x y
  SkewX x -> printf "skewX(%g)" x
  SkewY y -> printf "skewY(%g)" y

-- | Transform a list of transformations to a string for svg
-- `transform` attributes.
serializeTransformations :: [Transformation] -> String
serializeTransformations =
    unwords . fmap serializeTransformation

-- | Class helping find the drawing attributes for all
-- the SVG attributes.
class WithDrawAttributes a where
    -- | Lens which can be used to read/write primitives.
    drawAttr :: Lens' a DrawAttributes

-- | Define an empty 'default' element for the SVG tree.
-- It is used as base when parsing the element from XML.
class WithDefaultSvg a where
    -- | The default element.
    defaultSvg :: a

-- | Classify the font style, used to search a matching
-- font in the FontCache.
data FontStyle
  = FontStyleNormal
  | FontStyleItalic
  | FontStyleOblique
  deriving (Eq, Show)

-- | Tell where to anchor the text, where the position
-- given is realative to the text.
data TextAnchor
    -- | The text with left aligned, or start at the postion
    -- If the point is the '*' then the text will be printed
    -- this way:
    --
    -- >  *THE_TEXT_TO_PRINT
    --
    -- Equivalent to the `start` value.
  = TextAnchorStart
    -- | The text is middle aligned, so the text will be at
    -- the left and right of the position:
    --
    -- >   THE_TEXT*TO_PRINT
    --
    -- Equivalent to the `middle` value.
  | TextAnchorMiddle
    -- | The text is right aligned.
    --
    -- >   THE_TEXT_TO_PRINT*
    --
    -- Equivalent to the `end` value.
  | TextAnchorEnd
  deriving (Eq, Show)


-- | Correspond to the possible values of the
-- attributes `marker-start`, `marker-mid` and
-- `marker-end`.
data MarkerAttribute
  = MarkerNone  -- ^ Value for `none`
  | MarkerRef String -- ^ Equivalent to `url()` attribute.
  deriving (Eq, Show)

-- | This type define how to draw any primitives,
-- which color to use, how to stroke the primitives
-- and the potential transformations to use.
--
-- All these attributes are propagated to the children.
data DrawAttributes = DrawAttributes
    { -- | Attribute corresponding to the `stroke-width`
      -- SVG attribute.
      _strokeWidth      :: !(Last Number)
      -- | Correspond to the `stroke` attribute.
    , _strokeColor      :: !(Last Texture)
      -- | Define the `stroke-opacity` attribute, the transparency
      -- for the "border".
    , _strokeOpacity    :: !(Maybe Float)
      -- | Correspond to the `stroke-linecap` SVG
      -- attribute
    , _strokeLineCap    :: !(Last Cap)
      -- | Correspond to the `stroke-linejoin` SVG
      -- attribute
    , _strokeLineJoin   :: !(Last LineJoin)
      -- | Define the distance of the miter join, correspond
      -- to the `stroke-miterlimit` attritbue.
    , _strokeMiterLimit :: !(Last Float)
      -- | Define the filling color of the elements. Corresponding
      -- to the `fill` attribute.
    , _fillColor        :: !(Last Texture)
      -- | Define the `fill-opacity` attribute, the transparency
      -- for the "content".
    , _fillOpacity      :: !(Maybe Float)

      -- | Content of the `transform` attribute
    , _transform        :: !(Maybe [Transformation])
      -- | Define the `fill-rule` used during the rendering.
    , _fillRule         :: !(Last FillRule)
      -- | Map to the `class` attribute. Used for the CSS
      -- rewriting.
    , _attrClass        :: !(Last String)
      -- | Map to the `id` attribute. Used for the CSS
      -- rewriting.
    , _attrId           :: !(Maybe String)
      -- | Define the start distance of the dashing pattern.
      -- Correspond to the `stroke-dashoffset` attribute.
    , _strokeOffset     :: !(Last Number)
      -- | Define the dashing pattern for the lines. Correspond
      -- to the `stroke-dasharray` attribute.
    , _strokeDashArray  :: !(Last [Number])
      -- | Current size of the text, correspond to the
      -- `font-size` SVG attribute.
    , _fontSize         :: !(Last Number)
      -- | Define the possible fonts to be used for text rendering.
      -- Map to the `font-family` attribute.
    , _fontFamily       :: !(Last [String])
      -- | Map to the `font-style` attribute.
    , _fontStyle        :: !(Last FontStyle)
      -- | Define how to interpret the text position, correspond
      -- to the `text-anchor` attribute.
    , _textAnchor       :: !(Last TextAnchor)
      -- | Define the marker used for the start of the line.
      -- Correspond to the `marker-start` attribute.
    , _markerStart      :: !(Last MarkerAttribute)
      -- | Define the marker used for every point of the
      -- polyline/path Correspond to the `marker-mid`
      -- attribute.
    , _markerMid        :: !(Last MarkerAttribute)
      -- | Define the marker used for the end of the line.
      -- Correspond to the `marker-end` attribute.
    , _markerEnd        :: !(Last MarkerAttribute)
    }
    deriving (Eq, Show)

-- | Lenses for the DrawAttributes type.
makeClassy ''DrawAttributes

-- | This primitive describe an unclosed suite of
-- segments. Correspond to the `<polyline>` tag.
data PolyLine = PolyLine
  { -- | drawing attributes of the polyline.
    _polyLineDrawAttributes :: DrawAttributes 

    -- | Geometry definition of the polyline.
    -- correspond to the `points` attribute
  , _polyLinePoints :: [RPoint]
  }
  deriving (Eq, Show)

-- | Lenses for the PolyLine type.
makeClassy ''PolyLine

instance WithDefaultSvg PolyLine where
  defaultSvg = PolyLine
    { _polyLineDrawAttributes = mempty
    , _polyLinePoints = []
    }


instance WithDrawAttributes PolyLine where
    drawAttr = polyLineDrawAttributes

-- | Primitive decriving polygon composed
-- of segements. Correspond to the `<polygon>`
-- tag
data Polygon = Polygon
  { -- | Drawing attributes for the polygon.
    _polygonDrawAttributes :: DrawAttributes
    -- | Points of the polygon. Correspond to
    -- the `points` attributes.
  , _polygonPoints :: [RPoint]
  }
  deriving (Eq, Show)

-- | Lenses for the Polygon type
makeClassy ''Polygon

instance WithDrawAttributes Polygon where
    drawAttr = polygonDrawAttributes

instance WithDefaultSvg Polygon where
  defaultSvg = Polygon
    { _polygonDrawAttributes = mempty
    , _polygonPoints = []
    }

-- | Define a simple line. Correspond to the
-- `<line>` tag.
data Line = Line
  { -- | Drawing attributes of line.
    _lineDrawAttributes :: DrawAttributes
    -- | First point of the the line, correspond
    -- to the `x1` and `y1` attributes.
  , _linePoint1 :: Point
    -- | Second point of the the line, correspond
    -- to the `x2` and `y2` attributes.
  , _linePoint2 :: Point
  }
  deriving (Eq, Show)

-- | Lenses for the Line type.
makeClassy ''Line

instance WithDrawAttributes Line where
    drawAttr = lineDrawAttributes

instance WithDefaultSvg Line where
  defaultSvg = Line
    { _lineDrawAttributes = mempty
    , _linePoint1 = zeroPoint
    , _linePoint2 = zeroPoint
    }
    where zeroPoint = (Num 0, Num 0)

-- | Define a rectangle. Correspond to
-- `<rectangle>` svg tag.
data Rectangle = Rectangle 
  { -- | Rectangle drawing attributes.
    _rectDrawAttributes  :: DrawAttributes
    -- | Upper left corner of the rectangle, correspond
    -- to the attributes `x` and `y`.
  , _rectUpperLeftCorner :: Point
    -- | Rectangle width, correspond, strangely, to
    -- the `width` attribute.
  , _rectWidth           :: Number
    -- | Rectangle height, correspond, amazingly, to
    -- the `height` attribute.
  , _rectHeight          :: Number
    -- | Define the rounded corner radius radius
    -- of the rectangle. Correspond to the `rx` and
    -- `ry` attributes.
  , _rectCornerRadius    :: (Number, Number)
  }
  deriving (Eq, Show)

-- | Lenses for the Rectangle type.
makeClassy ''Rectangle

instance WithDrawAttributes Rectangle where
    drawAttr = rectDrawAttributes

instance WithDefaultSvg Rectangle where
  defaultSvg = Rectangle
    { _rectDrawAttributes  = mempty
    , _rectUpperLeftCorner = (Num 0, Num 0)
    , _rectWidth           = Num 0
    , _rectHeight          = Num 0
    , _rectCornerRadius    = (Num 0, Num 0)
    }

-- | Type mapping the `<path>` svg tag.
data PathPrim = PathPrim
  { -- | Drawing attributes of the path.
    _pathDrawAttributes :: DrawAttributes
    -- | Definition of the path, correspond to the
    -- `d` attributes.
  , _pathDefinition :: [Path]
  }
  deriving (Eq, Show)

-- | Lenses for the PathPrim type
makeClassy ''PathPrim

instance WithDrawAttributes PathPrim where
  drawAttr = pathDrawAttributes

instance WithDefaultSvg PathPrim where
  defaultSvg = PathPrim
    { _pathDrawAttributes = mempty
    , _pathDefinition = []
    }

-- | Define a SVG group, corresponding `<g>` tag.
data Group a = Group
  { -- | Group drawing attributes, propagated to all of its
    -- children.
    _groupDrawAttributes :: !DrawAttributes
    -- | Content of the group, corresponding to all the tags
    -- inside the `<g>` tag.
  , _groupChildren  :: ![a]
    -- | Mapped to the attribute `viewBox`
  , _groupViewBox   :: !(Maybe (Int, Int, Int, Int))
  }
  deriving (Eq, Show)

-- | Lenses associated to the Group type.
makeClassy ''Group

instance WithDrawAttributes (Group a) where
    drawAttr = groupDrawAttributes

instance WithDefaultSvg (Group a) where
  defaultSvg = Group
    { _groupDrawAttributes = mempty
    , _groupChildren  = []
    , _groupViewBox = Nothing
    }

-- | Define the `<symbol>` tag, equivalent to
-- a named group.
newtype Symbol a =
    Symbol { _groupOfSymbol :: Group a }

-- | Lenses associated with the Symbol type.
makeLenses ''Symbol

instance WithDrawAttributes (Symbol a) where
  drawAttr = groupOfSymbol . drawAttr

instance WithDefaultSvg (Symbol a) where
  defaultSvg = Symbol defaultSvg

-- | Define a `<circle>`.
data Circle = Circle
  { -- | Drawing attributes of the circle.
    _circleDrawAttributes :: DrawAttributes
    -- | Define the center of the circle, describe
    -- the `cx` and `cy` attributes.
  , _circleCenter   :: Point
    -- | Radius of the circle, equivalent to the `r`
    -- attribute.
  , _circleRadius   :: Number
  }
  deriving (Eq, Show)

-- | Lenses for the Circle type.
makeClassy ''Circle

instance WithDrawAttributes Circle where
    drawAttr = circleDrawAttributes

instance WithDefaultSvg Circle where
  defaultSvg = Circle
    { _circleDrawAttributes = mempty
    , _circleCenter = (Num 0, Num 0)
    , _circleRadius = Num 0
    }

-- | Define an `<ellipse>`
data Ellipse = Ellipse
  {  -- | Drawing attributes of the ellipse.
    _ellipseDrawAttributes :: DrawAttributes
    -- | Center of the ellipse, map to the `cx`
    -- and `cy` attributes.
  , _ellipseCenter :: Point
    -- | Radius along the X axis, map the
    -- `rx` attribute.
  , _ellipseXRadius :: Number
    -- | Radius along the Y axis, map the
    -- `ry` attribute.
  , _ellipseYRadius :: Number
  }
  deriving (Eq, Show)

-- | Lenses for the ellipse type.
makeClassy ''Ellipse

instance WithDrawAttributes Ellipse where
  drawAttr = ellipseDrawAttributes

instance WithDefaultSvg Ellipse where
  defaultSvg = Ellipse
    { _ellipseDrawAttributes = mempty
    , _ellipseCenter = (Num 0, Num 0)
    , _ellipseXRadius = Num 0
    , _ellipseYRadius = Num 0
    }

-- | Define an `<use>` for a named content.
-- Every named content can be reused in the
-- document using this element.
data Use = Use
  { -- | Position where to draw the "used" element.
    -- Correspond to the `x` and `y` attributes.
    _useBase   :: Point
    -- | Referenced name, correspond to `xlink:href`
    -- attribute.
  , _useName   :: String
    -- | Define the width of the region where
    -- to place the element. Map to the `width`
    -- attribute.
  , _useWidth  :: Maybe Number
    -- | Define the height of the region where
    -- to place the element. Map to the `height`
    -- attribute.
  , _useHeight :: Maybe Number
    -- | Use draw attributes.
  , _useDrawAttributes :: DrawAttributes
  }
  deriving (Eq, Show)

-- | Lenses for the Use type.
makeClassy ''Use

instance WithDrawAttributes Use where
  drawAttr = useDrawAttributes

instance WithDefaultSvg Use where
  defaultSvg = Use
    { _useBase   = (Num 0, Num 0)
    , _useName   = ""
    , _useWidth  = Nothing
    , _useHeight = Nothing
    , _useDrawAttributes = mempty
    }

-- | Define position information associated to
-- `<text>` or `<tspan>` svg tag.
data TextInfo = TextInfo
  { _textInfoX      :: ![Number] -- ^ `x` attribute.
  , _textInfoY      :: ![Number] -- ^ `y` attribute.
  , _textInfoDX     :: ![Number] -- ^ `dx` attribute.
  , _textInfoDY     :: ![Number] -- ^ `dy` attribute.
  , _textInfoRotate :: ![Float] -- ^ `rotate` attribute.
  , _textInfoLength :: !(Maybe Number) -- ^ `textLength` attribute.
  }
  deriving (Eq, Show)

instance Monoid TextInfo where
  mempty = TextInfo [] [] [] [] [] Nothing
  mappend (TextInfo x1 y1 dx1 dy1 r1 l1)
          (TextInfo x2 y2 dx2 dy2 r2 l2) =
    TextInfo (x1 <> x2)   (y1 <> y2)
                (dx1 <> dx2) (dy1 <> dy2)
                (r1 <> r2)
                (getLast $ Last l1 <> Last l2)

-- | Lenses for the TextInfo type.
makeClassy ''TextInfo

instance WithDefaultSvg TextInfo where
  defaultSvg = mempty

-- | Define the content of a `<tspan>` tag.
data TextSpanContent
    = SpanText    !T.Text -- ^ Raw text
    | SpanTextRef !String -- ^ Equivalent to a `<tref>`
    | SpanSub     !TextSpan -- ^ Define a `<tspan>`
    deriving (Eq, Show)

-- | Define a `<tspan>` tag.
data TextSpan = TextSpan
  { -- | Placing information for the text.
    _spanInfo           :: !TextInfo
    -- | Drawing attributes for the text span.
  , _spanDrawAttributes :: !DrawAttributes
    -- | Content of the span.
  , _spanContent        :: ![TextSpanContent]
  }
  deriving (Eq, Show)

-- | Lenses for the TextSpan type.
makeClassy ''TextSpan

instance WithDefaultSvg TextSpan where
  defaultSvg = TextSpan
    { _spanInfo = defaultSvg
    , _spanDrawAttributes = mempty
    , _spanContent        = mempty
    }

-- | Describe the content of the `method` attribute on
-- text path.
data TextPathMethod
  = TextPathAlign   -- ^ Map to the `align` value.
  | TextPathStretch -- ^ Map to the `stretch` value.
  deriving (Eq, Show)

-- | Describe the content of the `spacing` text path
-- attribute.
data TextPathSpacing
  = TextPathSpacingExact -- ^ Map to the `exact` value.
  | TextPathSpacingAuto  -- ^ Map to the `auto` value.
  deriving (Eq, Show)

-- | Describe the `<textpath>` SVG tag.
data TextPath = TextPath
  { -- | Define the beginning offset on the path,
    -- the `startOffset` attribute.
    _textPathStartOffset :: !Number
    -- | Define the `xlink:href` attribute.
  , _textPathName        :: !String
    -- | Correspond to the `method` attribute.
  , _textPathMethod      :: !TextPathMethod
    -- | Correspond to the `spacing` attribute.
  , _textPathSpacing     :: !TextPathSpacing
    -- | Real content of the path.
  , _textPathData        :: ![Path]
  }
  deriving (Eq, Show)

-- | Lenses for the TextPath type.
makeClassy ''TextPath

instance WithDefaultSvg TextPath where
  defaultSvg = TextPath
    { _textPathStartOffset = Num 0
    , _textPathName        = mempty
    , _textPathMethod      = TextPathAlign
    , _textPathSpacing     = TextPathSpacingExact
    , _textPathData        = []
    }

-- | Define the possible values of the `lengthAdjust`
-- attribute.
data TextAdjust
  = TextAdjustSpacing -- ^ Value `spacing`
  | TextAdjustSpacingAndGlyphs -- ^ Value `spacingAndGlyphs`
  deriving (Eq, Show)

-- | Define the global `<tag>` SVG tag.
data Text = Text
  { -- | Define the `lengthAdjust` attribute.
    _textAdjust   :: !TextAdjust
    -- | Root of the text content.
  , _textRoot     :: !TextSpan
  }
  deriving (Eq, Show)

-- | Lenses for the Text type.
makeClassy ''Text

instance WithDrawAttributes Text where
  drawAttr = textRoot . spanDrawAttributes

instance WithDefaultSvg Text where
  defaultSvg = Text
    { _textRoot = defaultSvg
    , _textAdjust = TextAdjustSpacing
    }

-- | Main type for the scene description, reorient to
-- specific type describing each tag.
data Tree
    = None
    | UseTree       !Use  !Tree
    | GroupTree     !(Group Tree)
    | SymbolTree    !(Group Tree)
    | Path          !PathPrim
    | CircleTree    !Circle
    | PolyLineTree  !PolyLine
    | PolygonTree   !Polygon
    | EllipseTree   !Ellipse
    | LineTree      !Line
    | RectangleTree !Rectangle
    | TextArea      !(Maybe TextPath) !Text
    deriving (Eq, Show)

-- | Define the orientation, associated to the
-- `orient` attribute on the Marker
data MarkerOrientation
  = OrientationAuto        -- ^ Auto value
  | OrientationAngle Coord -- ^ Specific angle.
  deriving (Eq, Show)

-- | Define the content of the `markerUnits` attribute
-- on the Marker.
data MarkerUnit
  = MarkerUnitStrokeWidth    -- ^ Value `strokeWidth`
  | MarkerUnitUserSpaceOnUse -- ^ Value `userSpaceOnUse`
  deriving (Eq, Show)

-- | Define the `<marker>` tag.
data Marker = Marker
  { -- | Draw attributes of the marker.
    _markerDrawAttributes :: DrawAttributes
    -- | Define the reference point of the marker.
    -- correspond to the `refX` and `refY` attributes.
  , _markerRefPoint :: (Number, Number)
    -- | Define the width of the marker. Correspond to
    -- the `markerWidth` attribute.
  , _markerWidth    :: Number
    -- | Define the height of the marker. Correspond to
    -- the `markerHeight` attribute.
  , _markerHeight   :: Number
    -- | Correspond to the `orient` attribute.
  , _markerOrient   :: Maybe MarkerOrientation
    -- | Map the `markerUnits` attribute.
  , _markerUnits    :: Maybe MarkerUnit
    -- | Elements defining the marker.
  , _markerElements :: [Tree]
  }
  deriving (Eq, Show)

-- | Lenses for the Marker type.
makeClassy ''Marker

instance WithDrawAttributes Marker where
    drawAttr = markerDrawAttributes

instance WithDefaultSvg Marker where
  defaultSvg = Marker
    { _markerDrawAttributes = mempty
    , _markerRefPoint = (Num 0, Num 0)
    , _markerWidth = Num 0
    , _markerHeight = Num 0
    , _markerOrient = Nothing -- MarkerOrientation
    , _markerUnits = Nothing -- MarkerUnitStrokeWidth
    , _markerElements = []
    }

-- | Insert element in the first sublist in the list of list.
appNode :: [[a]] -> a -> [[a]]
appNode [] e = [[e]]
appNode (curr:above) e = (e:curr) : above

-- | Map a tree while propagating context information.
-- The function passed in parameter receive a list
-- representing the the path used to go arrive to the
-- current node.
zipTree :: ([[Tree]] -> Tree) -> Tree -> Tree
zipTree f = dig [] where
  dig prev e@None = f $ appNode prev e
  dig prev e@(UseTree u sub) =
      f . appNode prev . UseTree u $ dig ([] : appNode prev e) sub
  dig prev e@(GroupTree g) =
      f . appNode prev . GroupTree $ zipGroup (appNode prev e) g
  dig prev e@(SymbolTree g) =
      f . appNode prev . SymbolTree $ zipGroup (appNode prev e) g
  dig prev e@(Path _) = f $ appNode prev e
  dig prev e@(CircleTree _) = f $ appNode prev e
  dig prev e@(PolyLineTree _) = f $ appNode prev e
  dig prev e@(PolygonTree _) = f $ appNode prev e
  dig prev e@(EllipseTree _) = f $ appNode prev e
  dig prev e@(LineTree _) = f $ appNode prev e
  dig prev e@(RectangleTree _) = f $ appNode prev e
  dig prev e@(TextArea _ _) = f $ appNode prev e

  zipGroup prev g = g { _groupChildren = updatedChildren }
    where
      groupChild = _groupChildren g
      updatedChildren = 
        [dig (c:prev) child
            | (child, c) <- zip groupChild $ inits groupChild]

-- | For every element of a svg tree, associate
-- it's SVG tag name.
nameOfTree :: Tree -> T.Text
nameOfTree v =
  case v of
   None     -> ""
   UseTree _ _     -> "use"
   GroupTree _     -> "g"
   SymbolTree _    -> "symbol"
   Path _      -> "path"
   CircleTree _    -> "circle"
   PolyLineTree _  -> "polyline"
   PolygonTree _   -> "polygon"
   EllipseTree _   -> "ellipse"
   LineTree _      -> "line"
   RectangleTree _ -> "rectangle"
   TextArea    _ _ -> "text"

drawAttrOfTree :: Tree -> DrawAttributes
drawAttrOfTree v = case v of
  None -> mempty
  UseTree e _ -> e ^. drawAttr
  GroupTree e -> e ^. drawAttr
  SymbolTree e -> e ^. drawAttr
  Path e -> e ^. drawAttr
  CircleTree e -> e ^. drawAttr
  PolyLineTree e -> e ^. drawAttr
  PolygonTree e -> e ^. drawAttr
  EllipseTree e -> e ^. drawAttr
  LineTree e -> e ^. drawAttr
  RectangleTree e -> e ^. drawAttr
  TextArea _ e -> e ^. drawAttr

setDrawAttrOfTree :: Tree -> DrawAttributes -> Tree
setDrawAttrOfTree v attr = case v of
  None -> None
  UseTree e t -> UseTree (e & drawAttr .~ attr) t
  GroupTree e -> GroupTree $ e & drawAttr .~ attr
  SymbolTree e -> SymbolTree $ e & drawAttr .~ attr
  Path e -> Path $ e & drawAttr .~ attr
  CircleTree e -> CircleTree $ e & drawAttr .~ attr
  PolyLineTree e -> PolyLineTree $ e & drawAttr .~ attr
  PolygonTree e -> PolygonTree $ e & drawAttr .~ attr
  EllipseTree e -> EllipseTree $ e & drawAttr .~ attr
  LineTree e -> LineTree $ e & drawAttr .~ attr
  RectangleTree e -> RectangleTree $ e & drawAttr .~ attr
  TextArea a e -> TextArea a $ e & drawAttr .~ attr

instance WithDrawAttributes Tree where
    drawAttr = lens drawAttrOfTree setDrawAttrOfTree

instance WithDefaultSvg Tree where
    defaultSvg = None

-- | Define the possible values of the `gradientUnits`,
-- used in the definition of the gradients.
data GradientUnits
    = GradientUserSpace   -- ^ `userSpaceOnUse` value
    | GradientBoundingBox -- ^ `objectBoundingBox` value
    deriving (Eq, Show)

-- | Define the possible values for the `spreadMethod`
-- values used for the gradient definitions.
data Spread
    = SpreadRepeat  -- ^ `reapeat` value
    | SpreadPad     -- ^ `pad` value
    | SpreadReflect -- ^ `reflect value`
    deriving (Eq, Show)

-- | Define a color stop for the gradients. Represent
-- the `<stop>` SVG tag.
data GradientStop = GradientStop 
    { -- | Gradient offset between 0 and 1, correspond
      -- to the `offset` attribute.
      _gradientOffset :: Float
      -- | Color of the gradient stop. Correspond
      -- to the `stop-color` attribute.
    , _gradientColor  :: PixelRGBA8
    }
    deriving (Eq, Show)

-- | Lenses for the GradientStop type.
makeClassy ''GradientStop

instance WithDefaultSvg GradientStop where
  defaultSvg = GradientStop 
    { _gradientOffset = 0.0
    , _gradientColor  = PixelRGBA8 0 0 0 255
    }

-- | Define a `<linearGradient>` tag.
data LinearGradient = LinearGradient
    { -- | Define coordinate system of the gradient,
      -- associated to the `gradientUnits` attribute.
      _linearGradientUnits  :: GradientUnits
      -- | Point defining the beginning of the line gradient.
      -- Associated to the `x1` and `y1` attribute.
    , _linearGradientStart  :: Point
      -- | Point defining the end of the line gradient.
      -- Associated to the `x2` and `y2` attribute.
    , _linearGradientStop   :: Point
      -- | Define how to handle the values outside
      -- the gradient start and stop. Associated to the
      -- `spreadMethod` attribute.
    , _linearGradientSpread :: Spread
      -- | Define the transformation to apply to the
      -- gradient points. Associated to the `gradientTransform`
      -- attribute.
    , _linearGradientTransform :: [Transformation]
      -- | List of color stops of the linear gradient.
    , _linearGradientStops  :: [GradientStop]
    }
    deriving (Eq, Show)

-- | Lenses for the LinearGradient type.
makeClassy ''LinearGradient

instance WithDefaultSvg LinearGradient where
  defaultSvg = LinearGradient
    { _linearGradientUnits     = GradientBoundingBox
    , _linearGradientStart     = (Percent 0, Percent 0)
    , _linearGradientStop      = (Percent 1, Percent 0)
    , _linearGradientSpread    = SpreadPad
    , _linearGradientTransform = []
    , _linearGradientStops     = []
    }

-- | Define a `<radialGradient>` tag.
data RadialGradient = RadialGradient
  { -- | Define coordinate system of the gradient,
    -- associated to the `gradientUnits` attribute.
    _radialGradientUnits   :: GradientUnits
    -- | Center of the radial gradient. Associated to
    -- the `cx` and `cy` attributes.
  , _radialGradientCenter  :: Point
    -- | Radius of the radial gradient. Associated to
    -- the `r` attribute.
  , _radialGradientRadius  :: Number
    -- | X coordinate of the focus point of the radial
    -- gradient. Associated to the `fx` attribute.
  , _radialGradientFocusX  :: Maybe Number
    -- | Y coordinate of the focus point of the radial
    -- gradient. Associated to the `fy` attribute.
  , _radialGradientFocusY  :: Maybe Number
    -- | Define how to handle the values outside
    -- the gradient start and stop. Associated to the
    -- `spreadMethod` attribute.
  , _radialGradientSpread  :: Spread
    -- | Define the transformation to apply to the
    -- gradient points. Associated to the `gradientTransform`
    -- attribute.
  , _radialGradientTransform :: [Transformation]
    -- | List of color stops of the radial gradient.
  , _radialGradientStops   :: [GradientStop]
  }
  deriving (Eq, Show)

-- | Lenses for the RadialGradient type.
makeClassy ''RadialGradient

instance WithDefaultSvg RadialGradient where
  defaultSvg = RadialGradient
    { _radialGradientUnits   = GradientBoundingBox
    , _radialGradientCenter  = (Percent 0.5, Percent 0.5)
    , _radialGradientRadius  = Percent 0.5
    , _radialGradientFocusX  = Nothing
    , _radialGradientFocusY  = Nothing
    , _radialGradientSpread  = SpreadPad
    , _radialGradientTransform = []
    , _radialGradientStops   = []
    }

-- | Define the possible values of the `patternUnit`
-- attribute.
data PatternUnit
  = PatternUnitUserSpaceOnUse
  | PatternUnitObjectBoundingBox
  deriving (Eq, Show)

-- | Define a `<pattern>` tag.
data Pattern = Pattern
    { -- | Pattern drawing attributes.
      _patternDrawAttributes :: DrawAttributes
      -- | Possible `viewBox`.
    , _patternViewBox  :: Maybe (Int, Int, Int, Int)
      -- | Width of the pattern tile, mapped to the
      -- `width` attribute
    , _patternWidth    :: Number
      -- | Height of the pattern tile, mapped to the
      -- `height` attribute
    , _patternHeight   :: Number
      -- | Pattern tile base, mapped to the `x` and
      -- `y` attributes.
    , _patternPos      :: Point
      -- | Elements used in the pattern.
    , _patternElements :: [Tree]
      -- | Define the cordinate system to use for
      -- the pattern. Mapped to the `patternUnits`
      -- attribute.
    , _patternUnit     :: PatternUnit
    }
    deriving Show

-- | Lenses for the Patter type.
makeClassy ''Pattern

instance WithDrawAttributes Pattern where
    drawAttr = patternDrawAttributes

instance WithDefaultSvg Pattern where
  defaultSvg = Pattern
    { _patternViewBox  = Nothing
    , _patternWidth    = Num 0
    , _patternHeight   = Num 0
    , _patternPos      = (Num 0, Num 0)
    , _patternElements = []
    , _patternUnit = PatternUnitObjectBoundingBox
    , _patternDrawAttributes = mempty
    }

-- | Sum types helping keeping track of all the namable
-- elemens in a SVG document.
data Element
    = ElementLinearGradient LinearGradient
    | ElementRadialGradient RadialGradient
    | ElementGeometry Tree
    | ElementPattern  Pattern
    | ElementMarker Marker
    deriving Show

-- | Represent a full svg document with style,
-- geometry and named elements.
data Document = Document
    { _viewBox     :: Maybe (Int, Int, Int, Int)
    , _width       :: Maybe Number
    , _height      :: Maybe Number
    , _elements    :: [Tree]
    , _definitions :: M.Map String Element
    , _description  :: String
    , _styleText   :: String
    , _styleRules  :: [CssRule]
    }
    deriving Show

-- | Calculate the document size in function of the
-- different available attributes in the document.
documentSize :: Document -> (Int, Int)
documentSize Document { _width = Just (Num w)
                            , _height = Just (Num h) } = (floor w, floor h)
documentSize Document { _viewBox = Just (x1, y1, x2, y2)
                            , _width = Just (Percent pw)
                            , _height = Just (Percent ph)
                            } =
    (floor $ dx * pw, floor $ dy * ph)
      where
        dx = fromIntegral . abs $ x2 - x1
        dy = fromIntegral . abs $ y2 - y1
documentSize Document { _viewBox = Just (x1, y1, x2, y2) } =
    (abs $ x2 - x1, abs $ y2 - y1)
documentSize _ = (1, 1)

mayMerge :: Monoid a => Maybe a -> Maybe a -> Maybe a
mayMerge (Just a) (Just b) = Just $ mappend a b
mayMerge _ b@(Just _) = b
mayMerge a Nothing = a

instance Monoid DrawAttributes where
    mempty = DrawAttributes 
        { _strokeWidth      = Last Nothing
        , _strokeColor      = Last Nothing
        , _strokeOpacity    = Nothing
        , _strokeLineCap    = Last Nothing
        , _strokeLineJoin   = Last Nothing
        , _strokeMiterLimit = Last Nothing
        , _fillColor        = Last Nothing
        , _fillOpacity      = Nothing
        , _fontSize         = Last Nothing
        , _fontFamily       = Last Nothing
        , _fontStyle        = Last Nothing
        , _transform        = Nothing
        , _fillRule         = Last Nothing
        , _attrClass        = Last Nothing
        , _attrId           = Nothing
        , _strokeOffset     = Last Nothing
        , _strokeDashArray  = Last Nothing
        , _textAnchor       = Last Nothing

        , _markerStart      = Last Nothing
        , _markerMid        = Last Nothing
        , _markerEnd        = Last Nothing
        }

    mappend a b = DrawAttributes
        { _strokeWidth = (mappend `on` _strokeWidth) a b
        , _strokeColor =  (mappend `on` _strokeColor) a b
        , _strokeLineCap = (mappend `on` _strokeLineCap) a b
        , _strokeOpacity = (opacityMappend `on` _strokeOpacity) a b
        , _strokeLineJoin = (mappend `on` _strokeLineJoin) a b
        , _strokeMiterLimit = (mappend `on` _strokeMiterLimit) a b
        , _fillColor =  (mappend `on` _fillColor) a b
        , _fillOpacity = (opacityMappend `on` _fillOpacity) a b
        , _fontSize = (mappend `on` _fontSize) a b
        , _transform = (mayMerge `on` _transform) a b
        , _fillRule = (mappend `on` _fillRule) a b
        , _attrClass = (mappend `on` _attrClass) a b
        , _attrId = _attrId b
        , _strokeOffset = (mappend `on` _strokeOffset) a b
        , _strokeDashArray = (mappend `on` _strokeDashArray) a b
        , _fontFamily = (mappend `on` _fontFamily) a b
        , _fontStyle = (mappend `on` _fontStyle) a b
        , _textAnchor = (mappend `on` _textAnchor) a b
        , _markerStart = (mappend `on` _markerStart) a b
        , _markerMid = (mappend `on` _markerMid) a b
        , _markerEnd = (mappend `on` _markerEnd) a b
        }
      where
        opacityMappend Nothing Nothing = Nothing
        opacityMappend (Just v) Nothing = Just v
        opacityMappend Nothing (Just v) = Just v
        opacityMappend (Just v) (Just v2) = Just $ v * v2

instance WithDefaultSvg DrawAttributes where
  defaultSvg = mempty

instance CssMatcheable Tree where
  cssAttribOf _ _ = Nothing
  cssClassOf = fmap T.pack . getLast . view (drawAttr . attrClass)
  cssIdOf = fmap T.pack . view (drawAttr . attrId)
  cssNameOf = nameOfTree

