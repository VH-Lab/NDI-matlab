% not general - only works on specified directory on Daniel's computer

% Remove .ndi directory if it exists to avoid errors
dirpath = '/Users/danielgmu/Downloads/Experiments/2019-08-22'
if exist([dirpath filesep '.ndi'], 'dir') == 7
    rmdir([dirpath filesep '.ndi'], 's');
end

our_exp = ndi.session.dir('ts1',dirpath);

ced_filenav = ndi.file.navigator(our_exp, {'.*\.smr\>', 'probemap.txt'}, 'ndi.epoch.epochprobemap_daqsystem', 'probemap.txt');
ced_vis_filenav = ndi.file.navigator(our_exp, {'.*\.smr\>', 'probemap.txt', 'stims.mat'}, 'ndi.epoch.epochprobemap_daqsystem', 'probemap.txt');

% Create daqreader objects for our daq systems
ced_rdr = ndi.daq.reader.mfdaq.cedspike2();
ced_vis_rdr = ndi.daq.reader.mfdaq.stimulus.vhlabvisspike2();

% Create a metadata reader for our stimulus daq system
% This reader interprets the metadata from our visual stimuli
ced_vis_mdr = {ndi.daq.metadatareader.NewStimStims('stims.mat')};

measure_sys = ndi.daq.system.mfdaq('ced_daqsystem', ced_filenav, ced_rdr);
stim_sys = ndi.daq.system.mfdaq('ced_vis_daqsystem', ced_vis_filenav, ced_vis_rdr);

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
spikeextractor.add_appdoc(spikeextractor.session, 'extraction_parameters', [], 'ReplaceIfDifferent', ...
    'test_extract');
spikeextractor.extract(probe, e,'test_extract');

w = spikeextractor.loaddata_appdoc('spikewaves', probe, 1, 'test_extract');
figure;
plot(w(:,:,1));
title(['First spike']);
xlabel('Samples');
ylabel('Amplitude');

spikesorter = ndi.ap0.spikesorter(our_exp);
spikesorter.add_sorting_doc('test_sort', []);
spikesorter.spike_sort(probe, e, 'test_extract', 'test_sort', 0);

neuron1 = our_exp.getelements('element.name','neuron_1');
[d1,t1] = readtimeseries(neuron1{1},1,-Inf,Inf);

figure(10)
plot(t1,d1,'ko');
title([neuron1{1}.name]);
ylabel(['spikes']);
xlabel(['time (s)']);
