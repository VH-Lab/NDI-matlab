function test_ndi_daqreader_documents
% TEST_NDI_DAQREADER_DOCUMENTS - test creating database entries, searching, and building from documents
%
% TEST_NDI_DAQREADER_DOCUMENTS(DIRNAME)
%
% Given a directory that corresponds to an session, this function tries to create
% the following objects :
%   1) ndi_daqreader
%   2) ndi_daqreader_mfdaq
%   3) ndi_daqreader_mfdaq_cedspike2
%   4) ndi_daqreader_mfdaq_intan
%   5) ndi_daqreader_mfdaq_spikegadgets
%   6) ndi_daqreader_mfdaq_stimulus_vhlabvisspike2
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
	 % remove any existing daqreaders
	doc = E.database_search(ndi_query('','isa','ndi_document_daqreader.json',''));
	E.database_rm(doc);

	object_list = { ...
			'ndi_daqreader',...
			'ndi_daqreader_mfdaq', ...
			'ndi_daqreader_mfdaq_cedspike2', ...
			'ndi_daqreader_mfdaq_intan', ...
			'ndi_daqreader_mfdaq_spikegadgets', ...
			'ndi_daqreader_mfdaq_stimulus_vhlabvisspike2' ...
			};

	dr = {};
	 
	 % Steps a and b and c)

	daqreader_docs = {};

	for i=1:numel(object_list),
		disp(['Making ' object_list{i} '...']);
		dr{i} = eval([object_list{i} '();']);
		disp(['Making document for ' object_list{i} '...']);
		dr_doc{i} = dr{i}.newdocument();
		E.database_add(dr_doc{i});
		daqreader_docs{i} = E.database_search(dr{i}.searchquery());
		if numel(daqreader_docs{i})~=1,
			error(['Did not find exactly 1 match.']);
		end;
	end;

	dr_fromdoc = {};

	for i=1:numel(daqreader_docs),
		dr_fromdoc{i} = ndi_document2ndi_object(daqreader_docs{i}{1},E);
		if eq(dr_fromdoc{i},dr{i}),
			disp(['Daqreader number ' int2str(i) ' matches.']);
		else,
			error(['Daqreader number ' int2str(i) ' does not match.']);
		end;
	end;
end
