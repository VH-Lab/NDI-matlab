function [b,msg] = compare(D1,D2)
    % COMPARE datasets for equality
    %
    % [B,MSG] = COMPARE(D1, D2)
    %
    % Compare two datasets for equality. If the datasets
    % have the same documents and files, then B is 1 and
    % MSG is ''. Otherwise, B is 0 and MSG contains a
    % description of the first difference encountered.
    %

    arguments
        D1 (1,1) ndi.dataset
        D2 (1,1) ndi.dataset
    end

    b = 0;
    msg = '';

    d1 = D1.database_search(ndi.query('base.id','regexp','(.*)'));
    d2 = D2.database_search(ndi.query('base.id','regexp','(.*)'));

    d1_id = {};
    d2_id = {};
    for i=1:numel(d1),
        d1_id{i} = d1{i}.document_properties.base.id;
    end;
    for i=1:numel(d2),
        d2_id{i} = d2{i}.document_properties.base.id;
    end;

    [d1_in_d2,d1_in_d2_indexes] = ismember(d1_id,d2_id);
    [d2_in_d1,d2_in_d1_indexes] = ismember(d2_id,d1_id);

    % it is possible for d2 to have extra 'session' documents compared to
    % d1. That is okay.

    if ~all(d1_in_d2),
        ids_missing_index = find(d1_in_d2==0);
        ids_missing = d1_id(ids_missing_index);
        ids_missing_str = strjoin(ids_missing,', ');
        msg = ['Documents from D1 are missing in D2: ' ids_missing_str];
        return;
    end;

    % okay, now compare files

    for i=1:numel(d1),
        f1 = d1{i}.current_file_list();
        f2 = d2{d1_in_d2_indexes(i)}.current_file_list();
        if ~isequal(f1,f2),
            msg = ['File list for id ' d1_id{i} ' is different between D1 and D2.'];
            return;
        end;

        for f=1:numel(f1),
            file1 = D1.database_openbinarydoc(d1{i},f1{f});
            file2 = D2.database_openbinarydoc(d2{d1_in_d2_indexes(i)},f1{f});
            b_ = ndi.test.file.compare_fileobj(file1,file2);
            D1.database_closebinarydoc(file1);
            D1.database_closebinarydoc(file2);
            if ~b_,
                msg = ['Binary file ' f1{f} ' in document ' d1_id{i} ' does not match.'];
            end;
        end;
    end;

    % we made it

    b = 1;
