function pyraview_doc = makePyraviewDoc(probe, epochid, filterband, options)
    % MAKEPYRAVIEWDOC - create a pyraview document for a probe and epoch
    %
    % PYRAVIEW_DOC = ndi.app.makePyraviewDoc(PROBE, EPOCHID, FILTERBAND, ...)
    %
    % Inputs:
    %   PROBE: An ndi.probe object
    %   EPOCHID: The epoch identifier string
    %   FILTERBAND: 'low' or 'high'
    %
    % Optional Parameters:
    %   chunkDuration (default 50)
    %   chunkExcess (default 1)
    %
    arguments
        probe (1,1) {mustBeA(probe, 'ndi.probe')}
        epochid (1,:) char
        filterband (1,:) char {mustBeMember(filterband, {'low', 'high'})}
        options.chunkDuration (1,1) double = 50
        options.chunkExcess (1,1) double = 1
    end

    % 1. Get Epoch Information and check for 'dev_local_time'
    et = probe.epochtable();
    match_idx = find(strcmp({et.epoch_id}, epochid), 1);
    if isempty(match_idx)
        error(['Epoch ' epochid ' not found in probe ' probe.elementstring()]);
    end
    epoch_entry = et(match_idx);

    % Check for 'dev_local_time'
    has_dev_local_time = false;
    t0 = 0;
    t1 = 0;

    % epoch_clock is a cell array of clocktypes
    for i = 1:numel(epoch_entry.epoch_clock)
        if strcmp(epoch_entry.epoch_clock{i}.type, 'dev_local_time')
            has_dev_local_time = true;
            t0 = epoch_entry.t0_t1{i}(1);
            t1 = epoch_entry.t0_t1{i}(2);
            break;
        end
    end

    if ~has_dev_local_time
        error('Epoch does not have ''dev_local_time'' clock type.');
    end

    % 2. Get Sampling Rate
    sr = probe.samplerate(epochid);

    % 3. Filter Logic moved to filterData call inside loop,
    % but we need filterStruct for metadata.
    % We can call filterData with dummy data to get struct
    [~, filterStruct] = ndi.gui.app.pyraview.filterData([0], sr, filterband);

    % 4. Prepare for Processing
    temp_dir = tempname;
    mkdir(temp_dir);
    [~, probe_name_clean] = fileparts(tempname); % get a random unique string
    prefix = fullfile(temp_dir, ['pyraview_' probe_name_clean]);

    steps = [100 10 10 10 10 10 10]; % Decimation steps
    nativeRate = sr;
    append = true;

    % Initialize Progress Bar
    pb_fig = figure('Name', 'Pyraview Progress', 'NumberTitle', 'off', 'MenuBar', 'none', ...
                    'ToolBar', 'none', 'Resize', 'off', 'Position', [500 500 520 80]);
    % Pass Name-Value arguments directly, NOT as a struct
    pb = ndi.gui.component.NDIProgressBar('Parent', pb_fig, ...
        'Message', 'Initializing...', 'Text', 'Starting data processing...');

    % 5. Loop and Process Chunks
    chunk_dur = options.chunkDuration;
    excess = options.chunkExcess;

    current_t = t0;

    % Initialize data_central size for metadata
    data_channels = 0;

    total_dur = t1 - t0;
    if total_dur <= 0, total_dur = 1; end

    cleanupObj = onCleanup(@() delete(pb_fig));

    while current_t < t1
        % Update Progress
        progress = (current_t - t0) / total_dur;
        pb.Value = progress;
        pb.Message = sprintf('Processing %.1f%%...', progress * 100);
        drawnow;

        % Define read times with excess
        t_read_start = current_t - excess;
        t_read_end = current_t + chunk_dur + excess;

        % Read data
        % probe.readtimeseries(epochid, t0, t1)
        data = probe.readtimeseries(epochid, t_read_start, t_read_end);

        if ~isempty(data)
             % Filter data using new function
             [data, ~] = ndi.gui.app.pyraview.filterData(data, sr, filterband);

             if data_channels == 0
                 data_channels = size(data, 2);
             end

             % Calculate actual start time of data
             % readtimeseries typically clamps to valid range [t0, t1]
             data_start_time = max(t0, t_read_start);

             % We want central portion corresponding to [current_t, current_t + chunk_dur]
             % Calculate time offset from start of data
             offset_start = current_t - data_start_time;
             offset_end = (current_t + chunk_dur) - data_start_time;

             % Convert to samples
             % If offset is negative, it means we want data before what we have (shouldn't happen if logic is sound)
             % If offset is positive, we trim from beginning

             start_idx = round(offset_start * sr) + 1;
             end_idx = round(offset_end * sr);

             % Clamp indices
             if start_idx < 1, start_idx = 1; end
             if end_idx > size(data, 1), end_idx = size(data, 1); end

             if start_idx <= end_idx
                 data_central = data(start_idx:end_idx, :);

                 %try
                     pyraview.pyraview(data_central, prefix, steps, nativeRate, t0, append);
                 %catch mex_err
                 %    warning(['Pyraview MEX failed: ' mex_err.message]);
                 %end
             end
        end

        current_t = current_t + chunk_dur;
    end

    pb.Value = 1;
    pb.Message = 'Completed.';
    drawnow;

    % 6. Create Document
    % Create an ndi.document of type 'pyraview'

    epochidStruct.epochid = epochid;
    pyraviewStruct.label = filterband;
    pyraviewStruct.nativeRate = sr;
    pyraviewStruct.nativeStartTime = t0;
    pyraviewStruct.channels = data_channels;
    pyraviewStruct.dataType = 'double';
    pyraviewStruct.decimationLevels = steps;
    pyraviewStruct.decimationSamplingRates = sr ./ cumprod(pyraviewStruct.decimationLevels);
    pyraviewStruct.decimationStartTimes = t0*ones(numel(pyraviewStruct.decimationLevels),1);

    epochclocktimesStruct.clocktype='dev_local_time';
    epochclocktimesStruct.t0_t1 = [t0;t1];

    pyraview_doc = ndi.document('pyraview', 'pyraview', pyraviewStruct, ...
      'epochid', epochidStruct, 'filter', filterStruct, ...
      'epochclocktimes', epochclocktimesStruct) + probe.session.newdocument();
    pyraview_doc = pyraview_doc.set_dependency_value('element_id', probe.id());
    % to do: must add files here, e.g.
    for i=1:numel(steps)
        pyraview_doc = pyraview_doc.add_file(['level' int2str(i) '.bin'],[prefix '_L' int2str(i) '.bin']);
    end

    % Add to database
    probe.session.database_add(pyraview_doc);
end
