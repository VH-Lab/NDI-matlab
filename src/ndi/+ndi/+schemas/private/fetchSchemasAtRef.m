function fetchSchemasAtRef(info, destDir)
%FETCHSCHEMASATREF Download a DID-schema ref and extract the schema set.
%
%   FETCHSCHEMASATREF(INFO, DESTDIR) downloads the GitHub tarball for
%   INFO.repo at INFO.ref, extracts INFO.path inside it, and copies the
%   set-version tree to DESTDIR. For the index.json + tier-folder layout
%   (V_epsilon), this copies index.json plus each stable/draft/deprecated
%   tier's `*.json`, preserving the tier subfolders so the did2 cache
%   resolves classes across tiers. A flat directory (pre-index layout)
%   is copied verbatim.
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
    sourceDir = fullfile(extractDir, entries(1).name, info.path);
    if ~isfolder(sourceDir)
        error('NDI:schemas:FetchFailed', ...
            'Pinned path "%s" not found in tarball.', info.path);
    end

    if isfolder(destDir)
        % Clear stale contents so the cache exactly mirrors the ref.
        rmdir(destDir, 's');
    end
    mkdir(destDir);

    copySchemaSet(sourceDir, destDir);
end

function copySchemaSet(srcDir, destDir)
    % Copy a set-version directory in the index.json + tier-folder
    % layout (V_epsilon): the top-level *.json (index.json and any meta
    % files at the root) plus each tier subfolder's *.json. Falls back
    % to a flat copy (pre-index layout, e.g. a bare V_delta/stable pin)
    % when no tier subfolders are present.
    tiers = {'stable', 'draft', 'deprecated'};
    tierDirsPresent = false;
    for k = 1:numel(tiers)
        if isfolder(fullfile(srcDir, tiers{k}))
            tierDirsPresent = true;
            break;
        end
    end

    if ~tierDirsPresent
        % Flat layout: copy the directory's *.json verbatim.
        copyJsonFiles(srcDir, destDir, true);
        return;
    end

    % Index layout. Top-level *.json must include index.json.
    if ~isfile(fullfile(srcDir, 'index.json'))
        error('NDI:schemas:FetchFailed', ...
            'index.json not found at set-version root %s.', srcDir);
    end
    copyJsonFiles(srcDir, destDir, false);
    for k = 1:numel(tiers)
        tierSrc = fullfile(srcDir, tiers{k});
        if ~isfolder(tierSrc)
            continue;
        end
        tierDest = fullfile(destDir, tiers{k});
        if ~isfolder(tierDest)
            mkdir(tierDest);
        end
        copyJsonFiles(tierSrc, tierDest, false);
    end
end

function copyJsonFiles(srcDir, destDir, requireNonEmpty)
    listing = dir(fullfile(srcDir, '*.json'));
    if isempty(listing)
        if requireNonEmpty
            error('NDI:schemas:FetchFailed', ...
                'No *.json schemas found in %s.', srcDir);
        end
        return;
    end
    for k = 1:numel(listing)
        copyfile( ...
            fullfile(srcDir, listing(k).name), ...
            fullfile(destDir, listing(k).name));
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
