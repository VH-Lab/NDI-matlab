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

		function extract_and_sort(ndi_app_spikesorter_hengen_obj, varargin)
		% EXTRACT_AND_SORT - extracts and sorts selected .bin file in ndi_experiment directory
		%
		% EXTRACT_AND_SORT(REDO) - to handle selected .bin file in json input
		% EXTRACT_AND_SORT(NDI_ELEMENT, REDO) - to handle selected ndi_element
		%	
			
			if numel(varargin) == 2
				if isa(varargin{1}, 'ndi_timeseries')
					element = varargin{1};
				else
					error('invalid element input')
				end
				
				if isinteger(int8(varargin{2}))
					redo = varargin{2};
				else
					error('invalid redo input')
				end				
			end

			if numel(varargin) == 1
				if isinteger(int8(varargin{1}))
					redo = varargin{1};
				end
				if isa(varargin{1}, 'ndi_timeseries')
					element = varargin{1};
					redo = 0;
				end
			end

			if isempty(varargin)
				redo = 0;
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

			if exist('element') == 1
				[d] = readtimeseries(element, 1, -Inf, Inf);
				sr = element.samplerate(1);
				
				save('ndiouttmp.mat', 'd', 'sr')
				
				system(['/usr/local/opt/python@3.8/bin/python3 spikeinterface_currentall.py -f json_input_files/spkint_wrapper_input_64ch.json --experiment-path ' ndi_app_spikesorter_hengen_obj.experiment.path ' --ndi-hengen-path ' ndi_hengen_path ' --ndi-input'])
			else
				system(['/usr/local/opt/python@3.8/bin/python3 spikeinterface_currentall.py -f json_input_files/spkint_wrapper_input_64ch.json --experiment-path ' ndi_app_spikesorter_hengen_obj.experiment.path ' --ndi-hengen-path ' ndi_hengen_path])
				%python spikeinterface_currentall.py -f json_input_files/spkint_wrapper_input_64ch.json
			end
			
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
				[d,t] = readtimeseries(neuron_thing, 1, -Inf, Inf);
				% figure;
				% plot(t, d, 'o');

				figure(i); hold on;
				for j=1:numel(d)
					plot([t(j), t(j)], [0.4 0.6], 'b')
				end
				ylim([0 1])

			end

			delete tmp.mat

			cd(prev_folder)

		end % rate_neuron_quality

		% function extraction_doc = add_extraction_doc(ndi_app_spikesorter_hengen_obj, extraction_name, extraction_parameters)
		% % ADD_EXTRACTION_DOC - add extraction parameters document
		% %
		% % EXTRACTION_DOC = ADD_EXTRACTION_DOC(NDI_APP_SPIKESORTER_HENGEN_OBJ, EXTRACTION_NAME, EXTRACTION_PARAMETERS)
		% %
		

		% end % add_extraction_doc

		function sorting_doc = add_sorting_doc(ndi_app_spikesorter_hengen_obj, sorting_name, sorter, sorting_parameters)
		% ADD_SORTING_DOC - add sorting parameters document
		%
		% SORTING_DOC = ADD_SORTING_DOC(NDI_APP_SPIKESORTER_HENGEN_OBJ, SORTER, SORTING_NAME, SORTING_PARAMETERS)


			if nargin < 3
				sorting_parameters = []
			end

			if strcmp(sorter, 'm') || strcmp(sorter, 'mountainsort')
				error(['Unrecognized sorter, currently only ''' m ''' for mountainsort is supported.'])
			end

			params_searchq = ndi_query('ndi_document.name', 'exact_string', sorting_name, '') & ...
				ndi_query('', 'isa', 'mountainsort')

			docs_found = ndi_app_spikesorter_hengen_obj.experiment.database_search(params_searchq);

			if ~isempty(docs_found)
				error([int2str(numel(docs_found)) ' sorting documents with sorting_name ''' sorting_name ''' already exist(s).']);
			end

			if isempty(sorting_parameters),
				sorting_parameters = ndi_document('apps/spikesorter_hengen/mountainsort') + ...
					ndi_app_spikesorter_hengen_obj.newdocument();
				% this function needs a structure
				sorting_parameters = sorting_parameters.document_properties.sorting_parameters; 
			elseif isa(sorting_parameters,'ndi_document'),
				% this function needs a structure
				sorting_parameters = sorting_parameters.document_properties.sorting_parameters; 
			elseif isa(sorting_parameters, 'char') % loading struct from file 
				sorting_parameters = loadStructArray(sorting_parameters);
			elseif isstruct(sorting_parameters),
				% If extraction_params was inputed as a struct then no need to parse it
			else
				error('unable to handle extraction_params.');
			end

			% TODO: Ask Steve how he checks for fields being valid
			sorting_doc = ndi_document('apps/spikesorter_hengen/mountainsort', 'sorting_parameters', sorting_parameters) + ...
					ndi_app_spikesorter_hengen_obj.newdocument() + + ndi_document('ndi_document', 'ndi_document.name', sorting_name);

			ndi_app_spikesorter_hengen_obj.experiment.database_add(sorting_doc)

			sorting_doc.document_properties,
		end % add_sorting_doc

		function geometry_doc = add_geometry_doc(ndi_app_spikesorter_hengen_obj, probe, geometry)
		% ADD_GEOMETRY_DOC - add probe geometry document
		%
		% GEOMETRY_DOC = ADD_GEOMETRY_DOC(NDI_APP_SPIKESORTER_HENGEN_OBJ, PROBE, GEOMETRY)
		%
		% Add a geometry in a cell array corresponding to channel_groups, ex.
		% This app follows spikeinterface standard, unknown what the unit of geometry values are
		% 
		% {
		% 	"0": {
		% 		"channels": [0, 1, 2, 3],
		% 		"geometry": [[0, 0], [0, 1000], [0, 2000], [0, 3000]],
		% 		"label": ["t_00", "t_01", "t_02", "t_03"]
		% 	}
		% }
			
			% if no geometry provided assume line flat geometry
			if nargin < 3
				geometry = [];
			end

			geom_searchq = ndi_query('', 'depends_on', 'thing_id', probe.id()) & ndi_query('', 'isa', 'probe_geometry', ''); 

			docs_found = ndi_app_spikesorter_hengen_obj.experiment.database_search(geom_searchq);

			if ~isempty(docs_found)
				error([int2str(numel(docs_found)) ' probe_geometry documents for probe ''' probe.name ''' already exist(s).']);
			end

			if isempty(geometry)
				channels = [];
				g = [];
				label = [];

				nchannels = size(readtimeseries(probe, 1, 1, Inf), 2);

				for channel=1:nchannels
					channels(channel) = channel;
					g(channel,1) = 0;
					g(channel,2) = (channel-1)*1000;
					label{channel} = ['chan_' num2str(channel)];
				end

				geometry = struct("x0", struct('channels', channels, 'geometry', g, 'label', string(label)))

				geometry_doc = ndi_document('apps/spikesorter_hengen/probe_geometry', 'geometry', geometry) ...
					+ ndi_app_spikesorter_hengen_obj.newdocument();

				geometry_doc.set_dependency_value('underlying_thing_id', probe.id())
				
				ndi_app_spikesorter_hengen_obj.experiment.database_add(geometry_doc);

				geometry_doc
			end
		end % add_geometry_doc

	end % methods

end % ndi_app_spikesorter
