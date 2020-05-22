// not general - only works on specified directory on Ora's computer

our_exp = ndi_session_dir('ts1','/Users/Ora/Docs2/Experiments/2019-08-22');

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
spikeextractor.add_extraction_doc('default', []);
spikeextractor.extract(probe, e,'default');

w = spikeextractor.load_spikewaves_epoch(probe,1,'default');
figure;
plot(w(:,:,1));
title(['First spike']);
xlabel('Samples');
ylabel('Amplitude');

spikesorter = ndi_app_spikesorter(our_exp);
param_folder = '/Users/Ora/Documents/MATLAB/tools/NDI-matlab/ndi_common/example_sessions/spikesortdemo/';
sort_param = [param_folder 'tvh_sorting_parameters.txt'];
spikesorter.spike_sort(probe, e, 'default', 'test_sort', sort_param);

neuron1 = ndi_app_spikesorter_obj.session.getelements('element.name','neuron_1');
[d1,t1] = readtimeseries(neuron1{1},1,-Inf,Inf);

figure(10)
plot(t1,d1,'ko');
title([neuron.name]);
ylabel(['spikes']);
xlabel(['time (s)']);
