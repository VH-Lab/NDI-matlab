% This script contains all of the code for
%
% NDI Tutorial 1: Analzying your first electrophysiology experiment with NDI
%    Tutorial 1.1: Reading an example dataset
% The tutorial is available at 
%     https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/1_example_dataset.md
%
%

 % Code block 1.1.2.1

prefix = [userpath filesep 'Documents' filesep 'NDI']; % or '/Users/yourusername/Desktop/' if you put it on the desktop perhaps
ls([prefix filesep 'ts_exper1' filesep 't*']); % list all the files in the t0000N folders

 % Code block 1.1.2.2

my_smr_file = fullfile(prefix,'ts_exper1','t00001','spike2data.smr')
ndi.example.tutorial.plottreeshrewdata(my_smr_file);

 % Code block 1.1.3.1

type (fullfile(prefix,'ts_exper1','t00001','probemap.txt'))

 % Code block 1.1.3.2

type (fullfile(prefix,'ts_exper1','t00001','stims.tsv'))

 % Code block 1.1.4.1

S = ndi.session.dir('ts_exper1',[prefix filesep 'ts_exper1'])

 % inserted code for the full script:

S.daqsystem_clear() % make sure we don't have old daq systems from the demo

 % Code block 1.1.4.2
S.getprobes()

 % Code block 1.1.4.3

ced_filenav = ndi.file.navigator(S, {'.*\.smr\>', 'probemap.txt'}, ...
    'ndi.daq.metadata.epochprobemap_daqsystem','probemap.txt');
ced_rdr = ndi.daq.reader.mfdaq.cedspike2();
ced_system = ndi.daq.system.mfdaq('ced_daqsystem', ced_filenav, ced_rdr);
 % if you haven't already added the daq system, you can add it here:
S.daqsystem_add(ced_system);

 % Code block 1.1.4.4

 % let's look at the epochs the daq.system can find
et = ced_system.epochtable() % should see a 4 element answer
f = ced_system.filenavigator.getepochfiles(1) % you should see the files from epoch 1, t00001

 % Code block 1.1.4.5

vis_filenav = ndi.file.navigator(S, {'.*\.smr\>', 'probemap.txt', 'stims.tsv'},...
     'ndi.daq.metadata.epochprobemap_daqsystem','probemap.txt');
vis_rdr = ndi.daq.reader.mfdaq.cedspike2();
vis_mdrdr = ndi.daq.metadatareader('stims.tsv');
vis_system = ndi.daq.system.mfdaq('vis_daqsystem', vis_filenav, vis_rdr, {vis_mdrdr});
 % if you haven't already added the daq system, you can add it here:
S.daqsystem_add(vis_system);

 % Code block 1.1.4.6

nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
S.syncgraph_addrule(nsf);

 % Code block 1.1.5.1

p = S.getprobes() % get all of the probes that are in the ndi.session S
for i=1:numel(p), p{i}, end; % display the probe information for each probe

% look at the number of epochs recorded for probe 1
p_ctx1_list = S.getprobes('name','ctx','reference',1) % returns a cell array of matches
p_ctx1 = p_ctx1_list{1}; % take the first one, should be the only one
et = p_ctx1.epochtable()
for i=1:numel(et), et(i), end; % display the epoch table entries
epoch_to_read = 1;

 % Code block 1.1.5.2

[data,t,timeref_p_ctx1]=p_ctx1.readtimeseries(epoch_to_read,-Inf,Inf); % read all data from epoch 1
figure(100);
plot(t,data);
xlabel('Time(s)');
ylabel('Voltage (V)');
set(gca,'xlim',[t(1) t(end)]);
box off;

 % Code block 1.1.5.3

p_visstim_list = S.getprobes('name','vis_stim','reference',1) % returns a cell array of matches
p_visstim = p_visstim_list{1}; % take the first one, should be the only one
et = p_visstim.epochtable()
for i=1:numel(et), et(i), end; % display the epoch table entries

 % Code block 1.1.5.4

timeref_p_ctx1

 % Code block 1.1.5.5

[data,t,timeref_stim]=p_visstim.readtimeseries(timeref_p_ctx1,-Inf,Inf); % read all data from epoch 1 of p_ctx1 !
figure(100);
hold on;
vlt.neuro.stimulus.plot_stimulus_timeseries(7,t.stimon,t.stimon+2,'stimid',data.stimid);

 % Code block 1.1.5.6

t, % show timestamps
t.stimon,
data, % show data
data.stimid,
data.parameters{1}







