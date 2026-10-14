function files = fileMetadataArray(rawFiles)
%FILEMETADATAARRAY Normalize decoded {uid, uploaded, size, crc32} records.
%
%   FILES = ndi.cloud.api.implementation.files.FILEMETADATAARRAY(RAWFILES)
%
%   NDI Cloud returns per-file metadata as a JSON array of objects with fields
%   uid, uploaded, size and crc32 (POST /files/lookup `files`, and the
%   signed-url-set `fileInfo`). JSONDECODE turns that into a struct array, a
%   cell array (when the objects differ in fields), or [] (when empty), and
%   turns a null crc32 into []. This returns one consistent shape.
%
%   Inputs:
%       rawFiles - The decoded array: struct array, cell array of structs,
%                  or empty.
%
%   Outputs:
%       files    - Nx1 struct array with fields:
%                    uid      - char
%                    uploaded - logical
%                    size     - double, bytes
%                    crc32    - char, base64 of the big-endian CRC-32 of the
%                               content; '' when the cloud has none (compare
%                               size instead)
%                  Entries without a uid are skipped.
%
%   See also: ndi.cloud.api.files.lookupFiles, ndi.fun.file.crc32

    arguments
        rawFiles
    end

    files = struct('uid', {}, 'uploaded', {}, 'size', {}, 'crc32', {});
    if isempty(rawFiles)
        files = reshape(files, 0, 1);
        return
    end

    n = numel(rawFiles);
    for i = 1:n
        if iscell(rawFiles)
            f = rawFiles{i};
        else
            f = rawFiles(i);
        end
        if ~isstruct(f) || ~isfield(f, 'uid') || isempty(f.uid)
            continue
        end

        entry = struct('uid', char(f.uid), 'uploaded', false, 'size', 0, 'crc32', '');
        if isfield(f, 'uploaded') && ~isempty(f.uploaded)
            entry.uploaded = logical(f.uploaded);
        end
        if isfield(f, 'size') && ~isempty(f.size)
            entry.size = double(f.size);
        end
        if isfield(f, 'crc32') && ~isempty(f.crc32)
            entry.crc32 = char(f.crc32);
        end
        files(end+1, 1) = entry; %#ok<AGROW>
    end
    files = reshape(files, [], 1);
end
