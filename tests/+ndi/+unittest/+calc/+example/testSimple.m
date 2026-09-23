classdef testSimple < ndi.unittest.session.buildSession
    % TESTSIMPLE - test the simple calculator

    methods (Test)
        function testSimpleCalc(testCase)
            % TESTSIMPLECALC - test the simple calculator
            %
            % Runs every self-test the calculator declares and verifies each one.
            % The number of tests comes from numberOfSelfTests, so it does not have
            % to be repeated here. requireDistinct additionally requires that the
            % tests give different answers from one another, and that their stored
            % expectations differ.

            S = ndi.calc.example.simple(testCase.Session);
            S.verifySelfTests(testCase,'requireDistinct',true);
        end
    end
end
