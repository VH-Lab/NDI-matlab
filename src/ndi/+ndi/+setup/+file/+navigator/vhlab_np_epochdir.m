classdef vhlab_np_epochdir < ndi.file.navigator.epochdir
    % NDI.SETUP.FILE.NAVIGATOR.VHLAB_NP_EPOCHDIR - epochdir file navigator
    % that recurses into per-epoch subdirectories (e.g. Epoch_Set_1).
    %
    % In vhlab SpikeGLX / Neuropixels GLX sessions, each epoch lives in an
    % Epoch*_g0 subdirectory of the session directory (same as the standard
    % epochdir layout), but the AJBPod stimulus log files (TSV + JSON) are
    % placed one level deeper inside an Epoch_Set_X subdirectory of that
    % epoch directory. The default ndi.file.navigator.epochdir only scans
    % the immediate epoch directory (SearchDepth=1) and therefore misses
    % those files.
    %
    % This navigator treats each first-level subdirectory of the session as
    % one epoch and recursively collects every file (across all nested
    % subdirectories) whose basename matches any of the configured
    % FileParameters. All matching files are returned as a single epoch
    % file group, so a VHAudreyBPodNP reader can combine the TSV / JSON
    % with the SpikeGLX .nidq files from the parent epoch directory.
    %

    methods
        function obj = vhlab_np_epochdir(varargin)
            obj = obj@ndi.file.navigator.epochdir(varargin{:});
        end % constructor

        function id = epochid(obj, epoch_number, epochfiles)
            % EPOCHID - return the epoch identifier for an epoch.
            %
            % For this navigator, each epoch corresponds to a first-level
            % subdirectory of the session directory (e.g. Epoch1_g0). The
            % returned id is the name of that subdirectory, regardless of
            % how deeply nested the individual files in EPOCHFILES are.
            %
            if nargin < 3
                epochfiles = getepochfiles(obj, epoch_number);
            end
            if ndi.file.navigator.isingested(epochfiles)
                id = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
                return;
            end
            sess_path = obj.path();
            % Use the first file to walk upward until its parent is the
            % session directory; that parent is the epoch directory.
            fpath = epochfiles{1};
            id = '';
            while true
                [parent, name] = fileparts(fpath);
                if isempty(parent) || strcmp(parent, fpath)
                    break;
                end
                if strcmp(parent, sess_path)
                    id = name;
                    return;
                end
                fpath = parent;
            end
            % fallback to default behaviour
            [pathdir, ~] = fileparts(epochfiles{1});
            [~, id] = fileparts(pathdir);
        end % epochid

        function [epochfiles_disk] = selectfilegroups_disk(obj)
            % SELECTFILEGROUPS_DISK - find epoch file groups by walking
            % each Epoch*_g0 directory recursively.

            exp_path = obj.path();
            epochfiles_disk = {};
            if ~isfolder(exp_path)
                return;
            end

            d = dir(exp_path);
            d = d(~ismember({d.name}, {'.','..'}));
            epoch_dirs = d([d.isdir]);

            % Get the file-match patterns as a cell array of regexes
            filematch = obj.fileparameters.filematch;
            if ischar(filematch)
                filematch = {filematch};
            end

            for k = 1:numel(epoch_dirs)
                if epoch_dirs(k).name(1) == '.'
                    continue;
                end
                epoch_path = fullfile(exp_path, epoch_dirs(k).name);

                matches = ndi.setup.file.navigator.vhlab_np_epochdir.gather_matching_files(epoch_path, filematch);
                if ~isempty(matches)
                    epochfiles_disk{end+1,1} = matches; %#ok<AGROW>
                end
            end
        end % selectfilegroups_disk
    end % methods

    methods (Static, Access = private)
        function files = gather_matching_files(rootdir, filematch)
            % GATHER_MATCHING_FILES - recursively walk ROOTDIR and return a
            % column cell array of full paths for every file whose basename
            % matches any of the regexes in FILEMATCH. The same
            % same-string-substitution symbol ('#') supported by
            % vlt.file.findfilegroups is expanded to '.*' here so multiple
            % loosely-coupled files can be collected together.
            files = {};
            if ~isfolder(rootdir)
                return;
            end

            % Convert '#' placeholders into '.*' so each pattern is a
            % plain regex. Uniqueness of the substitution string is not
            % enforced here (this navigator groups by directory, not by
            % substitution string).
            regexes = cell(size(filematch));
            for i = 1:numel(filematch)
                pat = filematch{i};
                pat = strrep(pat, '#', '.*');
                regexes{i} = pat;
            end

            stack = {rootdir};
            while ~isempty(stack)
                cur = stack{end};
                stack(end) = [];
                entries = dir(cur);
                for i = 1:numel(entries)
                    if strcmp(entries(i).name, '.') || strcmp(entries(i).name, '..')
                        continue;
                    end
                    full = fullfile(cur, entries(i).name);
                    if entries(i).isdir
                        stack{end+1} = full; %#ok<AGROW>
                    else
                        for r = 1:numel(regexes)
                            if ~isempty(regexp(entries(i).name, regexes{r}, 'once'))
                                files{end+1,1} = full; %#ok<AGROW>
                                break;
                            end
                        end
                    end
                end
            end
        end % gather_matching_files
    end % static methods
end
