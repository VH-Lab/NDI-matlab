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
			% The document that is created tuningcurve
			% by the input parameters.
				% check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters.''']); end;
				
				% Step 1: set up the output structure
				tuningcurve_calc = parameters;

				stim_response_doc = ndi_calculation_obj.session.database_search(ndi.query('ndi_document.id','exact_number',...
					vlt.db.struct_name_value_search(parameters.input_parameters.depends_on,'stimulus_response_scalar_id'),''));
				if numel(stim_response_doc)~=1, 
					error(['Could not find stimulus response doc..']);
				end;
				stim_response_doc = stim_response_doc{1};
			
				% Step 2: perform the calculation, which here creates a tuning curve from instructions

				% build input arguments for tuning curve app

				independent_label = split(parameters.input_parameters.independent_label,',');
				independent_parameter = split(parameters.input_parameters.independent_parameter,',');
				if numel(independent_label)~=numel(independent_parameter),
					error(['There are not the same number of independent labels and independent parameters specified.']);
				end;
				for i=1:numel(independent_label),
					independent_label{i} = strtrim(independent_label{i});
					independent_parameter{i} = strtrim(independent_parameter{i});
				end;
				
				constraint = vlt.data.emptystruct('field','operation','param1','param2');

				for i=1:numel(parameters.input_parameters.selection),
					if strcmpi(char(parameters.input_parameters.selection(i).value),'best'),
						% calculate best value
						[n,v,stim_property_value] = ndi_calculation_obj.best_value(parameters.input_parameters.best_algorithm,...
							stim_response_doc, parameters.input_parameters.selection(i).property);
						
						constraint_here = struct('field',parameters.input_parameters.selection(i).property,...
							'operation','exact_number','param1',stim_property_value,'param2','');
					else,
						constraint_here = struct('field',parameters.input_parameters.selection(i).property,...
							'operation',parameters.input_parameters.selection(i).operation,...
							'param1',parameters.input_parameters.selection(i).value,...
							'param2','');
					end;
					constraint(end+1) = constraint_here;
				end;
				
				% Step 3: place the results of the calculation into an NDI document

					% we use the ndi.app.stimulus.tuning_response app to actually make the tuning curve
				tapp = ndi.app.stimulus.tuning_response(ndi_calculation_obj.session);
				doc = tapp.tuning_curve(stim_response_doc,'independent_label',independent_label,...
					'independent_parameter',independent_parameter,'constraint',constraint,'doAdd',0);
				doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'tuningcurve_calc',tuningcurve_calc) + doc;
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

		% NEW functions in tuningcurve_calc that are not overriding any superclass functions

		function [n,v,property_value] = best_value(ndi_calculation_obj, algorithm, stim_response_doc, property)
			% BEST_VALUE - calculate the stimulus with the "best" response
			%
			% [N,V,PROPERTY_VALUE] = ndi.calc.stimulus.tuningcurve.best_value(NDI_CALC_STIMULUS_TUNINGCURVE, ALGORITHM, ...
			%   STIM_RESPONSE_DOC, PROPERTY)
			%
			% Given an ndi.document of type STIMULUS_RESPONSE_SCALAR, return the stimulus presentation number N with
			% the "best" response, as determined by ALGORITHM, for any stimulus that has the property PROPERTY.  
			%
			% N is the stimulus number that meets the criteria. V is the best response value. PROPERTY_VALUE
			% is the value of the PROPERTY of stimulus N.
			%
			% The algorithms known are:
			% -------------------------------------------------------------------------------------
			% 'empirical_maximum'      | Use the stimulus with the empirically largest mean value.
			%
			%
				n = NaN;
				v = -Inf;
				switch lower(algorithm),
					case 'empirical_maximum',
						[n,v,property_value] = ndi_calculation_obj.best_value_empirical(stim_response_doc,property);
					otherwise,
						error(['Unknown algorithm ' algorithm '.']);
				end;
		end; % best_value

		function [n,v,property_value] = best_value_empirical(ndi_calculation_obj, stim_response_doc, property)
			% BEST_VALUE_EMPIRICAL - find the best response value for a given stimulus property
			%
			% [N, V, PROPERTY_VALUE] = ndi.calc.stimulus.tuningcurve.best_value_empirical(NDI_CALC_STIMULUS_TUNINGCURVE_OBJ, STIM_RESPONSE_DOC, PROPERTY)
			%
			% Given an ndi.document of type STIMULUS_RESPONSE_SCALAR, return the stimulus presentation number N with
			% largest mean response for any stimulus that has the property PROPERTY.  If the value is complex-valued,
			% then the largest absolute value is used.
			%
			% N is the stimulus number that meets the criteria. V is the best response value. PROPERTY_VALUE
			% is the value of the PROPERTY of stimulus N.
			%
			% If this function cannot find a stimulus presentation document for the STIM_RESPONSE_DOC, it produces
			% an error.
			%
				stim_pres_doc = ndi_calculation_obj.session.database_search(ndi.query('ndi_document.id', 'exact_string', ...
                                        stim_response_doc.dependency_value('stimulus_presentation_id'),''));

				if numel(stim_pres_doc)~=1, 
					error(['Could not find stimulus presentation doc for document ' stim_response_doc.id() '.']);
				end;
				stim_pres_doc = stim_pres_doc{1};

				% see which stimuli to include

				include = [];
				for i=1:numel(stim_pres_doc.document_properties.stimulus_presentation.stimuli),
					if isfield(stim_pres_doc.document_properties.stimulus_presentation.stimuli(i).parameters,property),
						include(end+1) = i;
					end;
				end;

				n = NaN;
				v = -Inf;
				property_value = '';

				R = stim_response_doc.document_properties.stimulus_response_scalar.responses;

				for i=1:numel(include),
					indexes = find(stim_pres_doc.document_properties.stimulus_presentation.presentation_order==include(i));
					r_value = [];
					if ~isempty(indexes),
						for j=1:numel(indexes),
							r_value(end+1) = R.response_real(indexes(j)) + sqrt(-1)*R.response_imaginary(indexes(j));
							control_value = R.control_response_real(indexes(j)) + sqrt(-1)*R.control_response_imaginary(indexes(j));
							if ~isnan(control_value),
								r_value(end) = r_value(end) - control_value;
							end;
						end;
						mn = nanmean(r_value);
						if ~isreal(mn),
							mn = abs(mn);
						end;
						if mn> v,
							v = mn;
							n = include(i);
							property_value = getfield(stim_pres_doc.document_properties.stimulus_presentation.stimuli(include(i)).parameters,property);
						end;
					end;
				end;

		end; % best_value_empirical()

	end; % methods()

		
end % tuningcurve
