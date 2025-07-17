function savename = webSaveVerbose(filename, url, varargin)
%WEBSAVEVERBOSE Saves web content to a file and prints verbose debugging info.
%   savename = webSaveVerbose(filename, url)
%   savename = webSaveVerbose(filename, url, options)
%
%   Acts as a drop-in replacement for MATLAB's built-in websave function,
%   but adds detailed diagnostic output to help debug download issues.
%   This function is compatible with both old and new versions of MATLAB.
%
%   It performs a 3-step process:
%   1. Download & Header Capture: Uses webread to get the content. It tries
%      to get response headers if the MATLAB version supports it.
%   2. Save to File: Manually saves the downloaded content to the specified file.
%   3. Verification: Compares file size against Content-Length if available.
%
%   Example:
%       url = 'https://www.mathworks.com/images/mathworks-logo.svg';
%       filename = 'matlab_logo.svg';
%       webSaveVerbose(filename, url);
%
%   See also websave, webread, weboptions.

% --- 1. Initial Setup ---
fprintf('\n--- webSaveVerbose ---\n');
fprintf('Requesting URL: %s\n', url);
fprintf('Saving to file: %s\n', filename);

% --- 2. Download content and headers using webread ---
disp('--- Downloading content and headers (using webread) ---');
response = []; % Initialize response as empty
try
    % TRY the modern, two-output syntax first.
    [content, response] = webread(url, varargin{:});
    disp('webread (modern syntax) completed.');
catch ME
    % CATCH the error if it's the "Too many outputs" issue on older MATLAB.
    if strcmp(ME.identifier, 'MATLAB:maxlhs') || contains(ME.message, 'Too many output arguments')
        disp('Older MATLAB version detected. Falling back to single-output webread.');
        disp('Header information will not be available.');
        content = webread(url, varargin{:});
        disp('webread (legacy syntax) completed.');
    else
        % If it's a different error, rethrow it.
        fprintf('\n--- DOWNLOAD FAILED during webread ---\n');
        rethrow(ME);
    end
end

% --- 3. Print Diagnostic Info (if available) ---
disp('--- Response Headers ---');
expectedSize = NaN; % Default to NaN if Content-Length is not available

% Only try to print headers if the 'response' variable was populated
if ~isempty(response)
    % Print debugging info from the response, checking if fields exist first
    if isprop(response, 'Request') && isprop(response.Request, 'UserAgent')
        fprintf('Client User-Agent: %s\n', response.Request.UserAgent);
    end

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
    disp('Header diagnostics skipped (not supported on this MATLAB version).');
end


% --- 4. Manually save the content to a file ---
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


% --- 5. Post-download Verification ---
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
