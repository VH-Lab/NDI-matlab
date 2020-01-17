function d = ndi_findemptythingreference(E)
% NDI_FINDEMPTYTHINGREFERENCE - find documents that refer to things that no longer exist
%
% D = NDI_FINDEMPTYTHINGREFERENCE(E)
%
% E - an NDI_EXPERIMENT object
%

warning('depricated, change to NDI_FINDDOCS_MISSING_DEPENDENCIES');
d = ndi_finddocs_missing_dependencies(E,'thing_id');

return;

 % the old way

things = E.getthings();

d = E.database_search(ndi_query('','isa','thingreference.json',''));

include = [];

thing_unique_ids = {};
for j=1:numel(things),
	thing_unique_ids{j} = things{j}.doc_unique_id();
end;

for i=1:numel(d),
	match_here = 0;
	for j=1:numel(things),
		if strcmp(d{i}.document_properties.thingreference.thing_unique_id,thing_unique_ids{j}),
			match_here = 1;
			break;
		end;
	end;
	if ~match_here,
		include(end+1) = i;
	end;
end;

d = d(include);

