function [tVec, dataOut, level] = getData(probe, doc, t0, t1, pixelSpan, options)
% GETDATA - Retrieve data from a pyraview document using NDI binary doc methods
%
%   [TVEC, DATAOUT, LEVEL] = ndi.gui.app.pyraview.getData(PROBE, DOC, T0, T1, PIXELSPAN, ...)
%
%   Inputs:
%       PROBE     - An ndi.probe object.
%       DOC       - An ndi.document object of type 'pyraview'.
%       T0        - Start time of the display window.
%       T1        - End time of the display window.
%       PIXELSPAN - Width of the display window in pixels.
%
%   Optional Parameters:
%       readExcess - Amount of time (in seconds) to read before/after requested range for filtering (Level 0 only). Default 1.0.
%
%   Outputs:
%       TVEC      - Time vector of the retrieved data.
%       DATAOUT   - Data matrix (Samples x Channels) or (Samples x Channels x 2).
%       LEVEL     - The decimation level used (0 for raw, >0 for decimated).
%

    arguments
        probe (1,1)
        doc (1,1)
        t0 (1,1) double
        t1 (1,1) double
        pixelSpan (1,1) double
        options.readExcess (1,1) double = 1.0
    end

    % Ensure types
    assert(isa(probe, 'ndi.probe'), 'Input probe must be an ndi.probe object.');
    assert(isa(doc, 'ndi.document'), 'Input doc must be an ndi.document object.');

    % 1. Calculate delta and read range
    delta = t1 - t0;
    read_t0 = t0 - delta;
    read_t1 = t1 + delta;

    % 2. Extract Pyraview Properties
    if ~isfield(doc.document_properties, 'pyraview')
        error('Document is not a valid pyraview document.');
    end
    pv = doc.document_properties.pyraview;

    % Prepare Files list based on decimation levels
    % Assuming file names follow pattern 'levelN.bin' where N is index
    numLevels = numel(pv.decimationLevels);
    fileList = cell(1, numLevels);
    for i = 1:numLevels
        fileList{i} = ['level' int2str(i) '.bin'];
    end

    % Handle decimationStartTime naming difference
    if isfield(pv, 'decimationStartTimes')
        decStartTimes = pv.decimationStartTimes;
    elseif isfield(pv, 'decimationStartTime')
        decStartTimes = pv.decimationStartTime;
    else
        decStartTimes = pv.nativeStartTime; % Fallback
    end

    % 3. Create Dataset Object
    dataset = pyraview.Dataset('', ...
        'NativeRate', pv.nativeRate, ...
        'NativeStartTime', pv.nativeStartTime, ...
        'Channels', pv.channels, ...
        'DataType', pv.dataType, ...
        'decimationLevels', pv.decimationLevels, ...
        'decimationSamplingRates', pv.decimationSamplingRates, ...
        'decimationStartTime', decStartTimes, ...
        'Files', fileList);

    % 4. Determine Level and Samples
    [tVec, level, sStart, sEnd] = dataset.getLevelForReading(read_t0, read_t1, pixelSpan);

    if isempty(level)
        tVec = [];
        dataOut = [];
        return;
    end

    % 5. Handle Level 0 Logic
    % If level is 0, we must read raw data from probe and filter it.
    if level == 0
        % Extract epochid
        if ~isfield(doc.document_properties, 'epochid') || ~isfield(doc.document_properties.epochid, 'epochid')
            error('Pyraview document missing epochid.');
        end
        epochid = doc.document_properties.epochid.epochid;

        % Extract filter type
        if ~isfield(doc.document_properties, 'filter') || ~isfield(doc.document_properties.filter, 'type')
             if isfield(doc.document_properties.pyraview, 'label')
                filterType = doc.document_properties.pyraview.label;
             else
                filterType = 'high'; % Fallback
             end
        else
             filterType = doc.document_properties.filter.type;
        end

        % Calculate expanded range for filtering
        readExcess = options.readExcess;
        t_raw_start = read_t0 - readExcess;
        t_raw_end = read_t1 + readExcess;

        % Read Raw Data
        dataRaw = probe.readtimeseries(epochid, t_raw_start, t_raw_end);

        if isempty(dataRaw)
            tVec = []; dataOut = []; return;
        end

        sr = probe.samplerate(epochid);

        % Filter Data
        [dataFiltered, ~] = ndi.gui.app.pyraview.filterData(dataRaw, sr, filterType);

        % Trim excess to match read_t0 to read_t1
        offset_start = read_t0 - t_raw_start;
        offset_end = read_t1 - t_raw_start;

        idx_start = round(offset_start * sr) + 1;
        idx_end = round(offset_end * sr);

        if idx_start < 1, idx_start = 1; end
        if idx_end > size(dataFiltered, 1), idx_end = size(dataFiltered, 1); end

        if idx_start <= idx_end
            dataOut = dataFiltered(idx_start:idx_end, :);

            % Generate tVec for this segment
            % t = t_raw_start + (idx_start - 1)/sr
            numSamples = size(dataOut, 1);
            indices = (0 : numSamples - 1)';
            tStartSlice = t_raw_start + (idx_start - 1) / sr;
            tVec = tStartSlice + indices / sr;
        else
            tVec = []; dataOut = [];
        end

        return;
    end

    % 6. Identify Filename and Open File (For Level > 0)
    if level > length(dataset.Files)
        warning('Level %d requested but only %d files available.', level, length(dataset.Files));
        tVec = []; dataOut = []; return;
    end

    filename = dataset.Files{level};

    % Use NDI to open the file
    session = probe.session;

    binarydoc = [];
    try
        binarydoc = session.database_openbinarydoc(doc, filename);
    catch e
        warning('Failed to open binary doc: %s', e.message);
        tVec = []; dataOut = []; return;
    end

    % Ensure binarydoc is closed
    cleanupObj = onCleanup(@() session.database_closebinarydoc(binarydoc));

    % 7. Read Data
    if isprop(binarydoc, 'fullpathfilename')
        localpath = binarydoc.fullpathfilename;
    elseif isfield(struct(binarydoc), 'fullpathfilename')
         localpath = binarydoc.fullpathfilename;
    else
        try
             localpath = binarydoc.fullpathfilename;
        catch
             warning('Binary doc object does not expose fullpathfilename.');
             tVec = []; dataOut = []; return;
        end
    end

    if ~isfile(localpath)
         warning('Local file path from binary doc does not exist: %s', localpath);
         tVec = []; dataOut = []; return;
    end

    % Use pyraview.readFile
    try
        dataOut = pyraview.readFile(localpath, sStart, sEnd - 1);
    catch e
        warning('Failed to read file %s: %s', localpath, e.message);
        tVec = []; dataOut = []; return;
    end

    % Adjust tVec length
    if size(dataOut, 1) < length(tVec)
        tVec = tVec(1:size(dataOut, 1));
    elseif size(dataOut, 1) > length(tVec)
         tVec = tVec(1:size(dataOut, 1));
    end
end
