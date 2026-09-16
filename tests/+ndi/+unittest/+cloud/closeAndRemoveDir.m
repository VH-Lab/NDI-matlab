function closeAndRemoveDir(directoryPath)
% closeAndRemoveDir - Close open SQLite handles, then remove a directory tree.
%
%   ndi.unittest.cloud.closeAndRemoveDir(DIRECTORYPATH)
%
%   Closes any open mksqlite database connections and then removes
%   DIRECTORYPATH (and its contents) if it exists. Intended for use in test
%   teardown, where a temporary NDI dataset/session directory must be
%   deleted after the test finishes.
%
%   NDI datasets and sessions keep their DID SQLite database
%   (.ndi/did-sqlite.sqlite) open through mksqlite. On Windows an open file
%   cannot be deleted, so a teardown that calls rmdir on the dataset
%   directory before the SQLite handle is released fails with
%   'MATLAB:RMDIR:SomeDirectoriesNotRemoved'. POSIX platforms silently allow
%   deleting a still-open file, which is why this only bites on Windows.
%   Closing the database first makes teardown deterministic across platforms
%   (see issue #870).
%
%   See also: mksqlite, rmdir

    arguments
        directoryPath (1,1) string
    end

    % Release ALL open SQLite database handles so that Windows will permit
    % the underlying did-sqlite.sqlite file to be deleted. We must pass
    % dbid 0 here: mksqlite('close') defaults to dbid 1 and closes only the
    % first connection, but these tests keep several datasets/sessions open
    % at once (the local dataset plus datasets that sync downloads), so the
    % connection locking the directory being removed is often not dbid 1.
    % mksqlite(0, 'close') closes every open connection; DID reopens lazily
    % on the next operation, so this is safe (issue #870). The call is
    % guarded because mksqlite may not be loaded if no SQLite-backed dataset
    % was opened during the test.
    try
        mksqlite(0, 'close');
    catch
        % Nothing to close (mksqlite not loaded / no open connections).
    end

    if isfolder(directoryPath)
        rmdir(directoryPath, 's');
    end
end
