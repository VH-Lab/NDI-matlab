ndi_globals;

if 0,
	exp_dir = '/Users/Ora/Desktop/labx_experiments';
end;

dot_ndi = [exp_dir filesep '.ndi'];
our_exp = ndi_experiment_dir('treeshrew1',exp_dir)

if exist(dot_ndi, 'dir') == 7
	rmdir(dot_ndi, 's');
end

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
prb = 1; 
probe = probelist{prb};

howmany_epochs = length(epochtable(measure_sys))
e = 4; 

figure('Name', ['Probe ' num2str(prb)  ', Epoch ' num2str(e)], 'NumberTitle','off');
[d,t] = probe.read_epochsamples(e,1,Inf);
plot_multichan(d,t,10);

spikeextractor = ndi_app_spikeextractor(our_exp);
extract_doc = ndi_document('apps/spikeextractor/spike_extraction_parameters');
spikeextractor.add_extraction_doc('default_parameters', extract_doc);
spikeextractor.extract(probe, e, 'default_parameters');

w = spike_extractor.load_spikewaves_epoch(probe,1,'test');
figure;
plot(w(:,:,1)); 
title(['First spike']);
xlabel('Samples');
ylabel('Amplitude');

spikesorter = ndi_app_spikesorter(our_exp);
sort_param = [param_folder 'tvh_sorting_parameters.txt'];
spikesorter.spike_sort(probe, e,'extraction_name','test_sort', sort_param)
