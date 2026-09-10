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
        options.clevel (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.clevel, 1), mustBeLessThanOrEqual(options.clevel, 22)} = 5
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
        'clevel', options.clevel);

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
