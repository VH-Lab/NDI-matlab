% Create session folder and add .bin files to extract and sort
% modify filepath in app/spikesorter_hengen/json_input_files/spkint_wrapper_input_64ch.json
% to point to desired .bin file (to be found ndi_session path)

% E = ndi.session.dir('exp_hengen', '/Users/danielgmu/Downloads/session_empty')

% probes = E.getprobes('element.name', 'tetrode7')

% spikesorter_hengen = ndi.app.spikesorter_hengen(E)

% spikesorter_hengen.extract_and_sort(probes{1})

% spikesorter_hengen.rate_neuron_quality()

% neurons = E.getelements('element.name', 'neuron_1');

% [d,t] = readtimeseries(neurons{1}, 1, -Inf, Inf);

% figure;
% plot(t, d, 'o');

% NDI way

% Remove .ndi directory if it exists to avoid errors
dirpath = '/Users/danielgmu/Downloads/Experiments/'
if exist([dirpath filesep '.ndi'], 'dir') == 7
	rmdir([dirpath filesep '.ndi'], 's');
end

disp(['Opening experiment ' dirpath '...']);

E = ndi.setups.vhlab_expdir('2019-11-19', dirpath);

probelist = E.getprobes();
howmany_probes = length(probelist)
prb = 1;

extraction_name = 'hengen_carbon_extraction_test'
sorting_name = 'hengen_carbon_sorting_test'

probes = E.getprobes()

keyboard

spikesorter_hengen = ndi.app.spikesorter_hengen(E)

spikesorter_hengen.add_extraction_doc(extraction_name, [])

spikesorter_hengen.add_sorting_doc(sorting_name, [])

spikesorter_hengen.add_geometry_doc(probes{1})

spikesorter_hengen.extract_and_sort(probes{1}, extraction_name, sorting_name, 1)

spikesorter_hengen.rate_neuron_quality

