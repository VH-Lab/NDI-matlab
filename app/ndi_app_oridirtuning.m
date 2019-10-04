classdef ndi_app_oridirtuning < ndi_app

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_oridirtuning_obj = ndi_app_oridirtuning(varargin)
			% NDI_APP_ORIDIRTUNING - an app to calculate and analyze orientation/direction tuning curves
			%
			% NDI_APP_ORIDIRTUNING_OBJ = NDI_APP_ORIDIRTUNING(EXPERIMENT)
			%
			% Creates a new NDI_APP_ORIDIRTUNING object that can operate on
			% NDI_EXPERIMENTS. The app is named 'ndi_app_oridirtuning'.
			%
				experiment = [];
				name = 'ndi_app_oridirtuning';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				ndi_app_oridirtuning_obj = ndi_app_oridirtuning_obj@ndi_app(experiment, name);

		end % ndi_app_oridirtuning() creator


		function tuning_doc = calculate_tuning_curve(ndi_app_oridirtuning_obj, ndi_thing_obj, varargin)
			% CALCULATE_TUNING_CURVE - calculate an orientation/direction tuning curve from stimulus responses
			%
			% TUNING_DOC = CALCULATE_TUNING_CURVE(NDI_APP_ORIDIRTUNING_OBJ, NDI_THING)
			%
			% 
				tuning_doc = {};

				E = ndi_app_oridirtuning_obj.experiment;
				rapp = ndi_app_tuning_response(E);

				q_rthing = ndi_query('thingreference.thing_unique_id','exact_string',ndi_thing_obj.doc_unique_id(),'');
				q_rdoc = ndi_query('','isa','ndi_document_stimulus_response_scalar.json','');
				rdoc = E.database_search(q_rdoc&q_rthing);

				for r=1:numel(rdoc),
					if is_oridir_stimulus_response(ndi_app_oridirtuning_obj, rdoc{r}),
						independent_parameter = {'angle'};
						independent_label = {'direction'};
						constraint = struct('field','sFrequency','operation','hasfield','param1','','param2','');
						tuning_doc{end+1} = rapp.tuning_curve(rdoc{r},'independent_parameter',independent_parameter,...
							'independent_label',independent_label,'constraint',constraint);
					end;
				end;

		end; % calculate_tuning_curve()

		function oriprops = calculate_all_oridir_indexes(ndi_app_oridirtuning_obj, ndi_thing_obj);
			% 
			%
				E = ndi_app_oridirtuning_obj.experiment;
				rapp = ndi_app_tuning_response(E);

				q_rthing = ndi_query('thingreference.thing_unique_id','exact_string',ndi_thing_obj.doc_unique_id(),'');
				q_rdoc = ndi_query('','isa','ndi_document_stimulus_response_scalar.json','');
				rdoc = E.database_search(q_rdoc&q_rthing);

				for r=1:numel(rdoc),
					if is_oridir_stimulus_response(ndi_app_oridirtuning_obj, rdoc{r}),
						% find the tuning curve doc


					end;
				end;

		end; % calculate_all_oridir_indexes()

		function oriprops = calculate_oridir_indexes(ndi_app_oridirtuning_obj, tuning_doc)
			% CALCULATE_ORIDIR_INDEXES 
			%
			%
			%
				ind = {};
				control_ind = {};
				for i=1:numel(tuning_doc.document_properties.individual_responses_real),
					ind{i} = tuning_doc.document_properties.individual_responses_real{i} + ...
						sqrt(-1)*tuning_doc.document_properties.individual_responses_imaginary{i};
					control_ind{i} = tuning_doc.document_properties.control_individual_responses_real{i} + ...
						sqrt(-1)*tuning_doc.document_properties.control_individual_responses_imaginary{i};
				end;

				[anova_across_stims, anova_across_stims_blank] = neural_response_significance(struct('ind',ind,'blankind',control_ind{1}));

				


		end; % calculate_oridir_indexes()

		function b = is_oridir_stimulus_response(ndi_app_oridirtuning_obj, response_doc)
			%
				E = ndi_app_oridirtuning_obj.experiment;
					% does this stimulus vary in orientation or direction tuning?
				stim_pres_doc = E.database_search(ndi_query('ndi_document.document_unique_reference', 'exact_string',...
					response_doc.document_properties.stimulus_response.stimulus_presentation_document_identifier,''));
				if isempty(stim_pres_doc),
					error(['empty stimulus response doc, do not know what to do.']);
				end;
				stim_props = {stim_pres_doc{1}.document_properties.stimuli.parameters};
				% need to make this more general TODO
				included = [];
				for n=1:numel(stim_props),
					if ~isfield(stim_props{n},'isblank'),
						included(end+1) = n;
					elseif ~stim_props{n}.isblank,
						included(end+1) = n;
					end;
				end;
				desc = structwhatvaries(stim_props(included));
				b = eqlen(desc,{'angle'});
		end; % is_oridir_stimulus_response

	end; % methods

	methods (Static),
		

	end; % static methods

end % ndi_app_oridirtuning


