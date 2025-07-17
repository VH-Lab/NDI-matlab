function savename = webSaveVerbose(filename, url, varargin)
%WEBSAVEVERBOSE Saves web content to a file and prints verbose debugging info.
%   savename = webSaveVerbose(filename, url)
%   savename = webSaveVerbose(filename, url, options)
%
%   Acts as a drop-in replacement for MATLAB's built-in websave function,
%   but adds detailed diagnostic output to help debug download issues.
%   This function is compatible with all MATLAB versions and content types.
%
%   It performs a 4-step process:
%   1. Download & Header Capture: Uses webread, gracefully falling back to a
%      content-only download if headers are not available for the content type.
%   2. Hex Dump: Prints the first 1024 bytes of the content in hex format.
%   3. Save to File: Manually saves the downloaded content to the specified file.
%   4. Verification: Compares file size against Content-Length if available.
%
%   Example:
%       url = 'https://www.ndi-cloud.com/about';
%       filename = 'about.html';
%       webSaveVerbose(filename, url);
%
%   See also websave, webread, weboptions.

% --- 1. Initial Setup ---
fprintf('\n--- webSaveVerbose ---\n');
fprintf('Requesting URL: %s\n', url);
fprintf('Saving to file: %s\n', filename);

% --- 2. Proactively Check User-Agent ---
disp('--- Client Info ---');
% Create a weboptions object to inspect the default User-Agent string.
% This allows us to see the User-Agent even if webread later fails
% to return the full response object.
options = weboptions;
% If user passed in their own options, use them.
if ~isempty(varargin) && isa(varargin{1}, 'matlab.net.http.HTTPOptions')
    options = varargin{1};
end
fprintf('Client User-Agent: %s\n', options.UserAgent);


% --- 3. Download content and headers using a robust try/catch block ---
disp('--- Downloading content and headers (using webread) ---');
response = []; % Initialize response as empty
content = [];  % Initialize content as empty

try
    % Attempt to get both content and response headers. This works on modern
    % MATLAB versions for specific content types (e.g., JSON).
    [content, response] = webread(url, options);
    disp('webread completed (with headers).');
catch ME
    % If the above fails with "Too many output arguments", it means this
    % MATLAB version or content-type doesn't support the two-output syntax.
    if strcmp(ME.identifier, 'MATLAB:maxlhs') || contains(ME.message, 'Too many output arguments')
        disp('Could not retrieve headers (unsupported for this content type or MATLAB version).');
        disp('Falling back to content-only download.');
        content = webread(url, options);
        disp('webread completed (content-only).');
    else
        % If it's a different error (e.g., 404 Not Found), rethrow it.
        fprintf('\n--- DOWNLOAD FAILED during webread ---\n');
        rethrow(ME);
    end
end

% --- 4. Print Diagnostic Info (if available) ---
disp('--- Response Headers ---');
expectedSize = NaN; % Default to NaN if Content-Length is not available

% Only try to print headers if the 'response' variable was populated
if ~isempty(response)
    if isprop(response, 'ContentType') && ~isempty(response.ContentType)
        fprintf('Server Reported Content-Type: %s\n', response.ContentType);
    end

    if isprop(response, 'ContentLength') && ~isempty(response.ContentLength)
        fprintf('Server Reported Content-Length: %s bytes\n', response.ContentLength);
        expectedSize = str2double(response.ContentLength);
    else
        disp('Server did not report Content-Length.');
    end
else
    disp('Header diagnostics skipped.');
end

% --- 5. Hex Dump of First 1024 Bytes ---
disp('--- Hex Dump of First 1024 Bytes ---');
if ~isempty(content)
    numBytesToPrint = min(1024, numel(content));
    bytesToPrint = uint8(content(1:numBytesToPrint)); % Ensure uint8 for dec2hex
    hexStr = dec2hex(bytesToPrint)';
    fprintf('Showing %d of %d bytes:\n', numBytesToPrint, numel(content));
    for i = 1:16:numBytesToPrint
        endIndex = min(i + 15, numBytesToPrint);
        % Address part
        fprintf('%04x: ', i-1);
        % Hex part
        lineHex = hexStr(:, i:endIndex);
        fprintf('%s ', lineHex);
        fprintf('\n');
    end
else
    disp('Content is empty, skipping hex dump.');
end


% --- 6. Manually save the content to a file ---
disp('--- Saving content to file ---');
try
    % Open file for binary writing ('wb') to handle all content types safely
    fileID = fopen(filename, 'wb');
    if fileID == -1
        error('webSaveVerbose:FileOpenError', 'Cannot open file for writing: %s', filename);
    end
    
    % Write the content and close the file
    fwrite(fileID, content);
    fclose(fileID);
    savename = filename; % Set the output argument
    fprintf('Successfully saved content to %s\n', savename);
    
catch ME
    % Ensure file is closed if an error occurs during writing
    if exist('fileID', 'var') && fileID ~= -1
        fclose(fileID);
    end
    error('webSaveVerbose:FileWriteError', 'Failed to write content to file: %s. Error: %s', filename, ME.message);
end


% --- 7. Post-download Verification ---
disp('--- Verification ---');
s = dir(savename);
if isempty(s)
    warning('VERIFICATION FAILED: Output file was not created or is empty.');
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

fprintf('--- webSaveVerbose Finished ---\n\n');

end
