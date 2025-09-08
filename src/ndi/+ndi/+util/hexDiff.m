function hexDiff(filename1, filename2, options)
%HEXDIFF Compares two files and displays the lines where they differ.
%   hexDiff(FILENAME1, FILENAME2) compares the two files and prints a
%   side-by-side hexadecimal view of any 16-byte chunks that are not identical.
%
%   hexDiff(___, Name, Value) specifies additional options using
%   name-value pairs.
%
%   Optional Name-Value Arguments:
%   'StartByte' - A non-negative integer specifying the zero-based byte
%                 offset at which to start the comparison. Defaults to 0.
%   'StopByte'  - A non-negative integer specifying the zero-based byte
%                 offset at which to end the comparison. Defaults to the
%                 end of the longer file.
%
%   Example:
%       % Compare two files from the beginning to byte 1023
%       hexDiff('file_mac.bin', 'file_pc.bin', 'StopByte', 1023);

arguments
    filename1 (1,1) string
    filename2 (1,1) string
    options.StartByte (1,1) {mustBeNumeric, mustBeNonnegative, mustBeInteger} = 0
    options.StopByte (1,1) {mustBeNumeric, mustBeNonnegative} = Inf
end

% --- 1. Read file contents ---
data1 = readFileBytes(filename1);
data2 = readFileBytes(filename2);

fileSize1 = numel(data1);
fileSize2 = numel(data2);
maxSize = max(fileSize1, fileSize2);

% --- 2. Validate byte range ---
startByte = options.StartByte;
stopByte = options.StopByte;

if isinf(stopByte)
    stopByte = maxSize - 1;
end
if stopByte < 0
    stopByte = -1; % Allows for empty file comparison
end


if startByte >= maxSize && maxSize > 0
    error('hexDiff:InvalidRange', 'StartByte (%d) is beyond the end of both files.', startByte);
end
if startByte > stopByte
    error('hexDiff:InvalidRange', 'StartByte (%d) cannot be greater than StopByte (%d).', startByte, stopByte);
end

% --- 3. Print header and compare files ---
fprintf('Comparing "%s" (%d bytes) with "%s" (%d bytes)\n', filename1, fileSize1, filename2, fileSize2);
disp('Displaying only differing 16-byte lines...');
disp(repmat('-', 1, 140));

bytesPerLine = 16;
differencesFound = false;

for offset = startByte:bytesPerLine:(stopByte)
    
    chunkEnd = offset + bytesPerLine - 1;
    
    % Get chunks for both files
    chunk1 = getChunk(data1, offset, chunkEnd);
    chunk2 = getChunk(data2, offset, chunkEnd);
    
    % Compare chunks. nansum is used because NaN ~= NaN.
    % If lengths are different or content is different, they are not equal.
    if numel(chunk1) ~= numel(chunk2) || any(chunk1 ~= chunk2)
        if ~differencesFound
            % Print the header only if we find a difference
            printHeader();
            differencesFound = true;
        end
        
        % Print the differing line
        printDiffLine(offset, chunk1, chunk2);
    end
end

if ~differencesFound
    disp('Files are identical in the specified range.');
end
disp(repmat('-', 1, 140));

end

% --- Helper Functions ---

function data = readFileBytes(filename)
    % Reads entire file into a uint8 array.
    fid = fopen(filename, 'rb');
    if fid == -1
        error('hexDiff:FileOpenError', 'Cannot open file: %s', filename);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    data = fread(fid, Inf, '*uint8');
end

function chunk = getChunk(data, startOffset, stopOffset)
    % Extracts a chunk of data, handling out-of-bounds access.
    % Note: Offsets are 0-based, data is 1-based.
    startIdx = startOffset + 1;
    stopIdx = stopOffset + 1;
    
    if startIdx > numel(data)
        chunk = [];
        return;
    end
    
    chunkEnd = min(stopIdx, numel(data));
    chunk = data(startIdx:chunkEnd);
end

function printHeader()
    % Prints the main header for the diff output.
    header1 = ' Offset(h)  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |ASCII           |';
    header2 = '  |  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |ASCII           |';
    disp([header1 header2]);
    disp(repmat('-', 1, 140));
end

function printDiffLine(offset, chunk1, chunk2)
    % Prints a single side-by-side line of differing data.
    fprintf('%08x:   ', offset);
    
    % Print File 1 Hex and ASCII
    printChunk(chunk1);
    
    fprintf('  |  ');
    
    % Print File 2 Hex and ASCII
    printChunk(chunk2);
    
    fprintf('\n');
end

function printChunk(chunk)
    % Prints the hex and ASCII for a single 16-byte chunk.
    % Hex part
    for k = 1:16
        if k <= numel(chunk)
            fprintf('%02X ', chunk(k));
        else
            fprintf('   '); % Pad with spaces
        end
        if k == 8, fprintf(' '); end
    end
    
    % ASCII part
    fprintf(' |');
    for k = 1:16
        if k <= numel(chunk)
            if chunk(k) >= 32 && chunk(k) <= 126
                fprintf('%c', chunk(k));
            else
                fprintf('.');
            end
        else
            fprintf(' '); % Pad with spaces
        end
    end
    fprintf('|');
end
