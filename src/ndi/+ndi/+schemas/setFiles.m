function [files, sourceDir, layout] = setFiles(treeRoot, pinnedPath)
%NDI.SCHEMAS.SETFILES The schema files of a did-schema tree, tiered or flat.
%
%   [FILES, SOURCEDIR, LAYOUT] = NDI.SCHEMAS.SETFILES(TREEROOT, PINNEDPATH)
%   finds the pinned schema folder under TREEROOT (a did-schema checkout or
%   unpacked tarball) and returns the full paths of the `*.json` files to
%   load from it (FILES, a cellstr, sorted by name), the folder they came
%   from (SOURCEDIR) and which layout it was (LAYOUT):
%
%     'pinned'  the pinned path itself, e.g. schemas/did_v2/stable (tiered)
%     'flat'    the pinned path's parent, read when the pinned path ends in
%               a tier (`stable` or `draft`) that the tree no longer has:
%               Decided by Jess Haley, 2026-10-29 [one folder, final classes
%               only] (did-schema V_eta_go_forward_class_audit.md): "every V2
%               class lives in one folder, `schemas/did_v2/`, with no
%               `stable/` / `draft/` tiers", and the siblings that read the
%               tiers by path read the flat layout first. In the flat folder
%               `index.json` and `topics.json` are not schemas (the class
%               index and the topic list have always sat at the set's root)
%               and are left out.
%
%   [schema set renamed did_v2] (Jess Haley, 2026-10-25), step 1 "accept both
%   names": a pinned schemas/V_eta/... path is looked for under
%   schemas/did_v2/... first, and the other way round.
%
%   Errors NDI:schemas:FetchFailed when no candidate folder exists or the
%   one found holds no schema file.
%
%   See also ndi.schemas.refresh, ndi.schemas.pin.

    arguments
        treeRoot (1,:) char
        pinnedPath (1,:) char
    end

    files = {};
    sourceDir = '';
    layout = '';

    % 1. the pinned folder (either set name)
    for c = setNameCandidates(pinnedPath)
        candidate = fullfile(treeRoot, c{1});
        if isfolder(candidate)
            sourceDir = candidate;
            layout = 'pinned';
            break;
        end
    end

    % 2. its parent, when the pinned folder is a tier the tree no longer has
    if isempty(sourceDir)
        [parent, leaf] = fileparts(regexprep(char(pinnedPath), '[\\/]+$', ''));
        if any(strcmp(leaf, {'stable', 'draft'})) && ~isempty(parent)
            for c = setNameCandidates(parent)
                candidate = fullfile(treeRoot, c{1});
                if isfolder(candidate)
                    sourceDir = candidate;
                    layout = 'flat';
                    break;
                end
            end
        end
    end

    if isempty(sourceDir)
        error('NDI:schemas:FetchFailed', ...
            'Pinned path "%s" not found in %s (nor its flat parent).', ...
            pinnedPath, treeRoot);
    end

    listing = dir(fullfile(sourceDir, '*.json'));
    names = sort({listing.name});
    if strcmp(layout, 'flat')
        names = names(~ismember(names, {'index.json', 'topics.json'}));
    end
    if isempty(names)
        error('NDI:schemas:FetchFailed', ...
            'No *.json schemas found in %s.', sourceDir);
    end
    files = cellfun(@(n) fullfile(sourceDir, n), names, 'UniformOutput', false);
end

function c = setNameCandidates(p)
%SETNAMECANDIDATES The path under schemas/did_v2/ first, then under
%   schemas/V_eta/ (one entry when the path names neither).
p = char(p);
didv2 = regexprep(p, '(^|/)V_eta(/|$)', '$1did_v2$2', 'once');
veta  = regexprep(p, '(^|/)did_v2(/|$)', '$1V_eta$2', 'once');
c = unique({didv2, veta, p}, 'stable');
end
