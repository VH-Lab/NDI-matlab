function [b, report] = compare(rawSession, ingestedSession, options)
% COMPARE - compare a raw session with an ingested copy of it, channel by channel
%
% [B, REPORT] = ndi.test.ingest.compare(RAWSESSION, INGESTEDSESSION, ...)
%
% Compares the data of RAWSESSION, a session that has NOT been ingested, with
% INGESTEDSESSION, a copy of it that HAS been ingested (e.g., copy the session
% folder and call S.ingest() on the copy). Each may be an ndi.session object or
% the path of a session folder. Reads from the ingested copy come only from its
% ingested documents, so a match shows that ingestion stored the data
% faithfully.
%
% Every multifunction DAQ system (ndi.daq.system.mfdaq) of RAWSESSION is matched
% by name to one in INGESTEDSESSION and compared with
% ndi.test.ingest.mfdaq_compare: every epoch, its channel list, and the data of
% every channel type. A DAQ system missing from INGESTEDSESSION is reported.
%
% B is true if everything compared equal. REPORT is the structure array
% described in ndi.test.ingest.mfdaq_compare, with the entries for all DAQ
% systems (check 'daqsystem' marks a DAQ system that could not be compared).
% Nothing stops or prompts on a mismatch.
%
% This function takes name/value pairs that modify its behavior:
% |---------------------------|-----------------------------------------------|
% | Parameter (default)       | Description                                   |
% |---------------------------|-----------------------------------------------|
% | Mode ('full')             | 'full' compares every sample; 'spot' compares |
% |                           |   one random window per channel type per      |
% |                           |   epoch. See ndi.test.ingest.mfdaq_compare.   |
% | ChunkSeconds (60)         | Length of each read in 'full' mode.           |
% | SpotSeconds (300)         | Length of the window in 'spot' mode.          |
% | TimeTolerance (1e-6)      | Largest difference allowed for time channels. |
% | DaqSystemNames ({})       | Compare only these DAQ systems (default: all).|
% | Verbose (true)            | Print progress and each failed check.         |
% | ShowProgress (true)       | Show a progress bar per DAQ system            |
% |                           |   (ndi.gui.component.ProgressBarWindow).      |
% |---------------------------|-----------------------------------------------|
%
% Example:
%   [b, report] = ndi.test.ingest.compare(Sraw, Singested);
%   report(~[report.ok])   % the checks that failed
%
% See also: ndi.test.ingest.mfdaq_compare, ndi.session/ingest

arguments
    rawSession
    ingestedSession
    options.Mode (1,:) char {mustBeMember(options.Mode,{'full','spot'})} = 'full'
    options.ChunkSeconds (1,1) double {mustBePositive} = 60
    options.SpotSeconds (1,1) double {mustBePositive} = 300
    options.TimeTolerance (1,1) double {mustBeNonnegative} = 1e-6
    options.DaqSystemNames {mustBeText} = {}
    options.Verbose (1,1) logical = true
    options.ShowProgress (1,1) logical = true
end

S1 = openSession(rawSession);
S2 = openSession(ingestedSession);

daqs1 = asCell(S1.daqsystem_load('name','(.*)'));
daqs2 = asCell(S2.daqsystem_load('name','(.*)'));
names2 = cellfun(@(d) char(d.name), daqs2, 'UniformOutput', false);
wanted = cellstr(options.DaqSystemNames);

progressBar = [];
if options.ShowProgress
    try
        progressBar = ndi.gui.component.ProgressBarWindow('NDI Ingest Compare','Overwrite',false);
    catch ME
        warning('NDI:test:ingest:compare:progressFailed', ...
            'Could not open a progress window: %s', ME.message);
    end
end

report = struct('daqsystem',{},'epoch_id',{},'check',{},'ok',{},'message',{},...
    't0_t1',{},'samples',{},'maxAbsDiff',{});

for i=1:numel(daqs1)
    name = char(daqs1{i}.name);
    if ~isempty(wanted) && ~any(strcmp(name, wanted))
        continue;
    end
    if ~isa(daqs1{i}, 'ndi.daq.system.mfdaq')
        if options.Verbose
            fprintf('Skipping %s: not an ndi.daq.system.mfdaq.\n', name);
        end
        continue;
    end
    j = find(strcmp(name, names2), 1);
    if isempty(j)
        report(end+1) = struct('daqsystem',name,'epoch_id','','check','daqsystem','ok',false,...
            'message','DAQ system is missing from the ingested session.','t0_t1',[],...
            'samples',0,'maxAbsDiff',NaN); %#ok<AGROW> one entry per missing DAQ system
        if options.Verbose
            fprintf('MISMATCH %s: DAQ system is missing from the ingested session.\n', name);
        end
        continue;
    end
    [~, ~, reportHere] = ndi.test.ingest.mfdaq_compare(daqs1{i}, daqs2{j}, ...
        'Mode', options.Mode, 'ChunkSeconds', options.ChunkSeconds, ...
        'SpotSeconds', options.SpotSeconds, 'TimeTolerance', options.TimeTolerance, ...
        'Verbose', options.Verbose, 'ProgressBar', progressBar);
    report = cat(2, report, reportHere);
end

b = all([report.ok]);
if options.Verbose
    fprintf('%d checks, %d failed.\n', numel(report), nnz(~[report.ok]));
end

end % compare()

function S = openSession(s)
% OPENSESSION - an ndi.session, or a session opened from a folder path
    if isa(s, 'ndi.session')
        S = s;
    elseif ischar(s) || (isstring(s) && isscalar(s))
        S = ndi.session.dir(char(s));
    else
        error('NDI:test:ingest:compare:badSession', ...
            'Each session must be an ndi.session or the path of a session folder.');
    end
end

function c = asCell(x)
    if isempty(x)
        c = {};
    elseif iscell(x)
        c = x;
    else
        c = {x};
    end
end
