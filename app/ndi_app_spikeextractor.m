classdef ndi_app_spikeextractor < ndi_app

	properties (SetAccess=protected,GetAccess=public)


	end % properties

	methods

		function ndi_app_spikeextractor_obj = ndi_app_spikeextractor(varargin)
			% NDI_APP_SPIKEEXTRACTOR - an app to extract probes found in experiments
			%
			% NDI_APP_SPIKEEXTRACTOR_OBJ = NDI_APP_SPIKEEXTRACTOR(EXPERIMENT)
			%
			% Creates a new NDI_APP_SPIKEEXTRACTOR object that can operate on
			% NDI_EXPERIMENTS. The app is named 'ndi_app_spikeextractor'.
			%
				experiment = [];
				name = 'ndi_app_spikeextractor';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				ndi_app_spikeextractor_obj = ndi_app_spikeextractor_obj@ndi_app(experiment, name);

		end % ndi_app_spikeextractor() creator

		function filterstruct = makefilterstruct(ndi_app_spikeextractor_obj, extraction_doc, sample_rate)
			% MAKEFILTERSTRUCT - make a filter structure for a given sampling rate and extraction parameters
			%
			% FILTERSTRUCT = MAKEFILTERSTRUCT(NDI_APP_SPIKEEXTRACTOR_OBJ, EXTRACTION_DOC, SAMPLE_RATE)
			%
			% Given an EXTRACTION_DOC of parameters and a sampling rate SAMPLE_RATE, make a filter
			% structure for passing to FILTERDATA.
			%
				switch(extraction_doc.document_properties.spike_extraction_parameters.filter_type),
					case 'cheby1high',
						[b,a] = cheby1(extraction_doc.document_properties.spike_extraction_parameters.filter_order, ...
								extraction_doc.document_properties.spike_extraction_parameters.filter_ripple, ...
								extraction_doc.document_properties.spike_extraction_parameters.filter_high/(0.5*sample_rate),'high');
						filterstruct = struct('b',b,'a',a);
					case 'none',
						filterstruct = [];
					otherwise,
						error(['Unknown filter type: ' extraction_doc.document_properties.spike_extraction_parameters.filter_type]);
				end;
		end; % makefilterstruct()

		function data_out = filter(ndi_app_spikeextractor_obj, data_in, filterstruct)
			% FILTER - filter data based on a filter structure
			%
			% DATA_OUT = FILTER(NDI_APP_SPIKEEXTRACTOR_OBJ, DATA_IN, FILTERSTRUCT)
			%
			% Filters data based on FILTERSTRUCT (see NDI_APP_SPIKEEXTRACTOR/MAKEFILTERSTRUCT)
			%
				if isempty(filterstruct),
					data_out = data_in;
				else,
					data_out = filtfilt(filterstruct.b,filterstruct.a,data_in);
				end;
		end; % filter()

		function extract(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name, redo, t0_t1)
			% EXTRACT - method that extracts spikes from epochs of an NDI_TIMESERIES_OBJ (such as NDI_PROBE or NDI_THING)
			%
			% EXTRACT(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_PARAMS, EXTRACTION_NAME, [REDO], [T0 T1])
			% NAME is the probe name if any
			% TYPE is the type of probe if any
			% combination of NAME and TYPE must return at least one probe from experiment
			% EPOCH is an index number or id to select epoch to extract, or can be a cell array of epoch number/ids
			% EXTRACTION_NAME name given to find ndi_doc in database
			% EXTRACTION_PARAMS a struct or filepath (tab separated file) with extraction parameters
			% REDO - if 1, then extraction is re-done for epochs even if it has been done before with same extraction parameters

				ndi_globals;


				if ndi_debug.veryverbose,
					disp(['Beginning of extract']);
				end;

				% process input arguments

				if isempty(epoch),
					et = epochtable(ndi_timeseries_obj);
					epoch = {et.epoch_id};
				elseif ~iscell(epoch),
					epoch = {epoch};
				end;

				extraction_doc = ndi_app_spikeextractor_obj.experiment.database_search({'ndi_document.name',extraction_name,'spike_extraction_parameters.filter_type','(.*)'});
				if isempty(extraction_doc),
					error(['No spike_extraction_parameters document named ' extraction_name ' found.']);
				elseif numel(extraction_doc)>1,
					error(['More than one extraction_parameters document with same name. Should not happen but needs to be fixed.']);
				else,
					extraction_doc = extraction_doc{1};
				end;

				if nargin<5,
					redo = 0;
				end;

				if nargin<6,
					t0_t1 = repmat([-Inf Inf],numel(epoch),1);
				end;

				% loop over requested epochs
				for n=1:numel(epoch),
					epoch_string = ndi_timeseries_obj.epoch2str(epoch{n});

					if ndi_debug.veryverbose,
						disp(['Beginning to set up for epoch ' epoch_string '.']);
					end;

					% begin an epoch, get ready


					spikewaves_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
						{'epochid', epoch_string, 'spikewaves.extraction_name', extraction_name});
					old_spikewaves_doc = ndi_app_spikeextractor_obj.experiment.database_search(spikewaves_searchq);
					spiketimes_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
						{'epochid', epoch_string, 'spiketimes.extraction_name', extraction_name});
					old_spiketimes_doc = ndi_app_spikeextractor_obj.experiment.database_search(spiketimes_searchq);

					if (~isempty(old_spikewaves_doc) & ~isempty(old_spiketimes_doc)) & ~redo,
						% we already have this epoch
						continue; % skip to next epoch
					end;

					sample_rate = ndi_timeseries_obj.samplerate(epoch{n});
					data_example = ndi_timeseries_obj.readtimeseries(epoch{n},0,1/sample_rate); % read a single sample
					start_sample = ndi_timeseries_obj.times2samples(epoch{n},t0_t1(n,1));
					if isnan(start_sample), start_sample = 1; end;
					read_start_sample = start_sample;
					end_sample =  ndi_timeseries_obj.times2samples(epoch{n},t0_t1(n,2));
					if isnan(end_sample), end_sample = Inf; end;
					endReached = 0; % Variable to know if end of file reached

					% convert from parameter file units of time to samples here
					center_range_samples = ceil(extraction_doc.document_properties.spike_extraction_parameters.center_range_time * sample_rate);
					refractory_samples = round(extraction_doc.document_properties.spike_extraction_parameters.refractory_time * sample_rate);
					spike_sample_start = floor(extraction_doc.document_properties.spike_extraction_parameters.spike_start_time * sample_rate);
					spike_sample_end = ceil(extraction_doc.document_properties.spike_extraction_parameters.spike_end_time * sample_rate);
					%interpolation = extraction_doc.document_properties.spike_extraction_parameters.interpolation;

					filterstruct = ndi_app_spikeextractor_obj.makefilterstruct(extraction_doc, sample_rate);

					% Clear extraction within probe with extraction_name
					ndi_app_spikeextractor_obj.clear_spikewaves_doc(ndi_timeseries_obj, epoch{n}, extraction_name);
					ndi_app_spikeextractor_obj.clear_spiketimes_doc(ndi_timeseries_obj, epoch{n}, extraction_name);

					% Create spikes ndi_doc
					spikes_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/spikewaves', ...
							'spikewaves.extraction_name', extraction_name, ...
							'spikewaves.extraction_parameters_file_id', extraction_doc.doc_unique_id(),...
							'spikewaves.sample_rate', sample_rate,...
							'spikewaves.s0', extraction_doc.document_properties.spike_extraction_parameters.spike_start_time,...
							'spikewaves.s1', extraction_doc.document_properties.spike_extraction_parameters.spike_end_time,...
							'epochid', epoch_string) ...
							+ ndi_timeseries_obj.newdocument(epoch_string) + ndi_app_spikeextractor_obj.newdocument();

					% Create times ndi_doc
					times_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/spiketimes', ...
							'spiketimes.extraction_name', extraction_name, ...
							'spiketimes.extraction_parameters_file_id', extraction_doc.doc_unique_id(), ...
							'epochid', epoch_string) ...
							+ ndi_timeseries_obj.newdocument(epoch_string) + ndi_app_spikeextractor_obj.newdocument();

					% Add docs to database
					ndi_app_spikeextractor_obj.experiment.database_add(spikes_doc);
					ndi_app_spikeextractor_obj.experiment.database_add(times_doc);

					% temporary or maybe permanent: cutting interpolation from this part, will use it in calculating features
					% Required vectors for interpolation
					%spikelength = spike_sample_end - spike_sample_start + 1;
					%x = [spike_sample_start:spike_sample_end];
					%xq = [spike_sample_start:(1/interpolation):spike_sample_end]; % ex: 1/3 sets up interpolation at 3x
					%[I,V]=findclosest(xq,0);
					%xq(I) = 0; % make sure center is exactly 0

					% add header to spikes_doc
					fileparameters.numchannels = size(data_example,2);
					fileparameters.S0 = spike_sample_start;    %  -1*numel(find(xq<0)); the commented code is wrong, even if using interpolation
					fileparameters.S1 = spike_sample_end;      % numel(find(xq>0)); the commented code is wrong, even if using interpolation
					fileparameters.name = spikes_doc.doc_unique_id();
					fileparameters.ref =  0;
					fileparameters.comment = epoch_string; %epoch 
					fileparameters.samplingrate = double(sample_rate);

					spikewaves_binarydoc = ndi_app_spikeextractor_obj.experiment.database_openbinarydoc(spikes_doc);
					newvhlspikewaveformfile(spikewaves_binarydoc, fileparameters); 
					spiketimes_binarydoc = ndi_app_spikeextractor_obj.experiment.database_openbinarydoc(times_doc); % we will just write double data here

					% leave these files open while we extract

					epochtic = tic; % Timer variable to measure duration of epoch extraction
					disp(['Epoch ' ndi_timeseries_obj.epoch2str(epoch{n}) ' spike extraction started...']);

					% now read the file in chunks
					while (~endReached)
						read_end_sample = ceil(read_start_sample + extraction_doc.document_properties.spike_extraction_parameters.read_time * sample_rate); % end sample for chunk to read
						if read_end_sample > end_sample,
							read_end_sample = end_sample;
						end;
						% Read from probe in epoch n from start_time to end_time
						read_times = ndi_timeseries_obj.samples2times(epoch{n}, [read_start_sample read_end_sample]);
						data = ndi_timeseries_obj.readtimeseries(epoch{n}, read_times(1), read_times(2)); 
						%size(data), end_sample-start_sample+1  % display sizes of data read

						% Checks if endReached by a threshold sample difference (data - (end_time - start_time))
						if (size(data,1) - ((read_end_sample - read_start_sample) + 1)) < 0 % if we got less than we asked for, we are done
							endReached = 1;
						elseif read_end_sample==end_sample,
							endReached = 1;
						end

						if ~isempty(filterstruct),
							data = ndi_app_spikeextractor_obj.filter(data,filterstruct);
						end;

						if 0,
						figure(10);
						plot(data);
						hold on;
						AX=axis;
						plot([AX(1) AX(2)], [1 1]*extraction_doc.document_properties.spike_extraction_parameters.threshold_parameter,'k--');
						hold off;
						pause(2);
						end;

						% Spike locations stored here
						locs = [];

						% For number of channels
						for channel=1:size(data_example,2) %channel
							locs_here = [];
							switch extraction_doc.document_properties.spike_extraction_parameters.threshold_method,
								case 'standard_deviation',
									% Calculate stdev for channel
									stddev = std(data(:,channel));
									% Dot discriminator to find thresholds CHECK complex matlab c code running here, potential source of bugs in demo
									locs_here = dotdisc(double(data(:,channel)), ...
										[extraction_doc.document_properties.spike_extraction_parameters.threshold_parameter*stddev ...
											extraction_doc.document_properties.spike_extraction_parameters.threshold_sign  0]); 
								case 'absolute',
									locs_here = dotdisc(double(data(:,channel)), ...
										[extraction_doc.document_properties.spike_extraction_parameters.threshold_parameter ...
											extraction_doc.document_properties.spike_extraction_parameters.threshold_sign  0]); 
								otherwise,
									error(['unknown threshold method']);
							end
							%Accomodates spikes according to refractory period
							%locs_here = refractory(locs_here, refractory_samples); % only apply to all events
							locs_here = locs_here(find(locs_here > -spike_sample_start & locs_here <= length(data(:,channel))-spike_sample_end));
							locs = [locs(:) ; locs_here];
						end % for

						% Sorts locs
						locs = sort(locs);
						% Apply refractory period to all events
						locs = refractory(locs, refractory_samples);

						sample_offsets = repmat([spike_sample_start:spike_sample_end]',1,size(data,2));
						channel_offsets = repmat([0:size(data,2)-1], spike_sample_end - spike_sample_start + 1,1);
						single_spike_selection = sample_offsets + channel_offsets*size(data,1);
						spike_selections = repmat(single_spike_selection(:)', length(locs), 1) + repmat(locs(:), 1, prod(size(sample_offsets)));
						waveforms = single(data(spike_selections))'; % (spike-spike-spike-spike) X Nspikes

						waveforms = reshape(waveforms, spike_sample_end - spike_sample_start + 1, size(data,2), length(locs)); % Nsamples X Nchannels X Nspikes
						waveforms = permute(waveforms,[3 1 2]); % Nspikes X Nsamples X Nchannels

						%Center spikes; if threshold is low-to-high, flip sign (assume positive-spikes)
						waveforms = (-1*extraction_doc.document_properties.spike_extraction_parameters.threshold_sign)*centerspikes_neg( ...
							(-1*extraction_doc.document_properties.spike_extraction_parameters.threshold_sign)*waveforms,center_range_samples);

						% Permute waveforms for addvhlspikewaveformfile to Nsamples X Nchannels X Nspikes
						waveforms = permute(waveforms, [2 3 1]);

						%size(waveforms),

						% Interpolation of waveforms, cutting for now

						if 0, % interpolation>1,
							% For number of spikes
							for i=1:size(waveforms, 3);
								waveforms_out(:,:,i) = interp1(x, waveforms(:,:,i), xq, 'spline');
							end
						elseif 0,
							waveforms_out = waveforms;
						end;
						% Store epoch waveforms in file
						addvhlspikewaveformfile(spikewaves_binarydoc, waveforms);
					  
						% Store epoch spike times in file
						spiketimes_binarydoc.fwrite(ndi_timeseries_obj.samples2times(epoch{n},read_start_sample-1+locs),'float32');
						read_start_sample = round(read_start_sample + extraction_doc.document_properties.spike_extraction_parameters.read_time * sample_rate - ...
								extraction_doc.document_properties.spike_extraction_parameters.overlap * sample_rate);
					end % while ~endReached

					ndi_app_spikeextractor_obj.experiment.database_closebinarydoc(spikewaves_binarydoc);
					ndi_app_spikeextractor_obj.experiment.database_closebinarydoc(spiketimes_binarydoc);
					disp(['Epoch ' int2str(n) ' spike extraction done.']);
				end % epoch n
		end % extract

		function extraction_doc = add_extraction_doc(ndi_app_spikeextractor_obj, extraction_name, extraction_params)
			% ADD_EXTRACTION_DOC - add extraction parameters document
			%
			% EXTRACTION_DOC = ADD_EXTRACTION_DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, EXTRACTION_NAME, EXTRACTION_PARAMS)
			%
			% Given EXTRACTION_PARAMS as either a structure or a filename, this function returns
			% EXTRACTION_DOC parameters as an NDI_DOCUMENT and checks its fields. If EXTRACTION_PARAMS is empty,
			% then the default parameters are returned. If EXTRACTION_NAME is already the name of an existing
			% NDI_DOCUMENT then an error is returned.
			%
			% EXTRACTION_PARAMS should contain the following fields:
			% Fieldname              | Description
			% -------------------------------------------------------------------------
			% center_range (10)         | Range in samples to find spike center
			% overlap (0.5)             | Overlap allowed
			% read_time (30)            | Number of seconds to read in at a single time
			% refractory_samples (10)   | Number of samples to use as a refractory period
			% spike_sample_start (-9)   | Samples before the threshold to include % unclear if time or sample
			% spike_sample_stop (20)    | Samples after the threshold to include % unclear if time or sample
			% start_time (1)            | First sample to read
			% do_filter (1)             | Should we perform a filter? (0/1)
			% filter_type               | What filter? Default is 'cheby1high' but can also be 'none'
			%  ('cheby1high')           | 
			% filter_low (0)            | Low filter frequency
			% filter_high (300)         | Filter high frequency
			% filter_order (4)          | Filter order
			% filter_ripple (0.8)       | Filter ripple parameter
			% threshold_method          | Threshold method. Can be "standard_deviation" or "absolute"
			% threshold_parameter       | Threshold parameter. If threshold_method is "standard_deviation" then
			%    ('standard_deviation') |    this parameter is multiplied by the empirical standard deviation.
			%                           |    If "absolute", then this value is taken to be the absolute threshold.
			% threshold_sign (-1)       | Threshold crossing sign (-1 means high-to-low, 1 means low-to-high)
			% 
				if nargin<3,
					extraction_params = [];
				end;

					% search for any existing documents with that name; any doc that has that name and spike_extraction_parameters as a field
				searchq = {'ndi_document.name',extraction_name,'spike_extraction_parameters.filter_type','(.*)'};
				mydoc = ndi_app_spikeextractor_obj.experiment.database_search(searchq);
				if ~isempty(mydoc),
					error([int2str(numel(mydoc)) ' spike_extraction_parameters documents with name ''' extraction_name ''' already exist(s).']);
				end;

				% okay, we can build a new document


				if isempty(extraction_params),
					extraction_params = ndi_document('apps/spikeextractor/spike_extraction_parameters') + ...
						ndi_app_spikeextractor_obj.newdocument();
					% this function needs a structure
					extraction_params = extraction_params.document_properties.spike_extraction_parameters; 
				elseif isa(extraction_params,'ndi_document'),
					% this function needs a structure
					extraction_params = extraction_params.document_properties.spike_extraction_parameters; 
				elseif isa(extraction_params, 'char') % loading struct from file 
					extraction_parameters = loadStructArray(extraction_params);
				elseif isstruct(extraction_params),
					% If extraction_params was inputed as a struct then no need to parse it
				else
					error('unable to handle extraction_params.');
				end

				% now we have a extraction_params as a structure

				% check parameters here
				fields_needed = {'center_range_time','overlap','read_time','refractory_time',...
					'spike_start_time','spike_end_time',...
					'do_filter', 'filter_type','filter_low','filter_high','filter_order','filter_ripple',...
					'threshold_method','threshold_parameter','threshold_sign'};
				sizes_needed = {[1 1], [1 1], [1 1], [1 1],...
					[1 1],[1 1],...
					[1 1],[1 -1],[1 1],[1 1],[1 1],[1 1],...
					[1 -1], [1 1], [1 1]};

				[good,errormsg] = hasAllFields(extraction_params,fields_needed, sizes_needed);

				if ~good,
					error(['Error in extraction_parameters: ' errormsg]);
				end;

				% now we need to convert to an ndi_document

				extraction_doc = ndi_document('apps/spikeextractor/spike_extraction_parameters','spike_extraction_parameters',extraction_params) + ...
					ndi_app_spikeextractor_obj.newdocument() + ndi_document('ndi_document','ndi_document.name',extraction_name);

				ndi_app_spikeextractor_obj.experiment.database_add(extraction_doc);

		end; % add_extraction_doc

		function b = clear_extraction_parameters(ndi_app_spikeextractor_obj, extraction_name)
		% CLEAR_EXTRACTION_PARAMETERS - clear all 'spikewaves' records for an NDI_PROBE_OBJ from experiment database
		%
		% B = CLEAR_EXTRACTIONPARAMETERS(NDI_APP_SPIKEEXTRACTOR_OBJ, EXTRACTION_NAME)
		%
		% Clears all extraction parameters with name EXTRACTION_NAME. 
		% 
		%
		% Returns 1 on success, 0 otherwise.
		%%%
		% See also: NDI_APP_MARKGARBAGE/MARKVALIDINTERVAL, NDI_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
		%      NDI_APP_MARKGARBAGE/LOADVALIDINTERVAL

			% Look for any docs matching extraction name and remove them
			% Concatenate app query parameters and extraction_name parameter
			extract_searchq = {'ndi_document.name', extraction_name,'spike_extraction_parameters.filter_type','(.*)'};
			extract_doc = ndi_app_spikeextractor_obj.experiment.database_search(extract_searchq);
			if ~isempty(extract_doc),
				ndi_app_spikeextractor_obj.experiment.database_rm(extract_doc);
			end;
			b = 1;

		end % clear_extraction_parameters()

		function b = clear_spikewaves_doc(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
		% CLEARSPIKEWAVES - clear all 'spikewaves' records for an NDI_PROBE_OBJ from experiment database
		%
		% B = CLEARSPIKEWAVES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_EPOCHSET_OBJ)
		%
		% Clears all spikewaves entries from the experiment database for object NDI_PROBE_OBJ.
		%
		% Returns 1 on success, 0 otherwise.
		%%%
		% See also: NDI_APP_MARKGARBAGE/MARKVALIDINTERVAL, NDI_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
		%      NDI_APP_MARKGARBAGE/LOADVALIDINTERVAL

			% Look for any docs matching extraction name and remove them
			% Concatenate app query parameters and extraction_name parameter
			extract_searchq = {'ndi_document.name', extraction_name, 'spike_extraction_parameters.filter_type','(.*)'};
			extract_doc = ndi_app_spikeextractor_obj.experiment.database_search(extract_searchq);
			epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
			if ~isempty(extract_doc),
				for i=1:numel(extract_doc),
					spikewaves_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
						{'epochid', epoch_string, 'spikewaves.extraction_name', extraction_name});
					mydoc = ndi_app_spikeextractor_obj.experiment.database_search(spikewaves_searchq);
					ndi_app_spikeextractor_obj.experiment.database_rm(mydoc);
				end;
			end;
			b = 1;
		end; % clear_spikewaves_doc()

		function b = clear_spiketimes_doc(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
		% CLEARSPIKETIMES - clear all 'spiketimes' records for an NDI_TIMESERIES_OBJ from experiment database
		%
		% B = CLEAR_SPIKETIMES_DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, NDI_EPOCHSET_OBJ)
		%
		% Clears all spikewaves entries from the experiment database for object NDI_PROBE_OBJ.
		%
		% Returns 1 on success, 0 otherwise.
		%%%
		% See also: NDI_APP_MARKGARBAGE/MARKVALIDINTERVAL, NDI_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
		%      NDI_APP_MARKGARBAGE/LOADVALIDINTERVAL

			% Look for any docs matching extraction name and remove them
			% Concatenate app query parameters and extraction_name parameter
			extract_searchq = {'ndi_document.name', extraction_name, 'spike_extraction_parameters.filter_type','(.*)'};
			extract_doc = ndi_app_spikeextractor_obj.experiment.database_search(extract_searchq);
			if ~isempty(extract_doc),
				epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
				times_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
					{'epochid', epoch_string, 'spiketimes.extraction_name', extraction_name});
				mydoc = ndi_app_spikeextractor_obj.experiment.database_search(times_searchq);
				ndi_app_spikeextractor_obj.experiment.database_rm(mydoc);
			end;
			b = 1;
		end % clear_spiketimes_doc()

		function [waveforms,waveparameters] = load_spikewaves_epoch(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
			% LOAD_SPIKEWAVES_EPOCH - load spikewaves from an epoch
			%
			% [CONCATENATED_SPIKES, WAVEPARAMETERS] = LOAD_SPIKEWAVES_EPOCH(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
			%
			% WAVEPARAMETERS is a structure with the following fields:
			% Field              | Description
			% --------------------------------------------------------
			% numchannels        | Number of channels in each spike
			% S0                 | Number of samples before spike center
			%                    |    (usually negative)
			% S1                 | Number of samples after spike center
			%                    |    (usually positive)
			% samplerate         | The sampling rate
			%
			% Reads the spikewaves for an NDI_TIMESERIES object for a given EPOCH and EXTRACTION_NAME.
				epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
				spikewaves_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
					{'epochid', epoch_string, 'spikewaves.extraction_name', extraction_name});
				spikewaves_doc = ndi_app_spikeextractor_obj.experiment.database_search(spikewaves_searchq);
				
				if numel(spikewaves_doc)==1,
					spikewaves_doc = spikewaves_doc{1};
					spikewaves_binarydoc = ndi_app_spikeextractor_obj.experiment.database_openbinarydoc(spikewaves_doc);
					%[waveforms,header] = readvhlspikewaveformfile(spikewaves_binarydoc,-1,-1) 
					[waveforms,waveparameters] = readvhlspikewaveformfile(spikewaves_binarydoc);
					waveparameters.samplerate = waveparameters.samplingrate;
					ndi_app_spikeextractor_obj.experiment.database_closebinarydoc(spikewaves_binarydoc);
				elseif numel(spikewaves_doc)>1,
					error(['Found ' int2str(numel(spikewaves_doc)) ' documents matching the criteria. Do not know how to proceed.']);
				else,
					waveforms = [];
					waveparameters = [];
				end;
		end; % load_spikewaves_epoch

		function times = load_spiketimes_epoch(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
			% LOAD_SPIKEWAVES_EPOCH - load spikewaves from an epoch
			%
			% TIMES = LOAD_SPIKEWAVES_EPOCH(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
			%
			% Reads the spikewaves for an NDI_TIMESERIES object for a given EPOCH and EXTRACTION_NAME.
				epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
				spiketimes_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
					{'epochid', epoch_string, 'spiketimes.extraction_name', extraction_name});
				spiketimes_doc = ndi_app_spikeextractor_obj.experiment.database_search(spiketimes_searchq);
				
				if numel(spiketimes_doc)==1,
					spiketimes_doc = spiketimes_doc{1};
					spiketimes_binarydoc = ndi_app_spikeextractor_obj.experiment.database_openbinarydoc(spiketimes_doc);
					times = fread(spiketimes_binarydoc,Inf,'float32');
					ndi_app_spikeextractor_obj.experiment.database_closebinarydoc(spiketimes_binarydoc);
				elseif numel(spiketimes_doc)>1,
					error(['Found ' int2str(numel(spiketimes_doc)) ' documents matching the criteria. Do not know how to proceed.']);
				else,
					times = [];
				end;
	
		end; % load_spikewaves_epoch

		function concatenated_spikes = load_spikes(ndi_app_spikeextractor_obj, ndi_probe_obj, epoch, extraction_name)
		% LOADSPIKES - Load all spikewaves records from experiment database
		%
		% SW = LOADSPIKES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_PROBE_OBJ, EPOCH, EXTRACTION_NAME)
		%
		% Loads stored spikewaves generated by NDI_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
		%
			spikes_searchq = cat(2, ndi_app_spikeextractor_obj.searchquery(), ...
				{'document_class.class_name','spikes'});
			spikes_searchq = cat(2, spikes_searchq, ndi_probe_obj.searchquery());
			spikes_searchq = cat(2, spikes_searchq, ...
				{'spike_extraction.extraction_name', extraction_name});
			spikes_searchq = cat(2, spikes_searchq, ...
				{'spike_extraction.epoch', epoch});
			docs = ndi_app_spikeextractor_obj.experiment.database_search(spikes_searchq);

			% TODO How to get them in order? maybe add epoch_number to spikes and times ndi_doc
			if ~isempty(docs)
				% TODO make sure multiple epochs work
				for i=1:numel(docs)
					spikes_doc = ndi_app_spikeextractor_obj.experiment.database_search(ndi_query('ndi_document.id','exact_string',docs{i}.id,''));
					spikes_doc = celloritem(spikes_doc,1);
					spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database_openbinarydoc(spikes_doc);
					waveforms = [];

					header_size = 512; % 512 bytes in the header

					% step 1 - read header
					spikewaves_binarydoc_fid.fseek(0,'bof');
					parameters.numchannels = spikewaves_binarydoc_fid.fread(1,'uint8');      % now at 1 byte
					parameters.S0 = spikewaves_binarydoc_fid.fread(1,'int8');                % now at 2 bytes
					parameters.S1 = spikewaves_binarydoc_fid.fread(1,'int8');                % now at 3 bytes
					parameters.name = spikewaves_binarydoc_fid.fread(80,'char');             % now at 83 bytes
					parameters.name = char(parameters.name(find(parameters.name)))';
					parameters.ref = spikewaves_binarydoc_fid.fread(1,'uint8');              % now at 84 bytes
					parameters.comment = spikewaves_binarydoc_fid.fread(80,'char');          % now at 164 bytes
					parameters.comment = char(parameters.comment(find(parameters.comment)))';
					parameters.samplingrate = double(spikewaves_binarydoc_fid.fread(1,'float32'));

					% step 2 - read the waveforms
					my_wave_start = 1;
					my_wave_end = Inf;
					% each data points takes 4 bytes; the number of samples is equal to the number of channels
					% multiplied by the number of samples taken from each channel, which is S1-S0+1
					samples_per_channel = parameters.S1-parameters.S0+1;
					wave_size = parameters.numchannels * samples_per_channel;

					data_size = 4; % 32 bit floats

					if my_wave_start>0,
						spikewaves_binarydoc_fid.fseek(header_size+data_size*(my_wave_start-1)*wave_size,'bof'); % move to the right place in the file
						data_size_to_read = (my_wave_end-my_wave_start+1)*wave_size;
						waveforms = spikewaves_binarydoc_fid.fread(data_size_to_read,'float32');
						waves_actually_read = length(waveforms)/(parameters.numchannels*samples_per_channel);
						if abs(waves_actually_read-round(waves_actually_read))>0.0001,
							error(['Got an odd number of samples for these spikes. Corrupted file perhaps?']);
						end;
						concatenated_spikes = reshape(waveforms,samples_per_channel,parameters.numchannels,waves_actually_read);
					end;
					% TODO make sure multiple epochs work
					%if i > 1
					%	waveforms = cat(2,)
					ndi_app_spikeextractor_obj.experiment.database_closebinarydoc(spikewaves_binarydoc_fid);
				end
				% warning(['concatenated ' num2str(i) ' epochs(s) with same extraction name within probe'])
			end
		end % load_spikes()

		function concatenated_times = load_times(ndi_app_spikeextractor_obj, ndi_probe_obj, extraction_name)
		% LOADSPIKETIMES - Load all spiketimes records from experiment database
		%
		% ST = LOADSPIKETIMES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_PROBE_OBJ, EXTRACTION_NAME)
		%
		% Loads stored spiketimes generated by NDI_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
		%
			times_searchq = cat(2, ndi_app_spikeextractor_obj.searchquery(), ...
				{'document_class.class_name','times'});
			times_searchq = cat(2, times_searchq, ndi_probe_obj.searchquery());
			times_searchq = cat(2, times_searchq, ...
				{'spike_extraction.extraction_name',extraction_name});
			times_searchq = cat(2, spikes_searchq, ...
				{'spike_extraction.epoch', epoch});
			docs = ndi_app_spikeextractor_obj.experiment.database_search(times_searchq);

			% TODO How to get them in order? maybe add epoch_number to times and times ndi_doc
			if ~isempty(docs)
				% TODO make sure multiple epochs work
				for i=1:numel(docs)
					times_doc = ndi_app_spikeextractor_obj.experiment.database_search(ndi_query('ndi_document.id','exact_string',docs{i}.id(),''));
					times_doc = celloritem(times_doc,1);
					spiketimes_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database_openbinarydoc(times_doc);

					% step 1 - read header
					spiketimes_binarydoc_fid.fseek(0,'bof');
					parameters.numchannels = spiketimes_binarydoc_fid.fread(1,'uint8');      % now at 1 byte
					parameters.S0 = spiketimes_binarydoc_fid.fread(1,'int8');                % now at 2 bytes
					parameters.S1 = spiketimes_binarydoc_fid.fread(1,'int8');                % now at 3 bytes
					parameters.name = spiketimes_binarydoc_fid.fread(80,'char');             % now at 83 bytes
					parameters.name = char(parameters.name(find(parameters.name)))';
					parameters.ref = spiketimes_binarydoc_fid.fread(1,'uint8');              % now at 84 bytes
					parameters.comment = spiketimes_binarydoc_fid.fread(80,'char');          % now at 164 bytes
					parameters.comment = char(parameters.comment(find(parameters.comment)))';
					parameters.samplingrate = double(spiketimes_binarydoc_fid.fread(1,'float32'));

					spiketimes_binarydoc_fid.fseek( 512, 'bof');

					spiketimes = spiketimes_binarydoc_fid.fread(Inf,'float32');
					epoch = [parameters.ref];
					% 1xspiketimes
					epocharray = repmat(epoch, [1, size(spiketimes, 1)]);

					concatenated_times = cat(1, epocharray, spiketimes');
					% TODO make sure multiple epochs work
					% if i > 1
					%	waveforms = cat(2,)
					ndi_app_spikeextractor_obj.experiment.database_closebinarydoc(spiketimes_binarydoc_fid);
				end
				% warning(['concatenated ' num2str(i) ' epochs(s) with same extraction name within probe'])
			end
		end % loadspiketimes()

		function parameters = load_parameters(ndi_app_spikeextractor_obj, ndi_probe_obj)
		% LOAD_PARAMETERS - Load parameters matching the probe
		%
		% PARAMETERS = LOADSPIKES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_PROBE_OBJ, EXTRACTION_NAME)
		%
		% Loads stored spikewaves generated by NDI_APP_SPIKEEXTRACTOR/SPIKE_EXTRACT_PROBES
		%
			parameters_searchq = cat(2, ndi_app_spikeextractor_obj.searchquery(), ...
				{'document_class.class_name','extraction_parameters'});
			parameters_searchq = cat(2, parameters_searchq, ndi_probe_obj.searchquery());
			% TODO add extraction name as a feature
			% parameters_searchq = cat(2, parameters_searchq, ...
			%	{'spike_extraction.extraction_name',extraction_name});
			docs = ndi_app_spikeextractor_obj.experiment.database_search(parameters_searchq);

			% TODO How to get them in order? maybe add epoch_number to spikes and times ndi_doc
			if ~isempty(docs)
				% TODO make sure multiple epochs work
				for i=1:numel(docs)
					parameters_doc = ndi_app_spikeextractor_obj.experiment.database_search(ndi_query('ndi_document.id','exact_string',docs{i}.id(),''));
					parameters_doc = celloritem(parameters_doc,1);
					error('I do not think this next line will succeed.');
					spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.read(parameters_doc); % ??
					waveforms = [];

					header_size = 512; % 512 bytes in the header

						% step 1 - read header
					spikewaves_binarydoc_fid.fseek(0,'bof');
					parameters.numchannels = spikewaves_binarydoc_fid.fread(1,'uint8');      % now at 1 byte
					parameters.S0 = spikewaves_binarydoc_fid.fread(1,'int8');                % now at 2 bytes
					parameters.S1 = spikewaves_binarydoc_fid.fread(1,'int8');                % now at 3 bytes
					parameters.name = spikewaves_binarydoc_fid.fread(80,'char');             % now at 83 bytes
					parameters.name = char(parameters.name(find(parameters.name)))';
					parameters.ref = spikewaves_binarydoc_fid.fread(1,'uint8');              % now at 84 bytes
					parameters.comment = spikewaves_binarydoc_fid.fread(80,'char');          % now at 164 bytes
					parameters.comment = char(parameters.comment(find(parameters.comment)))';
					parameters.samplingrate= double(spikewaves_binarydoc_fid.fread(1,'float32'));

					% step 2 - read the waveforms
					my_wave_start = 1;
					my_wave_end = Inf;
					% each data points takes 4 bytes; the number of samples is equal to the number of channels
					%       multiplied by the number of samples taken from each channel, which is S1-S0+1
					samples_per_channel = parameters.S1-parameters.S0+1;
					wave_size = parameters.numchannels * samples_per_channel;

					data_size = 4; % 32 bit floats

					if my_wave_start>0,
						spikewaves_binarydoc_fid.fseek(header_size+data_size*(my_wave_start-1)*wave_size,'bof'); % move to the right place in the file
						data_size_to_read = (my_wave_end-my_wave_start+1)*wave_size;
						waveforms = spikewaves_binarydoc_fid.fread(data_size_to_read,'float32');
						waves_actually_read = length(waveforms)/(parameters.numchannels*samples_per_channel);
						if abs(waves_actually_read-round(waves_actually_read))>0.0001,
							error(['Got an odd number of samples for these spikes. Corrupted file perhaps?']);
						end;
						concatenated_spikes = reshape(waveforms,samples_per_channel,parameters.numchannels,waves_actually_read);
					end;
					% TODO make sure multiple epochs work
					% if i > 1
					%	waveforms = cat(2,)
				end
				% warning(['concatenated ' num2str(i) ' epochs(s) with same extraction name within probe'])
			end
		end % load_parameters()

	end % methods

end % ndi_app_spikeextractor
