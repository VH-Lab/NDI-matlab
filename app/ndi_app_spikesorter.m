classdef ndi_app_spikesorter < ndi_app

	properties (SetAccess=protected,GetAccess=public)
	end % properties

	methods

		function ndi_app_spikesorter_obj = ndi_app_spikesorter(varargin)
		% NDI_APP_spikesorter - an app to sort spikewaves found in sessions
		%
		% NDI_APP_spikesorter_OBJ = NDI_APP_spikesorter(SESSION)
		%
		% Creates a new NDI_APP_spikesorter object that can operate on
		% NDI_SESSIONS. The app is named 'ndi_app_spikesorter'.
		%
			session = [];
			name = 'ndi_app_spikesorter';
			if numel(varargin)>0,
				session = varargin{1};
			end
			ndi_app_spikesorter_obj = ndi_app_spikesorter_obj@ndi_app(session, name);

		end % ndi_app_spikesorter() creator
		%%%%%%
		%% TODO: Figure out how to pass parameters to save in database
		%%%%%%
		function spike_sort(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name, sort_name, redo)
		% SPIKE_SORT - method that sorts spikes from specific probes in session to ndi_doc
		%
		% SPIKE_SORT(SPIKEWAVES, SORT_NAME, SORTING_PARAMS)
		%%%%%%%%%%%%%%
		% SORT_NAME name given to save sort to ndi_doc
			
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

			sort_searchq = ndi_query('ndi_document.name','exact_string',sort_name,'') & ...
					ndi_query('','isa','sorting_parameters','');
					sorting_parameters_doc = ndi_app_spikesorter_obj.session.database_search(sort_searchq);
			if isempty(sorting_parameters_doc),
				error(['No sorting_parameters document named ' sort_name ' found.']);
			elseif numel(sorting_parameters_doc)>1,
				error(['More than one sorting_parameters document with same name. Should not happen but needs to be fixed.']);
			else,
				sorting_parameters_doc = sorting_parameters_doc{1};
			end;

			% Read spikewaves here
			spike_extractor = ndi_app_spikeextractor(ndi_app_spikesorter_obj.session);
			waveforms = spike_extractor.load_spikewaves_epoch(ndi_timeseries_obj, epoch, extraction_name);

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

			% spikewaves = ndi_app_spikesorter_obj.load_spikewaves_epoch(ndi_timeseries_obj, epoch, extraction_name);
			times = ndi_app_spikesorter_obj.load_spiketimes_epoch(ndi_timeseries_obj, epoch, extraction_name);
			% spiketimes_samples = ndi_timeseries_obj.times2samples(1, times);
            
            
			% Uncomment to enable spikewaves_gui
			% cluster_spikewaves_gui('waves', spikewaves, 'waveparameters', waveparameters, 'clusterids', spikeclusterids, 'wavetimes', spiketimes);

			% 'EpochStartSamples', epoch_start_samples, 'EpochNames', epoch_names);
			disp('Done clustering.');
			figure(101);
			hist(clusterids);

			% Create spike_clusters ndi_doc
			spike_clusters_doc = ndi_app_spikesorter_obj.session.newdocument('apps/spikesorter/spike_clusters', ...
				'spike_sort.sort_name', sort_name, ...
				'spike_sort.sorting_parameters_file_id', sorting_parameters_doc.id, ...
				'spike_sort.clusterids', clusterids, ...
				'spike_sort.spiketimes', times, ...
				'spike_sort.numclusters', numclusters) ...
				+ ndi_timeseries_obj.newdocument() + ndi_app_spikesorter_obj.newdocument();

			% Add doc to database
			ndi_app_spikesorter_obj.session.database_add(spike_clusters_doc);

			disp(['----' num2str(numclusters) ' neuron(s) found----'])

			for nNeuron=1:numclusters

				disp(['--------NEURON_' num2str(nNeuron) '--------'])
                

				neuron_element = ndi_element_timeseries(ndi_app_spikesorter_obj.session, ['neuron_' num2str(nNeuron)], ndi_timeseries_obj.reference, 'neuron', ndi_timeseries_obj, 0);
				doc = neuron_element.newdocument();
				%%% TODO: add properties like epoch and stuff?
				ndi_app_spikesorter_obj.session.database_add(doc);

				et = ndi_timeseries_obj.epochtable;
				
				neuron_times_idxs = find(clusterids == nNeuron);
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

			%%% TODO: function add_sorting_doc

		function sorting_doc = add_sorting_doc(ndi_app_spikesorter_obj, sort_name, sort_params)
			% ADD_SORTING_DOC - add sorting parameters document
			%
			% SORTING_DOC = ADD_SORTING_DOC(NDI_APP_SPIKESORTER_OBJ, SORT_NAME, SORT_PARAMS)
			%
			% Given SORT_PARAMS as either a structure or a filename, this function returns
			% SORTING_DOC parameters as an NDI_DOCUMENT and checks its fields. If SORT_PARAMS is empty,
			% then the default parameters are returned. If SORT_NAME is already the name of an existing
			% NDI_DOCUMENT then an error is returned.
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
				sort_searchq = ndi_query('ndi_document.name','exact_string',sort_name,'') & ...
					ndi_query('','isa','sorting_parameters','');
				mydoc = ndi_app_spikesorter_obj.session.database_search(sort_searchq);
				if ~isempty(mydoc),
					error([int2str(numel(mydoc)) ' sorting_parameters documents with name ''' sort_name ''' already exist(s).']);
				end;

				% okay, we can build a new document

				if isempty(sort_params),
					sort_params = ndi_document('apps/spikesorter/sorting_parameters') + ...
						ndi_app_spikesorter_obj.newdocument();
					% this function needs a structure
					sort_params = sort_params.document_properties.sorting_parameters; 
				elseif isa(sort_params,'ndi_document'),
					% this function needs a structure
					sort_params = sort_params.document_properties.sorting_parameters; 
				elseif isa(sort_params, 'char') % loading struct from file 
					sort_params = loadStructArray(sort_params);
				elseif isstruct(sort_params),
					% If sort_params was inputed as a struct then no need to parse it
				else
					error('unable to handle sort_params.');
				end

				% now we have a sort_params as a structure

				% check parameters here
				fields_needed = {'num_pca_features','interpolation'};
				sizes_needed = {[1 1], [1 1]};

				[good,errormsg] = hasAllFields(sort_params,fields_needed, sizes_needed);

				if ~good,
					error(['Error in sort_params: ' errormsg]);
				end;

				% now we need to convert to an ndi_document

				sorting_doc = ndi_document('apps/spikesorter/sorting_parameters','sorting_parameters',sort_params) + ...
					ndi_app_spikesorter_obj.newdocument() + ndi_document('ndi_document','ndi_document.name',sort_name);

				ndi_app_spikesorter_obj.session.database_add(sorting_doc);

				sorting_doc.document_properties,

		end; % add_sorting_doc




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

		function waveforms = load_spikewaves_epoch(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name)
			waveforms = ndi_app_spikeextractor(ndi_app_spikesorter_obj.session).load_spikewaves_epoch(ndi_timeseries_obj, epoch, extraction_name);
		end

		function times = load_spiketimes_epoch(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name)
			times = ndi_app_spikeextractor(ndi_app_spikesorter_obj.session).load_spiketimes_epoch(ndi_timeseries_obj, epoch, extraction_name);
		end

		function spikes = load_spikes(ndi_app_spikesorter_obj, name, type, epoch, extraction_name)
			probe = ndi_app_spikesorter_obj.session.getprobes('name',name,'type',type); % can add reference
			spikes = ndi_app_spikeextractor(ndi_app_spikesorter_obj.session).load_spikes(probe{1}, epoch, extraction_name);
		end

		function spikes = load_times(ndi_app_spikesorter_obj, name, type, epoch, extraction_name)
			probe = ndi_app_spikesorter_obj.session.getprobes('name',name,'type',type); % can add reference
			spikes = ndi_app_spikeextractor(ndi_app_spikesorter_obj.session).load_times(probe{1}, epoch, extraction_name);
		end

	end % methods

end % ndi_app_spikesorter
