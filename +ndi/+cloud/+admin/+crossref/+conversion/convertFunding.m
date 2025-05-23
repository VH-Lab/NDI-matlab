function fundingObj = convertFunding(cloudDataset)
    
    if ~isfield(cloudDataset, 'funding') || isempty(cloudDataset.funding)
        fundingObj = crossref.model.FrProgram.empty;
    else
        fundingDetails = cloudDataset.funding;

        frAssertions = cell(1, numel(fundingDetails));
        for i = 1:numel(fundingDetails)

            frAssertions{i} = crossref.model.FrAssertion(...
                "Name", "funder_name", ...
                "Value", string(fundingDetails(i).source));
            
        end

        fundingObj = crossref.model.FrProgram(...
            "Assertion", [frAssertions{:}]);
    end
end
