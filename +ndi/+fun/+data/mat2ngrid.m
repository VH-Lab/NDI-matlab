function [ngrid] = mat2ngrid(x,varargin)
%MAT2NGRID - Create an ngrid structure from an n-dimensional matrix.
%
%   ngrid = MAT2NGRID(X)
%       Creates an ngrid structure from the n-dimensional matrix X, using
%       default indices as coordinates.
%
%   ngrid = MAT2NGRID(X, c1, c2, ..., cn)
%       Creates an ngrid structure from X, using the provided coordinate
%       vectors c1, c2, ..., cn for each dimension.
%
%   Input Arguments:
%       X  - n-dimensional numeric matrix.
%       c1, c2, ..., cn - Coordinate vectors for each dimension of X. Each
%                        ci must be a numeric vector with length matching
%                        size(X, i). All ci must be of the same data type.
%
%   Output Arguments:
%       ngrid - Structure containing the following fields:
%           data_size   - Size of the data type in bytes.
%           data_type   - Class of the data (e.g., 'double').
%           data_dim    - Dimensions of X.
%           coordinates - Vertically concatenated coordinate positions,
%                         size [sum(data_dim), 1].
%
%   Error Handling:
%       - 'MAT2NGRID:defaultCoords': If no coordinates are provided, indices
%         are used, and a warning is issued.
%       - 'MAT2NGRID:invalidCoords': If coordinate vectors are not numeric,
%         not vectors, or have incorrect lengths.
%       - 'MAT2NGRID:tooFewCoords': If fewer coordinates than dimensions of
%         X are provided.
%       - 'MAT2NGRID:tooManyCoords': If more coordinates than dimensions of
%         X are provided.

% Get size, type, and dimension
props = whos('x');
ngrid.data_size = props.bytes/numel(x);
ngrid.data_type = class(x);
ngrid.data_dim = size(x);

% Handle logical
if islogical(x)
    ngrid.data_type = 'ubit1';
end

% Check if coordinates are included. If completely excluded, use indices.
% If partially included, prompt user to fix.
ngrid.coordinates = [];

if nargin == 1
    % warning('MAT2NGRID:defaultCoords', 'Coordinates set to default indices.');
    for i = 1:ndims(x)
        ngrid.coordinates = [ngrid.coordinates; (1:size(x, i))'];
    end
elseif nargin == ndims(x) + 1
    for i = 1:length(varargin)
        if ~isvector(varargin{i})
            error('MAT2NGRID:invalidCoords', 'All coordinates must be vectors corresponding to each dimension of x.');
        elseif ~isnumeric(varargin{i})
            error('MAT2NGRID:invalidCoords', 'All coordinates must be numeric.');
        elseif ~strcmp(class(varargin{i}), class(varargin{1}))
            error('MAT2NGRID:invalidCoords', 'All coordinates must have the same data type.');
        elseif length(varargin{i}) ~= size(x, i)
            error('MAT2NGRID:invalidCoords', ['The length of coordinate vector ', num2str(i), ' must match dimension ', num2str(i), ' of x.']);
        else
            ngrid.coordinates = [ngrid.coordinates; reshape(varargin{i}, [], 1)];
        end
    end
elseif nargin < ndims(x) + 1
    error('MAT2NGRID:tooFewCoords', 'Not enough inputs. Include coordinates for each dimension of x.');
elseif nargin > ndims(x) + 1
    error('MAT2NGRID:tooManyCoords', 'Too many inputs. Include coordinates for each dimension of x.');
end

end