function test_daqsystem(ft,dq)
% TEST_DAQSYSTEM_DOCUMENTS - test creating database entries, searching, and building from documents
%
% TEST_DAQSYSTEM_DOCUMENTS(DIRNAME)
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
    
    %If the user does not supply file_navigator or daqreader
    if nargin < 2
        E = ndi_experiment_dir('exp1',dirname);
        ft = ndi_filenavigator(E, '.*\.rhd\>');
        dq = ndi_daqreader();
    end
    
    %create a new daqsystem
    ds = ndi_daqsystem('dummy',ft, ndi_daqreader());
    ds_doc = ds.newdocument();
    
    %Store filenavigator and daqreader ndi_document into the experiment
    %database
    E.database_add(ds_doc{1});
    E.database_add(ds_doc{2});
    E.database_add(ds_doc{3});
    
    %create a new daqsystem with ndi_document
    ds_withdoc = ndi_daqsystem(E,ds_doc{3});
    
    %Verify if the two objects created with two methods are indeed equal
    if eq(ds,ds_withdoc) == 1
        disp("Success")
    else
        disp("Fail")
    end
end
