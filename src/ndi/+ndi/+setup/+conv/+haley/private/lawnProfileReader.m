function P = lawnProfileReader(file)
%LAWNPROFILEREADER Open analyzeGFP's lawnProfiles for reading, one image at a time.
%
%   P = lawnProfileReader(FILE) reads the image numbers of `lawnProfiles` in
%   FILE (analyzeGFP's output, e.g. analyzeGFP_24-04-04.mat; Haley et al.
%   2024, analysis/analyzeGFP.m) and the references to each image's
%   `distances` and `pixelValuesNormalized`, without loading the struct:
%   its image fields (image, imageNormalized, labeled) are ~170 GB. Read one
%   image's curves with lawnProfileRead(P, imageNum). Decision #64.
%
%   A -v7.3 file is HDF5 and is read through its object references. Any
%   other MAT file is small enough to load, and is.
%
%   P fields: file, imageNums (row), byImage (containers.Map imageNum ->
%   position), hdf5 (logical), refs (struct of the two reference arrays,
%   HDF5 only), loaded (the struct, non-HDF5 only).

P = struct('file', file, 'imageNums', [], 'byImage', containers.Map('KeyType', 'double', ...
    'ValueType', 'double'), 'hdf5', false, 'refs', struct(), 'loaded', struct());
if H5F.is_hdf5(file)
    P.hdf5 = true;
    P.imageNums = double(reshape(h5read(file, '/lawnProfiles/imageNum'), 1, []));
    fid = H5F.open(file, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    c = onCleanup(@() H5F.close(fid));
    for f = ["distances", "pixelValuesNormalized"]
        d = H5D.open(fid, "/lawnProfiles/" + f);
        r = H5D.read(d, 'H5T_STD_REF_OBJ', 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT');
        H5D.close(d);
        P.refs.(f) = reshape(r, size(r, 1), []);
    end
else
    S = load(file, 'lawnProfiles');
    P.loaded = S.lawnProfiles;
    P.imageNums = double(reshape(P.loaded.imageNum, 1, []));
end
for k = 1:numel(P.imageNums)
    P.byImage(P.imageNums(k)) = k;
end
end
