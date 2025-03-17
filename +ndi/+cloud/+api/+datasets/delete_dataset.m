function [status, response] = delete_dataset(dataset_id, options)
    % DELETE_DATASET - Delete a dataset. Datasets cannot be deleted if they
    % have been branched off of
    %
    % [STATUS, RESPONSE] = ndi.cloud.api.datasets.DELETE_DATASET(DATASET_ID)
    %
    % Inputs:
    %   DATASET_ID - a string representing the dataset id
    %
    % Outputs:
    %   STATUS - did delete request work? 1 for no, 0 for yes
    %   RESPONSE - the delete confirmation
    %

    arguments
        dataset_id (1,1) string
        options.ConfirmDeletion (1,1) logical = true
    end

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.DELETE;

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers);

    url = ndi.cloud.api.url('delete_dataset', 'dataset_id', dataset_id);

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 204)
        status = 0;
    elseif (response.StatusCode == 504)
        % Delete dataset endpoint always runs into a gateway timeout error.
        % Accept this and try to get dataset to confirm it is deleted
        if options.ConfirmDeletion
            try % This should fail
                [~, ~, ~] = ndi.cloud.api.datasets.get_dataset(dataset_id);
                warning('Dataset with id "%s" might not have been deleted', dataset_id)
            catch ME
                if strcmp(ME.message, 'Failed to run command. Not Found')
                    fprintf('Dataset with id "%s" deleted from NDI Cloud.\n', dataset_id)
                else
                    rethrow(ME)
                end
            end
        end
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
