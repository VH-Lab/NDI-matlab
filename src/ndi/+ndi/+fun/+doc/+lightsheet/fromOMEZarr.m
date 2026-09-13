function [pyramidDoc, levelDocs, info] = fromOMEZarr(session, zarrPath, options)
% NDI.FUN.DOC.LIGHTSHEET.FROMOMEZARR - build lightsheetZarrPyramid docs from an OME-Zarr store
%
%   [PYRAMIDDOC, LEVELDOCS, INFO] = NDI.FUN.DOC.LIGHTSHEET.FROMOMEZARR(...
%       SESSION, ZARRPATH)
%
%   Walks an OME-Zarr (NGFF v0.4) store at ZARRPATH, enumerates its
%   multiscale pyramids with NDR.FORMAT.OMEZARR.LISTPYRAMIDS, and writes
%   ONE lightsheetZarrPyramid document (the source volume) plus one
%   lightsheetZarrLevel document per unique level to SESSION.
%
%   ONE DOCUMENT PER SOURCE VOLUME. The parent describes the source
%   volume; reductions (mean, max, ...) live on the level children.
%   A store with mean and max pyramids produces one parent, not two.
%
%   LEVEL 0 IS DEDUPED. When two NGFF multiscales entries reference
%   the same underlying array (typically level 0: their
%   `datasets[0].path` is the same string), one level document is
%   written -- with reduction_function='none' -- and both readers use
%   it. Reduced levels are per-reduction and get
%   reduction_function='mean'/'max'/... .
%
%   READING IS METADATA-ONLY. No chunk bytes are read here; the
%   source store's .zattrs and per-level .zarray are enough to fill
%   the documents. Materializing chunk bytes into a level document's
%   `chunk.bin_#` file series is follow-up work (see the package
%   README).
%
%   Optional Name-Value Arguments:
%   subjectID  - char/string, id of the subject depended on. If empty,
%                the caller is refused: a lightsheetZarrPyramid without
%                a subject is not a valid document.
%   elementID  - char/string, id of the imaging element the volume was
%                captured on. May be empty.
%   pyramidNames - cellstr/string, restrict to these multiscales.name
%                  values. Empty means all.
%   reductionMap - containers.Map / struct mapping pyramid name (as
%                  reported by listPyramids) or type to a reduction
%                  label ('mean', 'max', ...). When a name is not in
%                  the map, `pyramid_type` is inspected first, then a
%                  fallback of 'mean' is used with a warning.
%   pipelineVersion - char/string tag written into
%                     lightsheetZarrPyramid.pipeline_version.
%   sourceFileID - id of an existing fileReference document for
%                  ZARRPATH. When empty, a new fileReference is created
%                  via NDI.FUN.DOC.LIGHTSHEET.MAKESOURCEFILE.
%   label      - human-readable label written into the parent pyramid.
%   tileBudgetBytes - target uncompressed bytes per chunk when chunk
%                     shape is chosen automatically. Default 8*2^20
%                     (8 MB). Forwarded to makePyramid.
%   chunks     - optional explicit chunk shape (row vector, axes_order).
%                Empty (default) means auto-size from the budget.
%                Forwarded to makePyramid.
%
%   INFO returns a struct with fields:
%     zarrPath          - absolute path resolved
%     pyramids          - the raw output of ndr.format.omezarr.listPyramids
%     reductions        - cellstr, unique reductions present in the ladder
%     sourceFileID      - id of the fileReference document used
%     sharedLevel0      - logical, true if level 0 was shared across
%                         reductions and deduped
%
%   Example:
%     S = ndi.session.dir('mysession','/path/to/session');
%     [P, L, info] = ndi.fun.doc.lightsheet.fromOMEZarr(S, ...
%         '/cloudcache/subject42/volume.ome.zarr', ...
%         'subjectID', subj.id());
%
%   See also: ndi.fun.doc.lightsheet.makePyramid,
%             ndi.fun.doc.lightsheet.chooseLevel,
%             ndi.fun.doc.lightsheet.viewCommand,
%             ndr.format.omezarr.listPyramids,
%             ndr.format.omezarr.probe

    arguments
        session (1,1)
        zarrPath (1,:) char
        options.subjectID char = ''
        options.elementID char = ''
        options.pyramidNames = {}
        options.reductionMap = struct()
        options.pipelineVersion char = ''
        options.sourceFileID char = ''
        options.label char = ''
        options.tileBudgetBytes (1,1) double {mustBePositive} = 8 * 2^20
        options.chunks double = []
        options.materializeChunks (1,1) logical = false
        options.codec (1,:) char {mustBeMember(options.codec, {'raw','blosc-zstd'})} = 'raw'
        options.clevel (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.clevel, 1), mustBeLessThanOrEqual(options.clevel, 9)} = 5
        % progressFcn is one of:
        %   'default'         - the default. Open an NDI
        %                       ProgressBarWindow and drive it.
        %                       Headless MATLAB (CI, -batch) does
        %                       silent bookkeeping only, no figure,
        %                       so this is safe on servers.
        %   function_handle   - progressFcn(fraction, text) is
        %                       called before each level and after
        %                       each chunk write. Use this to feed
        %                       your own dialog or logger.
        %   []                - no reporting at all.
        options.progressFcn = 'default'
        % Number of parallel workers to use for chunk compression.
        %   -1 (default) - use any parpool already open, else serial.
        %    0 / 1       - force serial.
        %    N > 1       - open a parpool of size N.
        % Reads stay serial in all modes; compression fans out.
        % See makePyramid for details.
        options.numWorkers (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.numWorkers, -1)} = -1
        % How much source data to prefetch into RAM per readArray
        % call. Bigger = fewer seeks + subprocess round trips at the
        % cost of more RAM. See makePyramid. Default 512 MB.
        options.prefetchBytes (1,1) double {mustBePositive} = 512 * 2^20
        % Overlap disk reads with parfor compression via parfeval.
        % See makePyramid for details. Default true; ignored when
        % numWorkers resolves to serial.
        options.asyncPrefetch (1,1) logical = true
    end

    if isempty(strtrim(options.subjectID))
        error('NDI:lightsheet:fromOMEZarr:noSubject', ...
            ['A lightsheetZarrPyramid depends_on a subject; pass ' ...
             '''subjectID''.']);
    end

    if ~isfolder(zarrPath)
        error('NDI:lightsheet:fromOMEZarr:noSuchStore', ...
            'OME-Zarr store not found at %s.', zarrPath);
    end

    if ~ndr.format.omezarr.isOMEZarr(zarrPath)
        error('NDI:lightsheet:fromOMEZarr:notOMEZarr', ...
            '%s does not look like an OME-Zarr store (.zattrs missing multiscales).', ...
            zarrPath);
    end

    pyramids = ndr.format.omezarr.listPyramids(zarrPath);
    if isempty(pyramids)
        error('NDI:lightsheet:fromOMEZarr:noPyramids', ...
            '%s reports zero multiscales entries.', zarrPath);
    end

    keep = true(numel(pyramids), 1);
    if ~isempty(options.pyramidNames)
        wanted = cellstr(options.pyramidNames);
        for i = 1:numel(pyramids)
            keep(i) = any(strcmp(pyramids(i).name, wanted));
        end
        if ~any(keep)
            error('NDI:lightsheet:fromOMEZarr:noNamedPyramid', ...
                ['None of the requested pyramid names (%s) matched. ' ...
                 'Available: %s.'], strjoin(wanted, ', '), ...
                strjoin({pyramids.name}, ', '));
        end
    end
    pyramids = pyramids(keep);

    n = numel(pyramids);
    perEntryReduction = cell(n, 1);
    for i = 1:n
        perEntryReduction{i} = pickReduction(pyramids(i), options.reductionMap);
    end

    sourceFileID = options.sourceFileID;
    if isempty(sourceFileID)
        srcDoc = ndi.fun.doc.lightsheet.makeSourceFile(session, zarrPath);
        session.database_add(srcDoc);
        sourceFileID = srcDoc.id();
    end

    % Resolve the progress callback: 'default' -> open an NDI
    % ProgressBarWindow and update it; a function handle -> use it as
    % is; [] -> stay silent. The window's constructor detects headless
    % MATLAB by itself and no-ops without a figure, so CI runs need no
    % special casing here.
    progressFcn = resolveProgressCallback(options.progressFcn, ...
        options.label, char(zarrPath));

    [pyramidDoc, levelDocs, sharedLevel0] = ndi.fun.doc.lightsheet.makePyramid( ...
        session, pyramids, perEntryReduction, ...
        'subjectID', options.subjectID, ...
        'elementID', options.elementID, ...
        'sourceFileID', sourceFileID, ...
        'pipelineVersion', options.pipelineVersion, ...
        'label', options.label, ...
        'tileBudgetBytes', options.tileBudgetBytes, ...
        'chunks', options.chunks, ...
        'materializeChunks', options.materializeChunks, ...
        'sourceZarrPath', char(zarrPath), ...
        'codec', options.codec, ...
        'clevel', options.clevel, ...
        'progressFcn', progressFcn, ...
        'numWorkers', options.numWorkers, ...
        'prefetchBytes', options.prefetchBytes, ...
        'asyncPrefetch', options.asyncPrefetch);

    info = struct( ...
        'zarrPath', char(zarrPath), ...
        'pyramids', pyramids, ...
        'reductions', {unique(perEntryReduction)}, ...
        'sourceFileID', sourceFileID, ...
        'sharedLevel0', sharedLevel0);
end

function r = pickReduction(pyramid, reductionMap)
% pickReduction - choose 'mean' or 'max' for this pyramid entry
%
%   Preference: explicit map by name, then by type, then a heuristic:
%   pyramid.type == 'max' -> 'max', anything else -> 'mean'. Warns when
%   falling back because pyramid.type is unreliable.
    r = '';
    if ~isempty(reductionMap)
        if isstruct(reductionMap)
            if ~isempty(pyramid.name) && isfield(reductionMap, pyramid.name)
                r = char(reductionMap.(pyramid.name));
            elseif ~isempty(pyramid.type) && isfield(reductionMap, pyramid.type)
                r = char(reductionMap.(pyramid.type));
            end
        elseif isa(reductionMap, 'containers.Map')
            if ~isempty(pyramid.name) && isKey(reductionMap, pyramid.name)
                r = char(reductionMap(pyramid.name));
            elseif ~isempty(pyramid.type) && isKey(reductionMap, pyramid.type)
                r = char(reductionMap(pyramid.type));
            end
        end
    end
    if isempty(r)
        t = lower(strtrim(char(pyramid.type)));
        n = lower(strtrim(char(pyramid.name)));
        if strcmp(t, 'max') || contains(n, 'max')
            r = 'max';
        else
            r = 'mean';
            if ~isempty(t) && ~any(strcmp(t, {'mean','box','average'}))
                warning('NDI:lightsheet:fromOMEZarr:reductionFallback', ...
                    ['Pyramid %s has type ''%s''; falling back to ' ...
                     '''mean''. Pass reductionMap to override.'], ...
                    pyramid.name, pyramid.type);
            end
        end
    end
end

function fcn = resolveProgressCallback(spec, label, zarrPath)
% RESOLVEPROGRESSCALLBACK - turn the options.progressFcn spec into a
% callable, opening an NDI ProgressBarWindow when the caller took the
% default. Failures to open the bar are swallowed and the ingest
% continues silently: a bar that could not draw itself must not stop
% a multi-hour ingest.
    if isa(spec, 'function_handle')
        fcn = spec;
        return;
    end
    if isempty(spec)
        fcn = [];
        return;
    end
    if ~(ischar(spec) || (isstring(spec) && isscalar(spec)))
        error('NDI:lightsheet:fromOMEZarr:badProgressFcn', ...
            ['progressFcn must be ''default'', a function handle, ' ...
             'or []. Got a %s.'], class(spec));
    end
    spec = char(string(spec));
    if ~any(strcmpi(spec, {'default', 'auto'}))
        error('NDI:lightsheet:fromOMEZarr:badProgressFcn', ...
            ['progressFcn keyword ''%s'' is not recognised. Use ' ...
             '''default'', a function handle, or [].'], spec);
    end

    barLabel = 'Building lightsheet pyramid';
    if ~isempty(label)
        barLabel = sprintf('Building pyramid: %s', label);
    elseif ~isempty(zarrPath)
        [~, zn] = fileparts(char(zarrPath));
        if ~isempty(zn)
            barLabel = sprintf('Building pyramid: %s', zn);
        end
    end
    tag = sprintf('lightsheet-ingest-%s', localUniqueId());

    fcn = [];
    try
        pbw = ndi.gui.component.ProgressBarWindow('NDI lightsheet ingest');
        pbw.addBar('Label', barLabel, 'Tag', tag, 'Auto', true);
        fcn = @(frac, txt) pbw.updateBar(tag, min(1, max(0, frac)));
    catch
        % Fall through with fcn = [] -- silent.
    end
end

function u = localUniqueId()
% A short unique tag so a second ingest in the same MATLAB does not
% collide with a bar the first one is still holding.
    try
        u = did.ido.unique_id();
        u = char(u);
    catch
        u = char(java.util.UUID.randomUUID().toString());
    end
    if numel(u) > 12, u = u(1:12); end
end
