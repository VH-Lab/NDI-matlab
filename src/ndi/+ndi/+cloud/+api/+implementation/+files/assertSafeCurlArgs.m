function assertSafeCurlArgs(url, localPath, options)
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
%
%   PLATFORM. On Windows, system() runs the command through cmd.exe, not sh.
%   There backslash is the path separator (every tempname() path contains
%   it), and ` and $ have no special meaning; inside double quotes the
%   characters that matter are " (ends the quoted argument) and % (expands
%   environment variables). So on Windows the LOCAL PATH is checked against
%   " and % instead of the sh set. Refusing backslash there rejected every
%   Windows download and upload outright. The URL check is the same on all
%   platforms (a percent-encoded pre-signed URL never contains a backslash).
%
%   ndi.cloud.api.implementation.files.assertSafeCurlArgs(..., 'isWindows', TF)
%   overrides the platform (default ispc()); intended for tests.

    arguments
        url (1,1) string
        localPath (1,1) string
        options.isWindows (1,1) logical = ispc()
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
    shForbidden = ['"' '`' '$' '\'];
    assertNoShellMetacharacters(urlChar, 'URL', 'NDI:CloudApi:UnsafeCurlURL', ...
        true, shForbidden);
    if options.isWindows
        % cmd.exe: " ends the quoted argument and % expands variables;
        % backslash is the path separator and must be allowed.
        pathForbidden = ['"' '%'];
    else
        pathForbidden = shForbidden;
    end
    assertNoShellMetacharacters(pathChar, 'local file path', ...
        'NDI:CloudApi:UnsafeCurlPath', false, pathForbidden);
end

function assertNoShellMetacharacters(value, label, errorId, rejectWhitespace, forbidden)
    % FORBIDDEN lists the characters that can escape a double-quoted argument
    % for the shell in use. For sh: double quotes do not neutralise command
    % substitution, so ` and $ remain dangerous, \ can escape the closing
    % quote, and " terminates it outright. For cmd.exe see the header.
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
