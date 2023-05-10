function databaseId = create_database(organizationId, name, authToken)
    % Prepare the JSON data to be sent in the POST request
    json = struct('name', name);
    jsonStr = jsonencode(json);
    
    % Construct the curl command with the organization ID and authentication token
    cmd = sprintf(['curl -X POST ' ...
        'https://rsmz66zk54.execute-api.us-east-1.amazonaws.com/dev/v1/organizations/%s/datasets'...
        '-H "accept: application/json" ' ...
        '-H "Authorization: Bearer %s" ' ...
        '-H "Content-Type: application/json" ' ...
        '-d ''%s'' https://rsmz66zk54.execute-api.us-east-1.amazonaws.com/dev/v1/organizations/%s/datasets'] ...
        , organizationId, authToken, jsonStr);

    % Run the curl command and capture the output
    [status, output] = system(cmd);
    
    % Check the status code and handle any errors
    if status ~= 0
        error('Failed to run curl command: %s', output);
    end
    
    % Process the JSON response
    response = jsondecode(output);
    if isfield(response, 'error')
        error(response.error);
    end
    
    % Extract any relevant information from the response
    % (e.g., database ID, etc.) and perform necessary actions
    databaseId = response.id;
    
    disp('Database created successfully!');
    disp(['Database ID: ' databaseId]);
end
