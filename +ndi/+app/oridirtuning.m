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
					{'apps/vision/oridir/orientation_direction_tuning',...
                    'stimulus/tuning_curve'},...
					session);
                
		end % ndi.app.oridirtuning() creator

		function tuning_doc = calculate_tuning_curve(ndi_app_oridirtuning_obj, ndi_element_obj)

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

		function oriprops = calculate_all_oridir_indexes(ndi_app_oridirtuning_obj, ndi_element_obj, docexistsaction);

			% 
			%
				oriprops = {};
				E = ndi_app_oridirtuning_obj.session;
                
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
							appdoc_struct.tuning_doc_id = tdoc{t}.id();
							% call add_appdoc with the 
							%oriprops{end+1} = calculate_oridir_indexes(ndi_app_oridirtuning_obj, tdoc{t});
							oriprops{end+1} = ndi_app_oridirtuning_obj.add_appdoc('orientation_direction_tuning',appdoc_struct,docexistsaction,tdoc{t});
						end;
					end;
				end;

		end; % calculate_all_oridir_indexes()

		function oriprops = calculate_oridir_indexes(ndi_app_oridirtuning_obj, tuning_doc, do_add)
			% CALCULATE_ORIDIR_INDEXES 
			%
			%
			%
				if nargin < 3,
					do_add = 1;
				end;
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

				if do_add == 1,
					E.database_add(oriprops);
				end;

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
		end; % is_oridir_stimulus_response()

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

		%%% functions that override ndi_app_appdoc  %%
        
		function doc = struct2doc(ndi_app_oridirtuning_obj, appdoc_type, appdoc_struct, varargin)
			% STRUCT2DOC - create an ndi.document from an input structure and input parameters
			%
			% DOC = STRUCT2DOC(NDI_APP_ORIDIRTUNING_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
			%
			% For ndi_app_oridirtuning, one can use an APPDOC_TYPE of the following:
			% APPDOC_TYPE                   | Description
			% ----------------------------------------------------------------------------------------------
			% 'orientation_tuning_direction'| A document that describes the parameters to be used for 
			%                               | orientation tuning direction 
			% 
			% See APPDOC_DESCRIPTION for a list of the parameters.
			% 
                if strcmpi(appdoc_type,'orientation_direction_tuning'),
                   tuning_doc_id = appdoc_struct.tuning_doc_id;
                   td = ndi_app_oridirtuning_obj.session.database_search(ndi.query('ndi_document.id','exact_string',tuning_doc_id,''));
                   if numel(td)==1, 
                       td = td{1};
                   elseif numel(td)>1,
                       error(['Too many tuning documents.']); % should not happen
                   elseif numel(td)==0,
                       error(['No tuning doc with id ' tuning_doc_id '.']);
                   end;
                   doc = ndi_app_oridirtuning_obj.calculate_oridir_indexes(td, 0);            
                elseif strcmpi(appdoc_type,'tuning_curve'),
                    tuning_curve_doc = appdoc_struct.tuning_curve_doc;
                    doc = ndi_app_oridirtuning_obj.calculate_oridir_indexes(tuning_curve_doc, 0);
                else
					error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
                end;
		end; %struct2doc()

		function doc = find_appdoc(ndi_app_oridirtuning_obj, appdoc_type, varargin)
			% FIND_APPDOC - find an ndi_app_appdoc document in the session database
			%
			% See ndi_app_oridirtuning/APPDOC_DESCRIPTION for documentation.
			%
				doc = {};
            
				switch(lower(appdoc_type))
					case 'orientation_direction_tuning'
						q = ndi.query('','isa','orientation_direction_tuning', '');
						if numel(varargin)>=1,
							tuning_doc=varargin{1};
							if ~isempty(tuning_doc),
								q = q&ndi.query('','depends_on','stimulus_tuningcurve_id',tuning_doc.id());
							end;
						end;
						if numel(varargin)>=2,
							element_id = varargin{2};
							if ~isempty(element_id),
								q = q&ndi.query('','depends_on','element_id',element_id);
							end;
						end;
						doc = ndi_app_oridirtuning_obj.session.database_search(q);
                    
                    case 'tuning_curve'
						q = ndi.query('','isa','stimulus_tuningcurve', '');
                        q = 
						if numel(varargin)>=1,
							tuning_doc=varargin{1};
								q = q&ndi.query('','depends_on','element_id',element.id());
                        end;
						doc = ndi_app_oridirtuning_obj.session.database_search(q);
                        
					otherwise,
						error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
                        
				end %switch
		end % find_appdoc()
        
		function appdoc_struct = doc2struct(ndi_app_oridirtuning_obj, appdoc_type, doc)
			% DOC2STRUCT - create an ndi.document from an input structure and input parameters
			%
			% DOC = STRUCT2DOC(NDI_APPDOC_OBJ, SESSION, APPDOC_TYPE, APPDOC_STRUCT, [additional parameters]
			%
			% Create an ndi.document from a data structure APPDOC_STRUCT. The ndi.document is created
			% according to the APPDOC_TYPE of the NDI_APPDOC_OBJ.
			%
			% In the base class, this uses the property info in the ndi.document to load the data structure.
			%
				if strcmpi(appdoc_type,'orientation_direction_tuning'),
					appdoc_struct.tuning_doc_id = doc.dependency_value('stimulus_tuningcurve_id');
                elseif strcmpi(appdoc_type,'tuning_curve'),
            		appdoc_struct.tuning_curve_doc = doc;
                end;
		end; % doc2struct()
        
	end; % methods
    
	methods (Static),
		

	end; % static methods

end % ndi.app.oridirtuning


