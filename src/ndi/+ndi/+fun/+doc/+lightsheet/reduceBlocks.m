function out = reduceBlocks(arr, factor, reduction, outClass)
% NDI.FUN.DOC.LIGHTSHEET.REDUCEBLOCKS - block-reduce an N-D array, vectorized
%
%   OUT = ndi.fun.doc.lightsheet.REDUCEBLOCKS(ARR, FACTOR, REDUCTION)
%   OUT = ndi.fun.doc.lightsheet.REDUCEBLOCKS(ARR, FACTOR, REDUCTION, OUTCLASS)
%
%   Downsamples ARR by the per-axis integer FACTOR (one entry per axis
%   of ARR, trailing singleton axes included; a scalar applies to every
%   axis) using REDUCTION, 'mean' or 'max'. Output element i along an
%   axis covers input elements (i-1)*f+1 .. i*f; the trailing block may
%   be partial and is reduced over the elements it has, so an axis of
%   length 5 with factor 2 gives 3 outputs (blocks of 2, 2 and 1). These
%   are the semantics of ndr.format.omezarr.reduce and of the NGFF
%   writers whose pyramids NDI ingests, so a pyramid built here matches
%   one built by spim2zarr.
%
%   OUTCLASS (default: the class of ARR) is the class of OUT. A 'mean'
%   into an integer class is rounded to nearest.
%
%   Vectorized one axis at a time: a block's mean is the mean of the
%   per-axis means (the block is a Cartesian product), and likewise for
%   max, so this costs a handful of whole-array operations instead of
%   one loop iteration per output voxel. The mean is accumulated in
%   single precision for 8- and 16-bit inputs (exact sums for blocks up
%   to 256 voxels) and in double otherwise.
%
%   Example:
%     out = ndi.fun.doc.lightsheet.reduceBlocks(uint16(magic(5)), [2 2], 'mean');
%
%   See also: ndr.format.omezarr.reduce, ndi.fun.doc.lightsheet.fromSPIM

    arguments
        arr {mustBeNumeric}
        factor (1,:) double {mustBePositive, mustBeInteger}
        reduction (1,:) char {mustBeMember(reduction, {'mean','max'})}
        outClass (1,:) char = class(arr)
    end

    if isscalar(factor)
        factor = repmat(factor, 1, ndims(arr));
    end
    if numel(factor) < ndims(arr)
        error('NDI:lightsheet:reduceBlocks:badFactor', ...
            'factor has %d entries for a %d-D array.', numel(factor), ndims(arr));
    end
    sz = size(arr, 1:numel(factor));

    if strcmp(reduction, 'mean')
        if any(strcmp(class(arr), {'uint8','int8','uint16','int16','single'}))
            work = single(arr);
        else
            work = double(arr);
        end
    else
        work = arr;
    end

    for d = 1:numel(factor)
        f = factor(d);
        if f == 1 || sz(d) == 1
            continue;   % nothing to reduce along this axis
        end
        work = reduceAxis(work, d, f, reduction);
        sz(d) = size(work, d);
    end

    if strcmp(reduction, 'mean') && ~any(strcmp(outClass, {'single','double'}))
        work = round(work);
    end
    out = cast(work, outClass);
end

function A = reduceAxis(A, d, f, reduction)
% Reduce A along axis D by factor F, trailing partial block included.
    n = size(A, d);
    m = ceil(n / f);
    pad = m * f - n;
    nd = max(ndims(A), d);
    sz = size(A, 1:nd);
    if pad > 0
        padSz = sz;
        padSz(d) = pad;
        switch reduction
            case 'mean'
                % Zeros add nothing to the sum; the last block's divisor
                % is corrected below.
                A = cat(d, A, zeros(padSz, 'like', A));
            case 'max'
                % Repeat the last element: it cannot change the max.
                idx = repmat({':'}, 1, nd);
                idx{d} = repmat(n, 1, pad);
                A = cat(d, A, A(idx{:}));
        end
        sz(d) = m * f;
    end
    % Split axis d into (f, m) and reduce over the f part.
    newSz = [sz(1:d-1), f, m, sz(d+1:end)];
    A = reshape(A, newSz);
    switch reduction
        case 'mean'
            A = sum(A, d);
            counts = repmat(f, 1, m);
            counts(end) = n - (m - 1) * f;
            cshape = ones(1, numel(newSz));
            cshape(d + 1) = m;
            A = A ./ reshape(cast(counts, 'like', A), cshape);
        case 'max'
            A = max(A, [], d);
    end
    outSz = sz;
    outSz(d) = m;
    A = reshape(A, outSz);
end
