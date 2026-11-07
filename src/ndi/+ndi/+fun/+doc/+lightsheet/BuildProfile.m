classdef BuildProfile < handle
% NDI.FUN.DOC.LIGHTSHEET.BUILDPROFILE - where a pyramid build spends its time
%
%   P = ndi.fun.doc.lightsheet.BuildProfile(LOGFILE, EVERYSECONDS)
%
%   ndi.fun.doc.lightsheet.makePyramid times every super-block (one read,
%   one parallel compression of its chunks, one hand-off to the target)
%   and ADDs a row here. Each row is appended to LOGFILE as CSV (empty: no
%   file), a summary is printed every EVERYSECONDS (default 600) and at
%   the end of each level, and FINISH prints one for the whole build:
%
%     [profile] Level 0 (mean), last 10 min, 58 batches: read-wait 41%,
%       assemble 4%, compress 38% (workers 63% busy), upload 14%
%       (URLs 6%, staging+CRC 2%, waiting for curl 3%, cloud check 3%),
%       progress 1%, other 2%. 11.8 MB/s of chunks made, 5.2 MB/s
%       compressed, 31.0 MB/s read.
%
%   The shares are of the main MATLAB's wall-clock time, so they add up
%   to 100%. READ-WAIT is time spent waiting for the next super-block's
%   read (it runs on a worker while the previous one compresses; time
%   here means the read is the slower of the two). COMPRESS is the
%   parallel loop's wall-clock time; WORKERS ... BUSY is how much of the
%   workers' time in it went to chunks (the rest is idle: uneven chunks,
%   or fewer chunks than workers in the last round). UPLOAD is the time
%   the target took to take the batch (ndi.cloud.upload.SessionWriter:
%   signed URLs, staging and CRC-32, waiting for the background curl of
%   the batch before, checking that batch with the cloud). PROGRESS is
%   the progress callback (a job saves its record and redraws there).
%   MB/s READ counts what the source had to read (whole slices for
%   SmartSPIM), so it shows how hard the source (disk, network) works.
%
%   LOGFILE columns: when, level, superblock, nSuperBlocks, chunks,
%   workers, mbRead, mbChunks, mbOut, readWait, assemble, compress,
%   workerBusy, upload, urls, stage, send, verify, progress, total
%   (seconds; mbOut is the compressed size). A resumed build appends.
%
%   See also: ndi.fun.doc.lightsheet.makePyramid

    properties (SetAccess = private)
        logFile char = ''
        rows = []    % one struct per super-block (see EMPTYROWS)
    end

    properties (Access = private)
        everySeconds (1,1) double = 600
        lastPrint = []
        windowFirst (1,1) double = 1
        levelFirst (1,1) double = 1
    end

    methods
        function obj = BuildProfile(logFile, everySeconds)
            obj.rows = ndi.fun.doc.lightsheet.BuildProfile.emptyRows();
            if nargin >= 1, obj.logFile = char(logFile); end
            if nargin >= 2, obj.everySeconds = everySeconds; end
            obj.lastPrint = tic;
        end

        function add(obj, r)
        % ADD - record one super-block (a struct with BuildProfile's fields)
            r.when = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
            r = orderfields(r, ndi.fun.doc.lightsheet.BuildProfile.emptyRows());
            obj.rows(end+1) = r;
            obj.append(r);
            if toc(obj.lastPrint) >= obj.everySeconds
                fprintf('[profile] %s, last %s: %s\n', r.level, ...
                    ndi.fun.doc.lightsheet.BuildProfile.minutes(toc(obj.lastPrint)), ...
                    ndi.fun.doc.lightsheet.BuildProfile.summarize(obj.rows(obj.windowFirst:end)));
                obj.windowFirst = numel(obj.rows) + 1;
                obj.lastPrint = tic;
            end
        end

        function endLevel(obj, label)
        % ENDLEVEL - print the summary of the level just finished
            these = obj.rows(obj.levelFirst:end);
            if ~isempty(these)
                fprintf('[profile] %s, whole level: %s\n', char(label), ...
                    ndi.fun.doc.lightsheet.BuildProfile.summarize(these));
            end
            obj.levelFirst = numel(obj.rows) + 1;
            obj.windowFirst = obj.levelFirst;
            obj.lastPrint = tic;
        end

        function finish(obj)
        % FINISH - print the summary of everything built in this run
            if ~isempty(obj.rows)
                fprintf('[profile] Whole build (this run): %s\n', ...
                    ndi.fun.doc.lightsheet.BuildProfile.summarize(obj.rows));
                if ~isempty(obj.logFile)
                    fprintf('[profile] Every batch is in %s\n', obj.logFile);
                end
            end
        end
    end

    methods (Static)
        function t = summarize(rows)
        % SUMMARIZE - one sentence on where ROWS' time went
            n = numel(rows);
            if n == 0
                t = 'no batches';
                return
            end
            total = sum([rows.total]);
            pct = @(x) 100 * sum(x) / max(total, eps);
            readWait = [rows.readWait]; assemble = [rows.assemble];
            compress = [rows.compress]; upload = [rows.upload];
            progress = [rows.progress];
            other = total - sum(readWait) - sum(assemble) - sum(compress) - ...
                sum(upload) - sum(progress);
            capacity = sum(compress .* [rows.workers]);
            busy = 100 * sum([rows.workerBusy]) / max(capacity, eps);
            t = sprintf(['%d batches: read-wait %.0f%%, assemble %.0f%%, ' ...
                'compress %.0f%% (workers %.0f%% busy), upload %.0f%% ' ...
                '(URLs %.0f%%, staging+CRC %.0f%%, waiting for curl %.0f%%, ' ...
                'cloud check %.0f%%), progress %.0f%%, other %.0f%%. ' ...
                '%.1f MB/s of chunks made, %.1f MB/s compressed, %.1f MB/s read.'], ...
                n, pct(readWait), pct(assemble), pct(compress), busy, ...
                pct(upload), pct([rows.urls]), pct([rows.stage]), ...
                pct([rows.send]), pct([rows.verify]), pct(progress), ...
                max(0, pct(other)), ...
                sum([rows.mbChunks]) / max(total, eps), ...
                sum([rows.mbOut]) / max(total, eps), ...
                sum([rows.mbRead]) / max(total, eps));
        end

        function r = emptyRows()
            r = struct('when', {}, 'level', {}, 'superblock', {}, ...
                'nSuperBlocks', {}, 'chunks', {}, 'workers', {}, ...
                'mbRead', {}, 'mbChunks', {}, 'mbOut', {}, ...
                'readWait', {}, 'assemble', {}, 'compress', {}, ...
                'workerBusy', {}, 'upload', {}, 'urls', {}, 'stage', {}, ...
                'send', {}, 'verify', {}, 'progress', {}, 'total', {});
        end
    end

    methods (Static, Access = private)
        function s = minutes(seconds)
            s = sprintf('%.0f min', seconds / 60);
        end
    end

    methods (Access = private)
        function append(obj, r)
            if isempty(obj.logFile), return; end
            try
                isNew = ~isfile(obj.logFile);
                fid = fopen(obj.logFile, 'a');
                if fid < 0, return; end
                closer = onCleanup(@() fclose(fid));
                names = fieldnames(r);
                if isNew
                    fprintf(fid, '%s\n', strjoin(names, ','));
                end
                vals = cell(1, numel(names));
                for i = 1:numel(names)
                    v = r.(names{i});
                    if ischar(v) || isstring(v)
                        vals{i} = ['"' strrep(char(v), '"', '""') '"'];
                    else
                        vals{i} = sprintf('%.4g', v);
                    end
                end
                fprintf(fid, '%s\n', strjoin(vals, ','));
            catch
                % Profiling never stops the build.
            end
        end
    end
end
