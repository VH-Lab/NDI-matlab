function info = pin(varargin)
%NDI.SCHEMAS.PIN Read or update the DID-schema pin.
%
%   INFO = NDI.SCHEMAS.PIN() returns the current pin as a struct with
%   fields `repo`, `ref`, and `path`.
%
%   INFO = NDI.SCHEMAS.PIN(REF) writes REF (a commit SHA or tag) to the
%   pin file and returns the updated struct. The repo and path keep
%   their current values.
%
%   INFO = NDI.SCHEMAS.PIN(REF, 'repo', REPO, 'path', PATH) also
%   overrides the repository (e.g. 'waltham-data-science/did-schema')
%   and/or source path. PATH is the set-version *root*
%   (e.g. 'schemas/V_epsilon') — the directory holding index.json and
%   the stable/draft/deprecated tier folders — so the did2 schema cache
%   resolves classes across tiers via the index.
%
%   Updating the pin does not refresh the cache. Call
%   NDI.SCHEMAS.REFRESH afterwards to fetch the new schemas.
%
%   See also ndi.schemas.refresh, ndi.schemas.init.

    arguments (Repeating)
        varargin
    end

    pinFile = pinFilePath();
    info = readPinFile(pinFile);

    if isempty(varargin)
        return;
    end

    ref = varargin{1};
    if ~(ischar(ref) || (isstring(ref) && isscalar(ref)))
        error('NDI:schemas:InvalidPinRef', ...
            'REF must be a char vector or scalar string.');
    end
    info.ref = char(ref);

    opts = struct(varargin{2:end});
    if isfield(opts, 'repo'); info.repo = char(opts.repo); end
    if isfield(opts, 'path'); info.path = char(opts.path); end

    writePinFile(pinFile, info);
end

function info = readPinFile(pinFile)
    if ~isfile(pinFile)
        info = struct( ...
            'repo', 'waltham-data-science/did-schema', ...
            'ref',  '', ...
            'path', 'schemas/V_epsilon');
        return;
    end
    raw = jsondecode(fileread(pinFile));
    info = struct( ...
        'repo', getOr(raw, 'repo', 'waltham-data-science/did-schema'), ...
        'ref',  getOr(raw, 'ref',  ''), ...
        'path', getOr(raw, 'path', 'schemas/V_epsilon'));
end

function writePinFile(pinFile, info)
    parent = fileparts(pinFile);
    if ~isfolder(parent); mkdir(parent); end
    fid = fopen(pinFile, 'wt');
    if fid < 0
        error('NDI:schemas:PinWriteFailed', ...
            'Could not write pin file: %s', pinFile);
    end
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s\n', jsonencode(info, 'PrettyPrint', true));
end

function v = getOr(s, name, default)
    if isfield(s, name) && ~isempty(s.(name))
        v = char(string(s.(name)));
    else
        v = default;
    end
end
