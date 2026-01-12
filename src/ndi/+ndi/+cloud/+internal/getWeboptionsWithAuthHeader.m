function opts = getWeboptionsWithAuthHeader()
% GETWEBOPTIONSWITHAUTHHEADER - Create weboptions with Authorization header.
%
% OPTS = GETWEBOPTIONSWITHAUTHHEADER()
%
% This function creates a MATLAB weboptions object that is pre-configured
% with the HTTP 'Authorization' header required for NDI cloud API requests.
%
% It first obtains an authentication token by calling ndi.cloud.authenticate.
% It then constructs the header value in the format "Bearer <token>" and
% sets it as a header field in the returned weboptions object.
%
% This is a convenience function to ensure that API calls are properly
% authenticated without duplicating header creation code.
%
% Outputs:
%   opts (weboptions) - A weboptions object with the 'Authorization' header
%     field set.
%
% Example:
%   % Create options for an authenticated API call
%   my_options = ndi.cloud.internal.getWeboptionsWithAuthHeader();
%   % Use my_options in a websave or webread call
%   data = webread('https://my.api.endpoint/data', my_options);
%
% See also: ndi.cloud.authenticate, weboptions

    auth_token = ndi.cloud.authenticate();
    opts = weboptions(...
        'HeaderFields', ["Authorization", sprintf("Bearer %s", auth_token)] ...
        );
end