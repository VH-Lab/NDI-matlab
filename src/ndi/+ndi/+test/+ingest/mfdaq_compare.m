function [b, errmsg, report] = mfdaq_compare(daq1, daq2, options)
% MFDAQ_COMPARE - compare raw and ingested data from two ndi.daq.system.mfdaq objects
%
% [B, ERRMSG, REPORT] = ndi.test.ingest.mfdaq_compare(DAQ1, DAQ2, ...)
%
% Compares the data read through DAQ1, a DAQ system of a session that has NOT
% been ingested, with the data read through DAQ2, the same DAQ system in a copy
% of that session that HAS been ingested. Reads through DAQ2 come only from the
% ingested documents, so a match shows that ingestion stored the data faithfully.
%
% For every epoch of DAQ1, matched to DAQ2's epoch by epoch id, it checks:
%   - that the epoch exists in DAQ2 and is ingested there;
%   - the channel list (every channel, matched by name; every field the two
%     lists share, e.g., type, sample rate, offset, scale);
%   - every continuous channel type present (analog_in, analog_out,
%     auxiliary_in, digital_in, digital_out, time): the number of samples, and
%     the samples themselves (to RelativeTolerance; time channels to
%     TimeTolerance);
%   - every event channel type present (event, marker, text): the timestamps
%     and values over the whole epoch.
%
% B is true if every check passed. ERRMSG is a cell array of messages, one per
% failed check. REPORT is a structure array with one entry per check, with
% fields:
%   daqsystem  - the DAQ system's name
%   epoch_id   - the epoch id ('' for checks about the DAQ system itself)
%   check      - 'epoch', 'channel_list', or the channel type compared
%   ok         - true if the check passed
%   message    - what differed ('' when ok)
%   t0_t1      - the epoch times compared, [t0 t1]
%   samples    - the number of samples compared (continuous types)
%   maxAbsDiff - the largest absolute difference found (continuous types)
%
% Nothing stops or prompts on a mismatch; every difference is reported and the
% comparison continues with the next check.
%
% This function takes name/value pairs that modify its behavior:
% |---------------------------|-----------------------------------------------|
% | Parameter (default)       | Description                                   |
% |---------------------------|-----------------------------------------------|
% | Mode ('full')             | 'full' compares every sample of every epoch,  |
% |                           |   ChunkSeconds at a time. 'spot' compares one |
% |                           |   randomly placed window of SpotSeconds per   |
% |                           |   channel type per epoch (faster; can miss a  |
% |                           |   fault confined to some segments).           |
% | ChunkSeconds (60)         | Length of each read in 'full' mode, which     |
% |                           |   bounds memory use.                          |
% | SpotSeconds (300)         | Length of the window in 'spot' mode.          |
% | RelativeTolerance (1e-12) | Largest difference allowed between raw and    |
% |                           |   ingested samples, relative to the larger of |
% |                           |   the two values. Scaled channels (e.g., an   |
% |                           |   Intan auxiliary input, 3.74e-5 V per step)  |
% |                           |   can differ in the last bit because the two  |
% |                           |   paths round the scaling differently; 1e-12  |
% |                           |   allows that while staying far below one     |
% |                           |   sample's quantization step. 0 demands       |
% |                           |   exact equality.                             |
% | TimeTolerance (1e-6)      | Largest difference allowed for time channels. |
% | Verbose (true)            | Print each epoch as it is compared, and each  |
% |                           |   failed check.                               |
% | ProgressBar ([])          | An ndi.gui.component.ProgressBarWindow to add |
% |                           |   a bar to (empty: no bar).                   |
% |---------------------------|-----------------------------------------------|
%
% Example:
%   dRaw = Sraw.daqsystem_load('name','intan1');
%   dIng = Singested.daqsystem_load('name','intan1');
%   [b, errmsg, report] = ndi.test.ingest.mfdaq_compare(dRaw, dIng);
%
% See also: ndi.test.ingest.compare, ndi.session/ingest

arguments
    daq1 (1,1) ndi.daq.system.mfdaq
    daq2 (1,1) ndi.daq.system.mfdaq
    options.Mode (1,:) char {mustBeMember(options.Mode,{'full','spot'})} = 'full'
    options.ChunkSeconds (1,1) double {mustBePositive} = 60
    options.SpotSeconds (1,1) double {mustBePositive} = 300
    options.RelativeTolerance (1,1) double {mustBeNonnegative} = 1e-12
    options.TimeTolerance (1,1) double {mustBeNonnegative} = 1e-6
    options.Verbose (1,1) logical = true
    options.ProgressBar = []
end

report = emptyReport();

daq1.session.cache.clear();
daq2.session.cache.clear();

et1 = daq1.epochtable();
et2 = daq2.epochtable();
epochIds2 = {et2.epoch_id};

