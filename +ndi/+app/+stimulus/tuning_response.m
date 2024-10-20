classdef tuning_response < ndi.app

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_tuning_response_obj = tuning_response(varargin)
			% ndi.app.stimulus.tuning_response - an app to decode stimulus information from NDI_PROBE_STIMULUS objects
			%
			% NDI_APP_TUNING_RESPONSE_OBJ = ndi.app.stimulus.tuning_response(SESSION)
			%
			% Creates a new ndi.app.stimulus.tuning_response object that can operate on
			% NDI_SESSIONS. The app is named 'ndi_app_stimulus_response'.
			%
				session = [];
				name = 'ndi_app_tuning_response';
				if numel(varargin)>0,
					session = varargin{1};
				end
				ndi_app_tuning_response_obj = ndi_app_tuning_response_obj@ndi.app(session, name);

		end % ndi.app.stimulus.tuning_response() creator

		function rdocs = stimulus_responses(ndi_app_tuning_response_obj, ndi_element_stim, ndi_timeseries_obj, reset, do_mean_only)
			% STIMULUS_RESPONSES - write stimulus records for all stimulus epochs of an ndi.element stimulus object
			%
			% [RDOCS] = STIMULUS_RESPONSES(NDI_APP_TUNING_RESPONSE_OBJ, NDI_ELEMENT_STIM, NDI_TIMESERIES_OBJ, [RESET], DO_MEAN_ONLY)
			%
			% Examines a the ndi.session associated with NDI_APP_TUNING_RESPONSE_OBJ and the stimulus
			% probe NDI_STIM_PROBE, and creates documents of type STIMULUS/STIMULUS_RESPONSE_SCALAR for all
			% stimulus epochs.
			% (NDI2: docs say it creates  and STIMULUS/STIMULUS_TUNINGCURVE but it does not seem to do that)
			%
			% If STIMULUS_PRESENTATION and STIMULUS_TUNINGCURVE documents already exist for a given
			% stimulus run, then they are returned in EXISTINGDOCS. Any new documents are returned in NEWDOCS.
			%
			% If the input argument RESET is given and is 1, then all existing tuning curve documents for this
			% NDI_TIMESERIES_OBJ are removed. The default for RESET is 0 (if it is not provided).
			%
			% If the input argument DO_MEAN_ONLY is given and is 1, then the function only computes the mean responses.
			% No F1 or F2 responses will be calculated.
			%
			%
			% Note that this function DOES add the new documents RDOCS to the database.
			%
				rdocs = {};
				if nargin<4, 
					reset = 0;
				end;
				if nargin<5,
					do_mean_only = 0;
				end;
				
				E = ndi_app_tuning_response_obj.session;

				ndi_decoder = ndi.app.stimulus.decoder(ndi_app_tuning_response_obj.session);

				% find all stimulus records from the stimulus element
				sq_nditimeseries = ndi.query('','depends_on','element_id',ndi_timeseries_obj.id());
				sq_stimelement = ndi.query('','depends_on','stimulus_element_id',ndi_element_stim.id()); 
				sq_stimelement2 = ndi.query('','depends_on','stimulator_id',ndi_element_stim.id()); 
				sq_e = ndi.query(E.searchquery());
				sq_stim = ndi.query('','isa','stimulus_presentation',''); % presentation
				sq_resp = ndi.query('','isa','stimulus_response_scalar','');
				doc_stim = E.database_search(sq_stim&sq_e&sq_stimelement);
				doc_resp = E.database_search(sq_resp&sq_e&sq_stimelement2&sq_nditimeseries);

				if reset,
					doc_p = {};
					for i=1:numel(doc_resp),
						% delete stimulus response parameters documents too
						stim_response_scalar_p = doc_resp{i}.dependency_value('stimulus_response_scalar_parameters_id');
						doc_here = E.database_search(ndi.query('base.id','exact_string',stim_response_scalar_p,''));
						doc_p = cat(2,doc_p,doc_here);
					end;
					E.database_rm(doc_resp);
					E.database_rm(doc_p);
				end;

				ndi_ts_epochs = {};

				% find all the epochs of overlap between stimulus element and ndi_timeseries_obj

				for i=1:numel(doc_stim),
					presentation_time = ndi_decoder.load_presentation_time(doc_stim{i});
					%disp(['Working on doc ' int2str(i) ' of ' int2str(numel(doc_stim)) '.']);
					% ASSUMPTION: each stimulus element epoch will overlap a single ndi_timeseries_obj epoch
					%   therefore, we can use the first stimulus as a proxy for them all
					if numel(presentation_time)>0, % make sure there is at least 1 stimulus 
						stim_timeref = ndi.time.timereference(ndi_element_stim, ...
							ndi.time.clocktype(presentation_time(1).clocktype), ...
							doc_stim{i}.document_properties.epochid.epochid, ...
							presentation_time(1).onset);
						[ts_epoch_t0_out, ts_epoch_timeref, msg] = E.syncgraph.time_convert(stim_timeref,...
							0, ndi_timeseries_obj, ndi.time.clocktype('dev_local_time'));
							% time is 0 because stim_timeref is relative to 1st stim
						if ~isempty(ts_epoch_t0_out),
							ndi_ts_epochs{i} = ts_epoch_timeref.epoch;
						else,
							ndi_ts_epochs{i} = '';
						end;
					end;
				end;

				if do_mean_only == 1,
					freq_response = 0;
				else,
					freq_response = [];
				end;

				for i=1:numel(doc_stim),
					if ~isempty(ndi_ts_epochs{i}),
						ctrl_search = ndi.query('','depends_on', 'stimulus_presentation_id', doc_stim{i}.id()) & ...
							ndi.query('','isa','control_stimulus_ids','');
						control_stim_doc = E.database_search(ctrl_search);
						for j=1:numel(control_stim_doc)
							presentation_time = ndi_decoder.load_presentation_time(doc_stim{i});
							% okay, now how to analyze these stims?
							% 
							% want to calculate F0, F1, F2
							% want to do this for regularly sampled and timestamp type data
							if 0,
								ndi_ts_epochs{i}
								doc_stim{i}.document_properties
								doc_stim{i}.document_properties.stimulus_presentation.stimuli(1).parameters
								doc_stim{i}.document_properties.stimulus_presentation.presentation_order
								presentation_time
								control_stim_doc{j}.document_properties.control_stimulus_ids
								control_stim_doc{j}.document_properties.control_stimulus_ids.control_stimulus_ids
							end;
							rdocs{end+1} = ndi_app_tuning_response_obj.compute_stimulus_response_scalar(ndi_element_stim, ...
								ndi_timeseries_obj, doc_stim{i}, control_stim_doc{j},'freq_response',freq_response);
						end;

					end
				end
		end % 

		function response_doc = compute_stimulus_response_scalar(ndi_app_tuning_response_obj, ndi_stim_obj, ndi_timeseries_obj, stim_doc, control_doc, varargin)
			% COMPUTE_STIMULUS_RESPONSES - compute responses to a stimulus set
			%
			% RESPONSE_DOC = COMPUTE_STIMULUS_RESPONSE_SCALAR(NDI_APP_TUNING_RESPONSE_OBJ, NDI_TIMESERIES_OBJ, STIM_DOC, ...)
			%
			% Given an NDI_TIMESERIES_OBJ, a STIM_DOC (an ndi.document of class 'stimulus_presentation'), and a
			% CONTROL_DOC (an ndi.document of class 'control_stimulus_ids'), this
			% function computes the stimulus responses of NDI_TIMESERIES_OBJ and stores the results as an
			% ndi.document of class 'stimulus_response_scalar'. In this app, by default, mean responses and responses at the
			% fundamental stimulus frequency are calculated. Note that this function may generate multiple documents (for mean responses,
			% F1, F2).
			%
			% Note that we recommend making a new app subclass if one wants to write additional classes of analysis procedures.
			%
			% This function also takes name/value pairs that alter the behavior:
			% Parameter (default)                  | Description
			% ---------------------------------------------------------------------------------
			% temporalfreqfunc                     |
			%   ('ndi.fun.stimulustemporalfrequency')  |
			% freq_response ([])                   | Frequency response to measure. If empty, then the function is 
			%                                      |   called 3 times with values 0, 1, and 2 times the fundamental frequency.
			% prestimulus_time ([])                | Calculate a baseline using a certain amount of TIMESERIES signal during
                        %                                      |     the pre-stimulus time given here
			% prestimulus_normalization ([])       | Normalize the stimulus response based on the prestimulus measurement.
			%                                      | [] or 0) No normalization
			%                                      |       1) Subtract: Response := Response - PrestimResponse
			%                                      |       2) Fractional change Response:= ((Response-PrestimResponse)/PrestimResponse)
			%                                      |       3) Divide: Response:= Response ./ PreStimResponse
			% isspike (0)                          | 0/1 Is the signal a spike process? If so, timestamps correspond to spike events.
			% spiketrain_dt (0.001)                | Resolution to use for spike train reconstruction if computing Fourier transform
			%
				ndi_decoder = ndi.app.stimulus.decoder(ndi_app_tuning_response_obj.session);
				temporalfreqfunc = 'ndi.fun.stimulustemporalfrequency';
				freq_response = [];
				prestimulus_time = [];
				prestimulus_normalization = [];
				isspike = 0;
				spiketrain_dt = 0.001;

				if ~isempty(intersect(fieldnames(ndi_timeseries_obj),'type')),
					if strcmpi(ndi_timeseries_obj.type,'spikes'),
						isspike = 1;
					end;
				end;

				vlt.data.assign(varargin{:});

				response_doc = {};

				E = ndi_app_tuning_response_obj.session;
				gapp = ndi.app.markgarbage(E);
				if isempty(freq_response),
					% do we have any stims that we know have a fundamental stimulus frequency?
					gotone = 0;
					for j=1:numel(stim_doc.document_properties.stimulus_presentation.stimuli),
						eval(['freq_multi_here = ' temporalfreqfunc '(stim_doc.document_properties.stimulus_presentation.stimuli(j).parameters);']);
						if ~isempty(freq_multi_here),
							gotone = 1; 
							break;
						end;
					end;
					if gotone,
						freq_response_commands = [0 1 2];
					else,
						freq_response_commands = 0;
					end;
				else,
					freq_response_commands = freq_response;
				end;

				% build up search for existing parameter documents
				q_doc = ndi.query('','isa','stimulus_response_scalar_parameters_basic','');
				q_rdoc = ndi.query('','isa','stimulus_response_scalar','') & ...
					ndi.query('','depends_on','element_id',ndi_timeseries_obj.id());
				q_r_stimdoc = ndi.query('','depends_on','stimulus_presentation_id',stim_doc.id());
				q_r_stimcontroldoc = ndi.query('','depends_on','stimulus_control_id',control_doc.id());
				q_e = ndi.query(E.searchquery());

				q_match{1} = ndi.query('stimulus_response_scalar_parameters_basic.temporalfreqfunc',...
					'exact_string',temporalfreqfunc,'');
				q_match{2} = ndi.query('stimulus_response_scalar_parameters_basic.prestimulus_time',...
					'exact_number',prestimulus_time,'');
				q_match{3} = ndi.query('stimulus_response_scalar_parameters_basic.prestimulus_normalization',...
					'exact_number',prestimulus_normalization,'');
				q_match{4} = ndi.query('stimulus_response_scalar_parameters_basic.isspike',...
					'exact_number',isspike,'');
				q_match{5} = ndi.query('stimulus_response_scalar_parameters_basic.spiketrain_dt',...
					'exact_number',spiketrain_dt,'');
				q_matchtot = q_match{1};
				for j=2:numel(q_match),
					q_matchtot = q_matchtot & q_match{j};
				end;
				q_matchtot = q_e & q_doc & q_matchtot;

				% load the data, get the stimulus times				

				presentation_time = ndi_decoder.load_presentation_time(stim_doc);
				stim_stim_onsetoffsetid=[vlt.data.colvec([presentation_time.onset]) ...
						vlt.data.colvec([presentation_time.offset]) ...
						vlt.data.colvec([stim_doc.document_properties.stimulus_presentation.presentation_order])];

				stim_timeref = ndi.time.timereference(ndi_stim_obj, ...
					ndi.time.clocktype(presentation_time(1).clocktype), ...
					stim_doc.document_properties.epochid.epochid, 0);

				[ts_epoch_t0_out, ts_epoch_timeref, msg] = E.syncgraph.time_convert(stim_timeref,...
					vlt.data.colvec(stim_stim_onsetoffsetid(:,[1 2])), ndi_timeseries_obj, ndi.time.clocktype('dev_local_time'));

				ts_stim_onsetoffsetid = [reshape(ts_epoch_t0_out,numel(stim_doc.document_properties.stimulus_presentation.presentation_order),2) ...
					stim_stim_onsetoffsetid(:,3)];

				[data,t_raw,timeref] = readtimeseries(ndi_timeseries_obj, ts_epoch_timeref.epoch, 0, 1);

				vi = gapp.loadvalidinterval(ndi_timeseries_obj);
				interval = gapp.identifyvalidintervals(ndi_timeseries_obj,timeref,0,Inf);

				[data,t_raw,timeref] = readtimeseries(ndi_timeseries_obj, ts_epoch_timeref.epoch, interval(1,1), interval(1,2));

				for f=1:numel(freq_response_commands),

					freq_response = freq_response_commands(f);

					if freq_response==0,
						response_type = 'mean';
					else,
						response_type = ['F' int2str(freq_response)];
					end;

					% step 1, build the parameter document, if necessary; if we can find an example, use it
					q_matchhere = ndi.query('stimulus_response_scalar_parameters_basic.freq_response',...
						'exact_number',freq_response,'');

					param_doc = E.database_search(q_matchtot&q_matchhere);

					if isempty(param_doc),
						% make one
						stimulus_response_scalar_parameters_basic = vlt.data.var2struct('temporalfreqfunc','freq_response',...
							'prestimulus_time','prestimulus_normalization',...
							'isspike','spiketrain_dt');
						param_doc = ndi.document('stimulus_response_scalar_parameters_basic',...
							'stimulus_response_scalar_parameters_basic', stimulus_response_scalar_parameters_basic') + ...
							E.newdocument();
						E.database_add(param_doc);
						param_doc = {param_doc};
					end;

					% look for existing response docs

					rdoc = E.database_search(q_e&q_rdoc&q_r_stimdoc&q_r_stimcontroldoc&...
						ndi.query('','depends_on','stimulus_response_scalar_parameters_id',param_doc{1}.id()));

					E.database_rm(rdoc);

					controlstimids = control_doc.document_properties.control_stimulus_ids.control_stimulus_ids(:);
					freq_mult = [];
					for j=1:numel(stim_doc.document_properties.stimulus_presentation.stimuli),
						eval(['freq_multi_here = ' temporalfreqfunc '(stim_doc.document_properties.stimulus_presentation.stimuli(j).parameters);']);
						if ~isempty(freq_multi_here),
							freq_mult(j) = freq_multi_here;
						else,
							freq_mult(j) = 0;
						end;
					end;

					response = vlt.neuro.stimulus.stimulus_response_scalar(data, t_raw, ts_stim_onsetoffsetid, 'control_stimid', controlstimids,...
						'freq_response', freq_response*freq_mult, 'prestimulus_time',prestimulus_time,...
						'prestimulus_normalization',prestimulus_normalization,...
						'isspike',isspike,'spiketrain_dt',spiketrain_dt);

					response_structure = struct('stimid',vlt.data.rowvec(ts_stim_onsetoffsetid(:,3)),...
						'response_real', vlt.data.rowvec(real([response.response])), ...
						'response_imaginary', vlt.data.rowvec(imag([response.response])), ...
						'control_response_real', vlt.data.rowvec(real([response.control_response])), ...
						'control_response_imaginary',vlt.data.rowvec(imag([response.control_response])));

					stimulus_response_scalar_struct = struct('response_type', response_type, 'responses',response_structure);

					stimulus_response_struct = struct( 'stimulator_epochid', stim_doc.document_properties.epochid.epochid, ...
						'element_epochid', ts_epoch_timeref.epoch);

					response_doc{end+1} = ndi.document('stimulus_response_scalar',...
						'stimulus_response_scalar',stimulus_response_scalar_struct,...
						'stimulus_response', stimulus_response_struct)+E.newdocument();
					response_doc{end} = response_doc{end}.set_dependency_value('stimulus_response_scalar_parameters_id', ...
						param_doc{1}.id());
					response_doc{end} = response_doc{end}.set_dependency_value('element_id', ndi_timeseries_obj.id());
					response_doc{end} = response_doc{end}.set_dependency_value('stimulus_presentation_id', stim_doc.id()); 
					response_doc{end} = response_doc{end}.set_dependency_value('stimulus_control_id', control_doc.id());
					response_doc{end} = response_doc{end}.set_dependency_value('stimulator_id', ndi_stim_obj.id()); 

					E.database_add(response_doc{end});
				end;
		end; % compute_stimulus_response_scalar()

		function tuning_doc = tuning_curve(ndi_app_tuning_response_obj, stim_response_doc, varargin)
			% TUNING_CURVE - compute a tuning curve from stimulus responses
			%
			% TUNING_DOC = TUNING_CURVE(NDI_APP_TUNING_RESPONSE_OBJ, STIM_RESOPNSE_DOC, ...)
			%
			%
			% This function accepts name/value pairs that modifies its basic operation:
			%
			% Parameter (default)         | Description
			% -----------------------------------------------------------------------
			% response_units ('Spikes/s') | Response units to pass along
			% independent_label {'label1'}| Independent parameter axis label
			% independent_parameter {}    | Independent parameters to search for in stimuli.
			%                             |   Can be multi-dimensional to create multi-variate 
			%                             |   tuning curves. Only stimuli that contain these fields
			%                             |   will be included.
			%                             |   Examples: {'angle'}  {'angle','sFrequency'}
			% constraint ([])             | Constraints in the form of a vlt.data.fieldsearch structure.
			%                             |   Example: struct('field','sFrequency','operation',...
			%                             |              'exact_number','param1',1,'param2','')
			% do_Add (1)                  | Should we actually add this to the database?
			%
			% See also: vlt.data.fieldsearch

				independent_label = {'label1'};

				independent_parameter = {};
				constraint = [];
				do_Add = 1;

				vlt.data.assign(varargin{:});

				E = ndi_app_tuning_response_obj.session;

				% Step 1: error checking
				if numel(independent_parameter)<1,
					error(['No criteria for tuning curve: independent_parameter/independent_label are empty.']);
				end;
				if numel(independent_parameter)~=numel(independent_label),
					error(['Mismatch between dimensions of independent_parameter and independent_label']);
				end;

				% Step 2: set up our search criteria

				for i=1:numel(independent_parameter),
					newconstraint = struct('field',independent_parameter{i},'operation','hasfield','param1','','param2','');
					if isempty(constraint),
						constraint = newconstraint;
					else,
						constraint(end+1) = newconstraint;
					end;
				end;

				% Step 3:

				% load stimulus information 
				stim_pres_doc = E.database_search(ndi.query('base.id', 'exact_string', ...
					stim_response_doc.dependency_value('stimulus_presentation_id'),''));
				if isempty(stim_pres_doc),
					error(['Could not load stimulus presentation document ' ...
						stim_response_doc.document_properties.stimulus_response.stimulus_presentation_identifier]);
				end;
				stim_pres_doc = stim_pres_doc{1};

				% Step 4: set up variables

				tuning_curve = vlt.data.emptystruct('independent_variable_label','independent_variable_value','stimid',...
					'response_mean','response_stddev','response_stderr',...
					'individual_responses_real','individual_responses_imaginary', 'stimulus_presentation_number', ...
					'control_stimid','control_response_mean','control_response_stddev','control_response_stderr',...
					'control_individual_responses_real','control_individual_responses_imaginary',...
					'response_units');

				tuning_curve(1).independent_variable_label = independent_label;
				tuning_curve.independent_variable_value = zeros(0,numel(independent_label));
			
				% Step 5: determine the conditions we have here, that will be averaged over

				isincluded = [];

				independent_variable_value = [];

				for n=1:numel(stim_pres_doc.document_properties.stimulus_presentation.stimuli),
					p = stim_pres_doc.document_properties.stimulus_presentation.stimuli(n).parameters;
					isincluded(n) = vlt.data.fieldsearch(p,constraint);
					if isincluded(n),
						value_here = [];
						for i=1:numel(independent_parameter),
							% walk through all stimuli, pull out values
							value_here(i) = eval(['p.' independent_parameter{i} ';']);
						end;
						independent_variable_value = [independent_variable_value; vlt.data.rowvec(value_here)];
					end;
				end;

				if isempty(isincluded), % nothing here to do
					tuning_doc = [];
					warning('empty tuning curve.');
					return;
				end;

				tuning_curve.independent_variable_value = unique(independent_variable_value,'rows'); % sort and find unique entries

				% Step 6: do the averaging and store the individual response values

				num_points = size(tuning_curve.independent_variable_value,1);
				tuning_curve.individual_responses_real = cell(1,num_points);
				tuning_curve.individual_responses_imaginary = cell(1,num_points);
				tuning_curve.control_individual_responses_real = cell(1,num_points);
				tuning_curve.control_individual_responses_imaginary = cell(1,num_points);
				tuning_curve.stimid = nan(1,num_points);

				nth_independent_value = 1;
				for n=1:numel(stim_pres_doc.document_properties.stimulus_presentation.stimuli),
					p = stim_pres_doc.document_properties.stimulus_presentation.stimuli(n).parameters;
					if isincluded(n),
						I = vlt.data.findrowvec(tuning_curve.independent_variable_value, independent_variable_value(nth_independent_value,:));
						nth_independent_value = nth_independent_value + 1;
						if isempty(I),
							error(['unexpected..cannot find stimulus values. Should not happen.']);
						end;
						stimulus_indexes = find(stim_response_doc.document_properties.stimulus_response_scalar.responses.stimid==n);
						tuning_curve.stimid(I) = n; % this stimid
						tuning_curve.individual_responses_real{I} = ...
							stim_response_doc.document_properties.stimulus_response_scalar.responses.response_real(stimulus_indexes);
						tuning_curve.individual_responses_imaginary{I} = ...
							stim_response_doc.document_properties.stimulus_response_scalar.responses.response_imaginary(stimulus_indexes);
						tuning_curve.control_individual_responses_real{I} = ...
							stim_response_doc.document_properties.stimulus_response_scalar.responses.control_response_real(stimulus_indexes);
						tuning_curve.control_individual_responses_imaginary{I} = ...
							stim_response_doc.document_properties.stimulus_response_scalar.responses.control_response_imaginary(stimulus_indexes);
						tuning_curve.stimulus_presentation_number{I} = stimulus_indexes;
						all_responses = tuning_curve.individual_responses_real{I} + sqrt(-1)*tuning_curve.individual_responses_imaginary{I};
						tuning_curve.response_mean(I)            = nanmean  (all_responses);
						if ~all(isreal(tuning_curve.response_mean)),
							tuning_curve.response_mean = abs(tuning_curve.response_mean);
						end;
						tuning_curve.response_stddev(I)          = nanstd   (all_responses);
						tuning_curve.response_stderr(I)          = vlt.data.nanstderr(all_responses);
						all_control_responses = tuning_curve.control_individual_responses_real{I} + ...
							sqrt(-1)*tuning_curve.control_individual_responses_imaginary{I};
						tuning_curve.control_response_mean(I)    = nanmean  (all_control_responses);
						if ~all(isreal(tuning_curve.control_response_mean)),
							tuning_curve.control_response_mean = abs(tuning_curve.control_response_mean);
						end;
						tuning_curve.control_response_stddev(I)  = nanstd   (all_control_responses);
						tuning_curve.control_response_stderr(I)  = vlt.data.nanstderr(all_control_responses);
					end;
				end;

				% okay, now we have these cell arrays for tuning_curve.individual* and tuning_curve.control_individual*,
				% but if the cell array is completely filled it will go into a JSON file as a matrix. So, we really ought
				% to make it a matrix. 

				tuning_curve.individual_responses_real = vlt.data.cellarray2mat(tuning_curve.individual_responses_real);
				tuning_curve.individual_responses_imaginary = vlt.data.cellarray2mat(tuning_curve.individual_responses_imaginary);
				tuning_curve.control_individual_responses_real = vlt.data.cellarray2mat(tuning_curve.control_individual_responses_real);
				tuning_curve.control_individual_responses_imaginary = vlt.data.cellarray2mat(tuning_curve.control_individual_responses_imaginary);
				tuning_curve.stimulus_presentation_number = vlt.data.cellarray2mat(tuning_curve.stimulus_presentation_number);

				tuning_doc = ndi.document('stimulus_tuningcurve','stimulus_tuningcurve',tuning_curve) + E.newdocument();
				tuning_doc = tuning_doc.set_dependency_value('stimulus_response_scalar_id',stim_response_doc.id());
				tuning_doc = tuning_doc.set_dependency_value('element_id',stim_response_doc.dependency_value('element_id'));
				if do_Add,
					E.database_add(tuning_doc);
				end;
				
		end; % tuning_curve()

		function cs_doc = label_control_stimuli(ndi_app_tuning_response_obj, stimulus_element_obj, reset, varargin)
			% LABEL_CONTROL_STIMULI - label control stimuli for all stimulus presentation documents for a given stimulator
			%
			% CS_DOC = LABEL_CONTROL_STIMULI(NDI_APP_TUNING_RESPONSE_OBJ, STIMULUS_ELEMENT_OBJ, RESET, ...)
			%
			% Thus function will look for all 'stimulus_presentation' documents for STIMULUS_PROBE_OBJ,
			% compute the corresponding control stimuli, and save them as an 'control_stimulus_ids' 
			% document that is also returned as a cell list in CS_DOC.
			%
			% If RESET is 1, then any existing documents of this type are first removed. If RESET is not provided or is
			% empty, then it is taken to be 0.
			%
			% The method of finding the control stimulus can be provided by providing extra name/value pairs.
			% See ndi.app.stimulus.tuning_response/CONTROL_STIMULUS for parameters.
			% 
				if nargin<3,
					reset = 0;
				end;

				sq_stimulus_element = ndi.query('','depends_on','stimulus_element_id',stimulus_element_obj.id());
				sq_stim = ndi.query('','isa','stimulus_presentation','');
				stim_doc = ndi_app_tuning_response_obj.session.database_search(sq_stim&sq_stimulus_element);

				if reset,
					sq_csi = ndi.query('','isa','control_stimulus_ids','');
					for i=1:numel(stim_doc),
						sq_csi_stim = ndi.query('','depends_on','stimulus_presentation_id',stim_doc{i}.id());
						old_cs_doc = ndi_app_tuning_response_obj.session.database_search(sq_csi&sq_csi_stim);
						ndi_app_tuning_response_obj.session.database_rm(old_cs_doc);
					end;
				end;

				cs_doc = {};

				for i=1:numel(stim_doc),
					[cs_ids,cs_doc_here] = ndi_app_tuning_response_obj.control_stimulus(stim_doc{i},varargin{:});
					cs_doc{end+1} = cs_doc_here;
				end;
		end;
		
		function [cs_ids, cs_doc] = control_stimulus(ndi_app_tuning_response_obj, stim_doc, varargin)
			% CONTROL_STIMULUS - determine the control stimulus ID for each stimulus in a stimulus set
			%
			% [CS_IDS, CS_DOC] = CONTROL_STIMULUS(NDI_APP_TUNING_RESPONSE_OBJ, STIM_DOC, ...)
			%
			% For a given set of stimuli described in ndi.document of type 'stimulus',
			% this function returns the control stimulus ID for each stimulus in the vector CS_IDS 
			% and a corresponding ndi.document of type control_stimulus_ids that describes this relationship.
			%
			%
			% This function accepts parameters in the form of NAME/VALUE pairs:
			% Parameter (default)              | Description
			% ------------------------------------------------------------------------
			% control_stim_method              | The method to be used to find the control stimulu for
			%  ('psuedorandom')                |    each stimulus:
			%                       -----------|
			%                       |   pseudorandom: Find the stimulus with a parameter
			%                       |      'controlid' that is in the same pseudorandom trial. In the
			%                       |      event that there is no match that divides evenly into 
			%                       |      complete repetitions of the stimulus set, then the
			%                       |      closest stimulus with field 'controlid' is chosen.
			%                       |      
			%                       |      
			%                       -----------|
			% controlid ('isblank')            | For some methods, the parameter that defines whether
			%                                  |    a stimulus is a 'control' stimulus or not.
			% controlid_value (1)              | For some methods, the parameter value of 'controlid' that
			%                                  |    defines whether a stimulus is a control stimulus or not.

				control_stim_method = 'psuedorandom';
				controlid = 'isblank';
				controlid_value = 1;
				ndi_decoder = ndi.app.stimulus.decoder(ndi_app_tuning_response_obj.session);
				presentation_time = ndi_decoder.load_presentation_time(stim_doc);
			
				vlt.data.assign(varargin{:});

				switch (lower(control_stim_method)),
					case 'psuedorandom'
						control_stim_id_method.method = control_stim_method;
						control_stim_id_method.controlid = controlid;
						control_stim_id_method.controlid_value = controlid_value;
		
						controlstimid = [];
						for n=1:numel(stim_doc.document_properties.stimulus_presentation.stimuli),
							if vlt.data.fieldsearch(stim_doc.document_properties.stimulus_presentation.stimuli(n).parameters, ...
								struct('field',controlid,'operation','exact_number','param1',controlid_value,'param2',[])),
								controlstimid(end+1) = n;
							end;
						end;
						
						% what if we have more than one? bail out for now

						if numel(controlstimid)>1,
							error(['Do not know what to do with more than one control stimulus type.']);
						end;

						% if number of control stimuli is 0, that's okay, just give values of NaN

						stimids = stim_doc.document_properties.stimulus_presentation.presentation_order;

						[reps,isregular] = vlt.neuro.stimulus.stimids2reps(stimids,numel(stim_doc.document_properties.stimulus_presentation.stimuli));

						control_stim_indexes = [];
						if ~isempty(controlstimid),
							control_stim_indexes = find(stimids==controlstimid);
						end;

						if isempty(control_stim_indexes),
							cs_ids = nan(size(stimids));
						else,
							if isregular,
								if numel(unique(reps))>numel(control_stim_indexes),
									control_stim_indexes(end+1) = control_stim_indexes(end); % let previous control stim stand in for incomplete
								end;
								cs_ids = control_stim_indexes(reps);
							else,
								cs_ids = [];
								% slow
								presentation_onsets = [presentation_time.onset];
								for n=1:numel(stimids),
									i=vlt.data.findclosest(presentation_onsets(control_stim_indexes), presentation_onsets(n));
									cs_ids(n) = control_stim_indexes(i);
								end;
							end;
						end;
					otherwise,
						error(['Unknown control stimulus method ' control_stim_method '.']);

				end; % switch

				% now we have cs_ids for each stimulus, so make the document

				control_stim_ids_struct = struct('control_stimulus_ids', cs_ids(:),'control_stimulus_id_method',control_stim_id_method);
				cs_doc = ndi.document('control_stimulus_ids','control_stimulus_ids',control_stim_ids_struct) ...
					+ ndi_app_tuning_response_obj.newdocument();
				cs_doc = cs_doc.set_dependency_value('stimulus_presentation_id',stim_doc.id());

				ndi_app_tuning_response_obj.session.database_add(cs_doc);

		end; % control_stimulus()

		function [tc_doc, srs_doc] = find_tuningcurve_document(ndi_app_tuning_response_obj, ndi_element_obj, epochid, response_type)
			% FIND_TUNINGCURVE_DOCUMENT - find a tuning curve document of a particular element, epochid, etc...
			%
			% [TC_DOC, SRS_DOC] = FIND_TUNINGCURVE_DOCUMENT(NDI_APP_TUNING_RESPONSE_OBJ, ELEMENT_OBJ, EPOCHID, RESPONSE_TYPE) 
			%
			%
				E = ndi_app_tuning_response_obj.session;

				tc_doc = {};
				srs_doc = {};

				q_e = ndi.query(E.searchquery());
				q_tc = ndi.query('','isa','stimulus_tuningcurve','');
				q_elementr = ndi.query('depends_on','depends_on','element_id',ndi_element_obj.id());

				tc_doc_matches = E.database_search(q_e&q_tc&q_elementr);

				match_indexes = [];
				srs = {};

				for i=1:numel(tc_doc_matches),
					q_stimresponsescalar = ndi.query('base.id','exact_string',...
						tc_doc_matches{i}.dependency_value('stimulus_response_scalar_id'),'');
					srs{i} = E.database_search(q_e&q_stimresponsescalar);
					if ~isempty(srs),
						for j=1:numel(srs{i}),
							if strcmpi(srs{i}{j}.document_properties.stimulus_response_scalar.response_type,response_type) & ...
								strcmpi(srs{i}{j}.document_properties.stimulus_response.element_epochid, epochid),
									match_indexes(end+1,:) = [i j];
							end;
						end;
					end;
				end;

				if ~isempty(match_indexes),
					for i=1:size(match_indexes),
						tc_doc{i} = ndi_app_tuning_response_obj.tuningdoc_fixcellarrays_static(tc_doc_matches{match_indexes(i,1)});
						srs_doc{i} = srs{match_indexes(i,1)}{match_indexes(i,2)};
					end;
				end;

		end; % find_tuningcurve_document

		function tc_doc = tuningdoc_fixcellarrays(ndi_app_tuning_response_obj, tc_doc)
			% TUNINGDOC_FIXCELLARRAYS - make sure fields that are supposed to be cell arrays are cell arrays in TUNINGCURVE document
			%
			% DEPRICATED - will cause an error
			%
				error(['This version is depricated. Use ndi.app.stimulus.tuning_response.tuningdoc_fixcellarrays_static() ']);
				document_properties = tc_doc.document_properties;

				for i=1:numel(document_properties.stimulus_tuningcurve.individual_responses_real),
					% grr..if the elements are all the same size, Matlab will make individual_response_real, etc, a matrix instead of cell
					document_properties.stimulus_tuningcurve.individual_responses_real = ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.individual_responses_real);
                                        document_properties.stimulus_tuningcurve.individual_responses_imaginary= ...
                                                        vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.individual_responses_imaginary);
					document_properties.stimulus_tuningcurve.control_individual_responses_real = ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.control_individual_responses_real);
					document_properties.stimulus_tuningcurve.control_individual_responses_imaginary= ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.control_individual_responses_imaginary);
					document_properties.stimulus_tuningcurve.stimulus_presentation_number = ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.stimulus_presentation_number);
                                end;

				tc_doc = setproperties(tc_doc, 'stimulus_tuningcurve',document_properties.stimulus_tuningcurve);
		end;  % fixcellarrays()

		function tuning_docs = make_1d_tuning(ndi_app_tuning_response_obj, stim_response_doc, param_to_vary, param_to_vary_label, param_to_fix, varargin)
			% MAKE_1D_TUNING - create 1d tuning documents out of stimulus responses that covary in 2 parameters
			%
			% TUNING_DOCS = MAKE_1D_TUNING(NDI_APP_TUNING_RESPONSE_OBJ, STIM_RESPONSE_DOC, PARAM_TO_VARY, PARAM_TO_VARY_LABEL, 
			%   PARAM_TO_FIX)
			%
			% This function examines a stimulus response doc that covaries in 2 parameters, and "deals" the responses into several tuning
			% curves where the parameter with name PARAM_TO_VARY varies across stimuli and the stimulus parameter with name
			% PARAM_TO_FIX is fixed for each tuning doc.
			%
			%
				tuning_docs = {};

				S = ndi_app_tuning_response_obj.session;

				stim_pres_doc = S.database_search(ndi.query('base.id','exact_string', ...
					dependency_value(stim_response_doc,'stimulus_presentation_id'),''));
				if isempty(stim_pres_doc),
					error(['Could not find stimulus presentation doc for stimulus response doc.']);
				end;
				
				stim_props = {stim_pres_doc{1}.document_properties.stimulus_presentation.stimuli.parameters};

				included = [];
				param_to_fix_values = [];

				for n=1:numel(stim_props),
					if ~isfield(stim_props{n},'isblank'),
						included(end+1) = n;
					elseif ~stim_props{n}.isblank,
						included(end+1) = n;
					end;
					if ismember(n,included),
						if isfield(stim_props{n},param_to_fix) & isfield(stim_props{n},param_to_vary),
							param_to_fix_values(end+1) = getfield(stim_props{n},param_to_fix);
						end;
					end;
				end;

				param_to_fix_values = unique(param_to_fix_values)

				for i=1:numel(param_to_fix_values),
					constraint = struct('field',param_to_fix,'operation','exact_number','param1',param_to_fix_values(i),'param2','');
					tuning_docs{end+1} = ndi_app_tuning_response_obj.tuning_curve(stim_response_doc, 'independent_parameter', {param_to_vary},...
						'independent_label',{param_to_vary_label},'constraint',constraint);
				end;

		end; % make_1d_tuning
	end; % methods

	methods (Static)

		function resp = tuningcurvedoc2vhlabrespstruct(tuning_doc)
			% TUNINGCURVEDOC2VHLABRESPSTRUCT - convert between a tuning curve document and the VH lab response structure
			%
			% RESPSTRUCT = TUNINGCURVEDOC2VHLABRESPSTRUCT(TUNINGCURVE_DOC)
			%
			% Converts entries from an NDI TUNINGCURVE document to a VH-lab response structure.
			% This function is generally used when one wants to call the VH lab libraries.
			%
			%   RESPSTRUCT is a structure  of response properties with fields:
			%   curve    |    4xnumber of directions tested,
			%            |      curve(1,:) is directions tested (degrees, compass coords.)
			%            |      curve(2,:) is mean responses, with control subtracted
			%            |      curve(3,:) is standard deviation
			%            |      curve(4,:) is standard error
			%   ind      |    cell list of individual trial responses for each direction
			%   spont    |    control responses [mean stddev stderr]
			%   spontind |    individual control responses
			%   Optionally:
			%   blankresp|    response to a control trial: [mean stddev stderr]
			%   blankind |    individual responses to control

				ind = {};
				ind_real = {};
				control_ind = {};
				control_ind_real = {};
				response_ind = {};
				response_mean = [];
				response_stddev = [];
				response_stderr = [];

				% grr..if the elements are all the same size, Matlab will make individual_response_real, etc, a matrix instead of cell
				tuning_doc = ndi.app.stimulus.tuning_response.tuningdoc_fixcellarrays_static(tuning_doc);

				for i=1:numel(tuning_doc.document_properties.stimulus_tuningcurve.individual_responses_real),
					ind{i} = tuning_doc.document_properties.stimulus_tuningcurve.individual_responses_real{i} + ...
						sqrt(-1)*tuning_doc.document_properties.stimulus_tuningcurve.individual_responses_imaginary{i};
					ind_real{i} = ind{i};
					if any(~isreal(ind_real{i})), ind_real{i} = abs(ind_real{i}); end;
					control_ind{i} = tuning_doc.document_properties.stimulus_tuningcurve.control_individual_responses_real{i} + ...
						sqrt(-1)*tuning_doc.document_properties.stimulus_tuningcurve.control_individual_responses_imaginary{i};
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
				resp.spontind = resp.blankind;
				resp.blankresp = [mean(resp.blankind(:)) std(resp.blankind(:)) vlt.stats.stderr(resp.blankind(:))];
				resp.spont = resp.blankresp; 

		                if size(tuning_doc.document_properties.stimulus_tuningcurve.independent_variable_value,2)>1,
					tuning_axis = 1:numel(response_mean);
				else,
					tuning_axis = tuning_doc.document_properties.stimulus_tuningcurve.independent_variable_value(:)';
				end;

				resp.curve = ...
					[ tuning_axis ; ...
						response_mean ; ...
						response_stddev ; ...
						response_stderr; ];
				resp.ind = response_ind;


		end; % tuningcurvedoc2vhlabrespstruct()

		function tc_doc = tuningdoc_fixcellarrays_static(tc_doc)
			% TUNINGDOC_FIXCELLARRAYS_STATIC - make sure fields that are supposed to be cell arrays are cell arrays in TUNINGCURVE document
			%
				document_properties = tc_doc.document_properties;

				if datetime(document_properties.base.datestamp(1:end-1)) > datetime('2024-02-11T0:0:01.0'),
					document_properties.stimulus_tuningcurve.individual_responses_real = ...
					document_properties.stimulus_tuningcurve.individual_responses_real';
					document_properties.stimulus_tuningcurve.individual_responses_imaginary = ...
					document_properties.stimulus_tuningcurve.individual_responses_imaginary';
					document_properties.stimulus_tuningcurve.control_individual_responses_real = ...
					document_properties.stimulus_tuningcurve.control_individual_responses_real';
					document_properties.stimulus_tuningcurve.control_individual_responses_imaginary = ...
					document_properties.stimulus_tuningcurve.control_individual_responses_imaginary';
					document_properties.stimulus_tuningcurve.stimulus_presentation_number = ...
					document_properties.stimulus_tuningcurve.stimulus_presentation_number';
				end;

				for i=1:numel(document_properties.stimulus_tuningcurve.individual_responses_real),
					% grr..if the elements are all the same size, Matlab will make individual_response_real, etc, a matrix instead of cell
						document_properties.stimulus_tuningcurve.individual_responses_real = ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.individual_responses_real);
						document_properties.stimulus_tuningcurve.individual_responses_imaginary= ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.individual_responses_imaginary);
						document_properties.stimulus_tuningcurve.control_individual_responses_real = ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.control_individual_responses_real);
						document_properties.stimulus_tuningcurve.control_individual_responses_imaginary= ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.control_individual_responses_imaginary);
						document_properties.stimulus_tuningcurve.stimulus_presentation_number = ...
							vlt.data.matrow2cell(document_properties.stimulus_tuningcurve.stimulus_presentation_number);
                                end;

				tc_doc = setproperties(tc_doc, 'stimulus_tuningcurve',document_properties.stimulus_tuningcurve);

		end;  % fixcellarrays()

		        function [b,ratio,meanresponse,modulatedresponse,mean_index,modulated_index] = modulated_or_mean(stimulus_response_scalar_docs, varargin)
			% MODULATED_OR_MEAN - is the response stronger in modulation or mean?
			%
			% [B,ratio,mean_response,modulated_response,mean_index,modulated_index] = ...
			%     MODULATED_OR_MEAN(STIMULUS_RESPONSE_SCALAR_DOCS, ...)
			% 
			% Given a cell array of STIMULUS_RESPONSE_SCALAR documents that
			% correspond to different response types to the same stimulus, this
			% function examines whether the best modulated response
			% is greater than the best mean response.
			%
			% B is 1 if the modulated response is greater, and 0 if the mean response is greater.
			% If there is no basis for the comparison, then -1 is returned.
			%
			% MEAN_RESPONSE is the mean response for the stimulus that has the largest
			% response (this largest response could be the mean or the modulated response).
			% MODULATED_RESPONSE is the modulated response for the stimulus that has the largest
			% response (this largest response could be the mean or the modulated response).
			% RATIO is the ratio of these two values (MODULATED_RESPONSE / MEAN_RESPONSE).
			% 
			% MEAN_INDEX is the index number of the stimulus response scalar document with the
			% mean response. MODULATED_INDEX is the index number of the stimulus
			% response scalar document with the modulated response.
			%
			% This function examines the empirical responses and does not do any
			% fitting.
			%
			% This function also takes name/value pairs that modify the default behavior.
			%
			% |--------------------------------------------------------------------------------| 
			% | Parameter (default)          | Description                                     |
			% |--------------------------------------------------------------------------------|
			% |  modulated_response_names    | Possible matches for the modulated responses    |
			% |  ({'F1','modulated'})        |   in the 'response_type' field of the           |
			% |                              |   STIMULUS_RESPONSE_SCALAR documents.           |
			% |  mean_response_names         | Possible matches for the mean responses         |
			% |  ({'F0','mean'})             |   in the 'response_type' field of the           |
                        % |                              |   STIMULUS_RESPONSE_SCALAR documents.           |
			% |------------------------------|-------------------------------------------------|
			%
				% Step 0: initialize parameters

				modulated_response_names = {'F1','modulated'};
				mean_response_names = {'F0','mean'};

				vlt.data.assign(varargin{:});

				% Step 1: check the inputs
				% Step 1a: do some sanity checking on inputs
	
				if ~iscell(stimulus_response_scalar_docs), 
					error(['STIMULUS_RESPONSE_SCALAR_DOCS should be a cell array.']);
				end;

				% Step 1b: make sure stimulus_response_scalar documents depend on the same
				%  stimulus. At the same time, grab some information out of the documents about
				%  response types.

				good = 1;

				response_types = {};
				matches_mean = [];
				matches_modulation = [];
				stimulus_presentation = dependency_value(stimulus_response_scalar_docs{1},'stimulus_presentation_id');

				for i=1:numel(stimulus_response_scalar_docs),
					if ~isa(stimulus_response_scalar_docs{i},'ndi.document'),
						good = 0;
						break; 
					else,
						if ~isfield(stimulus_response_scalar_docs{i}.document_properties,'stimulus_response_scalar'),
							good = 0;
							break;
						else,
							response_types{i} = stimulus_response_scalar_docs{i}.document_properties.stimulus_response_scalar.response_type;
							matches_mean(i) = any(strcmpi(response_types{i},mean_response_names));
							matches_modulation(i) = any(strcmpi(response_types{i},modulated_response_names));
						end;
					end;
				end;
				
				if ~good,
					error(['STIMULUS_RESPONSE_SCALAR_DOCS must be of type ''stimulus_response_scalar''']);
				end;

				% Step 1c: now see if we have a single mean response

				b = -1;
				ratio = NaN;
				meanresponse = NaN;
				modulationresponse = NaN;

				if sum(matches_mean)==0 | sum(matches_modulation)==0, 
					return; % nothing more to do
				end;

				if sum(matches_mean)>1,
					error(['More than one mean response; do not know which to use.']);
				end;
				if sum(matches_modulation)>1,
					error(['More than one modulated response; do not know which to use.']);
				end;

				mean_stim_response = find(matches_mean); % will be 1 element
				mean_index = mean_stim_response;
				modulation_stim_response = find(matches_modulation); % will be 1 element
				modulated_index = modulation_stim_response;

				mean_resps = [];
				modulation_resps = [];

				R_mean = stimulus_response_scalar_docs{mean_stim_response}.document_properties.stimulus_response_scalar.responses;
				R_mod = stimulus_response_scalar_docs{modulation_stim_response}.document_properties.stimulus_response_scalar.responses;
				stimids_present = unique(R_mean.stimid);

				for i=1:numel(stimids_present),
					indexes = find(R_mean.stimid == stimids_present(i));
					mean_resps_here = R_mean.response_real(indexes) + sqrt(-1)*R_mean.response_imaginary(indexes) - (R_mean.control_response_real(indexes)+sqrt(-1)*R_mean.control_response_imaginary(indexes));
					mean_resps(i) = nanmean(mean_resps_here);
					if imag(mean_resps(i))>1e-6,
						mean_resps(i) = abs(mean_resps(i));
					else,
						mean_resps(i) = real(mean_resps(i));
					end;
					modulated_resps_here = R_mod.response_real(indexes) + sqrt(-1)*R_mod.response_imaginary(indexes) - (R_mod.control_response_real(indexes)+sqrt(-1)*R_mod.control_response_imaginary(indexes));
					modulation_resps(i) = nanmean(modulated_resps_here);
					if abs(imag(modulation_resps(i)))>1e-6,
						modulation_resps(i) = abs(modulation_resps(i));
					else,
						modulation_resps(i) = real(modulation_resps(i));
					end;
				end;

				[biggest_modulated,biggest_modulated_index] = max(modulation_resps);
				[biggest_mean,biggest_mean_index] = max(mean_resps);

				b = biggest_modulated > biggest_mean;

				if b, % simple-like response
					modulatedresponse = biggest_modulated;
					meanresponse = mean_resps(biggest_modulated_index);
				else,
					modulatedresponse = modulation_resps(biggest_mean_index);
					meanresponse = biggest_mean;
				end;

				ratio = modulatedresponse/meanresponse;

		end; % modualated_or_mean

	end; % static methods

end % ndi_app_stimulus_response
