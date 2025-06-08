function mustBeValidColor(c)
    % This function validates that the input is a valid MATLAB color specification.
    isNumericRGB = isnumeric(c) && isvector(c) && numel(c) == 3 && all(c>=0) && all(c<=1);
    isCharOrString = (ischar(c) && size(c,1)<=1) || (isstring(c) && isscalar(c));

    if ~(isNumericRGB || isCharOrString)
        error(['Property ''FontColor'' must be a 1x3 RGB triplet with values from 0 to 1 (e.g., [0 0 0]) ' ...
               'or a character/string color name (e.g., ''red'').']);
    end
end