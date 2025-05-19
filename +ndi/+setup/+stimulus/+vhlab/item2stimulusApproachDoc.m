function [doc] = item2stimulusApproachDoc(session,approach,epochid)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

item = ndi.database.fun.ndicloud_ontology_lookup('Name',approachName);
if isempty(item)
    error(['Could not find item that matches ' approachName '.']);
end

% make sure epoch is in epochtable
if ~any(strcmp(epochid,{et.epoch_id}))
    error(['Could not find epoch ' epochid '.']);
end

ont_id = ['NDIC:' sprintf('%0.8d',item.Identifier)]

% do we already have the item as a document?
q_e = ndi.query('epochid.epochid','exact_string',epochid);
q_s = ndi.query('openminds.fields.name','exact_string',approachName) & ...
    ndi.query('openminds.fields.preferredOntologyIdentifier','exact_string',ont_id);
doc = session.database_search(q_e&q_s);
if isempty(doc)
    new_approach = openminds.controlledterms.StimulationApproach(...
        'name',item.Name,...
        'preferredOntologyIdentifier',ont_id,...
        'description',item.Description);
    doc = ndi.database.fun.openMINDSobj2ndi_document(new_approach,...
        session_id, 'stimulus',probe_id,'epochid.epochid', epochid);
end

end