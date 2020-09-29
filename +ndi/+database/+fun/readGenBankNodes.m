function [G] = ndi_readGenBankNodes(filename)
% NDI_READGENBANKNODES - read the node tree from GenBank data dump
%
% G = ndi.database.fun.readGenBankNodes(FILENAME)
%
% Given a 'nodes.dmp' file from a GenBank taxonomy data dump,
% this function produces a sparse connectivity matrix G such that
% G(i,j) = 1 iff node number i is a parent of node j.
% 

if ischar(filename),
	T = vlt.file.text2cellstr(filename);
else,
	T = filename; % hidden mode for debugging
end;


mystr = split(T{end},sprintf('\t|\t')); % get last string
node_max = eval(mystr{1});

parents = zeros(numel(T),1);
children = zeros(numel(T),1);

progressbar('Interpreting nodes...');

for t=1:numel(T),

	if mod(t,1000)==0,
		progressbar(t/numel(T));
	end;
	mystr = split(T{t},sprintf('\t|\t'));

	parents(t) = str2num(mystr{2});
	children(t) = str2num(mystr{1});
end;

G = sparse(parents,children,ones(size(parents)),node_max,node_max,length(parents));

progressbar(1);


