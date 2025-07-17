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
%   REQUIREMENTS:
%   The 'curl' command must be available on the system's path. This is
%   the default for Windows 10 (1803+), Windows 11, macOS, and most
%   Linux distributions.
%
%   It accepts one optional Name-Value argument:
%   'Verbose'    - A logical (true/false) to control whether detailed
%                  debugging information is printed to the console.
%
%   Example (silent):
%       savename = webSaveCurl('logo.svg', 'https://www.mathworks.com/images/mathworks-logo.svg');
%
%   Example (verbose):
%       savename = webSaveCurl('about.html', 'https://www.ndi-cloud.com/about', 'Verbose', true);

arguments
    filename (1,1) string
    url (1,1) string
    options.Verbose (1,1) logical = false
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

% Construct the command string.
% -L: Follow redirects (essential for many URLs, including S3)
% -s: Silent mode (no progress meter)
% -S: Show errors if they occur
% -o: Output file
% We enclose filenames and URLs in double quotes to handle spaces.
command = sprintf('curl -L -s -S -o "%s" "%s"', filename, url);

if options.Verbose
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
