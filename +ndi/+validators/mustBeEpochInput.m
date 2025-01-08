function mustBeEpochInput(v)
% mustBeEpochInput - determines whether an input can describe an epoch
%
% mustBeEpochInput(V)
%
% Validates if V is a character array, string, or double of size 1x1.
% Otherwise returns an error.
%
% Note that this function does not determine if the input actually
% corresponds to a valid epoch. Instead, it merely tests whether the input
% CAN be a valid epoch according to its formatting.
% 
% See also: ndi.epoch.epochset.epochtable
%
% Example:
%   ndi.validators.mustBeEpochInput(1) % no error
%   ndi.validators.mustBeEpochInput('t00001') % no error
%   ndi.validators.mustBeEpochInput("t00001") % no error
%   ndi.validators.mustBeEpochInput([1 2 3]) % error
%   


try
    mustBeTextScalar(v);
catch
    try
        [m,n]=size(v);
        assert((m==1)&(n==1));
        mustBeInteger(v);
        mustBePositive(v);
    catch
        error(['Value must be a character vector, string scalar, or positive integer scalar.'])
    end
end

