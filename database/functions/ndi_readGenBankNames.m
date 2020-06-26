function names = ndi_readGenBankNames(filename)
% NDI_READGENBANKNAMES - read the GenBank names from the 'names.dmp' file
%
% NAMES = NDI_READGENBANKNAMES(FILENAME)
%
% Given a 'names.dmp' file from a GenBank taxonomy data dump,
% this function produces a Matlab structure with the following fields:
% 
% fieldname            | Description
% -----------------------------------------------------------------
% node                 | The node number in the GenBank database
% genbank_commonname   | The genbank common name of the organism
% scientific_name      | The genbank scientific name
% synonym              | A cell array of strings with scientific name synonyms
% other_commonname     | A cell array of strings with the other common names

names = emptystruct('node','genbank_commonname','scientific_name','synonym','other_commonname');

if ischar(filename),
	T = text2cellstr(filename);
else,
	T = filename; % hidden mode for debugging
end;

mystr = split(T{end},sprintf('\t|\t'));
maxnode = eval(mystr{1});


progressbar('Interpreting node names...');

for t=1:numel(T),

	if mod(t,1000) == 0,
		progressbar(t/numel(T));
	end;

	mystr = split(T{t},sprintf('\t|\t'));
	% remove tab and line at end of line
	lasttab = strfind(mystr{end},sprintf('\t|'));
	if ~isempty(lasttab),
		mystr{end} = mystr{end}(1:lasttab-1);
	end;
	node_here = eval(mystr{1});
	name_here = mystr{2};
	category = mystr{end};
	
	% set the node entry
	I = find([names.node]==node_here);
	if isempty(I),
		name_struct_here = emptystruct('node','genbank_commonname','scientific_name','synonym','other_commonname');
		name_struct_here(1).node = node_here;
		name_struct_here.synonym = {};
		name_struct_here.other_commonname = {};
		names(end+1) = name_struct_here;
		I = numel(names);
	end;
	

	switch category,
		case 'scientific name',
			if ~isempty(names(I).scientific_name),
				error(['Multiply scientific names for node ' num2str(node_here) '.']);
			end;
			names(I).scientific_name = name_here;
		case 'synonym',
			names(I).synonym{end+1} = name_here;
		case 'genbank common name',
			if ~isempty(names(I).genbank_commonname),
				error(['Multiply genbank common names for node ' num2str(node_here) '.']);
			end;
			names(I).genbank_commonname = name_here;
		case 'common name'
			names(I).other_commonname{end+1} = name_here;

		otherwise,
			% do nothing
	end;
end;


progressbar(1);
