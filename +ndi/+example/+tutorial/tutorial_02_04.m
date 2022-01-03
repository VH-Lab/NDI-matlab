function tutorial_02_04(prefix, testing)
% ndi.example.tutorials.tutorial_02_04 - runs the code in Tutorial 2.4
%
% out = ndi.example.tutorials.tutorial_02_04(PREFIX, [TESTING])
%
% Runs (and tests) the code for 
%
% NDI Tutorial 2: Analzying your first electrophysiology experiment with NDI
%    Tutorial 2.4: Analyzing stimulus responses
% The tutorial is available at 
%     https://vh-lab.github.io/NDI-matlab/tutorials/analyzing_first_physiology_experiment/4_analyzing_tuning_curves/
%
% PREFIX should be the directory that contains the directory 'ts_exper2'. If it is not
% provided or is empty, the default is [userpath filesep 'Documents' filesep 'NDI'].
%
% If TESTING is 1, then the files are examined in the temporary directory ndi_globals.path.temppath (use
% ndi.globals() to make this variable available for inspection). It is assumed that
% ndi.example.tutorial.tutorial_t02_03([],1) has been run (with TESTING set to 1).
%
%

if nargin<1 | isempty(prefix),
	prefix = [userpath filesep 'Documents' filesep 'NDI']; % or '/Users/yourusername/Desktop/' if you put it on the desktop perhaps
end;

if nargin<2,
	testing = 0;
end;

tutorial_dir = 'ts_exper2';

if testing, % copy the files to the temp directory
	ndi.globals() 
	prefix = ndi_globals.path.temppath;
	disp(['Assuming clean data files ts_exper2 are in ' prefix '.']);
end

 % Code block 2.4.1.1
disp(['Code block 2.4.1.1:']);

dirname = [prefix filesep 'ts_exper2']; % differs from manual tutorial
ref = 'ts_exper2';
S = ndi.setup.vhlab(ref,dirname);  

% let's find our probes that correspond to extracellular electrodes

% find out stimulus probe
stimprobe = S.getprobes('type','stimulator');
stimprobe = stimprobe{1}; % grab the first one, should be our stimulus monitor

 % Code block 2.4.2.1
disp(['Code block 2.4.2.1:']);

sapp = ndi.app.stimulus.decoder(S);
redo = 1;
[stim_pres_docs] = sapp.parse_stimuli(stimprobe,redo);

 % Code block 2.4.2.2
disp(['Code block 2.4.2.2:']);

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


 % Code block 2.4.3.1
disp(['Code block 2.4.3.1:']);

rapp = ndi.app.stimulus.tuning_response(S);
cs_doc = rapp.label_control_stimuli(stimprobe,redo);

 % Code block 2.4.3.2
disp(['Code block 2.4.3.2:']);

 % see the control stimulus identifier for all the stimuli
cs_doc{1}.document_properties.control_stimulus_ids.control_stimulus_ids
 % see the method used to identify the control stimulus for each stimulus:
cs_doc{1}.document_properties.control_stimulus_ids.control_stimulus_id_method

 % see the help for the label_control_stimuli function:
help ndi.app.stimulus.tuning_response.label_control_stimuli

 % Code block 2.4.4.1
disp(['Code block 2.4.4.1:']);

e = S.getelements('element.type','spikes');

rdocs{1} = rapp.stimulus_responses(stimprobe, e{1}, redo);
rdocs{2} = rapp.stimulus_responses(stimprobe, e{2}, redo);

 % Code block 2.4.4.2
disp(['Code block 2.4.4.2:']);

 % look at rdocs{1}:
rdocs{1}
 % it is a 1x2 cell array, and each of these cell entries is in turn a 1x3 cell array
rdocs{1}{1}
 % this reflects the two epochs ('t00001' and 't00002'), and, for each epoch, the analysis of the mean response, the F1 component, and the F2 component

 % to see this, let's look at the first document

rdocs{1}{1}{1}.document_properties
rdocs{1}{1}{1}.document_properties.stimulus_response

rdocs{1}{1}{1}.document_properties.stimulus_response_scalar
 % we see that this is the 'mean' response. We can see the responses contained within:

rdocs{1}{1}{1}.document_properties.stimulus_response_scalar.responses
 % we can see that each of the 85 presentations includes a response that can possibly have a real and imaginary component, as well as a control response

rdocs{1}{1}{1}.document_properties.stimulus_response_scalar.responses.response_real(1)
rdocs{1}{1}{1}.document_properties.stimulus_response_scalar.responses.control_response_real(1)

 % Code block 2.4.5.1
disp(['Code block 2.4.5.1:']);

oapp = ndi.app.oridirtuning(S);

for i=1:2,
    tdoc{i} = oapp.calculate_all_tuning_curves(e{i},'Replace'); % replace any existing 
    oriprops{i} = oapp.calculate_all_oridir_indexes(e{i},'Replace'); % this takes a few minutes
end;

 % Code block 2.4.5.2
disp(['Code block 2.4.5.2:']);

  % see all the categories
oriprops{1}{1}{1}.document_properties.orientation_direction_tuning
  % see the property information
oriprops{1}{1}{1}.document_properties.orientation_direction_tuning.properties
  % see significance. Responses across orientation are very significant:
oriprops{1}{1}{1}.document_properties.orientation_direction_tuning.significance
  % fit parameters:
oriprops{1}{1}{1}.document_properties.orientation_direction_tuning.fit
  % vector tuning parameters:
oriprops{1}{1}{1}.document_properties.orientation_direction_tuning.vector

