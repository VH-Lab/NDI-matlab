% Create experiment folder and add .bin files to extract and sort
% modify filepath in app/spikesorter_hengen/json_input_files/spkint_wrapper_input_64ch.json
% to point to desired .bin file (to be found ndi_experiment path)

E = ndi_experiment_dir('exp_hengen', '/Users/danielgmu/Downloads/experiment_empty')

spikesorter_hengen = ndi_app_spikesorter_hengen(E)

spikesorter_hengen.extract_and_sort(1) % pass in 1 for redo

spikesorter_hengen.rate_neuron_quality()

neurons = E.getthings('thing.name', 'neuron_1');

[d,t] = readtimeseries(neurons{1}, 1, -Inf, Inf);

figure;
plot(t, d, 'o');
