function test_daq_documents(dirname)
% TEST_DAQ_DOCUMENTS - Test the functionality of the storage of DAQ objects using NDI_DOCUMENT and the NDI_EXPERIMENT database
%
%  TEST_DAQ_DOCUMENTS([DIRNAME])
%
%  Given a directory, this function tries to create some 
%  NDI_VARIABLE objects in the experiment DATABASE. The test function
%  removes them on completion.
%
%  If DIRNAME is not provided, the default directory
%  [NDIEXAMPLEEXPERPATH/exp1_eg] is used.
%
%

ndi_globals;

if nargin<1,
	dirname = [ndiexampleexperpath filesep 'exp1_eg'];
end;

disp(['Creating a new experiment object in directory ' dirname '.']);
E = ndi_experiment_dir('exp1',dirname);

 % if we ran the demo before, delete the entry

doc = E.database_search(ndi_query('','isa','ndi_document_filenavigator.json',''));
E.database_rm(doc);

myfilenavigator = ndi_filenavigator(E, '.*\.rhd\>');

mydoc = myfilenavigator.newdocument();

E.database_add(mydoc);

mynewdoc = E.database_search(ndi_query('','isa','ndi_document_filenavigator.json',''));

if numel(mynewdoc)~=1,
	error(['Too many or not enough file navigator documents.']);
end;

mynewdoc{1}.document_properties.filenavigator,

 % TODO
if 0,
	warning('skipping ndi_filenavigator creator step');
else,
	myotherfilenavigator = ndi_filenavigator(E, mynewdoc{1});
end;

E.database_rm(mynewdoc);
