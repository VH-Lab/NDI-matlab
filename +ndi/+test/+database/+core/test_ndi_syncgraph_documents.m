function test_ndi_syncgraph_documents
% TEST_NDI_SYNCGRAPH_DOCUMENTS - test creating database entries, searching, and building from documents
%
% ndi.test.syncgraph.documents(DIRNAME)
%
% Given a directory that corresponds to an session, this function tries to create
% the following objects :
%   1) ndi.time.syncgraph
%
%   Then, the following tests actions are conducted for each document type:
%   a) Create a new database document
%   b) Add the database document to the database
%   c) Search for the database document
%   d) Create a new object based on the database entry, and test that it matches the original
%

	ndi.globals;
	dirname = [ndi.common.PathConstants.ExampleDataFolder filesep 'exp1_eg'];

	E = ndi.session.dir('exp1',dirname);
	 % remove any existing syncrules
	doc = E.database_search(ndi.query('','isa','syncgraph',''));
	E.database_rm(doc);

	sg = {};
	sg_docs = {};
	 
	 % Steps a and b and c)

	syncrule_docs = {};

	disp(['Making ndi.time.syncgraph object ...']);
	sg{1} = ndi.time.syncgraph(E);
	sg{1} = sg{1}.addrule(ndi.time.syncrule.filematch());


	disp(['Making document for ndi.time.syncgraph object.']);
	sg_docs{1} = sg{1}.newdocument();
	E.database_add(sg_docs{1});
	syncgraph_docs{1} = E.database_search(sg{1}.searchquery());
	if numel(syncgraph_docs{1})~=1,
		error(['Did not find exactly 1 match.']);
	end;

	sg_fromdoc = {};

	for i=1:numel(syncgraph_docs),
		sg_fromdoc{i} = ndi.database.fun.ndi_document2ndi_object(syncgraph_docs{i}{1},E);
		if eq(sg_fromdoc{i},sg{i}),
			disp(['Syncgraph number ' int2str(i) ' matches.']);
		else,
			error(['Syncgraph number ' int2str(i) ' does not match.']);
		end;
	end;
end
