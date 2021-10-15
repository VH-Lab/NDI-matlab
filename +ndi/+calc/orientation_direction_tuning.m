classdef orientation_direction_tuning < ndi.calculation

	methods

		function orientation_direction_tuning_obj = orientation_direction_tuning(session)
			% ORIENTATION_DIRECTION_TUNING - ndi.calculation object that
			% calculates orientation and direction tuning curves from spike
			% elements
			%
			% ORIENTATION_DIRECTION_TUNING_OBJ = ORIENTATION_DIRECTION_TUNING(SESSION)
			%
			% Creates a orientation_direction_tuning ndi.calculation object
			%
				ndi.globals;
				orientation_direction_tuning_obj = orientation_direction_tuning_obj@ndi.calculation(session,'orientation_direction_index',...
					fullfile(ndi_globals.path.documentpath,'apps','calculations','orientation_direction_index.json'));
		end; % orientation_direction_tuning() creator

		function doc = calculate(ndi_calculation_obj, parameters)
			% CALCULATE - perform the calculation for ndi.calc.orientation_direction_tuning
			%
			% DOC = CALCULATE(NDI_CALCULATION_OBJ, PARAMETERS)
			%
			% Creates a orientation_direction_tuning_calc document given input parameters.
			% Check inputs
				if ~isfield(parameters,'tuning_doc'), 
                    error(['parameters structure lacks ''tuning_doc.''']); 
                else,
                    tuning_doc = parameters{1};
                end;
				if ~isfield(parameters,'depends_on'), 
                    error(['parameters structure lacks ''stimulus_tuningcurve_id.''']); 
                else,
                    id = parameters{2};
                end;
				
            % Calculate orientation and direction indexes from stimulus responses
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
                
			%%%	stim_response_doc = E.database_search(ndi.query('ndi_document.id','exact_string',tuning_doc.dependency_value('stimulus_response_scalar_id'),''));

				% grr..if the elements are all the same size, Matlab will make individual_response_real, etc, a matrix instead of cell
				tuning_doc = tapp.tuningdoc_fixcellarrays(tuning_doc);

				for i=1:numel(tuning_doc.document_properties.tuning_curve.individual_responses_real),
					ind{i} = tuning_doc.document_properties.tuning_curve.individual_responses_real{i} + ...
						sqrt(-1)*tuning_doc.document_properties.tuning_curve.individual_responses_imaginary{i};
					ind_real{i} = ind{i};
					if any(~isreal(ind_real{i})), ind_real{i} = abs(ind_real{i}); end;
					control_ind{i} = tuning_doc.document_properties.tuning_curve.control_individual_responses_real{i} + ...
						sqrt(-1)*tuning_doc.document_properties.tuning_curve.control_individual_responses_imaginary{i};
					control_ind_real{i} = control_ind{i};
					if any(~isreal(control_ind_real{i})), control_ind_real{i} = abs(control_ind_real{i}); end;
					response_ind{i} = ind{i} - control_ind{i};
					response_mean(i) = nanmean(response_ind{i});
					if ~isreal(response_mean(i)), response_mean(i) = abs(response_mean(i)); end;
					response_stddev(i) = nanstd(response_ind{i});
					response_stderr(i) = vlt.data.nanstderr(response_ind{i});
					if any(~isreal(response_ind{i})),
						response_ind{i} = abs(response_ind{i});
					end;
				end;

				resp.ind = ind_real;
				resp.blankind = control_ind_real{1};
				[anova_across_stims, anova_across_stims_blank] = neural_response_significance(resp);

				response.curve = ...
					[ tuning_doc.document_properties.tuning_curve.independent_variable_value(:)' ; ...
						response_mean ; ...
						response_stddev ; ...
						response_stderr; ];
				response.ind = response_ind;

				vi = vlt.neuro.vision.oridir.index.orientation_direction_tuning_vectorindexes(response);
				fi = vlt.neuro.vision.oridir.index.orientation_direction_tuning_fitindexes(response);

				properties.coordinates = 'compass';
				properties.response_units = tuning_doc.document_properties.tuning_curve.response_units;
			%%%	properties.response_type = stim_response_doc{1}.document_properties.stimulus_response_scalar.response_type;

				tuning_curve = struct('direction', vlt.data.rowvec(tuning_doc.document_properties.tuning_curve.independent_variable_value), ...
					'mean', response_mean, ...
					'stddev', response_stddev, ...
					'stderr', response_stderr, ...
					'individual', {response_ind}, ...
					'raw_individual', {ind_real}, ...
					'control_individual', {control_ind_real});

				significance = struct('visual_response_anova_p',anova_across_stims_blank,'across_stimuli_anova_p', anova_across_stims);

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

                % Store calculation in document
                orientation_direction_tuning = ndi.document('vision/orientation_direction_tuning/orientation_direction_tuning', ...
					'orientation_direction_tuning', vlt.data.var2struct('properties', 'tuning_curve', 'significance', 'vector', 'fit')) + ...
						ndi_app_orientation_direction_tuningtuning_obj.newdocument();
				orientation_direction_tuning = orientation_direction_tuning.set_dependency_value('stimulus_tuningcurve_id', tuning_doc.id());
                 
                orientation_direction_tuning = parameters;
			%%%	orientation_direction_tuning.answer = parameters.input_parameters.answer;
				doc = ndi.document(ndi_calculation_obj.doc_document_types{1},'orientation_direction_tuning',orientation_direction_tuning);
				for i=1:numel(parameters.depends_on),
					doc = doc.set_dependency_value(parameters.depends_on(i).name,parameters.depends_on(i).value);
				end;
                
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
            
            if numel(varargin)>=1,
                tuning_doc=varargin{1};
                if ~isempty(tuning_doc),
                    parameters.input_parameters = struct('stimulus_tuningcurve_id',q);
                    parameters.depends_on = vlt.data.emptystruct('stimulus_tuningcurve_id','value');
                    parameters.query = struct('name','stimulus_tuningcurve_id','query',ndi.query('','depends_on','stimulus_tuningcurve_id',tuning_doc.id());
                end;
            end;
                        
		end; % default_search_for_input_parameters

		function doc_about(ndi_calculation_obj)
			% ----------------------------------------------------------------------------------------------
			% NDI_CALCULATION: ORIENTATION_DIRECTION_TUNING_CALC
			% ----------------------------------------------------------------------------------------------
			%
			%   ----------------------------------------------
			%   | ORIENTATION_DIRECTION_TUNING_CALC -- ABOUT |
			%   ----------------------------------------------
			%
			%   ORIENTATION_DIRECTION_TUNING_CALC is an ndi.calculation object that calculates the orientation and direction tuning
			%   curves from spike elements.
            %   
			%   Each  document 'depends_on' an NDI daq system.
			%
			%   Definition: stimulus/vision/oridir/orientation_direction_tuning.json
			%
				eval(['help ndi.calc.orientation_direction_tuning.doc_about']);
		end; %doc_about()
	end; % methods()
			
end % orientation_direction_tuning
