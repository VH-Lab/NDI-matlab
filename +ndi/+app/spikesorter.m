classdef spikesorter < ndi.app & ndi.app.appdoc

	properties (SetAccess=protected,GetAccess=public)
	end % properties

	methods

		function ndi_app_spikesorter_obj =spikesorter(varargin)
		% NDI.APP.spikesorter - an app to sort spikewaves found in sessions
		%
		% NDI.APP.spikesorter_OBJ = ndi.app.spikesorter(SESSION)
		%
		% Creates a new NDI_APP_spikesorter object that can operate on
		% NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.
		%
			session = [];
			name = 'ndi_app_spikesorter';
			if numel(varargin)>0,
				session = varargin{1};
			end
            
			ndi_app_spikesorter_obj = ndi_app_spikesorter_obj@ndi.app(session, name);
			%intiate app doc
			ndi_app_spikesorter_obj = ndi_app_spikesorter_obj@ndi.app.appdoc(...
				{'sorting_parameters','spike_clusters'},...
				{'apps/spikesorter/sorting_parameters','apps/spikesorter/spike_clusters'},...
				session);
		end % ndi.app.spikesorter() creator
        
		function spike_sort(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name, sort_name, redo)
			% SPIKE_SORT - method that sorts spikes from specific probes in session to ndi_doc
			%
			% SPIKE_SORT(SPIKEWAVES, SORT_NAME, SORTING_PARAMS)
			%%%%%%%%%%%%%%
			% SORT_NAME name given to save sort to ndi_doc
        
				if exist('redo','var') == 0
					redo = 0
				end

				% epoch_string = ndi_timeseries_obj.epoch2str(epoch{n});

			% sorter_searchq = cat(2,ndi_app_spikesorter_obj.searchquery(), ...
			% 			{'epochid', epoch_string, 'spikewaves.sort_name', extraction_name});
			% 		old_sort_doc = ndi_app_spikesorter_obj.session.database_search(spikewaves_searchq);
					
			% if ~isempty(old_sort_doc) & ~redo
			% 	% we already have this epoch
			% 	continue % skip to next epoch
			% end

				% Clear sort within probe with sort_name
					% replace with appdoc
				ndi_app_spikesorter_obj.clear_sort(ndi_timeseries_obj, epoch, sort_name);

				sorting_parameters_doc = ndi_app_spikesorter_obj.find_appdoc('sorting_parameters', sort_name);
                    
				if isempty(sorting_parameters_doc),
					error(['No sorting_parameters document named ' sort_name ' found.']);
				elseif numel(sorting_parameters_doc)>1,
					error(['More than one sorting_parameters document with same name. Should not happen but needs to be fixed.']);
				else,
					sorting_parameters_doc = sorting_parameters_doc{1};
				end;

			% Read spikewaves here
			ndi_app_spikeextractor_obj = ndi.app.spikeextractor(ndi_app_spikesorter_obj.session);

			% need to loop over epochs here
            
				[waveforms, ~, spikewaves_doc] = ndi_app_spikeextractor_obj.loaddata_appdoc('spikewaves', ...
					ndi_timeseries_obj, epoch, extraction_name);

				% Interpolation
				interpolation = sorting_parameters_doc.document_properties.sorting_parameters.interpolation;
				waveforms_out = zeros(interpolation*size(waveforms,1), size(waveforms,2), size(waveforms,3));
				x = 1:length(waveforms(:,1,1));
				xq = 1/interpolation:1/interpolation:length(waveforms(:,1,1));
			
				for i=1:size(waveforms, 3)
					waveforms_out(:,:,i) = interp1(x, waveforms(:,:,i), xq, 'spline');
				end

				spikesamples = size(waveforms_out,1);
				nchannels = size(waveforms_out,2);
				nspikes = size(waveforms_out,3);

				% Concatenate waves for PCA
				concatenated_waves = reshape(waveforms_out,[spikesamples * nchannels,nspikes]);
				concatenated_waves = concatenated_waves';
				%% Spike Features (PCA)

				% get covariance matrix of the TRANSPOSE of spike array (waveforms need
				% to be in the rows for cov to give what we want)
				covariance = cov(concatenated_waves);

				% get eigenvectors & eigenvalues - these are pre-sorted in order of
				% ASCENDING eigenvalue
				[eigenvectors, eigenvalues] = eig(covariance);
				eigvals = diag(eigenvalues);

				% sort in order of DESCENDING eigenvalues
				[eigvals, indx] = sort(eigvals, 'descend');
				eigenvectors = eigenvectors(:, indx);

				% Project original waveforms into eigenvector space
				projected_waveforms = concatenated_waves * [eigenvectors];

				% Features used in klustakwik_cluster
				pca_coefficients = projected_waveforms(:, 1:sorting_parameters_doc.document_properties.sorting_parameters.num_pca_features);

				disp('KlustarinKwikly...');
				[clusterids,numclusters] = klustakwik_cluster(pca_coefficients, 3, 25, 5, 0);

				times = ndi_app_spikeextractor_obj.loaddata_appdoc('spiketimes', ndi_timeseries_obj, epoch, extraction_name);
            
				% spiketimes_samples = ndi_timeseries_obj.times2samples(1, times);
            
				% Uncomment to enable spikewaves_gui
				% vlt.neuro.spikesorting.cluster_spikewaves_gui('waves', spikewaves, 'waveparameters', waveparameters, ...
				%	'clusterids', spikeclusterids, 'wavetimes', spiketimes);
					% 'EpochStartSamples', epoch_start_samples, 'EpochNames', epoch_names);
				disp('Done clustering.');

				% Create spike_clusters ndi_doc
				spike_clusters_doc = ndi_app_spikesorter_obj.session.newdocument('apps/spikesorter/spike_clusters', ...
					'spike_sort.sort_name', sort_name, ...
					'spike_sort.epoch', epoch, ...
					'spike_sort.clusterids', clusterids, ...
					'spike_sort.spiketimes', times, ...
					'spike_sort.numclusters', numclusters, ...
					'ndi_document_epochid.epochid', ndi_timeseries_obj.epochid(epoch)) ...
					+ ndi_app_spikesorter_obj.newdocument();
				spike_clusters_doc = spike_clusters_doc.set_dependency_value('element_id', ndi_timeseries_obj.id());
				% spike_clusters_doc = spike_clusters_doc.set_dependency_value('extraction_parameters',the.id());
				spike_clusters_doc = spike_clusters_doc.set_dependency_value('sorting_parameters_id',sorting_parameters_doc.id());
				spike_clusters_doc = spike_clusters_doc.set_dependency_value('spikewaves_doc_id',spikewaves_doc.id()); % TODO: name 'spikewaves_doc' subject to change
				
				% Add doc to database
				ndi_app_spikesorter_obj.session.database_add(spike_clusters_doc);

				disp(['----' num2str(numclusters) ' neuron(s) found----'])

			for nNeuron=1:numclusters

				disp(['--------NEURON_' num2str(nNeuron) '--------'])
                

				neuron_element = ndi.element.timeseries(ndi_app_spikesorter_obj.session, ['neuron_' num2str(nNeuron)], ndi_timeseries_obj.reference, 'neuron', ndi_timeseries_obj, 0);
				doc = neuron_element.newdocument();
				%%% TODO: add properties like epoch and stuff?

				et = ndi_timeseries_obj.epochtable;
				
				neuron_times_idxs = find(clusterids == nNeuron);
                keyboard
				neuron_spiketimes = times(neuron_times_idxs);
                
        disp(['---Number of Spikes ' num2str(length(neuron_spiketimes)) '---'])
				
				[neuron, mydoc] = neuron_element.addepoch(...
					et(1).epoch_id, ...
					et(1).epoch_clock{1}, ...
					et(1).t0_t1{1}, ...
					neuron_spiketimes(:), ...
					ones(size(neuron_spiketimes(:)))...
				);
			
			end
			
			neuron

			neuron1 = ndi_app_spikesorter_obj.session.getelements('element.name','neuron_1');
			% neuron2 = ndi_app_spikesorter_obj.session.getelements('element.name','neuron_2');

			[d1,t1] = readtimeseries(neuron1{1},1,-Inf,Inf);
			% [d2,t2] = readtimeseries(neuron2{1},1,-Inf,Inf);

			figure(10)
			plot(t1,d1,'ko');
			title([neuron.name]);
			ylabel(['spikes']);
			xlabel(['time (s)']);
		end % spike_sort()

		function clusters2neurons(ndi_app_spikesorter_obj, ndi_timeseries_obj, sorting_name)
			% CLUSTERS2NEURONS - create ndi.neuron objects from spike clusterings
			%
			% CLUSTERS2NEURONS(NDI_APP_SPIKESORTER_OBJ, SPIKESORTER_CLUSTER_DOCUMENT) 
			%  or
			% CLUSTERS2NEURONS(NDI_APP_SPIKESORTER_OBJ, NDI_TIMESERIES_OBJ, SORTING_NAME, REDO)
			%
			% Generates ndi.neuron objects for each spike cluster represented in the 
			%
					% needs development
				for nNeuron=1:numclusters
					neuron_element = ndi.element.timeseries(ndi_app_spikesorter_obj.session, ...
						['neuron_' num2str(nNeuron)], ndi_timeseries_obj.reference, 'neuron', ndi_timeseries_obj, 0);
					doc = neuron_element.newdocument();
					et = ndi_timeseries_obj.epochtable;
					neuron_times_idxs = find(clusterids == nNeuron);
					neuron_spiketimes = times(neuron_times_idxs);
					[neuron, mydoc] = neuron_element.addepoch(...
						et(1).epoch_id, ...
						et(1).epoch_clock{1}, ...
						et(1).t0_t1{1}, ...
						neuron_spiketimes(:), ...
						ones(size(neuron_spiketimes(:)))...
					);
				end
		end; %  clusters2neurons()

        %access cluster doc
		function doc = load_spike_clusters_doc(ndi_app_spikesorter_obj, ndi_probe_obj, epoch, sort_name)
		
			searchq = cat(2,ndi_app_spikesorter_obj.searchquery(), ...
				{'spike_sort.sort_name', sort_name, 'spike_sort.epoch', epoch});
			
			doc = ndi_app_spikesorter_obj.session.database_search(searchq);

        end %fct end


		function b = clear_sort(ndi_app_spikesorter_obj, ndi_probe_obj, epoch, sort_name)
		% CLEAR_SORT - clear all 'sorted spikes' records for an NDI_PROBE_OBJ from session database
		%
		% B = CLEAR_SORT(NDI_APP_SPIKESORTER_OBJ, NDI_EPOCHSET_OBJ)
		%
		% Clears all sorting entries from the session database for object NDI_PROBE_OBJ.
		%
		% Returns 1 on success, 0 otherwise.

			% Look for any docs matching extraction name and remove them
			% Concatenate app query parameters and sort_name parameter
			searchq = cat(2,ndi_app_spikesorter_obj.searchquery(), ...
				{'spike_sort.sort_name', sort_name, 'spike_sort.epoch', epoch});

			% Concatenate probe query parameters
			searchq = cat(2, searchq, ndi_probe_obj.searchquery());

			% Search and get any docs
			mydoc = ndi_app_spikesorter_obj.session.database_search(searchq);

			% Remove the docs
			if ~isempty(mydoc),
				for i=1:numel(mydoc),
					ndi_app_spikesorter_obj.session.database_rm(mydoc{i}.id())
				end
				warning(['removed ' num2str(i) ' doc(s) with same extraction name'])
				b = 1;
			end
		end % clear_sort()

	% FUNCTIONS NEEDED
	%   loadSpikeWaves (from all epochs)
	%   initializeClusters

        %% functions that override ndi_app_appdoc
        
        function doc = struct2doc(ndi_app_spikesorter_obj, appdoc_type, appdoc_struct, varargin)
			% STRUCT2DOC - create an ndi.document from an input structure and input parameters
			%
			% DOC = STRUCT2DOC(ndi.app.spikeextractor_OBJ, APPDOC_TYPE, APPDOC_STRUCT, ...)
			%
			% For ndi.app.spikeextractor, one can use an APPDOC_TYPE of the following:
			% APPDOC_TYPE                 | Description
			% ----------------------------------------------------------------------------------------------
			% 'sorting_parameters'  | A document that 
			% 'spike_clusters'      | A document that  
			% 
			%
			% See APPDOC_DESCRIPTION for a list of the parameters.
			% 
				if strcmpi(appdoc_type,'sorting_parameters'),
					sorting_name = varargin{1};
					doc = ndi.document('apps/spikesorter/sorting_parameters',...
						'sorting_parameters',appdoc_struct) + ...
						ndi_app_spikesorter_obj.newdocument() + ...
						ndi.document('ndi_document','ndi_document.name',sorting_name);
				elseif strcmpi(appdoc_type,'spike_clusters'),
					sorting_name = varargin{1};
					epoch = varargin{2};
					clusterid = varargin{3};
					numcluscters = varargin{4};
					epochid = varargin{5};
					epochid_string = ndi_timeseries_obj.epoch2string(epochid); %make sure to use string form
                
					doc= ndi.dociment('apps/spikesorter/spike_clusters',...
						'spike_clusters', appdoc_struct, 'epoch', epoch, 'clusterid', clusterid, ...
						'numcluscters', numcluscters, 'epochid', epochid_string) + ...
						ndi_app_spikesorter_obj.newdocument() + ...
						ndi.document('ndi_document', 'ndi_document.name', sorting_name);
				else
					error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
				end
            
			end %struct2doc()
        
		function [b,errormsg] = isvalid_appdoc_struct(ndi_app_spikesorter_obj, appdoc_type, appdoc_struct)
			% ISVALID_APPDOC_STRUCT - is an input structure a valid descriptor for an APPDOC?
			%
			% [B,ERRORMSG] = ISVALID_APPDOC_STRUCT(ndi.app.spikeextractor_OBJ, APPDOC_TYPE, APPDOC_STRUCT)
			%
			% Examines APPDOC_STRUCT and determines whether it is a valid input for creating an
			% ndi.document described by APPDOC_TYPE. B is 1 if it is valid and 0 otherwise.
			%
			% For ndi_app_spikesorter, one can use an APPDOC_TYPE of the following:
			% APPDOC_TYPE               | Description
			% ----------------------------------------------------------------------------------------------
			% 'sorting_parameters'   | A document that describes the parameters to be used for sorting
			% 'spike_clusters'       | A document that describes the 
		    
				errormsg = '';
		    
				if strcmpi(appdoc_type,'sorting_parameters')
					sorting_parameters = appdoc_struct;
					%check parameters here
					fields_needed = {'graphical_mode', 'num_pca_features', 'interpolation','min_clusters','max_clusters','num_start'};
					sizes_needed = {[1 1],[1 1],[1 1],[1 1],[1 1],[1 1]}; % all single numbers, size should be 1x1
					[b,errormsg] = vlt.data.hasAllFields(sorting_parameters, fields_needed, sizes_needed);
				elseif strcmpi(appdoc_type,'spike_clusters')
					% fix, need more info actually
					spike_clusters = appdoc_struct;
					
					%check parameters here
					fields_needed = {'epoch','clusterids', 'spiketimes', 'numclusters', 'epochid'};
					sizes_needed = {[1 1], [1 -1], [1 -1], [1 -1], [1 -1]};
					
					[b,errormsg] = vlt.data.hasAllFields(spike_clusters, fields_needed, sizes_needed);
					
				else
					error(['Unknown appdoc_type' appdoc_type '.']);
		    
				end
		    
	        end % isvalid_appdoc_struct()
        
		function doc = find_appdoc(ndi_app_spikesorter_obj, appdoc_type, varargin)
			% FIND_APPDOC - find an ndi_app_appdoc document in the session database
			%
			% See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.
			%
            
				switch(lower(appdoc_type))
					case 'sorting_parameters'
						sorting_parameters_name = varargin{1};
                    
						sorting_search = ndi.query('ndi_document.name','exact_string',sorting_parameters_name,'') & ...
						ndi.query('','isa','sorting_parameters', '');
						doc = ndi_app_spikesorter_obj.session.database_search(sorting_search);
                
					case 'spike_clusters'
						spike_clusters_name = varargin{1};
                    
						cluster_search = ndi.query('ndi.document.name', 'exact_string', spike_clusters_name, '') & ...
						ndi.query('', 'isa', 'spike_clusters', '');
						doc = ndi_app_spikesorter_obj.session.database_search(cluster_search);
                
					otherwise
						error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
					end %switch
		end % find_appdoc()
        
		function varargout = loaddata_appdoc(ndi_app_spikesorter_obj, appdoc_type, varargin)
			% LOADDATA_APPDOC - load data from an application document
			%
			% See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.
			%
				switch(lower(appdoc_type))
					case {'sorting_parameters','spike_clusters'},
						varargout{1} = ndi_app_spikesorter_obj.find_appdoc(appdoc_type,varargin{:});
                
					otherwise
						error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
				end %switch
		end % loaddata_appdoc()
        
		function appdoc_description(ndi_app_appdoc_obj)
			% APPDOC_DESCRIPTION - a function that prints a description of all appdoc types
			%
			% For ndi_app_spikeextractor, there are the following types:
			% APPDOC_TYPE                 | Description
			% ----------------------------------------------------------------------------------------------
			% 'sorting_parameters'        | A document that describes the parameters to be used for sorting
			% 'spikeclusters'             | A document that contains the assignment of a set of spikes to clusters
			% ----------------------------------------------------------------------------------------------
			%
			% ----------------------------------------------------------------------------------------------
			% APPDOC 1: SORTING_PARAMETERS
			% ----------------------------------------------------------------------------------------------
			%
			%   ----------------------------------
			%   | SORTING_PARAMETERS -- ABOUT | 
			%   ----------------------------------
			%
			%   SORTING_PARAMETERS documents hold the parameters that are to be used to guide the extraction of
			%   spikewaves.
			%
			%   Definition: apps/spikesorter/sorting_parameters.json
			%
			%   -------------------------------------
			%   | SORTING_PARAMETERS -- CREATION | 
			%   -------------------------------------
			%
			%   DOC = STRUCT2DOC(NDI_APP_SPIKESORTER_OBJ, 'sorting_parameters', SORTING_PARAMS, SORTING_PARAMETERS_NAME)
			%
			%   SORTING_NAME is a string containing the name of the extraction document.
			%
			%   SORTING_PARAMS should contain the following fields:
			%   Fieldname                 | Description
			%   -------------------------------------------------------------------------
			%   graphical_mode (0)        | Should we use graphical mode (1) or automatic mode (0)?
			%   num_pca_features (10)     | Number of pca-driven features to use in the clustering calculation in automatic mode
			%   interpolation (3)         | By how many times should we oversample the spikes, interpolating by splines?
			%   min_clusters (1)          | Minimum clusters parameter for KlustaKwik in automatic mode
			%   max_clusters (10)         | Maximum clusters parameter for KlustaKwik in automatic mode
			%   num_start (5)             | Number of random starting positions in automatic mode
			%   
			%
			%   ------------------------------------
			%   | SORTING_PARAMETERS -- FINDING |
			%   ------------------------------------
			%
			%   [SORTING_PARAMETERS_DOC] = FIND_APPDOC(NDI_APP_SPIKESORTER_OBJ, ...
			%        'sorting_parameters', SORTING_PARAMETERS_NAME)
			%
			%   INPUTS: 
			%     SORTING_PARAMETERS_NAME - the name of the sorting parameter document
			%   OUPUT: 
			%     Returns the sorting parameters ndi.document with the name SORTING_PARAMETERS_NAME.
			%
			%   ------------------------------------
			%   | SORTING_PARAMETERS -- LOADING |
			%   ------------------------------------
			%
			%   [SORTING_PARAMETERS_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKESORTER_OBJ, ...
			%        'sorting_parameters', SORTING_PARAMETERS_NAME)
			% 
			%   INPUTS: 
			%     SORTING_PARAMETERS_NAME - the name of the sorting parameter document
			%   OUPUT: 
			%     Returns the sorting parameters ndi.document with the name SORTING_PARAMETERS_NAME.
			%
			% ----------------------------------------------------------------------------------------------
			% APPDOC 2: SPIKE_CLUSTERS
			% ----------------------------------------------------------------------------------------------
			%
			%   ---------------------------
			%   | SPIKE_CLUSTERS -- ABOUT | 
			%   ---------------------------
			%
			%   SPIKEWAVES documents store the spike waveforms that are read during a spike extraction. It
			%   DEPENDS ON the ndi.time.timeseries object on which the extraction is performed and the SORTING_PARAMETERS
			%   that descibed the extraction.
			%
			%   Definition: apps/spikesorter/spike_clusters
			%
			%   ------------------------------
			%   | SPIKE_CLUSTERS -- CREATION | 
			%   ------------------------------
			%
			%   Spike cluster documents are created internally by the SORT function
			%
			%   ----------------------------
			%   | SPIKE_CLUSTERS - FINDING |
			%   ----------------------------
			%
			%   [SPIKECLUSTERS_DOC] = FIND_APPDOC(NDI_APP_SPIKESORTER_OBJ, 'spike_clusters', ...
			%                               NDI_TIMESERIES_OBJ, SORTING_PARAMETERS_NAME)
			%
			%   INPUTS:
			%      NDI_TIMESERIES_OBJ - the ndi.time.timeseries object that was used in the extraction
			%      SORTING_PARAMETERS_NAME - the name of the sorting parameters document used in the sorting
			%   OUTPUT:
			%      SPIKECLUSTERS_DOC - the ndi.document of the clustered waveforms
			%
			%   ----------------------------
			%   | SPIKE_CLUSTERS - LOADING |
			%   ----------------------------
			%
			%   [CONCATENATED_SPIKES, WAVEPARAMETERS, SPIKEWAVES_DOC] = LOADDATA_APPDOC(NDI_APP_SPIKESORTER_OBJ, 'spikewaves', ...
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
				eval(['help ndi_app_spikesorter/appdoc_description']); 
		end; % appdoc_description()
        end


	end % methods

end % ndi.app.spikesorter

