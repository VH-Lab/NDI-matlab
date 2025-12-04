classdef ctest
    %  ndi.mock.ctest - calculator test class, provides methods for testing ndi.calculator objects
    %

    methods
        function ctest_obj = ctest()
            % ndi.mock.ctest - object that provides methods for testing ndi.calculator objects
            %
            % CTEST_OBJ = ndi.mock.ctest()
            %
            % Create an ndi.mock.ctest object.
            %
        end % ctest (creator)

        function [b,errormsg,b_expected,doc_output,doc_expected_output] = test(ctest_obj, scope, number_of_tests, plot_it, options)
            % test - perform a test of an ndi.calculator object
            %
            % [B, ERRORMSG] = test(CTEST_OBJ, SCOPE, NUMBER_OF_TESTS, PLOT_IT, ...)
            %
            % Perform tests of the calculator for a certain SCOPE.
            %
            % B is a NUMBER_OF_TESTS x NUMBER_OF_TESTS array of whether the comparisons
            %   of the expected output of test i and actual output of test j are equal.
            %   Generally, b(i,i) should be 1 for all tests, and b(i,j) for i~=j should
            %   be 0, although results might be close enough for some comparisons to be
            %   equal even if there are no errors. If test indices are
            %   specified, B becomes a numel(specific_test_inds) x
            %   numel(specific_test_inds) array.
            %
            % ERRORMSG{i,j} is any error message given if the comparison between the
            %   expected outcome of test i and the actual outcome of test j.
            %
            % B_EXPECTED is the result of the comparisons between the expected
            %   outcome of test i and the expected outcome of test j. Some tests
            %   might have the same expected outcome, which can be useful for
            %   interpreting the results in B.
            %
            % SCOPE should be one of 'highSNR' or 'lowSNR'.
            %   'highSNR' performs tests on specific hard-coded inputs.
            %   'lowSNR' performs tests on specific hard-coded inputs with noise added.
            %
            % NUMBER_OF_TESTS indicates the number of tests to perform.
            % PLOT_IT indicates (0/1) whether or not the results should be plotted.
            %
            % This function's behavior can be modified by name/value pairs.
            % --------------------------------------------------------------------------------
            % | Parameter (default):     | Description:                                      |
            % |--------------------------|---------------------------------------------------|
            % | specific_test_inds([])   | Should we specify which tests to run?             |
            % |--------------------------|---------------------------------------------------|
            %
            arguments
                ctest_obj (1,1) ndi.mock.ctest
                scope (1,:) char {mustBeMember(scope, {'highSNR', 'lowSNR'})}
                number_of_tests (1,1) double {mustBeInteger, mustBeNonnegative}
                plot_it (1,1) {mustBeNumericOrLogical}
                options.specific_test_inds (1,:) double = []
            end

            % Step 1: generate_mock_docs
            % override number_of_tests
            [docs,doc_output,doc_expected_output] = ...
                ctest_obj.generate_mock_docs(scope,number_of_tests,'specific_test_inds',options.specific_test_inds);

            % Step 2:

            % load comparisons
            test_inds = 1:number_of_tests;
            if ~isempty(options.specific_test_inds)
                test_inds = options.specific_test_inds;
            end

            docComparisons = cell(1,numel(test_inds));
            for i=1:numel(test_inds)
                docComparisons{i} = ctest_obj.load_mock_comparison(test_inds(i));
            end

            b = [];
            errormsg = {};
            b_expected = [];
            for i=1:numel(doc_output)
                for j=1:numel(doc_output)
                    try
                        [doesitmatch,theerrormsg] = ctest_obj.compare_mock_docs(doc_expected_output{j}, ...
                            doc_output{i}, scope, docComparisons{j});
                    catch ME
                        if strcmp(ME.identifier, 'MATLAB:TooManyInputs')
                            [doesitmatch,theerrormsg] = ctest_obj.compare_mock_docs(doc_expected_output{j}, ...
                                doc_output{i}, scope);
                        else
                            rethrow(ME);
                        end
                    end
                    b(i,j) = doesitmatch;
                    b(j,i) = doesitmatch;
                    errormsg{i,j} = theerrormsg;

                    try
                        [doesitmatch,theerrormsg] = ctest_obj.compare_mock_docs(doc_expected_output{i},...
                            doc_expected_output{j}, scope, docComparisons{j});
                    catch ME
                        if strcmp(ME.identifier, 'MATLAB:TooManyInputs')
                            [doesitmatch,theerrormsg] = ctest_obj.compare_mock_docs(doc_expected_output{i},...
                                doc_expected_output{j}, scope);
                        else
                            rethrow(ME);
                        end
                    end
                    b_expected(i,j) = doesitmatch;
                    b_expected(j,i) = doesitmatch;
                end
            end

            if plot_it
                for i=1:numel(doc_output)
                    figure;
                    ctest_obj.plot(doc_output{i});
                end
            end
        end % test()

        function h = plot(ctest_obj, document)
            % PLOT - plot a calculation test document
            %
            % H = PLOT(CTEST_OBJ, DOCUMENT)
            %
            % Plot the ndi.document DOCUMENT in the current axes.
            %
            % In the abstract class, nothing is done.

            arguments
                ctest_obj (1,1) ndi.mock.ctest
                document (1,1) ndi.document
            end

        end % plot()

        function [docs,doc_output,doc_expected_output] = generate_mock_docs(ctest_obj, scope, number_of_tests, options)
            % GENERATE_MOCK_DOCS - generate tests for ndi.calc.* objects
            %
            % [DOCS, DOC_OUTPUT, DOC_EXPECTED_OUTPUT] = GENERATE_MOCK_DOCS(CSTEST_OBJ,...
            %    SCOPE, NUMBER_OF_TESTS)
            %
            % SCOPE should be one of 'highSNR' or 'lowSNR'.
            %   'highSNR' performs tests on specific hard-coded inputs.
            %   'lowSNR' performs tests on specific hard-coded inputs with noise added.
            %
            % NUMBER_OF_TESTS is the number of tests to generate.
            %

            arguments
                ctest_obj (1,1) ndi.mock.ctest
                scope (1,:) char
                number_of_tests (1,1) double
                options.specific_test_inds (1,:) double = []
            end

            docs = {};
            doc_output = {};
            doc_expected_output = {};

            switch (scope)

                case 'highSNR'

                case 'lowSNR'

            end

        end % generate_mock_docs()

        function [b, errormsg] = compare_mock_docs(ctest_obj, expected_doc, actual_doc, scope, docCompare)
            % COMPARE_MOCK_DOCS - compare an expected calculation answer with an actual answer
            %
            % [B, ERRORMSG] = COMPARE_MOCK_DOCS(CTEST_OBJ, EXPECTED_DOC, ACTUAL_DOC, SCOPE, [DOCCOMPARE])
            %
            % Given an NDI document with the expected answer to a calculation (EXPECTED_DOC),
            % the ACTUAL_DOC computed, and the SCOPE (a string: 'highSNR', 'lowSNR'),
            % this function computes whether the ACTUAL_DOC is within an allowed tolerance of
            % EXPECTED_DOC.
            %
            % B is 1 if the differences in the documents are within the tolerance of the class.
            % Otherwise, B is 0.
            % If B is 0, ERRORMSG is a string that indicates where the ACTUAL_DOC is out of tolerance.
            %
            % In this abstract class, B is always 1 and ERRORMSG is always an empty string.
            %
            % Developer's note: this method should be overridden in each calculator object.
            %
            arguments
                ctest_obj (1,1) ndi.mock.ctest
                expected_doc (1,1) ndi.document
                actual_doc (1,1) ndi.document
                scope (1,:) char
                docCompare = []
            end

            if strcmpi(scope, 'highSNR') && ~isempty(docCompare) && isa(docCompare, 'ndi.database.doctools.docComparison')
                actual_doc_struct = vlt.data.columnize_struct(actual_doc.document_properties);
                actual_doc_col = ndi.document(actual_doc_struct);
                [b, errormsg] = docCompare.compare(actual_doc_col, expected_doc);
                return;
            end

            b = 1;
            errormsg = '';
        end % compare_mock_docs()

        function clean_mock_docs(ctest_obj)
            % CLEAN_MOCK_DOCS - remove mock/test documents

            arguments
                ctest_obj (1,1) ndi.mock.ctest
            end

        end % clean_mock_docs()

        function path = calc_path(ctest_obj)
            % CALC_PATH return the path to the ndi.calculator object
            %
            % P = CALC_PATH(CTEST_OBJ)
            %
            % Return the path of an ndi.calculator object.
            %
            arguments
                ctest_obj (1,1) ndi.mock.ctest
            end
            w = which(class(ctest_obj));
            [parent,classname,ext] = fileparts(w);
            path = [parent filesep];
        end % calc_path

        function mp = mock_path(ctest_obj)
            % MOCK_PATH - return the path to the stored mock example output documents
            %
            % MP = MOCK_PATH(CTEST_OBJ)
            %
            % Returns the path to the mock document example outputs.
            % The returned path ends in a file separator.
            %
            arguments
                ctest_obj (1,1) ndi.mock.ctest
            end
            w = which(class(ctest_obj));
            [parent,classname,ext] = fileparts(w);
            mp = [ctest_obj.calc_path() filesep 'mock' filesep classname filesep];
        end % mock_path

        function doc = load_mock_expected_output(ctest_obj, number)
            % LOAD_MOCK_EXPECTED_OUTPUT - load expected NDI document answer for a calculation
            %
            % DOC = LOAD_MOCK_EXPECTED_OUTPUT(CTEST_OBJ, N)
            %
            % Load the Nth stored ndi.document that contains the expected answer for the
            % Nth standard mock test.
            %
            fname = ctest_obj.mock_expected_filename(number);
            if vlt.file.isfile(fname)
                json_data = vlt.file.textfile2char(fname);
                doc = ndi.document(jsondecode(json_data));
            else
                error(['File ' fname ' does not exist.']);
            end

        end % load_mock_expected_output()

        function fname = mock_expected_filename(ctest_obj, number)
            % MOCK_EXPECTED_FILENAME - file of expected NDI document answer for a calculation
            %
            % FNAME = MOCK_EXPECTED_FILENAME(CTEST_OBJ, N)
            %
            % Return the filename for the Nth stored ndi.document that contains the expected
            % answer for the Nth standard mock test.
            %
            fname = [ctest_obj.mock_path() 'mock.' int2str(number) '.json'];
        end % mock_expected_filename()

        function fname = mock_comparison_filename(ctest_obj, number)
            % MOCK_COMPARISON_FILENAME - file of expected NDI document comparison for a calculation
            %
            % FNAME = MOCK_COMPARISON_FILENAME(CTEST_OBJ, N)
            %
            % Return the filename for the Nth stored ndi.database.doctools.docComparison JSON object
            % that contains the comparison parameters for the Nth standard mock test.
            %
            fname = [ctest_obj.mock_path() 'mock.' int2str(number) '.compare.json'];
        end % mock_comparison_filename()

        function docCompare = load_mock_comparison(ctest_obj, number)
            % LOAD_MOCK_COMPARISON - load comparison object for a calculation
            %
            % DOCCOMPARE = LOAD_MOCK_COMPARISON(CTEST_OBJ, N)
            %
            % Load the Nth stored ndi.database.doctools.docComparison object that contains the
            % comparison parameters for the Nth standard mock test.
            %
            % If the file does not exist, empty is returned.
            %
            fname = ctest_obj.mock_comparison_filename(number);
            docCompare = [];
            if vlt.file.isfile(fname)
                json_data = vlt.file.textfile2char(fname);
                docCompare = ndi.database.doctools.docComparison(json_data);
            end

        end % load_mock_comparison()

        function b = write_mock_expected_output(ctest_obj, number, doc)
            % WRITE_MOCK_EXPECTED_OUTPUT - write
            %
            % B = WRITE_MOCK_EXPECTED_OUTPUT(CTEST_OBJ, NUMBER, DOC)
            %
            % Set the expected mock document for mock calculation NUMBER to
            % be the ndi.document DOC.
            %
            % This function will not overwrite an existing expected mock document.
            % It must be deleted manually to ensure programmer really wants to overwrite it.
            %
            fname = ctest_obj.mock_expected_filename(number);
            json_output = char(did.datastructures.jsonencodenan(doc.document_properties));
            if isfile(fname)
                error(['File ' fname ' already exists. Delete to overwrite.']);
            end
            parentdir = fileparts(fname);
            if ~isfolder(parentdir)
                mkdir(parentdir);
            end
            vlt.file.str2text(fname,json_output);
        end % write_mock_expected_output()

    end

    methods(Static)
    end % static methods
end
