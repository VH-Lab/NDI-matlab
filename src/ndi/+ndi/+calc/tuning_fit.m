classdef tuning_fit < ndi.calculator

    methods
        function tuning_fit_obj = tuning_fit(session, name, doc_type)
            % TUNING_FIT - create a new ndi.calc.tuning_fit object
            %
            % TUNING_FIT_OBJ = TUNING_FIT(SESSION, NAME, DOC_TYPE)
            %
            % Creates a new ndi.calc.tuning_fit object with the given SESSION, NAME, and DOC_TYPE.
            %
                tuning_fit_obj = tuning_fit_obj@ndi.calculator(session, name, doc_type);
        end % tuning_fit()

        function [docs, doc_output, doc_expected_output] = generate_mock_docs(obj, scope, number_of_tests, kwargs)
            % GENERATE_MOCK_DOCS - generate mock documents and expected answers for tests
            %
            % [DOCS, DOC_OUTPUT, DOC_EXPECTED_OUTPUT] = GENERATE_MOCK_DOCS(OBJ, ...
            %    SCOPE, NUMBER_OF_TESTS, ...)
            %
            % Creates a set of documents to test the calculator.
            %
            % SCOPE is the scope to be tested: 'highSNR' or 'lowSNR'
            % NUMBER_OF_TESTS indicates the number of tests to be performed.
            %
            % DOCS{i} is the set of helper documents that may have been created
            %   in generating the ith test.
            % DOC_OUTPUT{i} is the actual output of the calculator when operating on
            %   DOCS{i} (the ith test).
            % DOC_EXPECTED_OUTPUT{i} is what the output of the calculator should be, if there
            %   were no noise.
            %
            % The quality of these outputs are evaluted using the function COMPARE_MOCK_DOCS
            % as part of the TEST function for ndi.calculator objects.
            %
            % This function's behavior can be modified by name/value pairs.
            % --------------------------------------------------------------------------------
            % | Parameter (default):     | Description:                                      |
            % |--------------------------|---------------------------------------------------|
            % | generate_expected_docs(0)| Should we generate the expected docs? (That is,   |
            % |                          |   generate the "right answer"?) Use carefully.    |
            % | specific_test_inds([])   | A vector of test indices to run. If empty, all    |
            % |                          |   tests are run. DOCS and DOC_OUTPUT will have    |
            % |                          |   empty entries for skipped tests, but            |
            % |                          |   DOC_EXPECTED_OUTPUT will be populated.          |
            % |--------------------------|---------------------------------------------------|
            %
                arguments
                    obj
                    scope {mustBeMember(scope,{'highSNR','lowSNR'})}
                    number_of_tests
                    kwargs.generate_expected_docs (1,1) logical = false
                    kwargs.specific_test_inds double = []
                end
                specific_test_inds = kwargs.specific_test_inds;
                generate_expected_docs = kwargs.generate_expected_docs;

                if numel(specific_test_inds) == 0
                    specific_test_inds = 1:number_of_tests;
                end

                docs = cell(obj.numberOfSelfTests,1);
                doc_output = cell(obj.numberOfSelfTests,1);
                doc_expected_output = cell(obj.numberOfSelfTests,1);

                for i=1:obj.numberOfSelfTests
                    docs{i} = {};
                    if ismember(i, specific_test_inds)
                        [param_struct, independent_variable, x, r] = obj.generate_mock_parameters(scope, i);

                        switch scope
                            case 'highSNR'
                                reps = 5; % need reps to test significance measures
                                noise = 0.001;
                            case 'lowSNR'
                                reps = 10;
                                noise = 1;
                            otherwise
                                error(['Unknown scope ' scope '.']);
                        end % switch

                        docs{i} = ndi.mock.fun.stimulus_response(obj.session,...
                            param_struct, independent_variable, x, r, noise, reps);

                        calcparameters = obj.default_search_for_input_parameters();

                        % If the default search parameters don't specify the independent variable query,
                        % we assume the subclass's default_search_for_input_parameters/default_parameters_query does.
                        % However, we need to enforce the specific element dependency.

                        % We will create a query that intersects the default query with the specific element dependency.
                        q_element = ndi.query('','depends_on','element_id',docs{i}{3}.id());

                        if isstruct(calcparameters.query) && isfield(calcparameters.query, 'query')
                             calcparameters.query.query = calcparameters.query.query & q_element;
                        else
                            error('default_search_for_input_parameters did not return a valid query structure.');
                        end

                        % Note: some subclasses were also overwriting the query to search for specific strings
                        % (e.g. 'angle', 'spatial_frequency').
                        % However, default_parameters_query in those subclasses ALREADY does that.
                        % For example, oridir_tuning's default_parameters_query looks for 'Orientation', 'Direction', 'angle'.
                        % The previous generate_mock_docs in oridir_tuning was overwriting this with just 'angle'.
                        % Using the default query should be safer and more correct as it uses the class definition.
                        % One potential issue: if the default query is broader than what generate_mock_docs was enforcing.
                        % But since we are restricting by element_id (which is unique to the mock doc), it should be fine.

                        doc_output{i} = obj.run('Replace',calcparameters);

                        if numel(doc_output{i})>1
                            error('Generated more than one output doc when one was expected.');
                        elseif numel(doc_output{i})==0
                             % debug
                             % disp(['Search query: ' calcparameters.query.query.to_string()]);
                            error('Generated no output docs when one was expected.');
                        end
                        doc_output{i} = doc_output{i}{1};

                        if generate_expected_docs
                            obj.write_mock_expected_output(i,doc_output{i});
                        end
                    end

                    doc_expected_output{i} = obj.load_mock_expected_output(i);

                end % for
        end % generate_mock_docs()

        function [param_struct, independent_variable, x, r] = generate_mock_parameters(obj, scope, index)
            % GENERATE_MOCK_PARAMETERS - generate mock parameters for testing
            %
            % [PARAM_STRUCT, INDEPENDENT_VARIABLE, X, R] = GENERATE_MOCK_PARAMETERS(OBJ, SCOPE, INDEX)
            %
            % This method is used by GENERATE_MOCK_DOCS to generate parameters for creating
            % mock stimulus response documents for testing purposes. It must be overridden by
            % subclasses.
            %
            % Inputs:
            %   obj - the calculator object
            %   scope - the scope of the test ('highSNR' or 'lowSNR')
            %   index - the index of the test (integer)
            %
            % Outputs:
            %   param_struct - a structure of parameters for the stimulus response document.
            %                  See ndi.mock.fun.stimulus_response for details.
            %   independent_variable - a cell array of strings indicating the independent variables.
            %   x - the independent variable values (MxN matrix where M is steps and N is dimensions)
            %   r - the response values (Mx1 vector)
            %

            error('Subclasses must override generate_mock_parameters');
        end

    end % methods
end % classdef
