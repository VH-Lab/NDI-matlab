function ndi_test_sessiontable
    % NDI_TEST_SESSIONTABLE
    %
    % Test the ndi.session.sessiontable object
    %

    st = ndi.session.sessiontable();

    % backup any current file

    st.backupsessiontable();
    st.clearsessiontable();

    st.addtableentry('12345','~/Desktop/myexperiment');

    t = st.getsessiontable();

    if numel(t)~=1,
        error(['Session table does not have right number of entries.']);
    end;

    [b,results]=st.checktable();

    st.removetableentry('12345');

    t = st.getsessiontable();

    if numel(t)~=0,
        error(['Session table does not have right number of entries.']);
    end;

    st.clearsessiontable();

    f = st.backupfilelist();

    if numel(f)>0,
        % small risk, file not locked or checked out
        movefile(f{end},ndi.session.sessiontable.localtablefilename());
    end;

