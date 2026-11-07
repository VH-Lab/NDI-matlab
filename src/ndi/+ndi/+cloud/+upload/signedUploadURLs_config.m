function cfg = signedUploadURLs_config(apiUrls, token, outFiles)
% NDI.CLOUD.UPLOAD.SIGNEDUPLOADURLS_CONFIG - the curl config ndi.cloud.upload.signedUploadURLs sends
%
%   CFG = ndi.cloud.upload.signedUploadURLs_config(APIURLS, TOKEN, OUTFILES)
%
%   One block per request: GET APIURLS{i} with the bearer TOKEN, its
%   answer written to OUTFILES{i}, retried by curl on a transient error.
%   Blocks are separated by "next". Separate from signedUploadURLs so it
%   can be tested without a server.

    q = @(x) ['"' strrep(strrep(char(x), '\', '\\'), '"', '\"') '"'];
    n = numel(apiUrls);
    if any(cellfun(@(u) any(char(u) < 32), apiUrls)) || any(char(token) < 32) || ...
            any(cellfun(@(f) any(char(f) < 32), outFiles))
        error('NDI:cloud:signedUploadURLs:controlCharacter', ...
            'A URL, the token or a file name contains a control character.');
    end
    blocks = cell(1, n);
    for i = 1:n
        lines = { ...
            ['url = ' q(apiUrls{i})], ...
            'header = "Accept: application/json"', ...
            ['header = ' q(['Authorization: Bearer ' char(token)])], ...
            ['output = ' q(outFiles{i})], ...
            'fail', 'silent', 'show-error', ...
            'retry = 3', 'connect-timeout = 30', 'max-time = 60'};
        blocks{i} = sprintf('%s\n', lines{:});
    end
    cfg = strjoin(blocks, sprintf('next\n'));
end
