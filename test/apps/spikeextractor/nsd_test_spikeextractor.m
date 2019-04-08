function nsd_test_spikeextractor
% NSD_TEST_SPIKEEXTRACTOR - Test the functionality of the apps 'nsd_spikeextractor' and 'nsd_spikesort' with example data
%
% Tests the NSD_APP_SPIKEEXTRACTOR on example data in 
% [NSDCOMMONPATH]/example_app_experiments/exp_sg
%

 % find our directory

nsd_globals;
mydirectory = [nsdcommonpath filesep 'example_app_experiments'];
dirname = [mydirectory filesep 'exp_sg'];


disp(['creating a new experiment object...']);
E = nsd_experiment_dir('exp1', dirname);

% remove any old acq devices

devs = E.iodevice_load('name','(.*)');
for i=1:numel(devs),
	E.iodevice_rm(celloritem(devs,i));
end;


disp(['Now adding our acquisition device (SpikeGadgets):']);
ft = nsd_filetree(E, '.*\.rec\>');  % look for .rec files
dev1 = nsd_iodevice_mfdaq_sg('SpikeGadgets', ft);
E.iodevice_add(dev1);

eparams = [dirname filesep 'extraction_parameters.txt'];
sparams = [dirname filesep 'sorting_parameters.txt'];

spike_extractor = nsd_app_spikeextractor(E);
spike_sorter = nsd_app_spikesorter(E);

 % I'd add something here that clears out any old extraction variables; see nsd_app_markgarbage/clearvalidinterval

spike_extractor.spike_extract_probes('Tetrode7', 'n-trode', 'test', eparams);

probes = E.getprobes('name','Tetrode7');
myprobe = probes{1}; 

catspikes = spike_extractor.load_spikes(myprobe,'test'),

spike_sorter.spike_sort('Tetrode7', 'n-trode', 'test', 'test_sort', sparams);


