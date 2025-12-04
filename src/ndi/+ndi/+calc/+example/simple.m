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
            simple_obj = simple_obj@ndi.calculator(session,'simple_calc');
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
                parameters (1,1) struct
            end

            % check inputs
            if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end
            if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end

            % Step 1: set up the output structure
            simple = parameters;

            % Step 2: perform the calculator, which here is a simple one-line statement
            simple.answer = parameters.input_parameters.answer;

            % Step 3: place the results of the calculator into an NDI document
            doc = ndi.document(ndi_calculator_obj.doc_document_types{1},'simple',simple);
            for i=1:numel(parameters.depends_on)
                doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
            end
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
            parameters.query = struct('name','element_id','query',ndi.query('','isa','element',''));
        end % default_search_for_input_parameters

    end % methods()

end % simple
