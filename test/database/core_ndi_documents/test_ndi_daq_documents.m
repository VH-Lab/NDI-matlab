function test_ndi_daq_documents(varargin)
% TEST_NDI_DAQ_DOCUMENTS - Test the functionality of the storage of DAQ objects using NDI_DOCUMENT and the NDI_EXPERIMENT database
%
%  TEST_NDI_DAQ_DOCUMENTS([DIRNAME])
%
%  Given a directory, this function tries to create and test the
%  following objects and subclasses:
%     1) ndi_filenavigator (by calling test_ndi_filenavigator_document)
%     2) ndi_daqreader (by calling test_ndi_daqreader_document)
%     
%  If DIRNAME is not provided, the default directory
%  [NDIEXAMPLEEXPERPATH/exp1_eg] is used.
%
%

test_ndi_filenavigator_documents(varargin{:});
test_ndi_daqreader_documents(varargin{:});

