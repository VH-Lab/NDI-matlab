classdef ndi_app_spikeextractor < ndi_app

	properties (SetAccess=protected,GetAccess=public)


	end % properties

	methods

		function ndi_app_spikeextractor_obj = ndi_app_spikeextractor(varargin)
			% NDI_APP_SPIKEEXTRACTOR - an app to extract elements found in sessions
			%
			% NDI_APP_SPIKEEXTRACTOR_OBJ = NDI_APP_SPIKEEXTRACTOR(SESSION)
			%
			% Creates a new NDI_APP_SPIKEEXTRACTOR object that can operate on
			% NDI_SESSIONS. The app is named 'ndi_app_spikeextractor'.
			%
				session = [];
				name = 'ndi_app_spikeextractor';
				if numel(varargin)>0,
					session = varargin{1};
				end
				ndi_app_spikeextractor_obj = ndi_app_spikeextractor_obj@ndi_app(session, name);

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
			% EXTRACT - method that extracts spikes from epochs of an NDI_ELEMENT_TIMESERIES_OBJ 
			%
			% EXTRACT(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_PARAMS, EXTRACTION_NAME, [REDO], [T0 T1])
			% TYPE is the type of probe if any
			% combination of NAME and TYPE must return at least one probe from session
			% EPOCH is an index number or id to select epoch to extract, or can be a cell array of epoch number/ids
			% EXTRACTION_NAME name given to find ndi_doc in database
			% REDO - if 1, then extraction is re-done for epochs even if it has been done before with same extraction parameters

				ndi_globals;

				if ndi.debug.veryverbose,
					disp(['Beginning of extract']);
				end;

				% process input arguments

				if isempty(epoch),
					et = epochtable(ndi_timeseries_obj);
					epoch = {et.epoch_id};
				elseif ~iscell(epoch),
					epoch = {epoch};
				end;

				extract_searchq = ndi_query('ndi_document.name','exact_string',extraction_name,'') & ...
					ndi_query('','isa','spike_extraction_parameters','');
				extraction_doc = ndi_app_spikeextractor_obj.session.database_search(extract_searchq);
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

					if ndi.debug.veryverbose,
						disp(['Beginning to set up for epoch ' epoch_string '.']);
					end;

					% begin an epoch, get ready

					q_app = ndi_query(ndi_app_spikeextractor_obj.searchquery());
					q_epoch = ndi_query('epochid', 'exact_string', epoch_string, '');
					q_sw = ndi_query('spikewaves.extraction_name','exact_string', extraction_name,''); % no longer used
					q_st = ndi_query('spiketimes.extraction_name','exact_string', extraction_name,''); % no longer used
					q_element = ndi_query('','depends_on','element_id',ndi_timeseries_obj.id());
					q_extdoc = ndi_query('','depends_on','extraction_parameters_id',extraction_doc.id());
						
					old_spikewaves_doc = ndi_app_spikeextractor_obj.session.database_search(q_app&q_epoch&q_element&q_extdoc);
					old_spiketimes_doc = ndi_app_spikeextractor_obj.session.database_search(q_app&q_epoch&q_element&q_extdoc);

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

					% Clear extraction within element with extraction_name
					ndi_app_spikeextractor_obj.clear_spikewaves_doc(ndi_timeseries_obj, epoch{n}, extraction_name);
					ndi_app_spikeextractor_obj.clear_spiketimes_doc(ndi_timeseries_obj, epoch{n}, extraction_name);

					% Create spikes ndi_doc
					spikes_doc = ndi_app_spikeextractor_obj.session.newdocument('apps/spikeextractor/spikewaves', ...
							'spikewaves.extraction_name', extraction_name, ...
							'spikewaves.sample_rate', sample_rate,...
							'spikewaves.s0', extraction_doc.document_properties.spike_extraction_parameters.spike_start_time,...
							'spikewaves.s1', extraction_doc.document_properties.spike_extraction_parameters.spike_end_time,...
							'epochid', epoch_string) ...
							+ ndi_app_spikeextractor_obj.newdocument();
					spikes_doc = spikes_doc.set_dependency_value('extraction_parameters_id',extraction_doc.id());
					spikes_doc = spikes_doc.set_dependency_value('element_id',ndi_timeseries_obj.id());

					% Create times ndi_doc
					times_doc = ndi_app_spikeextractor_obj.session.newdocument('apps/spikeextractor/spiketimes', ...
							'spiketimes.extraction_name', extraction_name, ...
							'epochid', epoch_string) ...
							+ ndi_app_spikeextractor_obj.newdocument();
					times_doc = times_doc.set_dependency_value('extraction_parameters_id',extraction_doc.id());
					times_doc = times_doc.set_dependency_value('element_id',ndi_timeseries_obj.id());

					% Add docs to database
					ndi_app_spikeextractor_obj.session.database_add(spikes_doc);
					ndi_app_spikeextractor_obj.session.database_add(times_doc);

					% add header to spikes_doc
					fileparameters.numchannels = size(data_example,2);
					fileparameters.S0 = spike_sample_start;    %  -1*numel(find(xq<0)); the commented code is wrong, even if using interpolation
					fileparameters.S1 = spike_sample_end;      % numel(find(xq>0)); the commented code is wrong, even if using interpolation
					fileparameters.name = spikes_doc.id();
					fileparameters.ref =  0;
					fileparameters.comment = epoch_string; %epoch 
					fileparameters.samplingrate = double(sample_rate);

					spikewaves_binarydoc = ndi_app_spikeextractor_obj.session.database_openbinarydoc(spikes_doc);
					newvhlspikewaveformfile(spikewaves_binarydoc, fileparameters); 
					spiketimes_binarydoc = ndi_app_spikeextractor_obj.session.database_openbinarydoc(times_doc); % we will just write double data here

					% leave these files open while we extract

					epochtic = tic; % Timer variable to measure duration of epoch extraction
					disp(['Epoch ' ndi_timeseries_obj.epoch2str(epoch{n}) ' spike extraction started...']);

					% now read the file in chunks
					while (~endReached)
						read_end_sample = ceil(read_start_sample + extraction_doc.document_properties.spike_extraction_parameters.read_time * sample_rate); % end sample for chunk to read
						if read_end_sample > end_sample,
							read_end_sample = end_sample;
						end;
						% Read from element in epoch n from start_time to end_time
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

					ndi_app_spikeextractor_obj.session.database_closebinarydoc(spikewaves_binarydoc);
					ndi_app_spikeextractor_obj.session.database_closebinarydoc(spiketimes_binarydoc);
					disp(['Epoch ' int2str(n) ' spike extraction done.']);
				end % epoch n
		end % extract

		function [extraction_doc] = add_extraction_doc(ndi_app_spikeextractor_obj, extraction_name, extraction_params, varargin)
			% ADD_EXTRACTION_DOC - add extraction parameters document
			%
			% [EXTRACTION_DOC] = ADD_EXTRACTION_DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, EXTRACTION_NAME, EXTRACTION_PARAMS, ...)
			%
			% Given EXTRACTION_PARAMS as either a structure or a filename, this function returns
			% EXTRACTION_DOC parameters as an NDI_DOCUMENT and checks its fields. If EXTRACTION_PARAMS is empty,
			% then the default parameters are returned. If EXTRACTION_NAME is already the name of an existing
			% NDI_DOCUMENT then an error is returned.
			%
			% EXTRACTION_PARAMS should contain the following fields:
			% Fieldname                 | Description
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
			%
			% This function also takes NAME/VALUE pairs that alter its main behavior.
			% Parameter (default)       | Description
			% --------------------------------------------------------------------------
			% DocExists ('Error')       | What to do if a document by that name already exists.
			%                           |   Possible values are the following:
			%                           |      'Error'   : generate an error
			%                           |      'NoAction': leave the existing document
			%                           |      'Replace' : replace the document (deletes all dependent documents)
			%
			% See also: NAMEVALUEPAIR
				if nargin<3,
					extraction_params = [];
				end;

				DocExists = 'Error';

				assign(varargin{:});

					% search for any existing documents with that name; any doc that has that name and spike_extraction_parameters as a field
				extract_searchq = ndi_query('ndi_document.name','exact_string',extraction_name,'') & ...
					ndi_query('','isa','spike_extraction_parameters','');
				mydoc = ndi_app_spikeextractor_obj.session.database_search(extract_searchq);
				if ~isempty(mydoc),
					switch(DocExists),
						case 'Error',
							error([int2str(numel(mydoc)) ...
								' spike_extraction_parameters documents with name ''' extraction_name ''' already exist(s).']);
						case 'NoAction',
							extraction_doc = mydoc{1};
							return;
						case 'Replace',
							b=ndi_app_spikeextractor_obj.clear_extraction_parameters(extraction_name);
							if ~b,
								error(['Could not delete existing extraction_name doc ' extraction_name '.']);
							end;
					end; % switch(DocExists)
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

				ndi_app_spikeextractor_obj.session.database_add(extraction_doc);

				extraction_doc.document_properties,

		end; % add_extraction_doc


		function b = clear_extraction_parameters(ndi_app_spikeextractor_obj, extraction_name)
		% CLEAR_EXTRACTION_PARAMETERS - clear all 'spikewaves' records for an NDI_PROBE_OBJ from session database
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
			extract_searchq = ndi_query('ndi_document.name','exact_string',extraction_name,'') & ...
				ndi_query('','isa','spike_extraction_parameters','');
			extract_doc = ndi_app_spikeextractor_obj.session.database_search(extract_searchq);
			if ~isempty(extract_doc),
				ndi_app_spikeextractor_obj.session.database_rm(extract_doc);
			end;
			b = 1;
		end % clear_extraction_parameters()

		function b = clear_spikewaves_doc(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
		% CLEARSPIKEWAVES - clear all 'spikewaves' records for an NDI_PROBE_OBJ from session database
		%
		% B = CLEARSPIKEWAVES(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_EPOCHSET_OBJ)
		%
		% Clears all spikewaves entries from the session database for object NDI_PROBE_OBJ.
		%
		% Returns 1 on success, 0 otherwise.
		%%%
		% See also: NDI_APP_MARKGARBAGE/MARKVALIDINTERVAL, NDI_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
		%      NDI_APP_MARKGARBAGE/LOADVALIDINTERVAL

			% Look for any docs matching extraction name and remove them
			% Concatenate app query parameters and extraction_name parameter
			extract_searchq = ndi_query('','isa','spike_extraction_parameters.json','') & ...
				ndi_query('ndi_document.name', 'exact_string', extraction_name,'');
			extract_doc = ndi_app_spikeextractor_obj.session.database_search(extract_searchq);
			epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
			if ~isempty(extract_doc),
				for i=1:numel(extract_doc),
					spikewaves_searchq = ndi_query(ndi_app_spikeextractor_obj.searchquery())  & ...
						ndi_query('epochid','exact_string', epoch_string,'') & ...
						ndi_query('spikewaves.extraction_name','exact_string',extraction_name,'') & ...
						ndi_query('','depends_on','element_id',ndi_timeseries_obj.id());
					mydoc = ndi_app_spikeextractor_obj.session.database_search(spikewaves_searchq);
					ndi_app_spikeextractor_obj.session.database_rm(mydoc);
				end;
			end;
			b = 1;
		end; % clear_spikewaves_doc()

		function b = clear_spiketimes_doc(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
		% CLEARSPIKETIMES - clear all 'spiketimes' records for an NDI_TIMESERIES_OBJ from session database
		%
		% B = CLEAR_SPIKETIMES_DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, NDI_EPOCHSET_OBJ)
		%
		% Clears all spikewaves entries from the session database for object NDI_PROBE_OBJ.
		%
		% Returns 1 on success, 0 otherwise.
		%%%
		% See also: NDI_APP_MARKGARBAGE/MARKVALIDINTERVAL, NDI_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
		%      NDI_APP_MARKGARBAGE/LOADVALIDINTERVAL

			% Look for any docs matching extraction name and remove them
			% Concatenate app query parameters and extraction_name parameter
			extract_searchq = ndi_query('','isa','spike_extraction_parameters.json','') & ...
				ndi_query('ndi_document.name', 'exact_string', extraction_name,'');
			extract_doc = ndi_app_spikeextractor_obj.session.database_search(extract_searchq);
			if ~isempty(extract_doc),
				epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
				times_searchq = ndi_query(ndi_app_spikeextractor_obj.searchquery())  & ...
					ndi_query('epochid','exact_string', epoch_string,'') & ...
					ndi_query('spiketimes.extraction_name','exact_string',extraction_name,'') & ...
						ndi_query('','depends_on','element_id',ndi_timeseries_obj.id());
				mydoc = ndi_app_spikeextractor_obj.session.database_search(times_searchq);
				ndi_app_spikeextractor_obj.session.database_rm(mydoc);
			end;
			b = 1;
		end % clear_spiketimes_doc()

		function [waveforms, waveparameters, spikewaves_doc] = load_spikewaves_epoch(ndi_app_spikeextractor_obj, ndi_timeseries_obj, epoch, extraction_name)
			% LOAD_SPIKEWAVES_EPOCH - load spikewaves from an epoch
			%
			% [CONCATENATED_SPIKES, WAVEPARAMETERS, SPIKEWAVES_DOC] = LOAD_SPIKEWAVES_EPOCH(NDI_APP_SPIKEEXTRACTOR_OBJ, NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
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
			% SPIKEWAVES_DOC is the NDI_DOCUMENT of the extracted spikes.
			%
			% Reads the spikewaves for an NDI_TIMESERIES object for a given EPOCH and EXTRACTION_NAME.
				epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
				spikewaves_searchq = ndi_query(ndi_app_spikeextractor_obj.searchquery()) & ...
					ndi_query('epochid','exact_string',epoch_string,'') & ...
					ndi_query('spikewaves.extraction_name','exact_string',extraction_name,'') & ...
					ndi_query('','depends_on','element_id',ndi_timeseries_obj.id());
				spikewaves_doc = ndi_app_spikeextractor_obj.session.database_search(spikewaves_searchq);
			
				if numel(spikewaves_doc)==1,
					spikewaves_doc = spikewaves_doc{1};
					spikewaves_binarydoc = ndi_app_spikeextractor_obj.session.database_openbinarydoc(spikewaves_doc);
					%[waveforms,header] = readvhlspikewaveformfile(spikewaves_binarydoc,-1,-1) 
					[waveforms,waveparameters] = readvhlspikewaveformfile(spikewaves_binarydoc);
					waveparameters.samplerate = waveparameters.samplingrate;
					ndi_app_spikeextractor_obj.session.database_closebinarydoc(spikewaves_binarydoc);
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
				spiketimes_searchq = ndi_query(ndi_app_spikeextractor_obj.searchquery()) & ...
					ndi_query('epochid','exact_string',epoch_string,'') & ...
					ndi_query('spiketimes.extraction_name','exact_string',extraction_name,'') & ...
					ndi_query('','depends_on','element_id',ndi_timeseries_obj.id());
				
				spiketimes_doc = ndi_app_spikeextractor_obj.session.database_search(spiketimes_searchq);
				
				if numel(spiketimes_doc)==1,
					spiketimes_doc = spiketimes_doc{1};
					spiketimes_binarydoc = ndi_app_spikeextractor_obj.session.database_openbinarydoc(spiketimes_doc);
					times = fread(spiketimes_binarydoc,Inf,'float32');
					ndi_app_spikeextractor_obj.session.database_closebinarydoc(spiketimes_binarydoc);
				elseif numel(spiketimes_doc)>1,
					error(['Found ' int2str(numel(spiketimes_doc)) ' documents matching the criteria. Do not know how to proceed.']);
				else,
					times = [];
				end;
	
		end; % load_spikewaves_epoch

	end % methods

	methods (Static)
		function [b,errormsg] = isvalid_extraction_parameters(extraction_parameter_struct)
		% ISVALID_EXTRACTION_PARAMETERS - are extration parameters valid?
		%
		% [B,ERRORMSG] = ISVALID_EXTRACTION_PARAMETERS(EXTRACTION_PARAMETER_STRUCT)
		%
		% Checks to ensure that the parameters provided in EXTRACTION_PARAMETER_STRUCT are
		% valid for the NDI_APP_SPIKEEXTRACTOR. B is 1 if it passes. B is 0 otherwise.
		% ERRORMSG contains a human-readable error message if the validation fails.
		%
			% check parameters here
			fields_needed = {'center_range_time','overlap','read_time','refractory_time',...
				'spike_start_time','spike_end_time',...
				'do_filter', 'filter_type','filter_low','filter_high','filter_order','filter_ripple',...
				'threshold_method','threshold_parameter','threshold_sign'};
			sizes_needed = {[1 1], [1 1], [1 1], [1 1],...
				[1 1],[1 1],...
				[1 1],[1 -1],[1 1],[1 1],[1 1],[1 1],...
				[1 -1], [1 1], [1 1]};

			[b,errormsg] = hasAllFields(extraction_params,fields_needed, sizes_needed);

		end; % isvalid_extraction_parameters()

		function b = isequal_extraction_parameters(extraction_parameter_struct1, extraction_parameter_struct2)
		% ISEQUAL_EXTRACTION_PARAMETERS - are extraction parameters equal?
		%
		% B = ISEQUAL_EXTRACTION_PARAMETERS(EXTRACTION_PARAMETERS_STRUCT1, EXTRACTION_PARAMETER_STRUCT2)
		%
		% B is 1 if the extraction parameter structures EXTRACTION_PARAMETERS_STRUCT1 and
		% EXTRACTION_PARAMETERS_STRUCT2 are valid and equal. Otherwise B is 0.
		%
		%
			b = ndi_app_spikeextractor.isvalid_extraction_parameters(extraction_parameter_struct1);
			b = b & ndi_app_spikeextractor.isvalid_extraction_parameters(extraction_parameter_struct2);
			if ~b, % both must be valid to keep going
				return;
			end;
			fields_needed = {'center_range_time','overlap','read_time','refractory_time',...
				'spike_start_time','spike_end_time',...
				'do_filter', 'filter_type','filter_low','filter_high','filter_order','filter_ripple',...
				'threshold_method','threshold_parameter','threshold_sign'};
			for i=1:numel(fields_needed),
				v1 = getfield(extraction_parameters_struct1,fields_needed{i});
				v2 = getfield(extraction_parameters_struct2,fields_needed{i});
				if ~eqlen(v1==v2),
					b = 0;
					return;
				end;
			end;
			% if we make it here, they are equal
		end; % isequal_extraction_parameters

	end

end % ndi_app_spikeextractor
