function [are_identical, diff_output] = getHexDiffFromFileObj(f1, f2, options)
%GETHEXDIFFFROMFILEOBJ Compares two file objects and returns a string with the lines where they differ.
%   [ARE_IDENTICAL, DIFF_OUTPUT] = getHexDiffFromFileObj(F1, F2) compares two file objects
%   and returns a boolean indicating if they are identical, and a side-by-side hexadecimal view of any
%   16-byte chunks that are not identical.
%
%   [ARE_IDENTICAL, DIFF_OUTPUT] = getHexDiffFromFileObj(___, Name, Value) specifies additional options using
%   name-value pairs.
%
%   Optional Name-Value Arguments:
%   'StartByte' - A non-negative integer specifying the zero-based byte
%                 offset at which to start the comparison. Defaults to 0.
%   'StopByte'  - A non-negative integer specifying the zero-based byte
%                 offset at which to end the comparison. Defaults to the
%                 end of the longer file.
%
arguments
    f1
    f2
    options.StartByte (1,1) {mustBeNumeric, mustBeNonnegative, mustBeInteger} = 0
    options.StopByte (1,1) {mustBeNumeric, mustBeNonnegative} = Inf
end

    output_lines = {};

    fseek(f1.fid, 0, 'eof');
    fileSize1 = ftell(f1.fid);
    fseek(f2.fid, 0, 'eof');
    fileSize2 = ftell(f2.fid);
    maxSize = max(fileSize1, fileSize2);

    startByte = options.StartByte;
    stopByte = options.StopByte;

    if isinf(stopByte)
        stopByte = maxSize - 1;
    end
    if stopByte < 0
        stopByte = -1;
    end

    fseek(f1.fid, startByte, 'bof');
    fseek(f2.fid, startByte, 'bof');

    output_lines{end+1} = 'Comparing file objects...';
    output_lines{end+1} = 'Displaying only differing 16-byte lines...';
    output_lines{end+1} = repmat('-', 1, 140);

    bytesPerLine = 16;
    differencesFound = false;
    offset = startByte;

    while offset <= stopByte && (~feof(f1.fid) || ~feof(f2.fid))
        chunk1 = fread(f1.fid, bytesPerLine, '*uint8');
        chunk2 = fread(f2.fid, bytesPerLine, '*uint8');

        if numel(chunk1) ~= numel(chunk2) || any(chunk1 ~= chunk2)
            if ~differencesFound
                output_lines{end+1} = printHeader();
                differencesFound = true;
            end
            output_lines{end+1} = printDiffLine(offset, chunk1, chunk2);
        end
        offset = offset + bytesPerLine;
    end

    are_identical = ~differencesFound;

    if ~differencesFound
        output_lines{end+1} = 'File objects are identical in the specified range.';
    end
    output_lines{end+1} = repmat('-', 1, 140);

    diff_output = strjoin(output_lines, '\n');
end

% --- Helper Functions ---
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
