{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Stack.Freeze
    ( freeze
    , FreezeOpts (..)
    , FreezeMode (..)
    ) where

import           Data.Aeson ((.=), object)
import qualified Data.Yaml as Yaml
import qualified RIO.ByteString as B
import           Stack.Prelude
import           Stack.Types.BuildPlan
import           Stack.Types.Config

data FreezeMode = FreezeProject | FreezeSnapshot

newtype FreezeOpts = FreezeOpts
    { freezeMode :: FreezeMode
    }

freeze :: HasEnvConfig env => FreezeOpts -> RIO env ()
freeze (FreezeOpts FreezeProject) = do
  mproject <- view $ configL.to configMaybeProject
  case mproject of
    Just (p, _) -> do
      let deps = projectDependencies p
          resolver = projectResolver p
          completePackageLocation' pl =
            case pl of
              PLImmutable pli -> PLImmutable <$> completePackageLocation pli
              plm@(PLMutable _) -> pure plm
      resolver' <- completeSnapshotLocation resolver
      deps' <- mapM completePackageLocation' deps
      if deps' == deps && resolver' == resolver
      then
        logInfo "No freezing is required for this project"
      else do
        logInfo "# Fields not mentioned below do not need to be updated"

        if resolver' == resolver
          then logInfo "# No update to resolver is needed"
          else do
            logInfo "# Frozen version of resolver"
            B.putStr $ Yaml.encode $ object ["resolver" .= resolver']

        if deps' == deps
          then logInfo "# No update to extra-deps is needed"
          else do
            logInfo "# Frozen version of extra-deps"
            B.putStr $ Yaml.encode $ object ["extra-deps" .= deps']
    Nothing -> logWarn "No project was found: nothing to freeze"

freeze (FreezeOpts FreezeSnapshot) = do
  undefined
  {-
  msnapshot <- view $ buildConfigL.to bcSnapshotDef.to sdSnapshot
  case msnapshot of
    Just (snap, _) -> do
      snap' <- completeSnapshot snap
      if snap' == snap
      then
        logInfo "No freezing is required for the snapshot of this project"
      else
        liftIO $ B.putStr $ Yaml.encode snap'
    Nothing ->
      logWarn "No snapshot was found: nothing to freeze"
  -}
