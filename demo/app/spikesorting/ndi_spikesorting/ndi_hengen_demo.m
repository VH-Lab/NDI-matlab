% Create session folder and add .bin files to extract and sort
% modify filepath in app/spikesorter_hengen/json_input_files/spkint_wrapper_input_64ch.json
% to point to desired .bin file (to be found ndi.session path)

% E = ndi.session.dir('exp_hengen', '/Users/danielgmu/Downloads/session_empty')

% probes = E.getprobes('element.name', 'tetrode7')

% spikesorter_hengen = ndi.app.spikesorter.hengen(E)

% spikesorter_hengen.extract_and_sort(probes{1})

% spikesorter_hengen.rate_neuron_quality()

% neurons = E.getelements('element.name', 'neuron_1');

% [d,t] = readtimeseries(neurons{1}, 1, -Inf, Inf);

% figure;
% plot(t, d, 'o');

% NDI way

% Remove .ndi directory if it exists to avoid errors
dirpath = '/Users/danielgmu/Downloads/Experiments/2019-08-22'
if exist([dirpath filesep '.ndi'], 'dir') == 7
	rmdir([dirpath filesep '.ndi'], 's');
end

E = ndi.session.dir('ts1','/Users/danielgmu/Downloads/Experiments/2019-08-22');

ced_filenav = ndi.file.navigator(E, {'.*\.smr\>', 'probemap.txt'}, 'ndi.epoch.epochprobemap_daqsystem', 'probemap.txt'); 
ced_vis_filenav = ndi.file.navigator(E, {'.*\.smr\>', 'probemap.txt', 'stims.mat'}, 'ndi.epoch.epochprobemap_daqsystem', 'probemap.txt'); 

% Create daqreader objects for our daq systems
ced_rdr = ndi.daq.reader.mfdaq.cedspike2(); 
ced_vis_rdr = ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2();

% Create a metadata reader for our stimulus daq system
% This reader interprets the metadata from our visual stimuli
ced_vis_mdr = {ndi.daq.metadatareader.NewStimStims('stims.mat')}; 

measure_sys = ndi.daq.system.mfdaq('ced_daqsystem', ced_filenav, ced_rdr);
stim_sys = ndi.daq.system.mfdaq('ced_vis_daqsystem', ced_vis_filenav, ced_vis_rdr);

E.daqsystem_add(measure_sys); 
E.daqsystem_add(stim_sys);

extraction_name = 'hengen_extraction_test'
sorting_name = 'hengen_sorting_test'

probes = E.getprobes()

spikesorter_hengen = ndi.app.spikesorter.hengen(E)

spikesorter_hengen.add_extraction_doc(extraction_name, [])

spikesorter_hengen.add_sorting_doc(sorting_name, [])

spikesorter_hengen.add_geometry_doc(probes{1})

spikesorter_hengen.extract_and_sort(probes{1}, extraction_name, sorting_name, 1)

spikesorter_hengen.rate_neuron_quality

