function [docs] = stimulus_response(S, parameter_struct, independent_variables, X, R, noise, reps, options)
    % ndi.mock.fun.stimulus_response- make a set of mock documents to simulate a stimulus and spiking response
    %
    % [DOCS] = ndi.mock.fun.stimulus_presentation(ndi_session_obj, parameter_struct, ...
    %    independent_variables, X, R, noise, reps, ...)
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
    % | stim_duration_min (0.2)            | Minimum duration of a mock stimulus presentation        |
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

    arguments
        S (1,1) ndi.session
        parameter_struct (1,:) struct
        independent_variables (1,:) cell
        X (:,:) double
        R (:,1) double
        noise (1,1) double
        reps (1,1) double
        options.stim_duration (1,1) double = 2
        options.interstimulus_interval (1,1) double = 3
        options.stim_duration_min (1,1) double = 0.2
        options.epochid (1,:) char = 'mockepoch'
    end

    mock_output = ndi.mock.fun.subject_stimulator_neuron(S);

    % Convert options to name-value pairs for forwarding
    fn = fieldnames(options);
    vals = struct2cell(options);
    nv_pairs = [fn(:)'; vals(:)'];
    nv_pairs = nv_pairs(:)';

    [stim_pres_doc,spiketimes] = ndi.mock.fun.stimulus_presentation(S,mock_output.mock_stimulator.id(),...
        parameter_struct, independent_variables, X, R, noise, reps, nv_pairs{:});

    S.database_add(stim_pres_doc);

    decoder = ndi.app.stimulus.decoder(S);

    presentation_time = decoder.load_presentation_time(stim_pres_doc);

    end_time = presentation_time(end).stimclose + 5;

    t0_t1_matrix = [ [0 end_time]' [0 end_time]'];
    mock_output.mock_spikes.addepoch('mockepoch','dev_local_time,utc', t0_t1_matrix, ...
        spiketimes, ones(size(spiketimes)) );

    % add a blank epoch so that the stimulator has an epoch to connect with stim_pres_doc
    mock_output.mock_stimulator.addepoch('mockepoch','dev_local_time,utc', t0_t1_matrix, ...
        [], [] );

    stimulator_doc = mock_output.mock_stimulator.load_element_doc();
    spikes_doc = mock_output.mock_spikes.load_element_doc();

    r_app = ndi.app.stimulus.tuning_response(S);

    control_stim_doc = r_app.label_control_stimuli(mock_output.mock_stimulator);
    stim_response_doc = r_app.stimulus_responses(mock_output.mock_stimulator, mock_output.mock_spikes,0,1);

    tc = ndi.calc.stimulus.tuningcurve(S);
    tc_docs = {};

    parameters.input_parameters.independent_label = independent_variables;
    parameters.input_parameters.independent_parameter = independent_variables;
    parameters.input_parameters.best_algorithm = 'empirical_maximum';
    parameters.input_parameters.selection = struct('property',independent_variables{1},'operation','hasfield','value','varies'); %what to do if multiple independent variables?
    I = tc.search_for_input_parameters(parameters);

    for i=1:numel(stim_response_doc)
        for j=1:numel(stim_response_doc{i})
            parameters.input_parameters.depends_on = struct('name','stimulus_response_scalar_id','value',stim_response_doc{i}{j}.id());
            parameters.depends_on = did.datastructures.emptystruct('name','value');
            tc_docs{end+1} = tc.run('Replace',parameters);
        end
    end

    docs = { mock_output.mock_subject stimulator_doc spikes_doc stim_pres_doc control_stim_doc stim_response_doc{1}{:} tc_docs{1}{:} };
