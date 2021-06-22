classdef oridirtuning < ndi.app & ndi.app.appdoc

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_oridirtuning_obj = oridirtuning(varargin)
			% ndi.app.oridirtuning - an app to calculate and analyze orientation/direction tuning curves
			%
			% NDI_APP_ORIDIRTUNING_OBJ = ndi.app.oridirtuning(SESSION)
			%
			% Creates a new ndi.app.oridirtuning object that can operate on
			% NDI_SESSIONS. The app is named 'ndi.app.oridirtuning'.
			%
				session = [];
				name = 'ndi_app_oridirtuning';
				if numel(varargin)>0,
					session = varargin{1};
				end
				ndi_app_oridirtuning_obj = ndi_app_oridirtuning_obj@ndi.app(session, name);
                ndi_app_oridirtuning_obj = ndi_app_oridirtuning_obj@ndi.app.appdoc(...
					{'orientation_direction_tuning'},...
					{'vision/oridir/orientation_direction_tuning'},...
					session);
                
		end % ndi.app.oridirtuning() creator

		function tuning_doc = calculate_tuning_curve(ndi_app_oridirtuning_obj, ndi_element_obj, varargin)
			% CALCULATE_TUNING_CURVE - calculate an orientation/direction tuning curve from stimulus responses
			%
			% TUNING_DOC = CALCULATE_TUNING_CURVE(NDI_APP_ORIDIRTUNING_OBJ, ndi.element)
			%
			% 
				tuning_doc = {};

				E = ndi_app_oridirtuning_obj.session;
				rapp = ndi.app.stimulus.tuning_response(E);

				q_relement = ndi.query('depends_on','depends_on','element_id',ndi_element_obj.id());
				q_rdoc = ndi.query('','isa','stimulus_response_scalar.json','');
				rdoc = E.database_search(q_rdoc&q_relement)

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

		function oriprops = calculate_all_oridir_indexes(ndi_app_oridirtuning_obj, ndi_element_obj);
			% 
			%
				oriprops = {};
				E = ndi_app_oridirtuning_obj.session;
				rapp = ndi.app.stimulus.tuning_response(E);

				q_relement = ndi.query('depends_on','depends_on','element_id',ndi_element_obj.id());
				q_rdoc = ndi.query('','isa','stimulus_response_scalar.json','');
				rdoc = E.database_search(q_rdoc&q_relement);


				for r=1:numel(rdoc),
					if is_oridir_stimulus_response(ndi_app_oridirtuning_obj, rdoc{r}),
						% find the tuning curve doc
						q_tdoc = ndi.query('','isa','stimulus_tuningcurve.json','');
						q_tdocrdoc = ndi.query('','depends_on','stimulus_response_scalar_id',rdoc{r}.id());
						tdoc = E.database_search(q_tdoc&q_tdocrdoc&q_relement);
						for t=1:numel(tdoc),
							oriprops{end+1} = calculate_oridir_indexes(ndi_app_oridirtuning_obj, tdoc{t});
						end;
					end;
				end;

		end; % calculate_all_oridir_indexes()

		function oriprops = calculate_oridir_indexes(ndi_app_oridirtuning_obj, tuning_doc)
			% CALCULATE_ORIDIR_INDEXES 
			%
			%
			%
				E = ndi_app_oridirtuning_obj.session;
				tapp = ndi.app.stimulus.tuning_response(E);
				ind = {};
				ind_real = {};
				control_ind = {};
				control_ind_real = {};
				response_ind = {};
				response_mean = [];
				response_stddev = [];
				response_stderr = [];

				stim_response_doc = E.database_search(ndi.query('ndi_document.id','exact_string',tuning_doc.dependency_value('stimulus_response_scalar_id'),''));

				if isempty(stim_response_doc),
					error(['cannot find stimulus response document. Do not know what to do.']);
				end;

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

				vi = vlt.neuro.vision.oridir.index.oridir_vectorindexes(response);
				fi = vlt.neuro.vision.oridir.index.oridir_fitindexes(response);

				properties.coordinates = 'compass';
				properties.response_units = tuning_doc.document_properties.tuning_curve.response_units;
				properties.response_type = stim_response_doc{1}.document_properties.stimulus_response_scalar.response_type;

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

				oriprops = ndi.document('vision/oridir/orientation_direction_tuning', ...
					'orientation_direction_tuning', vlt.data.var2struct('properties', 'tuning_curve', 'significance', 'vector', 'fit')) + ...
						ndi_app_oridirtuning_obj.newdocument();
				oriprops = oriprops.set_dependency_value('element_id', stim_response_doc{1}.dependency_value('element_id'));
				oriprops = oriprops.set_dependency_value('stimulus_tuningcurve_id', tuning_doc.id());

				E.database_add(oriprops);

				figure;
				ndi_app_oridirtuning_obj.plot_oridir_response(oriprops);

		end; % calculate_oridir_indexes()

		function b = is_oridir_stimulus_response(ndi_app_oridirtuning_obj, response_doc)
			%
				E = ndi_app_oridirtuning_obj.session;
					% does this stimulus vary in orientation or direction tuning?
				stim_pres_doc = E.database_search(ndi.query('ndi_document.id', 'exact_string', dependency_value(response_doc, 'stimulus_presentation_id'),''));
				if isempty(stim_pres_doc),
					error(['empty stimulus response doc, do not know what to do.']);
				end;
				stim_props = {stim_pres_doc{1}.document_properties.stimulus_presentation.stimuli.parameters};
				% need to make this more general TODO
				included = [];
				for n=1:numel(stim_props),
					if ~isfield(stim_props{n},'isblank'),
						included(end+1) = n;
					elseif ~stim_props{n}.isblank,
						included(end+1) = n;
					end;
				end;
				desc = vlt.data.structwhatvaries(stim_props(included));
				b = vlt.data.eqlen(desc,{'angle'});
		end; % is_oridir_stimulus_response

		function plot_oridir_response(ndi_app_oridirtuning_obj, oriprops_doc)

				E = ndi_app_oridirtuning_obj.session;

				h = vlt.plot.myerrorbar(oriprops_doc.document_properties.orientation_direction_tuning.tuning_curve.direction, ...
					oriprops_doc.document_properties.orientation_direction_tuning.tuning_curve.mean, ...
					oriprops_doc.document_properties.orientation_direction_tuning.tuning_curve.stderr, ...
					oriprops_doc.document_properties.orientation_direction_tuning.tuning_curve.stderr);

				delete(h(2));
				set(h(1),'color',[0 0 0]);

				hold on;
				baseline_h = plot([0 360],[0 0],'k--');
				fitline_h = plot(oriprops_doc.document_properties.orientation_direction_tuning.fit.double_gaussian_fit_angles,...
					oriprops_doc.document_properties.orientation_direction_tuning.fit.double_gaussian_fit_values,'k-');
				box off;

				element_doc = E.database_search(ndi.query('ndi_document.id','exact_string',dependency_value(oriprops_doc,'element_id'),'')); 
				if isempty(element_doc),
					error(['Empty element document, don''t know what to do.']);
				end;
				element = ndi.database.fun.ndi_document2ndi_object(element_doc{1}, E);
				xlabel('Direction (\circ)');
				ylabel(oriprops_doc.document_properties.orientation_direction_tuning.properties.response_units);
				title([element.elementstring() '.' element.type '; ' oriprops_doc.document_properties.orientation_direction_tuning.properties.response_type]);

		end; % plot_oridir_response

    % functions that override ndi_app_appdoc

        function doc = add_appdoc(ndi_app_oridirtuning_obj, appdoc_type, appdoc_struct, docexistsaction, varargin)
			% ADD_APPDOC - Load data from an application document
			%
			% [...] = ADD_APPDOC(NDI_APPDOC_OBJ, APPDOC_TYPE, ...
			%     APPDOC_STRUCT, DOCEXISTSACTION, [additional arguments])
			%
			% Creates a new ndi.document that is based on the type APPDOC_TYPE with creation data
			% specified by APPDOC_STRUCT.  [additional inputs] are used to find or specify the
			% NDI_document in the database. They are passed to the function FIND_APPDOC,
			% so see help FIND_APPDOC for the documentation for each app.
			%
			% The DOC is returned as a cell array of NDI_DOCUMENTs (should have 1 entry but could have more than
			% 1 if the document already exists).
			%
			% If APPDOC_STRUCT is empty, then default values are used. If it is a character array, then it is
			% assumed to be a filename of a tab-separated-value text file. If it is an ndi.document, then it
			% is assumed to be an ndi.document and it will be converted to the parameters using DOC2STRUCT.
			%
			% This function also takes a string DOCEXISTSACTION that describes what it should do
			% in the event that the document fitting the [additional inputs] already exists:
			% DOCEXISTACTION value      | Description
			% ----------------------------------------------------------------------------------
			% 'Error'                   | An error is generating indicating the document exists.
			% 'NoAction'                | The existing document is left alone. The existing ndi.document
			%                           |    is returned in DOC.
			% 'Replace'                 | Replace the document; note that this deletes all NDI_DOCUMENTS
			%                           |    that depend on the original.
			% 'ReplaceIfDifferent'      | Conditionally replace the document, but only if the 
			%                           |    the data structures that define the document are not equal.
			% 
			%

				% Step 1, load the appdoc_struct if it is not already a structure

				if isempty(appdoc_struct),
					appdoc_struct = ndi_app_appdoc_obj.defaultstruct_appdoc(appdoc_type);
				elseif isa(appdoc_struct,'ndi.document'),
					appdoc_struct = ndi_app_appdoc_obj.doc2struct(appdoc_type,appdoc_struct);
				elseif isa(appdoc_struct,'char'),
					try,
						appdoc_struct = vlt.file.loadStructArray(appdoc_strut);
					catch,
						error(['APPDOC_STRUCT was a character array, so it was assumed to be a file.' ...
								' But file reading failed with error ' lasterr '.']);
					end;
				elseif isstruct(appdoc_struct),
					% we are happy, nothing to do
				else,
					error(['Do not know how to process APPDOC_STRUCT as provided.']);
				end;

				% Step 2, see if a document by this description already exists

				doc = ndi_app_appdoc_obj.find_appdoc(appdoc_type, varargin{:});

				if ~isempty(doc),
					switch (lower(docexistsaction)),
						case 'error',
							error([int2str(numel(doc)) ' document(s) of application document type '...
								appdoc_type ' already exist.']);
						case 'noaction',
							return; % we are done
						case {'replace','replaceifdifferent'},
							aredifferent = 1; % by default, we will replace unless told to check
							if strcmpi(docexistsaction,'ReplaceIfDifferent'),
								% see if they really are different
								if numel(doc)>1, % there are multiple versions, must be different
									aredifferent = 1;
								else,
									appdoc_struct_here = ndi_app_appdoc_obj.doc2struct(appdoc_type, doc{1});
									b = ndi_app_appdoc_obj.isequal_appdoc_struct(appdoc_type, appdoc_struct, ...
										appdoc_struct_here);
									aredifferent = ~b;
								end;
							end;
							if aredifferent,
								b = ndi_app_appdoc_obj.clear_appdoc(appdoc_type, varargin{:});
								if ~b,
									error(['Could not delete existing ' appdoc_type ' document(s).']);
								end;
							else,
								return; % nothing to do, it's already there and the same as we wanted
							end;
						otherwise,
							error(['Unknown DOCEXISTSACTION: ' docexistsaction '.']);
					end; % switch(docexistsaction)
				end;

				% if we haven't returned, we need to make a document and add it

				doc = ndi_app_appdoc_obj.struct2doc(appdoc_type,appdoc_struct,varargin{:});

				ndi_app_appdoc_obj.doc_session.database_add(doc);

				doc = {doc}; % make it a cell array

		end; % add_appdoc
        
        function doc = struct2doc(ndi_app_oridirtuning_obj, appdoc_type, appdoc_struct, varargin)
			% STRUCT2DOC - create an ndi.document from an input structure and input parameters
			%
			% DOC = STRUCT2DOC(NDI_APP_ORIDIRTUNING_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
			%
			% For ndi.app.oridirtuning, one can use an APPDOC_TYPE of the following:
			% APPDOC_TYPE                 | Description
			% ----------------------------------------------------------------------------------------------
			% 'orientation_tuning_direction'  | A document that describes
            %                                 | the parameters to be used for extraction for a single epoch 
			% 
			%
			% See APPDOC_DESCRIPTION for a list of the parameters.
			% 

%               if strcmpi(appdoc_type,'orientation_direction_tuning'),
% 					if numel(varargin)<1,
% 						error(['Needs an additional argument describing the sorting parameters name']);
% 					end;
%     					if ~ischar(varargin{1}),
%     						error(['sorting parameters name must be a character string.']);
%     					end;
%     					oridirtun_name = varargin{1};
%     					doc = ndi.document('vision/oridir/orientation_tuning_direction',...
%     						'orientation_direction_tuning',appdoc_struct) + ...
%     						ndi_app_oridirtuning_obj.newdocument() + ...
%     						ndi.document('ndi_document','ndi_document.name',oridirtun_name);
% 				else
% 					error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
% 				end;
       	end; %struct2doc()

    % functions that override ndi_app


    end; % methods
    
	methods (Static),
		

	end; % static methods

end % ndi.app.oridirtuning


