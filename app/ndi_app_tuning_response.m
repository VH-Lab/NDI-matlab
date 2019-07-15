classdef ndi_app_tuning_response < ndi_app

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_tuning_response_obj = ndi_app_tuning_response(varargin)
			% NDI_APP_TUNING_RESPONSE - an app to decode stimulus information from NDI_PROBE_STIMULUS objects
			%
			% NDI_APP_TUNING_RESPONSE_OBJ = NDI_APP_TUNING_RESPONSE(EXPERIMENT)
			%
			% Creates a new NDI_APP_TUNING_RESPONSE object that can operate on
			% NDI_EXPERIMENTS. The app is named 'ndi_app_stimulus_response'.
			%
				experiment = [];
				name = 'ndi_app_tuning_response';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				ndi_app_tuning_response_obj = ndi_app_tuning_response_obj@ndi_app(experiment, name);

		end % ndi_app_tuning_response() creator


		function [newdocs, existingdocs] = stimulus_responses(ndi_app_tuning_response_obj, ndi_probe_stim, ndi_timeseries_obj, reset)
			% PARSE_STIMULI - write stimulus records for all stimulus epochs of an NDI_PROBE stimulus probe
			%
			% [NEWDOCS, EXISITINGDOCS] = STIMULUS_RESPONSES(NDI_APP_TUNING_RESPONSE_OBJ, NDI_PROBE_STIM, NDI_TIMESERIES_OBJ, [RESET])
			%
			% Examines a the NDI_EXPERIMENT associated with NDI_APP_TUNING_RESPONSE_OBJ and the stimulus
			% probe NDI_STIM_PROBE, and creates documents of type NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE
			% for all stimulus epochs.
			%
			% If NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE documents already exist for a given
			% stimulus run, then they are returned in EXISTINGDOCS. Any new documents are returned in NEWDOCS.
			%
			% If the input argument RESET is given and is 1, then all existing documents for this probe are
			% removed and all documents are recalculated. The default for RESET is 0 (if it is not provided).
			%
			% Note that this function DOES add the new documents to the database.
			%
				dbstack,
				E = ndi_app_tuning_response_obj.experiment;

				newdocs = {};
				existingdocs = {};

				% find all stimulus records from the stimulus probe
				sq_probe = ndi_probe_stim.searchquery();
				sq_e = E.searchquery();
				sq_stim  = {'document_class.class_name','ndi_document_stimulus' };
				sq_tune  = {'document_class.class_name','ndi_document_tuningcurve'};
				doc_stim = E.database_search( cat(2,sq_e,sq_probe,sq_stim) );
				doc_tune = E.database_search( cat(2,sq_e,sq_probe,sq_tune) );

				ndi_ts_epochs = {};

				% find all the epochs of overlap between stimulus probe and ndi_timeseries_obj

				truematches = [];
				for i=1:numel(doc_stim),
					truematches(i) = strcmp(doc_stim{i}.document_properties.document_class.class_name,'ndi_document_stimulus');
				end;
				doc_stim = doc_stim(logical(truematches));

				for i=1:numel(doc_stim),
					% ASSUMPTION: each stimulus probe epoch will overlap a single ndi_timeseries_obj epoch
					%   therefore, we can use the first one as a proxy for them all
					if numel(doc_stim{i}.document_properties.presentation_time)>0, % make sure there is at least 1 stimulus 
						stim_timeref = ndi_timereference(ndi_probe_stim, ...
							ndi_clocktype(doc_stim{i}.document_properties.presentation_time(1).clocktype), ...
							doc_stim{i}.document_properties.epochid, doc_stim{i}.document_properties.presentation_time(1).onset);
						[ts_epoch_t0_out, ts_epoch_timeref, msg] = E.syncgraph.time_convert(stim_timeref,...
							0, ndi_timeseries_obj, ndi_clocktype('dev_local_time')); % time is 0 because stim_timeref is relative to 1st stim
						if ~isempty(ts_epoch_t0_out),
							ndi_ts_epochs{i} = ts_epoch_timeref.epoch;
						else,
							ndi_ts_epochs{i} = '';
						end;
					end;
				end;

				for i=1:numel(doc_stim),
					if ~isempty(ndi_ts_epochs{i}),
						% okay, now how to analyze these stims?
						% 
						% want to calculate F0, F1, F2
						% want to do this for regularly sampled and timestamp type data

						ndi_ts_epochs{i}
						doc_stim{i}.document_properties




					end
				end
		end % 


		function tuning_doc = analyze_1d_tuning_curve(ndi_app_tuning_response_obj, ndi_probe_stim, ndi_timeseries_obj, stim_doc, varargin)
			% COMPUTE_STIMULUS_RESPONSE_SUMMARY - compute responses to a stimulus set
			%
			% DOC = COMPUTE_STIMULUS_RESPONSE_SUMMARY(NDI_APP_STIMULUS_RESPONSE_APP, NDI_PROBE_STIM, NDI_TIMESERIES_OBJ, TIMEREF, T0, T1, ...)
			%
			%
			%
			% Note: Uses the app NDI_APP_MARKGARBAGE to limit analysis to intervals that have been
			% marked as valid or have not been marked invalid.
			%
			%
			% This function also takes name/value pairs that alter the behavior:
			% Parameter (default)             | Description
			% ---------------------------------------------------------------------------------
			% independent_axis_units ('')     | If empty, the program attempts to determine the
			%                                 |   axis units by determining what varies across the
			%                                 |   stimulus parameters.
			% independent_axis_label ('')     | The label to use by a plotting program for the independent
			%                                 |   variable
			% independent_axis_parameter ('') | The parameter to read from the stimulus in order
			%                                 |   to obtain the independent_axis_values.
			% response_units ('')             | Response units; if empty, attempts to read from probe
			% response_label ('')             | Label for the responses for a plotting program
			%                                 |
			% blank_stimid ([])               | Pass the stimulus id numbers of any 'blank' (control)
			%                                 |   stimuli. If empty, then the program will look for 'isblank'
			%                                 |   fields in the parameters.
			% freq_response_parameter (0)     | The parameter of each stimulus to examine for frequency response.
			%                                 |   If 0, then the mean response is used.
			% freq_response_multiplier (0)    | The multipier to use with the freq_response_parameter value. For example,
			%                                 |   pass '1' to compute the F1 component (the response at the freq_response_parameter
			%                                 |   frequency).
			% prestimulus_time ([])           | If a baseline per stimulus is to be computed, it can be passed here (time in seconds)
			% prestimulus_normalization ([])  | Normalize the stimulus response based on the prestimulus measurement.
			%                                 | [] or 0) No normalization
			%                                 |       1) Subtract: Response := Response - PrestimResponse
			%                                 |       2) Fractional change Response:= ((Response-PrestimResponse)/PrestimResponse)
			%                                 |       3) Divide: Response:= Response ./ PreStimResponse
			%
				independent_axis_units = '';
				independent_axis_label = '';
				independent_axis_parameter = '';
				response_units = '';
				response_label = '';

				blank_stimid = [];

				freq_response_parameter = 0;
				freq_response_multiplier = 0;

				prestimulus_time = [];
				prestimulus_normalization = [];

				assign(varargin{:});

				[data,t_raw,timeref] = readtimeseries(ndi_timeseries_obj, timeref, t0, t0);

				gapp = ndi_app_markgarbage(ndi_app_stimulus_response_obj.experiment);
				vi = gapp.loadvalidinterval(sharpprobe);
				interval = gapp.identifyvalidintervals(ndi_timeseries_obj,timeref,t0,t1)

				[ds, ts, timeref_]=stimprobe.readtimeseries(timeref,interval(1,1),interval(1,2));
				[data,t_raw,timeref] = readtimeseries(sharpprobe, timeref, interval(1,1), interval(1,2));

				stim_onsetoffsetid = [ts.stimon ts.stimoff ds.stimid];

				if isempty(blank_stimid),
					isblank = structfindfield(ds.parameters,'isblank',1);
					notblank = setdiff(1:numel(ds.parameters),isblank);
					blank_stimid = isblank;
				end;

				% now get frequencies in order

				if isempty(freq_response_parameter),
					freq_response_parameter = 0;
					freq_response = 0;
				elseif isnumeric(freq_response_parameter),
					freq_response = freq_response_parameter;
				elseif ischar(freq_response_parameter),
					freq_response = [];
					for i=1:numel(ds.parameters),
						if isfield(ds.parameters{i},freq_response_parameter),
							freq_response(i) = getfield(ds.parameters{i},freq_response_parameter) * freq_response_multiplier;
						else,
							freq_response(i) = 0;
						end
					end
				end

				nvp = str2namevaluepair(var2struct('freq_response',blank_stimid','prestimulus_time','prestimulus_normalization'));

				response = stimulus_response_summary(data, t_raw, stim_onsetoffsetid, 'freq_response', freq_response, nvp{:});

				% now need to convert response to document

				% need to read independent_axis values

				independent_axis_values = [];

				if isempty(independent_axis_parameter),
					independent_axis_values = response.stimid;
				else,
					for i=1:numel(response.stimid),
						if isfield(ds.parameters{response.stimid(i)}),
							independent_axis_values(i) = getfield(ds.parameters{response.stimid(i)});
						else,
							independent_axis_values(i) = NaN;
						end
					end
				end

				independent_axis_units = '';
				independent_axis_label = '';
				independent_axis_parameter = '';
				response_units = '';
				response_label = '';

				doc = ndi_app_stimulus_response_obj.experiment.newdocument('data/stimulus_response_summary', ...
						'stimulus_response_summary.independent_axis_units', independent_axis_units, ...
						'stimulus_response_summary.independent_axis_label', independent.axis_label, ...
						'stimulus_response_summary.independent_axis_parameter', independent_axis_parameter, ...
						'stimulus_response_summary.response_units', response_units, ...
						'stimulus_response_summary.response_label', response_label, ...
						'stimulus_response_summary.independent_axis_values', '', ...
						'stimulus_response_summary.mean_responses', responses.mean_responses, ...
						'stimulus_response_summary.stddev_responses', responses.stddev_responses, ...
						'stimulus_response_summary.stderr_responses', responses.stderr_responses, ...
						'stimulus_response_summary.individual_responses', responses.individual_responses, ...
						'stimulus_response_summary.blank_response.mean_responses', responses.blank_mean, ...
						'stimulus_response_summary.blank_response.stddev_responses', responses.blank_stddev, ...
						'stimulus_response_summary.blank_response.stderr_responses', responses.blank_stderr, ...
						'stimulus_response_summary.blank_response.individual_responses', responses.blank_individual_responses ...
						) + ndi_app_stimulus_response_obj.newdocument();

		end; % analyze_1d_tuning_curve

	end; % methods

end % ndi_app_stimulus_response


