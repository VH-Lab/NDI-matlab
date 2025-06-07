function makesubjects(S, n)
    % MAKESUBJECTS - make text files for subjects
    %
    % MAKESUBJECTS(S, N)
    %
    % Make subject*.txt files for N subjects.
    %

    dirname = S.path();

    [parentdir,this_dir] = fileparts(dirname);

    for i=1:n
        vlt.file.str2text(...
            [dirname filesep 'subject' int2str(i) '.txt'], ...
            [this_dir '_' sprintf('%.2d',i) '@marderlab.brandeis.edu']);

    end;
