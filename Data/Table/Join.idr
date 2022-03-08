module Data.Table.Join

import public Data.Table.Column
import public Data.Table.Data
import public Data.Table.Record
import public Data.Table.Row
import public Data.Table.Row.Constructor
import public Data.Table.Schema
import public Data.Table.Schema.Quantifiers

import public Data.List
import public Data.List.Quantifiers

import Syntax.WithProof

public export
Reason : (0 prf : post === pre) -> Frame s post -> Frame s pre
Reason prf frm = replace {p = Frame s} prf frm

namespace Record
  public export
  (|*|) : Record schema1 -> Frame schema2 n -> Frame (schema1 ++ schema2) n
  rec |*| frame = Reason
                    (plusZeroRightNeutral _) $
                    ([< rec] `Element` %search) |*| frame

namespace Frame
  public export
  (|*|) : Frame schema1 n1 -> Frame schema2 n2
    -> Frame (schema1 ++ schema2) (n1*n2)
  frame1 |*| frame2 =
    let 0 hasRows1 = frame1.snd
        0 hasRows2 = frame2.snd
    in (frame1.fst |*| frame2.fst)
         `Element`
       (crossJoinHasRows frame1.fst frame2.fst)

public export
(|!|) : {schema : Schema} ->
  Foldable f => (rec : Record schema) -> (names : f String) -> Record (schema |!| names)
[<] |!| names = [<]
((rec :< fld) |!| names) with (schema.tail.Name `elem` names)
  _ | True  = (rec |!| names) :< fld
  _ | False = (rec |!| names)

public export
(|-|) : {schema : Schema} ->
  Foldable f => (rec : Record schema) -> (names : f String) -> Record (schema |-| names)
[<] |-| names = [<]
(rec :< fld) |-| names with (schema.tail.Name `elem` names)
 _ | True  = (rec |-| names)
 _ | False = (rec |-| names) :< fld

data FieldNamed : Schema -> String -> Type where
  Here : FieldNamed (schema :< (name :! type)) name
  There : FieldNamed schema name -> FieldNamed (schema :< fld) name

infix 4 !!

(!!) : (schema : Schema) -> schema `FieldNamed` name -> Type
-- silly: re-ordering these clauses produces the correct case tree
(schema :< fld) !! (There pos) = schema !! pos
(schema :< (name :! type)) !! Here = type

cast : (pos : schema `FieldNamed` name) -> Field schema name (schema !! pos)
cast Here = Here
cast (There pos) = There $ cast pos
namespace Thin
  public export
  data Thin : (src, tgt : Schema) -> Type where
    Lin : Thin [<] schema
    K{-eep-} : Thin src tgt -> Thin (src :< fld) (tgt :< fld)
    T{-hin-} : Thin src tgt -> Thin src (tgt :< fld)

namespace Mask
  -- Can help thinking about thinnings as bit-masks
  public export
  data Bit = K | T

  public export
  data Mask : Schema -> Type where
    Lin : Mask [<]
    (:<) : Mask schema -> Bit -> Mask (schema :< fld)

  public export
  (.in) : {schema : Schema} -> Mask schema -> Schema
  [<].in = [<]
  (mask :< K).in {schema = schema :< fld} = mask.in :< fld
  (mask :< T).in = mask.in

  public export
  (.out) : {schema : Schema} -> Mask schema -> Schema
  [<].out = [<]
  (mask :< T).out {schema = schema :< fld} = mask.out :< fld
  (mask :< K).out = mask.out

  public export
  Fwd : (mask : Mask schema) -> Thin mask.in schema
  Fwd [<] = [<]
  Fwd (mask :< K) = K (Fwd mask)
  Fwd (mask :< T) = T (Fwd mask)

  public export
  Bwd : {schema : Schema} -> Thin src schema -> Mask schema
  Bwd [<] {schema = [<]} = [<]
  Bwd [<] {schema = (schema :< fs)} = Bwd [<] :< T
  Bwd (K x) = Bwd x :< K
  Bwd (T x) = Bwd x :< T

  public export
  (.flip) : Mask schema -> Mask schema
  [<].flip = [<]
  (mask :< K).flip = mask.flip :< T
  (mask :< T).flip = mask.flip :< K

  export
  flipInOut : (mask : Mask schema) -> mask.flip.in = mask.out
  flipInOut [<] = Refl
  flipInOut (mask :< K) = flipInOut mask
  flipInOut ((mask :< T) {fld}) = cong (:< fld) $ flipInOut mask


namespace Thin
  public export
  (|!|) : (schema : Schema) -> Thin src schema -> Schema
  schema |!| thin = (Bwd thin).out

  public export
  (.complement) : {schema : Schema} -> (thin : Thin src schema)
    -> Thin (schema |!| thin) schema
  thin.complement = replace {p = flip Thin schema}
                    (flipInOut _)
                    $ Fwd (Bwd thin).flip

namespace Projection
  public export
  FieldTyped : Schema -> Type -> Type
  FieldTyped schema type = Exists (\name => Field schema name type)

  public export
  Ren : (src, tgt : Schema) -> Type
  Ren src tgt = All (\fld => tgt `FieldTyped` fld.Sort) src

  public export
  (.project) : (rec : Record schema) -> FieldTyped schema type -> type
  rec.project pos = ?iAmHere

