function [docs] = stimulus_response(S, parameter_struct, independent_variables, X, R, noise, reps, varargin)
% ndi.mock.fun.stimulus_response- make a set of mock documents to simulate a stimulus and spiking response
%
% [DOCS] = ndi.mock.fun.stimulus_presentation(ndi_session_obj, parameter_struct, ...
%    independent_variables, X, R, control, noise, reps, ...)
%
% Create a mock subject, mock stimulator, mock neuron with response, and
% mock stimulus presentation document that approximates the responses R
% responses R as closely as possible (within the stimulus duration bounds).
% If necessary, the time of each stimulus presentation is adjusted to allow a more
% accurate representation of the requested firing rate.
%
% PARAMETER_STRUCT should be a structure that has the base parameters
%   that are common to all of the stimuli in the group.
% INDEPENDENT_VARIABLES is a cell array of strings that are the names of the parameters that
%   vary in the list of stimuli.
% X is a vector of the values of the INDEPENDENT_VARIABLES. Each column
%   should have the value for each entry in INDEPENDENT_VARIABLES. NaN
%   can be used to indicate control stimuli (aka blank stimuli).
% R is a vector of the responses to each stimulus. It should have the same
%   number of rows as X.
% NOISE is a scalar that indicates how much noise with mean 0 and standard deviation
%   equal to the value of R should be added to the stimulus response on each trial.
%   0 indicates no noise should be added, 1 indicates that the standard deviation
%   of the noise to be added should be 1 * the value of the response, etc.
% REPS is the number of times to repeat each stimulus.
%
% This function takes additional arguments as NAME/VALUE pairs:
%
% |------------------------------------|---------------------------------------------------------|
% | Parameter (default)                | Description                                             |
% |------------------------------------|---------------------------------------------------------|
% | stim_duration (2)                  | Duration of each mock stimulus                          |
% | stim_duration_min (0.2)            | Minumum duration of a mock stimulus presentation        |
% |                                    |   (set so that firing rate can be matched)              |
% | interstimulus_interval(3)          | Interstimulus interval                                  |
% |------------------------------------|---------------------------------------------------------|
%
% Example:
%    % if S is an ndi.session object
%    param_struct = struct('spatial_frequency',0.5);
%    independent_variable = {'contrast'};
%    X = [ 0 ; 0.5 ; 1];
%    R = [ 0 ; 2 ; 4]; % spikes/sec
%    noise = 0;
%    reps = 1;
%    docs = ndi.mock.fun.stimulus_response(S,param_struct, independent_variable, X, R, noise, reps);
%

mock_output = ndi.mock.fun.subject_stimulator_neuron(S);
[stim_pres_doc,spiketimes] = ndi.mock.fun.stimulus_presentation(mock_output.mock_subject.id(),...
	parameter_struct, independent_variables, X, R, noise, reps);

end_time = stim_pres_doc.document_properties.stimulus_presentation.presentation_time(end).stimclose + 5;

mock_output.mock_spikes.addepoch('mockepoch',ndi.time.clocktype('UTC'), [0 end_time], ...
	spiketimes, ones(size(spiketimes)) );

stimulator_doc = mock_output.mock_stimulator.load_element_doc();
spikes_doc = mock_output.mock_spikes.load_element_doc();

docs = { mock_output.mock_subject stimulator_doc spikes_doc stim_pres_doc };
