function hexDump(filename, options)
%HEXDUMP Displays the hexadecimal and ASCII content of a file.
%   hexDump(FILENAME) displays the entire content of the file specified
%   by FILENAME.
%
%   hexDump(FILENAME, Name, Value) specifies additional options using
%   name-value pairs.
%
%   Optional Name-Value Arguments:
%   'StartByte' - A non-negative integer specifying the zero-based byte
%                 offset at which to start the dump. Defaults to 0.
%   'StopByte'  - A non-negative integer specifying the zero-based byte
%                 offset at which to end the dump. Defaults to the end
%                 of the file.
%
%   Example:
%       % Dump the first 256 bytes of a file
%       hexDump('my_data.bin', 'StopByte', 255);
%
%   Example:
%       % Dump a 128-byte block starting at byte 1024
%       hexDump('my_data.bin', 'StartByte', 1024, 'StopByte', 1024+127);

arguments
    filename (1,1) string
    options.StartByte (1,1) {mustBeNumeric, mustBeNonnegative, mustBeInteger} = 0
    % CORRECTED: Removed 'mustBeInteger' validator to allow Inf as a default.
    options.StopByte (1,1) {mustBeNumeric, mustBeNonnegative} = Inf 
end

% --- 1. Open file and set up cleanup ---
fid = fopen(filename, 'rb');
if fid == -1
    error('hexDump:FileOpenError', 'Cannot open file: %s', filename);
end
% Use onCleanup to ensure the file is always closed, even if errors occur.
cleanupObj = onCleanup(@() fclose(fid));

% --- 2. Determine file size and validate byte range ---
fseek(fid, 0, 'eof');
fileSize = ftell(fid);
fseek(fid, 0, 'bof'); % Rewind to the beginning

% *** FIX: Handle empty file case first to prevent range errors ***
if fileSize == 0
    disp('-----------------------------------------------------------------------------');
    fprintf(' Hex Dump of: %s\n', filename);
    fprintf(' File Size: 0 bytes\n');
    disp('-----------------------------------------------------------------------------');
    disp('No data to display in the specified range.');
    disp('-----------------------------------------------------------------------------');
    return;
end

startByte = options.StartByte;
stopByte = options.StopByte;

% If StopByte is Inf, set it to the last byte of the file.
if isinf(stopByte)
    stopByte = fileSize - 1;
end

% Validate the requested byte range against the actual file size.
if startByte >= fileSize
    error('hexDump:InvalidRange', 'StartByte (%d) is beyond the end of the file (size: %d bytes).', startByte, fileSize);
end
if stopByte >= fileSize
    warning('hexDump:AdjustedStopByte', 'StopByte (%d) is beyond the end of the file. Adjusting to %d.', stopByte, fileSize - 1);
    stopByte = fileSize - 1;
end
if startByte > stopByte
    % This case can now only be triggered by user input, not by an empty file.
    error('hexDump:InvalidRange', 'StartByte (%d) cannot be greater than StopByte (%d).', startByte, stopByte);
end

% --- 3. Read the specified data chunk from the file ---
fseek(fid, startByte, 'bof');
bytesToRead = stopByte - startByte + 1;
data = fread(fid, bytesToRead, '*uint8');

if isempty(data)
    disp('No data to display in the specified range.');
    return;
end

% --- 4. Print the formatted hex dump ---
disp('-----------------------------------------------------------------------------');
fprintf(' Hex Dump of: %s\n', filename);
fprintf(' File Size: %d bytes\n', fileSize);
fprintf(' Displaying bytes %d through %d\n', startByte, stopByte);
disp('-----------------------------------------------------------------------------');
fprintf(' Offset(h)  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |ASCII           |\n');
disp('-----------------------------------------------------------------------------');

bytesPerLine = 16;
for offset = 0:bytesPerLine:(numel(data)-1)
    
    % Get the chunk of data for the current line (up to 16 bytes)
    chunkEnd = min(offset + bytesPerLine, numel(data));
    chunk = data(offset+1 : chunkEnd);
    
    % Print the current file offset (address)
    currentAddress = startByte + offset;
    fprintf('%08x:   ', currentAddress);
    
    % Print the hexadecimal representation of the bytes
    for k = 1:16
        if k <= numel(chunk)
            fprintf('%02X ', chunk(k));
        else
            fprintf('   '); % Pad with spaces if the line is short
        end
        if k == 8
            fprintf(' '); % Add an extra space in the middle for readability
        end
    end
    
    % Print the ASCII representation of the bytes
    fprintf(' |');
    for k = 1:numel(chunk)
        if chunk(k) >= 32 && chunk(k) <= 126
            % Character is printable
            fprintf('%c', chunk(k));
        else
            % Character is not printable, show a dot
            fprintf('.');
        end
    end
    fprintf('|\n');
end
disp('-----------------------------------------------------------------------------');

end
