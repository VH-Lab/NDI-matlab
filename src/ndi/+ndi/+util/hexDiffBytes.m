function diff_string = hexDiffBytes(data1, data2, options)
%HEXDIFFBYTES Compares two byte arrays and returns a formatted hex diff string.
%   DIFF_STRING = hexDiffBytes(DATA1, DATA2) compares two uint8 arrays
%   and returns a string containing a side-by-side hexadecimal view of any
%   16-byte chunks that are not identical.
%
%   DIFF_STRING = hexDiffBytes(___, Name, Value) specifies additional options
%   using name-value pairs.
%
%   Optional Name-Value Arguments:
%   'StartOffset' - A non-negative integer specifying the zero-based byte
%                   offset at which to start the comparison. Defaults to 0.

arguments
    data1 (1,:) uint8
    data2 (1,:) uint8
    options.StartOffset (1,1) {mustBeNumeric, mustBeNonnegative, mustBeInteger} = 0
end

% --- 1. Setup ---
output_lines = {};
maxSize = max(numel(data1), numel(data2));
bytesPerLine = 16;
differencesFound = false;
startByte = options.StartOffset;

% --- 2. Compare data in chunks ---
for offset = startByte:bytesPerLine:(maxSize - 1)

    chunkEnd = offset + bytesPerLine - 1;

    chunk1 = getChunk(data1, offset, chunkEnd);
    chunk2 = getChunk(data2, offset, chunkEnd);

    if numel(chunk1) ~= numel(chunk2) || any(chunk1 ~= chunk2)
        if ~differencesFound
            output_lines{end+1} = getHeaderString();
            differencesFound = true;
        end
        output_lines{end+1} = getDiffLineString(offset, chunk1, chunk2);
    end
end

% --- 3. Finalize output string ---
if ~differencesFound
    diff_string = ''; % Return empty if no differences, as per getHexDiffFromFileObj's expectation
else
    diff_string = strjoin(output_lines, char(10));
end

end

% --- Helper Functions ---

function chunk = getChunk(data, startOffset, stopOffset)
    startIdx = startOffset + 1;
    stopIdx = stopOffset + 1;

    if startIdx > numel(data)
        chunk = uint8([]);
        return;
    end

    chunkEnd = min(stopIdx, numel(data));
    chunk = data(startIdx:chunkEnd);
end

function header_str = getHeaderString()
    header1 = ' Offset(h)  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |ASCII           |';
    header2 = '  |  00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  |ASCII           |';
    separator = repmat('-', 1, 140);
    header_str = strjoin({[header1 header2], separator}, char(10));
end

function line_str = getDiffLineString(offset, chunk1, chunk2)
    offset_str = sprintf('%08x:   ', offset);
    chunk1_str = getChunkString(chunk1);
    chunk2_str = getChunkString(chunk2);
    line_str = [offset_str, chunk1_str, '  |  ', chunk2_str];
end

function chunk_str = getChunkString(chunk)
    hex_parts = {};
    for k = 1:16
        if k <= numel(chunk)
            hex_parts{end+1} = sprintf('%02X ', chunk(k));
        else
            hex_parts{end+1} = '   ';
        end
        if k == 8, hex_parts{end+1} = ' '; end
    end
    hex_str = [hex_parts{:}];

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
    ascii_str = [ascii_parts{:}];

    chunk_str = [hex_str, ' |', ascii_str, '|'];
end
