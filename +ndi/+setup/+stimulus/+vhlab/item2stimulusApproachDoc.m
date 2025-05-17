function [doc] = item2stimulusApproachDoc(item)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

item = ndi.database.fun.ndicloud_ontology_lookup('Name',item.Approach);
if isempty(item)
    error(['Could not find item that matches ' item.Approach '.']);
end

% make sure epoch is in epochtable
if isempty(find(strcmp(item.Epoch,{et.epoch_id})))
    error(['Could not find epoch ' item.Epoch '.']);
end

ont_id = ['NDIC:' sprintf('%0.8d',item.Identifier)]

% do we already have the item as a document?
q_e = ndi.query('epochid.epochid','exact_string',item.Epoch);
q_s = ndi.query('openminds.fields.name','exact_string',item.Approach) & ...
    ndi.query('openminds.fields.preferredOntologyIdentifier','exact_string',ont_id);
doc = S.database_search(q_e&q_s);
if isempty(doc)
    new_approach = openminds.controlledterms.StimulationApproach(...
        'name',item.Name,...
        'preferredOntologyIdentifier',ont_id,...
        'description',item.Description);
    doc = ndi.database.fun.openMINDSobj2ndi_document(new_approach,...
        session_id, 'stimulus',probe_id,'epochid.epochid', item.Epoch);
end

end