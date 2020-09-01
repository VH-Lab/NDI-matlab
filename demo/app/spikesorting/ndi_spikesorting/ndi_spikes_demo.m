ndi_Init;
ndi_globals;

mydirectory = [ndi.path.exampleexperpath];
dirname = [mydirectory filesep 'exp_sg'];
dot_ndi = [dirname filesep '.ndi'];

% Remove .ndi directory if it exists to avoid errors
if exist(dot_ndi, 'dir') == 7
	rmdir([dirname filesep '.ndi'], 's');
end

disp(['opening session object...']);
E = ndi_session_dir('exp1', dirname);
d = E.daqsystem_load('name','SpikeGadgets');

if isempty(d),
	disp(['Now adding our acquisition device (SpikeGadgets):']);
	filenav = ndi_filenavigator(E, '.*\.rec\>');  % look for .rec files
	dr = ndi_daqreader_mfdaq_spikegadgets;
	dev1 = ndi_daqsystem_mfdaq('SpikeGadgets',filenav, dr);
	E.daqsystem_add(dev1);
end;

spike_extractor = ndi_app_spikeextractor(E);
spike_sorter = ndi_app_spikesorter(E);
probes = E.getprobes();
probe = probes{1};

% d = E.database_search({'ndi_document.name','test','spike_extraction_parameters.filter_type','(.*)'});
% if isempty(d),
% 	spike_extractor.add_extraction_doc('test');
% end;


spike_extractor.extract(probe, 1, 'test', 'default', 1); % probe/element, epoch, extraction_name, extraction_params, redo
w = spike_extractor.load_spikewaves_epoch(probe,1,'test');
figure;
plot(w(:,:,1)); 
title(['First spike']);
xlabel('Samples');
ylabel('Amplitude');

spike_sorter.spike_sort(probe, 1, 'test', 'test_sort', 'ndi_common/example_app_sessions/exp_sg/sorting_parameters.txt')
