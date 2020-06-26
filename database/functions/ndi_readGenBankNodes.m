function [G] = ndi_readGenBankNodes(filename)
% NDI_READGENBANKNODES - read the node tree from GenBank data dump
%
% G = NDI_READGENBANKNODES(FILENAME)
%
% Given a 'nodes.dmp' file from a GenBank taxonomy data dump,
% this function produces a sparse connectivity matrix G such that
% G(i,j) = 1 iff node number j is a parent of node i.
% 

if ischar(filename),
	T = text2cellstr(filename);
else,
	T = filename; % hidden mode for debugging
end;


mystr = split(T{end},sprintf('\t|\t')); % get last string
node_here = eval(mystr{1});

G = sparse(node_here, node_here);

progressbar('Interpreting nodes...');

for t=1:numel(T),

	if mod(t,1000)==0,
		progressbar(t/numel(T));
	end;
	mystr = split(T{t},sprintf('\t|\t'));
	% remove tab and line at end of line
	lasttab = strfind(mystr{end},sprintf('\t|'));
	if ~isempty(lasttab),
		mystr{end} = mystr{end}(1:lasttab-1);
	end;

	node_here = eval(mystr{1});
	parent_here = eval(mystr{2});

	G(node_here, parent_here) = 1;
end;

progressbar(1);


