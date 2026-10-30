function fetchSchemasAtRef(info, destDir)
%FETCHSCHEMASATREF Download a DID-schema ref and extract the stable tree.
%
%   FETCHSCHEMASATREF(INFO, DESTDIR) downloads the GitHub tarball for
%   INFO.repo at INFO.ref, extracts INFO.path inside it (or, when that
%   tier is gone, its flat parent: ndi.schemas.setFiles), and copies the
%   resulting `*.json` files to DESTDIR.
%
%   The tarball mechanism is the lightest of the three options listed
%   in issue #774 (submodule / tarball / shallow clone): a single HTTPS
%   GET with no git tooling required and no working tree retained.

    arguments
        info  (1,1) struct
        destDir (1,:) char
    end

    if isempty(info.repo)
        error('NDI:schemas:FetchFailed', 'Pin repo is empty.');
    end
    if isempty(info.ref)
        error('NDI:schemas:FetchFailed', 'Pin ref is empty.');
    end

    url = sprintf('https://codeload.github.com/%s/tar.gz/%s', ...
        info.repo, info.ref);

    workDir = tempname();
    mkdir(workDir);
    cleanup = onCleanup(@() rmdirIfExists(workDir));

    tarPath = fullfile(workDir, 'schema.tar.gz');
    try
        websave(tarPath, url);
    catch ME
        error('NDI:schemas:FetchFailed', ...
            'Download failed from %s: %s', url, ME.message);
    end

    try
        files = gunzip(tarPath, workDir); %#ok<NASGU>
        tarFile = fullfile(workDir, 'schema.tar');
        if ~isfile(tarFile)
            % gunzip strips the .gz; resolve to whatever it produced.
            d = dir(fullfile(workDir, '*.tar'));
            if isempty(d)
                error('NDI:schemas:FetchFailed', ...
                    'Could not locate extracted tar file in %s.', workDir);
            end
            tarFile = fullfile(workDir, d(1).name);
        end
        extractDir = fullfile(workDir, 'extract');
        mkdir(extractDir);
        untar(tarFile, extractDir);
    catch ME
        error('NDI:schemas:FetchFailed', ...
            'Extraction failed for %s: %s', tarPath, ME.message);
    end

    % GitHub tarballs unpack to a single top-level dir named
    % <repo>-<ref>/; locate it and join INFO.path.
    entries = dir(extractDir);
    entries = entries(~ismember({entries.name}, {'.', '..'}));
    entries = entries([entries.isdir]);
    if numel(entries) ~= 1
        error('NDI:schemas:FetchFailed', ...
            'Unexpected tarball layout in %s.', extractDir);
    end
    % The pinned folder, or (once did-schema has no tiers) its flat parent:
    % [one folder, final classes only] (Jess Haley, 2026-10-29) and
    % [schema set renamed did_v2] (2026-10-25); see ndi.schemas.setFiles.
    files = ndi.schemas.setFiles(fullfile(extractDir, entries(1).name), info.path);

    if isfolder(destDir)
        % Clear stale contents so the cache exactly mirrors the ref.
        rmdir(destDir, 's');
    end
    mkdir(destDir);

    for k = 1:numel(files)
        [~, n, e] = fileparts(files{k});
        copyfile(files{k}, fullfile(destDir, [n e]));
    end
end

function rmdirIfExists(p)
    if isfolder(p)
        try
            rmdir(p, 's');
        catch
            % best-effort cleanup; tempdir GC will reclaim.
        end
    end
end
