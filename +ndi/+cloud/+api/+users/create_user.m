function response = create_user(email, name, password)
    % CREATE_USER - create a new user
    %
    % RESPONSE = ndi.cloud.user.create_user(EMAIL, NAME, PASSWORD)
    %
    % Inputs:
    %   EMAIL - a string representing the user's e-mail
    %   NAME -  a string representing the username
    %   PASSWORD - a string representing the user's password
    %
    % Outputs:
    %   RESPONSE - a message indicates if the user is created or not
    %

    % Prepare the JSON data to be sent in the POST request
    json = struct('email', email, 'name', name, 'password', password);
    json_str = jsonencode(json);

    % Construct the curl command with the organization ID and authentication token
    uri = ndi.cloud.api.url('create_user');
    url = uri.EncodedURI;
    cmd = sprintf("curl -X 'POST' '%s' " + ...
        "-H 'accept: application/json' " + ...
        "-H 'Content-Type: application/json' " +...
        " -d '%s' ", url, json_str);

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
end
