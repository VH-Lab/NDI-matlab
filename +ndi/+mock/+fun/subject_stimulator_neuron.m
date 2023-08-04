function [output] = subject_stimulator_neuron(ndi_session_obj)
% ndi.mock.fun.subject_stimulator_neuron - create a mock subject, stimulator, and neuron set
%
% OUTPUT = ndi.mock.fun.subject_stimulator_neuron(NDI_SESSION_OBJ)
%
% Creates a mock subject, a mock stimulator, a mock stimulus presentation,
% and mock spiking neuron with responses as specified.
% OUTPUT is a structure with fields discussed below.
%
% OUTPUT.refNum: a random reference number, used in the name and reference of the
% mock subject and the mock stimulator and mock spike object.
% 
% OUTPUT.mock_subject: Attempts to find or create a mock subject called
%    'mockREFNUM@nosuchlab.org'. An NDI_document is returned in field mock_subject.  
% 
% OUTPUT.mock_stimulator: Attempts to find or create a stimulator with name 
%    'mock stimulator' and pseudorandom reference. An NDI_document is returned in
%    field mock_stimulator.
%
% OUTPUT.mock_spikes: Mock spiking neuron NDI_document (of type
%   (ndi.element.timeseries with name 'mock spikes', a pseduorandom reference, type 'spikes')
%

S = ndi_session_obj; % shorten the name so it's easier to work with

 % Step 0:

refNum = ndi.fun.pseudorandomint();

 % Step 1: set up mock subject

ms = ndi.subject(['mock' int2str(refNum) '@nosuchlab.org'],'A mock subject for testing purposes');
subdoc = ms.newdocument();
subdoc_id = subdoc.id();
S.database_add(subdoc);

output.mock_subject = subdoc;

 % Step 2 and 3: make our stimulator object and spiking neuron object

nde_stimulator = ndi.element.timeseries(S,'mock stimulator',refNum,'stimulator',[],0,subdoc_id);
output.mock_stimulator = nde_stimulator;

nde = ndi.element.timeseries(S,'mock spikes',refNum,'spikes',[],0,subdoc_id);
output.mock_spikes = nde;

return;

% leave this here to read

% Step 4: make the stimuli

  % stimulus presentation document

stimulus_presentation_struct = struct([]);
stimulus_N = size(X,2);
stims = 1:stimulus_N;

stim_pres_struct.presentation_order = [ repmat([stims]',n_reps,1) ];
presentation_time = vlt.data.emptystruct('clocktype','stimopen','onset','offset','stimclose','stimevents');
stim_pres_struct.stimuli = emptystruct('parameters');



t = vlt.data.colvec([ 1:10]);

nde.addepoch('mockepoch',ndi.time.clocktype('UTC'), [0 100], t, ones(size(t)) );

[data,t,timeref] = nde.readtimeseries('mockepoch',-Inf,Inf);



nde_stimulator.addepoch('mockepoch',ndi.time.clocktype('UTC'),[0 100], [], []);

 % let's say we have 10 stimuli, repeated 5 times each, with no noise, with a control stimulus (so total 11 stimuli)

stims = 1:11;
n_reps = 5;

stim_onset_multiplier = 5;
stim_duration = 2;

parameters = {'Contrast'};
values{1} = [0.1:0.1:1 ];
add_blank = 1;

stim_pres_struct.presentation_order = [ repmat([stims]',n_reps,1) ];
presentation_time = vlt.data.emptystruct('clocktype','stimopen','onset','offset','stimclose','stimevents');
stim_pres_struct.stimuli = emptystruct('parameters');

for i=1:numel(stim_pres_struct.presentation_order),
	pt_here = vlt.data.emptystruct(fieldnames(stim_pres_struct.presentation_time));
	pt_here(1).clocktype = 'utc';
	pt_here(1).stimopen = i * 5;
	pt_here(1).onset    = pt_here(1).stimopen;
	pt_here(1).offset   = pt_here(1).onset + stim_duration;
	pt_here(1).stimclose = pt_here(1).offset;
	presentation_time(i,1) = pt_here;
end;

for i=1:numel(values{1}),
	stimulus_here = emptystruct('parameters');
	for j=1:numel(parameters),
		eval(['stimulus_here(1).parameters.' parameters{j} '=values{1}(i);']);
	end;
	stim_pres_struct.stimuli(end+1,1) = stimulus_here;
end;

if add_blank,
	stim_pres_struct.stimuli(end+1,1) = struct('parameters',struct('isblank',1));
end;

