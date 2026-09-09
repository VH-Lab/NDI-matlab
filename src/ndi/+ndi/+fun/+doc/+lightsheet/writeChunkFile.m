function [levelDoc, nWritten] = writeChunkFile(session, levelDoc, pyramidEntry, level)
% NDI.FUN.DOC.LIGHTSHEET.WRITECHUNKFILE - materialize a level's chunks into its file series
%
%   [LEVELDOC, NWRITTEN] = NDI.FUN.DOC.LIGHTSHEET.WRITECHUNKFILE(...
%       SESSION, LEVELDOC, PYRAMIDENTRY, LEVEL)
%
%   Reads the OME-Zarr array at LEVEL.path (from a PYRAMIDENTRY as
%   returned by NDR.FORMAT.OMEZARR.LISTPYRAMIDS) chunk by chunk and
%   writes each chunk's raw byte payload to the LEVELDOC's
%   `chunk.bin_#` file series, 1-based, C-order flatten against the
%   chunk grid. Returns the (possibly re-fetched) LEVELDOC and the
%   count of files actually written.
%
%   THIS IS A SCAFFOLD ON MAIN. The end-state design writes only
%   non-fill-value chunks and records their (1-based) chunk index in a
%   small side-index that lives in the level document (chunk_index).
%   Until that side-index lands, this scaffold writes ALL chunks
%   sequentially in C-order (level 0 first chunk = `chunk.bin_1`) so a
%   reader can find any chunk by `1 + ravel(index, chunk_grid,
%   'C-order')`. Sparse pyramids will waste space this way until the
%   index is added. See README-lightsheet-zarr.md.
%
%   Callers are: NDI.FUN.DOC.LIGHTSHEET.MAKEPYRAMID when its option
%   `materializeChunks` is true. Direct callers are welcome; the
%   function is self-contained.

    arguments
        session (1,1) %#ok<INUSA>
        levelDoc (1,1)
        pyramidEntry (1,1) struct %#ok<INUSA>
        level (1,1) struct %#ok<INUSA>
    end

    % Initialise so the return-value-might-be-unset warning is only about
    % the *documented* scaffold state. The real implementation will
    % rewrite levelDoc (with the file-series bumps) and set nWritten.
    nWritten = 0; %#ok<NASGU>

    error('NDI:lightsheet:writeChunkFile:notImplemented', ...
        ['This function is a documented scaffold. Materializing ' ...
         'chunk bytes across the HIPAA-compliant cloud API needs the ' ...
         'binary-file upload machinery that ' ...
         'ndi.cloud.sync.internal.uploadFilesForDatasetDocuments ' ...
         'provides, and a small chunk_index side-file that has not ' ...
         'been designed yet. Track the follow-up in README-' ...
         'lightsheet-zarr.md at the top of the +lightsheet package.']);
end
