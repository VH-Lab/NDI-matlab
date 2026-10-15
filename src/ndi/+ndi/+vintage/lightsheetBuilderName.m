function name = lightsheetBuilderName()
%LIGHTSHEETBUILDERNAME The software entity name that marks a migrated lightsheet pyramid.
%
%   NAME = ndi.vintage.lightsheetBuilderName()
%
%   DID-matlab +migrators_j/lightsheet_zarr_pyramid.m names the `software`
%   entity of every migrated lightsheetZarrPyramid with this string (its
%   BUILDER constant; Jess 2026-10-14, lightsheet point 5), and points the
%   pyramid's observation at it through software_id. It is the one thing on a
%   migrated pyramid that says "lightsheet pyramid" rather than "some
%   fluorescence measurement", so ndi.vintage.lightsheetPyramidDocs finds
%   pyramids by it. It must stay character-for-character the migrator's;
%   ndi.unittest.vintage.TestLightsheetVintage pins it against the migrator
%   when DID-matlab's migrators are on the path.
%
%   See also: ndi.vintage.lightsheetPyramidDocs.

name = 'NDI lightsheet pyramid builder (ndi.fun.doc.lightsheet.makePyramid)';
end
