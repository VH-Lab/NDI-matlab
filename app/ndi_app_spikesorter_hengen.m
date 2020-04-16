classdef ndi_app_spikesorter_hengen < ndi_app

	properties (SetAccess=protected,GetAccess=public)
	end % properties

	methods

		function ndi_app_spikesorter_hengen_obj = ndi_app_spikesorter_hengen(varargin)
		% NDI_APP_spikesorter_hengen - an app to sort spikewaves found in experiments using hengen Spike Sorter
		%
		% NDI_APP_spikesorter_hengen_OBJ = NDI_APP_spikesorter_hengen(EXPERIMENT)
		%
		% Creates a new NDI_APP_spikesorter_hengen object that can operate on
		% NDI_EXPERIMENTS. The app is named 'ndi_app_spikesorter_hengen'.
		%
			experiment = [];
			name = 'ndi_app_spikesorter_hengen';
			if numel(varargin)>0,
				experiment = varargin{1};
			end
			ndi_app_spikesorter_hengen_obj = ndi_app_spikesorter_hengen_obj@ndi_app(experiment, name);

		end % ndi_app_spikesorter() creator

		function extract_and_sort(ndi_app_spikesorter_hengen_obj, redo)
		% EXTRACT_AND_SORT - extracts and sorts selected .bin file in ndi_experiment directory
		%
			
			if isempty(redo)
				redo = 0
			end
			
			warning([newline 'This app assumes macOS with python3.8 installed with homebrew' newline 'as well as the following packages:' newline ' numpy' newline ' scipy' newline ' ml_ms4alg' newline ' seaborn' newline ' neuraltoolkit' newline ' musclebeachtools' newline ' spikeinterface' newline '  ^ requires appropriate modification of source in line 611 of postprocessing_tools.py (refer to musclebeachtools FAQ)'])
			warning(['using /usr/local/opt/python@3.8/bin/python3' newline 'modify source to use a different python installation'])
			prev_folder = cd(ndi_app_spikesorter_hengen_obj.experiment.path);

			% deal with directory clustering_output
			if isfolder('clustering_output')
				if redo == 1
					rmdir('clustering_output', 's')
					mkdir('clustering_output')
				elseif redo == 0
					error(['Folder clustering_output exists. Remove directory or make redo value 1 to overwrite'])
				else
					error(['redo should be either 0 or 1'])
				end
			else
				mkdir('clustering_output')
			end
			
			% delete existing tmp dir and create it
			if isfolder('tmp')
				rmdir('tmp', 's')
			end

			mkdir('tmp')

			cd(prev_folder);

			ndi_globals;

			ndi_hengen_path = [ndipath filesep 'app' filesep 'spikesorter_hengen'];

			prev_folder = cd(ndi_hengen_path);

			system(['/usr/local/opt/python@3.8/bin/python3 spikeinterface_currentall.py -f json_input_files/spkint_wrapper_input_64ch.json --experiment-path ' ndi_app_spikesorter_hengen_obj.experiment.path ' --ndi-hengen-path ' ndi_hengen_path])
			%python spikeinterface_currentall.py -f json_input_files/spkint_wrapper_input_64ch.json

			cd(prev_folder)
		end % extract_and_sort

		function rate_neuron_quality(ndi_app_spikesorter_hengen_obj)
		% RATE_NEURON_QUALITY - given an existing sorting output from hengen sorter, rate neuron quality and add ndi_things to experiment

			% TODO: remove temp code
			%%% temp %%%
			doc = ndi_app_spikesorter_hengen_obj.experiment.database_search({'ndi_document.type','ndi_thing(.*)'});
			if ~isempty(doc),
				for i=1:numel(doc),
					ndi_app_spikesorter_hengen_obj.experiment.database_rm(doc{i}.id());
				end;
			end;
			%%% temp %%%

			warning([newline 'This app assumes a UNIX machine with python3 installed' newline 'as well as the following packages:' newline 'numpy' newline ' scipy' newline ' neuraltoolkit' newline ' musclebeachtools' newline ' spikeinterface' newline '  ^ requires appropriate modification of source in line 611 of postprocessing_tools.py (refer to musclebeachtools FAQ)'])

			ndi_globals;

			prev_folder = cd([ndipath filesep 'app' filesep 'spikesorter_hengen']);

			% python spikeinterface_currentall.py -f json_input_files/spkint_wrapper_input_64ch.json
			warning(['using /usr/local/opt/python@3.8/bin/python3' newline 'modify source to use a different python installation'])
			system(['/usr/local/opt/python@3.8/bin/python3 rate_neuron_quality.py --experiment-path '  ndi_app_spikesorter_hengen_obj.experiment.path])

			load('tmp.mat', 'n');

			for i=1:2 % TODO: hardcoded
				neuron = n{i}

				% neuron_thing_doc = ndi_app_spikesorter_hengen_obj.experiment.newdocument('apps/spikesorter_hengen/neuron_hengen', ...
				% 	...% thing properties
				% 	'thing.name', ['neuron_' num2str(neuron.clust_idx+1)],...
				% 	'thing.reference', num2str(neuron.clust_idx),...
				% 	'thing.type', 'neuron',...
				% 	'thing.direct', 0,...
				% 	...% neuron_hengen_object properties (from musclebeachtools)
				% 	'neuron_properties.waveform', neuron.waveform,...
				% 	'neuron_properties.waveforms', neuron.waveforms,...
				% 	'neuron_properties.clust_idx', neuron.clust_idx,...
				% 	'neuron_properties.quality', neuron.quality,...
				% 	'neuron_properties.cell_type', neuron.cell_type,...
				% 	'neuron_properties.mean_amplitude', neuron.mean_amplitude,...
				% 	'neuron_properties.waveform_tetrodes', neuron.waveform_tetrodes,...
				% 	'neuron_properties.spike_amplitude', neuron.spike_amplitude...
				% ) + ndi_app_spikesorter_hengen_obj.newdocument()

				% neuron_thing_doc.set_dependency_value('underlying_thing_id', ''); % TODO: is this the right way of doing this?

				% ndi_app_spikesorter_hengen_obj.experiment.database_add(neuron_thing_doc);

				neuron_thing = ndi_neuron_hengen(ndi_app_spikesorter_hengen_obj.experiment,...
					['neuron_' num2str(neuron.clust_idx + 1)],...
					num2str(neuron.clust_idx + 1),...
					'neuron_hengen',...
					[],...
					0,...
					neuron.quality,...
					'inference')

				[neuron_thing, neuron_thing_doc] = neuron_thing.addepoch('epoch1', ndi_clocktype('dev_local_time'), [neuron.on_times, neuron.off_times], [neuron.spike_time / neuron.fs]', ones(numel(neuron.spike_time), 1));
				
				% Test plotting
				% [d,t] = readtimeseries(neuron_thing, 1, -Inf, Inf);
				% figure;
				% plot(t, d, 'o');
			end

			delete tmp.mat

			cd(prev_folder)

		end % rate_neuron_quality

	end % methods

end % ndi_app_spikesorter
