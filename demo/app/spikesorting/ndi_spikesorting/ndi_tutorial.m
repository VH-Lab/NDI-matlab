% not general - only works on specified directory on Daniel's computer

% Remove .ndi directory if it exists to avoid errors
dirpath = '/Users/danielgmu/Downloads/Experiments/2019-08-22'
if exist([dirpath filesep '.ndi'], 'dir') == 7
	rmdir([dirpath filesep '.ndi'], 's');
end

our_exp = ndi_experiment_dir('ts1','/Users/danielgmu/Downloads/Experiments/2019-08-22');

ced_filenav = ndi_filenavigator(our_exp, {'.*\.smr\>', 'probemap.txt'}, 'ndi_epochprobemap_daqsystem', 'probemap.txt'); 
ced_vis_filenav = ndi_filenavigator(our_exp, {'.*\.smr\>', 'probemap.txt', 'stims.mat'}, 'ndi_epochprobemap_daqsystem', 'probemap.txt'); 

ced_rdr = ndi_daqreader_mfdaq_cedspike2(); 
ced_vis_rdr = ndi_daqreader_mfdaq_stimulus_vhlabvisspike2();

measure_sys = ndi_daqsystem_mfdaq('ced_daqsystem', ced_filenav, ced_rdr);
stim_sys = ndi_daqsystem_mfdaq_stimulus('ced_vis_daqsystem', ced_vis_filenav, ced_vis_rdr);

our_exp.daqsystem_add(measure_sys); 
our_exp.daqsystem_add(stim_sys);

probelist = our_exp.getprobes()

howmany_probes = length(probelist)
prb = 3; 
howmany_epochs = length(epochtable(measure_sys))
e = 1;

figure('Name', ['Probe ' num2str(prb)  ', Epoch ' num2str(e)], 'NumberTitle','off');
probe = probelist{prb};
[d,t] = probe.read_epochsamples(e,1,Inf);
plot_multichan(d,t,10);

spikeextractor = ndi_app_spikeextractor(our_exp); 
spikeextractor.add_extraction_doc('test_extract', []);
spikeextractor.extract(probe, e,'test_extract');

w = spikeextractor.load_spikewaves_epoch(probe, 1, 'test_extract');
figure;
plot(w(:,:,1));
title(['First spike']);
xlabel('Samples');
ylabel('Amplitude');

spikesorter = ndi_app_spikesorter(our_exp);
spikesorter.add_sorting_doc('test_sort', []);
spikesorter.spike_sort(probe, e, 'test_extract', 'test_sort', 0);

neuron1 = our_exp.getelements('element.name','neuron_1');
[d1,t1] = readtimeseries(neuron1{1},1,-Inf,Inf);

figure(10)
plot(t1,d1,'ko');
title([neuron1{1}.name]);
ylabel(['spikes']);
xlabel(['time (s)']);
