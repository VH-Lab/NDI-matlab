classdef simple < ndi.calculator

	methods

		function simple_obj = simple(session)
			% SIMPLE - a simple demonstration of an ndi.calculator object
			%
			% SIMPLE_OBJ = SIMPLE(SESSION)
			%
			% Creates a SIMPLE ndi.calculator object
			%
				ndi.globals;
				simple_obj = simple_obj@ndi.calculator(session,'simple_calc',...
					fullfile(ndi_globals.path.documentpath,'apps','calculators','simple_calc.json'));
		end; % simple()

		function doc = calculate(ndi_calculator_obj, parameters)
			% CALCULATE - perform the calculator for ndi.calc.example.simple
			%
			% DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
			%
			% Creates a simple_calc document given input parameters.
			%
			% The document that is created simple has an 'answer' that is given
			% by the input parameters.
				% check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end;
				
				% Step 1: set up the output structure
				simple = parameters;
				
				% Step 2: perform the calculator, which here is a simple one-line statement
				simple.answer = parameters.input_parameters.answer;
				
				% Step 3: place the results of the calculator into an NDI document
				doc = ndi.document(ndi_calculator_obj.doc_document_types{1},'simple',simple);
				for i=1:numel(parameters.depends_on),
					doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
				end;
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculator_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculator.
			%
				parameters.input_parameters = struct('answer',5);
				parameters.depends_on = vlt.data.emptystruct('name','value');
				parameters.query = struct('name','probe_id','query',ndi.query('element.ndi_element_class','contains_string','ndi.probe',''));
		end; % default_search_for_input_parameters

		function doc_about(ndi_calculator_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATOR: SIMPLE_CALC
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | SIMPLE_CALC -- ABOUT |
			%   ------------------------
			%
			%   SIMPLE_CALC is a demonstration document. It simply produces the 'answer' that
			%   is provided in the input parameters. Each SIMPLE_CALC document 'depends_on' an
			%   NDI daq system.
			%
			%   Definition: apps/simple_calc.json
			%
				eval(['help ndi.calc.example.simple.doc_about']);
		end; %doc_about()
	end; % methods()
			
end % simple
