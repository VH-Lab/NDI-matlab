classdef ndi_app_spikesorter < ndi_app

	properties (SetAccess=protected,GetAccess=public)
	end % properties

	methods

		function ndi_app_spikesorter_obj = ndi_app_spikesorter(varargin)
		% NDI_APP_spikesorter - an app to sort spikewaves found in experiments
		%
		% NDI_APP_spikesorter_OBJ = NDI_APP_spikesorter(EXPERIMENT)
		%
		% Creates a new NDI_APP_spikesorter object that can operate on
		% NDI_EXPERIMENTS. The app is named 'ndi_app_spikesorter'.
		%
			experiment = [];
			name = 'ndi_app_spikesorter';
			if numel(varargin)>0,
				experiment = varargin{1};
			end
			ndi_app_spikesorter_obj = ndi_app_spikesorter_obj@ndi_app(experiment, name);

		end % ndi_app_spikesorter() creator

		function spike_sort(ndi_app_spikesorter_obj, name, type, epoch, extraction_name, sort_name, sorting_params) %, sorting_params)
		% SPIKE_SORT - method that sorts spikes from specific probes in experiment to ndi_doc
		%
		% SPIKE_SORT(NAME, TYPE, EXTRACTION_NAME, SORT_NAME, SORTING_PARAMS)
		% NAME is the probe name if any
		% TYPE is the type of probe if any
		% combination of NAME and TYPE must return at least one probe from experiment, that has extracted spikes as ndi_docs
		% EPOCH is an index number to select epoch to extract
		% EXTRACTION_NAME name given to find ndi_doc in database
		% SORT_NAME name given to save sort to ndi_doc
		% SORTING_PARAMS a struct or filepath (tab separated file) with extraction parameters
		% - min_rng = range used to compute features
		% - num_pca_features = integer for number of pca features to use in k-means clustering

			% Extracts probe with name
			probes = ndi_app_spikesorter_obj.experiment.getprobes('name',name,'type',type); % can add reference
			% TODO add for loop to extract multiple probes, right now only extracts first of selection
			probe = probes{1};
			%If extraction_params was inputed as a struct then no need to parse it
			if isstruct(sorting_params)
				sorting_parameters = sorting_params;
				% Consider saving in some var_branch_within probe_branch
			elseif isa(sorting_params, 'char')
				sorting_parameters = loadStructArray(sorting_params);
				% Consider saving in some var_branch_within probe_branch
			else
				error('unable to handle sorting_params.');
			end

			% Clear sort within probe with sort_name
			ndi_app_spikesorter_obj.clear_sort(probe, sort_name);

			% Create sorting parameters ndi_doc
			sorting_parameters_doc = ndi_app_spikesorter_obj.experiment.newdocument('apps/spikesorter/sorting_parameters', 'sorting_parameters', sorting_parameters) ...
				+ probe.newdocument() + ndi_app_spikesorter_obj.newdocument();

			% Add doc to database
			ndi_app_spikesorter_obj.experiment.database.add(sorting_parameters_doc);


			% Read spikewaves here
			spike_extractor = ndi_app_spikeextractor(ndi_app_spikesorter_obj.experiment);
			spikes = spike_extractor.load_spikes(probe, epoch, extraction_name);
			spikesamples = size(spikes,1);
			nchannels = size(spikes,2);
			nspikes = size(spikes,3);
			concatenated_waves = reshape(spikes,[spikesamples*nchannels,nspikes]);
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
			pca_coefficients = projected_waveforms(:, 1:sorting_parameters.num_pca_features);

			disp('KlustarinKwikly...');
			[clusterids,numclusters] = klustakwik_cluster(pca_coefficients, 3, 25, 5, 0);

			% interpolation coming from reading parameters
			interpolation = 3;
			disp('Cluster_spikewaves_gui testing...')
			[~, ~, ~, ~, channellist_in_probe] = getchanneldevinfo(probe, 1);
			waveparameters = struct;
			waveparameters.numchannels = numel(channellist_in_probe);
			waveparameters.S0 = -9 * interpolation;
			waveparameters.S1 = 20 * interpolation;
			waveparameters.name = '';
			waveparameters.ref = 1;
			waveparameters.comment = '';
			waveparameters.samplingrate = probe.samplerate(1) * interpolation;% ;

			spikewaves = ndi_app_spikesorter_obj.load_spikes(name, type, epoch, extraction_name);
			times = ndi_app_spikesorter_obj.load_times(name, type, epoch, extraction_name);
			spikeclusterids = clusterids;
			spiketimes = times(2,:);
			% keyboard
			size(spikewaves)
			size(spiketimes)

			% Uncomment to enable spikewaves_gui
			% cluster_spikewaves_gui('waves', spikewaves, 'waveparameters', waveparameters, 'clusterids', spikeclusterids, 'wavetimes', spiketimes);

			% 'EpochStartSamples', epoch_start_samples, 'EpochNames', epoch_names);
			disp('Done clustering.');
			figure(101);
			hist(clusterids);

			% Create spike_clusters ndi_doc
			spike_clusters_doc = ndi_app_spikesorter_obj.experiment.newdocument('apps/spikesorter/spike_clusters', ...
			'spike_clusters.sort_name', sort_name, ...
			'spike_clusters.sorting_parameters_file_id', sorting_parameters_doc.doc_unique_id(), ...
			'spike_clusters.clusterids', clusterids, ...
			'spike_clusters.numclusters', numclusters) ...
				+ probe.newdocument() + ndi_app_spikesorter_obj.newdocument();

			% Add doc to database
			ndi_app_spikesorter_obj.experiment.database.add(spike_clusters_doc);

			end %function

			function b = clear_sort(ndi_app_spikesorter_obj, ndi_probe_obj, sort_name)
			% CLEAR_SORTING - clear all 'sorted spikes' records for an NDI_PROBE_OBJ from experiment database
			%
			% B = CLEAR_SORTING(NDI_APP_SPIKESORTER_OBJ, NDI_EPOCHSET_OBJ)
			%
			% Clears all sorting entries from the experiment database for object NDI_PROBE_OBJ.
			%
			% Returns 1 on success, 0 otherwise.
			%%%
			% See also: NDI_APP_MARKGARBAGE/MARKVALIDINTERVAL, NDI_APP_MARKGARBAGE/SAVEALIDINTERVAL, ...
			%      NDI_APP_MARKGARBAGE/LOADVALIDINTERVAL

				% Look for any docs matching extraction name and remove them
				% Concatenate app query parameters and sort_name parameter
				searchq = cat(2,ndi_app_spikesorter_obj.searchquery(), ...
					{'spike_sort.sort_name', sort_name});

				% Concatenate probe query parameters
				searchq = cat(2, searchq, ndi_probe_obj.searchquery());

				% Search and get any docs
				mydoc = ndi_app_spikesorter_obj.experiment.database.search(searchq);

				% Remove the docs
				if ~isempty(mydoc),
					for i=1:numel(mydoc),
						ndi_app_spikesorter_obj.experiment.database.remove(mydoc{i}.doc_unique_id)
					end
					warning(['removed ' num2str(i) ' doc(s) with same extraction name'])
					b = 1;
				end
			end % clear_sort()

			function spikes = load_spikes(ndi_app_spikesorter_obj, name, type, epoch, extraction_name)
				probe = ndi_app_spikesorter_obj.experiment.getprobes('name',name,'type',type); % can add reference
				spikes = ndi_app_spikeextractor(ndi_app_spikesorter_obj.experiment).load_spikes(probe{1}, epoch, extraction_name);
			end

			function spikes = load_times(ndi_app_spikesorter_obj, name, type, epoch, extraction_name)
				probe = ndi_app_spikesorter_obj.experiment.getprobes('name',name,'type',type); % can add reference
				spikes = ndi_app_spikeextractor(ndi_app_spikesorter_obj.experiment).load_times(probe{1}, epoch, extraction_name);
			end

	end % methods

end % ndi_app_spikesorter
