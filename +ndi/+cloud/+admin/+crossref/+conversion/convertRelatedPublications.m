function relProgramObj = convertRelatedPublications(cloudDataset)
    
    if ~isfield(cloudDataset, 'associatedPublications') ...
            || isempty(cloudDataset.associatedPublications)
        relProgramObj = crossref.model.RelProgram.empty;
    else
        relPublicationDetails = cloudDataset.associatedPublications;

        relItemList = crossref.model.RelRelatedItem.empty();

        for i = 1:numel(relPublicationDetails)
            % Todo: This is a placeholder. Update by filling in relevant info 
            % from  relPublicationDetails
            relItemList(i) = crossref.model.RelRelatedItem();
        end
        
        relProgramObj = crossref.model.RelProgram(...
            "RelatedItem", relItemList);
    end
end
