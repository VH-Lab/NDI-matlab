function test_filenavigator_documents(dirname)
% TEST_FILENAVIGATOR_DOCUMENTS - test creating database entries, searching, and building from documents
%
% TEST_FILENAVIGATOR_DOCUMENTS(DIRNAME)
%
% Given a directory that corresponds to an experiment, this function tries to create
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

	%Create and NDI_experiment object
	E = ndi_experiment_dir('exp1',dirname);

	ft{1} = ndi_filenavigator(E, '.*\.rhd\>');
	ft{2} = ndi_filenavigator_epochdir(E, '.*\.rhd\>');

	%Delete any demo ndi_document stored in the experiment
	doc = E.database_search(ndi_query('','isa','ndi_document_filenavigator.json',''));
	E.database_rm(doc);

	% Step a)

	%Test the ndi_document creater
	ft_doc{1} = ft{1}.newdocument();
	ft_doc{2} = ft{2}.newdocument();
	disp('Sucessfully created ndi_documents')

	% Step b)
	%Store the document as database
	E.database_add(ft_doc{1});
	E.database_add(ft_doc{2});
	disp('Sucessfully added documents to the database')

	% Step c)

	read_doc = E.database_search(ndi_query('','isa','ndi_document_filenavigator.json',''));

	disp(['Found ' int2str(numel(read_doc)) ' ndi_document_filenavigator document types.']);

	% Step d) 
	for i=1:numel(read_doc),
		read_doc{i}.document_properties.filenavigator,
		ft_withdoc{i} = ndi_document2ndi_object(read_doc{i},E);
	end;

	%Initialize the filenavigator using the ndi_document

	for i=1:numel(ft_doc),
		if eq(ft_withdoc{i},ft{i}),
			disp(['Object i=' int2str(i) ' created from database is successful']);
		else,
			error(['For i=' int2str(i) ', ndi_filenavigator objects do not match.']);
		end;
	end;

end

