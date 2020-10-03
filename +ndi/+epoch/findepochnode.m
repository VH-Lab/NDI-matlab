function index = findepochnode(epochnode, epochnodearray)
% FINDEPOCHNODE - find an occurence of an epochnode in an array of epochnodes
%
% INDEX = ndi.epoch.findepochnode(EPOCHNODE, EPOCHNODEARRAY)
%
% Returns the index of any occurrence(s) of EPOCHNODE in EPOCHNODEARRAY.
% EPOCHNODE and EPOCHNODEARRAY should be structures of the type returned by
% ndi.epoch.epochset/EPOCHNODES.
%
% EPOCHNODE should be a single element, and EPOCHNODEARRAY can be an array of
% epochnode structures.
%
% If any fields of EPOCHNODE are empty or are not present in the structure,
% then that field is not searched over. Thus, INDEX can be an array of all
% nodes that match the other criteria. If EPOCHNODE is fully filled, then
% only exact matches are returned.
%
% Note: at present, the 'epochprobemap' field is not compared.
% 
% See also: ndi.epoch.epochset/EPOCHNODES

index = [];

searchspace = 1:numel(epochnodearray);

parameters = {'objectname','objectclass','epoch_id','epoch_clock','epoch_session_id'};

if numel(epochnode)>1,
	error(['EPOCHNODE must be a single entry.']);
end;

for i=1:numel(parameters),
	value = [];
	if isfield(epochnode,parameters{i}),
		value = getfield(epochnode,parameters{i});
	end;
	if ~isempty(value)
		switch(parameters{i}),
			case {'objectname','objectclass','epoch_id','epoch_session_id'},
				eval(['subspacesearch = find(strcmp(value,{epochnodearray(searchspace).' parameters{i} '}));']);
			case 'epoch_clock',
				idx = cellfun(@(x) eq(x,value), {epochnodearray(searchspace).epoch_clock});
				subspacesearch = find(idx);
		end
		searchspace = searchspace(subspacesearch);
	end
end

index = searchspace;

