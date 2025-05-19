function response = registerDOI(username, password, doi, url, metadataJson, testMode)
%REGISTERDOI Registers a DOI with DataCite using their REST API
%
% Inputs:
%   - username: DataCite API username (e.g., "DATACITE_USERNAME")
%   - password: DataCite API password
%   - doi: The DOI to register (e.g., "10.1234/abcd1234")
%   - url: The landing page URL that the DOI should resolve to
%   - metadataJson: A string with metadata in DataCite JSON format
%   - testMode: (optional) true to use test endpoint; default false
%
% Output:
%   - response: Server response structure

    arguments
        username (1,:) char
        password (1,:) char
        doi (1,:) char
        url (1,:) char
        metadataJson (1,:) char
        testMode (1,1) logical = false
    end
    
    % Choose endpoint
    if testMode
        apiUrl = 'https://api.test.datacite.org/dois';
    else
        apiUrl = 'https://api.datacite.org/dois';
    end
    
    % Prepare metadata payload (must be valid JSON as a string)
    metadataStruct = jsondecode(metadataJson);  % Confirm it's valid JSON
    payload = struct("data", metadataStruct);
    
    % Send request
    options = weboptions(...
        'Username', username, ...
        'Password', password, ...
        'MediaType', 'application/vnd.api+json', ...
        'HeaderFields', {'Accept', 'application/vnd.api+json'}, ...
        'Timeout', 30);
    
    try
        response = webwrite(apiUrl, payload, options);
        fprintf('DOI %s registered successfully.\n', doi);
    catch ME
        fprintf('Failed to register DOI: %s\n', ME.message);
        if isfield(ME, 'response')
            disp(ME.response.Body.Data.errors)
        end
        rethrow(ME)
    end
end
