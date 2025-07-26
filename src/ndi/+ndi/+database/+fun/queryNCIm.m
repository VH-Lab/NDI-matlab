function data = queryNCIm(term)
% queryNCIm Queries the NCI Metathesaurus API.
%
%   data = queryNCIm(term) sends a request to the NCI
%   Metathesaurus API to search for the given term and returns the 
%   response data.
%
%   Inputs:
%       term: The search term (string).
%
%   Output:
%       data: The API response data (struct).


% Construct the API URL
base_url = 'https://api-evsrest.nci.nih.gov/api/v1/concept/ncim';
url = [base_url '?list=' term ];

% Set options for the webread function
options = weboptions('ContentType','json');

% Send the API request
try
    data = webread(url, options);
catch e
    fprintf('Error querying the NCI Metathesaurus API: %s\n', e.message);
    data = [];
end
end