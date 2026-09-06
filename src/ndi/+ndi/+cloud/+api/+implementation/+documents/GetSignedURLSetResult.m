classdef GetSignedURLSetResult < ndi.cloud.api.call
%GETSIGNEDURLSETRESULT Fetches and parses the blob a signed-url-set job produced.
%
%   A ready signed-url-set job reports a resultUrl: a presigned 24 h GET for a
%   gzipped JSON body of shape
%
%       { jobId, datasetId, documentId, generatedAt, fileCount, files: {uid: url} }
%
%   This downloads that blob and returns the map. The download goes through
%   ndi.cloud.api.files.getFile, which does not add an Authorization header --
%   the resultUrl is already presigned, and adding one makes S3 reject it.

    properties
        resultUrl (1,1) string
    end

    methods
        function this = GetSignedURLSetResult(args)
            %GETSIGNEDURLSETRESULT Creates a new GetSignedURLSetResult call.
            arguments
                args.resultUrl (1,1) string
            end
            this.resultUrl = args.resultUrl;
            this.endpointName = 'get_signed_url_set_job';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Downloads and parses the result blob.
            %
            %   Outputs:
            %       b      - True if the blob was downloaded and parsed.
            %       answer - On success, a struct with fields:
            %                  files       - containers.Map from uid to signed URL
            %                  fileCount   - count the server reported
            %                  generatedAt - when the server built the map
            %                On failure, a struct with field 'error'.
            %       apiResponse - Always [] (the download does not go through
            %                     matlab.net.http).
            %       apiURL      - The result URL that was fetched.

            % answer is assigned on every path below, so it is not
            % pre-initialized. apiResponse stays [] by design: the download
            % does not go through matlab.net.http.
            b = false;
            apiResponse = [];
            apiURL = this.resultUrl;

            localFile = [tempname '.signedurlset'];
            cleanup = onCleanup(@() localDelete(localFile));

            % Download through ndi.cloud.api.files.getFile rather than websave.
            % That path defaults to curl, which requests identity encoding so
            % the gateway does not hand back a body websave would auto-inflate
            % and corrupt -- the same hazard that made getFile prefer curl in
            % the first place, and this blob is gzipped.
            [downloaded, downloadAnswer] = this.downloadTo(localFile);
            if ~downloaded
                answer = struct('error', downloadAnswer);
                return
            end

            try
                txt = localReadPossiblyGzipped(localFile);
            catch ME
                answer = struct('error', ME.message);
                return
            end

            data = jsondecode(txt);

            decodedFiles = [];
            if isstruct(data) && isfield(data, 'files')
                decodedFiles = data.files;
            end

            answer = struct();
            answer.files = ndi.cloud.api.implementation.documents.signedURLFileMap(...
                decodedFiles, txt);
            answer.fileCount = localNumericField(data, 'fileCount', answer.files.Count);
            answer.generatedAt = localCharField(data, 'generatedAt');

            b = true;
        end
    end

    methods (Access = protected)
        function [ok, answer] = downloadTo(this, localFile)
            %DOWNLOADTO Fetch the result blob. Seam: a test subclass overrides
            %   this to drop a canned blob at LOCALFILE, so the gzip detection
            %   and parsing can be exercised without a network.
            [ok, answer] = ndi.cloud.api.files.getFile(this.resultUrl, localFile);
        end
    end
end

function txt = localReadPossiblyGzipped(localFile)
%LOCALREADPOSSIBLYGZIPPED Read a file that may or may not still be gzipped.
%   Whether a presigned GET hands back the compressed bytes or a body the
%   transport already inflated depends on the object's Content-Encoding, so
%   decide from the gzip magic number rather than assuming either.
    fid = fopen(localFile, 'rb');
    if fid < 0
        error('NDI:CloudApi:SignedURLSet:CannotReadResult', ...
            'Could not open the downloaded result blob.');
    end
    raw = fread(fid, inf, '*uint8')';
    fclose(fid);

    if numel(raw) >= 2 && raw(1) == 31 && raw(2) == 139   % 0x1f 0x8b
        gzFile = [localFile '.gz'];
        outDir = [localFile '_out'];
        movefile(localFile, gzFile);
        restore = onCleanup(@() localCleanupGz(gzFile, outDir));
        names = gunzip(gzFile, outDir);
        if isempty(names)
            error('NDI:CloudApi:SignedURLSet:EmptyArchive', ...
                'The downloaded result blob decompressed to nothing.');
        end
        txt = fileread(names{1});
    else
        txt = native2unicode(raw, 'UTF-8');
    end
end

function localCleanupGz(gzFile, outDir)
    localDelete(gzFile);
    if isfolder(outDir)
        rmdir(outDir, 's');
    end
end

function localDelete(f)
    if exist(f, 'file') == 2
        delete(f);
    end
end

function value = localCharField(data, name)
    value = '';
    if isstruct(data) && isfield(data, name) && ~isempty(data.(name))
        v = data.(name);
        if isstring(v), v = char(v); end
        if ischar(v), value = v; end
    end
end

function value = localNumericField(data, name, defaultValue)
    value = defaultValue;
    if isstruct(data) && isfield(data, name) && isnumeric(data.(name)) && ...
            isscalar(data.(name))
        value = data.(name);
    end
end
