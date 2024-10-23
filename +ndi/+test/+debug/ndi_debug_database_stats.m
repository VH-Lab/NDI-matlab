function out = ndi_debug_database_stats(E)
    % NDI_DEBUG_DATABASE_STATS - examine an NDI database to check for inconsistencies
    %
    % OUT = ndi.test.database.debug_stats(E)
    %
    % Return a bunch of documents from an NDI session E
    %

    Dmissing = ndi.database.fun.finddocs.missing.dependencies(E);
    Dall = E.database_search({'document_class.class_name','(.*)'});
    Dall2 = E.database_search({'base.id','(.*)'});

    sq_stim = ndi.query('','isa','stimulus_presentation','');
    stim_doc = E.database_search(sq_stim);
    if ~isempty(stim_doc),
        d_dep = ndi.database.fun.findalldependencies(E,[],stim_doc{1});
    end;


    out = vlt.data.workspace2struct;
    out = rmfield(out,'E');
