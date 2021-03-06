{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}

module Model.User where

import Data.Text
import Database.Persist.Quasi
import Database.Persist.Sql
import Database.Persist.TH
import GHC.Generics
import Model.Json
import Servant.Docs

mkPersist
  sqlSettings
  { mpsPrefixFields = False
  , mpsEntityJSON =
      Just
        EntityJSON
        { entityToJSON = 'myKeyValueEntityToJSON
        , entityFromJSON = 'myKeyValueEntityFromJSON
        }
  }
  $(persistFileWith lowerCaseSettings "config/models/user")

instance ToSample (Entity User) where
  toSamples _ =
    samples
      [ Entity (UserKey 1) (User "Alice" 42)
      , Entity (UserKey 2) (User "Bob" 32)
      , Entity (UserKey 3) (User "Snoyman" 30)
      ]

instance ToSample User where
  toSamples _ = samples [User "Alice" 42, User "Bob" 32, User "Snoyman" 30]

instance ToSample UserId where
  toSamples _ = singleSample (UserKey 1)
