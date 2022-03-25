module Data.Table.Schema.Data

import public Data.DPair
import Decidable.Equality

%default total

infix 10 :!

public export
data FieldSchema = (:!) String Type

%name FieldSchema fs

public export
(.Name) : FieldSchema -> String
(name :! _).Name = name

public export
(.Sort) : FieldSchema -> Type
(_ :! sort).Sort = sort

public export
data Schema : Type where
    Lin : Schema
    (:<) : Schema -> FieldSchema -> Schema

%name Schema schema

public export
names : Schema -> SnocList String
names [<] = [<]
names (schema :< (name :! type)) = names schema :< name

public export
types : Schema -> SnocList Type
types [<] = [<]
types (schema :< (name :! type)) = types schema :< type

public export
length : Schema -> Nat
length [<] = 0
length (schema :< _) = S (length schema)

public export
data Field : (schema : Schema) -> (name : String) -> Type -> Type where [search schema name]
    Here : Field (schema :< (name :! type)) name type
    There : (fld : Field schema name type) -> Field (schema :< fs) name type

public export
weaken : Field schema name type -> Field (schema :< col) name type
weaken fld = There fld

%name Field fld

public export
(++) : Schema -> Schema -> Schema
schema1 ++ [<] = schema1
schema1 ++ (schema2 :< fs) = (schema1 ++ schema2) :< fs

public export
(.field) : {schema : Schema} -> Field schema name type -> FieldSchema
(Here).field {schema = _ :< fld@(_ :! _)} = fld
(There fld).field = fld.field

-- Pivoted types of fields
public export
FieldNamed : Schema -> String -> Type
FieldNamed schema name = Exists (\type => Field schema name type)

infix 4 !!

public export
(!!) : (schema : Schema) -> schema `FieldNamed` name -> Type
schema !! pos = pos.snd.field.Sort

public export
FieldTyped : Schema -> Type -> Type
FieldTyped schema type = Exists (\name => Field schema name type)

recallAux : {schema : Schema} -> (0 type : Type) ->
  (fld : Field schema name type) -> type === (schema !! (Evidence type fld))
recallAux type Here = Refl
recallAux type (There fld)
  {schema = _ :< _ :! _}
  = recallAux type fld

export
recall : {schema : Schema} -> (fld : schema `FieldNamed` n) -> fld.fst = schema !! fld
recall fld = recallAux fld.fst fld.snd

public export
weakenField : (schema2 : Schema) ->
  Field schema1 name type ->
  Field (schema1 ++ schema2) name type
weakenField [<]            fld = fld
weakenField (schema :< fs) fld = There (weakenField schema fld)

export
decEqHet : 
  (fld1 : Field schema name1 type1) ->
  (fld2 : Field schema name2 type2) ->
  Dec (fld1 = fld2)

export
DecEq (Field schema name type) where
  decEq Here Here = Yes Refl
  decEq Here (There fld) = No $ \case _ impossible
  decEq (There fld) Here = No $ \case _ impossible
  decEq (There fld1) (There fld2) = case decEq fld1 fld2 of
    Yes prf   => Yes $ cong There prf
    No contra => No $ \Refl => contra Refl

export
DecEq (FieldTyped schema type) where
  decEq fld1@(Evidence _ _) fld2@(Evidence _ _) = case decEqHet fld1.snd fld2.snd of
    Yes prf   => Yes ?h190
    No contra => ?h1_1
