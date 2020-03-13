%This function tests the creator and newdocument() of daqsystem
function test_daqsystem(ft,dq)
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