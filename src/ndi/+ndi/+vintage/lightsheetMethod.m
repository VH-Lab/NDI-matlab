function m = lightsheetMethod()
%LIGHTSHEETMETHOD The method term that marks a migrated lightsheet pyramid.
%
%   M = ndi.vintage.lightsheetMethod()
%
%   M is struct('node', 'FBbi:00000369', 'name', 'selective plane
%   illumination fluorescence microscopy') -- light-sheet microscopy (checked
%   on OLS). DID-matlab +migrators_j/lightsheet_zarr_pyramid.m sets it as
%   `interaction.method.term` on the intensity observation it makes of EVERY v1
%   lightsheetZarrPyramid, OME-Zarr and SmartSPIM alike (Jess 2026-10-15). It
%   is what says "lightsheet pyramid" rather than "some fluorescence
%   measurement", so ndi.vintage.lightsheetPyramidDocs finds migrated pyramids
%   by its node. It must stay the migrator's, character for character;
%   ndi.unittest.vintage.TestLightsheetMigrated pins it against the migrator's
%   output when DID-matlab's migrators are on the path.
%
%   (Until 2026-10-15 the marker was the name of the builder `software`
%   entity the observation's software_id names. That entity is still
%   written, as the record of what built the pyramid; it no longer marks it.)
%
%   See also: ndi.vintage.lightsheetPyramidDocs.

m = struct('node', 'FBbi:00000369', ...
    'name', 'selective plane illumination fluorescence microscopy');
end
