function [authToken, organizationId] = Login(email, password)
    % Prepare the JSON data to be sent in the POST request
    json = struct('email', email, 'password', password);
    jsonStr = jsonencode(json);
    
    % Construct the curl command
    cmd = sprintf(['curl -X POST "https://rsmz66zk54.execute-api.us-east-1.amazonaws.com/dev/v1/auth/login" ' ...
        '-H "accept: application/json" ' ...
        '-H "Content-Type: application/json" ' ...
        '-d ''%s'], jsonStr);
  
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
    
    % Extract the authentication token from the response
    authToken = response.token;
    organizationId = response.user.organizations.id;
end
