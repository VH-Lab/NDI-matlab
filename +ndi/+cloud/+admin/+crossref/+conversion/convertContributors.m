function contributorsObj = convertContributors(cloudDataset)

    % Create person_name objects for contributors
    personNames = [];
    for i = 1:length(cloudDataset.contributors)
        contributor = cloudDataset.contributors(i);
        
        % Determine sequence attribute (first or additional)
        if i == 1
            sequence = crossref.enum.Sequence.first;
        else
            sequence = crossref.enum.Sequence.additional;
        end

        if isfield(contributor, 'firstName')
            givenName =  contributor.firstName;
        else
            givenName = missing;
        end
        if isfield(contributor, 'lastName')
            surName =  contributor.lastName;
        else
            surName = missing;
        end
        if isfield(contributor, 'orcid') && ~isempty(contributor.orcid)
            orcidValue = contributor.orcid;
            % Append orcid prefix if only numbers are given
            if ~isempty( regexp(orcidValue, '^\d{4}-\d{4}-\d{4}-\d{4}$', 'once') )
                orcidValue = "https://orcid.org/" + orcidValue;
            end
            orcIdObj = crossref.model.ORCID("Value", orcidValue);
        else
            orcIdObj = crossref.model.ORCID.empty;
        end

        % Create person_name object
        personName = crossref.model.PersonName(...
            'GivenName', givenName, ...
            'Surname', surName, ...
            'Orcid', orcIdObj, ...
            'Sequence', sequence, ...
            'ContributorRole', crossref.enum.ContributorRole.author ...
        );
        
        personNames = [personNames, personName]; %#ok<AGROW>
    end
    
    % Create contributors object
    contributorsObj = crossref.model.Contributors(...
        'Items', num2cell(personNames) ...
    );
end
