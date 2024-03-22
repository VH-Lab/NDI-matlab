function add_stimulus_approach(S, filename)
% ADD_STIMULUS_APPROACH add stimulus approaches to an ndi.session from a text file
%
% ADD_STIMULUS_APPROACH(S, [FILENAME])
%
% Examines a text file, either named 'stimulus_approaches.txt' in the root
% directory of the ndi.session object S or FILENAME if provided.
% The text file should be a tab-delimited table with first entries
% 'Epoch' and 'Approach'. Each subsequent row should have entries of 
% approach names in the NDI Cloud Ontology. 
%   Example:
%      Epoch<tab>Approach
%      t00001<tab>Purpose: Assessing spatial frequency tuning
%      t00002<tab>Purpose: Assessing temporal frequency tuning
% 
% The function for epochs in the device 'vhvis_spike2'. If the entries are already
% added, then they are not re-added.

if nargin<2,
	filename = [S.getpath filesep 'stimulus_approaches.txt'];
end;

tab = loadStructArray(filename);

daqsys = S.daqsystem_load('name','vhvis_spike2');

if isempty(daqsys),
	error(['Could not find daq system vhvis_spike2.']);
end;

daq_id = daqsys{1}.id();
session_id = S.id();

probe_id = ;
et = probe.epochtable();

for i=1:numel(tab),
	item = ndi.database.fun.ndicloud_ontology_lookup('Name',tab(i).Approach);
	if isempty(item),
		error(['Could not find item that matches ' tab(i).Approach '.']);
	end;
	% make sure epoch is in epochtable
	if isempty(find(strcmp(tab(i).Epoch,{et.epoch_id}))),
		error(['Could not find epoch ' tab(i).Epoch '.']);
	end;

	ont_id = ['NDIC:' sprintf('%0.8d',item.Identifier];

	% do we already have the item as a document?
	q_e = ndi.query('epochid.epochid','exact_string',tab(i).Epoch);
	q_s = ndi.query('openminds.fields.name','exact_string',tab(i).Approach) & ...
		ndi.query('openminds.fields.preferredOntologyIdentifier',ont_id);
	d_test = S.database_search(q_e&q&s);
	if isempty(d_test),
		new_approach = openminds.controlledterms.StimulusApproach(...
			'name',item.Name,...
			'preferredOntologyIdentifier',ont_id',...
			'description',item.Description);
		d_new = ndi.database.fun.openMINDSobj2ndi_document(new_approach,...
			session_id, 'stimulus',probe_id,'epochid.epochid', tab(i).Epoch);
	end;

end;


