function test_filenavigator_documents(dirname)
    %Test new_document() method in ndi_filenavigator as well as
    %ndi_filenavigator constructor using new ndi_filenavigator(ndi_experiment, ndi_document)

    ndi_globals;

    %No directory has passed in as a parameter
    if nargin<1
        dirname = [ndiexampleexperpath filesep 'exp1_eg'];
    end

    %Create and NDI_experiment object
    E = ndi_experiment_dir('exp1',dirname);

    ft = ndi_filenavigator(E, '.*\.rhd\>');

    %Delete any demo ndi_document stored in the experiment
    doc = E.database_search(ndi_query('','isa','ndi_document_filenavigator.json',''));
    E.database_rm(cell2str(doc));

    %Test the ndi_document creater
    ft_doc = ft.newdocument();
    disp("Sucessfully created a ndi_document")

    %Store the document as database
    E.database_add(ft_doc);
    doc = E.database_search(ndi_query('','isa','ndi_document_filenavigator.json',''));

    %Initialize the filenavigator using the ndi_document
    ft_withdoc = ndi_filenavigator(E, doc{1});
    
    %Check if the two filenavigator is equals
    if eq(ft_withdoc,ft)
        disp("Creater Method is sucessful")
    else
        disp("Some issue with the creater")
    end  
end