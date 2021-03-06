{-# LANGUAGE DeriveLift                 #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}
{-# LANGUAGE OverloadedStrings          #-}

module Hasura.RQL.Types.Permission
       ( RoleName(..)
       , UserId(..)
       , UserInfo(..)
       , adminUserInfo
       , adminRole
       , PermType(..)
       , permTypeToCode
       , PermId(..)
       ) where

import           Hasura.SQL.Types
import           Hasura.Prelude

import qualified Database.PG.Query          as Q

import           Data.Aeson
import           Data.Hashable
import           Data.Word
import           Instances.TH.Lift          ()
import           Language.Haskell.TH.Syntax (Lift)

import qualified Data.Text                  as T
import qualified PostgreSQL.Binary.Decoding as PD

newtype RoleName
  = RoleName {getRoleTxt :: T.Text}
  deriving ( Show, Eq, Hashable, FromJSONKey, ToJSONKey, FromJSON
           , ToJSON, Q.FromCol, Q.ToPrepArg, Lift)

instance DQuote RoleName where
  dquoteTxt (RoleName r) = r

adminRole :: RoleName
adminRole = RoleName "admin"

newtype UserId = UserId { getUserId :: Word64 }
  deriving (Show, Eq, FromJSON, ToJSON)

data UserInfo
  = UserInfo
  { userRole    :: !RoleName
  , userHeaders :: ![(T.Text, T.Text)]
  } deriving (Show, Eq)

adminUserInfo :: UserInfo
adminUserInfo = UserInfo adminRole [("X-Hasura-User-Id", "0")]

data PermType
  = PTInsert
  | PTSelect
  | PTUpdate
  | PTDelete
  deriving (Eq, Lift)

instance Q.FromCol PermType where
  fromCol bs = flip Q.fromColHelper bs $ PD.enum $ \case
    "insert" -> Just PTInsert
    "update" -> Just PTUpdate
    "select" -> Just PTSelect
    "delete" -> Just PTDelete
    _   -> Nothing

permTypeToCode :: PermType -> T.Text
permTypeToCode PTInsert = "insert"
permTypeToCode PTSelect = "select"
permTypeToCode PTUpdate = "update"
permTypeToCode PTDelete = "delete"

instance Hashable PermType where
  hashWithSalt salt a = hashWithSalt salt $ permTypeToCode a

instance Show PermType where
  show PTInsert = "insert"
  show PTSelect = "select"
  show PTUpdate = "update"
  show PTDelete = "delete"

instance FromJSON PermType where
  parseJSON (String "insert") = return PTInsert
  parseJSON (String "select") = return PTSelect
  parseJSON (String "update") = return PTUpdate
  parseJSON (String "delete") = return PTDelete
  parseJSON _ =
    fail "perm_type should be one of 'insert', 'select', 'update', 'delete'"

instance ToJSON PermType where
  toJSON = String . permTypeToCode

data PermId
  = PermId
  { pidTable :: !TableName
  , pidRole  :: !RoleName
  , pidType  :: !PermType
  } deriving (Eq)

instance Show PermId where
  show (PermId tn rn pType) =
    show $ mconcat
    [ getTableTxt tn
    , "."
    , getRoleTxt rn
    , "."
    , T.pack $ show pType
    ]
