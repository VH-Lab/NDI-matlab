function [pyramidDocs, levelDocs, info] = fromOMEZarr(session, zarrPath, options)
% NDI.FUN.DOC.LIGHTSHEET.FROMOMEZARR - build lightsheetZarrPyramid docs from an OME-Zarr store
%
%   [PYRAMIDDOCS, LEVELDOCS, INFO] = NDI.FUN.DOC.LIGHTSHEET.FROMOMEZARR(...
%       SESSION, ZARRPATH)
%
%   Walks an OME-Zarr (NGFF v0.4) store at ZARRPATH, enumerates its
%   multiscale pyramids with NDR.FORMAT.OMEZARR.LISTPYRAMIDS, and writes
%   a LIGHTSHEETZARRPYRAMID document plus one LIGHTSHEETZARRLEVEL
%   document per level to SESSION.
%
%   ONE DOCUMENT PER REDUCTION. An OME-Zarr store frequently contains
%   both a mean-reduced and a max-projected pyramid. This function writes
%   ONE lightsheetZarrPyramid per multiscales entry it finds; a store
%   with two entries produces two parents and their two ladders of
%   levels.
%
%   ONE DOCUMENT PER LEVEL. NDI documents are immutable, so each
%   resolution level is its own lightsheetZarrLevel document. The level
%   documents depend_on the parent pyramid document.
%
%   READING IS METADATA-ONLY. No chunk bytes are read here; the source
%   store's .zattrs and per-level .zarray are enough to fill the
%   documents. The chunk bytes belong to the source_file_id
%   (fileReference) and are materialized into a level document's
%   `chunk.bin_#` file series by NDI.FUN.DOC.LIGHTSHEET.MAKEPYRAMID.
%   Separating "probe and describe" from "materialize" keeps this
%   function fast enough to run inside a GUI dialog.
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
%                  label. Recognised reductions: 'mean', 'max'. When a
%                  name is not in the map, `pyramid_type` is inspected
%                  first, then a fallback of 'mean' is used with a
%                  warning.
%   pipelineVersion - char/string tag written into
%                     lightsheetZarrPyramid.pipeline_version.
%   sourceFileID - id of an existing fileReference document for
%                  ZARRPATH. When empty, a new fileReference is created
%                  via NDI.FUN.DOC.LIGHTSHEET.MAKESOURCEFILE.
%
%   INFO returns a struct with fields:
%     zarrPath         - absolute path resolved
%     pyramids         - the raw output of ndr.format.omezarr.listPyramids
%     reductions       - cellstr, one per created pyramid, giving the
%                        reduction assigned to it
%     sourceFileID     - id of the fileReference document used
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
    end

    if isempty(strtrim(options.subjectID))
        error('NDI:lightsheet:fromOMEZarr:noSubject', ...
            ['A lightsheetZarrPyramid depends_on a subject; pass ' ...
             '''subjectID'' or use NDI.FUN.DOC.LIGHTSHEET.MAKESOURCEFILE ' ...
             'first and then this function.']);
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

    sourceFileID = options.sourceFileID;
    if isempty(sourceFileID)
        srcDoc = ndi.fun.doc.lightsheet.makeSourceFile(session, zarrPath);
        sourceFileID = srcDoc.id();
    end

    n = numel(pyramids);
    pyramidDocs = cell(n, 1);
    levelDocsPerPyramid = cell(n, 1);
    reductions = cell(n, 1);

    for i = 1:n
        reduction = pickReduction(pyramids(i), options.reductionMap);
        reductions{i} = reduction;
        [pDoc, lDocs] = ndi.fun.doc.lightsheet.makePyramid(session, ...
            pyramids(i), ...
            'reduction', reduction, ...
            'subjectID', options.subjectID, ...
            'elementID', options.elementID, ...
            'sourceFileID', sourceFileID, ...
            'pipelineVersion', options.pipelineVersion);
        pyramidDocs{i} = pDoc;
        levelDocsPerPyramid{i} = lDocs;
    end

    levelDocs = vertcat(levelDocsPerPyramid{:});

    info = struct( ...
        'zarrPath', char(zarrPath), ...
        'pyramids', pyramids, ...
        'reductions', {reductions}, ...
        'sourceFileID', sourceFileID);
end

function r = pickReduction(pyramid, reductionMap)
% pickReduction - choose 'mean' or 'max' for this pyramid entry
%
%   Preference: explicit map by name, then by type, then a heuristic:
%   pyramid.type == 'max' -> 'max', anything else -> 'mean'. Warns when
%   falling back because pyramid.type is unreliable (the historical
%   writer of this format sometimes labeled the mean pyramid 'gaussian').
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
