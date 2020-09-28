function test_ndi_daqsystem_documents
% TEST_NDI_DAQSYSTEM_DOCUMENTS - test creating database entries, searching, and building from documents
%
% TEST_NDI_DAQSYSTEM_DOCUMENTS(DIRNAME)
%
% Given a directory that corresponds to an session, this function tries to create
% the following objects :
%   1) ndi_daqsystem_mfdaq
%   2) ndi_daqsystem_mfdaq_stimulus
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

	% First, delete any daq systems that are there from the dbleaf system
	E.daqsystem_clear();
	% Second, delete any existing daqsystem documents
	doc = E.database_search(ndi_query('','isa','ndi_document_daqsystem.json',''));
	E.database_rm(doc);

	% we will create one of all types returned by ndi_vhlab_makedev

	devlist = ndi_vhlab_makedev;

	daqsys = {};
	daqsys_docs = {};

	for i=1:numel(devlist),
		disp(['Making object ' devlist{i} '.']);
		E = ndi_vhlab_makedev(E, devlist{i});
		daqsys{i} = E.daqsystem_load('name',devlist{i});
		disp(['Making document for ' devlist{i} '.']);
		daqsys_docs{i} = daqsys{i}.newdocument();
		E.database_add(daqsys_docs{i});
		ds_doc{i} = E.database_search(daqsys{i}.searchquery());
		if numel(ds_doc{i})~=1,
			error(['Did not find exactly 1 match.']);
		end;
	end;

	ds_fromdoc = {};

	for i=1:numel(ds_doc),
		ds_fromdoc{i} = ndi_document2ndi_object(daqsys_docs{i}{3},E);
		if eq(ds_fromdoc{i},daqsys{i}),
			disp(['Daqsystem number ' int2str(i) ' matches.']);
		else,
			error(['Daqsystem number ' int2str(i) ' does not match.']);
		end;
	end;

	% clean up for next time
	E.daqsystem_clear();
end

