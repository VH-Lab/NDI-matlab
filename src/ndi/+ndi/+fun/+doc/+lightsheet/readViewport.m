function [img, info] = readViewport(session, pyramidDoc, region, options)
% NDI.FUN.DOC.LIGHTSHEET.READVIEWPORT - read a rectangle out of a pyramid
%
%   [IMG, INFO] = NDI.FUN.DOC.LIGHTSHEET.READVIEWPORT(SESSION,
%       PYRAMIDDOC, REGION, options)
%
%   Reads a region of interest from a lightsheetZarrPyramid at whichever
%   resolution level best matches the requested pixel size.
%
%   PYRAMIDDOC is a lightsheetZarrPyramid ndi.document, or its id.
%   REGION is a struct with fields matching the pyramid's axes_order
%   (e.g. `t`, `c`, `z`, `y`, `x`), each a 1x2 [lo hi] pair in physical
%   coordinates (units per pyramid.voxel_size_units). Missing fields
%   mean "all of that axis".
%
%   Optional Name-Value:
%     targetVoxelSize - the coarsest per-axis voxel size that still
%                       satisfies the caller's rendering target. Passed
%                       to CHOOSELEVEL. Default: the finest level's
%                       voxel size (i.e. level 0).
%     forceLevel      - override the level choice; 0-based level index.
%
%   Returns IMG (numeric array in the level's dtype) and INFO struct
%   with fields `level`, `voxel_size`, `translation`, `axes_order`,
%   `region_used_voxels`.
%
%   THIS FUNCTION HAS TWO BACKENDS.
%     1. If the level document's `n_chunks_stored` is 0, the source
%        OME-Zarr store is still authoritative and we read from it via
%        NDR.FORMAT.OMEZARR.READARRAY on the file named by the
%        fileReference. This is the path exercised by the napari
%        viewer on a session that has been probed but not fully
%        materialized.
%     2. If `n_chunks_stored` is > 0, we read the required chunks from
%        the level document's `chunk.bin_#` file series through the
%        NDI cloud API. That path is a scaffold today; see
%        README-lightsheet-zarr.md.
%
%   See also: ndi.fun.doc.lightsheet.chooseLevel,
%             ndi.fun.doc.lightsheet.levelTable,
%             ndr.format.omezarr.readArray

    arguments
        session (1,1) %#ok<INUSA>
        pyramidDoc   %#ok<INUSA>
        region (1,1) struct %#ok<INUSA>
        options.targetVoxelSize (1,:) double = []
        options.forceLevel (1,1) double {mustBeInteger} = -1
    end

    % Initialise so the return-value-might-be-unset warning is only about
    % the *documented* scaffold state, not a real MATLAB unset. The two
    % backends below will overwrite these before returning normally.
    img = [];
    info = struct();

    t = ndi.fun.doc.lightsheet.levelTable(session, pyramidDoc);
    if height(t) == 0
        error('NDI:lightsheet:readViewport:noLevels', ...
            'Pyramid has no lightsheetZarrLevel documents.');
    end

    if options.forceLevel >= 0
        row = t(t.level == options.forceLevel, :); %#ok<NASGU>
        if isempty(row)
            error('NDI:lightsheet:readViewport:noSuchLevel', ...
                'Requested level %d not present.', options.forceLevel);
        end
    else
        target = options.targetVoxelSize;
        if isempty(target)
            target = t.voxel_size{1};
        end
        [~, row] = ndi.fun.doc.lightsheet.chooseLevel(t, target); %#ok<NASGU>
    end

    error('NDI:lightsheet:readViewport:notImplemented', ...
        ['readViewport is a scaffold in this PR. See README-' ...
         'lightsheet-zarr.md for the two backend paths (source ' ...
         'OME-Zarr and materialized chunks) and their status.']);
end
