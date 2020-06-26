% Create experiment folder and add .bin files to extract and sort
% modify filepath in app/spikesorter_hengen/json_input_files/spkint_wrapper_input_64ch.json
% to point to desired .bin file (to be found ndi_experiment path)

% E = ndi_experiment_dir('exp_hengen', '/Users/danielgmu/Downloads/experiment_empty')

% probes = E.getprobes('thing.name', 'tetrode7')

% spikesorter_hengen = ndi_app_spikesorter_hengen(E)

% spikesorter_hengen.extract_and_sort(probes{1})

% spikesorter_hengen.rate_neuron_quality()

% neurons = E.getthings('thing.name', 'neuron_1');

% [d,t] = readtimeseries(neurons{1}, 1, -Inf, Inf);

% figure;
% plot(t, d, 'o');

% NDI way

% Remove .ndi directory if it exists to avoid errors
dirpath = '/Users/danielgmu/Downloads/Experiments/2019-08-22'
if exist([dirpath filesep '.ndi'], 'dir') == 7
	rmdir([dirpath filesep '.ndi'], 's');
end

E = ndi_experiment_dir('ts1','/Users/danielgmu/Downloads/Experiments/2019-08-22');

ced_filenav = ndi_filenavigator(E, {'.*\.smr\>', 'probemap.txt'}, 'ndi_epochprobemap_daqsystem', 'probemap.txt'); 
ced_vis_filenav = ndi_filenavigator(E, {'.*\.smr\>', 'probemap.txt', 'stims.mat'}, 'ndi_epochprobemap_daqsystem', 'probemap.txt'); 

ced_rdr = ndi_daqreader_mfdaq_cedspike2(); 
ced_vis_rdr = ndi_daqreader_mfdaq_stimulus_vhlabvisspike2();

measure_sys = ndi_daqsystem_mfdaq('ced_daqsystem', ced_filenav, ced_rdr);
stim_sys = ndi_daqsystem_mfdaq_stimulus('ced_vis_daqsystem', ced_vis_filenav, ced_vis_rdr);

E.daqsystem_add(measure_sys); 
E.daqsystem_add(stim_sys);

probelist = E.getprobes();

probe = probelist{1};

probes = E.getprobes()

spikesorter_hengen = ndi_app_spikesorter_hengen(E)

% spikesorter_hengen.add_extraction_doc(extraction_name, [])

% spikesorter_hengen.add_sorting_doc(sorting_name, [])

% spikesorter_hengen.extract_and_sort(probes{1}, extraction_name, geom, 1)

spikesorter_hengen.extract_and_sort(probes{1}, extraction_name, geom, 1)

spikesorter_hengen.rate_neuron_quality

