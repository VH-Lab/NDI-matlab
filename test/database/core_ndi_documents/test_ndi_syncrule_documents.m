function test_ndi_syncrule_documents
% TEST_NDI_SYNCRULE_DOCUMENTS - test creating database entries, searching, and building from documents
%
% TEST_NDI_SYNCRULE_DOCUMENTS(DIRNAME)
%
% Given a directory that corresponds to an session, this function tries to create
% the following objects :
%   1) ndi_syncrule_filematch
%
%   Then, the following tests actions are conducted for each document type:
%   a) Create a new database document
%   b) Add the database document to the database
%   c) Search for the database document
%   d) Create a new object based on the database entry, and test that it matches the original
%

	ndi_globals;
	dirname = [ndiexampleexperpath filesep 'exp1_eg'];

	E = ndi_session_dir('exp1',dirname);
	 % remove any existing syncrules
	doc = E.database_search(ndi_query('','isa','ndi_document_syncrule.json',''));
	E.database_rm(doc);

	object_list = { ...
			'ndi_syncrule_filematch',...
			};

	sr = {};
	sr_docs = {};
	 
	 % Steps a and b and c)

	syncrule_docs = {};

	for i=1:numel(object_list),
		disp(['Making ' object_list{i} '...']);
		sr{i} = eval([object_list{i} '();']);
		disp(['Making document for ' object_list{i} '...']);
		sr_docs{i} = sr{i}.newdocument();
		E.database_add(sr_docs{i});
		syncrule_docs{i} = E.database_search(sr{i}.searchquery());
		if numel(syncrule_docs{i})~=1,
			error(['Did not find exactly 1 match.']);
		end;
	end;

	sr_fromdoc = {};

	for i=1:numel(syncrule_docs),
		sr_fromdoc{i} = ndi_document2ndi_object(syncrule_docs{i}{1},E);
		if eq(sr_fromdoc{i},sr{i}),
			disp(['Syncrule number ' int2str(i) ' matches.']);
		else,
			error(['Syncrule number ' int2str(i) ' does not match.']);
		end;
	end;
end
