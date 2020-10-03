// not general - only works on specified directory on Ora's computer

our_exp = ndi.session.dir('ts1','/Users/Ora/Docs2/Experiments/2019-08-22');

ced_filenav = ndi.file.navigator(our_exp, {'.*\.smr\>', 'probemap.txt'}, 'ndi.epoch.epochprobemap_daqsystem', 'probemap.txt'); 
ced_vis_filenav = ndi.file.navigator(our_exp, {'.*\.smr\>', 'probemap.txt', 'stims.mat'}, 'ndi.epoch.epochprobemap_daqsystem', 'probemap.txt'); 

ced_rdr = ndi.daq.reader.mfdaq.cedspike2(); 
ced_vis_rdr = ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2();

measure_sys = ndi.daq.system.mfdaq('ced_daqsystem', ced_filenav, ced_rdr);
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
vlt.plot.plot_multichan(d,t,10);

spikeextractor = ndi.ap0.spikeextractor(our_exp); 
spikeextractor.add_appdoc(spikeextractor.session, 'extraction_parameters', [], 'default');
spikeextractor.extract(probe, e,'default');

w = spikeextractor.loaddata_appdoc('spikewaves',probe,1,'default');
figure;
plot(w(:,:,1));
title(['First spike']);
xlabel('Samples');
ylabel('Amplitude');

spikesorter = ndi.ap0.spikesorter(our_exp);
param_folder = '/Users/Ora/Documents/MATLAB/tools/NDI-matlab/ndi_common/example_sessions/spikesortdemo/';
sort_param = [param_folder 'tvh_sorting_parameters.txt'];
spikesorter.spike_sort(probe, e, 'default', 'test_sort', sort_param);

neuron1 = ndi.ap0.spikesorter_obj.session.getelements('element.name','neuron_1');
[d1,t1] = readtimeseries(neuron1{1},1,-Inf,Inf);

figure(10)
plot(t1,d1,'ko');
title([neuron.name]);
ylabel(['spikes']);
xlabel(['time (s)']);
