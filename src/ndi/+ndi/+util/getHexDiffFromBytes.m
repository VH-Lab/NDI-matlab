function [are_identical, diff_output] = getHexDiffFromBytes(data1, data2, options)
%GETHEXDIFFFROMBYTES Compares two uint8 arrays and returns a string with the lines where they differ.
%   [ARE_IDENTICAL, DIFF_OUTPUT] = getHexDiffFromBytes(DATA1, DATA2) compares two uint8 arrays
%   and returns a boolean indicating if they are identical, and a side-by-side hexadecimal view of any
%   16-byte chunks that are not identical.
%
%   [ARE_IDENTICAL, DIFF_OUTPUT] = getHexDiffFromBytes(___, Name, Value) specifies additional options using
%   name-value pairs.
%
%   Optional Name-Value Arguments:
%   'StartByte' - A non-negative integer specifying the zero-based byte
%                 offset at which to start the comparison. Defaults to 0.
%   'StopByte'  - A non-negative integer specifying the zero-based byte
%                 offset at which to end the comparison. Defaults to the
%                 end of the longer array.
%
%   Example:
%       data1 = uint8([1 2 3 4]);
%       data2 = uint8([1 2 5 4]);
%       [identical, diff_str] = getHexDiffFromBytes(data1, data2);

arguments
    data1 (1,:) uint8
    data2 (1,:) uint8
    options.StartByte (1,1) {mustBeNumeric, mustBeNonnegative, mustBeInteger} = 0
    options.StopByte (1,1) {mustBeNumeric, mustBeNonnegative} = Inf
end

    output_lines = {};

    arraySize1 = numel(data1);
    arraySize2 = numel(data2);
    maxSize = max(arraySize1, arraySize2);

    startByte = options.StartByte;
    stopByte = options.StopByte;

    if isinf(stopByte)
        stopByte = maxSize - 1;
    end
    if stopByte < 0
        stopByte = -1;
    end

    if startByte >= maxSize && maxSize > 0
        error('getHexDiff:InvalidRange', 'StartByte (%d) is beyond the end of both arrays.', startByte);
    end
    if startByte > stopByte
        error('getHexDiff:InvalidRange', 'StartByte (%d) cannot be greater than StopByte (%d).', startByte, stopByte);
    end

    output_lines{end+1} = sprintf('Comparing byte array 1 (%d bytes) with byte array 2 (%d bytes)', arraySize1, arraySize2);
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
        output_lines{end+1} = 'Arrays are identical in the specified range.';
    end
    output_lines{end+1} = repmat('-', 1, 140);

    diff_output = strjoin(output_lines, '\n');
end

% --- Helper Functions ---
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
