classdef tuningcurve < ndi.calculation

	methods

		function tuningcurve_obj = tuningcurve(session)
			% TUNINGCURVE - a tuningcurve demonstration of an ndi.calculation object
			%
			% TUNINGCURVE_OBJ = TUNINGCURVE(SESSION)
			%
			% Creates a TUNINGCURVE ndi.calculation object
			%
				ndi.globals;
				tuningcurve_obj = tuningcurve_obj@ndi.calculation(session,'tuningcurve_calc',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','tuningcurve_calc.json'));
		end; % tuningcurve()

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform the calculation for ndi.calc.example.tuningcurve
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a tuningcurve_calc document given input parameters.
			%
			% The document that is created tuningcurve has an 'answer' that is given
			% by the input parameters.
				% check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				
				% Step 1: set up the output structure
				tuningcurve_calc = parameters;
				
				% Step 2: perform the calculation, which here creates a tuning curve from instructions

				% build constraints arguments for tuning curve app

				independent_label = {};
				independent_parameter = {};
				constraint = vlt.data.emptystruct('field','operation','param1','param2');

				for i=1:numel(input_parameters.selection),
					if strcmpi(char(input_parameters.selection(i).value),'best'),
						% calculate best value
						
					else,
						constraint_here = struct('field',input_parameters.selection(i).property,...
							'operation',input_parameters.selection(i).operation,...
							'param1',input_parameters.selection(i).value),...
							'param2','');
					end;
					constraint(end+1) = constraint_here;
				end;
				
				% Step 3: place the results of the calculation into an NDI document
				doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'tuningcurve_calc',tuningcurve);
				% set any dependencies

		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculation_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation.
			%
				parameters.input_parameters = struct('best_algorithm','empirical_maximum');
				parameters.input_parameters.selection = vlt.data.emptystruct('property','operation','value');
				parameters.depends_on = vlt.data.emptystruct('name','value');
				parameters.query = vlt.data.emptystruct('name','query'); 
		end; % default_search_for_input_parameters

		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: TUNINGCURVE_CALC
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | TUNINGCURVE_CALC -- ABOUT |
			%   ------------------------
			%
			%   TUNINGCURVE_CALC is a demonstration document. It simply produces the 'answer' that
			%   is provided in the input parameters. Each TUNINGCURVE_CALC document 'depends_on' an
			%   NDI daq system.
			%
			%   Definition: apps/tuningcurve_calc.json
			%
				eval(['help ndi.calc.example.tuningcurve.doc_about']);
		end; %doc_about()

		function v = best_value(ndi_calculation_obj, response_doc, property)


		end; % best_value

		function v = best_value_empirical(ndi_calculation_obj, response_doc, property)
			% BEST_VALUE_EMPIRICAL - find the best response value for a given stimulus property
			%
			% [N, V] = ndi.calc.stimulus.best_value_empirical(NDI_CALC_STIMULUS_TUNINGCURVE_OBJ, RESPONSE_DOC, PROPERTY)
			%
			% Given an ndi.document of type STIMULUS_RESPONSE_SCALAR, return the stimulus presentation number N with
			% largest response for any stimulus that has the property PROPERTY.
			%
			%
			
				stim_pres_doc = E.database_search(ndi.query('ndi_document.id', 'exact_string', ...
                                        stim_response_doc.dependency_value('stimulus_presentation_id'),''));

				ndi_calculation_obj.session

		end; % best_value_empirical()

	end; % methods()

		
end % tuningcurve
