function test_ndi_syncgraph_documents
% TEST_NDI_SYNCGRAPH_DOCUMENTS - test creating database entries, searching, and building from documents
%
% TEST_NDI_SYNCGRAPH_DOCUMENTS(DIRNAME)
%
% Given a directory that corresponds to an session, this function tries to create
% the following objects :
%   1) ndi_syncgraph
%
%   Then, the following tests actions are conducted for each document type:
%   a) Create a new database document
%   b) Add the database document to the database
%   c) Search for the database document
%   d) Create a new object based on the database entry, and test that it matches the original
%

	ndi_globals;
	dirname = [ndi_globals.path.exampleexperpath filesep 'exp1_eg'];

	E = ndi_session_dir('exp1',dirname);
	 % remove any existing syncrules
	doc = E.database_search(ndi_query('','isa','ndi_document_syncgraph',''));
	E.database_rm(doc);

	sg = {};
	sg_docs = {};
	 
	 % Steps a and b and c)

	syncrule_docs = {};

	disp(['Making ndi_syncgraph object ...']);
	sg{1} = ndi_syncgraph(E);
	sg{1} = sg{1}.addrule(ndi_syncrule_filematch());


	disp(['Making document for ndi_syncgraph object.']);
	sg_docs{1} = sg{1}.newdocument();
	E.database_add(sg_docs{1});
	syncgraph_docs{1} = E.database_search(sg{1}.searchquery());
	if numel(syncgraph_docs{1})~=1,
		error(['Did not find exactly 1 match.']);
	end;

	sg_fromdoc = {};

	for i=1:numel(syncgraph_docs),
		sg_fromdoc{i} = ndi_document2ndi_object(syncgraph_docs{i}{1},E);
		if eq(sg_fromdoc{i},sg{i}),
			disp(['Syncgraph number ' int2str(i) ' matches.']);
		else,
			error(['Syncgraph number ' int2str(i) ' does not match.']);
		end;
	end;
end
