classdef ctest 
	%  ndi.mock.ctest - calculator test class, provides methods for testing ndi.calculator objects
	%

	properties
		base_scope % structure with the base scope information for the class
	end; % properties


	methods
		function ctest_obj = ctest()
			% ndi.mock.ctest - an object that provides base methods for testing ndi.calculator objects
			%
			% CTEST_OBJ = ndi.mock.ctest()
			%
			% Create an ndi.mock.ctest object. 
			%
				ctest_obj.base_scope = ndi.mock.ctest.default_scope();
		end; % ctest (creator)


		function [b,errormsg] = test(ctest_obj, scope, number_of_tests, plot_it)
			% test - perform a test of an ndi.calculator object
			%
			% [B, ERRORMSG] = test(CTEST_OBJ, SCOPE, NUMBER_OF_TESTS, PLOT_IT)
			%
			% Perform tests of the calculator for a certain SCOPE.
			%
			% Scope should be one of 'standard', 'low_noise', or 'high_noise'.
			%   'standard' performs tests on specific hard-coded inputs.
			%   'low_noise' performs tests on specific hard-coded inputs with small amounts of noise added.
			%   'high_noise' performs tests on specific hard-coded inputs with large amounts of noise added.
			%
			% NUMBER_OF_TESTS indicates the number of tests to perform.
			% PLOT_IT indicates (0/1) whether or not the results should be plotted.
			%
			% 

				% Step 1: generate_mock_docs
				[docs,doc_output,doc_expected_output] = generate_mock_docs(scope);

				% Step 2:
	
				[doesitmatch,errormsg] = compare_mock_docs(doc_expected_output, doc_output); 

				if plot_it,
					ctest_obj.plot(doc_output);
				end;
		end;

		function h = plot(ctest_obj, document)
			% PLOT - plot a calculation test document
			%
			% H = PLOT(CTEST_OBJ, DOCUMENT)
			%
			% Plot the ndi.document DOCUMENT in the current axes.
			%
			% In the abstract class, nothing is done.

		end; % plot()

			% need modify this:
		function [docs,doc_output,doc_expected_output] = generate_mock_docs(ctest_obj, scope)

			% randomly generating parameters and then creating mock stimulus and response documents

			switch (scope),

				case 'exact',
					

				case 'low-noise',
	
				case 'high-noise',

			end;

		end;

			% need modify this:
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
				b = 1;
				errormsg = '';
		end;



		function clean_mock_docs()



		end;

		function path = calc_path(ctest_obj)
			% CALC_PATH return the path to the ndi.calculator object
			%
			% P = CALC_PATH(CTEST_OBJ)
			%
			% Return the path of an ndi.calculator object.
			%
				w = which(classname(ctest_obj));
				parent = fileparts(w);
				path = [parent filesep classname(ctest_obj) filesep];
		end; % calc_path

		function mp = mock_path(ctest_obj)
			% MOCK_PATH - return the path to the stored mock example output documents
			%
			% MP = MOCK_PATH(CTEST_OBJ)
			%
			% Returns the path to the mock document example outputs.
			% The returned path ends in a file separator.
			%
				mp = [ctest_obj.calc_path() '.mock' filesep];
		end; % mock_path

		function doc = load_mock_expected_output(ctest_obj, number)
			% LOAD_MOCK_EXPECTED_OUTPUT - load the expected NDI document answer for a calculation
			%
			% DOC = LOAD_MOCK_EXPECTED_OUTPUT(CTEST_OBJ, N)
			%
			% Load the Nth stored ndi.document that contains the expected answer for the
			% Nth standard mock test.
			%
				fname = [ctest_obj.mock_path '.' int2str(number) '.json'];
				if vlt.file.isfile(fname),
					json_data = vlt.file.text2char(fname);
					doc = jsondecode(json_data);
				else,
					error(['File ' fname ' does not exist.']);
				end;

		end; % load_mock_expected_output()

	end;

	methods(Static) 
		function base_scope = default_scope()
			% ndi.mock.ctest.default_scope - return default scope types for ndi.mock.ctest object
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


