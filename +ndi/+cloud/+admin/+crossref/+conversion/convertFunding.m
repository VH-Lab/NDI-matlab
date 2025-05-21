function fundingObj = convertFunding(cloudDataset)
    
    if ~isfield(cloudDataset, 'funding') || isempty(cloudDataset.funding)
        fundingObj = crossref.model.FrProgram.empty;
    else
        fundingDetails = cloudDataset.funding;

        frAssertion = crossref.model.FrAssertion(...
            "Name", "funder_name", ...
            "Value", string(fundingDetails.source));
        
        fundingObj = crossref.model.FrProgram(...
            "Assertion", frAssertion);
    end
end
