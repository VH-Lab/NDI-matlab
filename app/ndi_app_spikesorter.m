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
		%%%%%%
		%% TODO: Figure out how to pass parameters to save in database
		%%%%%%
		function spike_sort(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name, sort_name, sorting_params, redo)
		% SPIKE_SORT - method that sorts spikes from specific probes in experiment to ndi_doc
		%
		% SPIKE_SORT(SPIKEWAVES, SORT_NAME, SORTING_PARAMS)
		%%%%%%%%%%%%%%
		% SORT_NAME name given to save sort to ndi_doc
		% SORTING_PARAMS a struct or filepath (tab separated file) with extraction parameters
		% - min_rng = range used to compute features
		% - num_pca_features = integer for number of pca features to use in k-means clustering

			%If sorting_params was inputed as a struct then no need to parse it
			if isstruct(sorting_params)
				sorting_parameters = sorting_params;
			elseif isa(sorting_params, 'char')
				sorting_parameters = loadStructArray(sorting_params);
			else
				error('unable to handle sorting_params.');
			end

			% if isempty(epoch)
			% 	et = epochtable(ndi_timeseries_obj);
			% 	epoch = {et.epoch_id};
			% elseif ~iscell(epoch)
			% 	epoch = {epoch};
			% end

			if ~isfield(sorting_parameters, 'interpolation')
				sorting_parameters.interpolation = 3
			end
			
			if exist('redo') == 0
				redo = 0
			end

			% epoch_string = ndi_timeseries_obj.epoch2str(epoch{n});

			% sorter_searchq = cat(2,ndi_app_spikesorter_obj.searchquery(), ...
			% 			{'epochid', epoch_string, 'spikewaves.sort_name', extraction_name});
			% 		old_sort_doc = ndi_app_spikesorter_obj.experiment.database_search(spikewaves_searchq);
					
			% if ~isempty(old_sort_doc) & ~redo
			% 	% we already have this epoch
			% 	continue % skip to next epoch
			% end

			% Clear sort within probe with sort_name
			ndi_app_spikesorter_obj.clear_sort(ndi_timeseries_obj, epoch, sort_name);

			% Create sorting parameters ndi_doc
			sorting_parameters_doc = ndi_app_spikesorter_obj.experiment.newdocument('apps/spikesorter/sorting_parameters', 'sorting_parameters', sorting_parameters) ...
				+ ndi_timeseries_obj.newdocument() + ndi_app_spikesorter_obj.newdocument();

			% Add doc to database
			ndi_app_spikesorter_obj.experiment.database.add(sorting_parameters_doc);

			% Read spikewaves here
			spike_extractor = ndi_app_spikeextractor(ndi_app_spikesorter_obj.experiment);
			waveforms = spike_extractor.load_spikewaves_epoch(ndi_timeseries_obj, epoch, extraction_name);

			% Interpolation
			interpolation = sorting_parameters.interpolation;
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
			pca_coefficients = projected_waveforms(:, 1:sorting_parameters.num_pca_features);

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

			spikewaves = ndi_app_spikesorter_obj.load_spikewaves_epoch(ndi_timeseries_obj, epoch, extraction_name);
			times = ndi_app_spikesorter_obj.load_spiketimes_epoch(ndi_timeseries_obj, epoch, extraction_name);
			spiketimes_samples = ndi_timeseries_obj.times2samples(1, times);
			% keyboard

			% Uncomment to enable spikewaves_gui
			% cluster_spikewaves_gui('waves', spikewaves, 'waveparameters', waveparameters, 'clusterids', spikeclusterids, 'wavetimes', spiketimes);

			% 'EpochStartSamples', epoch_start_samples, 'EpochNames', epoch_names);
			disp('Done clustering.');
			figure(101);
			hist(clusterids);

			% Create spike_clusters ndi_doc
			spike_clusters_doc = ndi_app_spikesorter_obj.experiment.newdocument('apps/spikesorter/spike_clusters', ...
			'spike_sort.sort_name', sort_name, ...
			'spike_sort.sorting_parameters_file_id', sorting_parameters_doc.doc_unique_id, ...
			'spike_sort.clusterids', clusterids, ...
			'spike_sort.spiketimes', times, ...
			'spike_sort.numclusters', numclusters) ...
				+ ndi_timeseries_obj.newdocument() + ndi_app_spikesorter_obj.newdocument();

			% Add doc to database
			ndi_app_spikesorter_obj.experiment.database.add(spike_clusters_doc);

			disp(['----' num2str(numclusters) ' found----'])

			for nNeuron=1:numclusters

				disp(['-------NEURON_' num2str(nNeuron) '-------'])

				neuron_thing = ndi_thing_timeseries(['neuron_' num2str(nNeuron)], 'neuron', ndi_timeseries_obj, 0);
				doc = neuron_thing.newdocument();
				%%% TODO: add properties like epoch and stuff?
				ndi_app_spikesorter_obj.experiment.database_add(doc);

				et = ndi_timeseries_obj.epochtable;

				[data, time] = readtimeseries(ndi_timeseries_obj, 1, -Inf, Inf);

				disp(['length of CLUSTERIDS = ' num2str(length(clusterids))])
				spikelocs_indexes = find(clusterids == nNeuron);
				disp(['length of spikelocs_indexes = ' num2str(length(spikelocs_indexes))])
				spikelocs_samples = spiketimes_samples(spikelocs_indexes);
				neuron_timeseries = zeros(1, length(data));
				disp(['length of neuron_timeseries = ' num2str(length(spikelocs_indexes))])
				neuron_timeseries(spikelocs_samples) = 1;
				keyboard
				[neuron, mydoc] = neuron_thing.addepoch(...
					et(1).epoch_id, ...
					et(1).epoch_clock{1}, ...
					et(1).t0_t1{1}, ...
					time, ...
					neuron_timeseries...
                );
			end

			% et_t1 = mything1.epochtable();
			% et_t2 = mything2.epochtable();

			keyboard

			neuron1 = ndi_app_spikesorter_obj.experiment.getthings('thing.name','neuron_1');
			neuron2 = ndi_app_spikesorter_obj.experiment.getthings('thing.name','neuron_2');

			[d1,t1] = readtimeseries(thing1{1},1,-Inf,Inf);
			[d2,t2] = readtimeseries(thing2{1},1,-Inf,Inf);

			figure(10)
			plot(d1)
			plot(d2)

		end %function

			%%% TODO: function add_sorting_doc

			%%% TODO: load neurons




		function b = clear_sort(ndi_app_spikesorter_obj, ndi_probe_obj, epoch, sort_name)
		% CLEAR_SORT - clear all 'sorted spikes' records for an NDI_PROBE_OBJ from experiment database
		%
		% B = CLEAR_SORT(NDI_APP_SPIKESORTER_OBJ, NDI_EPOCHSET_OBJ)
		%
		% Clears all sorting entries from the experiment database for object NDI_PROBE_OBJ.
		%
		% Returns 1 on success, 0 otherwise.

			% Look for any docs matching extraction name and remove them
			% Concatenate app query parameters and sort_name parameter
			searchq = cat(2,ndi_app_spikesorter_obj.searchquery(), ...
				{'spike_sort.sort_name', sort_name, 'spike_sort.epoch', epoch});

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

		function waveforms = load_spikewaves_epoch(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name)
			waveforms = ndi_app_spikeextractor(ndi_app_spikesorter_obj.experiment).load_spikewaves_epoch(ndi_timeseries_obj, epoch, extraction_name);
		end

		function times = load_spiketimes_epoch(ndi_app_spikesorter_obj, ndi_timeseries_obj, epoch, extraction_name)
			times = ndi_app_spikeextractor(ndi_app_spikesorter_obj.experiment).load_spiketimes_epoch(ndi_timeseries_obj, epoch, extraction_name);
		end

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
