module Tests.Test.HUnit.Reporting where

import Data.List
import Distribution.TestSuite(Test(..),
                              TestInstance(..),
                              Progress(Finished),
                              testGroup)
import Test.HUnit.Reporting
import Tests.Test.HUnit.ReporterUtils(ReportEvent(..))

import qualified Tests.Test.HUnit.ReporterUtils as Utils

type ReporterState = [ReportEvent]
type CombinedReporterState = (ReporterState, ReporterState)
type ReporterOp = Utils.ReporterOp ReporterState
type CombinedReporterOp = Utils.ReporterOp CombinedReporterState

loggingReporter = Utils.loggingReporter

combinedLoggingReporter :: Reporter CombinedReporterState
combinedLoggingReporter = combinedReporter loggingReporter loggingReporter

reportSystemErr = Utils.reportSystemErr combinedLoggingReporter
reportSystemOut = Utils.reportSystemOut combinedLoggingReporter
reportFailure = Utils.reportFailure combinedLoggingReporter
reportError = Utils.reportError combinedLoggingReporter
reportSkip = Utils.reportSkip combinedLoggingReporter
reportProgress = Utils.reportProgress combinedLoggingReporter
reportStartCase = Utils.reportStartCase combinedLoggingReporter
reportEndCase = Utils.reportEndCase combinedLoggingReporter
runReporterTest = Utils.runReporterTest combinedLoggingReporter
reportStartSuite = Utils.reportStartSuite combinedLoggingReporter
reportEndSuite = Utils.reportEndSuite combinedLoggingReporter
reportEnd = Utils.reportEnd combinedLoggingReporter

reporterActions :: [(String, CombinedReporterOp, ReporterState)]
reporterActions = [
    ("systemErr", reportSystemErr "Error Message", [SystemErr "Error Message"]),
    ("systemOut", reportSystemOut "Output Message",
     [SystemOut "Output Message"]),
    ("failure", reportFailure "Failure Message", [Failure "Failure Message"]),
    ("error", reportError "Error Message", [Error "Error Message"]),
    ("progress", reportProgress "Progress Message",
     [Progress "Progress Message"]),
    ("skip", reportSkip, [Skip]),
    ("startCase", reportStartCase, [StartCase]),
    ("endCase", reportEndCase 1.0, [EndCase 1.0]),
    ("startSuite", reportStartSuite, [StartSuite]),
    ("endSuite", reportEndSuite 2.0, [EndSuite 2.0]),
    ("end", reportEnd 3.0, [End 3.0])
  ]

reporterCases :: [[(String, CombinedReporterOp, ReporterState)]]
reporterCases =
  map (: []) reporterActions ++
  foldr (\a accum ->
          foldr (\b accum -> [a, b] : accum)
                accum reporterActions)
        [] reporterActions

genCombinedReporterTest :: [(String, CombinedReporterOp, ReporterState)] -> Test
genCombinedReporterTest testactions =
  let
    name = intercalate "_" (map (\(a, _, _) -> a) testactions)
    ops = map (\(_, a, _) -> a) testactions
    log = concat (map (\(_, _, a) -> a) testactions)
    expected = (log, log)

    out = TestInstance { name = "combinedReporter_ " ++ name,
                         tags = [], options = [],
                         setOption = (\_ _ -> Right out),
                         run = runReporterTest ops expected show >>=
                               return . Finished }
  in
    Test out

tests :: Test
tests = testGroup "Reporting" (map genCombinedReporterTest reporterCases)