function fileMap = signedURLFileMap(decodedFiles, rawPayload)
%SIGNEDURLFILEMAP Build a uid -> signed URL map, preserving the true uids.
%
%   FILEMAP = ndi.cloud.api.implementation.documents.SIGNEDURLFILEMAP(DECODEDFILES, RAWPAYLOAD)
%
%   The signed-url-set endpoints return a JSON object whose keys are DID file
%   uids:
%
%       "files": { "4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6": "https://...", ... }
%
%   MATLAB decodes a JSON object into a struct, and a struct field name cannot
%   begin with a digit. A did.ido uid is NUM2HEX(<serial date>) '_'
%   NUM2HEX(<random>), so it is 16 hex digits, an underscore, and 16 more hex
%   digits -- and it begins with a digit far more often than not. JSONDECODE
%   silently renames those fields (prefixing an 'x'), so reading the uids back
%   off the decoded struct would hand callers uids that do not exist.
%
%   The field ORDER, however, survives decoding. So this function takes the
%   values from the decoded struct (letting JSONDECODE handle string escaping
%   in the URLs) and the keys from the raw payload text (which still has the
%   uids verbatim), and zips them together.
%
%   Inputs:
%       decodedFiles - The decoded `files` value: a struct whose fields are the
%                      (possibly renamed) uids, or [] / empty struct if the page
%                      carried no files.
%       rawPayload   - The raw response payload (uint8 or char). Obtain it by
%                      sending the request with
%                      matlab.net.http.HTTPOptions('SavePayload', true) and
%                      reading apiResponse.Body.Payload.
%
%   Outputs:
%       fileMap      - A containers.Map from uid (char) to signed URL (char).
%                      Empty map when there are no files. ValueType is
%                      'any' because containers.Map requires scalar values for
%                      any other ValueType, and a URL is a char array.
%
%   If the raw payload cannot be scanned (empty, or a key count that disagrees
%   with the decoded struct), this errors rather than returning uids that were
%   silently renamed. A wrong uid is worse than a failed call: it would send
%   the caller to download a file that does not exist, or -- if it happened to
%   collide -- the wrong file.
%
%   See also: ndi.cloud.api.documents.getSignedURLSet

    arguments
        decodedFiles
        rawPayload
    end

    fileMap = containers.Map('KeyType','char','ValueType','any');

    if isempty(decodedFiles) || ~isstruct(decodedFiles)
        return
    end

    values = struct2cell(decodedFiles);
    if isempty(values)
        return
    end

    uids = ndi.cloud.api.implementation.documents.signedURLFileMap_keys(rawPayload);

    if numel(uids) ~= numel(values)
        error('NDI:CloudApi:SignedURLSet:KeyCountMismatch', ...
            ['Recovered %d uid(s) from the raw response but the decoded ' ...
            '`files` object has %d entr(ies). Refusing to guess which uid ' ...
            'goes with which URL.'], numel(uids), numel(values));
    end

    for i = 1:numel(uids)
        v = values{i};
        if isstring(v), v = char(v); end
        if ~ischar(v)
            error('NDI:CloudApi:SignedURLSet:NonStringURL', ...
                'The signed URL for uid "%s" is not a string.', uids{i});
        end
        fileMap(uids{i}) = v;
    end
end
