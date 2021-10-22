classdef tuning_curve < ndi.calculation

	methods

		function tuning_curve_obj = tuning_curve(session)
			% TUNING_CURVE - ndi.calculation object that calculates the
			% tuning curve from spike elements
			%
			% TUNING_CURVE_OBJ = TUNING_CURVE(SESSION)
			%
			% Creates a TUNING_CURVE ndi.calculation object
			%
				ndi.globals;
				tuning_curve_obj = tuning_curve_obj@ndi.calculation(session,'tuning_curve',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','tuning_curve.json'));
		end; % tuning_curve() creator

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - performs the tuning curve calculations for each
			% spike element
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a tuning_curve document given input parameters.
			%
			% The document that is created has an 'answer' that is given
			% by the input parameters.
				
                % check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on.''']); end;
				
				tuning_curve = parameters;
                tuning_curve.independent_variable_label = parameters.input_parameters.independent_variable_label;
                tuning_curve.independent_label = parameters.input_parameters.independent_variable_value;
                
                % calculate
                E = ndi_calc_tuning_curve_obj.session;
                rapp = ndi.app.stimulus.tuning_response(E);
                
				tuning_curve.independent_parameter = {'angle'};
                tuning_curve.independent_label = {'direction'};
                tuning_curve.constraint = struct('field','sFrequency','operation','hasfield','param1','','param2','');
                
%                doc = rapp.tuning_curve(rdoc,'independent_parameter',independent_parameter,...
%                    'independent_label',independent_label,'constraint',constraint);

                doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'tuning_curve',tuning_curve);                
                for i=1:numel(parameters.depends_on),
					doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
				end;
                             
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculation_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation.
			%
                parameters.input_parameters = struct('independent_variable_label','','independent_variable_value','');
                tuning_doc.document_properties.tuning_curve.independent_variable_value
				parameters.depends_on = vlt.data.emptystruct('name','value');
                
              	q = ndi.query('','isa','stimulus_tuningcurve','');
                q = q&ndi.query('element.ndi_element_class','contains_string','ndi.stimulus_tuning_curve','');
                parameters.query = struct('name', 'stimulus_response_scalar_id','query',q);
                
%                 if input ~= empty,
%                     response_doc = input;
%                     q = q&ndi.query('','depends_on','stimulus_response_scalar_id',response_doc.id());
%                 end;
%                parameters.query = ndi_app_calculation_obj.session.database_search(q);
		end; % default_search_for_input_parameters

		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: TUNING_CURVE
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | TUNING_CURVE -- ABOUT |
			%   ------------------------
			%
			%   TUNING_CURVE calculates tuning curves given the provided input parameters. 
			%   Each TUNING_CURVE document 'depends_on' an NDI daq system.
			%
			%   Definition: apps/calc/tuning_curve.json
			%
				eval(['help ndi.calc.tuning_curve.doc_about']);
		end; %doc_about()
	end; % methods()
			
end % tuning_curve
