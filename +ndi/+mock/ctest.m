classdef ctest 
	%  ndi.mock.ctest - calculator test class, provides methods for testing ndi.calculator objects
	%

	properties
		base_scope % structure with the base scope information for the class
	end; % properties


	methods
                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function ctest_obj = ctest()
			% ndi.mock.ctest - object that provides methods for testing ndi.calculator objects
			%
			% CTEST_OBJ = ndi.mock.ctest()
			%
			% Create an ndi.mock.ctest object. 
			%
				ctest_obj.base_scope = ndi.mock.ctest.default_scope();
		end; % ctest (creator)
 
                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function [b,errormsg,b_expected] = test(ctest_obj, scope, number_of_tests, plot_it)
			% test - perform a test of an ndi.calculator object
			%
			% [B, ERRORMSG] = test(CTEST_OBJ, SCOPE, NUMBER_OF_TESTS, PLOT_IT)
			%
			% Perform tests of the calculator for a certain SCOPE.
			%
			% B is a NUMBER_OF_TESTS x NUMBER_OF_TESTS array of whether the comparisons 
			%   of the expected output of test i and actual output of test j are equal.
			%   Generally, b(i,i) should be 1 for all tests, and b(i,j) for i~=j should
			%   be 0, although results might be close enough for some comparisons to be
			%   equal even if there are no errors.
			%
			% ERRORMSG{i,j} is any error message given if the comparison between the
			%   expected outcome of test i and the actual outcome of test j.
			%
			% B_EXPECTED is the result of the comparisons between the expected
			%   outcome of test i and the expected outcome of test j. Some tests
			%   might have the same expected outcome, which can be useful for
			%   interpreting the results in B.
			% 
			% SCOPE should be one of 'standard', 'low_noise', or 'high_noise'.
			%   'standard' performs tests on specific hard-coded inputs.
			%   'low_noise' performs tests on specific hard-coded inputs with small amounts
			%      of noise added. 
			%   'high_noise' performs tests on specific hard-coded inputs with large amounts
			%      of noise added.
			%
			% NUMBER_OF_TESTS indicates the number of tests to perform.
			% PLOT_IT indicates (0/1) whether or not the results should be plotted.
			%
			% 
				% Step 1: generate_mock_docs
				[docs,doc_output,doc_expected_output] = ...
					ctest_obj.generate_mock_docs(scope, number_of_tests);

				% Step 2:

				b = [];
				errormsg = {};
				b_expected = [];
				for i=1:numel(doc_output),
					for j=1:numel(doc_output),
						[doesitmatch,theerrormsg] = ctest_obj.compare_mock_docs(doc_expected_output{i}, ...
							doc_output{i}, scope); 
						b(i,j) = doesitmatch;
						b(j,i) = doesitmatch;
						errormsg{i,j} = theerrormsg;
						[doesitmatch,theerrormsg] = ctest_obj.compare_mock_docs(doc_expected_output{i},...
							doc_expected_output{j}, scope);
						b_expected(i,j) = doesitmatch;
						b_expected(j,i) = doesitmatch;
					end;
				end;

				if plot_it,
					for i=1:numel(doc_output),
						figure;
						ctest_obj.plot(doc_output{i});
					end;
				end;
		end;

                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function h = plot(ctest_obj, document)
			% PLOT - plot a calculation test document
			%
			% H = PLOT(CTEST_OBJ, DOCUMENT)
			%
			% Plot the ndi.document DOCUMENT in the current axes.
			%
			% In the abstract class, nothing is done.

		end; % plot()


                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function [docs,doc_output,doc_expected_output] = generate_mock_docs(ctest_obj, scope, number_of_tests)
			% GENERATE_MOCK_DOCS - generate tests for ndi.calc.* objects
			%
			% [DOCS, DOC_OUTPUT, DOC_EXPECTED_OUTPUT] = GENERATE_MOCK_DOCS(CSTEST_OBJ,...
			%    SCOPE, NUMBER_OF_TESTS)
			%
			% SCOPE should be one of 'standard', 'low_noise', or 'high_noise'.
			%   'standard' performs tests on specific hard-coded inputs.
			%   'low_noise' performs tests on specific hard-coded inputs with small amounts
			%      of noise added. 
			%   'high_noise' performs tests on specific hard-coded inputs with large amounts
			%      of noise added.
			%
			% NUMBER_OF_TESTS is the number of tests to generate.
			%


				docs = {};
				doc_output = {};
				doc_expected_output = {};

				switch (scope),

					case 'standard',

					case 'low-noise',
		
					case 'high-noise',

				end;

		end; % generate_mock_docs()

                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function [b, errormsg] = compare_mock_docs(ctest_obj, expected_doc, actual_doc, scope)
			% COMPARE_MOCK_DOCS - compare an expected calculation answer with an actual answer
			%
			% [B, ERRORMSG] = COMPARE_MOCK_DOCS(CTEST_OBJ, EXPECTED_DOC, ACTUAL_DOC, SCOPE)
			%
			% Given an NDI document with the expected answer to a calculation (EXPECTED_DOC),
			% the ACTUAL_DOC computed, and the SCOPE (a string: 'standard', 'low_noise','high_noise'),
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
				b = 1;
				errormsg = '';
		end; % compare_mock_docs()

                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function clean_mock_docs(cstest_obj)
			% CLEAN_MOCK_DOCS - remove mock/test documents


		end; % clean_mock_docs()

                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function path = calc_path(ctest_obj)
			% CALC_PATH return the path to the ndi.calculator object
			%
			% P = CALC_PATH(CTEST_OBJ)
			%
			% Return the path of an ndi.calculator object.
			%
				w = which(class(ctest_obj));
				[parent,classname,ext] = fileparts(w);
				path = [parent filesep];
		end; % calc_path

                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function mp = mock_path(ctest_obj)
			% MOCK_PATH - return the path to the stored mock example output documents
			%
			% MP = MOCK_PATH(CTEST_OBJ)
			%
			% Returns the path to the mock document example outputs.
			% The returned path ends in a file separator.
			%
				w = which(class(ctest_obj));
				[parent,classname,ext] = fileparts(w);
				mp = [ctest_obj.calc_path() filesep 'mock' filesep classname filesep];
		end; % mock_path

                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function doc = load_mock_expected_output(ctest_obj, number)
			% LOAD_MOCK_EXPECTED_OUTPUT - load expected NDI document answer for a calculation
			%
			% DOC = LOAD_MOCK_EXPECTED_OUTPUT(CTEST_OBJ, N)
			%
			% Load the Nth stored ndi.document that contains the expected answer for the
			% Nth standard mock test.
			%
				fname = ctest_obj.mock_expected_filename(number);
				if vlt.file.isfile(fname),
					json_data = vlt.file.textfile2char(fname);
					doc = ndi.document(jsondecode(json_data));
				else,
					error(['File ' fname ' does not exist.']);
				end;

		end; % load_mock_expected_output()

                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function fname = mock_expected_filename(ctest_obj, number)
			% MOCK_EXPECTED_FILENAME - file of expected NDI document answer for a calculation
			%
			% FNAME = MOCK_EXPECTED_FILENAME(CTEST_OBJ, N)
			% 
			% Return the filename for the Nth stored ndi.document that contains the expected
			% answer for the Nth standard mock test.
			%
				fname = [ctest_obj.mock_path() 'mock.' int2str(number) '.json'];
		end; % mock_expected_filename()

                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
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
				json_output = char(vlt.data.prettyjson(vlt.data.jsonencodenan(doc.document_properties)));
				if isfile(fname),
					error(['File ' fname ' already exists. Delete to overwrite.']);
				end;
				parentdir = fileparts(fname);
				if ~isfolder(parentdir),
					mkdir(parentdir);
				end;
				vlt.file.str2text(fname,json_output);
		end; % write_mock_expected_output()

	end;

	methods(Static) 
                        % 80 character reference; documentation should be within 80 character limit
			% 01234567890123456789012345678901234567890123456789012345678901234567890123456789
		function base_scope = default_scope()
			% ndi.mock.ctest.default_scope - default scope types for ndi.mock.ctest object
			%
			% BASE_SCOPE = ndi.mock.ctest.default_scope();
			%
			% Return a default base_scope structure for an ndi.mock.ctest object.
			%
			%
				base_scope(1) = struct(...
					'scope', 'standard', 'autocompare', 1);
				base_scope(2) = struct(...
					'scope', 'random_parameters', 'autocompare', 1);
				base_scope(3) = struct(...
					'scope', 'low_noise', 'autocompare', 1);
				base_scope(4) = struct(...
					'scope', 'high_noise', 'autocompare', 0);

		end; % ndi.mock.ctest.default_scope()

	end; % static methods
end


