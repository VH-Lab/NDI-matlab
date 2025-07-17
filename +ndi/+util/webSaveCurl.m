function savename = webSaveCurl(filename, url, options)
%WEBSAVECURL Saves web content to a file using the system's cURL command.
%   savename = webSaveCurl(filename, url)
%   savename = webSaveCurl(filename, url, Name, Value)
%
%   Acts as a highly robust drop-in replacement for MATLAB's websave,
%   bypassing MATLAB's networking stack entirely. It uses the operating
%   system's native cURL command, which is standard on modern Windows,
%   macOS, and Linux. This avoids platform-specific issues with Java,
%   proxies, or GZIP handling that can cause file corruption.
%
%   On Windows, it attempts to set the console code page to UTF-8 (65001)
%   before running curl to prevent shell-level character encoding corruption.
%
%   REQUIREMENTS:
%   The 'curl' command must be available on the system's path. This is
%   the default for Windows 10 (1803+), Windows 11, macOS, and most
%   Linux distributions.
%
%   It accepts four optional Name-Value arguments:
%   'weboptions'  - A weboptions object, used to set the User-Agent header.
%   'Verbose'     - A logical (true/false) to control diagnostic output.
%   'HTTPVersion' - A string to force a specific HTTP version (e.g., "1.1").
%   'HeaderFields'- A cell array of extra headers to add to the request.
%
%   Example (adding custom headers):
%       ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)...';
%       opts = weboptions('UserAgent', ua);
%       headers = {'Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'; ...
%                  'Accept-Language', 'en-US,en;q=0.5'};
%       savename = webSaveCurl('about.html', '...', 'weboptions', opts, 'HeaderFields', headers);

arguments
    filename (1,1) string
    url (1,1) string
    options.weboptions
    options.Verbose (1,1) logical = false
    options.HTTPVersion (1,1) string = ""
    options.HeaderFields (:,2) cell = {}
end

% --- Handle default options ---
if ~isfield(options, 'weboptions')
    options.weboptions = weboptions;
end

if options.Verbose
    fprintf('\n--- webSaveCurl (Verbose Mode) ---\n');
    fprintf('Requesting URL: %s\n', url);
    fprintf('Saving to file: %s\n', filename);
end

% --- 1. Check for cURL executable ---
if options.Verbose
    disp('--- Checking for cURL executable ---');
end
if ispc
    [status, ~] = system('where curl.exe >nul 2>nul');
else
    [status, ~] = system('which curl >/dev/null 2>&1');
end

if status ~= 0
    error('webSaveCurl:NoCurl', ...
        ['The ''curl'' command was not found on the system path. ' ...
         'This function requires curl, which is standard on modern Windows, macOS, and Linux.']);
end
if options.Verbose
    disp('cURL executable found.');
end

% --- 2. Construct and execute the cURL command ---
if options.Verbose
    disp('--- Downloading content using system cURL ---');
end

% Get the User-Agent from the weboptions object.
userAgent = options.weboptions.UserAgent;

% Build the HTTP version flag if specified
httpFlag = "";
if strlength(options.HTTPVersion) > 0
    switch options.HTTPVersion
        case "1.1"
            httpFlag = "--http1.1";
        case "2"
            httpFlag = "--http2";
        otherwise
            warning('webSaveCurl:UnknownHTTPVersion', 'Unknown HTTPVersion "%s" ignored.', options.HTTPVersion);
    end
end

% Build the custom headers flags
headerFlags = "";
for i = 1:size(options.HeaderFields, 1)
    headerFlags = [headerFlags, sprintf('-H "%s: %s" ', options.HeaderFields{i,1}, options.HeaderFields{i,2})];
end

% Construct the command string.
% -A <agent>: Sets the User-Agent string.
% -H <header>: Adds a custom header.
% -L: Follow redirects (essential for many URLs, including S3)
% -s: Silent mode (no progress meter)
% -S: Show errors if they occur
% -o: Output file
% We enclose filenames, URLs, and the User-Agent in double quotes.
baseCurlCommand = sprintf('curl %s %s -L -s -S -A "%s" -o "%s" "%s"', httpFlag, headerFlags, userAgent, filename, url);

% *** FIX FOR WINDOWS ENCODING CORRUPTION ***
% Prepend the command with 'chcp 65001' on Windows to switch the shell to
% the UTF-8 code page, which may prevent corruption of non-ASCII bytes.
if ispc
    command = ['chcp 65001 && ' baseCurlCommand];
else
    command = baseCurlCommand;
end

if options.Verbose
    fprintf('Client User-Agent: %s\n', userAgent);
    if strlength(httpFlag) > 0
        fprintf('Forcing HTTP Version: %s\n', options.HTTPVersion);
    end
    if ~isempty(headerFlags)
        disp('Adding Custom Headers:');
        disp(options.HeaderFields);
    end
    fprintf('Executing command: %s\n', command);
end

% Execute the command using MATLAB's system function
[status, cmdout] = system(command);

% --- 3. Check for errors ---
if status ~= 0
    error('webSaveCurl:CurlFailed', ...
        'cURL command failed with status %d.\nURL: %s\nOutput:\n%s', ...
        status, url, cmdout);
end

if options.Verbose
    disp('Download completed successfully.');
end

% Return the full path to the saved file
savename = filename;
if options.Verbose
    s = dir(savename);
    if ~isempty(s)
        fprintf('Actual file size on disk: %d bytes\n', s.bytes);
    end
    fprintf('--- webSaveCurl Finished ---\n\n');
end

end
