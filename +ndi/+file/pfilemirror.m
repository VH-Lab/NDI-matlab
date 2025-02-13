function b = pfilemirror(m_path,p_path)
    %PFILEMIRROR Mirror a directory with m files into a directory with p files
    %  B = PFILEMIRROR(M_PATH, P_PATH)
    %
    % Recursively copy a directory with .m files into a directory of .p files.
    % M_PATH is a full path of a directory with .m files and subdirectories,
    % and P_PATH is the location where the mirrored .p files should be placed.
    %

    b = 0;
    files = dir(m_path);

    for i = 1:numel(files)
        if ~strcmp(files(i).name, '.') && ~strcmp(files(i).name, '..')
            src_path = fullfile(m_path, files(i).name);
            [~, name, ext] = fileparts(files(i).name);

            if files(i).isdir
                dest_path = fullfile(p_path, files(i).name);
                if ~exist(dest_path, 'dir')
                    mkdir(dest_path);
                end
                b = ndi.file.pfilemirror(src_path, dest_path);
                if ~b
                    return;
                end
            elseif endsWith(files(i).name, '.m')
                dest_path = fullfile(p_path, [name, '.p']);
                if ~exist(p_path, 'dir')
                    mkdir(p_path);
                end
                pcode(src_path,'-inplace');
                if ~exist(dest_path, 'file') || ~vlt.file.arefilessame([src_path(1:end-2), '.p'], dest_path)
                    movefile([src_path(1:end-2), '.p'], dest_path);
                else
                    delete([src_path(1:end-2), '.p']);
                end

            else
                dest_path = fullfile(p_path, files(i).name);
                if ~exist(p_path, 'dir')
                    mkdir(p_path);
                end
                copyfile(src_path, dest_path);
            end
        end
    end
    b = 1;
end
