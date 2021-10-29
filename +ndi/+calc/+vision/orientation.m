classdef orientation < ndi.calculation

	methods

		function orientation_obj = orientation(session)
			% orientation - ndi.calculation object that
			% calculates orientation and direction tuning curves from spike
			% elements
			%
			% ORIENTATION_OBJ = ORIENTATION(SESSION)
			%
			% Creates a orientation ndi.calculation object
			%
				ndi.globals;
				orientation_obj = orientation_obj@ndi.calculation(session,'orientation',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','orientation.json'));
		end; % orientation() creator

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform the calculation for
			% ndi.calc.orientation
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a orientation_direction_tuning_calc document given input parameters.
			
                % Check inputs
                if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end;
				
                % Calculate orientation and direction indexes from stimulus responses
                orientation = parameters;
				
                doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'orientation',orientation);
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
            
            q = ndi.query('','isa','orientation', '');
            q = q&ndi.query('element.ndi_element_class','contains_string','ndi.stimulus_tuningcurve_id','');

			parameters.query = struct('name','stimulus_tuningcurve_id','query',q);           
                   
                        
		end; % default_search_for_input_parameters

		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: ORIENTATION
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | ORIENTATION -- ABOUT |
			%   ------------------------
			%
			%   ORIENTATION is an ndi.calculation object that calculates the orientation and direction tuning
			%   curves from spike elements.
            %   
			%   Each  document 'depends_on' an NDI daq system.
			%
			%   Definition: apps/calc/orientation.json
			%
				eval(['help ndi.calc.orientation.doc_about']);
		end; %doc_about()
	end; % methods()
			
end % orientation
