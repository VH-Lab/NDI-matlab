function writeSyncIndex(ndiDataset, syncIndex, options)
%WRITESYNCINDEX Atomically write the sync index for a dataset.
%
% writeSyncIndex(ndiDataset, syncIndex) serialises syncIndex to JSON and
% stores it at <ndiDataset.path>/.ndi/sync/index.json.
%
% The write is atomic. The JSON is written to a temporary file in the same
% directory as the target and then renamed into place with movefile, so a
% concurrent reader never observes a half-written file, and any interruption
% before the rename (jsonencode error, disk full, MATLAB killed, power loss)
% leaves the previous index untouched. This replaces an earlier fopen("wt")
% / fwrite / fclose sequence that truncated the target before the write and
% could leave it empty on any failure -- and because readSyncIndex reads an
% unreadable index as struct.empty and callers treat that as "never synced",
% that truncation would silently reset the dataset's sync state.
%
% Inputs:
%   ndiDataset (1,1) ndi.dataset
%   syncIndex  (1,1) struct
%   options.Verbose (1,1) logical = false
%
% See also: ndi.cloud.sync.internal.index.readSyncIndex,
%           ndi.cloud.sync.internal.index.updateSyncIndex

    arguments
        ndiDataset (1,1) ndi.dataset
        syncIndex  (1,1) struct
        options.Verbose (1,1) logical = false
    end

    indexPath = ndi.cloud.sync.internal.index.getIndexFilepath(...
        ndiDataset.path, "write", "Verbose", options.Verbose);

    encoded = jsonencode(syncIndex);

    % A random suffix keeps two concurrent writers from picking the same
    % temp path (which would let one clobber the other's in-flight write).
    % [~, unique] = fileparts(tempname) is the standard MATLAB way to get a
    % random-per-call token; it does NOT read from the system temp
    % directory, so the token is safe to append to any path.
    [~, uniqueSuffix] = fileparts(tempname);
    tempPath = sprintf('%s.tmp.%s', char(indexPath), uniqueSuffix);

    % The temp file MUST live in the same directory as the target: a rename
    % is only atomic within one filesystem, and MATLAB's tempdir is often
    % on a different volume from a dataset. getIndexFilepath returns a path
    % under <dataset>/.ndi/sync, so ".tmp.<suffix>" alongside it stays on
    % the same volume.

    fid = fopen(tempPath, "wt");
    if fid < 0
        error('NDI:cloud:sync:IndexWriteFailed', ...
            'Could not open %s for writing.', tempPath);
    end

    % Belt-and-braces cleanup. fidCloser guarantees fclose even if fwrite
    % throws, so the handle never leaks. tempCleaner removes a stray temp
    % file on any error path; it is explicitly cleared after a successful
    % rename below, because the rename consumed the temp file and running
    % delete() on that name would then hit the freshly-swapped index.
    fidCloser   = onCleanup(@() iCloseIfOpen(fid)); %#ok<NASGU>
    tempCleaner = onCleanup(@() iDeleteIfExists(tempPath));

    fwrite(fid, encoded);
    clear fidCloser  % flush and close BEFORE the rename

    [renameOk, msg] = movefile(tempPath, char(indexPath), 'f');
    if ~renameOk
        error('NDI:cloud:sync:IndexWriteFailed', ...
            'Could not move %s into place at %s: %s', tempPath, indexPath, msg);
    end
    clear tempCleaner
end

function iCloseIfOpen(fid)
    % fclose(-1) errors, and fclose on an already-closed fid also errors;
    % guard both. onCleanup handlers must not throw -- that would mask a
    % more informative error already propagating up the stack.
    if fid >= 0
        try
            fclose(fid);
        catch
            % already closed
        end
    end
end

function iDeleteIfExists(path)
    if isfile(path)
        try
            delete(path);
        catch
            % best-effort cleanup; do not mask an upstream error
        end
    end
end
