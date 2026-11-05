classdef CurlSender < handle
% NDI.CLOUD.UPLOAD.CURLSENDER - send a batch of files with one background curl
%
%   S = ndi.cloud.upload.CurlSender(URLS, PATHS, CRCS, UIDS, FOLDER)
%   S = ndi.cloud.upload.CurlSender(..., 'Parallel', N)
%
%   PUTs PATHS{i} to the pre-signed upload URL URLS{i}, signed with the
%   CRC-32 CRCS{i} (ndi.fun.file.crc32; '' for none), N at a time
%   (default 4), in one curl process started in the background: the call
%   returns at once and MATLAB carries on while the files go up.
%
%   The batch is written to FOLDER as a curl config file (one block per
%   file), and curl writes one line per finished transfer to a log there,
%   "<uid> <HTTP status>". WAIT reads it once curl has exited:
%
%       [OK, MSG, FAILED] = S.wait()          % or S.wait(TIMEOUTSECONDS)
%
%   OK is true when curl exited cleanly and every uid has a 2xx line;
%   FAILED lists the uids that did not. Nothing is assumed from a good
%   status: SessionWriter still checks each file's CRC-32 with NDI Cloud.
%
%   Each transfer is retried by curl on a transient error, and abandoned
%   if it stalls (under 1 kB/s for 2 minutes), so a send always ends.
%
%   curl is started with ndi.util.startProcess (java.lang.ProcessBuilder),
%   so the same code runs on Linux, macOS and Windows without a shell:
%   no quoting, and the process can be asked whether it is still running.
%   Needs curl 7.68 or newer (--parallel, and --parallel-immediate:
%   without it curl waits to multiplex on one HTTP/2 connection, which
%   storage serving HTTP/1.1 turns into one file at a time); SUPPORTED
%   says whether this computer has it.
%
%   Deleting S stops a send still running and removes its files.
%
%   See also: ndi.cloud.upload.SessionWriter, ndi.cloud.api.files.putFiles

    properties (SetAccess = private)
        uids = {}
        cfgFile char = ''
        logFile char = ''
        errFile char = ''
    end

    properties (Access = private)
        process = []
    end

    methods
        function obj = CurlSender(urls, paths, crcs, uids, folder, options)
            arguments
                urls cell
                paths cell
                crcs cell
                uids cell
                folder (1,:) char
                options.Parallel (1,1) double {mustBeInteger, mustBePositive} = 4
            end
            n = numel(paths);
            if numel(urls) ~= n || numel(crcs) ~= n || numel(uids) ~= n
                error('NDI:cloud:CurlSender:sizes', ...
                    'URLS, PATHS, CRCS and UIDS must have one entry per file.');
            end
            if ~isfolder(folder), mkdir(folder); end
            obj.uids = cellfun(@char, uids, 'UniformOutput', false);
            stem = fullfile(folder, ['send-' char(did.ido.unique_id())]);
            obj.cfgFile = [stem '.cfg'];
            obj.logFile = [stem '.log'];
            obj.errFile = [stem '.err'];

            blocks = cell(1, n);
            for i = 1:n
                % No shell is involved (see ndi.util.startProcess), so only
                % the config file's own quoting matters: CONFIGBLOCK escapes
                % \ and ", and a control character (a newline) is refused.
                if ~startsWith(char(urls{i}), 'https://') || any(char(urls{i}) < 32)
                    error('NDI:cloud:CurlSender:badUrl', ...
                        'Upload URL %d is not a plain https URL.', i);
                end
                if any(char(paths{i}) < 32)
                    error('NDI:cloud:CurlSender:badPath', ...
                        'File path %d contains a control character.', i);
                end
                if isempty(regexp(obj.uids{i}, '^[A-Za-z0-9_.-]+$', 'once'))
                    error('NDI:cloud:CurlSender:badUid', 'Unexpected file uid ''%s''.', obj.uids{i});
                end
                blocks{i} = ndi.cloud.upload.CurlSender.configBlock(char(urls{i}), ...
                    char(paths{i}), char(crcs{i}), obj.uids{i});
            end
            fid = fopen(obj.cfgFile, 'w');
            if fid < 0
                error('NDI:cloud:CurlSender:cannotWrite', 'Could not write %s.', obj.cfgFile);
            end
            fwrite(fid, strjoin(blocks, sprintf('next\n')), 'char');
            fclose(fid);

            obj.process = ndi.util.startProcess( ...
                {'curl', '--parallel', '--parallel-immediate', ...
                 '--parallel-max', sprintf('%d', options.Parallel), ...
                 '--config', obj.cfgFile}, obj.logFile, obj.errFile);
        end

        function tf = isDone(obj)
        % ISDONE - has curl exited?
            tf = isempty(obj.process) || ~obj.process.isAlive();
        end

        function [ok, msg, failed] = wait(obj, timeoutSeconds)
        % WAIT - wait for curl to exit (stopping it after TIMEOUTSECONDS), then report
            if nargin < 2 || isempty(timeoutSeconds), timeoutSeconds = Inf; end
            t0 = tic;
            while ~obj.isDone()
                if toc(t0) > timeoutSeconds
                    obj.stop();
                    break
                end
                pause(0.2);
            end
            status = NaN;
            if ~isempty(obj.process) && ~obj.process.isAlive()
                status = double(obj.process.exitValue());
            end
            codes = obj.statusByUid();
            failed = obj.uids(~cellfun(@(u) isKey(codes, u) && ...
                codes(u) >= 200 && codes(u) < 300, obj.uids));
            ok = status == 0 && isempty(failed);
            msg = '';
            if ~ok
                err = '';
                if isfile(obj.errFile)
                    err = strtrim(fileread(obj.errFile));
                    if numel(err) > 300, err = [err(1:300) '...']; end
                end
                if isnan(status)
                    msg = sprintf('curl did not finish within %g s', timeoutSeconds);
                else
                    msg = sprintf('curl exited with status %d; %d of %d file(s) not sent', ...
                        status, numel(failed), numel(obj.uids));
                end
                if ~isempty(err), msg = sprintf('%s (%s)', msg, err); end
            end
        end

        function stop(obj)
        % STOP - end a send that is still running
            if ~isempty(obj.process) && obj.process.isAlive()
                obj.process.destroy();
                obj.process.waitFor(5, java.util.concurrent.TimeUnit.SECONDS);
            end
        end

        function delete(obj)
            try
                obj.stop();
            catch
            end
            for f = {obj.cfgFile, obj.logFile, obj.errFile}
                if ~isempty(f{1}) && isfile(f{1})
                    delete(f{1});
                end
            end
        end
    end

    methods (Access = private)
        function m = statusByUid(obj)
        % The "<uid> <code>" lines curl wrote, as uid -> HTTP status.
            m = containers.Map('KeyType', 'char', 'ValueType', 'double');
            if ~isfile(obj.logFile), return; end
            lines = splitlines(fileread(obj.logFile));
            for k = 1:numel(lines)
                parts = strsplit(strtrim(lines{k}));
                if numel(parts) == 2 && any(strcmp(parts{1}, obj.uids))
                    m(parts{1}) = str2double(parts{2});
                end
            end
        end
    end

    methods (Static)
        function tf = supported()
        % SUPPORTED - is there a curl here new enough (7.68+)?
            persistent answer
            if isempty(answer)
                answer = false;
                try
                    out = [tempname '.txt'];
                    p = ndi.util.startProcess({'curl', '--version'}, out, out);
                    if p.waitFor(20, java.util.concurrent.TimeUnit.SECONDS) && p.exitValue() == 0
                        v = ndi.cloud.upload.CurlSender.parseVersion(fileread(out));
                        answer = v(1) > 7 || (v(1) == 7 && v(2) >= 68);
                    else
                        p.destroy();
                    end
                    if isfile(out), delete(out); end
                catch
                    answer = false;
                end
            end
            tf = answer;
        end

        function v = parseVersion(text)
        % PARSEVERSION - [major minor] from "curl --version" output ([0 0] if none)
            tok = regexp(char(text), 'curl (\d+)\.(\d+)', 'tokens', 'once');
            v = [0 0];
            if ~isempty(tok)
                v = str2double(tok);
            end
        end

        function s = configBlock(url, path, crc, uid)
        % CONFIGBLOCK - the curl config lines that PUT one file
        %
        %   As ndi.cloud.api.files.putFiles sends one, with curl's own
        %   retry and stall limits, and a write-out line naming the uid.
            q = @(x) ['"' strrep(strrep(x, '\', '\\'), '"', '\"') '"'];
            if ispc, nullDevice = 'NUL'; else, nullDevice = '/dev/null'; end
            lines = { ...
                ['url = ' q(url)], ...
                ['upload-file = ' q(path)], ...
                ['output = ' q(nullDevice)], ...
                'header = "Content-Type: application/octet-stream"', ...
                'header = "Accept-Encoding: identity"'};
            if ~isempty(crc)
                lines{end+1} = ['header = ' q(['x-amz-checksum-crc32: ' crc])];
            end
            lines = [lines, { ...
                'fail', 'silent', 'show-error', ...
                'retry = 3', 'connect-timeout = 30', ...
                'speed-limit = 1024', 'speed-time = 120', ...
                ['write-out = "' uid ' %{http_code}\n"']}];
            s = sprintf('%s\n', lines{:});
        end
    end
end
