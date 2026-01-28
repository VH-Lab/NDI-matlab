classdef testSimple < ndi.unittest.session.buildSession
    % TESTSIMPLE - test the simple calculator

    methods (Test)
        function testSimpleCalc(testCase)
            % TESTSIMPLECALC - test the simple calculator

            % Create the calculator
            S = ndi.calc.example.simple(testCase.Session);

            % Run the test
            % S.test(scope, number_of_tests, plot_it)
            % Use 2 tests because numberOfSelfTests is 2
            [b, reports, b_expected] = S.test('highSNR', 2, 0);

            % Verify first output (b) is diag([1 1])
            expected_matrix = diag([1 1]);
            testCase.verifyTrue(isequal(double(b), expected_matrix), ...
                'First output argument (b) should be diag([1 1])');

            % Verify third output (b_expected) is diag([1 1])
            testCase.verifyTrue(isequal(double(b_expected), expected_matrix), ...
                'Third output argument (b_expected) should be diag([1 1])');

            % Check that reports is present (optional but good sanity check)
            testCase.verifyNotEmpty(reports, 'Reports should not be empty');
        end
    end
end
