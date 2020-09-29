classdef hengen < ndi.app.app

	properties (SetAccess=protected,GetAccess=public)
	end % properties

	methods

		function ndi_app_spikesorter_hengen_obj = hengen(varargin)
		% NDI.APP.spikesorter.hengen - an app to sort spikewaves found in experiments using hengen Spike Sorter
		%
		% NDI_APP_spikesorter_hengen_OBJ = ndi.app.spikesorter_hengen(EXPERIMENT)
		%
		% Creates a new NDI.APP.spikesorter_hengen object that can operate on
		% ndi.session.session objects. The app is named 'ndi_app_spikesorter_hengen'.
		%
			session = [];
			name = 'ndi_app_spikesorter_hengen';
			if numel(varargin)>0,
				session = varargin{1};
			end
			ndi_app_spikesorter_hengen_obj = ndi_app_spikesorter_hengen_obj@ndi.app.app(session, name);

		end % ndi_app_spikesorter() creator

		function extract_and_sort(ndi_app_spikesorter_hengen_obj, varargin)
		% EXTRACT_AND_SORT - extracts and sorts selected .bin file in ndi.session.directory
		%
		% EXTRACT_AND_SORT(REDO) - to handle selected .bin file in json input
		% EXTRACT_AND_SORT(NDI_ELEMENT, EXTRACTION_NAME, SORTING_NAME, REDO) - to handle selected ndi.element.element
		%	
			
			if (numel(varargin) ~= 1) && (numel(varargin) ~= 4)
				error(['Invalid number of arguments expected 1 or 4.'])
			end
			
			if numel(varargin) == 4
				if isa(varargin{1}, 'ndi.time.timeseries')
					element = varargin{1};
				else
					error('invalid element input')
				end

				if ischar(varargin{2}) == 1
					extraction_name = varargin{2}
				else
					error('invalid extraction_name input')
				end

				if ischar(varargin{3}) == 1
					sorting_name = varargin{3}
				else
					error('invalid sorting_name input')
				end
				
				if isinteger(int8(varargin{4}))
					redo = varargin{4};
				else
					error('invalid redo input')
				end				
			end

			if numel(varargin) == 1
				if isinteger(int8(varargin{1}))
					redo = varargin{1};
				end
				if isa(varargin{1}, 'ndi.time.timeseries')
					element = varargin{1};
					redo = 0;
				end
			end

			if isempty(varargin)
				redo = 0;
			end

			% Find extraction doc in database and return appropriate errors if not found
			extract_searchq = ndi.query('ndi_document.name', 'exact_string', extraction_name,'') & ...
				ndi.query('', 'isa', 'extraction_parameters', '');
			extraction_doc = ndi_app_spikesorter_hengen_obj.session.database_search(extract_searchq);

			if isempty(extraction_doc)
				error(['No extraction_parameters document named ' extraction_name ' found.']);
			elseif numel(extraction_doc) > 1
				error(['More than one extraction_parameters document with same name. Should not happen but needs to be fixed.']);
			else,
				extraction_doc = extraction_doc{1}.document_properties.extraction_parameters;
			end;

			% Find sorting doc in database and return appropriate errors if not found
			sort_searchq = ndi.query('ndi_document.name', 'exact_string', sorting_name, '') & ...
				ndi.query('', 'isa', 'mountainsort', '');
			sorting_doc = ndi_app_spikesorter_hengen_obj.session.database_search(sort_searchq);

			if isempty(sorting_doc)
				error(['No extraction_parameters document named ' extraction_name ' found.']);
			elseif numel(sorting_doc) > 1
				error(['More than one extraction_parameters document with same name. Should not happen but needs to be fixed.']);
			else,
				sorting_doc{1}.document_properties
				sorting_doc = sorting_doc{1}.document_properties.mountainsort_parameters;
			end;
			
			warning([newline 'This app assumes macOS with python3.8 installed with homebrew' newline 'as well as the following packages:' newline ' numpy' newline ' scipy' newline ' ml_ms4alg' newline ' seaborn' newline ' neuraltoolkit' newline ' musclebeachtools' newline ' spikeinterface' newline '  ^ requires appropriate modification of source in line 611 of postprocessing_tools.py (refer to musclebeachtools FAQ)'])
			warning(['using /usr/local/opt/python@3.8/bin/python3' newline 'modify source to use a different python installation'])
			
			prev_folder = cd(ndi_app_spikesorter_hengen_obj.session.path);

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

			ndi.globals;

			% ndi_hengen_path = [ndipath filesep 'app' filesep 'spikesorter_hengen'];
			[filepath] = fileparts(which('spikeinterface_currentall.py'))
			ndi_hengen_path = filepath

			prev_folder = cd(ndi_hengen_path);

			if exist('element') == 1
				[d] = readtimeseries(element, 1, -Inf, Inf);
				sr = element.samplerate(1);
				
				geom_searchq = ndi.query('', 'depends_on', 'underlying_element_id', element.id()) & ndi.query('', 'isa', 'probe_geometry', ''); 

				geom_doc = ndi_app_spikesorter_hengen_obj.session.database_search(geom_searchq);

				if isempty(geom_doc)
					warning(['No geometry document associated with probe ' element.name ' with id ' element.id '.'])
					error(['Please add a geometry doc for inputted probe. '])
				elseif numel(geom_doc) > 1
					error(['More than one geometry document associated with probe. Should not happen but needs to be fixed.']);
				else
					geom_doc = geom_doc{1};
				end

				g = geom_doc.document_properties.geometry.x0

				g.channels

				g.geometry = g.geometry'

				g.label

				extraction_p = extraction_doc

				sorting_p = sorting_doc
				
				% save('ndiouttmp.mat', 'd', 'sr', 'g', 'extraction_p', 'sorting_p')

				save('ndiouttmp.mat', 'sr', 'g', 'extraction_p', 'sorting_p')

				writemda16i(d, 'ndiout.mda')

				% TODO: write json and probe_file to disk

				script_path = which('spikeinterface_currentall.py')
				
				system(['/usr/local/opt/python@3.8/bin/python3 ' script_path ' -f json_input_files/spkint_wrapper_input_64ch.json --experiment-path ' ndi_app_spikesorter_hengen_obj.session.path ' --ndi-hengen-path ' ndi_hengen_path ' --ndi-input'])
			else
				system(['/usr/local/opt/python@3.8/bin/python3 ' script_path ' -f json_input_files/spkint_wrapper_input_64ch.json --experiment-path ' ndi_app_spikesorter_hengen_obj.session.path ' --ndi-hengen-path ' ndi_hengen_path])
			end
			
			cd(prev_folder)
		end % extract_and_sort

		function rate_neuron_quality(ndi_app_spikesorter_hengen_obj)
		% RATE_NEURON_QUALITY - given an existing sorting output from hengen sorter, rate neuron quality and add ndi_elements to experiment

			% TODO: remove temp code
			%%% temp %%%
			doc = ndi_app_spikesorter_hengen_obj.session.database_search({'ndi_document.type','ndi_element(.*)'});
			if ~isempty(doc),
				for i=1:numel(doc),
					ndi_app_spikesorter_hengen_obj.session.database_rm(doc{i}.id());
				end;
			end;
			%%% temp %%%

			warning([newline 'This app assumes a UNIX machine with python3 installed' newline 'as well as the following packages:' newline ' numpy' newline ' scipy' newline ' neuraltoolkit' newline ' musclebeachtools' newline ' spikeinterface' newline '  ^ requires appropriate modification of source in line 611 of postprocessing_tools.py (refer to musclebeachtools FAQ)'])

			ndi.globals;

			prev_folder = cd([ndi_globals.path.path filesep 'app' filesep 'spikesorter_hengen']);

			% python spikeinterface_currentall.py -f json_input_files/spkint_wrapper_input_64ch.json
			warning(['using /usr/local/opt/python@3.8/bin/python3' newline 'modify source to use a different python installation'])
			system(['/usr/local/opt/python@3.8/bin/python3 rate_neuron_quality.py --experiment-path '  ndi_app_spikesorter_hengen_obj.session.path])

			load('tmp.mat', 'n');

			for i=1:2 % TODO: hardcoded
				neuron = n{i}

				% neuron_element_doc = ndi_app_spikesorter_hengen_obj.session.newdocument('apps/spikesorter_hengen/neuron_hengen', ...
				% 	...% element properties
				% 	'element.name', ['neuron_' num2str(neuron.clust_idx+1)],...
				% 	'element.reference', num2str(neuron.clust_idx),...
				% 	'element.type', 'neuron',...
				% 	'element.direct', 0,...
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

				% neuron_element_doc.set_dependency_value('underlying_element_id', ''); % TODO: is this the right way of doing this?

				% ndi_app_spikesorter_hengen_obj.session.database_add(neuron_element_doc);

				neuron_element = ndi.neuron.hengen(ndi_app_spikesorter_hengen_obj.session,...
					['neuron_' num2str(neuron.clust_idx + 1)],...
					num2str(neuron.clust_idx + 1),...
					'neuron_hengen',...
					[],...
					0,...
					neuron.quality,...
					'inference')

				[neuron_element, neuron_element_doc] = neuron_element.addepoch('epoch1', ndi.time.clocktype('dev_local_time'), [neuron.on_times, neuron.off_times], [neuron.spike_time / neuron.fs]', ones(numel(neuron.spike_time), 1));
				
				% Test plotting
				[d,t] = readtimeseries(neuron_element, 1, -Inf, Inf);
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

		function extraction_doc = add_extraction_doc(ndi_app_spikesorter_hengen_obj, extraction_name, extraction_parameters)
		% ADD_EXTRACTION_DOC - add extraction parameters document
		%
		% EXTRACTION_DOC = ADD_EXTRACTION_DOC(NDI_APP_SPIKESORTER_HENGEN_OBJ, EXTRACTION_NAME, EXTRACTION_PARAMETERS)
		%

			if nargin < 3,
				extraction_parameters = [];
			end;

				% search for any existing documents with that name; any doc that has that name and spike_extraction_parameters as a field
			extract_searchq = ndi.query('ndi_document.name','exact_string',extraction_name,'') & ...
				ndi.query('','isa','extraction_parameters','');
			mydoc = ndi_app_spikesorter_hengen_obj.session.database_search(extract_searchq);
			if ~isempty(mydoc),
				error([int2str(numel(mydoc)) ' extraction_parameters documents with name ''' extraction_name ''' already exist(s).']);
			end;

			% okay, we can build a new document

			if isempty(extraction_parameters),
				extraction_parameters = ndi.document('apps/spikesorter_hengen/hengen_extraction_parameters') + ...
				ndi_app_spikesorter_hengen_obj.newdocument();
				% this function needs a structure
				extraction_parameters = extraction_parameters.document_properties.hengen_extraction_parameters; 
			elseif isa(extraction_parameters,'ndi.document'),
				% this function needs a structure
				extraction_params = extraction_parameters.document_properties.extraction_parameters; 
			elseif isa(extraction_parameters, 'char') % loading struct from file 
				extraction_parameters = vlt.file.loadStructArray(extraction_parameters);
			elseif isstruct(extraction_parameters),
				% If extraction_params was inputed as a struct then no need to parse it
			else
				error('unable to handle extraction_parameters.');
			end

			% now we have a extraction_parameters as a structure

			% % check parameters here
			% fields_needed = {'center_range_time','overlap','read_time','refractory_time',...
			% 	'spike_start_time','spike_end_time',...
			% 	'do_filter', 'filter_type','filter_low','filter_high','filter_order','filter_ripple',...
			% 	'threshold_method','threshold_parameter','threshold_sign'};
			% sizes_needed = {[1 1], [1 1], [1 1], [1 1],...
			% 	[1 1],[1 1],...
			% 	[1 1],[1 -1],[1 1],[1 1],[1 1],[1 1],...
			% 	[1 -1], [1 1], [1 1]};

			% [good,errormsg] = vlt.data.hasAllFields(extraction_params,fields_needed, sizes_needed);

			% if ~good,
			% 	error(['Error in extraction_parameters: ' errormsg]);
			% end;

			% now we need to convert to an ndi.document

			extraction_doc = ndi.document('apps/spikesorter_hengen/hengen_extraction_parameters', 'extraction_parameters', extraction_parameters) + ...
			ndi_app_spikesorter_hengen_obj.newdocument() + ndi.document('ndi_document', 'ndi_document.name', extraction_name);

			ndi_app_spikesorter_hengen_obj.session.database_add(extraction_doc);

			extraction_doc.document_properties,
		

		end % add_extraction_doc

		function sorting_doc = add_sorting_doc(ndi_app_spikesorter_hengen_obj, sorting_name, sorter, sorting_parameters)
		% ADD_SORTING_DOC - add sorting parameters document
		%
		% SORTING_DOC = ADD_SORTING_DOC(NDI_APP_SPIKESORTER_HENGEN_OBJ, SORTER, SORTING_NAME, SORTING_PARAMETERS)

			disp(['nargin -> ' num2str(nargin)])
			if nargin < 4
				sorting_parameters = []
			end

			if isempty(sorter)
				sorter = 'm'
			end

			if ~strcmp(sorter, 'm') %|| ~strcmp(sorter, 'mountainsort')
				error(['Unrecognized sorter, currently only ''m'' for mountainsort is supported.'])
			end

			params_searchq = ndi.query('ndi_document.name', 'exact_string', sorting_name, '') & ...
				ndi.query('', 'isa', 'mountainsort', '');

			docs_found = ndi_app_spikesorter_hengen_obj.session.database_search(params_searchq);

			if ~isempty(docs_found)
				error([int2str(numel(docs_found)) ' sorting documents with sorting_name ''' sorting_name ''' already exist(s).']);
			end

			if isempty(sorting_parameters)
				sorting_parameters = ndi.document('apps/spikesorter_hengen/mountainsort') + ndi_app_spikesorter_hengen_obj.newdocument();
				% this function needs a structure
				sorting_parameters = sorting_parameters.document_properties.mountainsort_parameters; 
			elseif isa(sorting_parameters,'ndi.document'),
				% this function needs a structure
				sorting_parameters = sorting_parameters.document_properties.mountainsort_parameters; 
			elseif isa(sorting_parameters, 'char') % loading struct from file 
				sorting_parameters = vlt.file.loadStructArray(sorting_parameters);
			elseif isstruct(sorting_parameters),
				% If extraction_params was inputed as a struct then no need to parse it
			else
				error('unable to handle extraction_params.');
			end

			% TODO: Ask Steve how he checks for fields being valid
			sorting_doc = ndi.document('apps/spikesorter_hengen/mountainsort', 'mountainsort_parameters', sorting_parameters) + ...
					ndi_app_spikesorter_hengen_obj.newdocument() + ndi.document('ndi_document', 'ndi_document.name', sorting_name);

			ndi_app_spikesorter_hengen_obj.session.database_add(sorting_doc);
			
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

			geom_searchq = ndi.query('', 'depends_on', 'underlying_element_id', probe.id()) & ndi.query('', 'isa', 'probe_geometry', ''); 

			docs_found = ndi_app_spikesorter_hengen_obj.session.database_search(geom_searchq);

			if ~isempty(docs_found)
				error([int2str(numel(docs_found)) ' probe_geometry documents for probe ''' probe.name ''' already exist(s).']);
			end

			if isempty(geometry)
				channels = [];
				g = [];
				label = [];

				nchannels = size(readtimeseries(probe, 1, 1, Inf), 2);

				for channel=1:nchannels
					channels(1,channel) = channel;
					g(channel,1) = 0;
					g(channel,2) = (channel - 1) * 1000;
					label{channel} = ['chan_' num2str(channel)];
				end

				geometry = struct('x0', struct('channels', channels, 'geometry', g, 'label', string(label)))

				geometry_doc = ndi.document('apps/spikesorter_hengen/probe_geometry', 'geometry', geometry) ...
					+ ndi_app_spikesorter_hengen_obj.newdocument();

				geometry_doc = geometry_doc.set_dependency_value('underlying_element_id', probe.id())
				
				ndi_app_spikesorter_hengen_obj.session.database_add(geometry_doc);

				geometry_doc.document_properties
			end
		end % add_geometry_doc

	end % methods

end % ndi_app_spikesorter
