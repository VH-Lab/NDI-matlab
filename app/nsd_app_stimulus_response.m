classdef nsd_app_stimulus_response < nsd_app

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function nsd_app_stimulus_response_obj = nsd_app_stimulus_response(varargin)
			% NSD_APP_STIMULUS_RESPONSE - an app to help exclude garbage data from experiments
			%
			% NSD_APP_STIMULUS_RESPONSE_OBJ = NSD_APP_STIMULUS_RESPONSE(EXPERIMENT)
			%
			% Creates a new NSD_APP_STIMULUS_RESPONSE object that can operate on
			% NSD_EXPERIMENTS. The app is named 'nsd_app_stimulus_response'.
			%
				experiment = [];
				name = 'nsd_app_stimulus_response';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				nsd_app_stimulus_response_obj = nsd_app_stimulus_response_obj@nsd_app(experiment, name);

		end % nsd_app_stimulus_response() creator

		function doc = compute_stimulus_response_summary(nsd_app_stimulus_response_obj, nsd_probe_stim, nsd_probe_measure, timeref, t0, t1, varargin)
			% COMPUTE_STIMULUS_RESPONSE_SUMMARY - compute responses to a stimulus set
			%
			% DOC = COMPUTE_STIMULUS_RESPONSE_SUMMARY(NSD_APP_STIMULUS_RESPONSE_APP, NSD_PROBE_STIM, NSD_PROBE_MEASURE, TIMEREF, T0, T1, ...)
			%
			% 
			%
			% Uses the app NSD_APP_MARKGARBAGE to limit analysis to intervals that have been
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

				[data,t_raw,timeref] = readtimeseries(sharpprobe, timeref, t0, t0);

				gapp = nsd_app_markgarbage(nsd_app_stimulus_response_obj.experiment);
				vi = gapp.loadvalidinterval(sharpprobe);
				interval = gapp.identifyvalidintervals(sharpprobe,timeref,t0,t1)

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

				doc = nsd_app_stimulus_response_obj.experiment.newdocument('data/stimulus_response_summary', ...
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
						'stimulus_response_summary.blank_response.individual_responses', responses.blank_individual_responses, ...
						) + nsd_app_stimulus_response_obj.newdocument();
				
		end % compute_stimulus_response_summary()

		function b = savevalidinterval(nsd_app_stimulus_response_obj, nsd_epochset_obj, validintervalstruct)
			% SAVEVALIDINTERVAL - save a valid interval structure to the experiment database
			%
			% B = SAVEVALIDINTERVAL(NSD_APP_STIMULUS_RESPONSE_OBJ, NSD_EPOCHSET_OBJ, VALIDINTERVALSTRUCT)
			%
			% Saves a VALIDINTERVALSTRUCT to an experment database, in the appropriate place for
			% the NSD_EPOCHSET_OBJ data.
			%
			% If the entry is a duplicate, it is not saved but b is still 1.
			%

				if ~isa(nsd_epochset_obj, 'nsd_probe'),
					error(['do not know how to handle non-probes yet.']);
				end

				[vi,mydoc] = nsd_app_stimulus_response_obj.loadvalidinterval(nsd_epochset_obj);
				b = 1;
			
				match = -1;
				for i=1:numel(vi),
					if eqlen(vi(i),validintervalstruct),
						match = i; 
						return; 
					end;
				end

				% if we are here, we found no match
				vi(end+1) = validintervalstruct;

				% save new variable, clearing old
				nsd_app_stimulus_response_obj.clearvalidinterval(nsd_epochset_obj);
				newdoc = nsd_app_stimulus_response_obj.experiment.newdocument('apps/markgarbage/valid_interval',...
						'valid_interval',vi) +  ...
					nsd_epochset_obj.newdocument() + nsd_app_stimulus_response_obj.newdocument(); % order of operations matters! superclasses last
				nsd_app_stimulus_response_obj.experiment.database.add(newdoc);
		end; % savevalidinterval()

		function b = clearvalidinterval(nsd_app_stimulus_response_obj, nsd_epochset_obj)
			% CLEARVALIDINTERVAL - clear all 'validinterval' records for an NSD_EPOCHSET from experiment database
			% 
			% B = CLEARVALIDINTERVAL(NSD_APP_STIMULUS_RESPONSE_OBJ, NSD_EPOCHSET_OBJ)
			%
			% Clears all valid interval entries from the experiment database for object NSD_EPOCHSET_OBJ.
			%
			% Returns 1 on success, 0 otherwise.
			%
			% See also: NSD_APP_STIMULUS_RESPONSE/MARKVALIDINTERVAL, NSD_APP_STIMULUS_RESPONSE/SAVEALIDINTERVAL, ...
			%      NSD_APP_STIMULUS_RESPONSE/LOADVALIDINTERVAL 

				[vi,mydoc] = nsd_app_stimulus_response_obj.loadvalidinterval(nsd_epochset_obj);

				if ~isempty(mydoc),
					nsd_app_stimulus_response_obj.experiment.database.remove(mydoc);
				end

		end % clearvalidinteraval()

		function [vi,mydoc] = loadvalidinterval(nsd_app_stimulus_response_obj, nsd_epochset_obj)
			% LOADVALIDINTERVAL - Load all valid interval records from experiment database
			%
			% [VI,MYDOC] = LOADVALIDINTERVAL(NSD_APP_STIMULUS_RESPONSE_OBJ, NSD_EPOCHSET_OBJ)
			%
			% Loads stored valid interval records generated by NSD_APP_STIMULUS_RESPONSE/MAKEVALIDINTERVAL
			%
			% MYDOC is the NSD_DOCUMENT that was loaded.
			%
				vi = emptystruct('timeref_structt0','t0','timeref_structt1','t1');

				warning(['not general: if subclass of markgarbage-valid_interval is created, this will fail (issue #88).']);
				searchq = cat(2,nsd_app_stimulus_response_obj.searchquery(), ...
					{'document_class.class_name','valid_interval'});

				if isa(nsd_epochset_obj,'nsd_probe'),
					searchq = cat(2,searchq,nsd_epochset_obj.searchquery());
				end

				mydoc = nsd_app_stimulus_response_obj.experiment.database.search(searchq);

				if ~isempty(mydoc),
					for i=1:numel(mydoc),
						vi = cat(1,vi,mydoc{i}.document_properties.valid_interval);
					end;
				end;
		end % loadvalidinterval()

		function [intervals] = identifyvalidintervals(nsd_app_stimulus_response_obj, nsd_epochset_obj, timeref, t0, t1)
			% IDENTIFYVALIDINTERVAL - identify valid region within an interval
			%
			% INTERVALS = IDENTIFYVALIDINTERVALS(NSD_APP_STIMULUS_RESPONSE_OBJ, NSD_EPOCHSET_OBJ, TIMEREF, T0, T1)
			%
			% Examines whether there is a stored 'validinterval' variable by the app 'nsd_app_stimulus_response' for
			% this NSD_EPOCHSET_OBJ, and, if so, returns valid intervals [t1_0 t1_1; t2_0 t2_1; ...] indicating
			% valid snips of data within the range T0 T1 (with respect to NSD_TIMEREFERENCE object TIMEREF).
			% INTERVALS has time with respect to TIMEREF.
			%
				% disp(['Call of identifyvalidintervals..']);
				baseline_interval = [t0 t1];
				explicitly_good_intervals = [];
				vi = nsd_app_stimulus_response_obj.loadvalidinterval(nsd_epochset_obj);
				if isempty(vi),
					return;
				end;
				for i=1:size(vi,1),
					% for each marked valid region
					%    Can we project the marked valid region into this timeref?
						interval_t0_timeref = nsd_timereference(nsd_app_stimulus_response_obj.experiment, vi(i).timeref_structt0);
						interval_t1_timeref = nsd_timereference(nsd_app_stimulus_response_obj.experiment, vi(i).timeref_structt1);
						[epoch_t0_out, epoch_t0_timeref, msg_t0] = ...
								nsd_app_stimulus_response_obj.experiment.syncgraph.time_convert(interval_t0_timeref, ...
									vi(i).t0, timeref.referent, timeref.clocktype);
						[epoch_t1_out, epoch_t1_timeref, msg_t1] = ...
								nsd_app_stimulus_response_obj.experiment.syncgraph.time_convert(interval_t1_timeref, ...
									vi(i).t1, timeref.referent, timeref.clocktype);
						if isempty(epoch_t0_out) | isempty(epoch_t1_out),
							% so we say the region is valid, we have no restrictions to add
						elseif ~strcmp(epoch_t0_timeref.epoch,timeref.epoch) | ~strcmp(epoch_t1_timeref.epoch,timeref.epoch),
							% we can find a match but not in the right epoch
						else, % we have to carve out a bit of this region
							% do we need to check that epoch_t0_timeref matches our timeref? I think it is guaranteed
							explicitly_good_intervals = interval_add(explicitly_good_intervals, [epoch_t0_out epoch_t1_out]);
						end;
				end;
				if isempty(explicitly_good_intervals),
					intervals = baseline_interval;
				else,
					intervals = explicitly_good_intervals;
				end;
				
		end; % identifyvalidinterval

	end; % methods

end % nsd_app_stimulus_response


