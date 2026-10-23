function name = lightsheetChunkName(levelDoc, k)
%LIGHTSHEETCHUNKNAME The file name of a lightsheet level's K-th stored chunk.
%
%   NAME = ndi.vintage.lightsheetChunkName(LEVELDOC, K)
%
%   K is the chunk's ONE-BASED linear index in C order (the index
%   ndi.fun.doc.lightsheet.makePyramid computes and has always put in the
%   name). LEVELDOC is a level in either vintage:
%
%     v1     lightsheetZarrLevel, series `chunk.bin`:  chunk.bin_K
%     V_eta  sampled_body, series `body_data`:         body_data_<K-1>
%
%   The V_eta name is not a different chunk. DID-matlab
%   +migrators_j/lightsheet_zarr_level.m renames the series chunk.bin ->
%   body_data and every member chunk.bin_k -> body_data_{k-1}, because V_eta
%   numbers series members from 0 and v1 from 1 (ndi.vintage.seriesMemberBase);
%   both name the same manifest slot and the same bytes.
%
%   See also: ndi.vintage.seriesMemberBase, ndi.vintage.lightsheetLevel.

arguments
    levelDoc
    k (1,1) double {mustBeInteger, mustBePositive}
end

props = ndi.v2.props(levelDoc);
if isfield(props, 'lightsheetZarrLevel')
    stem = 'chunk.bin';
else
    stem = 'body_data';
end
name = sprintf('%s_%d', stem, k - 1 + ndi.vintage.seriesMemberBase(levelDoc));
end
