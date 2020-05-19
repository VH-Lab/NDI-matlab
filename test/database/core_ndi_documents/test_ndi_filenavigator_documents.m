function test_ndi_filenavigator_documents(dirname)
% TEST_NDI_FILENAVIGATOR_DOCUMENTS - test creating database entries, searching, and building from documents
%
% TEST_NDI_FILENAVIGATOR_DOCUMENTS(DIRNAME)
%
% Given a directory that corresponds to an session, this function tries to create
% an ndi_filenavigator object and an ndi_filenavigator_epochdir object and do the following:
%   a) Create a new database document
%   b) Add the database document to the database
%   c) Search for the database document
%   d) Create a new object based on the database entry, and test that it matches the original
%  
	ndi_globals;

	%No directory has passed in as a parameter
	if nargin<1
		dirname = [ndiexampleexperpath filesep 'exp1_eg'];
	end

	%Create and NDI_session object
	E = ndi_session_dir('exp1',dirname);

	fn{1} = ndi_filenavigator(E, '.*\.rhd\>');
	fn{2} = ndi_filenavigator_epochdir(E, '.*\.rhd\>');

	%Delete any demo ndi_document stored in the session
	doc = E.database_search(ndi_query('','isa','ndi_document_filenavigator.json',''));
	E.database_rm(doc);

	% Step a)

	%Test the ndi_document creater
	fn_doc{1} = fn{1}.newdocument();
	fn_doc{2} = fn{2}.newdocument();
	disp('Sucessfully created ndi_documents')

	fn{1}.id()
	fn_doc{1}.document_properties.ndi_document

	% Step b)
	%Store the document as database
	E.database_add(fn_doc{1});
	E.database_add(fn_doc{2});
	disp('Sucessfully added documents to the database')

	% Step c)

	% Step d) 
	for i=1:numel(fn_doc),
		read_doc = E.database_search(fn{i}.searchquery());
		if numel(read_doc)~=1, 
			error(['Could not find document, i=' int2str(i)]);
		end; 
		read_doc{1}.document_properties.filenavigator,
		fn_withdoc{i} = ndi_document2ndi_object(read_doc{1},E);
	end;

	%Initialize the filenavigator using the ndi_document

	for i=1:numel(fn_doc),
		if eq(fn_withdoc{i},fn{i}),
			disp(['Object i=' int2str(i) ' created from database is successful']);
		else,
			error(['For i=' int2str(i) ', ndi_filenavigator objects do not match.']);
		end;
	end;
end

