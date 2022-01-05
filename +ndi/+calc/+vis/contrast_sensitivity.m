classdef contrast_sensitivity < ndi.calculation

	methods
		function contrast_sensitivity_obj = contrast_sensitivity(session)
			% CONTRAST_TUNING - a contrast_sensitivity demonstration of an ndi.calculation object
			%
			% CONTRAST_TUNING_OBJ = CONTRAST_TUNING(SESSION)
			%
			% Creates a CONTRAST_TUNING ndi.calculation object
			%
				ndi.globals;
				contrast_sensitivity_obj = contrast_sensitivity_obj@ndi.calculation(session,'contrastsensitivity_calc',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','contrastsensitivity_calc.json'));
		end; % contrast_sensitivity()

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform the calculation for ndi.calc.example.contrast_sensitivity
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a contrast_sensitivity_calc document given input parameters.
			%
			% The document that is created contrast_sensitivity
			% by the input parameters.
				% check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters''.']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on''.']); end;
				
				% Step 1: set up the output structure
				contrastsensitivity_calc = parameters;

				element_doc = ndi_calculation_obj.session.database_search(ndi.query('ndi_document.id','exact_number',...
					vlt.db.struct_name_value_search(parameters.depends_on,'element_id'),''));
				if numel(element_doc)~=1, 
					error(['Could not find element doc..']);
				end;
				element_doc = element_doc{1};

				% Step 2: search for possible stimulus_response_scalar docs

				q1a = ndi.query('','depends_on','element_id',element_doc.id());
				q1b = ndi.query('','isa','stimulus_response_scalar','');
				stim_resp_scalar = ndi_calculation_obj.session.database_search(q1a&q1b);

				tuning_curve_app = ndi.calc.stimulus.tuningcurve(ndi_calculation_obj.session);

				doc = {};

				for i=1:numel(stim_resp_scalar),
					% now see if the stimulus presentations vary in contrast and spatial frequency
					q2 = ndi.query('ndi_document.id','exact_string',stim_resp_scalar{i}.dependency_value('stimulus_presentation_id'),'');
					stim_pres_doc = ndi_calculation_obj.session.database_search(q2);
					if numel(stim_pres_doc) ~=1,
						error(['Missing stimulus presentation document for ' stim_resp_scalar.id() '. (Should not happen).']);
					end;
					stim_pres_doc = stim_pres_doc{1};
					good = 0;
					v1 = tuning_curve_app.property_value_array(stim_resp_scalar{i},'contrast');
					if numel(v1)>2, 
						good = 1;
					end;
					if good,
						v2 = tuning_curve_app.property_value_array(stim_resp_scalar{i},'sFrequency');
					end;
					if numel(v2)<=2,
						good = 0;
					end;
					if good,
						% Step 3: Search for contrast tuning curve objects that depend on this stimulus response document
						q3a = ndi.query('tuning_curve.independent_variable_label','exact_string','Contrast','');
						q3b = ndi.query('tuning_curve.independent_variable_label','exact_string','contrast','');
						q3c = ndi.query('tuning_curve.independent_variable_label','exact_string','CONTRAST','');
						q4 = ndi.query('','depends_on','stimulus_response_scalar_id',stim_resp_scalar{i}.id());
						q5 = ndi.query('','isa','stimulus_tuningcurve.json','');
						tuning_curves = ndi_calculation_obj.session.database_search( (q3a|q3b|q3c) & q4 & q5);

						spatial_frequencies = [];
						sensitivity_RB = [];
						sensitivity_RBN = [];
						sensitivity_RBNS = [];
						response_type = stim_resp_scalar{i}.document_properties.stimulus_response_scalar.response_type;
						
						for k=1:numel(tuning_curves),
							q6 = ndi.query('','isa','contrast_tuning','');
							q7 = ndi.query('','depends_on','stimulus_tuningcurve_id',tuning_curves{k}.id());
							
							contrast_tuning_props = ndi_calculation_obj.session.database_search(q6&q7);

							if numel(contrast_tuning_props)>1,
								error(['Found multiple contrast tuning property records for a single tuning curve.']);
							elseif numel(contrast_tuning_props)==0,
								error(['Found contrast tuning curve but no contrast tuning curve properties for element with id ' element_doc.id()]);
							else,
								contrast_tuning_props = contrast_tuning_props{1};
							end;

							stimid = tuning_curves{k}.document_properties.tuning_curve.stimid(1);
							params_here = stim_pres_doc.document_properties.stimulus_presentation.stimuli(stimid).parameters;
							if isfield(params_here,'sFrequency'),
								spatial_frequencies(end+1) = getfield(params_here,'sFrequency');
							else,
								error(['Expected spatial frequency information.']); % should this be an error or just a skip?
							end;
							sensitivity_RB = [ sensitivity_RB vlt.data.colvec(contrast_tuning_props.document_properties.contrast_tuning.fit.naka_rushton_RB_sensitivity) ];
							sensitivity_RBN = [ sensitivity_RBN vlt.data.colvec(contrast_tuning_props.document_properties.contrast_tuning.fit.naka_rushton_RBN_sensitivity) ];
							sensitivity_RBNS = [ sensitivity_RBNS vlt.data.colvec(contrast_tuning_props.document_properties.contrast_tuning.fit.naka_rushton_RBNS_sensitivity) ];
						end;
						[spatial_frequencies,order] = sort(spatial_frequencies);
						sensitivity_RB = sensitivity_RB(:,order);
						sensitivity_RBN = sensitivity_RBN(:,order);
						sensitivity_RBNS = sensitivity_RBNS(:,order);

						% make the doc

						parameters_here = contrastsensitivity_calc;
						parameters_here.spatial_frequencies = vlt.data.rowvec(spatial_frequencies);
						parameters_here.sensitivity_RB = sensitivity_RB;
						parameters_here.sensitivity_RBN = sensitivity_RBN;
						parameters_here.sensitivity_RBNS = sensitivity_RBNS;
					
						if numel(tuning_curves)>0,	
							doc{end+1} = ndi.document(ndi_calculation_obj.doc_document_types{1},'contrastsensitivity_calc',parameters_here);
						end;
						
					end; % if good
				end;
				
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculation_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculation. For contrast_sensitivity_calc, there is no appropriate default parameters
			% so this search will yield empty.
			%
				parameters.input_parameters = struct([]);
				parameters.depends_on = vlt.data.emptystruct('name','value');
				parameters.query = ndi_calculation_obj.default_parameters_query(parameters);
					
		end; % default_search_for_input_parameters

                function query = default_parameters_query(ndi_calculation_obj, parameters_specification)
			% DEFAULT_PARAMETERS_QUERY - what queries should be used to search for input parameters if none are provided?
			%
			% QUERY = DEFAULT_PARAMETERS_QUERY(NDI_CALCULATION_OBJ, PARAMETERS_SPECIFICATION)
			%
			% When one calls SEARCH_FOR_INPUT_PARAMETERS, it is possible to specify a 'query' structure to
			% select particular documents to be placed into the parameters 'depends_on' specification.
			% If one does not provide any 'query' structure, then the default values here are used.
			%
			% The function returns:
			% |-----------------------|----------------------------------------------|
			% | query                 | A structure with 'name' and 'query' fields   |
			% |                       |   that describes a search to be performed to |
			% |                       |   identify inputs for the 'depends_on' field |
			% |                       |   in the PARAMETERS output.                  |
			% |-----------------------|-----------------------------------------------
			%
			% For the ndi.calc.stimulus.contrast_sensitivity_calc class, this looks for 
			% documents of type 'stimulus_response_scalar.json' with 'response_type' fields
			% the contain 'mean' or 'F1'.
			%
			%
				q_total = ndi.query('','isa','ndi_document_element','');

				query = struct('name','element_id','query',q_total);
		end; % default_parameters_query()

		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: CONTRAST_SENSITIVITY_CALC
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | CONTRAST_TUNING_CALC -- ABOUT |
			%   ------------------------
			%
			%   CONTRAST_TUNING_CALC is a demonstration document. It simply produces the 'answer' that
			%   is provided in the input parameters. Each CONTRAST_TUNING_CALC document 'depends_on' an
			%   NDI daq system.
			%
			%   Definition: apps/contrast_sensitivity_calc.json
			%
				eval(['help ndi.calc.example.contrast_sensitivity.doc_about']);
		end; %doc_about()

		function h=plot(ndi_calculation_obj, doc_or_parameters, varargin)
                        % PLOT - provide a diagnostic plot to show the results of the calculation
                        %
                        % H=PLOT(NDI_CALCULATION_OBJ, DOC_OR_PARAMETERS, ...)
                        %
                        % Produce a plot of the tuning curve.
			%
                        % Handles to the figure, the axes, and any objects created are returned in H.
                        %
                        % This function takes additional input arguments as name/value pairs.
                        % See ndi.calculation.plot_parameters for a description of those parameters.

				% call superclass plot method to set up axes
				h=plot@ndi.calculation(ndi_calculation_obj, doc_or_parameters, varargin{:});

				if isa(doc_or_parameters,'ndi.document'),
					doc = doc_or_parameters;
				else,
					error(['Do not know how to proceed without an ndi document for doc_or_parameters.']);
				end;

				cs = doc.document_properties.contrastsensitivity_calc; % shorten our typing

				noise_threshold_indexes = [3 4 5 6];

				% First plot responses

				for i=1:numel(noise_threshold_indexes),
					hold on;
					h_baseline = plot([min(cs.spatial_frequencies) max(cs.spatial_frequencies)],...
						[0 0],'k--','linewidth',1.0001);
					h_baseline.Annotation.LegendInformation.IconDisplayStyle = 'off';
					h.objects(end+1) = h_baseline;
					
					% plot all fits

					h.objects(end+1) = plot(cs.spatial_frequencies, cs.sensitivity_RB(noise_threshold_indexes(i),:), 'o-', 'color', (1/(numel(noise_threshold_indexes)-1)) * [0 1 0],...
						'linewidth',1.5);
					h.objects(end+1) = plot(cs.spatial_frequencies, cs.sensitivity_RBN(noise_threshold_indexes(i),:), 'd-', 'color', (1/(numel(noise_threshold_indexes)-1)) * [0 0 1],...
						'linewidth',1.5);
					h.objects(end+1) = plot(cs.spatial_frequencies, cs.sensitivity_RBNS(noise_threshold_indexes(i),:), 's-', 'color', (1/(numel(noise_threshold_indexes)-1)) * [1 0 1],...
						'linewidth',1.5);

				end;

				if ~h.params.suppress_x_label,
					h.xlabel = xlabel('Spatial frequency');
				end;
				if ~h.params.suppress_y_label,
					h.ylabel = ylabel(['Sensitivity']);
				end;

				if 0, % when database is faster :-/
					if ~h.params.suppress_title,
						element = ndi.database.fun.ndi_document2ndi_object(doc.dependency_value('element_id'),ndi_calculation_obj.session);
						h.title = title(element.elementstring(), 'interp','none');
					end;
				end;
				box off;

		end; % plot()

	end; % methods()
end % contrast_sensitivity
