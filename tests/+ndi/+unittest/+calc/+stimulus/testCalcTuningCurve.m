classdef testCalcTuningCurve < ndi.unittest.session.buildSession
    % TESTCALCTUNINGCURVE - test the tuningcurve calculator

    methods (Test)
        function testTuningCurveCalc(testCase)
            % TESTTUNINGCURVECALC - test the tuningcurve calculator

            % Create the calculator
            S = ndi.calc.stimulus.tuningcurve(testCase.Session);

            % Run the test
            % S.test(scope, number_of_tests, plot_it)
            % Use 4 tests because numberOfSelfTests is 4
            [b, reports, b_expected] = S.test('highSNR', 4, 0);

            % DIAGNOSTIC: dump b, b_expected, and the reports for any cell
            % where b is not what diag([1 1 1 1]) expects, so CI logs
            % localize which i,j pair broke. Remove once root-caused.
            expected_matrix = diag([1 1 1 1]);
            actual_b = double(b);
            if ~isequal(actual_b, expected_matrix)
                fprintf('=== testTuningCurveCalc diagnostic ===\n');
                fprintf('b (actual):\n');
                disp(actual_b);
                fprintf('b_expected (expected-vs-expected):\n');
                disp(double(b_expected));
                for i = 1:size(actual_b, 1)
                    for j = 1:size(actual_b, 2)
                        if actual_b(i,j) ~= expected_matrix(i,j)
                            fprintf('--- mismatch at (i=%d, j=%d): got %g, want %g\n', ...
                                i, j, actual_b(i,j), expected_matrix(i,j));
                            if i <= size(reports,1) && j <= size(reports,2)
                                r = reports{i,j};
                                if ischar(r) || isstring(r)
                                    fprintf('    report: %s\n', char(r));
                                elseif isstruct(r)
                                    fprintf('    report (struct):\n');
                                    disp(r);
                                else
                                    fprintf('    report class: %s\n', class(r));
                                end
                            end
                        end
                    end
                end
                fprintf('=== end testTuningCurveCalc diagnostic ===\n');
            end

            % Verify first output (b) is diag([1 1 1 1])
            testCase.verifyTrue(isequal(actual_b, expected_matrix), ...
                'First output argument (b) should be diag([1 1 1 1])');

            % Verify third output (b_expected) is diag([1 1 1 1])
            testCase.verifyTrue(isequal(double(b_expected), expected_matrix), ...
                'Third output argument (b_expected) should be diag([1 1 1 1])');

            % Check that reports is present
            testCase.verifyNotEmpty(reports, 'Reports should not be empty');
        end
    end
end
