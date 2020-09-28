function ndi_test_spikeextractor
% NDI_TEST_SPIKEEXTRACTOR - Test the functionality of the apps 'ndi_spikeextractor' and 'ndi_spikesort' with example data
%
% Tests the NDI_APP_SPIKEEXTRACTOR on example data in 
% [NDICOMMONPATH]/example_app_sessions/exp_sg
%

 % find our directory

ndi_globals;
mydirectory = [ndi_globals.path.commonpath filesep 'example_app_sessions'];
dirname = [mydirectory filesep 'exp_sg'];


disp(['creating a new session object...']);
E = ndi_session_dir('exp1', dirname);

% remove any old acq devices

devs = E.daqsystem_load('name','(.*)');
for i=1:numel(devs),
	E.daqsystem_rm(vlt.data.celloritem(devs,i));
end;


disp(['Now adding our acquisition device (SpikeGadgets):']);
ft = ndi_filenavigator(E, '.*\.rec\>');  % look for .rec files
dev1 = ndi_daqsystem_mfdaq_sg('SpikeGadgets', ft);
E.daqsystem_add(dev1);

eparams = [dirname filesep 'extraction_parameters.txt'];
sparams = [dirname filesep 'sorting_parameters.txt'];

spike_extractor = ndi_app_spikeextractor(E);
spike_sorter = ndi_app_spikesorter(E);

 % I'd add someelement here that clears out any old extraction variables; see ndi_app_markgarbage/clearvalidinterval

spike_extractor.spike_extract_probes('Tetrode7', 'n-trode', 'test', eparams);

probes = E.getprobes('name','Tetrode7');
myprobe = probes{1}; 

catspikes = spike_extractor.load_spikes(myprobe,'test'),

spike_sorter.spike_sort('Tetrode7', 'n-trode', 'test', 'test_sort', sparams);


