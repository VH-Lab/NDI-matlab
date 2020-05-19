function d = ndi_findemptyelementreference(E)
% NDI_FINDEMPTYELEMENTREFERENCE - find documents that refer to elements that no longer exist
%
% D = NDI_FINDEMPTYELEMENTREFERENCE(E)
%
% E - an NDI_SESSION object
%

warning('depricated, change to NDI_FINDDOCS_MISSING_DEPENDENCIES');
d = ndi_finddocs_missing_dependencies(E,'element_id');

return;

 % the old way

elements = E.getelements();

d = E.database_search(ndi_query('','isa','elementreference.json',''));

include = [];

element_unique_ids = {};
for j=1:numel(elements),
	element_unique_ids{j} = elements{j}.doc_unique_id();
end;

for i=1:numel(d),
	match_here = 0;
	for j=1:numel(elements),
		if strcmp(d{i}.document_properties.elementreference.element_unique_id,element_unique_ids{j}),
			match_here = 1;
			break;
		end;
	end;
	if ~match_here,
		include(end+1) = i;
	end;
end;

d = d(include);

