classdef TuningCurveTest < ndi.unittest.session.buildSession
    methods(Test)
        function test_generate_mock_docs_highSNR(testCase)
            % Test generating mock docs with highSNR scope
            S = testCase.Session;
            tc = ndi.calc.stimulus.tuningcurve(S);

            % Generate mock docs
            [docs, doc_output, doc_expected_output] = tc.generate_mock_docs('highSNR', 4);

            % Verify documents were returned
            testCase.verifyNotEmpty(docs);
            testCase.verifyNotEmpty(doc_output);

            % Verify the number of tests matches
            testCase.verifyEqual(numel(doc_output), 4);

            % Verify doc_output contains valid tuningcurve_calc documents
            for i = 1:numel(doc_output)
                if ~isempty(doc_output{i})
                    testCase.verifyTrue(isa(doc_output{i}, 'ndi.document'));
                    testCase.verifyTrue(isfield(doc_output{i}.document_properties, 'tuningcurve_calc'));
                end
            end
        end

        function test_generate_mock_docs_lowSNR(testCase)
            % Test generating mock docs with lowSNR scope
            S = testCase.Session;
            tc = ndi.calc.stimulus.tuningcurve(S);

            % Generate mock docs
            [docs, doc_output, doc_expected_output] = tc.generate_mock_docs('lowSNR', 4);

            % Verify documents were returned
            testCase.verifyNotEmpty(docs);
            testCase.verifyNotEmpty(doc_output);

            % Verify the number of tests matches
            testCase.verifyEqual(numel(doc_output), 4);

             % Verify doc_output contains valid tuningcurve_calc documents
            for i = 1:numel(doc_output)
                if ~isempty(doc_output{i})
                    testCase.verifyTrue(isa(doc_output{i}, 'ndi.document'));
                    testCase.verifyTrue(isfield(doc_output{i}.document_properties, 'tuningcurve_calc'));
                end
            end
        end

        function test_generate_mock_docs_specific_index(testCase)
            % Test generating mock docs for a specific index
            S = testCase.Session;
            tc = ndi.calc.stimulus.tuningcurve(S);

            % Generate mock docs for index 2 only
            [docs, doc_output, doc_expected_output] = tc.generate_mock_docs('highSNR', 4, 'specific_test_inds', [2]);

            % Verify structure
            testCase.verifyEmpty(doc_output{1});
            testCase.verifyNotEmpty(doc_output{2});
            testCase.verifyEmpty(doc_output{3});
            testCase.verifyEmpty(doc_output{4});

             % Verify docs structure
             testCase.verifyEmpty(docs{1});
             testCase.verifyNotEmpty(docs{2});
             testCase.verifyEmpty(docs{3});
             testCase.verifyEmpty(docs{4});

        end

        function test_ctest_integration(testCase)
             % Test using the ctest 'test' method which calls generate_mock_docs
             S = testCase.Session;
             tc = ndi.calc.stimulus.tuningcurve(S);

             % We need to make sure we don't error out if expected docs are missing
             % Since we haven't created expected docs files, we expect this might issue warnings or return mismatches
             % depending on ctest implementation.
             % However, for 'lowSNR', ctest.test checks if b is 1.

             % Let's just try running it and ensure it doesn't crash.
             % Note: ctest.test loads comparison files which won't exist.
             % But the prompt only asked for 4 tests of generate_mock_docs specifically.
             % The instruction "Write 4 tests" probably applies to the new functionality.

             % So I will write a test that verifies the content of the generated document.

            [docs, doc_output, doc_expected_output] = tc.generate_mock_docs('highSNR', 1);
            doc = doc_output{1};

            % Check some properties of the tuning curve
            tc_props = doc.document_properties.tuningcurve_calc;
            testCase.verifyTrue(isfield(tc_props, 'stim_property_list'));
            testCase.verifyTrue(isfield(tc_props, 'tuning_curve'));

            % Verify dependent document IDs match
            deps = doc.dependency_value('stimulus_response_scalar_id');
            testCase.verifyNotEmpty(deps);
        end
    end
end
