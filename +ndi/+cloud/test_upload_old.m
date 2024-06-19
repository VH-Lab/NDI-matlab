%% tutorial 2.1
prefix = [filesep 'Users' filesep 'cxy' filesep 'Documents' filesep 'NDI'];
ls([prefix filesep 'ts_exper1' filesep 't*']);

my_smr_file = fullfile(prefix,'ts_exper1','t00001','spike2data.smr');
ndi.example.tutorial.plottreeshrewdata(my_smr_file);
type (fullfile(prefix,'ts_exper1','t00001','probemap.txt'))
type (fullfile(prefix,'ts_exper1','t00001','stims.tsv'))
S = ndi.session.dir('ts_exper1',[prefix filesep 'ts_exper1']);

%%
S.getprobes()
ced_filenav = ndi.file.navigator(S, {'.*\.smr\>', 'probemap.txt'}, ...
    'ndi.epoch.epochprobemap_daqsystem','probemap.txt');
ced_rdr = ndi.daq.reader.mfdaq.cedspike2();
ced_system = ndi.daq.system.mfdaq('ced_daqsystem', ced_filenav, ced_rdr);
 % if you haven't already added the daq system, you can add it here:
S.daqsystem_add(ced_system);

 % let's look at the epochs the daq.system can find
et = ced_system.epochtable(); % should see a 4 element answer
f = ced_system.filenavigator.getepochfiles(1); % you should see the files from epoch 1, t00001

vis_filenav = ndi.file.navigator(S, {'.*\.smr\>', 'probemap.txt', 'stims.tsv'},...
     'ndi.epoch.epochprobemap_daqsystem','probemap.txt');
vis_rdr = ndi.daq.reader.mfdaq.cedspike2();
vis_mdrdr = ndi.daq.metadatareader('stims.tsv');
vis_system = ndi.daq.system.mfdaq('vis_daqsystem', vis_filenav, vis_rdr, {vis_mdrdr});
 % if you haven't already added the daq system, you can add it here:
S.daqsystem_add(vis_system);
nsf = ndi.time.syncrule.filematch(struct('number_fullpath_matches',2));
S.syncgraph_addrule(nsf);

p = S.getprobes() % get all of the probes that are in the ndi.session S
for i=1:numel(p), p{i}, end; % display the probe information for each probe

% look at the number of epochs recorded for probe 1
p_ctx1_list = S.getprobes('name','ctx','reference',1) % returns a cell array of matches
p_ctx1 = p_ctx1_list{1}; % take the first one, should be the only one
et = p_ctx1.epochtable()
for i=1:numel(et), et(i), end; % display the epoch table entries
epoch_to_read = 1;

[data,t,timeref_p_ctx1]=p_ctx1.readtimeseries(epoch_to_read,-Inf,Inf); % read all data from epoch 1
figure(100);
plot(t,data);
xlabel('Time(s)');
ylabel('Voltage (V)');
set(gca,'xlim',[t(1) t(end)]);
box off;

p_visstim_list = S.getprobes('name','vis_stim','reference',1) % returns a cell array of matches
p_visstim = p_visstim_list{1}; % take the first one, should be the only one
et = p_visstim.epochtable()
for i=1:numel(et), et(i), end; % display the epoch table entries

[data,t,timeref_stim]=p_visstim.readtimeseries(timeref_p_ctx1,-Inf,Inf); % read all data from epoch 1 of p_ctx1 !
figure(100);
hold on;
vlt.neuro.stimulus.plot_stimulus_timeseries(7,t.stimon,t.stimon+2,'stimid',data.stimid);

t, % show timestamps
t.stimon,
data, % show data
data.stimid,
data.parameters{1}

%% tutorial 2.2
prefix = [filesep 'Users' filesep 'cxy' filesep 'Documents' filesep 'NDI']; % if you put the folder somewhere else, edit this
S = ndi.setup.vhlab('ts_exper2',[prefix filesep 'ts_exper2']);

p_ctx1_list = S.getprobes('name','ctx','reference',1) % returns a cell array of matches
p_ctx1 = p_ctx1_list{1}; % take the first one, should be the only one

epoch_to_read = 1;
[data,t,timeref_p_ctx1]=p_ctx1.readtimeseries(epoch_to_read,-Inf,Inf); % read all data from epoch 1
figure(100);
plot(t,data);
xlabel('Time(s)');
ylabel('Voltage (V)');
set(gca,'xlim',[t(1) t(end)]);
box off;

