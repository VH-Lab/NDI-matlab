classdef speed_tuning < ndi.calculator

	methods
		function speed_tuning_obj = speed_tuning(session)
			% SPEED_TUNING - a speed_tuning demonstration of an ndi.calculator object
			%
			% SPEED_TUNING_OBJ = SPEED_TUNING(SESSION)
			%
			% Creates a SPEED_TUNING ndi.calculator object
			%
				ndi.globals;
				speed_tuning_obj = speed_tuning_obj@ndi.calculator(session,'speedtuning_calc',...
					fullfile(ndi_globals.path.documentpath,'apps','calculators','speedtuning_calc.json'));
		end; % speed_tuning()

		function doc = calculate(ndi_calculator_obj, parameters)
			% CALCULATE - perform the calculator for ndi.calc.example.speed_tuning
			%
			% DOC = CALCULATE(NDI_CALCULATOR_OBJ, PARAMETERS)
			%
			% Creates a speed_tuning_calc document given input parameters.
			%
			% The document that is created speed_tuning
			% by the input parameters.
				% check inputs
				if ~isfield(parameters,'input_parameters'), error(['parameters structure lacks ''input_parameters''.']); end;
				if ~isfield(parameters,'depends_on'), error(['parameters structure lacks ''depends_on''.']); end;
				
				% Step 1: set up the output structure
				speed_tuning_calc = parameters;

				tuning_response_doc = ndi_calculator_obj.session.database_search(ndi.query('ndi_document.id','exact_number',...
					vlt.db.struct_name_value_search(parameters.depends_on,'stimulus_tuningcurve_id'),''));
				if numel(tuning_response_doc)~=1, 
					error(['Could not find stimulus tuning doc..']);
				end;
				tuning_response_doc = tuning_response_doc{1};

				% Step 2: perform the calculator, which here creates a speed_tuning doc
				doc = ndi_calculator_obj.calculate_speed_indexes(tuning_response_doc);
				
				if ~isempty(doc), 
					doc = ndi.document(ndi_calculator_obj.doc_document_types{1},'speedtuning_calc',speed_tuning_calc) + doc;
					doc = doc.set_dependency_value('stimulus_tuningcurve_id',tuning_response_doc.id());
					doc = doc.set_dependency_value('element_id',tuning_response_doc.dependency_value('element_id'));
				end;
		end; % calculate

		function parameters = default_search_for_input_parameters(ndi_calculator_obj)
			% DEFAULT_SEARCH_FOR_INPUT_PARAMETERS - default parameters for searching for inputs
			%
			% PARAMETERS = DEFAULT_SEARCH_FOR_INPUT_PARAMETERS(NDI_CALCULATOR_OBJ)
			%
			% Returns a list of the default search parameters for finding appropriate inputs
			% to the calculator. For speed_tuning_calc, there is no appropriate default parameters
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
			% For the ndi.calc.stimulus.speed_tuning_calc class, this looks for 
			% documents of type 'stimulus_response_scalar.json' with 'response_type' fields
			% the contain 'mean' or 'F1'.
			%
			%
				q1 = ndi.query('','isa','stimulus_tuningcurve.json','');
				q2 = ndi.query('tuning_curve.independent_variable_label','hasmember','spatial_frequency','');
				q3 = ndi.query('tuning_curve.independent_variable_label','hasmember','temporal_frequency','');
				q4 = ndi.query('tuning_curve.independent_variable_label','hassize',[2 1],'');
				q_total = q1 & q2 & q3 & q4;

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
				% and updating for speed
	
				switch lower(name),
					case lower('stimulus_tuningcurve_id'),
						q = ndi.query('ndi_document.id','exact_string',value,'');
						d = ndi_calculator_obj.S.database_search(q);
						b = (numel(d.document_properties.independent_variable_label) ==2);
					case lower('element_id'),
						b = 1;
				end;
		end; % is_valid_dependency_input()

		function doc_about(ndi_calculator_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATOR: SPEED_TUNING_CALC
			% ----------------------------------------------------------------------------------------------
			%
			%   ------------------------
			%   | SPEED_TUNING_CALC -- ABOUT |
			%   ------------------------
			%
			%   SPEED_TUNING_CALC is a demonstration document. It simply produces the 'answer' that
			%   is provided in the input parameters. Each SPEED_TUNING_CALC document 'depends_on' an
			%   NDI daq system.
			%
			%   Definition: apps/speed_tuning_calc.json
			%
				eval(['help ndi.calc.example.speed_tuning.doc_about']);
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

				sp = doc.document_properties.speed_tuning; % shorten our typing
				tc = sp.tuning_curve; % shorten our typing
				ft = sp.fit;

				% First plot fit
				hold on;

				%h_baseline = plot([min(tc.speed) max(tc.speed)],...
				%	[0 0],'k--','linewidth',1.0001);
				%h_baseline.Annotation.LegendInformation.IconDisplayStyle = 'off';

				% now call the plot routine

				[SF,TF,MNs] = vlt.math.vector2mesh(tc.spatial_frequency,tc.temporal_frequency,tc.mean);
				MNs_fit = vlt.neuro.vision.speed.tuningfunc(SF,TF,ft.Priebe_fit_parameters);

				significant = 0;
				linestyle = '--';
				if sp.significance.visual_response_anova_p<0.05,
					significant = 1;
					linestyle = '-';
				end;
				vlt.neuro.vision.speed.plottuning(SF,TF,MNs_fit,'marker','none','linestyle',linestyle);

				% now plot raw responses
				vlt.neuro.vision.speed.plottuning(SF,TF,MNs);

                ch = get(gcf,'children');
                currentaxes = gca;
                axes(ch(1));
                title(['Speed tuning:' num2str(ft.Priebe_fit_parameters(3))]);				

				if 0, % plot function already does this
				if ~h.params.suppress_x_label,
					h.xlabel = xlabel('Speed (deg/sec)');
				end;
				if ~h.params.suppress_y_label,
					h.ylabel = ylabel(['Response (' sp.properties.response_type ', ' sp.properties.response_units ')']);
				end;
				box off;
				end;


		end; % plot()

		function speed_props_doc = calculate_speed_indexes(ndi_calculator_obj, tuning_doc)
			% CALCULATE_SPEED_INDEXES - calculate speed index values from a tuning curve
			%
			% SPEED_PROPS_DOC = CALCULATE_SPEED_INDEXES(NDI_SPEED_TUNING_CALC_OBJ, TUNING_DOC)
			%
			% Given a 2-dimensional tuning curve document with measurements at many spatial and
			% and temporal frequencies, this function calculates speed response
			% parameters and stores them in SPEED_TUNING document SPEED_PROPS_DOC.
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

				sf_coord = 1;
				tf_coord = 2;
				if contains(tuning_doc.document_properties.tuning_curve.independent_variable_label{1},'temporal','IgnoreCase',true),
					sf_coord = 2;
					tf_coord = 1;
				end;

				resp = ndi.app.stimulus.tuning_response.tuningcurvedoc2vhlabrespstruct(tuning_doc);

				[anova_across_stims, anova_across_stims_blank] = neural_response_significance(resp);

				tuning_curve = struct(...
					'spatial_frequency', ...
						vlt.data.rowvec(tuning_doc.document_properties.tuning_curve.independent_variable_value(:,1)), ...
					'temporal_frequency', ...
						vlt.data.rowvec(tuning_doc.document_properties.tuning_curve.independent_variable_value(:,2)), ...
					'mean', resp.curve(2,:), ...
					'stddev', resp.curve(3,:), ...
					'stderr', resp.curve(4,:), ...
					'individual', {resp.ind}, ...
					'control_stddev', resp.blankresp(2),...
					'control_stderr', resp.blankresp(3));

				significance = struct('visual_response_anova_p',anova_across_stims_blank,...
					'across_stimuli_anova_p', anova_across_stims);

				f = vlt.neuro.vision.speed.fit(tuning_curve.spatial_frequency(:),tuning_curve.temporal_frequency(:),tuning_curve.mean(:));
				sfs = logspace(0.01,60,200);
				tfs = logspace(0.01,120,200);
				[SFs,TFs] = meshgrid(sfs,tfs);
				fit_values = vlt.neuro.vision.speed.tuningfunc(SFs(:),TFs(:),f);

				fit.Priebe_fit_parameters = f;
				fit.Priebe_fit_spatial_frequencies = SFs(:);
				fit.Priebe_fit_temporal_frequencies = TFs(:);
				fit.Priebe_fit_values = fit_values;
				fit.Priebe_fit_speed_tuning_index = fit.Priebe_fit_parameters(3);
				fit.Priebe_fit_spatial_frequency_preference = fit.Priebe_fit_parameters(6);
				fit.Priebe_fit_temporal_frequency_preference = fit.Priebe_fit_parameters(7);

				speed_tuning.properties = properties;
				speed_tuning.tuning_curve = tuning_curve;
				speed_tuning.significance = significance;
				speed_tuning.fit = fit;

				speed_props_doc = ndi.document('stimulus/vision/speed/speed_tuning',...
					'speed_tuning',speed_tuning);
				speed_props_doc = speed_props_doc.set_dependency_value('element_id', ...
					tuning_doc.dependency_value('element_id'));
				speed_props_doc = speed_props_doc.set_dependency_value('stimulus_tuningcurve_id',tuning_doc.id());
		end; % calculate_speed_indexes()
	end; % methods()
end % speed_tuning
