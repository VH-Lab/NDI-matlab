function report = extractLawnProfiles(source, destination)
%EXTRACTLAWNPROFILES Copy the E. coli profile curves and background fits into a small file.
%
%   REPORT = ndi.setup.conv.haley.extractLawnProfiles(SOURCE, DESTINATION)
%   reads analyzeGFP's workspace SOURCE (e.g. analyzeGFP_24-04-04.mat, 119 GB)
%   one image at a time and writes to DESTINATION only what the import uses
%   (ecoliDocuments, decisions #60 and #64):
%
%     lawnProfiles.imageNum               1 x nImages
%     lawnProfiles.distances              1 x nImages cell, each image's
%                                         distance from the patch edge (mm)
%     lawnProfiles.pixelValuesNormalized  1 x nImages cell, each image's
%                                         nPatches x nBins curves
%     backgroundInfo                      the background fits table
%
%   The images inside lawnProfiles (~170 GB) are never read. Point the
%   import at the result with import_V2(..., 'EcoliProfilesFile',
%   DESTINATION), or save it as ecoli/analyzeGFP_24-04-04.mat beside
%   bacteria.mat, where the import looks by default.
%
%   REPORT: images (denominator), withCurves, curves (patches in all),
%   backgroundRows, destination, bytes.

arguments
    source (1,:) char {mustBeFile}
    destination (1,:) char
end

P = lawnProfileReader(source);
n = numel(P.imageNums);
lawnProfiles = struct('imageNum', P.imageNums, 'distances', {cell(1, n)}, ...
    'pixelValuesNormalized', {cell(1, n)});
withCurves = 0;
curves = 0;
fprintf('DENOMINATOR: %d image(s) in %s\n', n, source);
for k = 1:n
    [x, Y] = lawnProfileRead(P, P.imageNums(k));
    lawnProfiles.distances{k} = x;
    lawnProfiles.pixelValuesNormalized{k} = Y;
    if ~isempty(Y)
        withCurves = withCurves + 1;
        curves = curves + size(Y, 1);
    end
    if mod(k, 250) == 0
        fprintf('  %d / %d images read\n', k, n);
    end
end

backgroundInfo = table();
w = whos('-file', source);
if any(strcmp({w.name}, 'backgroundInfo'))
    S = load(source, 'backgroundInfo');
    backgroundInfo = S.backgroundInfo;
end
save(destination, 'lawnProfiles', 'backgroundInfo', '-v7');

d = dir(destination);
report = struct('images', n, 'withCurves', withCurves, 'curves', curves, ...
    'backgroundRows', height(backgroundInfo), 'destination', destination, 'bytes', d.bytes);
fprintf(['%d image(s) read, %d with curves, %d curve(s) in all; %d background row(s); ' ...
    'wrote %s (%.1f MB)\n'], n, withCurves, curves, height(backgroundInfo), destination, d.bytes / 1e6);
end
