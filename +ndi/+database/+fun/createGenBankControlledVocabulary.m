function ndi_createGenBankControlledVocabulary(dirname, varargin)
% NDI_CREATEGENBANKCONTROLLEDVOCABULARY - create the controlled vocabulary dictionary for animals
% 
% ndi.database.fun.createGenBankControlledVocabulary(DIRNAME, ...)
%
% This function examines the name file 'names.dmp' and node file 'nodes.dmp' from 
% the GenBank taxonomy database in the directory DIRNAME. It generates a new text file
% called 'GenBankControlledVocabulary.tsv' with the following structure:
%
% Header row:
%   'Scientific_Name<tab>GenBank_Common_Name<tab>Synonyms<tab><Other_Common_Name'
%   and then 1 entry per organism.
%
% This function also takes name/value pairs that modify the behavior.
% Parameter (default)     | Description
% ---------------------------------------------------------------------------
% root_node ('Bilateria') | Root scientific name to start with; usually 'Bilateria' to
%                         |  include most research organisms but not cell lines, 
%                         |  bacteria, viruses, etc (everything not 'Bilateria').
%                         |  Use 'Root' for everything.
% nodefile ('nodes.dmp')  | File name of the node file within DIRNAME
% namefile ('names.dmp')  | File name of the name file with DIRNAME
% outname (...            | Output filen name of the file written to disk
% ['GenBankControlled'... | 
%   'Vocabulary.tsv'])
%
% The taxonomy data is available at https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz.
%
% This function usually takes a couple of hours to run and shows 3 progress bars
% (the first one is faster than the second).
%


root_node = 'Bilateria';
nodefile = 'nodes.dmp';
namefile = 'names.dmp';
outname = 'GenBankControlledVocabulary.tsv';

vlt.data.assign(varargin{:});

disp(['Reading nodes']);
N = vlt.file.text2cellstr([dirname filesep nodefile]);
disp(['Reading names']);
T = vlt.file.text2cellstr([dirname filesep namefile]);

 % open file so we are ready and don't have a permissions error after 2 hours of running code

fid = fopen([dirname filesep outname],'wt');
if fid<0,
	error(['Could not open file ' [dirname filesep outname] ' for writing.']);
end;

 % takes 5 minutes on my medium-speed laptop
genBankNames = ndi.database.fun.readGenBankNames(T);

root_node_entry = find(strcmp(root_node,genBankNames.scientific_name));

 % takes a less than 10 minutes on my medium-speed laptop
G = ndi.database.fun.readGenBankNodes(N);

dG = digraph(G);
[tree,D] = dG.shortestpathtree(root_node_entry);

indexes = find(~isinf(D)); % find everything you can get to

children = sum(G,2);
parents = sum(G,1);
leafs = find( children(:)==0 & parents(:)>0 );

H = intersect(indexes,leafs);

fprintf(fid,['Scientific_Name\tGenBank_Common_Name\tSynonyms\tOther_Common_Name\n']);

[dummy,order] = sort(genBankNames.scientific_name(H));
 % write in alphabetical order

H = H(order); % rerder

progressbar('Writing output file...');

for i=1:numel(H),
	if mod(i,1000) == 0,
		progressbar(i/numel(H));
	end;

	if ~isempty(strfind(lower(genBankNames.scientific_name{H(i)}),'environmental')),
		continue; % skip it
	end;
	if ~isempty(strfind(lower(genBankNames.scientific_name{H(i)}),'sample')),
		continue; % skip it;
	end;

	fprintf(fid,[genBankNames.scientific_name{H(i)} '\t']);
	fprintf(fid,[genBankNames.genbank_commonname{H(i)} '\t']);
	for j=1:numel(genBankNames.synonym{H(i)}),
		fprintf(fid,[genBankNames.synonym{H(i)}{j}]);
		if j~=numel(genBankNames.synonym{H(i)}),
			fprintf(fid,', ');
		end;
	end;
	fprintf(fid,'\t');
	for j=1:numel(genBankNames.other_commonname{H(i)}),
		fprintf(fid,[genBankNames.other_commonname{H(i)}{j}]);
		if j~=numel(genBankNames.other_commonname{H(i)}),
			fprintf(fid,', ');
		end;
	end;
	fprintf(fid,'\n');
end;

progressbar(1);

fclose(fid);


