function spikeextractor
% ndi.test.app.spikeextractor - Test the functionality of the apps 'ndi.ap0.spikeextractor' and 'ndi.app.spikesort' with example data
%
% Tests the ndi.ap0.spikeextractor on example data in 
% [NDICOMMONPATH]/example_app_sessions/exp_sg
%

 % find our directory

ndi.globals;
mydirectory = [ndi_globals.path.commonpath filesep 'example_app_sessions'];
dirname = [mydirectory filesep 'exp_sg'];


disp(['creating a new session object...']);
E = ndi.session.dir('exp1', dirname);

% remove any old acq devices

devs = E.daqsystem_load('name','(.*)');
for i=1:numel(devs),
	E.daqsystem_rm(vlt.data.celloritem(devs,i));
end;


disp(['Now adding our acquisition device (SpikeGadgets):']);
ft = ndi.file.navigator(E, '.*\.rec\>');  % look for .rec files
dev1 = ndi_daqsystem_mfdaq_sg('SpikeGadgets', ft);
E.daqsystem_add(dev1);

eparams = [dirname filesep 'extraction_parameters.txt'];
sparams = [dirname filesep 'sorting_parameters.txt'];

spike_extractor = ndi.ap0.spikeextractor(E);
spike_sorter = ndi.ap0.spikesorter(E);

 % I'd add someelement here that clears out any old extraction variables; see ndi.ap0.markgarbage/clearvalidinterval

spike_extractor.spike_extract_probes('Tetrode7', 'n-trode', 'test', eparams);

probes = E.getprobes('name','Tetrode7');
myprobe = probes{1}; 

catspikes = spike_extractor.load_spikes(myprobe,'test'),

spike_sorter.spike_sort('Tetrode7', 'n-trode', 'test', 'test_sort', sparams);


