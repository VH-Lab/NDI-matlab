classdef simple < ndi.calculator

    methods

        function simple_obj = simple(session)
            % SIMPLE - a simple demonstration of an ndi.calculator object
            %
            % SIMPLE_OBJ = SIMPLE(SESSION)
            %
            % Creates a SIMPLE ndi.calculator object
            %
            arguments
                session (1,1) ndi.session
            end
            simple_obj = simple_obj@ndi.calculator(session,'simple_calc','simple_calc');

            simple_obj.numberOfSelfTests = 2;
        end % simple()

        function doc = calculate(ndi_calculator_obj, parameters)
            % CALCULATE - perform the calculation
            %
            % DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
            %
            % Creates a simple_calc document given input parameters.
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calc.example.simple
                parameters (1,1) struct {ndi.validators.mustHaveFields(parameters, {'input_parameters', 'depends_on'})}
            end

            % Step 1: set up the output structure
            simple_calc.input_parameters = parameters.input_parameters;

            % Step 2: perform the calculator, which here is a simple one-line statement
            simple_calc.answer = parameters.input_parameters.answer;

            % Step 3: place the results of the calculator into an NDI document
            doc = ndi.document(ndi_calculator_obj.doc_document_types{1},'simple_calc',simple_calc) + ...
                ndi_calculator_obj.session.newdocument();
            doc = doc.set_dependency_value('document_id',parameters.depends_on(1).value);
        end % calculate

        function parameters = default_search_for_input_parameters(ndi_calculator_obj)
            % DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default search parameters
            %
            % PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
            %
            % Returns default search parameters for finding inputs.
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calc.example.simple
            end
            parameters.input_parameters = struct('answer',5);
            parameters.depends_on = vlt.data.emptystruct('name','value');
            % for this example, calculate on all documents (i.e., any
            % ndi document that is of class 'base', which is all of them)
            parameters.query = struct('name','document_id','query',ndi.query('','isa','base',''));
        end % default_search_for_input_parameters

        function [docs, doc_output, doc_expected_output] = generate_mock_docs(ndi_calculator_obj, scope, number_of_tests, options)
            % GENERATE_MOCK_DOCS - generate mock documents for testing
            %
            % [DOCS, DOC_OUTPUT, DOC_EXPECTED_OUTPUT] = GENERATE_MOCK_DOCS(NDI_CALCULATOR_OBJ, SCOPE, NUMBER_OF_TESTS, 'PARAM', VALUE, ...)
            %
            % The generate_mock_docs method is a testing utility present in NDI calculator classes.
            % It generates synthetic input data (mock documents) and runs the calculator to produce actual outputs,
            % which can then be compared against expected outputs.
            %
            % This method takes additional input arguments as name/value pairs:
            % |---------------------------|------------------------------------------------------|
            % | Parameter (default)       | Description                                          |
            % |---------------------------|------------------------------------------------------|
            % | generate_expected_docs    | If true, the method saves the current output as the  |
            % |   (false)                 | "expected" output for future tests. Use this when    |
            % |                           | updating the calculator logic or creating new tests. |
            % | specific_test_inds ([])   | Allows specifying a subset of test indices to run.   |
            % |                           | If empty, all NUMBER_OF_TESTS are run.               |
            % |---------------------------|------------------------------------------------------|
            %
            arguments
                ndi_calculator_obj (1,1) ndi.calc.example.simple
                scope (1,:) char
                number_of_tests (1,1) double
                options.generate_expected_docs (1,1) logical = false
                options.specific_test_inds (1,:) double = []
            end

            docs = {};
            doc_output = {};
            doc_expected_output = {};

            % 1. Create mock documents if they don't exist

            % Check/Create Doc for Test 1 (Value 5)
            q1 = ndi.query('','isa','demoNDIMock','');
            q2 = ndi.query('demoNDI.value','exact_number', 5, '');
            q_test1 = q1 & q2;
            docs_test1 = ndi_calculator_obj.session.database_search(q_test1);

            if isempty(docs_test1)
                mock_doc1_struct.demoNDI.value = 5;
                % demoNDIMock requires a file because it inherits from demoNDI
                mock_doc1 = ndi.document('demoNDIMock', 'demoNDI', mock_doc1_struct.demoNDI) + ndi_calculator_obj.session.newdocument();
                % We need to add a dummy file because demoNDI schema requires 'filename1.ext'
                % Ideally we create a dummy file on disk.
                fname1 = [ndi_calculator_obj.session.path() filesep 'test1_dummy.txt'];
                vlt.file.str2text(fname1, 'dummy content');
                mock_doc1 = mock_doc1.add_file('filename1.ext', fname1);
                ndi_calculator_obj.session.database_add(mock_doc1);
                docs{end+1} = mock_doc1;
            else
                docs{end+1} = docs_test1{1};
            end

            % Check/Create Doc for Test 2 (Value 10)
            q3 = ndi.query('demoNDI.value','exact_number', 10, '');
            q_test2 = q1 & q3;
            docs_test2 = ndi_calculator_obj.session.database_search(q_test2);

            if isempty(docs_test2)
                mock_doc2_struct.demoNDI.value = 10;
                mock_doc2 = ndi.document('demoNDIMock', 'demoNDI', mock_doc2_struct.demoNDI) + ndi_calculator_obj.session.newdocument();;
                fname2 = [ndi_calculator_obj.session.path() filesep 'test2_dummy.txt'];
                vlt.file.str2text(fname2, 'dummy content');
                mock_doc2 = mock_doc2.add_file('filename1.ext', fname2);
                ndi_calculator_obj.session.database_add(mock_doc2);
                docs{end+1} = mock_doc2;
            else
                docs{end+1} = docs_test2{1};
            end

            % 2. Run Tests

            test_inds = 1:number_of_tests;
            if ~isempty(options.specific_test_inds)
                test_inds = options.specific_test_inds;
            end

            for i = 1:numel(test_inds)
                test_idx = test_inds(i);

                % Determine which mock doc to use based on test index
                if test_idx == 1
                    target_value = 5;
                elseif test_idx == 2
                    target_value = 10;
                else
                    % Default or fallback for other tests
                     target_value = 5;
                end

                % Setup Query for this specific test
                q_val = ndi.query('demoNDI.value', 'exact_number', target_value, '');
                q_combined = q1 & q_val;

                search_params = struct('input_parameters', struct('answer', target_value), ...
                                       'depends_on', vlt.data.emptystruct('name','value'), ...
                                       'query', struct('name', 'document_id', 'query', q_combined));

                % Run the calculator
                doc_output_here = ndi_calculator_obj.run('Replace', search_params);

                if ~iscell(doc_output_here)
                    doc_output_here = {doc_output_here};
                end

                if ~isempty(doc_output_here)
                    doc_output{test_idx} = doc_output_here{1};
                end

                % Handle expected docs
                if options.generate_expected_docs
                     if ~isempty(doc_output{test_idx})
                        ndi_calculator_obj.write_mock_expected_output(test_idx, doc_output{test_idx});
                        doc_expected_output{test_idx} = doc_output{test_idx};
                     end
                else
                        doc_expected_output{test_idx} = ndi_calculator_obj.load_mock_expected_output(test_idx);
                end
            end

        end

    end % methods()

end % simple
