classdef tagger < ndi.app & ndi.app.appdoc

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_tagger_obj = spikeextractor(varargin)
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
				
				ndi_app_spikeextractor_obj = ndi_app_spikeextractor_obj@ndi.app(session, name);
				ndi_app_spikeextractor_obj = ndi_app_spikeextractor_obj@ndi.app.appdoc(...
					{'extraction_parameters','extraction_parameters_modification', 'spikewaves','spiketimes'},...
					{'apps/spikeextractor/spike_extraction_parameters','apps/spikeextractor/spike_extraction_parameters_modification',...
						'apps/spikeextractor/spikewaves','apps/spikeextractor/spiketimes'},...
					session);

		end % ndi_app_spikeextractor() creator

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
						if numel(varargin)<1,
							error(['extraction_parameters documents need a name. Please pass a name. See help ndi.app.spikeextractor/appdoc_description']);
						end;
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
				if ~ischar(appdoc_type),
					error(['appdoc_type must be a character string indicating the document type to use. Got a ' class(appdoc_type) '.']);
				end;
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

		function appdoc_description(ndi_app_appdoc_obj)
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
