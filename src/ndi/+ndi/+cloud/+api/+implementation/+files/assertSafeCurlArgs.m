function assertSafeCurlArgs(url, localPath)
% ASSERTSAFECURLARGS - validate a URL and local path before curl interpolation
%
%   ndi.cloud.api.implementation.files.assertSafeCurlArgs(URL, LOCALPATH)
%
%   GetFile and PutFiles build a curl command with sprintf and run it through
%   system(). Both the server-supplied pre-signed URL and the local file path
%   are interpolated inside double quotes. Because double quotes in sh do NOT
%   neutralise command substitution, a URL (or path) containing " ` $ or \
%   can break out of the quoting and execute arbitrary shell commands as the
%   MATLAB user. downloadURL is taken verbatim from the getFileDetails API
%   response, so it is fully attacker-controllable for any dataset a user
%   chooses to download.
%
%   This validator closes that hole without changing behaviour for legitimate
%   pre-signed URLs (which are percent-encoded and therefore never contain the
%   forbidden characters or whitespace):
%
%     * URL must parse as an https:// URI with a non-empty host.
%     * URL and LOCALPATH must contain none of: double quote ("), backtick (`),
%       dollar sign ($), backslash (\), or any whitespace/control character.
%
%   Note that '&', '?', '=' -- common in signed URLs -- are intentionally
%   allowed: they are inert inside the double-quoted argument.
%
%   On violation an error with a specific, diagnosable identifier is thrown,
%   following the house pattern of commit 86379c7de.
%
%   Callers that cannot guarantee a shell-safe transfer should instead route
%   the request through the native websave / matlab.net.http path.

    arguments
        url (1,1) string
        localPath (1,1) string
    end

    urlChar  = char(url);
    pathChar = char(localPath);

    % --- URL must be a well-formed https URI ---
    try
        uri = matlab.net.URI(urlChar);
    catch ME
        error('NDI:CloudApi:UnsafeCurlURL', ...
            'Download/upload URL does not parse as a URI: %s', ME.message);
    end
    if ~strcmpi(char(uri.Scheme), 'https')
        error('NDI:CloudApi:UnsafeCurlURL', ...
            'Download/upload URL must use the https scheme (got ''%s'').', ...
            char(uri.Scheme));
    end
    if isempty(char(uri.Host))
        error('NDI:CloudApi:UnsafeCurlURL', ...
            'Download/upload URL must have a non-empty host.');
    end

    % --- Neither argument may carry a shell-quote-breaking character ---
    % The URL must additionally be whitespace-free (a legitimate percent-encoded
    % pre-signed URL never contains a space). The local path is double-quoted in
    % the curl command, so spaces there are legitimate (e.g. "/Users/My Name")
    % and are allowed; only the quote-breaking and control characters are
    % refused for the path.
    assertNoShellMetacharacters(urlChar, 'URL', 'NDI:CloudApi:UnsafeCurlURL', true);
    assertNoShellMetacharacters(pathChar, 'local file path', ...
        'NDI:CloudApi:UnsafeCurlPath', false);
end

function assertNoShellMetacharacters(value, label, errorId, rejectWhitespace)
    % Characters that can escape a double-quoted sh argument (double quotes in
    % sh do not neutralise command substitution, so ` and $ remain dangerous,
    % \ can escape the closing quote, and " terminates it outright).
    forbidden = ['"' '`' '$' '\'];
    idx = find(ismember(value, forbidden), 1);
    if ~isempty(idx)
        error(errorId, ...
            'Refusing to run curl: %s contains the unsafe character ''%s''.', ...
            label, value(idx));
    end
    if any(value < 32) % control characters, including newline/CR/NUL/tab
        error(errorId, ...
            'Refusing to run curl: %s contains a control character.', label);
    end
    if rejectWhitespace && any(isspace(value))
        error(errorId, ...
            'Refusing to run curl: %s contains whitespace.', label);
    end
end
