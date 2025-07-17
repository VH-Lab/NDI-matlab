function savename = webSaveVerbose(filename, url, varargin)
%WEBSAVEVERBOSE Saves web content to a file and prints verbose debugging info.
%   savename = webSaveVerbose(filename, url)
%   savename = webSaveVerbose(filename, url, options)
%
%   Acts as a drop-in replacement for MATLAB's built-in websave function,
%   but adds detailed diagnostic output to help debug download issues.
%
%   It performs a 3-step process:
%   1. Pre-flight Check: Sends a HEAD request to get server headers like
%      Content-Length and Content-Type without downloading the full file.
%   2. Download: Calls the standard websave function to perform the download.
%   3. Verification: Compares the actual size of the downloaded file against
%      the Content-Length reported by the server.
%
%   Example:
%       url = 'https://www.mathworks.com/images/mathworks-logo.svg';
%       filename = 'matlab_logo.svg';
%       webSaveVerbose(filename, url);
%
%   See also websave, weboptions.

% --- 1. Initial Setup and Argument Parsing ---
fprintf('\n--- webSaveVerbose ---\n');
fprintf('Requesting URL: %s\n', url);
fprintf('Saving to file: %s\n', filename);

% Check if a weboptions object was passed in varargin
options = weboptions; % Start with default options
if ~isempty(varargin) && isa(varargin{1}, 'matlab.net.http.HTTPOptions')
    options = varargin{1};
end

% --- 2. Pre-flight Check (HEAD Request) ---
disp('--- Pre-flight Check (HEAD Request) ---');
headOptions = options;
headOptions.RequestMethod = 'head';
expectedSize = NaN; % Default to NaN if Content-Length is not available

try
    % webread with a HEAD request is efficient; it doesn't download the body
    [~, response] = webread(url, headOptions);
    
    % Print debugging info from the HEAD request
    fprintf('Client User-Agent: %s\n', response.Request.UserAgent);
    
    if isfield(response, 'ContentType') && ~isempty(response.ContentType)
        fprintf('Server Reported Content-Type: %s\n', response.ContentType);
    end
    
    if isfield(response, 'ContentLength') && ~isempty(response.ContentLength)
        fprintf('Server Reported Content-Length: %s bytes\n', response.ContentLength);
        expectedSize = str2double(response.ContentLength);
    else
        disp('Server did not report Content-Length.');
    end
    
catch ME
    warning('Pre-flight HEAD request failed. Will attempt full download anyway.');
    fprintf('Error during HEAD request: %s\n', ME.message);
end

% --- 3. Perform the actual download using websave ---
disp('--- Download (using websave) ---');
try
    % Pass the original arguments directly to websave
    savename = websave(filename, url, varargin{:});
    disp('websave command completed.');

    % --- 4. Post-download Verification ---
    disp('--- Verification ---');
    s = dir(savename);
    if isempty(s)
        warning('DOWNLOAD FAILED: Output file was not created or is empty.');
        return;
    end
    actualSize = s.bytes;
    fprintf('Actual file size on disk: %d bytes\n', actualSize);

    % Compare actual size with expected size from Content-Length
    if ~isnan(expectedSize)
        if actualSize == expectedSize
            disp('SUCCESS: Actual file size matches reported Content-Length.');
        else
            fprintf('\n*** WARNING: MISMATCH! ***\n');
            fprintf('Actual size (%d) does NOT match expected size (%d).\n', actualSize, expectedSize);
            disp('This confirms the server sent a different amount of data than advertised.');
            fprintf('*************************\n\n');
        end
    else
        disp('Verification skipped (Content-Length was not available).');
    end

catch ME
    fprintf('\n--- DOWNLOAD FAILED ---\n');
    % Rethrow the error to behave exactly like the original websave
    rethrow(ME);
end

fprintf('--- webSaveVerbose Finished ---\n\n');

end
