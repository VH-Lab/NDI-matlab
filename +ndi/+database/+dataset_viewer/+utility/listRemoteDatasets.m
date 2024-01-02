function datasets = listRemoteDatasets()

    % Todo: Get username/password from environment variables?
    [~, token, ~] = ndi.cloud.auth.login('eivind@walthamdatascience.com', 'nYqpad-7nygfe-pavqeq');

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