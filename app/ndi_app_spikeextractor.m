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

		function extract(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name, redo)
			% EXTRACT - method that extracts spikes from epochs of an NDI_TIMESERIES_OBJ (such as NDI_PROBE or NDI_THING)
			%
			% EXTRACT(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_PARAMS, EXTRACTION_NAME, [REDO])
			% NAME is the probe name if any
			% TYPE is the type of probe if any
			% combination of NAME and TYPE must return at least one probe from experiment
			% EPOCH is an index number to select epoch to extract
			% EXTRACTION_NAME name given to find ndi_doc in database
			% EXTRACTION_PARAMS a struct or filepath (tab separated file) with extraction parameters
			% REDO - if 1, then extraction is re-done for epochs even if it has been done before with same extraction parameters

				% process input arguments

				if isempty(epoch),
					epoch = {et.epoch_id};
				elseif ~iscell(epoch),
					epoch = {epoch};
				end;

				extraction_doc = ndi_app_spikeextractor_obj.experiment.database_search({'ndi_document.name',extraction_name,'spike_extraction_parameters.filter_type','(.*)'}),
				if isempty(extraction_doc),
					error(['No spike_extraction_parameters document named ' extraction_name ' found.']);
				elseif numel(extraction_doc)>1,
					error(['More than one extraction_parameters document with same name. Should not happen but needs to be fixed.']);
				else,
					extraction_doc = extraction_doc{1};
				end;

				extraction_doc.document_properties.spike_extraction_parameters

				if nargin<6,
					redo = 0;
				end;

				% loop over requested epochs
				for n=1:numel(epoch),
					% begin an epoch, get ready

					epoch_string = ndi_timeseries_obj.epoch2str(epoch{n}),

					sample_rate = ndi_timeseries_obj.samplerate(epoch{n}),
					data_example = ndi_timeseries_obj.read_epochsamples(epoch{n},1,1); % read a single sample
					start_time = 1; % matlab doesn't zero count annoying
					start_sample = 1;
					endReached = 0; % Variable to know if end of file reached

					% convert from parameter file units of time to samples here
					center_range_samples = ceil(extraction_doc.document_properties.spike_extraction_parameters.center_range_time * sample_rate);
					refractory_samples = round(extraction_doc.document_properties.spike_extraction_parameters.refractory_time * sample_rate);
					spike_sample_start = floor(extraction_doc.document_properties.spike_extraction_parameters.spike_start_time * sample_rate);
					spike_sample_end = ceil(extraction_doc.document_properties.spike_extraction_parameters.spike_end_time * sample_rate);
					interpolation = extraction_doc.document_properties.spike_extraction_parameters.interpolation;

					filterstruct = ndi_app_spikeextractor_obj.makefilterstruct(extraction_doc, sample_rate);

					% Clear extraction within probe with extraction_name
					ndi_app_spikeextractor_obj.clear_spikewaves_doc(ndi_timeseries_obj, epoch, extraction_name);
					ndi_app_spikeextractor_obj.clear_spiketimes_doc(ndi_timeseries_obj, epoch, extraction_name);

					% Create spikes ndi_doc
					spikes_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/spikewaves', ...
							'spikewaves.extraction_name', extraction_name, ...
							'spikewaves.extraction_parameters_file_id', extraction_doc.doc_unique_id(),...
							'epochid', epoch_string) ...
							+ ndi_timeseries_obj.newdocument(epoch_string) + ndi_app_spikeextractor_obj.newdocument();
					spikes_doc.document_properties

					% Create times ndi_doc
					times_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/spiketimes', ...
							'spiketimes.extraction_name', extraction_name, ...
							'spiketimes.extraction_parameters_file_id', extraction_doc.doc_unique_id(), ...
							'epochid', epoch_string) ...
							+ ndi_timeseries_obj.newdocument(epoch_string) + ndi_app_spikeextractor_obj.newdocument();
					times_doc.document_properties

					% Add docs to database
					ndi_app_spikeextractor_obj.experiment.database.add(spikes_doc);
					ndi_app_spikeextractor_obj.experiment.database.add(times_doc);

					% Required vectors for interpolation
					spikelength = spike_sample_end - spike_sample_start + 1;
					x = [spike_sample_start:spike_sample_end];
					xq = [spike_sample_start:(1/interpolation):spike_sample_end]; % ex: 1/3 sets up interpolation at 3x
					[I,V]=findclosest(xq,0);
					xq(I) = 0; % make sure center is exactly 0

					% add header to spikes_doc
					fileparameters.numchannels = size(data_example,2);
					fileparameters.S0 = -1*numel(find(xq<0));
					fileparameters.S1 = numel(find(xq>0));
					fileparameters.name = spikes_doc.doc_unique_id();
					fileparameters.ref =  0;
					fileparameters.comment = epoch_string; %epoch 
					fileparameters.samplingrate = double(sample_rate),

					spikewaves_binarydoc = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(spikes_doc);
					newvhlspikewaveformfile(spikewaves_binarydoc, fileparameters); 
					spiketimes_binarydoc = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(times_doc); % we will just write double data here

					% leave these files open while we extract

					epochtic = tic; % Timer variable for measure duration of epoch extraction
					disp(['Epoch ' ndi_timeseries_obj.epoch2str(epoch{n}) ' spike extraction started...']);

					% now read the file in chunks
					while (~endReached)
						end_sample = ceil(start_sample + extraction_doc.document_properties.spike_extraction_parameters.read_time * sample_rate); % end sample for chunk to read
						% Read from probe in epoch n from start_time to end_time
						data = ndi_timeseries_obj.read_epochsamples(epoch{n},start_sample, end_sample); 
						size(data), end_sample-start_sample+1

						% Checks if endReached by a threshold sample difference (data - (end_time - start_time))
						if (size(data,1) - ((end_sample - start_sample) + 1)) < 0 % if we got less than we asked for, we are done
							endReached = 1;
						end

						if ~isempty(filterstruct),
							data = ndi_app_spikeextractor_obj.filter(data,filterstruct);
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
							locs_here = refractory(locs_here, refractory_samples);
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

						% Interpolation of waveforms

						if interpolation>1,
							% For number of spikes
							for i=1:size(waveforms, 3);
								waveforms_out(:,:,i) = interp1(x, waveforms(:,:,i), xq, 'spline');
							end
						else,
							waveforms_out = waveforms;
						end;
						size(waveforms_out),
						% Store epoch waveforms in file
						addvhlspikewaveformfile(spikewaves_binarydoc, waveforms_out);
					  
						% Store epoch spike times in file
						spiketimes_binarydoc.fwrite(ndi_timeseries_obj.samples2times(epoch{n},locs),'float32');
						start_sample = round(start_sample + extraction_doc.document_properties.spike_extraction_parameters.read_time * sample_rate - ...
								extraction_doc.document_properties.spike_extraction_parameters.overlap * sample_rate);
					end % while ~endReached

					ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spikewaves_binarydoc);
					ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spiketimes_binarydoc);
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
			% interpolation (3)         | Integer multiplier to interpolate spikes
			% overlap (0.5)             | Overlap allowed
			% read_time (30)            | Number of seconds to read in at a single time
			% refractory_samples (10)   | Number of samples to use as a refractory period
			% spike_sample_start (-9)   | Samples before the threshold to include
			% spike_sample_stop (20)    | Samples after the threshold to include
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
				fields_needed = {'center_range_time','interpolation','overlap','read_time','refractory_time',...
					'spike_start_time','spike_end_time',...
					'do_filter', 'filter_type','filter_low','filter_high','filter_order','filter_ripple',...
					'threshold_method','threshold_parameter','threshold_sign'};
				sizes_needed = {[1 1], [1 1], [1 1], [1 1], [1 1],...
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


		function spike_extract_probes(ndi_app_spikeextractor_obj, name, type, epoch, extraction_name, extraction_params)
			% SPIKE_EXTRACT_PROBES - method that extracts specific probes in experiment to ndi_doc
			%
			% SPIKE_EXTRACT_PROBES(NAME, TYPE, EXTRACTION_NAME, EXTRACTION_PARAMS)
			% NAME is the probe name if any
			% TYPE is the type of probe if any
			% combination of NAME and TYPE must return at least one probe from experiment
			% EPOCH is an index number to select epoch to extract
			% EXTRACTION_NAME name given to find ndi_doc in database
			% EXTRACTION_PARAMS a struct or filepath (tab separated file) with extraction parameters
			% - center_range = range in samples to find spike center
			% - interpolation = integer mutliplier to smooth spike extraction
			% - overlap = overlap allowed
			% - read_size = read size when reading spike files to not run out of RAM
			% - refractory_samples = number of samples used to rule out refractory period spikes
			% - spike_sample_start = negative integer backward from lowest point in spike to save spike from
			% - spike_sample_end = positive integer forward from lowest point in spike to save spike from
			% - start_time = initial sample to read spike files from

				% Extracts probe with name
				probes = ndi_app_spikeextractor_obj.experiment.getprobes('name', name, 'type', type); % can add reference

				% TODO Handle an ndi_document

				% If extraction_params was inputed as a struct then no need to parse it
				if isstruct(extraction_params)
					extraction_parameters = extraction_params;
				elseif isa(extraction_params, 'char') % TODO fix loading struct to loading an ndi_doc
					extraction_parameters = loadStructArray(extraction_params);
					% Consider saving in some var_branch_within probe_branch
				else
					error('unable to handle extraction_params.');
				end

				for prb=1:length(probes)
					% Set probe to variable
					probe = probes{prb};
					% Calculate number of epochs based on probe
					nEpochs = probe.numepochs();
					% Device sample rate
					sample_rate = samplerate(probe,1);
					% For every epoch in probe we read...
					for jj=1:1,
						n = epoch % handle epoch selection % temporary move
						start_time = 1; % matlab doesn't zero count annoying
						endReached = 0; % Variable to know if end of file reached
						spikewavesfid = -1; % spikewaves file identifier set to (-1) null

						center_range       = extraction_parameters.center_range;
						interpolation      = extraction_parameters.interpolation;
						read_size          = extraction_parameters.read_size;
						overlap            = extraction_parameters.overlap;
						refractory_samples = extraction_parameters.refractory_samples;
						spike_sample_start = extraction_parameters.spike_sample_start;
						spike_sample_end   = extraction_parameters.spike_sample_end;

						epochtic = tic; % Timer variable for measure duration of epoch extraction
						disp(['Epoch ' int2str(n) ' spike extraction started...']);
						while (~endReached)
							% read chunks
							end_time = start_time + read_size * sample_rate; % end time for chunk to read
							% Read from probe in epoch n from start_time to end_time
							data = probe.read_epochsamples(n,start_time, end_time); 

							% Checks if endReached by a threshold sample difference (data - (end_time - start_time))
							if abs(length(data) - ((end_time - start_time) + 1)) > 2 % | T(end)>100, % CHECK do not remember what this comment is about
								endReached = 1;
							end

							% Applies Chebyshev Type I filter to channels
							[b,a] = cheby1(4, 0.8, 300/(0.5 * sample_rate), 'high');
							data = filtfilt(b, a, data);

							% Spike locations stored here
							locations = [];

							% For number of channels
							for channel=1:size(data,2) %channel
								% Calculate stdev for channel
								stddev = std(data(:,channel));
								% Dot discriminator to find thresholds CHECK complex matlab c code running here, potential source of bugs in demo
								locations{channel} = dotdisc(double(data(:,channel)), [-4*stddev -1 0]); % 4*stddev
								%Accomodates spikes according to refractory period
								locations{channel} = refractory(locations{channel}, refractory_samples);
								locations{channel} = locations{channel}(find(locations{channel} > -spike_sample_start & locations{channel} <= length(data(:,channel))-spike_sample_end));
							end % for

							% All channels spike locations will be stored here
							locs = [];
							% Storing all channels spike locations
							for channel=1:size(data,2)
								locs = [locs; locations{channel}(:)];
							end

							% Sorts locs
							locs = sort(locs);

							% Apply refractory period to all channels locs
							locs = refractory(locs, refractory_samples);

							sample_offsets = repmat([spike_sample_start:spike_sample_end]',1,size(data,2));

							channel_offsets = repmat([0:size(data,2)-1], spike_sample_end - spike_sample_start + 1,1);

							single_spike_selection = sample_offsets + channel_offsets*size(data,1);

							spike_selections = repmat(single_spike_selection(:)', length(locs), 1) + repmat(locs(:), 1, prod(size(sample_offsets)));

							waveforms = single(data(spike_selections))'; % (spike-spike-spike-spike) X Nspikes

							waveforms = reshape(waveforms, spike_sample_end - spike_sample_start + 1, size(data,2), length(locs)); % Nsamples X Nchannels X Nspikes
							waveforms = permute(waveforms,[3 1 2]); % Nspikes X Nsamples X Nchannels

							%Center spikes
							waveforms = centerspikes_neg(waveforms,center_range);

							% Uncomment to plot specific spike
							% figure(1);
							% spike = squeeze(waveforms(1,:,:));
							% plot(spike);
							% plot_multichan(spike,spike_samples(1):spike_samples(2),400);
							% keyboard

							% If start_time == 1 then we have a new epoch
							% WARNING POTENTIAL SOURCE OF BUGS AS NOT ALWAYS WILL WE BE READING AT BEGINNING OF FILE
							% SO REMEMBER TO ADD OPTION FOR FULL REWRITE OF FILES

							if start_time==1
								% Clear extraction within probe with extraction_name
								ndi_app_spikeextractor_obj.clear_extraction(probe, extraction_name)

								% Create extraction parameters ndi_doc
								extraction_parameters_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/extraction_parameters', ...
									'extraction_parameters', extraction_parameters) ...
									+ probe.newdocument() + ndi_app_spikeextractor_obj.newdocument();
							
								% Create spikes ndi_doc
								spikes_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/spikewaves', ...
									'spikewaves.extraction_name', extraction_name, ...
									'spikewaves.extraction_parameters_file_id', extraction_parameters_doc.doc_unique_id(),...
									'epochid', epoch) ...
									+ probe.newdocument() + ndi_app_spikeextractor_obj.newdocument();

								% Create times ndi_doc
								times_doc = ndi_app_spikeextractor_obj.experiment.newdocument('apps/spikeextractor/spiketimes', ...
									'spike_extraction.extraction_name', extraction_name, ...
									'spike_extraction.extraction_parameters_file_id', extraction_parameters_doc.doc_unique_id(), ...
									'spike_extraction.epoch', epoch) ...
									+ probe.newdocument() + ndi_app_spikeextractor_obj.newdocument();

								% Add docs to database
									ndi_app_spikeextractor_obj.experiment.database.add(extraction_parameters_doc);
									ndi_app_spikeextractor_obj.experiment.database.add(spikes_doc);
									ndi_app_spikeextractor_obj.experiment.database.add(times_doc);

								% struct with parameters written in spikewaveforms header
								% TODO can be changed to a corresponding ndi_doc
								fileparameters.numchannels = size(data,2);
								fileparameters.S0 = spike_sample_start * interpolation - interpolation + 1;
								fileparameters.S1 = spike_sample_end * interpolation;
								fileparameters.name = probe.name;
								fileparameters.ref =  probe.reference;

								% if channel list is to be saved in files somwhere accessed with the method below
								% [dev, devname, devepoch, channeltype, channellist] = getchanneldevinfo(probe, n)

								fileparameters.comment = n; %epoch % used to be devicename and channels read
								fileparameters.samplingrate = double(samplerate(probe,1));
								fileparameters
								% Detailed parameter information
								% parameters.numchannels (uint8)    : Number of channels
								% parameters.S0 (int8)              : Number of samples before spike center
								%                                   :  (usually negative)
								% parameters.S1 (int8)              : Number of samples after spike center
								%                                   :  (usually positive)
								% parameters.name (80xchar)         : Name (up to 80 characters)
								% parameters.ref (uint8)            : Reference number
								% parameters.comment (80xchar)      : Up to 80 characters of comment
								% parameters.samplingrate           : The sampling rate (float32)
								% (first 512 bytes are free for additional header use)

								% TODO handle the ndi_document way
								% if ~isempty(ndi_app_spikeextractor_obj.loadspikes)

								% Spikes ndi_doc, get ndi_binary_doc file identifier
								spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(spikes_doc)

								% write header
								spikewaves_binarydoc_fid.fseek(0,'bof');                                            % now at 0 bytes
								spikewaves_binarydoc_fid.fwrite(uint8(fileparameters.numchannels),'uint8');         % now at 1 byte
								spikewaves_binarydoc_fid.fwrite(int8(fileparameters.S0),'int8');                    % now at 2 bytes
								spikewaves_binarydoc_fid.fwrite(int8(fileparameters.S1),'int8');                    % now at 3 bytes

								if length(fileparameters.name)>80,
									fileparameters.name = fileparameters.name(1:80);
								end

								spikewaves_binarydoc_fid.fwrite(fileparameters.name,'char');
								spikewaves_binarydoc_fid.fwrite(zeros(1,80-length(fileparameters.name)),'char');    % now at 83 bytes

								spikewaves_binarydoc_fid.fwrite(uint8(fileparameters.ref),'uint8');                 % now at 84 bytes

								if length(fileparameters.comment)>80,
									fileparameters.comment = fileparameters.comment(1:80);
								end

								spikewaves_binarydoc_fid.fwrite(fileparameters.comment,'char');
								spikewaves_binarydoc_fid.fwrite(zeros(1,80-length(fileparameters.comment)),'char');      % now at 164 bytes
								spikewaves_binarydoc_fid.fwrite(single(fileparameters.samplingrate),'float32');      % now at 168 bytes

								% about to write byte 168; we want to fill up to 512 with 0's
								% this is 512-168+1 bytes
								spikewaves_binarydoc_fid.fwrite(zeros(1,512-168),'uint8');

								spikewaves_binarydoc_fid.fseek(512,'bof');
								disp('spikewaves_binary_doc_fid details:')
								spikewaves_binarydoc_fid
								disp('spikes_doc details:')
								spikes_doc.document_properties.ndi_document;

								% Close the spikewaves ndi_doc
								ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spikewaves_binarydoc_fid) % pass in the object not fid

								% Times ndi_doc
								spiketimes_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(times_doc)

								% write header
								spiketimes_binarydoc_fid.fseek(0,'bof');                                        % now at 0 bytes
								spiketimes_binarydoc_fid.fwrite(uint8(fileparameters.numchannels),'uint8');         % now at 1 byte
								spiketimes_binarydoc_fid.fwrite(int8(fileparameters.S0),'int8');                    % now at 2 bytes
								spiketimes_binarydoc_fid.fwrite(int8(fileparameters.S1),'int8');                    % now at 3 bytes

								if length(fileparameters.name)>80,
									fileparameters.name = fileparameters.name(1:80);
								end

							spiketimes_binarydoc_fid.fwrite(fileparameters.name,'char');
							spiketimes_binarydoc_fid.fwrite(zeros(1,80-length(fileparameters.name)),'char');    % now at 83 bytes

							spiketimes_binarydoc_fid.fwrite(uint8(fileparameters.ref),'uint8');                 % now at 84 bytes

							if length(fileparameters.comment)>80,
							   fileparameters.comment = fileparameters.comment(1:80);
							end

							spiketimes_binarydoc_fid.fwrite(fileparameters.comment,'char');
							spiketimes_binarydoc_fid.fwrite(zeros(1,80-length(fileparameters.comment)),'char'); % now at 164 bytes

							spiketimes_binarydoc_fid.fwrite(single(fileparameters.samplingrate),'float32');      % now at 168 bytes

							% about to write byte 168; we want to fill up to 512 with 0's
							% this is 512-168+1 bytes
							spiketimes_binarydoc_fid.fwrite(zeros(1,512-168),'uint8');

							spiketimes_binarydoc_fid.fseek(512,'bof');

							% Close the spiketimes ndi_doc
							ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spiketimes_binarydoc_fid)
						end
						% Permute waveforms for addvhlspikewaveformfile to Nsamples X Nchannels X Nspikes
						waveforms = permute(waveforms, [2 3 1]);

						% Interpolation of waveforms
						interpolated_waveforms = [];
						% Required vectors for interpolation
						spikelength = spike_sample_end - spike_sample_start + 1;
						x = [1:spikelength];
						xq = [1/interpolation: 1/interpolation :spikelength]; % 1/3 sets up interpolation at 3x

						% WARNING CHECK TRANSPOSES FOR BUGS

						% For number of spikes
						for i=1:size(waveforms, 3);
							% Clear variable to store [interp_spike-interp_spike-interp_spike-interp_spike]
							interpolated_spikes = [];
							% For channelspike in tetrode
							for channelspike=1:size(waveforms, 2)
								% Get one channelspike [spike-spike-spike-spike]
								current_spike = waveforms(:,channelspike,i);
								current_spike = double(current_spike);
						
								% Interpolate channelspike
								interpolated_spike = interp1(x, current_spike, xq, 'spline');
								% Add to [interpolated_spike-interpolated_spike-interpolated_spike-interpolated_spike]
								interpolated_spikes = [interpolated_spikes interpolated_spike];
							end
							% Uncomment to plot interpolated spike
							% figure(11);
							% plot(interpolated_spikes);
							% keyboard
							
							% Add in new row to waveforms to be written to file
							interpolated_waveforms = [interpolated_waveforms; interpolated_spikes];
						end

						interpolated_waveforms = interpolated_waveforms';

						% Reshape array to store in file
						interpolated_waveforms = reshape(interpolated_waveforms, spikelength * interpolation, size(waveforms,2), size(waveforms,3));
						  
						% Uncomment to plot example interpolated_spikes
						% figure(10);
						% plot(interpolated_spikes);
						% keyboard

						% TODO check what this commented code is about
						% Permute waveforms for addvhlspikewaveformfile to Nsamples X Nchannels X Nspikes
						% interpolated_waveforms = permute(interpolated_waveforms, [2 3 1]);

						% Store epoch waveforms in file
						
						% TODO open every time or keep open?
						spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(spikes_doc);
						[num_samples,numchannels,num_waveforms] = size(interpolated_waveforms);
						% we need the spikes waveforms to be represented in the columns of the matrix
						% this means we need to push all of the channels into 1 dimension
						interpolated_waveforms = single(reshape(interpolated_waveforms,num_samples*numchannels,num_waveforms));
						spikewaves_binarydoc_fid.fseek(0,'eof');  % go to the end
						spikewaves_binarydoc_fid.fwrite(single(interpolated_waveforms),'float32');
						ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spikewaves_binarydoc_fid);
						  
						% Store epoch spike times in file
						spiketimes_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(times_doc);
						spiketimes_binarydoc_fid.fseek(0,'eof');  % go to the end
						spiketimes_binarydoc_fid.fwrite(double(locs),'float32');
						ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spiketimes_binarydoc_fid);
						% finaltimes = [finaltimes locs];
						% Update start_time
						start_time = start_time + read_size * sample_rate - overlap * sample_rate;
					end % while ~endReached

					disp(['Epoch ' int2str(n) ' spike extraction done.']);
				end % epoch n
			end % prb
		end % function

		function b = clear_extraction(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
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
			searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
				{'spike_extraction.extraction_name', extraction_name});
			epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
			spikes_searchq = cat(2, searchq, ...
				{'spike_extraction.epoch', epoch_string});
			% Concatenate timeseries query parameters
			times_searchq = cat(2, searchq, ndi_timeseries_obj.searchquery());

			% Search and get any docs
			mydoc = ndi_app_spikeextractor_obj.experiment.database.search(searchq);

			% Remove the docs
			if ~isempty(mydoc),
				for i=1:numel(mydoc),
					ndi_app_spikeextractor_obj.experiment.database.remove(mydoc{i}.doc_unique_id)
				end
				b = 1;
			end
		end % clear_extraction()

		function b = clear_extraction_parameters(ndi_app_spikeextractor_obj, ndi_timeseries_obj, extraction_name)
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
			searchq = {'spike_extraction.extraction_name', extraction_name};
			extract_doc = ndi_app_spikeextractor_obj.experiment.database.search(extract_searchq);
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
			if ~isempty(extract_doc),
				for i=1:numel(extract_doc),
					epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
					spikewaves_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
						{'epochid', epoch_string, 'spikewaves.extraction_name', extraction_name});
					mydoc = ndi_app_spikeextractor_obj.experiment.database.search(spikewaves_searchq);
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
			extract_doc = ndi_app_spikeextractor_obj.experiment.database.search(extract_searchq);
			if ~isempty(extract_doc),
				epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
				times_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
					{'epochid', epoch_string, 'spiketimes.extraction_name', extraction_name});
				mydoc = ndi_app_spikeextractor_obj.experiment.database.search(times_searchq);
				ndi_app_spikeextractor_obj.experiment.database_rm(mydoc);
			end;
			b = 1;
		end % clear_spiketimes_doc()

		function waveforms = load_spikewaves_epoch(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
			% LOAD_SPIKEWAVES_EPOCH - load spikewaves from an epoch
			%
			% CONCATENATED_SPIKES = LOAD_SPIKEWAVES_EPOCH(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
			%
			% Reads the spikewaves for an NDI_TIMESERIES object for a given EPOCH and EXTRACTION_NAME.
				epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
				spikewaves_searchq = cat(2,ndi_app_spikeextractor_obj.searchquery(), ...
					{'epochid', epoch_string, 'spikewaves.extraction_name', extraction_name});
				spikewaves_doc = ndi_app_spikeextractor_obj.experiment.database.search(spikewaves_searchq),
				
				if numel(spikewaves_doc)==1,
					spikewaves_doc = spikewaves_doc{1};
					spikewaves_binarydoc = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(spikewaves_doc);
					%[waveforms,header] = readvhlspikewaveformfile(spikewaves_binarydoc,-1,-1) 
					waveforms = readvhlspikewaveformfile(spikewaves_binarydoc);
					ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spikewaves_binarydoc);
				elseif numel(spikewaves_doc)>1,
					error(['Found ' numel(spikewaves_doc) ' documents matching the criteria. Do not know how to proceed.']);
				else,
					waveforms = [];
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
					spikes_doc = ndi_app_spikeextractor_obj.experiment.database.read(docs{i}.doc_unique_id);
					spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(spikes_doc);
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
					ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spikewaves_binarydoc_fid);
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
			docs = ndi_app_spikeextractor_obj.experiment.database.search(times_searchq);

			% TODO How to get them in order? maybe add epoch_number to times and times ndi_doc
			if ~isempty(docs)
				% TODO make sure multiple epochs work
				for i=1:numel(docs)
					times_doc = ndi_app_spikeextractor_obj.experiment.database.read(docs{i}.doc_unique_id)
					spiketimes_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.openbinarydoc(times_doc);

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
					ndi_app_spikeextractor_obj.experiment.database.closebinarydoc(spiketimes_binarydoc_fid);
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
			docs = ndi_app_spikeextractor_obj.experiment.database.search(parameters_searchq);

			% TODO How to get them in order? maybe add epoch_number to spikes and times ndi_doc
			if ~isempty(docs)
				% TODO make sure multiple epochs work
				for i=1:numel(docs)
					parameters_doc = ndi_app_spikeextractor_obj.experiment.database.read(docs{i}.doc_unique_id)
					spikewaves_binarydoc_fid = ndi_app_spikeextractor_obj.experiment.database.read(parameters_doc);
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
