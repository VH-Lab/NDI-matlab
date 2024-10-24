function [stim_pres_doc,spiketimes] = stimulus_presentation(S, stimulus_element_id, parameter_struct, independent_variables, X, R, noise, reps, varargin)
    % ndi.mock.fun.stimulus_presentation - make a mock stimulus presentation document base
    %
    % [STIM_PRES_DOC,SPIKETIMES] = ndi.mock.fun.stimulus_presentation(S, stimulus_element_id, parameter_struct_array, ...
    %    independent_variables, X, R, noise, reps, ...)
    %
    % Create a mock stimulus presentation document and spike times that approximate the
    % responses R as closely as possible (within the stimulus duration bounds).
    % If necessary, the time of each stimulus presentation is adjusted to allow a more
    % accurate representation of the requested firing rate.
    %
    % S is the NDI session that the stimulator is a part of
    % STIMULUS_ELEMENT_ID is the id of a mock stimulator element.
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
    % | epochid ('mockepoch')              | The name of the stimulator epoch that is created.       |
    % |------------------------------------|---------------------------------------------------------|
    %
    % Example:
    %    stimulator_id = '12345'; % just for the example
    %    param_struct = struct('spatial_frequency',0.5);
    %    independent_variable = {'contrast'};
    %    X = [ 0 ; 0.5 ; 1];
    %    R = [ 0 ; 2 ; 4]; % spikes/sec
    %    noise = 0;
    %    reps = 1;
    %    stim_pres_doc = ndi.mock.fun.stimulus_presentation(stimulator_id,param_struct,independent_variable,X,R,noise,reps);
    %    disp(['Displaying stimulus parameters']);
    %    for i=1:size(X,1), stim_pres_doc.document_properties.stimulus_presentation.stimuli(i).parameters, end;
    %
    %

    stim_duration = 10;
    interstimulus_interval = 5;
    stim_duration_min = 0.2;
    epochid = 'mockepoch';
    t_eps = 1e-4; % time epsilon, make sure we stay within the edges of the stimulus

    vlt.data.assign(varargin{:});

    stimulus_N = size(X,1);
    stims = vlt.data.colvec(1:stimulus_N);

    stim_pres_struct.presentation_order = [ repmat([stims],reps,1) ];
    presentation_time = vlt.data.emptystruct('clocktype','stimopen','onset','offset','stimclose','stimevents');
    stim_pres_struct.stimuli = vlt.data.emptystruct('parameters');

    for i=1:stimulus_N,
        stim_params_here = parameter_struct;

        for j=1:size(X,2), % go over each column
            if isnan(X(i,j)),
                stim_params_here = setfield(stim_params_here,'isblank',1);
            else,
                stim_params_here = setfield(stim_params_here,independent_variables{j},X(i,j));
            end;
        end;
        stim_pres_struct.stimuli(i).parameters = stim_params_here;
    end;

    spiketimes = [];

    for i=1:numel(stim_pres_struct.presentation_order),
        pt_here = vlt.data.emptystruct(fieldnames(presentation_time));
        pt_here(1).clocktype = 'utc';
        pt_here(1).stimopen = i * (stim_duration+interstimulus_interval);
        pt_here(1).onset    = pt_here(1).stimopen;

        % now see how many spikes to fire for this stimulus
        stimid = stim_pres_struct.presentation_order(i);
        R_here = R(stimid) + noise * randn * R(stimid);
        if ~isnan(R_here) & (R_here>0),
            n_spikes_mean = R_here * stim_duration;
            n_spikes_floor = floor( n_spikes_mean );
            n_spikes_ceil = ceil( n_spikes_mean );
            deltat_floor = stim_duration - (n_spikes_floor/R_here);
            deltat_ceil = stim_duration - (n_spikes_ceil/R_here);
            stim_duration_here_floor = max(stim_duration_min, min(stim_duration+interstimulus_interval, stim_duration-deltat_floor));
            stim_duration_here_ceil = max(stim_duration_min, min(stim_duration+interstimulus_interval, stim_duration-deltat_ceil));
            if abs(n_spikes_floor/stim_duration_here_floor - R_here) < abs(n_spikes_ceil/stim_duration_here_ceil - R_here),
                n_spikes = n_spikes_floor;
                stim_duration_here = stim_duration_here_floor;
            else,
                n_spikes = n_spikes_ceil;
                stim_duration_here = stim_duration_here_ceil;
            end;
            spiketimes=cat(1,spiketimes,...
                vlt.data.colvec(linspace(pt_here(1).onset+t_eps,pt_here(1).onset+stim_duration_here-t_eps,n_spikes)));
        else,
            stim_duration_here = stim_duration;
        end;

        pt_here(1).offset   = pt_here(1).onset + stim_duration_here;
        pt_here(1).stimclose = pt_here(1).offset;
        presentation_time(i,1) = pt_here;
    end;

    epochid_struct.epochid = epochid;

    stim_pres_doc = ndi.document('stimulus_presentation','stimulus_presentation',stim_pres_struct,'epochid',epochid_struct) + S.newdocument();
    stim_pres_doc = stim_pres_doc.set_dependency_value('stimulus_element_id',stimulus_element_id);

    presentation_time_filename = ndi.file.temp_name();
    ndi.database.fun.write_presentation_time_structure(presentation_time_filename,...
        presentation_time);

    stim_pres_doc = stim_pres_doc.add_file('presentation_time.bin',presentation_time_filename);