public export total
jointSchemaType : (schema1, schema2 : Schema) -> String -> Type
jointSchemaType schema1 schema2 fld =
 (pos : schema1 `FieldNamed` fld ** (Field schema2 fld (schema1 !! pos), Eq (schema1 !! pos)))

-- For now, since Data.List's intersect is export non-public

public export
intersectByPublic : (a -> a -> Bool) -> List a -> List a -> List a
intersectByPublic eq xs ys = [x | x <- xs, any (eq x) ys]

public export
intersectPublic : Eq a => List a -> List a -> List a
intersectPublic = intersectByPublic (==)


public export
jointNames : (schema1, schema2 : Schema) -> List String
jointNames schema1 schema2 = (names schema1 <>> []) `intersectPublic` (names schema2 <>> [])

mkSchema : List (String, Type) -> Schema

(.project) : Record schema -> (proj : List (Exists $ \(fld,type) => Field schema fld type))
  -> Record (mkSchema $ map Exists.fst proj)

public export
join : {schema1,schema2 : Schema} -> (rec1 : Record schema1) -> (rec2 : Record schema2)
  -> {auto 0 ford1 : u === (jointSchemaType schema1 schema2)}
  -> {auto 0 ford2 : v === (jointNames schema1 schema2)}
  -> {auto joint : All u v}
  -> Table (schema1 ++ (schema2 |-| names schema1))
join rec1 rec2 {joint} = ?h910

S1, S2 : Schema
S1 = [< "a" :! Nat, "b" :! Bool]
S2 = [< "a" :! Nat, "b" :! Bool]

T1 : Record S1
T2 : Record S2

H : ?
H = join T1 T2

{-
join rec1 rec2 {joint} =
  if all (\case
            Nothing => True
            Just pos => value pos rec2 ?h2) joint
  then ?h23
  else ?h3
-}
{-
IsSubschema : (sub, super : Schema) -> Type
IsSubschema sub super = All (\fld => Field super fld.Name fld.Sort) sub

Subschema : (super : Schema) -> Type
Subschema super = Exists (\sub => sub `IsSubschema` super)

foo : Record super -> Unit
foo rec {super} with (rec)
 foo [<] {super = _}| rec0 = ?h2_0
 foo rec'@(rec :< x) {super = _}| rec0 = ?h2_1

infixl 5 |., \.


||| Project a Subschema out of a schema
public export
(|.) : Record super -> (sub : Subschema super) -> Record (sub.fst)
(rec  |. sub@(Evidence _ _)) {super} with (sub.snd)
 (rec |. sub@(Evidence _ _)) {super} | [<] = [<]
 ([<] |. sub@(Evidence _ _)) {super = [<]} | (x :< _) impossible
 (rec |. sub@(Evidence f _)) {super} | (x :< loc) {col = _ :! _}
   = (rec |. Evidence _ x) :< (value loc rec)

public export
(\.) : (super : Schema) -> (sub : Subschema super) -> Schema
super \. (Evidence fst snd) = ?op_rhs_0


JoinType : (a,b,c : Type) -> Type
JoinType a b c = a -> b -> Maybe c

infix 6 =<=, =>=

-- Examples
(=<=) : Eq a => JoinType a a a
x =<= y = if x == y then Just x else Nothing

(=>=) : Eq a => JoinType a a a
x =>= y = y =<= x

data Join : (schema1, schema2 : Schema) -> Type where
  Nil : Join schema1 schema2
  (::) :
       ( Field schema1 name1 type1
       , Field schema2 name2 type2
       , JoinType type1 type2 result
       )
    -> Join schema1 schema2 -> Join schema1 schema2

-- smart constructor

When : (name1 : String) -> JoinType type1 type2 result -> (name2 : String)
  -> (lftField : Field schema1 name1 type1)
  => (rgtField : Field schema2 name2 type2)
  => ( Field schema1 name1 type1
     , Field schema2 name2 type2
     , JoinType type1 type2 result
     )
When _ join _ {lftField, rgtField} = (lftField, rgtField, join)

guardLeft : (a -> x) -> (x -> x -> Bool) -> (b -> x) -> a -> b -> Maybe a


blah : Join [< "a" :! String, "b" :! Char] [< "c" :! Int, "d" :! Char]
blah = [When "b" (=<=) "d", When "a" (guardLeft (cast . length) (==) id) "c"]


infixl 5 |><|, ><|, |><, ><

defaultCombinationLft ,
defaultCombinationRgt : (schema1, schema2 : Schema) -> Schema
defaultCombinationLft schema1 schema2 = schema1 ++ (schema2 |-| names schema1)
defaultCombinationRgt schema1 schema2 = schema1 ++ (schema2 |-| names schema1)


combineLft : (schema1, schema2 : Schema)
  -> Record schema1 -> Record schema2
  -> Record (schema1 `defaultCombinationLft` schema2)

-- Inefficient, but that's not the point
joinBy : Table schema1 -> Table schema2 -> (Record schema1 -> Record schema2
  -> Maybe (Record schema3)) -> Table schema3
joinBy table1 table2 join = do
  xs <- table1
  ys <- table2
  case join xs ys of
    Nothing  => [<]
    Just rec => [< rec]
-}
