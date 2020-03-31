function test_daqreader_documents
% TEST_DAQREADER_DOCUMENTS - test creating database entries, searching, and building from documents
%
% TEST_DAQREADER_DOCUMENTS(DIRNAME)
%
% Given a directory that corresponds to an experiment, this function tries to create
% the following objects :
%   1) ndi_daqreader
%   2) ndi_daqreader_mfdaq
%   3) ndi_daqreader_stimulus
%   4) ndi_daqreader_mfdaq_cedspike2
%   5) ndi_daqreader_mfdaq_intan
%   6) ndi_daqreader_mfdaq_spikegadgets
%   7) ndi_daqreader_mfdaq_stimulus_vhlabvisspike2
%
%   Then, the following tests actions are conducted for each document type:
%   a) Create a new database document
%   b) Add the database document to the database
%   c) Search for the database document
%   d) Create a new object based on the database entry, and test that it matches the original
%

	ndi_globals;
	dirname = [ndiexampleexperpath filesep 'exp1_eg'];

	E = ndi_experiment_dir('exp1',dirname);
	 % remove any existing daqreaders
	doc = E.database_search(ndi_query('','isa','ndi_document_daqreader.json',''));
	E.database_rm(doc);

	object_list = { ...
			'ndi_daqreader',...
			'ndi_daqreader_mfdaq', ...
			'ndi_daqreader_mfdaq_cedspike2', ...
			'ndi_daqreader_mfdaq_intan', ...
			'ndi_daqreader_mfdaq_spikegadgets', ...
			'ndi_daqreader_stimulus', ...
			'ndi_daqreader_mfdaq_stimulus_vhlabvisspike2' ...
			};

	dr = {};
	 
	 % Steps a and b)

	for i=1:numel(object_list),
		disp(['Making ' object_list{i} '...']);
		dr{i} = eval([object_list{i} '();']);
		disp(['Making document for ' object_list{i} '...']);
		dr_doc{i} = dr{i}.newdocument();
		E.database_add(dr_doc{i});
	end;

	daqreader_docs = E.database_search(ndi_query('','isa','ndi_document_daqreader.json',''));

	 % Step c)

	dr_fromdoc = {};

	for i=1:numel(daqreader_docs),
		% because of order of adding, these should come back in order, too
		% but it is an assumption that need not be true for all databases

		dr_fromdoc{i} = ndi_document2ndi_object(daqreader_docs{i},E);
		if eq(dr_fromdoc{i},dr{i}),
			disp(['Daqreader number ' int2str(i) ' matches.']);
		else,
			error(['Daqreader number ' int2str(i) ' does not match.']);
		end;
	end;

end
