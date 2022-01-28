classdef oridirtuning < ndi.calculation

	methods

		function oridirtuning_obj = oridirtuning(session)
			% oridirtuning - ndi.calculation object that
			% calculates orientation and direction tuning curves from spike
			% elements
			%
			% ORIDIRTUNING_OBJ = ORIDIRTUNING(SESSION)
			%
			% Creates a oridirtuning ndi.calculation object
			%
				ndi.globals;
				oridirtuning_obj = oridirtuning_obj@ndi.calculation(session,'oridirtuning',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','oridirtuning.json'));
		end; % oridirtuning() creator

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform the calculation for
			% ndi.calc.oridirtuning
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a oridirtuning_direction_tuning_calc document given input parameters.
			
                % Check inputs
                if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end;
				
                % Calculate oridirtuning and direction indexes from stimulus responses
                oridirtuning = parameters;
				
                doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'oridirtuning',oridirtuning);
				for i=1:numel(parameters.depends_on),
					doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
				end;
				
                E = ndi_calculation_obj.session;
				tapp = ndi.app.stimulus.tuning_response(E);
				ind = {};
				ind_real = {};
				control_ind = {};
				control_ind_real = {};
				response_ind = {};
				response_mean = [];
				response_stddev = [];
				response_stderr = [];
                
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculation_obj, varargin)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation.
			%

            % search for stimulus_tuningcurve_id
            parameters.input_parameters = struct('');
            parameters.depends_on = vlt.data.emptystruct('name','value');
            
            q = ndi.query('','isa','oridirtuning', '');
            q = q&ndi.query('element.ndi_element_class','contains_string','ndi.stimulus_tuningcurve_id','');

			parameters.query = struct('name','stimulus_tuningcurve_id','query',q);           
                   
                        
		end; % default_search_for_input_parameters

		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: ORIDIRTUNING
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | ORIDIRTUNING -- ABOUT |
			%   ------------------------
			%
			%   ORIDIRTUNING is an ndi.calculation object that calculates the oridirtuning and direction tuning
			%   curves from spike elements.
            %   
			%   Each  document 'depends_on' an NDI daq system.
			%
			%   Definition: apps/calc/oridirtuning.json
			%
<<<<<<< Updated upstream
				eval(['help ndi.calc.oridirtuning.doc_about']);
=======
				eval(['help ndi.calc.vision.oridirtuning.doc_about']);
>>>>>>> Stashed changes
		end; %doc_about()
	end; % methods()
			
end % oridirtuning
