function ba = ndi_createNIFbrainareas(varargin)
% NDI_CREATENIFBRAINAREAS - create a list of allowable brain areas from the NIF-Ontology
%
% BA = NDI_CREATENIFBRAINAREAS(...)
%
% Creates a list of 'controlled' brain area labels and the corresponding nodes in the NIF-Ontology.
%
% Traces all areas that make up a part of the UBERON node 'nervous system', excluding those in the
% first level of depth (which are all relatively vague descriptors). This is then written to a file
% 'NIFBrainAreaControlledVocabulary.tsv' with a string id that describes the NIF-Ontology node ID
% and a string lbl that describes the NIF-Ontology label:
%
% Header row:
%   'ID<tab>LABEL<tab>Synonyms<tab><Other_Common_Name'
%   and then 1 entry per anatomical node.
%
% This function also takes name/value pairs that modify the behavior.
% Parameter (default)     | Description
% ---------------------------------------------------------------------------
% root ('UBERON:'...      | Root node for establishing the controlled vocabulary.
%  '0001016')             |  (Default is 'nervous system' in Uberon ontology.)
% depth (1000)            | How deep past "nervous system" to look
% depth_exclude (1)       | The depths to exclude from the list
% exclude_ontologies ({...| Ontologies to exclude
%  'CL'})                 |
% outname (...            | Output filen name of the file written to disk
% ['NIFBrainAreaContr'... |
%  'olledVocabulary.tsv'])|

root = 'UBERON:0001016';
depth = 1000;
depth_exclude = 1;
outname = 'NIFBrainAreaControlledVocabulary.tsv';
exclude_ontologies = {'CL'};

assign(varargin{:});

command = ['https://scicrunch.org/api/1/sparc-scigraph/graph/neighbors/' ...
		root ...
		'?relationshipType=subClassOf&relationshipType=BFO:0000050' ...
		'&direction=INCOMING' ...
		'&depth=' int2str(depth) ...
		'&key=hJ11JrXAMlnBzuWzREV14ctciyPXNVBw'];

command_ = ['https://scicrunch.org/api/1/sparc-scigraph/graph/neighbors/' ...
		root ...
		'?relationshipType=subClassOf&relationshipType=BFO:0000050' ...
		'&direction=INCOMING' ...
		'&depth=' int2str(depth_exclude) ...
		'&key=hJ11JrXAMlnBzuWzREV14ctciyPXNVBw'];

t = urlread(command);
t_ = urlread(command_);

J = jsondecode(t);
J_ = jsondecode(t_);

[keep,keepindexes] = setdiff({J.nodes.id},{J_.nodes.id});

ba = J.nodes(keepindexes);

fid = fopen([outname],'wt');
if fid<0,
        error(['Could not open file ' [pwd filesep outname] ' for writing.']);
end;

fprintf(fid,['ID\tLabel\tSynonyms\n']);

included = [];

for i=1:numel(ba),
	strs = split(ba(i).id,':');
	if any(strcmp(strs{1},exclude_ontologies)),
		continue; % skip
	end;
	included(end+1) = i;

        fprintf(fid,[ba(i).id '\t']);
        fprintf(fid,[ba(i).lbl '\t']);

	if isfield(ba(i).meta,'synonym'),
		for j=1:numel(ba(i).meta.synonym),
			fprintf(fid,[ba(i).meta.synonym{j}]);
			if j~=numel(ba(i).meta.synonym), 
				fprintf(fid,', ');
			end;
		end;

	end;

	% end the line
	fprintf(fid,'\n');
end;

fclose(fid);

ba = ba(included);
