function b = pfilemirror(m_path, p_path, options)
%PFILEMIRROR Mirror a directory with m files into a directory with p files
%  B = PFILEMIRROR(M_PATH, P_PATH)
%
% Recursively copy a directory with .m files into a directory of .p files.
% M_PATH is a full path of a directory with .m files and subdirectories,
% and P_PATH is the location where the mirrored .p files should be placed.
%
% This function can be called with name-value pairs:
% 'CopyNonMFiles'      (logical)  Should non .m-files be copied? Default false.
% 'CopyHiddenFiles'    (logical)  Should hidden files (e.g. .git) be copied?
%                                 Default false.
% 'verbose'            (logical)  Print files as they are copied? Default true.
% 'dryRun'             (logical)  If true, display actions without executing them.
%                                 Default false.
%

    arguments
        m_path (1,1) string {mustBeFolder}
        p_path (1,:) char
        options.CopyNonMFiles (1,1) logical = false
        options.CopyHiddenFiles (1,1) logical = false
        options.verbose (1,1) logical = true
        options.dryRun (1,1) logical = false
    end

    b = 0;
    files = dir(m_path);
    for i = 1:numel(files)
        % Skip '.', '..', '.git', and, if requested, other hidden files
        if strcmp(files(i).name, '.') || strcmp(files(i).name, '..') || strcmp(files(i).name, '.git')
            continue;
        end
        if ~options.CopyHiddenFiles && startsWith(files(i).name, '.')
            continue;
        end

        src_path = fullfile(m_path, files(i).name);
        [~, name, ~] = fileparts(files(i).name);

        if files(i).isdir
            dest_path = fullfile(p_path, files(i).name);
            if ~isfolder(dest_path)
                if options.verbose || options.dryRun
                    fprintf('Action: Create directory %s\n', dest_path);
                end
                if ~options.dryRun
                    mkdir(dest_path);
                end
            end
            % Recurse with the same options, using namespace
            b = ndi.file.pfilemirror(src_path, dest_path, ...
                "CopyNonMFiles", options.CopyNonMFiles, ...
                "CopyHiddenFiles", options.CopyHiddenFiles, ...
                "verbose", options.verbose, ...
                "dryRun", options.dryRun);
            if ~b
                return;
            end
        elseif endsWith(files(i).name, '.m')
            dest_path = fullfile(p_path, [name, '.p']);
            if ~isfolder(p_path)
                 if options.verbose || options.dryRun
                    fprintf('Action: Create directory %s\n', p_path);
                end
                if ~options.dryRun
                    mkdir(p_path);
                end
            end
            
            if options.verbose || options.dryRun
                fprintf('Action: P-code %s\n', src_path);
            end
            
            p_file_generated = fullfile(m_path, [name, '.p']);

            if options.dryRun
                % --- DRY RUN LOGIC ---
                if ~isfile(dest_path)
                    fprintf('Action: Move %s to %s\n', p_file_generated, dest_path);
                else
                    % We can't know if files are the same without creating one.
                    fprintf('Action: Overwrite %s with new file %s\n', dest_path, p_file_generated);
                end
            else
                % --- REAL RUN LOGIC (Now with forced overwrite) ---
                pcode(src_path,'-inplace');
                
                if options.verbose
                    fprintf('Action: Moving/Overwriting %s\n', dest_path);
                end
                % Unconditionally move the generated p-file, overwriting the destination.
                movefile(p_file_generated, dest_path);
            end
        else
            % This block handles all non-.m files
            if options.CopyNonMFiles
                dest_path = fullfile(p_path, files(i).name);
                if ~isfolder(p_path)
                    if options.verbose || options.dryRun
                        fprintf('Action: Create directory %s\n', p_path);
                    end
                    if ~options.dryRun
                        mkdir(p_path);
                    end
                end
                if options.verbose || options.dryRun
                    fprintf('Action: Copy %s to %s\n', src_path, dest_path);
                end
                if ~options.dryRun
                    copyfile(src_path, dest_path);
                end
            end
        end
    end
    b = 1;
end