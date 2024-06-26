{-# LANGUAGE OverloadedStrings #-}

module Tests.Test.HUnitPlus.ReporterUtils where

import Control.Monad
import Data.List
import Distribution.TestSuite(Result(Pass, Fail))
import Test.HUnitPlus.Reporting

import qualified Data.HashMap.Strict as HashMap
import qualified Data.Text as Strict

data ReportEvent =
    End Double
  | StartSuite
  | EndSuite Double
  | StartCase
  | EndCase Double
  | Skip
  | Progress Strict.Text
  | Failure Strict.Text
  | Error Strict.Text
  | Exception Strict.Text
  | SystemErr Strict.Text
  | SystemOut Strict.Text
    deriving (Show)

instance Eq ReportEvent where
  End e1 == End e2 = e1 == e2
  StartSuite == StartSuite = True
  EndSuite e1 == EndSuite e2 = e1 == e2
  StartCase == StartCase = True
  EndCase e1 == EndCase e2 = e1 == e2
  Skip == Skip = True
  Progress s1 == Progress s2 = s1 == s2
  Failure s1 == Failure s2 = s1 == s2
  Error s1 == Error s2 = s1 == s2
  Exception s1 == Error s2 = Strict.isInfixOf s1 s2
  Error s1 == Exception s2 = Strict.isInfixOf s2 s1
  Exception s1 == Exception s2 = s1 == s2
  SystemErr s1 == SystemErr s2 = s1 == s2
  SystemOut s1 == SystemOut s2 = s1 == s2
  _ == _ = False

type ReporterOp us = (State, us) -> IO (State, us)

loggingReporter :: Reporter [ReportEvent]
loggingReporter = defaultReporter {
    reporterStart = return [],
    reporterEnd = (\time _ events -> return (events ++ [End time])),
    reporterStartSuite = (\_ events -> return (events ++ [StartSuite])),
    reporterEndSuite = (\time _ events -> return (events ++ [EndSuite time])),
    reporterStartCase = (\_ events -> return (events ++ [StartCase])),
    reporterEndCase = (\time _ events -> return (events ++ [EndCase time])),
    reporterSkipCase = (\_ events -> return (events ++ [Skip])),
    reporterCaseProgress = (\msg _ events -> return (events ++ [Progress msg])),
    reporterFailure = (\msg _ events -> return (events ++ [Failure msg])),
    reporterError = (\msg _ events -> return (events ++ [Error msg])),
    reporterSystemErr = (\msg _ events -> return (events ++ [SystemErr msg])),
    reporterSystemOut = (\msg _ events -> return (events ++ [SystemOut msg]))
  }

initState :: State
initState = State { stName = "", stPath = [], stCounts = zeroCounts,
                    stOptions = HashMap.empty, stOptionDescs = [] }

setName :: Strict.Text -> ReporterOp us
setName name (s@State { stName = _ }, repstate) =
  return (s { stName = name }, repstate)

setOpt :: Strict.Text -> Strict.Text -> ReporterOp us
setOpt key value (s@State { stOptions = opts }, repstate) =
  return (s { stOptions = HashMap.insert key value opts }, repstate)

pushPath :: Strict.Text -> ReporterOp us
pushPath name (s@State { stPath = path }, repstate) =
  return (s { stPath = Label name : path }, repstate)

popPath :: ReporterOp us
popPath (s@State { stPath = _ : path }, repstate) =
  return (s { stPath = path }, repstate)

addOption :: Strict.Text -> Strict.Text -> ReporterOp us
addOption key value (s@State { stOptions = opts }, repstate) =
  return (s { stOptions = HashMap.insert key value opts }, repstate)

countAsserts :: Word -> ReporterOp us
countAsserts count (s@State { stCounts = c@Counts { cAsserts = n } },
                    repstate) =
  return (s { stCounts = c { cAsserts = n + count,
                             cCaseAsserts = count } }, repstate)

countTried :: Word -> ReporterOp us
countTried count (s@State { stCounts = c@Counts { cCases = cases,
                                                      cTried = tried } },
                  repstate) =
  return (s { stCounts = c { cCases = cases + count,
                             cTried = tried + count } },
          repstate)

countSkipped :: Word -> ReporterOp us
countSkipped count (s@State { stCounts = c@Counts { cSkipped = skipped,
                                                        cCases = cases } },
                  repstate) =
  return (s { stCounts = c { cSkipped = skipped + count,
                             cCases = cases + count } },
          repstate)

countErrors :: Word -> ReporterOp us
countErrors count (s@State { stCounts = c@Counts { cErrors = errors } },
                   repstate) =
  return (s { stCounts = c { cErrors = errors + count } }, repstate)

countFailed :: Word -> ReporterOp us
countFailed count (s@State { stCounts = c@Counts { cFailures = failed } },
                   repstate) =
  return (s { stCounts = c { cFailures = failed + count } }, repstate)

reportProgress :: Reporter us -> Strict.Text -> ReporterOp us
reportProgress reporter msg (state, repstate) =
  do
    repstate' <- (reporterCaseProgress reporter) msg state repstate
    return (state, repstate')

reportSystemErr :: Reporter us -> Strict.Text -> ReporterOp us
reportSystemErr reporter msg (state, repstate) =
  do
    repstate' <- (reporterSystemErr reporter) msg state repstate
    return (state, repstate')

reportSystemOut :: Reporter us -> Strict.Text -> ReporterOp us
reportSystemOut reporter msg (state, repstate) =
  do
    repstate' <- (reporterSystemOut reporter) msg state repstate
    return (state, repstate')

reportFailure :: Reporter us -> Strict.Text -> ReporterOp us
reportFailure reporter msg (state, repstate) =
  do
    repstate' <- (reporterFailure reporter) msg state repstate
    return (state, repstate')

reportError :: Reporter us -> Strict.Text -> ReporterOp us
reportError reporter msg (state, repstate) =
  do
    repstate' <- (reporterError reporter) msg state repstate
    return (state, repstate')

reportSkip :: Reporter us -> ReporterOp us
reportSkip reporter (state, repstate) =
  do
    repstate' <- (reporterSkipCase reporter) state repstate
    return (state, repstate')

reportStartCase :: Reporter us -> ReporterOp us
reportStartCase reporter (state, repstate) =
  do
    repstate' <- (reporterStartCase reporter) state repstate
    return (state, repstate')

reportEndCase :: Reporter us -> Double -> ReporterOp us
reportEndCase reporter time (state, repstate) =
  do
    repstate' <- (reporterEndCase reporter) time state repstate
    return (state, repstate')

reportStartSuite :: Reporter us -> ReporterOp us
reportStartSuite reporter (state, repstate) =
  do
    repstate' <- (reporterStartSuite reporter) state repstate
    return (state, repstate')

reportEndSuite :: Reporter us -> Double -> ReporterOp us
reportEndSuite reporter time (state, repstate) =
  do
    repstate' <- (reporterEndSuite reporter) time state repstate
    return (state, repstate')

reportEnd :: Reporter us -> Double -> ReporterOp us
reportEnd reporter time (state@State { stCounts = counts }, repstate) =
  do
    repstate' <- (reporterEnd reporter) time counts repstate
    return (state, repstate')

runReporterTest :: Eq us => Reporter us -> [ReporterOp us] -> us ->
                   (us -> String) -> IO Result
runReporterTest reporter tests expected format =
  do
    initrepstate <- reporterStart reporter
    (_, actual) <- foldM (\state op -> op state) (initState, initrepstate) tests
    if actual == expected
      then return Pass
      else return (Fail ("Expected " ++ format expected ++
                        "\nbut got " ++ format actual))
