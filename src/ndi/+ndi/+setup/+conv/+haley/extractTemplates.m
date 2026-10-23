function report = extractTemplates(source, destination)
%EXTRACTTEMPLATES Copy analyzeGFP's acetate template registrations into the small extract.
%
%   REPORT = ndi.setup.conv.haley.extractTemplates(SOURCE, DESTINATION)
%   reads `template` from analyzeGFP's workspace SOURCE (e.g.
%   analyzeGFP_24-04-04.mat) WITHOUT its masks (3.5 GB) and appends to
%   DESTINATION (the file extractLawnProfiles wrote):
%
%     template.imageNum, .plateNum, .expNum   1 x N: the brightfield image
%                                             each registration is from
%     template.center                         N x 2, [y x] pixels, AS STORED
%                                             (getAcetateArena: center =
%                                             flip(Centroid))
%     template.offset                         N x 2, as stored
%     template.angle                          1 x N, degrees (regionprops
%                                             Orientation)
%     template.scale                          1 x N, pixels per mm
%
%   Each is the acetate frame (16 x 25 mm) found in one brightfield image
%   (analyzeGFP.m:128-155); a fluorescence image uses its
%   metaData.brightfieldImageNum's. Decision #80.
%
%   REPORT: registrations (denominator), destination.

arguments
    source (1,:) char {mustBeFile}
    destination (1,:) char {mustBeFile}
end

fid = H5F.open(source, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
c = onCleanup(@() H5F.close(fid));
template = struct();
for f = ["imageNum", "plateNum", "expNum", "angle", "scale", "center", "offset"]
    v = readField(fid, "/template/" + f);
    if iscell(v)
        v = cellfun(@(x) reshape(double(x), 1, []), v, 'UniformOutput', false);
        v = vertcat(v{:});
    else
        v = reshape(double(v), 1, []);
    end
    template.(f) = v;
end
n = numel(template.imageNum);
fprintf('DENOMINATOR: %d template registration(s) in %s\n', n, source);
for f = ["plateNum", "expNum", "angle", "scale"]
    if numel(template.(f)) ~= n
        error('ndi:setup:conv:haley:templateShape', 'template.%s has %d entries, imageNum %d.', ...
            f, numel(template.(f)), n);
    end
end
for f = ["center", "offset"]
    if size(template.(f), 1) ~= n || size(template.(f), 2) ~= 2
        error('ndi:setup:conv:haley:templateShape', 'template.%s is %s, not %d x 2.', ...
            f, mat2str(size(template.(f))), n);
    end
end
save(destination, 'template', '-append');
fprintf('appended template (%d registrations, %d plate(s)) to %s\n', n, ...
    numel(unique(template.plateNum)), destination);
report = struct('registrations', n, 'destination', destination);
end

function v = readField(fid, path)
% a struct field of a -v7.3 MAT file: numeric data, or object references
% to one dataset per element (a cell)
arguments
    fid
    path {mustBeText}
end
d = H5D.open(fid, path);
cd = onCleanup(@() H5D.close(d));
t = H5D.get_type(d);
ct = onCleanup(@() H5T.close(t));
if H5T.get_class(t) ~= H5ML.get_constant_value('H5T_REFERENCE')
    v = H5D.read(d);
    return;
end
refs = H5D.read(d, 'H5T_STD_REF_OBJ', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT');
refs = reshape(refs, size(refs, 1), []);
v = cell(1, size(refs, 2));
for k = 1:size(refs, 2)
    try
        o = H5R.dereference(d, 'H5R_OBJECT', refs(:, k));
    catch
        o = H5R.dereference(d, 'H5P_DEFAULT', 'H5R_OBJECT', refs(:, k));
    end
    v{k} = H5D.read(o);
    H5O.close(o);
end
end
