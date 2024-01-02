function datasets = listRemoteDatasets()
    
    % Note: Function is not complete
    
    % Todo: Get username/password from environment variables?
    % Todo: Make loop and retrieve all available dataset pages
    
    token = ndi.cloud.uilogin();

    [~, response, dataset] = ndi.cloud.datasets.get_published(1, 10, token);

    numDatasets = numel(dataset);

    [authors, names, branchNames] = deal(cell(numDatasets, 1));

    for i = 1:numDatasets
        authors{i} = arrayfun(@(s) strjoin({s.firstName, s.lastName}), ...
            dataset(i).contributors, 'UniformOutput', false );
        authors{i} = string( strjoin(authors{i}, '; ') );
    end

    datasets = table(string(authors), string({dataset.name}'), string({dataset.branchName}'), ...
        'VariableNames', {'authors', 'name', 'branchName'} );
end