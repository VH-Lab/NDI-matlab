function test_ndi_daq_documents(varargin)
    % TEST_NDI_DAQ_DOCUMENTS - Test the functionality of the storage of DAQ objects using NDI_DOCUMENT and the NDI_SESSION database
    %
    %  ndi.test.daq.documents([DIRNAME])
    %
    %  Given a directory, this function tries to create and test the
    %  following objects and subclasses:
    %     1) ndi.file.navigator (by calling test_ndi_filenavigator_document)
    %     2) ndi.daq.reader (by calling test_ndi_daqreader_document)
    %     3) ndi.daq.system (by calling test_ndi_daqsystem_document)
    %     4) ndi.time.syncrule (by calling test_ndi_syncrule_document)
    %     5) ndi.time.syncgraph (by calling test_ndi_syncgraph_document)
    %
    %  If DIRNAME is not provided, the default directory
    %  [NDIEXAMPLEEXPERPATH/exp1_eg] is used.
    %
    %

    ndi.test.database.core.test_ndi_filenavigator_documents(varargin{:});
    ndi.test.database.core.test_ndi_daqreader_documents(varargin{:});
    ndi.test.database.core.test_ndi_daqsystem_documents();
    ndi.test.database.core.test_ndi_syncgraph_documents(varargin{:});
    ndi.test.database.core.test_ndi_syncrule_documents(varargin{:});

