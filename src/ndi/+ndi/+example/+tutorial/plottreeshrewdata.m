function plottreeshrewdata(filename, varargin)
    % ndi.example.tutorial.plottreeshrewdata - plot tree shrew data from Van Hooser et al. 2014
    %
    % ndi.example.tutorial.plottreeshrewdata(filename)
    %
    %
    % This function also accepts additional arguments in the form of name/value pairs
    % (see help NAMEVALUEPAIR)
    % -------------------------------------------------------------------------------
    % | Property (default)       | Description                                      |
    % | ------------------------ | ------------------------------------------------ |
    % | electrodeChannel (11)    | Channel with the electrode recording             |
    % | stimTriggerChannel (2)   | Channel with the stimulus trigger record         |
    % | syncChannel (4)          | Channel with the synchronizing information       |
    % | stimCodeMarkChannel (32) | Channel with stimulus code mark information      |
    % | timeWindow ([0 100])     | Time window to show initially in graph           |
    % | ePhysYRange ([-11 11])   | ePhys Y range                                    |
    % | ePhysYStimLabel (7)      | Y location for stimulus code type plot           |
    % | syncYRange ([0 8])       | stimSync Y range                                 |
    % | syncYStimLabel (7)       | Y location for stimulus code type plot           |
    % | stimDuration (2))        | Stimulus duration in seconds                     |
    % | fig ([])                 | The figure to use. If empty, make a new one      |
    % | verbose (1)              | Should we print status messages?                 |
    % | plotit (1)               | Plot the data                                    |
    % | plotstimsync (0)         | Plot a graph of the stimSync data                |
    % | title_string ('')        | Plot title string                                |
    % |-----------------------------------------------------------------------------|
    %

    electrodeChannel = 11;
    stimTriggerChannel = 2;
    syncChannel = 4;
    stimCodeMarkChannel = 30;
    timeWindow = [0 100];
    ePhysYRange = [-11 11];
    ePhysYStimLabel = 7;
    syncYRange = [0 8];
    syncYStimLabel = 7;
    stimDuration = 2;
    fig = [];
    verbose = 1;
    plotit = 1;
    plotstimsync = 0;
    title_string = '';

    ndr.data.assign(varargin{:});

    r = ndr.reader('smr');

    if verbose
        disp(['Reading ePhys data...']);
    end

    eData = r.readchannels_epochsamples('ai',electrodeChannel,{filename},1,-Inf,Inf);
    eTime = r.readchannels_epochsamples('time',electrodeChannel,{filename},1,-Inf,Inf);

    if verbose
        disp(['Reading stimulus trigger information...']);
    end

    stimTriggers = r.readevents_epochsamples('event', stimTriggerChannel, {filename}, 1, -Inf, Inf);
    stimTriggers = stimTriggers(1:2:end,:); % for this data, 2 triggers per stimulus
    [stimCodes_time,stimCodes_text] = r.readevents_epochsamples('text', stimCodeMarkChannel, {filename}, 1, -Inf, Inf);
    stimCodes_value = [];
    for i=1:size(stimCodes_text,1)
        stimCodes_value(i,1) = str2num(stimCodes_text(i,:));
    end

    scData = [];
    scTime = [];

    if plotstimsync
        if verbose
            disp(['Reading stimulus video frame sync information...']);
        end
        scData = r.readchannels_epochsamples('ai',syncChannel, {filename},1,-Inf,Inf);
        scTime = r.readchannels_epochsamples('time',syncChannel, {filename},1,-Inf,Inf);
    end

    if ~plotit % if we aren't plotting, just stop
        return;
    end

    if isempty(fig)
        fig = figure;
    end

    figure(fig); % bring this figure to the front, if necessary

    if plotstimsync
        ax_ephys = axes('units','normalized','position',[0.10 0.4 0.8 0.5]);
    else
        ax_ephys = axes;
    end
    plot(eTime,eData);
    box off;
    ylabel('Potential (Volts)');
    set(ax_ephys,'xlim',timeWindow,'ylim',ePhysYRange);
    hold on;
    vlt.neuro.stimulus.plot_stimulus_timeseries(ePhysYStimLabel,stimCodes_time,stimCodes_time+stimDuration,'stimid',stimCodes_value);
    pan on;
    title(title_string);

    if plotstimsync
        ax_sync = axes('units','normalized','position',[0.10 0.1 0.8 0.2]);
        plot(scTime,scData);
        set(ax_sync,'xlim',timeWindow,'ylim',syncYRange);
        box off;
        ylabel('Potential (Volts)');
        hold on;
        vlt.neuro.stimulus.plot_stimulus_timeseries(syncYStimLabel,stimCodes_time,stimCodes_time+stimDuration,'stimid',stimCodes_value);
        pan on;

        linkaxes([ax_ephys ax_sync],'x');
    else
        ax_sync = [];
    end