progressBar = [];
barTag = '';
if ~isempty(options.ProgressBar) && ~isempty(et1)
    [progressBar, barTag] = ndi.daq.system.addIngestProgressBar(options.ProgressBar, ...
        ['Comparing ' char(daq1.name) ' (' int2str(numel(et1)) ' epochs)']);
end

continuousTypes = {'analog_in','analog_out','auxiliary_in','digital_in','digital_out','time'};
eventTypes = {'event','marker','text'};

for i=1:numel(et1)
    epochId = et1(i).epoch_id;
    t0_t1 = et1(i).t0_t1{1};
    if options.Verbose
        fprintf('Comparing %s epoch %s (%d of %d)...\n', daq1.name, epochId, i, numel(et1));
    end

    % the epoch must exist in DAQ2, and be ingested there
    j = find(strcmp(epochId, epochIds2), 1);
    if isempty(j)
        report = addEntry(report, options, daq1, epochId, 'epoch', false, ...
            'Epoch is missing from the ingested session.', t0_t1, 0, NaN);
        ndi.daq.system.updateIngestProgressBar(progressBar, barTag, i/numel(et1));
        continue;
    end
    if ~ndi.file.navigator.isingested(et2(j).underlying_epochs.underlying)
        report = addEntry(report, options, daq1, epochId, 'epoch', false, ...
            'Epoch is not ingested in the second session.', t0_t1, 0, NaN);
        ndi.daq.system.updateIngestProgressBar(progressBar, barTag, i/numel(et1));
        continue;
    end
    report = addEntry(report, options, daq1, epochId, 'epoch', true, '', t0_t1, 0, NaN);

    % channel lists
    c1 = daq1.getchannelsepoch(epochId);
    c2 = daq2.getchannelsepoch(epochId);
    [ok, msg] = compareChannelLists(c1, c2);
    report = addEntry(report, options, daq1, epochId, 'channel_list', ok, msg, t0_t1, 0, NaN);

    % continuous channels, grouped by sample rate so each read is uniform
    for k=1:numel(continuousTypes)
        channels = channelNumbers(c1, continuousTypes{k});
        if isempty(channels)
            continue;
        end
        sr = daq1.samplerate(epochId, continuousTypes{k}, channels);
        sr = sr(:)';
        rates = unique(sr(:)');
        rates = rates(~isnan(rates));
        for r=1:numel(rates)
            channelsHere = channels(sr==rates(r));
            [ok, msg, n, mx] = compareContinuous(daq1, daq2, epochId, continuousTypes{k}, ...
                channelsHere, rates(r), t0_t1, options);
            report = addEntry(report, options, daq1, epochId, continuousTypes{k}, ok, msg, t0_t1, n, mx);
        end
    end

    % event channels, over the whole epoch
    for k=1:numel(eventTypes)
        channels = channelNumbers(c1, eventTypes{k});
        if isempty(channels)
            continue;
        end
        [ok, msg] = compareEvents(daq1, daq2, epochId, eventTypes{k}, channels, t0_t1);
        report = addEntry(report, options, daq1, epochId, eventTypes{k}, ok, msg, t0_t1, 0, NaN);
    end

    ndi.daq.system.updateIngestProgressBar(progressBar, barTag, i/numel(et1));
end

errmsg = {};
for i=1:numel(report)
    if ~report(i).ok
        errmsg{end+1} = [report(i).daqsystem ' ' report(i).epoch_id ' ' ...
            report(i).check ': ' report(i).message]; %#ok<AGROW> only failures
    end
end
b = all([report.ok]);

end % mfdaq_compare()

function report = emptyReport()
    report = struct('daqsystem',{},'epoch_id',{},'check',{},'ok',{},'message',{},...
        't0_t1',{},'samples',{},'maxAbsDiff',{});
end

function report = addEntry(report, options, daq, epochId, check, ok, msg, t0_t1, n, mx)
    report(end+1) = struct('daqsystem',char(daq.name),'epoch_id',epochId,'check',check,...
        'ok',logical(ok),'message',msg,'t0_t1',t0_t1,'samples',n,'maxAbsDiff',mx);
    if ~ok && options.Verbose
        fprintf('  MISMATCH %s %s: %s\n', epochId, check, msg);
    end
end

function n = channelNumbers(c, channeltype)
% CHANNELNUMBERS - the channel numbers of one type in a channel list
    entries = find(strcmp(channeltype, {c.type}));
    n = zeros(1,numel(entries));
    for k=1:numel(entries)
        [~, n(k)] = ndi.fun.channelname2prefixnumber(c(entries(k)).name);
    end
end

function [ok, msg] = compareChannelLists(c1, c2)
% COMPARECHANNELLISTS - same channels (by name) and same values in shared fields
    ok = true;
    msg = '';
    names1 = sort({c1.name});
    names2 = sort({c2.name});
    if ~isequal(names1, names2)
        ok = false;
        msg = ['Channel names differ. Only raw: ' strjoin(setdiff(names1,names2),', ') ...
            '; only ingested: ' strjoin(setdiff(names2,names1),', ') '.'];
        return;
    end
    [~, o1] = sort({c1.name});
    [~, o2] = sort({c2.name});
    c1 = c1(o1);
    c2 = c2(o2);
    fields = intersect(fieldnames(c1), fieldnames(c2));
    bad = {};
    for f=1:numel(fields)
        if ~isequaln({c1.(fields{f})}, {c2.(fields{f})})
            bad{end+1} = fields{f}; %#ok<AGROW> only differing fields
        end
    end
    if ~isempty(bad)
        ok = false;
        msg = ['Channel list fields differ: ' strjoin(bad,', ') '.'];
    end
end

function [ok, msg, nCompared, maxAbsDiff] = compareContinuous(daq1, daq2, epochId, channeltype, ...
    channels, sampleRate, t0_t1, options)
% COMPARECONTINUOUS - compare samples of one channel type at one sample rate
    ok = true;
    msg = '';
    nCompared = 0;
    maxAbsDiff = 0;
    isTime = strcmp(channeltype, 'time');

    s1 = daq1.epochtimes2samples(channeltype, channels, epochId, t0_t1);
    s2 = daq2.epochtimes2samples(channeltype, channels, epochId, t0_t1);
    if ~isequal(s1(:)', s2(:)')
        ok = false;
        msg = sprintf('Sample range differs: raw %d..%d, ingested %d..%d.', s1(1), s1(end), s2(1), s2(end));
        return;
    end
    sFirst = s1(1);
    sLast = s1(end);

    if strcmp(options.Mode, 'full')
        chunk = max(1, round(options.ChunkSeconds * sampleRate));
        starts = sFirst:chunk:sLast;
    else
        chunk = max(1, round(options.SpotSeconds * sampleRate));
        span = max(0, sLast - sFirst + 1 - chunk);
        starts = sFirst + floor(rand * (span + 1));
    end

    for s0 = starts
        sEnd = min(s0 + chunk - 1, sLast);
        try
            D1 = daq1.readchannels_epochsamples(channeltype, channels, epochId, s0, sEnd);
        catch ME
            ok = false;
            msg = sprintf('Reading the raw data failed at samples %d..%d: %s', s0, sEnd, ME.message);
            return;
        end
        try
            D2 = daq2.readchannels_epochsamples(channeltype, channels, epochId, s0, sEnd);
        catch ME
            ok = false;
            msg = sprintf('Reading the ingested data failed at samples %d..%d: %s', s0, sEnd, ME.message);
            return;
        end
        if ~isequal(size(D1), size(D2))
            ok = false;
            msg = sprintf('Sizes differ at samples %d..%d: raw %s, ingested %s.', s0, sEnd, ...
                mat2str(size(D1)), mat2str(size(D2)));
            return;
        end
        nCompared = nCompared + size(D1,1);
        if isempty(D1)
            continue;
        end
        d = abs(double(D1) - double(D2));
        d(isnan(D1) & isnan(D2)) = 0;
        d(xor(isnan(D1), isnan(D2))) = Inf;
        maxAbsDiff = max(maxAbsDiff, max(d(:)));
        if isTime
            allowed = options.TimeTolerance;
        else
            allowed = options.RelativeTolerance * max(abs(double(D1)), abs(double(D2)));
        end
        tooLarge = d > allowed;
        if any(tooLarge(:))
            excess = d;
            excess(~tooLarge) = -Inf;
            [row, col] = find(excess == max(excess(:)), 1);
            ok = false;
            msg = sprintf(['Data differ (max |difference| %g) starting by sample %d, channel %d ' ...
                '(read window %d..%d).'], maxAbsDiff, s0 + row - 1, channels(col), s0, sEnd);
            return;
        end
    end
end

function [ok, msg] = compareEvents(daq1, daq2, epochId, channeltype, channels, t0_t1)
% COMPAREEVENTS - compare the timestamps and values of event-type channels
    ok = true;
    msg = '';
    try
        [T1, D1] = daq1.readevents(channeltype, channels, epochId, t0_t1(1), t0_t1(2));
        [T2, D2] = daq2.readevents(channeltype, channels, epochId, t0_t1(1), t0_t1(2));
    catch ME
        ok = false;
        msg = ['Reading events failed: ' ME.message];
        return;
    end
    if ~isequaln(normalizeEmpty(T1), normalizeEmpty(T2))
        ok = false;
        msg = 'Event timestamps differ.';
    elseif ~isequaln(normalizeEmpty(D1), normalizeEmpty(D2))
        ok = false;
        msg = 'Event values (codes/text) differ.';
    end
end

function x = normalizeEmpty(x)
% NORMALIZEEMPTY - make every empty event array 0x1, so differently shaped
% empties compare equal
    if iscell(x)
        for k=1:numel(x)
            if isempty(x{k})
                x{k} = zeros(0,1);
            end
        end
    elseif isempty(x)
        x = zeros(0,1);
    end
end
