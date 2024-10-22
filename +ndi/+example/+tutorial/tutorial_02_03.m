function tutorial_02_03(prefix, testing)
% ndi.example.tutorials.tutorial_02_03 - runs the code in Tutorial 2.3
%
% out = ndi.example.tutorials.tutorial_02_03(PREFIX, [TESTING])
%
% Runs (and tests) the code for 
%
% NDI Tutorial 2: Analzying your first electrophysiology experiment with NDI
%    Tutorial 2.3: Using apps to analyze data (example - spike sorting)
% The tutorial is available at 
%     https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/3_spikesorting/
%
% PREFIX should be the directory that contains the directory 'ts_exper2'. If it is not
% provided or is empty, the default is [userpath filesep 'Documents' filesep 'NDI'].
%
% If TESTING is 1, then the files are examined in the temporary directory 
% ndi.common.PathConstants.TempFolder . It is assumed that
% ndi.example.tutorial.tutorial_t02_02([],1) has been run (with TESTING set to 1).
%
% Note: a little manual intervention is needed in this tutorial.
%

if nargin<1 | isempty(prefix),
    prefix = [userpath filesep 'Documents' filesep 'NDI']; % or '/Users/yourusername/Desktop/' if you put it on the desktop perhaps
end;

if nargin<2,
    testing = 0;
end;

tutorial_dir = 'ts_exper2';

if testing, % copy the files to the temp directory
    prefix = ndi.common.PathConstants.TempFolder;
    disp(['Assuming data files ts_exper2 are in ' prefix '.']);
end

 % Code block 2.3.2.1

disp(['Code block 2.3.2.1:']);
dirname = [prefix filesep 'ts_exper2']; % differs from manual tutorial
ref = 'ts_exper2';
S = ndi.setup.vhlab(ref,dirname);  

% let's find our probes that correspond to extracellular electrodes

p = S.getprobes('type','n-trode');

% make a new app instance
se = ndi.app.spikeextractor(S);

% find out what the spike extraction parameters are
extraction_param_struct = se.defaultstruct_appdoc('extraction_parameters');
% if we wanted to modify these parameters, we could
extraction_param_struct.threshold_parameter = 4;
extraction_param_struct.threshold_sign = 1;
my_extraction_name{1} = 'my_positive_extraction_params';
extraction_param_doc = se.add_appdoc('extraction_parameters',extraction_param_struct,'Replace',my_extraction_name{1});
my_extraction_name{2} = 'my_negative_extraction_params';
extraction_param_struct.threshold_parameter = -4;
extraction_param_struct.threshold_sign = -1;
extraction_param_doc_2 = se.add_appdoc('extraction_parameters',extraction_param_struct,'Replace',my_extraction_name{2});

% we will add a parameter document to our database that our extractor will use


% now let's perform the extraction over all epochs

redo = 1; % redo it if we already did it
 % we know there are two probes, so do it for both
se.extract(p{1},[],my_extraction_name{1},redo);
se.extract(p{2},[],my_extraction_name{2},redo);


 % Code block 2.3.2.2
disp(['Code block 2.3.2.2:']);

% now let's take a look at what we got for the first probe, first epoch
epoch_id = 't00001';

[spikes,waveparameters,spiketimes,spikewaves_doc] = se.loaddata_appdoc('spikewaves',p{1},epoch_id,my_extraction_name{1});

% let's plot these waveforms

t_spike = [waveparameters.S0:waveparameters.S1] * 1/waveparameters.samplerate; % create a time vector

% spikes is a 3-d matrix.
% The first dimension has the number of samples per spike.
% The second dimension has data from each channel. Because this is a single electrode, there is only one channel. If it were a tetrode, this would be 4.
% The third dimension is the number of spikes detected.
size(spikes)

figure(101);
plot(t_spike,squeeze(spikes));
xlabel('Time (s)');
ylabel('Voltage');
box off;

% We can see how we did by plotting the spike times back with the raw data:

[d,t] = readtimeseries(p{1},epoch_id,-Inf,Inf);
figure(102);
plot(t,d);
hold on;
samples = round(vlt.signal.value2sample(spiketimes, 1/(t(2)-t(1)), 0));
plot(t(samples),d(samples),'ko'); % mark each spike peak location with a circle 


 % Code block 2.3.3

disp(['Code block 2.3.3.1:'])
disp(['Note: manual intervention will be required. See https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/3_spikesorting/']);
disp(['(pausing for 5 seconds.)']);
pause(5);

ssa = ndi.app.spikesorter(S);

sorting_params_struct = ssa.defaultstruct_appdoc('sorting_parameters');
my_sorting_name = 'my_sorting_params';
sorting_param_doc = ssa.add_appdoc('sorting_parameters',sorting_params_struct,'Replace',my_sorting_name);

spike_cluster_doc = ssa.spike_sort(p{1},my_extraction_name{1},my_sorting_name,redo)
ssa.clusters2neurons(p{1},my_sorting_name,my_extraction_name{1},redo)

spike_cluster_doc = ssa.spike_sort(p{2},my_extraction_name{2},my_sorting_name,redo)
ssa.clusters2neurons(p{2},my_sorting_name,my_extraction_name{2})


 % Code block 2.3.3.2

disp(['Code block 2.3.3.2:'])

e = S.getelements('element.type','spikes','element.name','ctx_1')
[D,T] = e{1}.readtimeseries('t00001',-Inf,Inf);

figure(102);
hold on;
samples2 = round(vlt.signal.value2sample(T, 1/(t(2)-t(1)), 0));
plot(T,d(samples2), 'gs');

% now spike times from neuron 1 are plotted as green squares

 % Code block 2.3.4.1

disp(['Clode block 2.3.4.1:']);
help ndi.app.spikeextractor/appdoc_description


