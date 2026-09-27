classdef signedUrlDiskCache
%SIGNEDURLDISKCACHE Persistent (on-disk) cache for signed-URL-set payloads.
%
%   This is the disk-backed layer that sits beneath the in-process cache
%   inside ndi.cloud.download.internal.batchSignedUrlLookup. It exists so a
%   working scientist reopening the same dataset over a day pays the
%   ~85-minute async signed-URL-set-job cost ONCE and reads from disk on
%   every subsequent viewer open. NDI cloud infrastructure, not DID: DID's
%   file-bytes cache is a separate, complementary concern.
%
%   Scope key
%   ---------
%   The unit the cache stores and evicts is one (datasetId, documentId,
%   seriesName) tuple -- the same tuple batchSignedUrlLookup uses. An
%   empty seriesName marks a whole-document scope.
%
%   Payload
%   -------
%   What save() writes and load() returns is a struct with the fields the
%   getSignedURLSetResult / getSignedURLSetAll answers already carry:
%
%       .files          containers.Map from uid (char) to signed URL (char).
%       .filesExpireAt  ISO-8601 UTC string; the server's authoritative
%                       expiry timestamp for the SIGNED URLs. Preferred.
%       .expiresAt      ISO-8601 UTC string; older/paging path's field.
%                       Used only when filesExpireAt is not present.
%       .generatedAt    ISO-8601 UTC string; when the server built the map.
%                       Optional, informational.
%       .fileCount      Numeric; how many uids the server reported.
%                       Optional.
%
%   On-disk contract
%   ----------------
%   Location:  <cacheDir>/<datasetId>/<documentId>.json.gz  (whole-doc)
%              <cacheDir>/<datasetId>/<documentId>_<escapedSeries>.json.gz
%                                                            (scoped)
%
%   cacheDir defaults to ~/.ndi/signed-url-cache, overridable via the
%   NDI_SIGNED_URL_CACHE_DIR environment variable. The base directory is
%   created with mode 0700 (POSIX) because a signed URL is effectively a
%   bearer token for 24 h; Windows relies on the default per-user profile
%   ACL.
%
%   Filename escaping for seriesName: any byte that is not
%   [A-Za-z0-9._-] becomes '%XX' (uppercase hex). A resulting string
%   longer than 96 characters is replaced with 'hash-<sha1(raw)>' (45
%   chars). NDI-python mirrors this rule byte-for-byte.
%
%   Format:    Standard gzip framing (RFC 1952), single member, UTF-8
%              JSON body. Unzipping yields a human-readable JSON object:
%
%              {
%                "schemaVersion": 1,
%                "datasetId":     "<mongo _id>",
%                "documentId":    "<ndi id>",
%                "seriesName":    "" or "<name>",
%                "cachedAt":      "YYYY-MM-DDTHH:MM:SSZ",
%                "filesExpireAt": "YYYY-MM-DDTHH:MM:SSZ" or "",
%                "expiresAt":     "YYYY-MM-DDTHH:MM:SSZ" or "",
%                "generatedAt":   "YYYY-MM-DDTHH:MM:SSZ" or "",
%                "fileCount":     N,
%                "files":         { "<uid>": "<url>", ... }
%              }
%
%   TTL and safety buffer
%   ---------------------
%   The cache does not invent a TTL. It reads the authoritative
%   filesExpireAt (or expiresAt) from the payload; a payload with
%   neither is treated as un-cacheable (save is a no-op) and, on load,
%   as an immediate miss. A URL that would expire in less than the
%   safety buffer (default 30 min, override with
%   NDI_SIGNED_URL_CACHE_SAFETY_SECONDS) is also treated as a miss --
%   we never hand a caller a URL likely to 403 before they can use it.
%
%   Concurrency
%   -----------
%   Writes go to a per-writer temp file next to the target and are
%   moved into place with an atomic rename (java.nio.file.Files.move
%   with ATOMIC_MOVE, which uses rename(2) on POSIX and MoveFileEx on
%   Windows). Two viewers signing the same scope concurrently is fine:
%   whichever atomic move lands last wins, both readers see a
%   consistent file afterwards. There is no cross-process lock; the
%   contract is last-writer-wins, not exclusive.
%
%   Invalidation
%   ------------
%   forget(dsId, docId, seriesName) removes the file for one scope. The
%   caller does this from the chunk-download path when it sees an S3
%   403 -- the URL was in the cache but the object rotated or the
%   token was revoked, so drop the scope and let the next lookup
%   refetch. Failing to remove the file is not fatal.
%
%   Public API
%   ----------
%       payload = load(datasetId, documentId, seriesName)
%           Returns a struct on cache hit, [] on any miss/expired/error.
%       save(datasetId, documentId, seriesName, payload)
%           Writes atomically; best-effort (silent on any I/O error).
%       forget(datasetId, documentId, seriesName)
%           Deletes the cache file for that scope; best-effort.
%       location = cacheDir()
%           Returns the absolute on-disk root, honoring the env-var
%           override. Also creates it (with mode 0700 on POSIX) the
%           first time it is asked for on a session.
%
%   See also: ndi.cloud.download.internal.batchSignedUrlLookup,
%             ndi.cloud.api.files.getSignedURLSetResult,
%             ndi.cloud.api.files.getSignedURLSetAll

    properties (Constant, Access = private)
        SchemaVersion       = 1
        DefaultSafetySec    = 1800   % 30 min; task-declared floor.
        MaxEscapedSeriesLen = 96    % Beyond this we hash the series name.
    end

    methods (Static)

        function payload = load(datasetId, documentId, seriesName)
        %LOAD Read one scope's cached signed-URL set, or [] on any miss.
        %
        %   PAYLOAD = LOAD(DATASETID, DOCUMENTID, SERIESNAME) returns a
        %   struct (fields: files, filesExpireAt, expiresAt, generatedAt,
        %   fileCount) on cache hit. Returns [] on any of: no cache file,
        %   corrupt file, JSON parse error, expired-or-within-safety-buffer.
        %
        %   The safety buffer is 30 min by default, overridable via
        %   NDI_SIGNED_URL_CACHE_SAFETY_SECONDS. A URL that would expire
        %   inside that window is a miss so the caller refetches rather
        %   than handing bytes to a viewer that then 403s.
            arguments
                datasetId   (1,1) string
                documentId  (1,1) string
                seriesName  (1,1) string = ""
            end
            payload = [];

            filePath = ndi.cloud.download.internal.signedUrlDiskCache.cachePath( ...
                datasetId, documentId, seriesName);
            if ~isfile(filePath)
                return
            end

            try
                jsonTxt = ndi.cloud.download.internal.signedUrlDiskCache.gunzipToString(filePath);
            catch
                return
            end

            try
                decoded = ndi.cloud.download.internal.signedUrlDiskCache.parseJson(jsonTxt);
            catch
                return
            end

            if isempty(decoded)
                return
            end

            % Enforce the safety-buffer floor against the authoritative
            % server timestamp. A payload with no timestamp is a miss:
            % better to refetch than hand out a URL we can't age-check.
            safetySec = ndi.cloud.download.internal.signedUrlDiskCache.safetySeconds();
            expiryStr = decoded.filesExpireAt;
            if strlength(expiryStr) == 0
                expiryStr = decoded.expiresAt;
            end
            if strlength(expiryStr) == 0
                return
            end

            expiry = ndi.cloud.download.internal.signedUrlDiskCache.parseIsoUtc(expiryStr);
            if isnat(expiry)
                return
            end
            nowUtc = datetime('now', 'TimeZone', 'UTC');
            if seconds(expiry - nowUtc) < safetySec
                return
            end

            payload = decoded;
        end

        function save(datasetId, documentId, seriesName, payload)
        %SAVE Persist a scope's signed-URL set. Best-effort, atomic.
        %
        %   SAVE(DATASETID, DOCUMENTID, SERIESNAME, PAYLOAD) writes the
        %   payload to the scope's cache path via a temp file + atomic
        %   rename. A payload without a filesExpireAt / expiresAt is
        %   NOT written -- the cache cannot age-check something it has
        %   no timestamp for, and we refuse to invent a TTL.
        %
        %   Any I/O failure (missing dir, permission denied, disk full,
        %   another process racing us) is swallowed silently: the
        %   in-memory cache still works, so a viewer open still succeeds.
            arguments
                datasetId   (1,1) string
                documentId  (1,1) string
                seriesName  (1,1) string
                payload     struct
            end

            if ~isfield(payload, 'files') || ~isa(payload.files, 'containers.Map')
                return
            end

            % Refuse to persist an un-age-checkable payload.
            filesExpireAt = ndi.cloud.download.internal.signedUrlDiskCache.stringField(payload, 'filesExpireAt');
            expiresAt     = ndi.cloud.download.internal.signedUrlDiskCache.stringField(payload, 'expiresAt');
            if strlength(filesExpireAt) == 0 && strlength(expiresAt) == 0
                return
            end

            generatedAt = ndi.cloud.download.internal.signedUrlDiskCache.stringField(payload, 'generatedAt');
            fileCount   = ndi.cloud.download.internal.signedUrlDiskCache.numericField(payload, 'fileCount', ...
                double(payload.files.Count));

            filePath = ndi.cloud.download.internal.signedUrlDiskCache.cachePath( ...
                datasetId, documentId, seriesName);

            try
                ndi.cloud.download.internal.signedUrlDiskCache.ensureParentDir(filePath);
            catch
                return
            end

            try
                jsonTxt = ndi.cloud.download.internal.signedUrlDiskCache.buildJson(...
                    struct( ...
                        'datasetId',     char(datasetId), ...
                        'documentId',    char(documentId), ...
                        'seriesName',    char(seriesName), ...
                        'cachedAt',      ndi.cloud.download.internal.signedUrlDiskCache.isoNow(), ...
                        'filesExpireAt', char(filesExpireAt), ...
                        'expiresAt',     char(expiresAt), ...
                        'generatedAt',   char(generatedAt), ...
                        'fileCount',     fileCount, ...
                        'files',         payload.files));
            catch
                return
            end

            tmpPath = [filePath '.tmp.' num2str(feature('getpid')) '.' ...
                num2str(randi(2^31 - 1))];
            try
                ndi.cloud.download.internal.signedUrlDiskCache.gzipToFile(jsonTxt, tmpPath);
                ndi.cloud.download.internal.signedUrlDiskCache.atomicRename(tmpPath, filePath);
            catch
                if isfile(tmpPath)
                    try %#ok<TRYNC>
                        delete(tmpPath);
                    end
                end
            end
        end

        function forget(datasetId, documentId, seriesName)
        %FORGET Remove one scope's cache file. Best-effort.
        %
        %   Call this from the chunk-download path when an S3 403 says
        %   the cached URL is no longer valid. If the file is not
        %   present -- or the delete itself fails -- it is not an error:
        %   the next lookup will refetch.
            arguments
                datasetId   (1,1) string
                documentId  (1,1) string
                seriesName  (1,1) string = ""
            end
            filePath = ndi.cloud.download.internal.signedUrlDiskCache.cachePath( ...
                datasetId, documentId, seriesName);
            if isfile(filePath)
                try
                    delete(filePath);
                catch
                    % Best-effort: a failed delete is not fatal to the
                    % caller who is already recovering from a 403.
                end
            end
        end

        function d = cacheDir()
        %CACHEDIR Absolute path to the on-disk cache root.
        %
        %   Honors NDI_SIGNED_URL_CACHE_DIR; otherwise
        %   ~/.ndi/signed-url-cache. Creates the directory the first
        %   time it is asked for, with mode 0700 on POSIX so a bearer
        %   token that is legibly a bearer token is not world-readable.
            override = string(getenv('NDI_SIGNED_URL_CACHE_DIR'));
            if strlength(override) > 0
                d = char(override);
            else
                home = char(java.lang.System.getProperty('user.home'));
                d = fullfile(home, '.ndi', 'signed-url-cache');
            end
            if ~isfolder(d)
                try
                    mkdir(d);
                    ndi.cloud.download.internal.signedUrlDiskCache.chmodUserOnly(d);
                catch
                    % Best-effort: batchSignedUrlLookup treats a missing
                    % cache dir as "no disk cache available".
                end
            end
        end
    end

    methods (Static, Access = private)

        function s = safetySeconds()
            override = string(getenv('NDI_SIGNED_URL_CACHE_SAFETY_SECONDS'));
            if strlength(override) > 0
                v = str2double(override);
                if isfinite(v) && v >= 0
                    s = v;
                    return
                end
            end
            s = ndi.cloud.download.internal.signedUrlDiskCache.DefaultSafetySec;
        end

        function p = cachePath(datasetId, documentId, seriesName)
            % Series names can be arbitrary strings (paths, spaces, uni);
            % filesystems can't hold them literally. Follow the escape
            % rule NDI-python will mirror byte-for-byte.
            base = ndi.cloud.download.internal.signedUrlDiskCache.cacheDir();
            dsDir = fullfile(base, char(datasetId));
            if strlength(seriesName) == 0
                fname = [char(documentId) '.json.gz'];
            else
                escaped = ndi.cloud.download.internal.signedUrlDiskCache.escapeSeriesName(char(seriesName));
                fname = [char(documentId) '_' escaped '.json.gz'];
            end
            p = fullfile(dsDir, fname);
        end

        function s = escapeSeriesName(raw)
            % Percent-encode any byte outside [A-Za-z0-9._-]. Uppercase hex.
            % Above MaxEscapedSeriesLen fall back to 'hash-<sha1(raw)>'
            % so a pathologically long name never overflows a filesystem's
            % 255-byte name limit.
            bytes = uint8(unicode2native(raw, 'UTF-8'));
            safe = (bytes >= uint8('A') & bytes <= uint8('Z')) | ...
                   (bytes >= uint8('a') & bytes <= uint8('z')) | ...
                   (bytes >= uint8('0') & bytes <= uint8('9')) | ...
                   (bytes == uint8('.')) | ...
                   (bytes == uint8('_')) | ...
                   (bytes == uint8('-'));
            parts = cell(1, numel(bytes));
            for i = 1:numel(bytes)
                if safe(i)
                    parts{i} = char(bytes(i));
                else
                    parts{i} = sprintf('%%%02X', bytes(i));
                end
            end
            s = strjoin(parts, '');
            if numel(s) > ndi.cloud.download.internal.signedUrlDiskCache.MaxEscapedSeriesLen
                s = ['hash-' ndi.cloud.download.internal.signedUrlDiskCache.sha1Hex(raw)];
            end
        end

        function hex = sha1Hex(raw)
            md = java.security.MessageDigest.getInstance('SHA-1');
            md.update(int8(unicode2native(raw, 'UTF-8')));
            digest = typecast(md.digest(), 'uint8');
            hex = lower(reshape(dec2hex(digest, 2).', 1, []));
        end

        function ensureParentDir(filePath)
            parent = fileparts(filePath);
            if ~isfolder(parent)
                mkdir(parent);
            end
        end

        function chmodUserOnly(dirPath)
            % Bearer tokens for 24 h -- keep world-readable off on POSIX.
            % Windows relies on the default per-user profile ACL for
            % ~/.ndi/, which is roughly equivalent.
            if isunix
                try %#ok<TRYNC>
                    fileattrib(dirPath, '+w', 'u');
                    fileattrib(dirPath, '-w', 'go');
                    fileattrib(dirPath, '-r', 'go');
                    fileattrib(dirPath, '-x', 'go');
                end
            end
        end

        function gzipToFile(txt, outPath)
            % Java's GZIPOutputStream writes a valid single-member gzip
            % that gunzip(1), `tar -xzf`, and NDI-python's gzip module
            % can all read. onCleanup makes the stream close on both
            % normal return and exception; localSafeClose is idempotent
            % so a successful explicit close followed by the cleanup's
            % close is harmless.
            bytes = int8(unicode2native(char(txt), 'UTF-8'));
            fos  = java.io.FileOutputStream(outPath);
            fosCloser = onCleanup(@() localSafeClose(fos)); %#ok<NASGU>
            gzos = java.util.zip.GZIPOutputStream(fos);
            gzosCloser = onCleanup(@() localSafeClose(gzos)); %#ok<NASGU>
            gzos.write(bytes);
            gzos.close();
        end

        function txt = gunzipToString(inPath)
            fis = java.io.FileInputStream(inPath);
            fisCloser = onCleanup(@() localSafeClose(fis)); %#ok<NASGU>
            gzis = java.util.zip.GZIPInputStream(fis);
            gzisCloser = onCleanup(@() localSafeClose(gzis)); %#ok<NASGU>
            baos = java.io.ByteArrayOutputStream();
            buf = javaArray('byte', 8192);
            n = gzis.read(buf);
            while n > 0
                baos.write(buf, 0, n);
                n = gzis.read(buf);
            end
            bytes = typecast(baos.toByteArray(), 'uint8');
            txt = native2unicode(bytes(:).', 'UTF-8');
        end

        function atomicRename(srcPath, dstPath)
            % Files.move(ATOMIC_MOVE, REPLACE_EXISTING) is the one
            % cross-platform API that is atomic on both POSIX (rename(2))
            % and Windows (MoveFileEx MOVEFILE_REPLACE_EXISTING). MATLAB's
            % movefile is not, so we go to Java directly.
            %
            % java.io.File.toPath() avoids the awkward Paths.get(String,
            % String...) varargs call from MATLAB (the varargs array
            % conversion is a moving target across JVMs).
            src = java.io.File(srcPath).toPath();
            dst = java.io.File(dstPath).toPath();
            opts = javaArray('java.nio.file.CopyOption', 2);
            opts(1) = java.nio.file.StandardCopyOption.ATOMIC_MOVE;
            opts(2) = java.nio.file.StandardCopyOption.REPLACE_EXISTING;
            java.nio.file.Files.move(src, dst, opts);
        end

        function s = isoNow()
            dt = datetime('now', 'TimeZone', 'UTC');
            dt.Format = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
            s = char(dt);
        end

        function dt = parseIsoUtc(str)
            % Server sends 'YYYY-MM-DDTHH:MM:SSZ' or 'YYYY-MM-DDTHH:MM:SS.SSSZ'.
            % Strip a trailing 'Z' (or ' +00:00' / '+00:00') and parse as
            % naive UTC. Simpler than juggling MATLAB's timezone format
            % code, which differs across releases.
            str = char(str);
            dt = NaT('TimeZone','UTC');
            if isempty(str)
                return
            end
            % Normalise the trailing UTC marker.
            trimmed = strtrim(str);
            if endsWith(trimmed, 'Z')
                trimmed = trimmed(1:end-1);
            elseif endsWith(trimmed, '+00:00') || endsWith(trimmed, '-00:00')
                trimmed = trimmed(1:end-6);
            end
            trimmed = strrep(trimmed, ' ', 'T');
            candidates = { ...
                'yyyy-MM-dd''T''HH:mm:ss.SSS', ...
                'yyyy-MM-dd''T''HH:mm:ss'};
            for i = 1:numel(candidates)
                try
                    dt = datetime(trimmed, 'InputFormat', candidates{i}, ...
                        'TimeZone','UTC');
                    if ~isnat(dt)
                        return
                    end
                catch
                    % try next
                end
            end
        end

        function v = stringField(s, name)
            v = "";
            if isfield(s, name) && ~isempty(s.(name))
                v = string(s.(name));
                if strlength(v) == 0
                    v = "";
                end
            end
        end

        function v = numericField(s, name, defaultValue)
            v = defaultValue;
            if isfield(s, name) && isnumeric(s.(name)) && ~isempty(s.(name))
                v = double(s.(name));
            end
        end

        function txt = buildJson(rec)
            % Hand-build the JSON so digit-prefixed uid keys survive
            % verbatim -- jsonencode on a containers.Map is a moving
            % target across MATLAB releases, and jsondecode on a struct
            % with digit keys goes through the same rename dance that
            % signedURLFileMap already had to work around.
            E = @(v) jsonencode(string(v));
            parts = {};
            parts{end+1} = sprintf('{"schemaVersion":%d', ...
                ndi.cloud.download.internal.signedUrlDiskCache.SchemaVersion);
            parts{end+1} = sprintf(',"datasetId":%s',     E(rec.datasetId));
            parts{end+1} = sprintf(',"documentId":%s',    E(rec.documentId));
            parts{end+1} = sprintf(',"seriesName":%s',    E(rec.seriesName));
            parts{end+1} = sprintf(',"cachedAt":%s',      E(rec.cachedAt));
            parts{end+1} = sprintf(',"filesExpireAt":%s', E(rec.filesExpireAt));
            parts{end+1} = sprintf(',"expiresAt":%s',     E(rec.expiresAt));
            parts{end+1} = sprintf(',"generatedAt":%s',   E(rec.generatedAt));
            parts{end+1} = sprintf(',"fileCount":%d',     rec.fileCount);
            parts{end+1} = ',"files":';
            parts{end+1} = ndi.cloud.download.internal.signedUrlDiskCache.mapToJson(rec.files);
            parts{end+1} = '}';
            txt = strjoin(parts, '');
        end

        function txt = mapToJson(m)
            ks = keys(m);
            n = numel(ks);
            if n == 0
                txt = '{}';
                return
            end
            parts = cell(1, n);
            for i = 1:n
                k = ks{i};
                v = m(k);
                parts{i} = [jsonencode(string(k)) ':' jsonencode(string(v))];
            end
            txt = ['{' strjoin(parts, ',') '}'];
        end

        function out = parseJson(txt)
            out = [];
            % jsondecode renames field names beginning with a digit,
            % which every did.ido uid does. Reuse the same trick
            % signedURLFileMap uses: decode the whole thing, then
            % rebuild the files map by scanning the raw text for uid
            % keys in payload order. Everything else on the top-level
            % object survives decoding intact.
            data = jsondecode(txt);
            if ~isstruct(data)
                return
            end
            files = containers.Map('KeyType','char','ValueType','any');
            if isfield(data, 'files') && ~isempty(data.files)
                files = ndi.cloud.api.implementation.files.signedURLFileMap( ...
                    data.files, txt);
            end
            out = struct( ...
                'files',         files, ...
                'filesExpireAt', ndi.cloud.download.internal.signedUrlDiskCache.readTopString(data, 'filesExpireAt'), ...
                'expiresAt',     ndi.cloud.download.internal.signedUrlDiskCache.readTopString(data, 'expiresAt'), ...
                'generatedAt',   ndi.cloud.download.internal.signedUrlDiskCache.readTopString(data, 'generatedAt'), ...
                'fileCount',     ndi.cloud.download.internal.signedUrlDiskCache.readTopNumber(data, 'fileCount'));
        end

        function v = readTopString(data, name)
            v = "";
            if isfield(data, name) && ~isempty(data.(name))
                v = string(data.(name));
            end
        end

        function v = readTopNumber(data, name)
            v = 0;
            if isfield(data, name) && isnumeric(data.(name)) && ~isempty(data.(name))
                v = double(data.(name));
            end
        end
    end
end

function localSafeClose(obj)
% Best-effort close for a Java stream inside an onCleanup. Suppresses
% double-close and I/O errors -- the read/write already succeeded or
% already failed, and either way the stream is being torn down.
    if isempty(obj)
        return
    end
    try %#ok<TRYNC>
        obj.close();
    end
end
