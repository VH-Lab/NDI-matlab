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
%   See also: ndi.util.getHexDiffFromBytes

arguments
    filename1 (1,1) string
    filename2 (1,1) string
    options.StartByte (1,1) {mustBeNumeric, mustBeNonnegative, mustBeInteger} = 0
    options.StopByte (1,1) {mustBeNumeric, mustBeNonnegative} = Inf
end

    data1 = readFileBytes(filename1);
    data2 = readFileBytes(filename2);

    [are_identical, diff_output] = ndi.util.getHexDiffFromBytes(data1, data2, ...
        'StartByte', options.StartByte, 'StopByte', options.StopByte);

end

function data = readFileBytes(filename)
    fid = fopen(filename, 'rb');
    if fid == -1
        error('getHexDiff:FileOpenError', 'Cannot open file: %s', filename);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    data = fread(fid, Inf, '*uint8');
end
