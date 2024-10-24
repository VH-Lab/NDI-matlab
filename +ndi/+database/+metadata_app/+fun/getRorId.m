function rorid = getRorId(name)

    baseUrl = "curl 'https://api.ror.org/organizations?query='";
    cmd = sprintf('%s%s', baseUrl, name);
    [~, response] = system(cmd);
    response = jsondecode(response);
    if isfield(response, "errors")
        rorid = '';
    elseif response.number_of_results == 1
        rorid = response.items(1).id;
    elseif response.number_of_results > 1
        error('Multiple entries found')
    end
end
