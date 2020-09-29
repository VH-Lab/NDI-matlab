classdef spikeextractor < ndi.app.base & ndi_app_appdoc

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_spikeextractor_obj = spikeextractor(varargin)
			% ndi.app.spikeextractor - an app to extract elements found in sessions
			%
			% NDI_APP_SPIKEEXTRACTOR_OBJ = ndi.app.spikeextractor(SESSION)
			%
			% Creates a new ndi_app_spikeextractor object that can operate on
			% NDI_SESSIONS. The app is named 'ndi_app_spikeextractor'.
			%
				session = [];
				name = 'ndi_app_spikeextractor';
				if numel(varargin)>0,
					session = varargin{1};
				end
				
				ndi_app_spikeextractor_obj = ndi_app_spikeextractor_obj@ndi.app.base(session, name);
				ndi_app_spikeextractor_obj = ndi_app_spikeextractor_obj@ndi_app_appdoc(...
					{'extraction_parameters','extraction_parameters_modification', 'spikewaves','spiketimes'},...
					{'apps/spikeextractor/spike_extraction_parameters','apps/spikeextractor/spike_extraction_parameters_modification',...
						'apps/spikeextractor/spikewaves','apps/spikeextractor/spiketimes'},...
					session);

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
			% Filters data based on FILTERSTRUCT (see ndi_app_spikeextractor/MAKEFILTERSTRUCT)
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

				ndi.globals;

				ndi_globals.log.msg('system',1,'Beginning of extraction.');

				% process input arguments

				if isempty(epoch),
					et = epochtable(ndi_timeseries_obj);
					epoch = {et.epoch_id};
				elseif ~iscell(epoch),
					epoch = {epoch};
				end;

				extraction_doc = ndi_app_spikeextractor_obj.find_appdoc('extraction_parameters',extraction_name);

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

					ndi_globals.log.msg('system',1,['Beginning to set up for epoch ' epoch_string '.']);

					% begin an epoch, get ready

					old_spikewaves_doc = ndi_app_spikeextractor_obj.find_appdoc('spikewaves', ndi_timeseries_obj,epoch_string,extraction_name);
					old_spiketimes_doc = ndi_app_spikeextractor_obj.find_appdoc('spiketimes', ndi_timeseries_obj,epoch_string,extraction_name);
						
					if (~isempty(old_spikewaves_doc) & ~isempty(old_spiketimes_doc)) & ~redo,
						% we already have this epoch
						continue; % skip to next epoch
					end;

					% now use extraction_parameters to set spikewave parameters

					sample_rate = ndi_timeseries_obj.samplerate(epoch{n});
					data_example = ndi_timeseries_obj.readtimeseries(epoch{n},0,1/sample_rate); % read a single sample
					start_sample = ndi_timeseries_obj.times2samples(epoch{n},t0_t1(n,1));
					if isnan(start_sample),
						start_sample = 1;
					end;
					read_start_sample = start_sample;
					end_sample =  ndi_timeseries_obj.times2samples(epoch{n},t0_t1(n,2));
					if isnan(end_sample),
						end_sample = Inf;
					end;
					endReached = 0; % Variable to know if end of file reached

					% convert from parameter file units of time to samples here
					center_range_samples = ceil(extraction_doc.document_properties.spike_extraction_parameters.center_range_time * sample_rate);
					refractory_samples = round(extraction_doc.document_properties.spike_extraction_parameters.refractory_time * sample_rate);
					spike_sample_start = floor(extraction_doc.document_properties.spike_extraction_parameters.spike_start_time * sample_rate);
					spike_sample_end = ceil(extraction_doc.document_properties.spike_extraction_parameters.spike_end_time * sample_rate);

					filterstruct = ndi_app_spikeextractor_obj.makefilterstruct(extraction_doc, sample_rate);

					% Clear extraction within element with extraction_name
					
					ndi_app_spikeextractor_obj.clear_appdoc('spikewaves',ndi_timeseries_obj,epoch_string,extraction_name);
					ndi_app_spikeextractor_obj.clear_appdoc('spiketimes',ndi_timeseries_obj,epoch_string,extraction_name);

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
					vlt.file.custom_file_formats.newvhlspikewaveformfile(spikewaves_binarydoc, fileparameters); 
					spiketimes_binarydoc = ndi_app_spikeextractor_obj.session.database_openbinarydoc(times_doc); % we will just write double data here

					% leave these files open while we extract

					epochtic = tic; % Timer variable to measure duration of epoch extraction
					ndi_globals.log.msg('system',1,['Epoch ' ndi_timeseries_obj.epoch2str(epoch{n}) ' spike extraction started...']);

					% now read the file in chunks
					while (~endReached)
						read_end_sample = ceil(read_start_sample + extraction_doc.document_properties.spike_extraction_parameters.read_time * sample_rate); % end sample for chunk to read
						if read_end_sample > end_sample,
							read_end_sample = end_sample;
						end;
						% Read from element in epoch n from start_time to end_time
						read_times = ndi_timeseries_obj.samples2times(epoch{n}, [read_start_sample read_end_sample]);
						data = ndi_timeseries_obj.readtimeseries(epoch{n}, read_times(1), read_times(2)); 

						% Checks if endReached by a threshold sample difference (data - (end_time - start_time))
						if (size(data,1) - ((read_end_sample - read_start_sample) + 1)) < 0 % if we got less than we asked for, we are done
							endReached = 1;
						elseif read_end_sample==end_sample,
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
									locs_here = vlt.signal.dotdisc(double(data(:,channel)), ...
										[extraction_doc.document_properties.spike_extraction_parameters.threshold_parameter*stddev ...
											extraction_doc.document_properties.spike_extraction_parameters.threshold_sign  0]); 
								case 'absolute',
									locs_here = vlt.signal.dotdisc(double(data(:,channel)), ...
										[extraction_doc.document_properties.spike_extraction_parameters.threshold_parameter ...
											extraction_doc.document_properties.spike_extraction_parameters.threshold_sign  0]); 
								otherwise,
									error(['unknown threshold method']);
							end
							%Accomodates spikes according to refractory period
							%locs_here = vlt.signal.refractory(locs_here, refractory_samples); % only apply to all events
							locs_here = locs_here(find(locs_here > -spike_sample_start & locs_here <= length(data(:,channel))-spike_sample_end));
							locs = [locs(:) ; locs_here];
						end % for

						% Sorts locs
						locs = sort(locs);
						% Apply refractory period to all events
						locs = vlt.signal.refractory(locs, refractory_samples);

						sample_offsets = repmat([spike_sample_start:spike_sample_end]',1,size(data,2));
						channel_offsets = repmat([0:size(data,2)-1], spike_sample_end - spike_sample_start + 1,1);
						single_spike_selection = sample_offsets + channel_offsets*size(data,1);
						spike_selections = repmat(single_spike_selection(:)', length(locs), 1) + repmat(locs(:), 1, prod(size(sample_offsets)));
						waveforms = single(data(spike_selections))'; % (spike-spike-spike-spike) X Nspikes

						waveforms = reshape(waveforms, spike_sample_end - spike_sample_start + 1, size(data,2), length(locs)); % Nsamples X Nchannels X Nspikes
						waveforms = permute(waveforms,[3 1 2]); % Nspikes X Nsamples X Nchannels

						%Center spikes; if threshold is low-to-high, flip sign (assume positive-spikes)
						waveforms = (-1*extraction_doc.document_properties.spike_extraction_parameters.threshold_sign)*vlt.neuro.spikesorting.centerspikes_neg( ...
							(-1*extraction_doc.document_properties.spike_extraction_parameters.threshold_sign)*waveforms,center_range_samples);

						% Permute waveforms for vlt.file.custom_file_formats.addvhlspikewaveformfile to Nsamples X Nchannels X Nspikes
						waveforms = permute(waveforms, [2 3 1]);

						% Store epoch waveforms in file
						vlt.file.custom_file_formats.addvhlspikewaveformfile(spikewaves_binarydoc, waveforms);
					  
						% Store epoch spike times in file
						spiketimes_binarydoc.fwrite(ndi_timeseries_obj.samples2times(epoch{n},read_start_sample-1+locs),'float32');
						read_start_sample = round(read_start_sample + ...
								extraction_doc.document_properties.spike_extraction_parameters.read_time * sample_rate - ...
								extraction_doc.document_properties.spike_extraction_parameters.overlap * sample_rate);
					end % while ~endReached

					ndi_app_spikeextractor_obj.session.database_closebinarydoc(spikewaves_binarydoc);
					ndi_app_spikeextractor_obj.session.database_closebinarydoc(spiketimes_binarydoc);
					ndi_globals.log.msg('system',1,['Epoch ' int2str(n) ' spike extraction done.']);
				end % epoch n
		end % extract

		% functions that override ndi_app_appdoc

		function doc = struct2doc(ndi_app_spikeextractor_obj, appdoc_type, appdoc_struct, varargin)
			% STRUCT2DOC - create an ndi.document from an input structure and input parameters
			%
			% DOC = STRUCT2DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
			%
			% For ndi_app_spikeextractor, one can use an APPDOC_TYPE of the following:
			% APPDOC_TYPE                 | Description
			% ----------------------------------------------------------------------------------------------
			% 'extraction_parameters'     | A document that describes the parameters to be used for extraction
			% ['extraction_parameters'... | A document that modifies the parameters to be used for extraction for a single epoch 
			%   '_modification']          | 
			%
			% See APPDOC_DESCRIPTION for a list of the parameters.
			% 
				if strcmpi(appdoc_type,'extraction_parameters'),
					extraction_name = varargin{1};
					doc = ndi.document('apps/spikeextractor/spike_extraction_parameters',...
						'spike_extraction_parameters',appdoc_struct) + ...
						ndi_app_spikeextractor_obj.newdocument() + ...
						ndi.document('ndi_document','ndi_document.name',extraction_name);
				elseif strcmpi(appdoc_type,'extraction_parameters_modification'),
					ndi_timeseries_obj = varargin{1};
					epochid = varargin{2};
					extraction_name = varargin{3};
					if ~isa(ndi_timeseries_obj,'ndi.time.timeseries'),
						error(['ndi_timeseries_obj must be a member of class ndi.time.timeseries.']);
					end;
					epoch_string = ndi_timeseries_obj.epoch2str(epochid); % make sure to use string form
					extraction_doc = ndi_app_spikeextractor_obj.find_appdoc('extraction_parameters', extraction_name);
					if isempty(extraction_doc),
						error(['Could not find an extraction parameters document named ' extraction_name '.']);
					end;

					doc = ndi.document('apps/spikeextractor/spike_extraction_parameters_modification',...
						'spike_extraction_parameters_modification',appdoc_struct,'epochid',epoch_string) + ...
						ndi_app_spikeextractor_obj.newdocument() + ndi.document('ndi_document','ndi_document.name',extraction_name);
					doc = doc.set_dependency_value('extraction_parameters_id',extraction_doc.id());
					doc = doc.set_dependency_value('element_id',ndi_timeseries_obj.id());
				elseif strcmpi(appdoc_type,'spikewaves'),
					error(['spikewaves documents are created internally.']);
				elseif strcmpi(appdoc_type,'spiketimes'),
					error(['spiketimes documents are created internally.']);
				else,
					error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
				end;

		end; % struct2doc()

		function [b,errormsg] = isvalid_appdoc_struct(ndi_app_spikeextractor_obj, appdoc_type, appdoc_struct)
			% ISVALID_APPDOC_STRUCT - is an input structure a valid descriptor for an APPDOC?
			%
			% [B,ERRORMSG] = ISVALID_APPDOC_STRUCT(NDI_APP_SPIKEEXTRACTOR_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
			%
			% Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
			% ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
			%
			% For ndi_app_spikeextractor, one can use an APPDOC_TYPE of the following:
			% APPDOC_TYPE               | Description
			% ----------------------------------------------------------------------------------------------
			% 'extraction_parameters'   | A document that describes the parameters to be used for extraction
			%
				errormsg = '';
				if strcmpi(appdoc_type,'extraction_parameters') | strcmpi(appdoc_type,'extraction_parameters_modification'),
					extraction_params = appdoc_struct;
					% check parameters here
					fields_needed = {'center_range_time','overlap','read_time','refractory_time',...
						'spike_start_time','spike_end_time',...
						'do_filter', 'filter_type','filter_low','filter_high','filter_order','filter_ripple',...
						'threshold_method','threshold_parameter','threshold_sign'};
					sizes_needed = {[1 1], [1 1], [1 1], [1 1],...
						[1 1],[1 1],...
						[1 1],[1 -1],[1 1],[1 1],[1 1],[1 1],...
						[1 -1], [1 1], [1 1]};

					[b,errormsg] = vlt.data.hasAllFields(extraction_params,fields_needed, sizes_needed);
				elseif strcmpi(appdoc_type,'spikewaves'),
					% only the app creates this type, so it passes
					b = 1;
				elseif strcmpi(appdoc_type,'spiketimes'),
					% only the app creates this type, so it passes
					b = 1;
				else,
					error(['Unknown appdoc_type ' appdoc_type '.']);
				end;

		end; % isvalid_appdoc_struct()

                function doc = find_appdoc(ndi_app_spikeextractor_obj, appdoc_type, varargin)
                        % FIND_APPDOC - find an ndi_app_appdoc document in the session database
                        %
			% See ndi_app_spikeextractor/APPDOC_DESCRIPTION for documentation.
			%
			% See also: ndi_app_spikeextractor/APPDOC_DESCRIPTION
			%
        			switch(lower(appdoc_type)),
					case 'extraction_parameters',
						extraction_parameters_name = varargin{1};
		
						extract_searchq = ndi.query('ndi_document.name','exact_string',extraction_parameters_name,'') & ...
							ndi.query('','isa','spike_extraction_parameters','');
						doc = ndi_app_spikeextractor_obj.session.database_search(extract_searchq);

					case {'extraction_parameters_modification', 'spikewaves','spiketimes'}, 
						ndi_timeseries_obj = varargin{1};
						epoch = varargin{2};
						extraction_parameters_name = varargin{3};

						extraction_parameters_doc = ndi_app_spikeextractor_obj.find_appdoc('extraction_parameters',extraction_parameters_name);

						epoch_string = ndi_timeseries_obj.epoch2str(epoch); % make sure to use string form
						spikedocs_searchq = ndi.query(ndi_app_spikeextractor_obj.searchquery()) & ...
							ndi.query('epochid','exact_string',epoch_string,'') & ...
							ndi.query('','depends_on','element_id',ndi_timeseries_obj.id()) & ...
							ndi.query('','depends_on','extraction_parameters_id',extraction_parameters_doc{1}.id());
						spikewaves_search = ndi.query('','isa','spikewaves','');
						spiketimes_search = ndi.query('','isa','spiketimes','');
						extraction_parameters_modification_search = ndi.query('','isa','spike_extraction_parameters_modification','');
						if strcmp(appdoc_type,'spikewaves'),
							spikedocs_searchq = spikedocs_searchq & spikewaves_search;
						elseif strcmp(appdoc_type,'spiketimes'),
							spikedocs_searchq = spikedocs_searchq & spiketimes_search;
						elseif strcmp(appdoc_type,'extraction_parameters_modification'),
							spikedocs_searchq = spikedocs_searchq & extraction_parameters_modification_search;
						end;
		
						doc = ndi_app_spikeextractor_obj.session.database_search(spikedocs_searchq);

					otherwise,
						error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
				end; % switch
                end; % find_appdoc

		function varargout = loaddata_appdoc(ndi_app_spikeextractor_obj, appdoc_type, varargin)
			% LOADDATA_APPDOC - load data from an application document
			%
			% See ndi_app_spikeextractor/APPDOC_DESCRIPTION for documentation.
			%
			% See also: ndi_app_spikeextractor/APPDOC_DESCRIPTION
			%
				switch(lower(appdoc_type)),
					case {'extraction_parameters','extraction_parameters_modification'},
						varargout{1} = ndi_app_spikeextractor_obj.find_appdoc(appdoc_type,varargin{:});
					case 'spikewaves',
						spikewaves_doc = ndi_app_spikeextractor_obj.find_appdoc(appdoc_type,varargin{:});

						if numel(spikewaves_doc)==1,
							spikewaves_doc = spikewaves_doc{1};
							spikewaves_binarydoc = ndi_app_spikeextractor_obj.session.database_openbinarydoc(spikewaves_doc);
							[waveforms,waveparameters] = vlt.file.custom_file_formats.readvhlspikewaveformfile(spikewaves_binarydoc);
							waveparameters.samplerate = waveparameters.samplingrate;
							ndi_app_spikeextractor_obj.session.database_closebinarydoc(spikewaves_binarydoc);
						elseif numel(spikewaves_doc)>1,
							error(['Found ' int2str(numel(spikewaves_doc)) ...
								' documents matching the criteria. Do not know how to proceed.']);
						else,
							waveforms = [];
							waveparameters = [];
						end;

						varargout{1} = waveforms;
						varargout{2} = waveparameters;
						varargout{3} = spikewaves_doc;

					case 'spiketimes',
						spiketimes_doc = ndi_app_spikeextractor_obj.find_appdoc(appdoc_type,varargin{:});

						if numel(spiketimes_doc)==1,
							spiketimes_doc = spiketimes_doc{1};
							spiketimes_binarydoc = ndi_app_spikeextractor_obj.session.database_openbinarydoc(spiketimes_doc);
							times = fread(spiketimes_binarydoc,Inf,'float32');
							ndi_app_spikeextractor_obj.session.database_closebinarydoc(spiketimes_binarydoc);
						elseif numel(spiketimes_doc)>1,
							error(['Found ' int2str(numel(spiketimes_doc)) ...
								' documents matching the criteria. Do not know how to proceed.']);
						else,
							times = [];
						end;

						varargout{1} = times;
						varargout{2} = spiketimes_doc;

					otherwise,
						error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
				end; % switch
		end; % loaddata_appdoc()

		function appdoc_description(ndi.app.appdoc_obj)
			% APPDOC_DESCRIPTION - a function that prints a description of all appdoc types
			%
			% For ndi_app_spikeextractor, there are the following types:
			% APPDOC_TYPE                 | Description
			% ----------------------------------------------------------------------------------------------
			% 'extraction_parameters'     | A document that describes the parameters to be used for extraction
			% ['extraction_parameters'... | A document that describes modifications to the parameters to be used for extracting
			%     '_modification']        |    a particular epoch.
			% 'spikewaves'                | A document that stores spike waves found by the extractor in an epoch
			% 'spiketimes'                | A document that stores the times of the waves found by the extractor in an epoch
			% ----------------------------------------------------------------------------------------------
			%
			% ----------------------------------------------------------------------------------------------
			% APPDOC 1: EXTRACTION_PARAMETERS
			% ----------------------------------------------------------------------------------------------
			%
			%   ----------------------------------
			%   | EXTRACTION_PARAMETERS -- ABOUT | 
			%   ----------------------------------
			%
			%   EXTRACTION_PARAMETERS documents hold the parameters that are to be used to guide the extraction of
			%   spikewaves.
			%
			%   Definition: app/spikeextractor/extraction_parameters
			%
			%   -------------------------------------
			%   | EXTRACTION_PARAMETERS -- CREATION | 
			%   -------------------------------------
			%
			%   DOC = STRUCT2DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'extraction_parameters', EXTRACTION_PARAMS, EXTRACTION_NAME)
			%
			%   EXTRACTION_NAME is a string containing the name of the extraction document.
			%
			%   EXTRACTION_PARAMS should contain the following fields:
			%   Fieldname                 | Description
			%   -------------------------------------------------------------------------
			%   center_range (10)         | Range in samples to find spike center
			%   overlap (0.5)             | Overlap allowed
			%   read_time (30)            | Number of seconds to read in at a single time
			%   refractory_samples (10)   | Number of samples to use as a refractory period
			%   spike_sample_start (-9)   | Samples before the threshold to include % unclear if time or sample
			%   spike_sample_stop (20)    | Samples after the threshold to include % unclear if time or sample
			%   start_time (1)            | First sample to read
			%   do_filter (1)             | Should we perform a filter? (0/1)
			%   filter_type               | What filter? Default is 'cheby1high' but can also be 'none'
			%    ('cheby1high')           | 
			%   filter_low (0)            | Low filter frequency
			%   filter_high (300)         | Filter high frequency
			%   filter_order (4)          | Filter order
			%   filter_ripple (0.8)       | Filter ripple parameter
			%   threshold_method          | Threshold method. Can be "standard_deviation" or "absolute"
			%   threshold_parameter       | Threshold parameter. If threshold_method is "standard_deviation" then
			%      ('standard_deviation') |    this parameter is multiplied by the empirical standard deviation.
			%                             |    If "absolute", then this value is taken to be the absolute threshold.
			%   threshold_sign (-1)       | Threshold crossing sign (-1 means high-to-low, 1 means low-to-high)
			%
			%   ------------------------------------
			%   | EXTRACTION_PARAMETERS -- FINDING |
			%   ------------------------------------
			%
			%   [EXTRACTION_PARAMETERS_DOC] = FIND_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, ...
			%        'extraction_parameters', EXTRACTION_PARAMETERS_NAME)
			%
			%   INPUTS: 
			%     EXTRACTION_PARAMETERS_NAME - the name of the extraction parameter document
			%   OUPUT: 
			%     Returns the extraction parameters ndi.document with the name EXTRACTION_NAME.
			%
			%   ------------------------------------
			%   | EXTRACTION_PARAMETERS -- LOADING |
			%   ------------------------------------
			%
			%   [EXTRACTION_PARAMETERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, ...
			%        'extraction_parameters', EXTRACTION_NAME)
			% 
			%   INPUTS: 
			%     EXTRACTION_PARAMETERS_NAME - the name of the extraction parameter document
			%   OUPUT: 
			%     Returns the extraction parameters ndi.document with the name EXTRACTION_NAME.
			%
			%
			% ----------------------------------------------------------------------------------------------
			% APPDOC 2: EXTRACTION_PARAMETERS_MODIFICATION
			% ----------------------------------------------------------------------------------------------
			%
			%   -----------------------------------------------
			%   | EXTRACTION_PARAMETERS_MODIFICATION -- ABOUT | 
			%   -----------------------------------------------
			%
			%   EXTRACTION_PARAMETERS_MODIFICATION documents allow the user to modify the spike extraction 
			%   parameters for a specific epoch.
			%
			%   Definition: app/spikeextractor/extraction_parameters_modification
			%
			%   --------------------------------------------------
			%   | EXTRACTION_PARAMETERS_MODIFICATION -- CREATION | 
			%   --------------------------------------------------
			%
			%   DOC = STRUCT2DOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'extraction_parameters_modification',  ...
			%      EXTRACTION_PARAMS, EXTRACTION_NAME)
			%
			%   EXTRACTION_NAME is a string containing the name of the extraction document.
			%
			%   EXTRACTION_PARAMS should contain the following fields:
			%   Fieldname                 | Description
			%   -------------------------------------------------------------------------
			%   center_range (10)         | Range in samples to find spike center
			%   overlap (0.5)             | Overlap allowed
			%   read_time (30)            | Number of seconds to read in at a single time
			%   refractory_samples (10)   | Number of samples to use as a refractory period
			%   spike_sample_start (-9)   | Samples before the threshold to include % unclear if time or sample
			%   spike_sample_stop (20)    | Samples after the threshold to include % unclear if time or sample
			%   start_time (1)            | First sample to read
			%   do_filter (1)             | Should we perform a filter? (0/1)
			%   filter_type               | What filter? Default is 'cheby1high' but can also be 'none'
			%    ('cheby1high')           | 
			%   filter_low (0)            | Low filter frequency
			%   filter_high (300)         | Filter high frequency
			%   filter_order (4)          | Filter order
			%   filter_ripple (0.8)       | Filter ripple parameter
			%   threshold_method          | Threshold method. Can be "standard_deviation" or "absolute"
			%   threshold_parameter       | Threshold parameter. If threshold_method is "standard_deviation" then
			%      ('standard_deviation') |    this parameter is multiplied by the empirical standard deviation.
			%                             |    If "absolute", then this value is taken to be the absolute threshold.
			%   threshold_sign (-1)       | Threshold crossing sign (-1 means high-to-low, 1 means low-to-high)
			%
			%   -------------------------------------------------
			%   | EXTRACTION_PARAMETERS_MODIFICATION -- FINDING |
			%   -------------------------------------------------
			%
			%   [EXTRACTION_PARAMETERS_MODIFICATION_DOC] = FIND_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, ...
			%        'extraction_parameters_modification', NDI_TIMESERIES_OBJ, EPOCHID, EXTRACTION_NAME)
			%
			%   INPUTS: 
			%      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
			%      EPOCH - the epoch identifier to be accessed
			%      EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
			%   OUPUT: 
			%     Returns the extraction parameters modification ndi.document with the name EXTRACTION_NAME
			%      for the named EPOCHID and NDI_TIMESERIES_OBJ.
			%
			%   -------------------------------------------------
			%   | EXTRACTION_PARAMETERS_MODIFICATION -- LOADING |
			%   -------------------------------------------------
			%
			%   [EXTRACTION_PARAMETERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, ...
			%        'extraction_parameters_modification', NDI_TIMESERIES_OBJ, EPOCHID, EXTRACTION_NAME)
			% 
			%   INPUTS: 
			%      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
			%      EPOCH - the epoch identifier to be accessed
			%      EXTRACTION_PARAMETERS_NAME - the name of the extraction parameter document
			%   OUPUT: 
			%     Returns the extraction parameters modification ndi.document with the name EXTRACTION_NAME.
			%
			% ----------------------------------------------------------------------------------------------
			% APPDOC 3: SPIKEWAVES
			% ----------------------------------------------------------------------------------------------
			%
			%   -----------------------
			%   | SPIKEWAVES -- ABOUT | 
			%   -----------------------
			%
			%   SPIKEWAVES documents store the spike waveforms that are read during a spike extraction. It
			%   DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the EXTRACTION_PARAMETERS
			%   that descibed the extraction.
			%
			%   Definition: app/spikeextractor/spikewaves
			%
			%   --------------------------
			%   | SPIKEWAVES -- CREATION | 
			%   --------------------------
			%
			%   Spikewaves documents are created internally by the EXTRACT function
			%
			%   ------------------------
			%   | SPIKEWAVES - FINDING |
			%   ------------------------
			%
			%   [SPIKEWAVES_DOC] = FIND_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'spikewaves', ...
			%                               NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
			%
			%   INPUTS:
			%      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
			%      EPOCH - the epoch identifier to be accessed
			%      EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
			%   OUTPUT:
			%      SPIKEWAVES_DOC - the ndi.document of the extracted spike waves.
			%
			%   ------------------------
			%   | SPIKEWAVES - LOADING |
			%   ------------------------
			%
			%   [CONCATENATED_SPIKES, WAVEPARAMETERS, SPIKEWAVES_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'spikewaves', ...
			%                               NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
			%
			%   INPUTS:
			%      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
			%      EPOCH - the epoch identifier to be accessed
			%      EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
			%   
			%   OUTPUTS:
			%      CONCATENATED_SPIKES - an array of spike waveforms SxDxN, where S is the number of samples per channel of each waveform, 
			%         D is the number of channels (dimension), and N is the number of spike waveforms
			%      WAVEPARAMETERS - a structure with the following fields:
			%        Field              | Description
			%        --------------------------------------------------------
			%        numchannels        | Number of channels in each spike
			%        S0                 | Number of samples before spike center
			%                           |    (usually negative)
			%        S1                 | Number of samples after spike center
			%                           |    (usually positive)
			%        samplerate         | The sampling rate
			%      SPIKEWAVES_DOC - the ndi.document of the extracted spike waves.
			%
			% ----------------------------------------------------------------------------------------------
			% APPDOC 4: SPIKETIMES
			% ----------------------------------------------------------------------------------------------
			%
			%   -----------------------
			%   | SPIKETIMES -- ABOUT | 
			%   -----------------------
			%
			%   SPIKETIMES documents store the times spike waveforms that are read during a spike extraction. It
			%   DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the EXTRACTION_PARAMETERS
			%   that descibed the extraction. The times are in the local epoch time units.
			%
			%   Definition: app/spikeextractor/spiketimes
			%
			%   --------------------------
			%   | SPIKETIMES -- CREATION | 
			%   --------------------------
			%
			%   Spiketimes documents are created internally by the EXTRACT function
			%
			%   ------------------------
			%   | SPIKETIMES - FINDING |
			%   ------------------------
			%
			%   [SPIKETIMES_DOC] = FIND_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'spiketimes', ...
			%                               NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
			%
			%   INPUTS:
			%      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
			%      EPOCH - the epoch identifier to be accessed
			%      EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
			%   OUTPUT:
			%      SPIKEWAVES_DOC - the ndi.document of the extracted spike waves.
			%
			%   ------------------------
			%   | SPIKETIMES - LOADING |
			%   ------------------------
			%
			%   [SPIKETIMES, SPIKETIMES_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKEEXTRACTOR_OBJ, 'spiketimes', ...
			%                               NDI_TIMESERIES_OBJ, EPOCH, EXTRACTION_NAME)
			%
			%   INPUTS:
			%      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
			%      EPOCH - the epoch identifier to be accessed
			%      EXTRACTION_NAME - the name of the extraction parameters document used in the extraction
			%   
			%   OUTPUTS:
			%      SPIKETIMES - the time of each spike wave, in local epoch time coordinates
			%      SPIKETIMES_DOC - the ndi.document of the extracted spike times.
			%
 	 		% ----------------------------------------------------------------------------------------------
			%
				eval(['help ndi_app_spikeextractor/appdoc_description']); 
		end; % appdoc_description()

	end; % methods

end % ndi_app_spikeextractor