p_visstim_list = S.getprobes('type','stimulator') % returns a cell array of matches
p_visstim = p_visstim_list{1}; % take the first one, should be the only one
[data,t,timeref_stim]=p_visstim.readtimeseries(timeref_p_ctx1,-Inf,Inf); % read all data from epoch 1 of p_ctx1 !
figure(100);
hold on;
vlt.neuro.stimulus.plot_stimulus_timeseries(7,t.stimon,t.stimoff,'stimid',data.stimid);


%% tutorial 2.3
dirname = [prefix filesep 'ts_exper2']; % change this if you put the example somewhere else
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

%% tutorial 2.4
dirname = [prefix filesep 'ts_exper2']; % change this if you put the example somewhere else
ref = 'ts_exper2';
S = ndi.session.dir(ref,dirname);

% find out stimulus probe
stimprobe = S.getprobes('type','stimulator');
stimprobe = stimprobe{1}; % grab the first one, should be our stimulus monitor

sapp = ndi.app.stimulus.decoder(S);
redo = 1;
[stim_pres_docs] = sapp.parse_stimuli(stimprobe,redo);

stim_pres_docs{1}.document_properties.stimulus_presentation

% these are the fields that were decoded by ndi.app.stimulus.decoder
% let's take a look

 % here is information about the presentation time of the first stimulus
stim_pres_docs{1}.document_properties.stimulus_presentation.presentation_time(1)

 % here is information about the presentation order of the first 10 stimuli shown:

stim_pres_docs{1}.document_properties.stimulus_presentation.presentation_order(1:10)

 % We see that the first stimulus that was presented was stimulus number 4. Let's take a look at its properties:

stim_pres_docs{1}.document_properties.stimulus_presentation.stimuli(4).parameters

 % We can also take a look at the control or blank stimulus properties:

stim_pres_docs{1}.document_properties.stimulus_presentation.stimuli(17).parameters

% you can see that there are 4 such documents, one for each stimulus presentation in the experiment

stim_pres_docs,

rapp = ndi.app.stimulus.tuning_response(S);
cs_doc = rapp.label_control_stimuli(stimprobe,redo);

 % see the control stimulus identifier for all the stimuli
cs_doc{1}.document_properties.control_stimulus_ids.control_stimulus_ids
 % see the method used to identify the control stimulus for each stimulus:
cs_doc{1}.document_properties.control_stimulus_ids.control_stimulus_id_method

 % see the help for the label_control_stimuli function:
help ndi.app.stimulus.tuning_response.label_control_stimuli

e = S.getelements('element.type','spikes');

rdocs{1} = rapp.stimulus_responses(stimprobe, e{1}, redo);
rdocs{2} = rapp.stimulus_responses(stimprobe, e{2}, redo);

%% 2.5 Understanding and searching the NDI database
dirname = [prefix filesep 'ts_exper2']; % change this if you put the example somewhere else
ref = 'ts_exper2';
S = ndi.session.dir(ref,dirname);
stim_pres_doc = S.database_search(ndi.query('','isa','stimulus_presentation',''));
stim_pres_doc{1};
stim_pres_doc{1}.document_properties;
stim_pres_doc{1}.document_properties.document_class;
stim_pres_doc{1}.document_properties.document_class.superclasses(1);
stim_pres_doc{1}.document_properties.document_class.superclasses(2);
stim_pres_doc{1}.document_properties.document_class.superclasses(3);
q_stim = ndi.query('document_class.class_name','contains_string','stim',''); 
stim_docs = S.database_search(q_stim);
q_stim_decoder = ndi.query('app.name','exact_string','ndi_app_stimulus_decoder','');
q_stim_and_stim_decoder_docs = S.database_search(q_stim_decoder & q_stim);

%%
filename = 'special_char.json';
str_doc = fileread(filename); 
bug_document = jsondecode(str_doc); 
[status, response] = ndi.cloud.api.documents.post_documents(dataset_id, bug_document);

%%

[B,MSG] = ndi.database.fun.upload_to_NDI_cloud(S, email, password, dataset_id);
%%
prefix = [filesep 'Users' filesep 'cxy' filesep 'Documents' filesep 'MATLAB' filesep 'data' filesep '2021-04-01'];
