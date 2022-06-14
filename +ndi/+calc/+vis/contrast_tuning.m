classdef contrast_tuning < ndi.calculator

	methods
		function contrast_tuning_obj = contrast_tuning(session)
			% CONTRAST_TUNING - a contrast_tuning demonstration of an ndi.calculator object
			%
			% CONTRAST_TUNING_OBJ = CONTRAST_TUNING(SESSION)
			%
			% Creates a CONTRAST_TUNING ndi.calculator object
			%
				ndi.globals;
				contrast_tuning_obj = contrast_tuning_obj@ndi.calculator(session,'contrasttuning_calc',...
					fullfile(ndi_globals.path.documentpath,'apps','calculators','contrasttuning_calc.json'));
		end; % contrast_tuning()

		function doc = calculate(ndi_calculator_obj, parameters)
			% CALCULATE - perform the calculator for ndi.calc.example.contrast_tuning
			%
			% DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
			%
			% Creates a contrast_tuning_calc document given input parameters.
			%
			% The document that is created contrast_tuning
			% by the input parameters.
				% check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters''.']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on''.']); end;
				
				% Step 1: set up the output structure
				contrast_tuning_calc = parameters;

				tuning_response_doc = ndi_calculator_obj.session.database_search(ndi.query('ndi_document.id','exact_number',...
					vlt.db.struct_name_value_search(parameters.depends_on,'stimulus_tuningcurve_id'),''));
				if numel(tuning_response_doc)~=1, 
					error(['Could not find stimulus tuning doc..']);
				end;
				tuning_response_doc = tuning_response_doc{1};

				% Step 2: perform the calculator, which here creates a contrast_tuning doc
				doc = ndi_calculator_obj.calculate_contrast_indexes(tuning_response_doc);
				
				if ~isempty(doc), 
					doc = ndi.document(ndi_calculator_obj.doc_document_types{1},'contrasttuning_calc',contrast_tuning_calc) + doc;
				end;
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculator_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculator. For contrast_tuning_calc, there is no appropriate default parameters
			% so this search will yield empty.
			%
				parameters.input_parameters = struct([]);
				parameters.depends_on = vlt.data.emptystruct('name','value');
				parameters.query = ndi_calculator_obj.default_parameters_query(parameters);
					
		end; % default_search_for_input_parameters

                function query = default_parameters_query(ndi_calculator_obj, parameters_specification)
			% DEFAULT_PARAMETERS_QUERY - what queries should be used to search for input parameters if none are provided?
			%
			% QUERY = DEFAULT_PARAMETERS_QUERY(NDI_CALCULATOR_OBJ, PARAMETERS_SPECIFICATION)
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
			% For the ndi.calc.stimulus.contrast_tuning_calc class, this looks for 
			% documents of type 'stimulus_response_scalar.json' with 'response_type' fields
			% the contain 'mean' or 'F1'.
			%
			%
				q1 = ndi.query('','isa','stimulus_tuningcurve.json','');
				q2 = ndi.query('tuning_curve.independent_variable_label','exact_string','contrast','');
				q3 = ndi.query('tuning_curve.independent_variable_label','exact_string','Contrast','');
				q4 = ndi.query('tuning_curve.independent_variable_label','exact_string','CONTRAST','');
				q234 = q2 | q3 | q4;
				q_total = q1 & q234;

				query = struct('name','stimulus_tuningcurve_id','query',q_total);
		end; % default_parameters_query()

		function b = is_valid_dependency_input(ndi_calculator_obj, name, value)
			% IS_VALID_DEPENDENCY_INPUT - is a potential dependency input actually valid for this calculator?
			%
			% B = IS_VALID_DEPENDENCY_INPUT(NDI_CALCULATOR_OBJ, NAME, VALUE)
			%
			% Tests whether a potential input to a calculator is valid.
			% The potential dependency name is provided in NAME and its ndi_document id is
			% provided in VALUE.
			%
			% The base class behavior of this function is simply to return true, but it
			% can be overriden if additional criteria beyond an ndi.query are needed to
			% assess if a document is an appropriate input for the calculator.
			%
				b = 1;
				return;

				% could also use the below, but will require an extra query operation
	
				switch lower(name),
					case lower('stimulus_tuningcurve_id'),
						q = ndi.query('ndi_document.id','exact_string',value,'');
						d = ndi_calculator_obj.S.database_search(q);
						b = (numel(d.document_properties.independent_variable_label) ==1);
					case lower('element_id'),
						b = 1;
				end;
		end; % is_valid_dependency_input()

		function doc_about(ndi_calculator_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATOR: CONTRAST_TUNING_CALC
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
			%   Definition: apps/contrast_tuning_calc.json
			%
				eval(['help ndi.calc.example.contrast_tuning.doc_about']);
		end; %doc_about()

		function h=plot(ndi_calculator_obj, doc_or_parameters, varargin)
                        % PLOT - provide a diagnostic plot to show the results of the calculator
                        %
                        % H=PLOT(NDI_CALCULATOR_OBJ, DOC_OR_PARAMETERS, ...)
                        %
                        % Produce a plot of the tuning curve.
			%
                        % Handles to the figure, the axes, and any objects created are returned in H.
                        %
                        % This function takes additional input arguments as name/value pairs.
                        % See ndi.calculator.plot_parameters for a description of those parameters.

				% call superclass plot method to set up axes
				h=plot@ndi.calculator(ndi_calculator_obj, doc_or_parameters, varargin{:});

				if isa(doc_or_parameters,'ndi.document'),
					doc = doc_or_parameters;
				else,
					error(['Do not know how to proceed without an ndi document for doc_or_parameters.']);
				end;

				ct = doc.document_properties.contrast_tuning; % shorten our typing
				tc = ct.tuning_curve; % shorten our typing
				ft = ct.fit;

				% First plot responses
				hold on;
				h_baseline = plot([min(tc.contrast) max(tc.contrast)],...
					[0 0],'k--','linewidth',1.0001);
				h_baseline.Annotation.LegendInformation.IconDisplayStyle = 'off';
				h.objects(end+1) = h_baseline;
				[v,sortorder] = sort(tc.contrast);
				h_errorbar = errorbar(tc.contrast(sortorder(:)),...
					tc.mean(sortorder(:)),tc.stderr(sortorder(:)),tc.stderr(sortorder(:)));
				set(h_errorbar,'color',[0 0 0],'linewidth',1,'linestyle','none');
				h.objects = cat(2,h.objects,h_errorbar);
				
				% Second plot all fits

				h.objects(end+1) = plot(ft.naka_rushton_RB_contrast,ft.naka_rushton_RB_values,'-','color',0.33*[1 0 1],...
					'linewidth',1.5);
				h.objects(end+1) = plot(ft.naka_rushton_RBN_contrast,ft.naka_rushton_RBN_values,'-','color',0.67*[1 0 1],...
					'linewidth',1.5);
				h.objects(end+1) = plot(ft.naka_rushton_RBNS_contrast,ft.naka_rushton_RBNS_values,'-','color',1*[1 0 1],...
					'linewidth',1.5);

				if ~h.params.suppress_x_label,
					h.xlabel = xlabel('Contrast');
				end;
				if ~h.params.suppress_y_label,
					h.ylabel = ylabel(['Response (' ct.properties.response_type ', ' ct.properties.response_units ')']);
				end;

				if 0, % when database is faster :-/
					if ~h.params.suppress_title,
						element = ndi.database.fun.ndi_document2ndi_object(doc.dependency_value('element_id'),ndi_calculator_obj.session);
						h.title = title(element.elementstring(), 'interp','none');
					end;
				end;
				box off;

		end; % plot()

		function contrast_props_doc = calculate_contrast_indexes(ndi_calculator_obj, tuning_doc)
			% CALCULATE_CONTRAST_INDEXES - calculate contrast index values from a tuning curve
			%
			% CONTRAST_PROPS_DOC = CALCULATE_CONTRAST_INDEXES(NDI_CONTRAST_TUNING_CALC_OBJ, TUNING_DOC)
			%
			% Given a 1-dimensional tuning curve document, this function calculates contrast response
			% parameters and stores them in CONTRAST_TUNING document CONTRAST_PROPS_DOC.
			%
			%
				properties.response_units = tuning_doc.document_properties.tuning_curve.response_units;
				
				stim_response_doc = ndi_calculator_obj.session.database_search(ndi.query('ndi_document.id',...
					'exact_string',tuning_doc.dependency_value('stimulus_response_scalar_id'),''));
				if numel(stim_response_doc)~=1,
					error(['Could not find stimulus response scalar document.']);
				end;
				if iscell(stim_response_doc),
					stim_response_doc = stim_response_doc{1};
				end;

				properties.response_type = stim_response_doc.document_properties.stimulus_response_scalar.response_type;

				resp = ndi.app.stimulus.tuning_response.tuningcurvedoc2vhlabrespstruct(tuning_doc);

				[anova_across_stims, anova_across_stims_blank] = neural_response_significance(resp);

				tuning_curve = struct(...
					'contrast', ...
						vlt.data.rowvec(tuning_doc.document_properties.tuning_curve.independent_variable_value), ...
					'mean', resp.curve(2,:), ...
					'stddev', resp.curve(3,:), ...
					'stderr', resp.curve(4,:), ...
					'individual', {resp.ind}, ...
					'control_stddev', resp.blankresp(2),...
					'control_stderr', resp.blankresp(3));

				significance = struct('visual_response_anova_p',anova_across_stims_blank,...
					'across_stimuli_anova_p', anova_across_stims);

				fitless.interpolated_c50 = vlt.neuro.vision.contrast.indexes.c50interpolated(tuning_curve.contrast,...
					tuning_curve.mean);

				prefixes = {'naka_rushton_RB_','naka_rushton_RBN_', 'naka_rushton_RBNS_'};
				fitterms = 2:4;

				fit = struct([]);

				fit(1).naka_rushton_RB_parameters = [];

				for f = 1:numel(fitterms),
					fi = vlt.neuro.vision.contrast.indexes.fitindexes(resp,fitterms(f));
					fit = setfield(fit,[prefixes{f} 'parameters'],fi.fit_parameters);
					fit = setfield(fit,[prefixes{f} 'contrast'],fi.fit(1,:));
					fit = setfield(fit,[prefixes{f} 'values'],fi.fit(2,:));
					[m,pref_index] = max(fi.fit(2,:));
					pref = fi.fit(1,pref_index);
					fit = setfield(fit,[prefixes{f} 'pref'], pref);
					fit = setfield(fit,[prefixes{f} 'empirical_c50'], fi.empirical_C50);
					fit = setfield(fit,[prefixes{f} '_r2'], fi.r2);
					fit = setfield(fit,[prefixes{f} 'relative_max_gain'], fi.relative_max_gain);
					fit = setfield(fit,[prefixes{f} 'saturation_index'], fi.saturation_index);
					fit = setfield(fit,[prefixes{f} 'sensitivity'], fi.sensitivity);
				end;

				contrast_tuning.properties = properties;
				contrast_tuning.tuning_curve = tuning_curve;
				contrast_tuning.significance = significance;
				contrast_tuning.fitless = fitless;
				contrast_tuning.fit = fit;

				contrast_props_doc = ndi.document('stimulus/vision/contrast/contrast_tuning',...
					'contrast_tuning',contrast_tuning);
				contrast_props_doc = contrast_props_doc.set_dependency_value('element_id', ...
					tuning_doc.dependency_value('element_id'));
				contrast_props_doc = contrast_props_doc.set_dependency_value('stimulus_tuningcurve_id',tuning_doc.id());

		end; % calculate_contrast_indexes()

	end; % methods()
end % contrast_tuning
