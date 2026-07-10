function writeSparse(filename, varargin)
% ndi.util.writeSparse - write a sparse N-dimensional array to an .ndisparse file
%
% ndi.util.writeSparse(FILENAME, A)
% ndi.util.writeSparse(FILENAME, SUBS, VALS, SZ)
%
% Writes a sparse array to FILENAME using the NDI sparse array binary format
% (see FORMAT below). The file can be read back with ndi.util.readSparse in
% MATLAB or with ndi_sparse.read_sparse in Python; the two implementations
% produce byte-for-byte identical files.
%
% There are two calling forms:
%
%   ndi.util.writeSparse(FILENAME, A)
%       A is a 2-D MATLAB matrix (sparse or full). Its structural nonzeros
%       (as returned by FIND) are stored; explicit zeros are dropped.
%
%   ndi.util.writeSparse(FILENAME, SUBS, VALS, SZ)
%       An N-dimensional coordinate-list (COO) form.
%         SUBS - an nnz-by-ndims matrix of 1-based subscripts. Row k gives the
%                subscripts of the k-th stored entry.
%         VALS - an nnz-by-1 vector of values (stored as double).
%         SZ   - a 1-by-ndims vector giving the size of the full array along
%                each dimension.
%       In this form the entries are written exactly as given; a value that is
%       exactly zero is preserved (not dropped).
%
% =========================================================================
% FORMAT (the NDI sparse array format, version 1)
% =========================================================================
% All multi-byte fields are little-endian. Subscripts are stored 0-based on
% disk; this function converts the 1-based SUBS to 0-based on write, and
% ndi.util.readSparse converts back to 1-based on read.
%
%   offset  type                     meaning
%   ------  -----------------------  --------------------------------------
%   0       8 x uint8 (ASCII)        magic string 'NDISPARS'
%   8       uint32                   format version (currently 1)
%   12      uint32                   ndims, the number of dimensions
%   16      ndims x uint64           shape (size of each dimension)
%   ...     uint64                   nnz, the number of stored entries
%   ...     ndims blocks of          subscripts, dimension-major, 0-based:
%           nnz x uint64               all nnz indices for dimension 1, then
%                                      all nnz indices for dimension 2, etc.
%   ...     nnz x float64            the stored values, in the same order
%
% =========================================================================
% EXAMPLE
% =========================================================================
%   A = sparse([1 3 3],[1 2 4],[10 20 30.5],3,4);
%   ndi.util.writeSparse('activity.ndisparse', A);
%   B = ndi.util.readSparse('activity.ndisparse'); % B is a 3x4 sparse matrix
%
% See also: ndi.util.readSparse, FIND, SPARSE

    if nargin==2
        A = varargin{1};
        if ~ismatrix(A)
            error('ndi:util:writeSparse:not2D', ...
                ['When called with a single array argument, the array must ' ...
                'be 2-D. Use the (FILENAME, SUBS, VALS, SZ) form for ' ...
                'N-dimensional arrays.']);
        end
        if ~isnumeric(A) && ~islogical(A)
            error('ndi:util:writeSparse:notNumeric', ...
                'The array must be numeric or logical.');
        end
        [i,j,v] = find(A);
        subs = [i(:) j(:)];
        vals = double(v(:));
        sz = size(A);
    elseif nargin==4
        subs = varargin{1};
        vals = double(varargin{2}(:));
        sz = double(varargin{3}(:)).';
        ndims_ = numel(sz);
        if isempty(subs)
            subs = zeros(0, ndims_);
        end
        if size(subs,2)~=ndims_
            error('ndi:util:writeSparse:subsSizeMismatch', ...
                ['SUBS has %d columns but SZ specifies %d dimensions; the ' ...
                'number of SUBS columns must equal numel(SZ).'], ...
                size(subs,2), ndims_);
        end
        if size(subs,1)~=numel(vals)
            error('ndi:util:writeSparse:valsSizeMismatch', ...
                'SUBS has %d rows but VALS has %d entries; they must match.', ...
                size(subs,1), numel(vals));
        end
        if any(subs(:)<1) || any(subs(:)~=round(subs(:)))
            error('ndi:util:writeSparse:badSubs', ...
                'SUBS must contain positive integers (1-based subscripts).');
        end
        for d=1:ndims_
            if ~isempty(subs) && max(subs(:,d))>sz(d)
                error('ndi:util:writeSparse:subsOutOfBounds', ...
                    'A subscript in dimension %d exceeds the size %d.', d, sz(d));
            end
        end
    else
        error('ndi:util:writeSparse:badNargin', ...
            ['Call as ndi.util.writeSparse(FILENAME, A) or ' ...
            'ndi.util.writeSparse(FILENAME, SUBS, VALS, SZ).']);
    end

    ndims_ = numel(sz);
    nnz_ = size(subs,1);

    fid = fopen(filename, 'w', 'l'); % little-endian
    if fid<0
        error('ndi:util:writeSparse:cannotOpen', ...
            'Could not open %s for writing.', filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fwrite(fid, uint8('NDISPARS'), 'uint8');
    fwrite(fid, uint32(1), 'uint32');        % version
    fwrite(fid, uint32(ndims_), 'uint32');
    fwrite(fid, uint64(sz(:)), 'uint64');    % shape
    fwrite(fid, uint64(nnz_), 'uint64');
    for d=1:ndims_
        fwrite(fid, uint64(subs(:,d)-1), 'uint64'); % 0-based on disk
    end
    fwrite(fid, double(vals(:)), 'double');

end % writeSparse()
