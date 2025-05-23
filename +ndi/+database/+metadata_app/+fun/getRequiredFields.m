function S = getRequiredFields()

    S = struct(...
        'DatasetFullName', true, ...
        'DatasetShortName', true, ...
        'Description', true, ...
        'Comments', false, ...
        'ReleaseDate', false, ...
        'License', true, ...
        'FullDocumentation', false, ...
        'VersionIdentifier', true, ...
        'VersionInnovation', false, ...
        'Funding', false, ...
        'RelatedPublication', false, ...
        'ExperimentalApproach', false, ...
        'TechniquesEmployed', false, ...
        'DataType', true ...
        );
end
