function [output] = subject_stimulator_neuron(ndi_session_obj)
    % ndi.mock.fun.subject_stimulator_neuron - create a mock subject, stimulator, and neuron set
    %
    % OUTPUT = ndi.mock.fun.subject_stimulator_neuron(NDI_SESSION_OBJ)
    %
    % Creates a mock subject, a mock stimulator, a mock stimulus presentation,
    % and mock spiking neuron with responses as specified.
    % OUTPUT is a structure with fields discussed below.
    %
    % OUTPUT.refNum: a reference number, used in the name and reference of the
    % mock subject and the mock stimulator and mock spike object. It is drawn at
    % random and checked against the session, so that repeated calls on one
    % session never reuse a number. See the note at pickFreeReference below.
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

    arguments
        ndi_session_obj (1,1) ndi.session
    end

    S = ndi_session_obj; % shorten the name so it's easier to work with

    % Step 0:

    refNum = pickFreeReference(S);
    output.refNum = refNum; % documented above, but never returned until now

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

    for i=1:numel(stim_pres_struct.presentation_order)
        pt_here = vlt.data.emptystruct(fieldnames(stim_pres_struct.presentation_time));
        pt_here(1).clocktype = 'utc';
        pt_here(1).stimopen = i * 5;
        pt_here(1).onset    = pt_here(1).stimopen;
        pt_here(1).offset   = pt_here(1).onset + stim_duration;
        pt_here(1).stimclose = pt_here(1).offset;
        presentation_time(i,1) = pt_here;
    end

    for i=1:numel(values{1})
        stimulus_here = emptystruct('parameters');
        for j=1:numel(parameters)
            eval(['stimulus_here(1).parameters.' parameters{j} '=values{1}(i);']);
        end
        stim_pres_struct.stimuli(end+1,1) = stimulus_here;
    end

    if add_blank
        stim_pres_struct.stimuli(end+1,1) = struct('parameters',struct('isblank',1));
    end

end % subject_stimulator_neuron()

function refNum = pickFreeReference(S)
    % PICKFREEREFERENCE - a mock reference number not already used in this session
    %
    % An ndi.element is identified by its name, type and reference, so two mock
    % elements drawn with the same reference are one element. The second call
    % then adds a second epoch named 'mockepoch' to it, and reading that epoch
    % fails: epochtableentry returns two entries and the caller indexes it as
    % one. This is what happens when several mocks are made in a session
    % without clearing in between, as when a calculator regenerates all of its
    % stored self-test expectations in one go.
    %
    % The number was previously drawn from a span of 1000 with no check, which
    % collides about one time in five over 22 draws. Drawing is still random
    % rather than sequential, so that routines running in parallel on separate
    % sessions do not march in step; the check is what makes it safe.
    %
    % The reference field of an element document is an integer bounded by
    % element_schema.json at 100000, so the span stays well inside that.

    arguments
        S (1,1) ndi.session
    end

    referenceMin = 20000;
    referenceSpan = 60000;
    maxAttempts = 100;

    for attempt = 1:maxAttempts
        candidate = referenceMin + randi(referenceSpan);
        if ~mockReferenceInUse(S, candidate)
            refNum = candidate;
            return;
        end
    end

    error('ndi:mock:subject_stimulator_neuron:noFreeReference',...
        ['Could not find an unused mock reference number in %d attempts, over the range '...
        '%d to %d. The session appears to be full of mock documents; '...
        'ndi.mock.fun.clear removes them.'],...
        maxAttempts, referenceMin+1, referenceMin+referenceSpan);

end % pickFreeReference()

function b = mockReferenceInUse(S, refNum)
    % MOCKREFERENCEINUSE - does this session already hold a mock at this reference?
    %
    % Checks the subject as well as the two elements, because the subject name
    % carries the number too and a leftover subject would produce a second mock
    % subject with the same name.

    arguments
        S (1,1) ndi.session
        refNum (1,1) double
    end

    b = true;

    q = ndi.query('subject.local_identifier','exact_string',...
        ['mock' int2str(refNum) '@nosuchlab.org'],'');
    if ~isempty(S.database_search(q))
        return;
    end

    elementNames = {'mock stimulator','mock spikes'};
    for i = 1:numel(elementNames)
        q = ndi.query('element.name','exact_string',elementNames{i},'') & ...
            ndi.query('element.reference','exact_number',refNum,'');
        if ~isempty(S.database_search(q))
            return;
        end
    end

    b = false;

end % mockReferenceInUse()
