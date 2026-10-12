function checksum = crc32(fileName, options)
%CRC32 CRC-32 of a file, base64-encoded the way NDI Cloud and S3 store it.
%
% SYNTAX:
%   checksum = ndi.fun.file.crc32(fileName)
%   checksum = ndi.fun.file.crc32(fileName, 'chunkSize', BYTES)
%
% DESCRIPTION:
%   Computes the CRC-32 (IEEE, the zlib / java.util.zip.CRC32 polynomial) of
%   the file's bytes and returns the base64 of its 4-byte big-endian value.
%   That is the encoding S3 uses for x-amz-checksum-crc32, the value
%   ndi.cloud.api.files.getFileUploadURL sends as checksumCRC32, and the
%   value NDI Cloud returns as a file's crc32 (from getFileDetails, listFiles,
%   lookupFiles and getSignedURLSet). Comparing this to the cloud's crc32
%   tells whether the cloud copy has the same content as the local file.
%
%   The file is read in chunks, so large files do not need to fit in memory.
%
% INPUTS:
%   fileName - Path to the file.
%
% NAME-VALUE INPUTS:
%   chunkSize - Bytes read per chunk (default 8 MiB).
%
% OUTPUTS:
%   checksum - 1x8 char, e.g. 'NhCmhg==' for a file containing 'hello'.
%
% EXAMPLE:
%   c = ndi.fun.file.crc32('chunk.bin_1');
%
% See also: ndi.cloud.api.files.lookupFiles, ndi.cloud.api.files.getFileUploadURL

    arguments
        fileName (1,1) string {mustBeFile}
        options.chunkSize (1,1) double {mustBePositive, mustBeInteger} = 8*1024*1024
    end

    fid = fopen(fileName, 'r');
    if fid < 0
        error('NDI:fun:file:crc32:CannotOpen', 'Could not open file: %s', fileName);
    end
    closer = onCleanup(@() fclose(fid));

    crc = java.util.zip.CRC32();
    while true
        data = fread(fid, options.chunkSize, '*int8');
        if isempty(data)
            break;
        end
        crc.update(data);
    end

    checksum = ndi.fun.file.crc32ToBase64(crc.getValue());
end
