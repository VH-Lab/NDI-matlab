function [out, vals, sz] = readSparse(filename)
% ndi.util.readSparse - read a sparse N-dimensional array from an .ndisparse file
%
% A = ndi.util.readSparse(FILENAME)
% [SUBS, VALS, SZ] = ndi.util.readSparse(FILENAME)
%
% Reads a sparse array written by ndi.util.writeSparse (or by the NDI-python
% ndi_sparse writer) in the NDI sparse array binary format.
%
% The return value depends on the number of requested outputs:
%
%   A = ndi.util.readSparse(FILENAME)
%       If the stored array is 2-D, A is returned as a MATLAB sparse matrix.
%       If it is N-dimensional (N>2), MATLAB has no native sparse type, so A
%       is returned as a struct with fields 'subs' (nnz-by-ndims, 1-based),
%       'vals' (nnz-by-1), and 'size' (1-by-ndims).
%
%   [SUBS, VALS, SZ] = ndi.util.readSparse(FILENAME)
%       Always returns the raw coordinate-list form regardless of the number
%       of dimensions: SUBS is an nnz-by-ndims matrix of 1-based subscripts,
%       VALS is an nnz-by-1 vector of values, and SZ is the 1-by-ndims size of
%       the full array.
%
% Subscripts are stored 0-based on disk and converted to MATLAB's 1-based
% convention here. See ndi.util.writeSparse for the full format description.
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   A = ndi.util.readSparse('activity.ndisparse');       % 3x4 sparse matrix
%   [subs,vals,sz] = ndi.util.readSparse('activity.ndisparse');
%
% See also: ndi.util.writeSparse, SPARSE, FIND

    fid = fopen(filename, 'r', 'l'); % little-endian
    if fid<0
        error('ndi:util:readSparse:cannotOpen', ...
            'Could not open %s for reading.', filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    magic = fread(fid, 8, 'uint8=>uint8')';
    if ~isequal(magic, uint8('NDISPARS'))
        error('ndi:util:readSparse:badMagic', ...
            '%s is not an NDI sparse file (bad magic string).', filename);
    end
    version = fread(fid, 1, 'uint32=>double');
    if version~=1
        error('ndi:util:readSparse:badVersion', ...
            'Unsupported NDI sparse format version %d in %s.', version, filename);
    end
    ndims_ = fread(fid, 1, 'uint32=>double');
    sz = fread(fid, ndims_, 'uint64=>double')';
    nnz_ = fread(fid, 1, 'uint64=>double');

    subs = zeros(nnz_, ndims_);
    for d=1:ndims_
        subs(:,d) = fread(fid, nnz_, 'uint64=>double') + 1; % 0-based -> 1-based
    end
    vals = fread(fid, nnz_, 'double=>double');

    if nargout>=2
        % raw coordinate-list form requested
        out = subs;
        return;
    end

    % single-output convenience form
    if ndims_<=2
        m = sz(1);
        if numel(sz)>=2, n = sz(2); else, n = 1; end
        if isempty(subs)
            out = sparse(m, n);
        elseif ndims_==1
            out = sparse(subs(:,1), 1, vals, m, 1); % 1-D -> column vector
        else
            out = sparse(subs(:,1), subs(:,2), vals, m, n);
        end
    else
        out = struct('subs', subs, 'vals', vals, 'size', sz);
    end

end % readSparse()
