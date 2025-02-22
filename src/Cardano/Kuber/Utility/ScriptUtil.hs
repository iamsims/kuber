module Cardano.Kuber.Utility.ScriptUtil where
import Cardano.Api
import Cardano.Kuber.Error
import Cardano.Api.Shelley (fromPlutusData, PlutusScriptOrReferenceInput (PScript, PReferenceScript), SimpleScriptOrReferenceInput (SScript), PlutusScript (PlutusScriptSerialised))
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString.Short as SBS
import Codec.Serialise (serialise)
import qualified Plutus.V2.Ledger.Api as PV2
import qualified Plutus.V1.Ledger.Api as PV1

createTxInScriptWitness :: ScriptInAnyLang -> Maybe ScriptData -> ScriptData -> ExecutionUnits -> Either FrameworkError  (ScriptWitness WitCtxTxIn BabbageEra)
createTxInScriptWitness anyScript mDatum redeemer exUnits = do
  ScriptInEra langInEra script' <- validateScriptSupportedInEra' BabbageEra anyScript
  case script' of
    PlutusScript version pscript ->
      pure $ PlutusScriptWitness langInEra version (PScript pscript) datumForTxin redeemer exUnits
    SimpleScript version sscript ->Left $ FrameworkError  WrongScriptType "Simple Script used in Txin"
  where
    datumForTxin = maybe InlineScriptDatum ScriptDatumForTxIn mDatum


createTxInReferenceScriptWitness :: TxIn -> Maybe ScriptHash -> Maybe ScriptData -> ScriptData -> ExecutionUnits -> Either FrameworkError (ScriptWitness WitCtxTxIn BabbageEra)
createTxInReferenceScriptWitness scTxIn mScriptHash mDatum redeemer exUnits = pure $ PlutusScriptWitness PlutusScriptV2InBabbage PlutusScriptV2 (PReferenceScript scTxIn mScriptHash) datumForTxin redeemer exUnits
  where
    datumForTxin = maybe InlineScriptDatum ScriptDatumForTxIn mDatum


createPlutusMintingWitness :: ScriptInAnyLang ->ScriptData ->ExecutionUnits -> Either FrameworkError  (ScriptWitness WitCtxMint BabbageEra)
createPlutusMintingWitness anyScript redeemer exUnits = do
  ScriptInEra langInEra script' <- validateScriptSupportedInEra' BabbageEra anyScript
  case script' of
    PlutusScript version pscript ->
      pure $ PlutusScriptWitness langInEra version (PScript pscript) NoScriptDatumForMint redeemer exUnits
    SimpleScript version sscript -> Left $ FrameworkError WrongScriptType "Simple script not supported on creating plutus script witness."

createSimpleMintingWitness :: ScriptInAnyLang -> Either FrameworkError (ScriptWitness WitCtxMint BabbageEra)
createSimpleMintingWitness anyScript = do
  ScriptInEra langInEra script' <- validateScriptSupportedInEra' BabbageEra anyScript
  case script' of
    PlutusScript version pscript -> Left $ FrameworkError  WrongScriptType "Plutus script not supported on creating simple script witness"
    SimpleScript version sscript -> pure $ SimpleScriptWitness langInEra version (SScript sscript)


validateScriptSupportedInEra' ::  CardanoEra era -> ScriptInAnyLang -> Either FrameworkError (ScriptInEra era)
validateScriptSupportedInEra' era script@(ScriptInAnyLang lang _) =
  case toScriptInEra era script of
    Nothing -> Left $ FrameworkError WrongScriptType   (show lang ++ " not supported in " ++ show era ++ " era")
    Just script' -> pure script'

fromPlutusV2Validator :: PV2.Validator -> Script PlutusScriptV2
fromPlutusV2Validator validator = fromPlutusV2Script  $ PV2.unValidatorScript validator

fromPlutusV1Validator :: PV1.Validator -> Script PlutusScriptV1
fromPlutusV1Validator validator = fromPlutusV1Script $ PV1.unValidatorScript validator


fromPlutusV2Script :: PV2.Script -> Script PlutusScriptV2
fromPlutusV2Script plutusScript = PlutusScript PlutusScriptV2 $ PlutusScriptSerialised . SBS.toShort . LBS.toStrict $ serialise plutusScript

fromPlutusV1Script :: PV1.Script -> Script PlutusScriptV1
fromPlutusV1Script plutusScript = PlutusScript PlutusScriptV1 $ PlutusScriptSerialised . SBS.toShort . LBS.toStrict $ serialise plutusScript
