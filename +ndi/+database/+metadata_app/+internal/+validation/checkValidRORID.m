function [name, formattedID] = checkValidRORID(rorid)
    formattedID = {};
    name = {};
    cmd = sprintf("curl https://api.ror.org/organizations/%s", rorid);
    [~, response] = system(cmd);
    response = jsondecode(response);
    if ~isfield(response, "errors")
        formattedID = response.id;
        name = response.name;
    end
    if ~isempty(formattedID) && ~startsWith(formattedID, 'https://ror.org/')
        formattedID = strcat('https://ror.org/', formattedID);
    end
end
