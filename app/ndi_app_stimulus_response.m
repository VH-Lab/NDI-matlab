classdef ndi_app_stimulus_response < ndi_app

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_stimulus_response_obj = ndi_app_stimulus_response(varargin)
			% NDI_APP_STIMULUS_RESPONSE - an app to help exclude garbage data from experiments
			%
			% NDI_APP_STIMULUS_RESPONSE_OBJ = NDI_APP_STIMULUS_RESPONSE(EXPERIMENT)
			%
			% Creates a new NDI_APP_STIMULUS_RESPONSE object that can operate on
			% NDI_EXPERIMENTS. The app is named 'ndi_app_stimulus_response'.
			%
				experiment = [];
				name = 'ndi_app_stimulus_response';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				ndi_app_stimulus_response_obj = ndi_app_stimulus_response_obj@ndi_app(experiment, name);

		end % ndi_app_stimulus_response() creator

		function doc = compute_stimulus_response_summary(ndi_app_stimulus_response_obj, ndi_probe_stim, ndi_timeseries_obj, timeref, t0, t1, varargin)
			% COMPUTE_STIMULUS_RESPONSE_SUMMARY - compute responses to a stimulus set
			%
			% DOC = COMPUTE_STIMULUS_RESPONSE_SUMMARY(NDI_APP_STIMULUS_RESPONSE_APP, NDI_PROBE_STIM, NDI_TIMESERIES_OBJ, TIMEREF, T0, T1, ...)
			%
			% 
			%
			% Uses the app NDI_APP_MARKGARBAGE to limit analysis to intervals that have been
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

				gapp = ndi_app_markgarbage(ndi_app_stimulus_response_obj.experiment);
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
						'stimulus_response_summary.blank_response.individual_responses', responses.blank_individual_responses, ...
						) + ndi_app_stimulus_response_obj.newdocument();
				
		end % compute_stimulus_response_summary()

	end; % methods

end % ndi_app_stimulus_response


