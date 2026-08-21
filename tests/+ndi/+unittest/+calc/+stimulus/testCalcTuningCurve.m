classdef testCalcTuningCurve < ndi.unittest.session.buildSession
    % TESTCALCTUNINGCURVE - test the tuningcurve calculator

    methods (Test)
        function testTuningCurveCalc(testCase)
            % TESTTUNINGCURVECALC - test the tuningcurve calculator
            %
            % Runs every self-test the calculator declares and verifies each one.
            % The number of tests comes from numberOfSelfTests, so it does not have
            % to be repeated here. requireDistinct additionally requires that the
            % tests give different answers from one another, and that their stored
            % expectations differ.

            S = ndi.calc.stimulus.tuningcurve(testCase.Session);
            S.verifySelfTests(testCase,'requireDistinct',true);
        end
    end
end
