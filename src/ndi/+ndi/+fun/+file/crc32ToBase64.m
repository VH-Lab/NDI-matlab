function checksum = crc32ToBase64(value)
%CRC32TOBASE64 Encode a numeric CRC-32 as base64 of its 4-byte big-endian value.
%
% SYNTAX:
%   checksum = ndi.fun.file.crc32ToBase64(value)
%
% DESCRIPTION:
%   NDI Cloud and S3 represent a CRC-32 as the base64 of its four bytes in
%   big-endian order. This converts a numeric CRC-32 (for example from
%   java.util.zip.CRC32.getValue) to that form.
%
% INPUTS:
%   value - The CRC-32 as a number in [0, 4294967295].
%
% OUTPUTS:
%   checksum - 1x8 char base64 string, e.g. 'NhCmhg==' for 0x3610A686.
%
% See also: ndi.fun.file.crc32

    arguments
        value (1,1) {mustBeNumeric, mustBeInteger, mustBeNonnegative, ...
            mustBeLessThanOrEqual(value, 4294967295)}
    end

    v = uint32(value);
    bytes = uint8(bitand(bitshift(v, [-24 -16 -8 0]), uint32(255)));
    checksum = char(matlab.net.base64encode(bytes));
end
