classdef oridir_tuning < ndi.calculator

	methods
		function oridir_tuning_obj = oridir_tuning(session)
			% oridir_tuning - ndi.calculator object that
			% calculates orientation and direction tuning curves from spike
			% elements
			%
			% ORIDIRTUNING_OBJ = ORIDIRTUNING(SESSION)
			%
			% Creates a oridir_tuning ndi.calculator object
			%
				ndi.globals;
				oridir_tuning_obj = oridir_tuning_obj@ndi.calculator(session,'oridir_tuning',...
					fullfile(ndi_globals.path.documentpath,'apps','calculators','oridirtuning_calc.json'));
		end; % oridir_tuning() creator

		function doc = calculate(ndi_calculator_obj, parameters)
			% CALCULATE - perform the calculator for
			% ndi.calc.oridir_tuning
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a oridir_tuning_direction_tuning_calc document given input parameters.
			
				% Step 1. Check inputs
				if ~isfield(parameters,'input_parameters'),
					error(['parameters structure lacks ''input_parameters.''']);
				end;
				if ~isfield(parameters,'depends_on'),
					error(['parameters structure lacks ''depends_on.''']);
				end;
						
				% Step 2. Set up output structure
				oridir_tuning = parameters;
						
				tuning_doc = ndi_calculator_obj.session.database_search(ndi.query('ndi_document.id',...
					'exact_number',...
					vlt.db.struct_name_value_search(parameters.depends_on,'stimulus_tuningcurve_id'),''));
				if numel(tuning_doc)~=1, 
					error(['Could not find stimulus tuning curve doc..']);
				end;
				tuning_doc = tuning_doc{1};
						
				% Step 3. Calculate oridir_tuning and direction indexes from
				% stimulus responses and write output into an oridir_tuning document

				oriapp = ndi.app.oridirtuning(ndi_calculator_obj.session);
				doc = oriapp.calculate_oridir_indexes(tuning_doc,0,0);

				% Step 4. Check if doc exists
				if ~isempty(doc), 
					doc = ndi.document(ndi_calculator_obj.doc_document_types{1},...
						'oridirtuning_calc',oridir_tuning) + doc;
					doc = doc.set_dependency_value('stimulus_tuningcurve_id',tuning_doc.id());
				end;
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculator_obj, varargin)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATION_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculator.
			%
				% search for stimulus_tuningcurve_id
				parameters.input_parameters = struct([]);
			
				% parameters.input_parameters = struct('independent_label','','independent_parameter','','best_algorithm','empirical_maximum');
				% parameters.input_parameters.selection = vlt.data.emptystruct('property','operation','value');

				parameters.depends_on = vlt.data.emptystruct('name','value');
				parameters.query = ndi_calculator_obj.default_parameters_query(parameters);
		end; % default_search_for_input_parameters

		function query = default_parameters_query(ndi_calculator_obj, parameters_specification)
			% DEFAULT_PARAMETERS_QUERY - what queries should be used to
			% search for input parameters
			%
			% QUERY = DEFAULT_PARAMETERS_QUERY(NDI_CALCULATION_OBJ,
			% PARAMETERS_SPECIFICATION)
			%
			% Calling SEARCH_FOR_INPUT_PARAMETERS allows for users to
			% specify a 'query' structure to select particular documents to
			% be placed into the 'depends_on' parameter specification.
			% If a 'query' structure is not provided, the default will be
			% used.
			%
			% The function returns: 
			% |-----------|--------------------------------------------|
			% | query     | A structure with 'name' and 'query' fields |
			% |           | that describes a search to be performed to |
			% |           | identify inputs for the 'depends_on' field |
			% |           | in the PARAMETERS output.                  |
			% |-----------|--------------------------------------------|
			%
			% For the ndi.calc.vision.tuning_curve class, this looks for
			% documents of type 'stimulus_tuningcurve.json' with
			% 'response_type' fields that contain 'mean' or 'F1'.
			%
			%         
				q1 = ndi.query('','isa','stimulus_tuningcurve.json','');
			
				q2 = ndi.query('tuning_curve.independent_variable_label','exact_string_anycase','Orientation','');
				q3 = ndi.query('tuning_curve.independent_variable_label','exact_string_anycase','Direction','');
				q4 = ndi.query('tuning_curve.independent_variable_label','exact_string_anycase','angle','');
				q234 = q2 | q3 | q4;
				q_total = q1 & q234;
			
				query = struct('name','stimulus_tuningcurve_id','query',q_total);
		
		end; % default_parameters_query()
		
		function b = is_valid_dependency_input(ndi_calculator_obj, name, value)
			% IS_VALID_DEPENDENCY_INPUT - checks if a potential dependency input
			% actually valid for this calculator
			% 
			% B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATION_OBJ, NAME,
			% VALUE)
			%
			% Tests whether a potential input to a calculator is valid.
			% NAME - potential dependency name
			% VALUE - ndi_document id of the potential dependency name
			%
			% The base class behavior of this function will return true.
			% This is overridden if additional criteria beyond an ndi.query
			% are needed to assess if a document is an appropriate input
			% for the calculator.
				b = 1;
				return;

				% could also use the below, but will require an extra query operation
				% and updating for speed

				switch lower(name),
					case lower('stimulus_tuningcurve_id'),
						q = ndi.query('ndi_document.id','exact_string',value,'');
						d = ndi_calculator_obj.S.database_search(q);
						b = (numel(d.document_properties.independent_variable_label) ==2);
					end;
		end; % is_valid_dependency_input()

		function oridir_doc = calculate_oridir_indexes(ndi_calculator_obj, tuning_doc)
			% CALCULATE_ORIDIR_INDEXES - calculate orientation and direction index values from a tuning curve
			%
			% ORIDIR_DOC = CALCULATE_ORIDIR_INDEXES(NDI_ORIDIRTUNING_CALC_OBJ, TUNING_DOC)
			%
			% Given a 2-dimensional tuning curve document with measurements
			% at orientation and direction frequencies, this function calculates oridir_tuning
			% parameters and stores them in ORIDIRTUNING document ORIDIR_DOC.
			%
			%
				ind = {};
				ind_real = {};
				control_ind = {};
				control_ind_real = {};
				response_ind = {};
				response_mean = [];
				response_stddev = [];
				response_stderr = [];
                
				% stim_response_doc
				stim_response_doc = ndi_calculator_obj.session.database_search(ndi.query('ndi_document.id',...
					'exact_string',tuning_doc.dependency_value('stimulus_response_scalar_id'),''));
				if numel(stim_response_doc)~=1,
					error(['Could not find stimulus response scalar document.']);
				end;
				if iscell(stim_response_doc),
					stim_response_doc = stim_response_doc{1};
				end;
                
				tuning_doc = tapp.tuningdoc_fixcellarrays(tuning_doc);
                
				for i=1:numel(tuning_doc.document_properties.tuning_curve.individual_responses_real),
					ind{i} = tuning_doc.document_properties.tuning_curve.individual_responses_real{i} + ...
						sqrt(-1)*tuning_doc.document_properties.tuning_curve.individual_responses_imaginary{i};
					ind_real{i} = ind{i};
					if any(~isreal(ind_real{i})), 
						ind_real{i} = abs(ind_real{i}); 
					end;
					control_ind{i} = tuning_doc.document_properties.tuning_curve.control_individual_responses_real{i} + ...
						sqrt(-1)*tuning_doc.document_properties.tuning_curve.control_individual_responses_imaginary{i};
					control_ind_real{i} = control_ind{i};
					if any(~isreal(control_ind_real{i})), 
						control_ind_real{i} = abs(control_ind_real{i}); 
					end;
					response_ind{i} = ind{i} - control_ind{i};
					response_mean(i) = nanmean(response_ind{i});
					if ~isreal(response_mean(i)), 
						response_mean(i) = abs(response_mean(i)); 
					end;
					response_stddev(i) = nanstd(response_ind{i});
					response_stderr(i) = vlt.data.nanstderr(response_ind{i});
					if any(~isreal(response_ind{i})),
						response_ind{i} = abs(response_ind{i});
					end;
				end;
                   
				properties.coordinates = 'compass';
				properties.response_units = tuning_doc.document_properties.tuning_curve.response_units;
				properties.response_type = stim_response_doc.document_properties.stimulus_response_scalar.response_type;

				response.curve = ...
					[ tuning_doc.document_properties.tuning_curve.independent_variable_value(:)' ; ...
						response_mean ; ...
						response_stddev ; ...
						response_stderr; ];
				response.ind = response_ind;

 				vi = vlt.neuro.vision.oridir.index.oridir_vectorindexes(response);
 				fi = vlt.neuro.vision.oridir.index.oridir_fitindexes(response);
             
				resp.ind = ind_real;
				resp.blankind = control_ind_real{1};
				resp = ndi.app.stimulus.tuning_response.tuningcurvedoc2vhlabrespstruct(tuning_doc);
				[anova_across_stims, anova_across_stims_blank] = neural_response_significance(resp);

				tuning_curve = struct(...
					'direction', vlt.data.rowvec(tuning_doc.document_properties.tuning_curve.independent_variable_value), ...
					'mean', response_mean, ...
					'stddev', response_stddev, ...
					'stderr', response_stderr, ...
					'individual', {response_ind}, ...
					'raw_individual', {ind_real}, ...
					'control_individual', {control_ind_real});

				significance = struct('visual_response_anova_p',anova_across_stims_blank,...
					'across_stimuli_anova_p', anova_across_stims);

				vector = struct('circular_variance', vi.ot_circularvariance, ...
					'direction_circular_variance', vi.dir_circularvariance', ...
					'Hotelling2Test', vi.ot_HotellingT2_p, ...
					'orientation_preference', vi.ot_pref, ...
					'direction_preference', vi.dir_pref, ...
					'direction_hotelling2test', vi.dir_HotellingT2_p, ...
					'dot_direction_significance', vi.dir_dotproduct_sig_p);

				fit = struct('double_guassian_parameters', fi.fit_parameters,...
					'double_gaussian_fit_angles', vlt.data.rowvec(fi.fit(1,:)), ...
					'double_gaussian_fit_values', vlt.data.rowvec(fi.fit(2,:)), ...
					'orientation_preferred_orthogonal_ratio', fi.ot_index, ...
					'direction_preferred_null_ratio', fi.dir_index, ...
					'orientation_preferred_orthogonal_ratio_rectified', fi.ot_index_rectified', ...
					'direction_preferred_null_ratio_rectified', fi.dir_index_rectified, ...
					'orientation_angle_preference', mod(fi.dirpref,180), ...
					'direction_angle_preference', fi.dirpref, ...
					'hwhh', fi.tuning_width);

				% create document and store in oridir_tuning
				oriprops = ndi.document('stimulus/vision/oridir/orientation_direction_tuning',...
					'orientation_direction_tuning',vlt.data.var2struct('properties', 'tuning_curve', 'significance', 'vector', 'fit'));
                                oriprops = oriprops.set_dependency_value('element_id', stim_response_doc{1}.dependency_value('element_id'));
				oriprops = oriprops.set_dependency_value('stimulus_tuningcurve_id',tuning_doc.id());
		end; %calculate_oridir_indexes()
    
		function h=plot(ndi_calculator_obj, doc_or_parameters, varargin)
			% PLOT - provide a diagnostic plot to show the results of the calculator
			%
			% H=PLOT(NDI_CALCULATION_OBJ, DOC_OR_PARAMETERS, ...)
			%
			% Produce a plot of the tuning curve.
			%
			% Handles to the figure, the axes, and any objects created are returned in H.
			%
			% This function takes additional input arguments as name/value pairs.
			% See ndi.calculator.plot_parameters for a description of those parameters.

				% call superclass plot method to set up axes
				h=plot@ndi.calculator(ndi_calculator_obj, doc_or_parameters, varargin{:});
				
				% Check doc parameters
				if isa(doc_or_parameters,'ndi.document'),
					doc = doc_or_parameters;
				else,
					error(['Do not know how to proceed without an ndi document for doc_or_parameters.']);
				end;
           
				ot = doc.document_properties.orientation_direction_tuning;  % set variable for less typing
            
				% Set up plot
				ha = vlt.plot.myerrorbar(ot.tuning_curve.direction, ...
					ot.tuning_curve.mean, ...
					ot.tuning_curve.stderr, ...
					ot.tuning_curve.stderr);
                
				delete(ha(2));
				set(ha(1), 'color', [0 0 0]);
				h.objects(end+1) = ha(1);
                
				% Plot responses
				hold on;
				h_baseline = plot([0 360], [0 0], 'k--');
				h_fitline = plot(ot.fit.double_gaussian_fit_angles,...
					ot.fit.double_gaussian_fit_values,'k-');
				h.objects(end+1) = h_baseline;
				h.objects(end+1) = h_fitline;
			
				% Set labels
				if ~h.params.suppress_x_label,
					h.xlabel = xlabel('Direction (\circ)');
				end;
				if ~h.params.suppress_y_label,
					h.ylabel = ylabel(ot.properties.response_units);
				end;

				if 0, % when database is faster :-/
					if ~h.params.suppress_title,
						element = ndi.database.fun.ndi_document2ndi_object(doc.dependency_value('stimulus_tuningcurve_id'),ndi_calculator_obj.session);
						h.title = title([element.elementstring() '.' element.type '; ' ot.properties.response_type]);
					end;
				end;
				box off;
		end; % plot()
		
		function doc_about(ndi_calculator_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: ORIDIRTUNING
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | ORIDIRTUNING -- ABOUT |
			%   ------------------------
			%
			%   ORIDIRTUNING is an ndi.calculator object that calculates the oridir_tuning and direction tuning
			%   curves from spike elements.
			%   
			%   Each  document 'depends_on' an NDI daq system.
			%
			%   Definition: apps/calc/oridir_tuning.json
			%
				eval(['help ndi.calc.vision.oridir_tuning.doc_about']);
		end; %doc_about()

    end; % methods()
			
end % oridir_tuning
