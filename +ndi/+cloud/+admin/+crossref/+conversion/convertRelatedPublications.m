function relProgramObj = convertRelatedPublications(cloudDataset)
    
    if ~isfield(cloudDataset, 'associatedPublications') ...
            || isempty(cloudDataset.associatedPublications)
        relProgramObj = crossref.model.RelProgram.empty;
    else
        relPublicationDetails = cloudDataset.associatedPublications;

        relItemList = crossref.model.RelRelatedItem.empty();

        for i = 1:numel(relPublicationDetails)
            relItemList(i) = crossref.model.RelRelatedItem(...
                )
        frAssertion = crossref.model.FrAssertion(...
            "Name", "funder_name", ...
            "Value", string(fundingDetails.source));
        
        relProgramObj = crossref.model.FrProgram(...
            "Assertion", frAssertion);
    end
end
