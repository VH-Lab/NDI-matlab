function d = find_ingested_docs(S)
    % FIND_INGESTED_DOCS - find ingested documents from an ndi.session
    %
    % D = FIND_INGESTED_DOCS(S)
    %
    % Return all documents in ndi.session S that correspond to ingested data.
    %

    q_i1 = ndi.query('','isa','daqreader_mfdaq_epochdata_ingested');
    q_i2 = ndi.query('','isa','daqmetadatareader_epochdata_ingested');
    q_i3 = ndi.query('','isa','epochfiles_ingested');

    d = S.database_search( q_i1 | q_i2 | q_i3 );
