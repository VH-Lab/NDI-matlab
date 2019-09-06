ndi_globals;
mydirectory = [ndipath filesep 'ndi_common' filesep 'example_app_experiments'];
dirname = [mydirectory filesep 'exp_sg'];
rmdir([dirname filesep '.ndi'], 's')
disp(['creating a new experiment object...']);
exp = ndi_experiment_dir('exp1', dirname);
disp(['Now adding our acquisition device (SpikeGadgets):']);
filenav = ndi_filenavigator(exp, '.*\.rec\>');  % look for .rec files
dr = ndi_daqreader_mfdaq_sg;
dev1 = ndi_daqsystem_mfdaq('SpikeGadgets',filenav, dr);
exp.daqsystem_add(dev1);
spike_extractor = ndi_app_spikeextractor(exp);
spike_sorter = ndi_app_spikesorter(exp);
probe = exp.getprobes('name','Tetrode7','reference',1,'type','n-trode');
probe = probe{1};
spike_extractor.extract(probe, 1, [], 'test', 1)
%spike_sorter.spike_sort('Tetrode7', 'n-trode', 1, 'test', 'test_sort', 'ndi_common/example_app_experiments/exp_sg/sorting_parameters.txt')
