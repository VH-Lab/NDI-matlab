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
        
		%%%%%%
		%% TODO: Figure out how to pass parameters to save in database
		%%%%%%
        
		function spike_sort(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name, sort_name, redo)
		% SPIKE_SORT - method that sorts spikes from specific probes in session to ndi_doc
		%
		% SPIKE_SORT(SPIKEWAVES, SORT_NAME, SORTING_PARAMS)
		%%%%%%%%%%%%%%
		% SORT_NAME name given to save sort to ndi_doc
        
        %TODO: fix redo%
			
			if exist('redo') == 0
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
			ndi_app_spikesorter_obj.clear_sort(ndi_timeseries_obj, epoch, sort_name);

% 			sort_searchq = ndi.query('ndi_document.name','exact_string',sort_name,'') & ...
% 					ndi.query('','isa','sorting_parameters','');
% 					sorting_parameters_doc = ndi_app_spikesorter_obj.session.database_search(sort_searchq);
            
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

			% For spikewaves gui
			% disp('Cluster_spikewaves_gui testing...')
			% [~, ~, ~, ~, channellist_in_probe] = getchanneldevinfo(probe, 1);
			% waveparameters = struct;
			% waveparameters.numchannels = numel(channellist_in_probe);
			% waveparameters.S0 = -9 * interpolation;
			% waveparameters.S1 = 20 * interpolation;
			% waveparameters.name = '';
			% waveparameters.ref = 1;
			% waveparameters.comment = '';
			% waveparameters.samplingrate = probe.samplerate(1) * interpolation;% ;

			% spikewaves = ndi_app_spikeextractor_obj.loaddata_appdoc('spikewaves', ...
                %ndi_timeseries_obj, epoch, extraction_name);

			times = ndi_app_spikeextractor_obj.loaddata_appdoc('spiketimes', ndi_timeseries_obj, epoch, extraction_name);
            
			% spiketimes_samples = ndi_timeseries_obj.times2samples(1, times);
            
			% Uncomment to enable spikewaves_gui
			% vlt.neuro.spikesorting.cluster_spikewaves_gui('waves', spikewaves, 'waveparameters', waveparameters, 'clusterids', spikeclusterids, 'wavetimes', spiketimes);

			% 'EpochStartSamples', epoch_start_samples, 'EpochNames', epoch_names);
			disp('Done clustering.');
			figure(101);
			hist(clusterids);

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
		end %function

        %% function to call gui
        function spikesorter_gui(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name, sort_name)
            
            %load spike waves
            spikewaves = ndi_app_spikeextractor_obj.loaddata_appdoc('spikewaves', ...
                ndi_timeseries_obj, epoch, extraction_name);
            
            
            %load clusterids
            doc_spike_clusters = ndi_app_spikesorter_obj.load_spike_clusters_doc(ndi_timeseries_obj, epoch, sort_name);
            spikeclusterids = doc_spike_clusters{1, 1}.document_properties.spike_sort.clusterids; 
            
            %load wavetimes/spike times
            spiketimes = loaddata_appdoc(ndi_app_spikeextractor_obj, 'spiketimes', ...
                ndi_timeseries_obj, epoch, extraction_name);
            
            
            %load and create waveparameters
            
            %interpolation = sorting_parameters_doc.document_properties.sorting_parameters.interpolation;
            
            
			[~, ~, ~, ~, channellist_in_probe] = getchanneldevinfo(ndi_timeseries_obj, epoch);
			waveparameters = struct;
			waveparameters.numchannels = numel(channellist_in_probe);
			waveparameters.S0 = -9; %* interpolation;
			waveparameters.S1 = 20; %* interpolation;
			waveparameters.name = '';
			waveparameters.ref = 1;
			waveparameters.comment = '';
			waveparameters.samplingrate = ndi_timeseries_obj.samplerate(1); %* interpolation;% ;
            
            %call gui fct
            vlt.neuro.spikesorting.cluster_spikewaves_gui('waves', spikewaves, 'waveparameters', waveparameters, 'clusterids', spikeclusterids, 'wavetimes', spiketimes, 'spikewaves2NpointfeatureSampleList',  [10 15], 'spikewaves2pcaRange', [1 17]);
            
        end  %calling gui fct
        
        %%
		function sorting_doc = add_sorting_doc(ndi_app_spikesorter_obj, sort_name, sort_params)
			% ADD_SORTING_DOC - add sorting parameters document
			%
			% SORTING_DOC = ADD_SORTING_DOC(NDI_APP_SPIKESORTER_OBJ, SORT_NAME, SORT_PARAMS)
			%
			% Given SORT_PARAMS as either a structure or a filename, this function returns
			% SORTING_DOC parameters as an ndi.document and checks its fields. If SORT_PARAMS is empty,
			% then the default parameters are returned. If SORT_NAME is already the name of an existing
			% ndi.document then an error is returned.
			%
			% SORT_PARAMS should contain the following fields:
			% Fieldname              | Description
			% -------------------------------------------------------------------------
			% num_pca_features (10)     | Number of PCA features to use in klustakwik k-means clustering
			% interpolation (3)       | Interpolation factor
			% 
				if nargin<3,
					sort_params = [];
				end;

					% search for any existing documents with that name; any doc that has that name and sorting_parameters as a field
				sort_searchq = ndi.query('ndi_document.name','exact_string',sort_name,'') & ...
					ndi.query('','isa','sorting_parameters','');
				mydoc = ndi_app_spikesorter_obj.session.database_search(sort_searchq);
				if ~isempty(mydoc),
					error([int2str(numel(mydoc)) ' sorting_parameters documents with name ''' sort_name ''' already exist(s).']);
				end;

				% okay, we can build a new document

				if isempty(sort_params),
					sort_params = ndi.document('apps/spikesorter/sorting_parameters') + ...
						ndi_app_spikesorter_obj.newdocument();
					% this function needs a structure
					sort_params = sort_params.document_properties.sorting_parameters; 
				elseif isa(sort_params,'ndi.document'),
					% this function needs a structure
					sort_params = sort_params.document_properties.sorting_parameters; 
				elseif isa(sort_params, 'char') % loading struct from file 
					sort_params = vlt.file.loadStructArray(sort_params);
				elseif isstruct(sort_params),
					% If sort_params was inputed as a struct then no need to parse it
				else
					error('unable to handle sort_params.');
				end

				% now we have a sort_params as a structure

				% check parameters here
				fields_needed = {'num_pca_features','interpolation'};
				sizes_needed = {[1 1], [1 1]};

				[good,errormsg] = vlt.data.hasAllFields(sort_params,fields_needed, sizes_needed);

				if ~good,
					error(['Error in sort_params: ' errormsg]);
				end;

				% now we need to convert to an ndi.document

				sorting_doc = ndi.document('apps/spikesorter/sorting_parameters','sorting_parameters',sort_params) + ...
					ndi_app_spikesorter_obj.newdocument() + ndi.document('ndi_document','ndi_document.name',sort_name);

				ndi_app_spikesorter_obj.session.database_add(sorting_doc);

				sorting_doc.document_properties,

		end; % add_sorting_doc
        
        
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
                    'spike_clusters', appdoc_struct, 'epoch', epoch, 'clusterid', clusterid, 'numcluscters', numcluscters, 'epochid', epochid_string) + ...
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
                fields_needed = {'num_pca_features', 'interpolation'};
                sizes_needed = {[1 10],[1 3]};
                
                [b,errormsg] = vlt.data.hasALLFields(sorting_parameters, fields_needed, sizes_needed);
                
            elseif strcmpi(appdoc_type,'spike_clusters')
                spike_clusters = appdoc_struct;
                
                %check parameters here
                fields_needed = {'epoch','clusterids', 'spiketimes', 'numclusters', 'epochid'};
                sizes_needed = {[1 1], [1 -1], [1 -1], [1 -1], [1 -1]};
                
                [b,errormsg] = vlt.data.hasALLFields(spike_clusters, fields_needed, sizes_needed);
                
            else
                error(['Unknown appdoc_type' appdoc_type '.']);
            
            end
            
        end %isvalid_appdoc_struct
        
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
        end %find_appdoc
        
        function varargout = loaddata_appdoc(ndi_app_spikesorter_obj, appdoc_type, varargin)
			% LOADDATA_APPDOC - load data from an application document
			%
			% See ndi_app_spikesorter/APPDOC_DESCRIPTION for documentation.
			%
            switch(lower(appdoc_type))
                case {'sorting_parameters','spike_clusters'}
                varargout{1} = ndi_app_spikesorter_obj.find_appdoc(appdoc_type,varargin{:});
                
                otherwise
                    error(['Unknown APPDOC_TYPE ' appdoc_type '.']);
            end %switch
            
            
        end %loaddata_appdoc
        
        function appdoc_description(ndi_app_appdoc_obj)
			% APPDOC_DESCRIPTION - a function that prints a description of all appdoc types
        end
	end % methods

end % ndi_app_spikesorter

