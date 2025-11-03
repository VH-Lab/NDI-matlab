function [are_identical, diff_output] = getHexDiff(filename1, filename2, options)
%GETHEXDIFF Compares two files and returns a string with the lines where they differ.
%   [ARE_IDENTICAL, DIFF_OUTPUT] = getHexDiff(FILENAME1, FILENAME2) compares the two files and returns
%   a boolean indicating if they are identical, and a side-by-side hexadecimal view of any 16-byte chunks
%   that are not identical.
%
%   [ARE_IDENTICAL, DIFF_OUTPUT] = getHexDiff(___, Name, Value) specifies additional options using
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
%       [identical, diff_str] = getHexDiff('file_mac.bin', 'file_pc.bin', 'StopByte', 1023);

arguments
    filename1 (1,1) string
    filename2 (1,1) string
    options.StartByte (1,1) {mustBeNumeric, mustBeNonnegative, mustBeInteger} = 0
    options.StopByte (1,1) {mustBeNumeric, mustBeNonnegative} = Inf
end

    output_lines = {};

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
        error('getHexDiff:InvalidRange', 'StartByte (%d) is beyond the end of both files.', startByte);
    end
    if startByte > stopByte
        error('getHexDiff:InvalidRange', 'StartByte (%d) cannot be greater than StopByte (%d).', startByte, stopByte);
    end

    % --- 3. Print header and compare files ---
    output_lines{end+1} = sprintf('Comparing "%s" (%d bytes) with "%s" (%d bytes)', filename1, fileSize1, filename2, fileSize2);
    output_lines{end+1} = 'Displaying only differing 16-byte lines...';
    output_lines{end+1} = repmat('-', 1, 140);

    bytesPerLine = 16;
    differencesFound = false;

    for offset = startByte:bytesPerLine:(stopByte)
        chunkEnd = offset + bytesPerLine - 1;
        chunk1 = getChunk(data1, offset, chunkEnd);
        chunk2 = getChunk(data2, offset, chunkEnd);

        if numel(chunk1) ~= numel(chunk2) || any(chunk1 ~= chunk2)
            if ~differencesFound
                output_lines{end+1} = printHeader();
                differencesFound = true;
            end
            output_lines{end+1} = printDiffLine(offset, chunk1, chunk2);
        end
    end

    are_identical = ~differencesFound;

    if ~differencesFound
        output_lines{end+1} = 'Files are identical in the specified range.';
    end
    output_lines{end+1} = repmat('-', 1, 140);

    diff_output = strjoin(output_lines, '\n');
end

% --- Helper Functions ---

function data = readFileBytes(filename)
    fid = fopen(filename, 'rb');
    if fid == -1
        error('getHexDiff:FileOpenError', 'Cannot open file: %s', filename);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    data = fread(fid, Inf, '*uint8');
end

function chunk = getChunk(data, startOffset, stopOffset)
    startIdx = startOffset + 1;
    stopIdx = stopOffset + 1;
    if startIdx > numel(data)
        chunk = [];
        return;
    end
    chunkEnd = min(stopIdx, numel(data));
    chunk = data(startIdx:chunkEnd);
end

function header_str = printHeader()
    header1 = ' Offset(h)  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |ASCII           |';
    header2 = '  |  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |ASCII           |';
    header_str = [header1 header2];
end

function line_str = printDiffLine(offset, chunk1, chunk2)
    line_parts = {};
    line_parts{end+1} = sprintf('%08x:   ', offset);
    line_parts{end+1} = printChunk(chunk1);
    line_parts{end+1} = '  |  ';
    line_parts{end+1} = printChunk(chunk2);
    line_str = strjoin(line_parts, '');
end

function chunk_str = printChunk(chunk)
    hex_parts = {};
    for k = 1:16
        if k <= numel(chunk)
            hex_parts{end+1} = sprintf('%02X ', chunk(k));
        else
            hex_parts{end+1} = '   ';
        end
        if k == 8, hex_parts{end+1} = ' '; end
    end
    ascii_parts = {};
    for k = 1:16
        if k <= numel(chunk)
            if chunk(k) >= 32 && chunk(k) <= 126
                ascii_parts{end+1} = sprintf('%c', chunk(k));
            else
                ascii_parts{end+1} = '.';
            end
        else
            ascii_parts{end+1} = ' ';
        end
    end
    chunk_str = [strjoin(hex_parts,'') ' |' strjoin(ascii_parts,'') '|'];
end
