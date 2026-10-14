function [x, Y] = lawnProfileRead(P, imageNum)
%LAWNPROFILEREAD One image's patch intensity profiles from analyzeGFP.
%
%   [X, Y] = lawnProfileRead(P, IMAGENUM), P from lawnProfileReader. X is the
%   1 x nBins distance from the patch edge (mm; negative outside the patch,
%   1 um steps); Y is nPatches x nBins, the background-normalised intensity
%   in each bin, NaN where a patch has no pixels at that distance. Rows are
%   in the order analyzeLawnProfiles numbered the patches (bwlabel), the
%   order of that image's lawnAnalysis rows. Both are empty when the image
%   is not in the file or no patch was found in it. Decision #64.

x = []; Y = [];
if ~isKey(P.byImage, imageNum)
    return;
end
k = P.byImage(imageNum);
if ~P.hdf5
    x = P.loaded.distances{k};
    Y = P.loaded.pixelValuesNormalized{k};
    return;
end
fid = H5F.open(P.file, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
c = onCleanup(@() H5F.close(fid));
x = deref(fid, '/lawnProfiles/distances', P.refs.distances(:, k));
Y = deref(fid, '/lawnProfiles/pixelValuesNormalized', P.refs.pixelValuesNormalized(:, k));
x = reshape(double(x), 1, []);
Y = double(Y);
if ~isempty(Y) && size(Y, 2) ~= numel(x) && size(Y, 1) == numel(x)
    Y = Y.';
end
end

function v = deref(fid, path, ref)
d = H5D.open(fid, path);
cd = onCleanup(@() H5D.close(d));
try
    o = H5R.dereference(d, 'H5R_OBJECT', ref);
catch
    o = H5R.dereference(d, 'H5P_DEFAULT', 'H5R_OBJECT', ref);
end
co = onCleanup(@() H5O.close(o));
v = [];
try
    a = H5A.open(o, 'MATLAB_empty');     % an empty array: MATLAB stores only its size
    H5A.close(a);
    return;
catch
end
v = H5D.read(o);
end
