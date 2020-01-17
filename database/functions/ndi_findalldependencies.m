function [d] = ndi_findalldependencies(E, visited, varargin)
% NDI_FINDALLDEPENDENCIES- find documents that have dependencies on documents that do not exist
%
% [D] = NDI_FINDALLDEPENDENCIES(E, VISITED, DOC1, DOC2, ...)
%
% Searches the database of experiment E and returns all documents that have a 
% dependency ('depends_on') field for which the 'value' field corresponds to the
% id of DOC1 or DOC2, etc. If any DOCS do not need to be searched, provide them in VISITED.
% Otherwise, provide empty for VISITED.
%
% D is always a cell array of NDI_DOCUMENTS (perhaps empty, {}).
%

d = {};

if isempty(visited),
	visited = {};
end;

for i=1:numel(varargin),
	visited = cat(1,visited,{varargin{i}.id()});
end;


for i=1:numel(varargin),
	q_v = ndi_query('','depends_on','*',varargin{i}.id());
	bb = E.database_search(q_v);

	for j=1:numel(bb),
		id_here = bb{j}.id();
		if ~any(strcmp(id_here,visited)), % we don't already know about it
			visited = cat(1,visited,{id_here}); 
			d = cat(1,d,{bb{j}});
			newdocs = ndi_finddocs_missing_dependencies(E,visited,bb{j});
			if ~isempty(newdocs),
				for k=1:numel(newdocs),
					visited = cat(1,visited,newdocs{k}.id());
				end;
				d = cat(1,d,newdocs(:));
			end;
		end;
	end;
end;

if ~iscell(d),
    error(['This should always return a cell list, even if it is empty. Something is wrong, debug necessary.']);    
end;
