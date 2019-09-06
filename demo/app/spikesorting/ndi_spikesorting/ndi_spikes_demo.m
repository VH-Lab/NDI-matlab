ndi_Init;
ndi_globals;

mydirectory = [ndipath filesep 'ndi_common' filesep 'example_app_experiments'];
dirname = [mydirectory filesep 'exp_sg'];

rmdir([dirname filesep '.ndi'], 's')
disp(['creating a new experiment object...']);

exp = ndi_experiment_dir('exp1', dirname);
disp(['Now adding our acquisition device (SpikeGadgets):']);
filenav = ndi_filenavigator(exp, '.*\.rec\>');  % look for .rec files

dev1 = exp.daqsystem_load('name','spikegadgets');
if isempty(dev1),
	dev1 = ndi_daqsystem_mfdaq('spikegadgets', filenav, ndi_daqreader_mfdaq_sg());
	exp.daqsystem_add(dev1);
end

spike_extractor = ndi_app_spikeextractor(exp);
spike_sorter = ndi_app_spikesorter(exp);
spike_extractor.spike_extract_probes('Tetrode7', 'n-trode', 1, 'test_extraction', [ndipath filesep 'ndi_common/example_app_experiments/exp_sg/extraction_parameters.txt'])
spike_sorter.spike_sort('Tetrode7', 'n-trode', 1, 'test', 'test_sort', [ndipath filesep 'ndi_common/example_app_experiments/exp_sg/sorting_parameters.txt'])
