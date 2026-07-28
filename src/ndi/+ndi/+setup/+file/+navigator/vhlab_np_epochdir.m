classdef vhlab_np_epochdir < ndi.file.navigator.epochdir
    % NDI.SETUP.FILE.NAVIGATOR.VHLAB_NP_EPOCHDIR - epochdir file navigator
    % for vhlab AJBPod-on-Neuropixels (SpikeGLX) sessions.
    %
    % In these sessions each SpikeGLX run lives in an Epoch*_g0 subdirectory
    % of the session directory. The shared SpikeGLX files (the .nidq.bin /
    % .nidq.meta NI-DAQ recording and the .imec0.ap.meta probe file) sit at
    % the top of that *_g0 directory, while the AJBPod stimulus log for each
    % stimulus presentation is placed one level deeper, inside an Epoch_Set_X
    % subdirectory, as a matched pair of files: a
    % '*_stimulus_triggers_log.tsv' and a '*_summary_log.json'.
    %
    % A single *_g0 run may contain several stimulus presentations
    % (Epoch_Set_1, Epoch_Set_2, ...). This navigator therefore treats each
    % Epoch_Set_X as one epoch, pooling that set's .tsv / .json with the
    % shared SpikeGLX files from the parent *_g0 directory so a VHAudreyBPod
    % reader can combine the stimulus log with the NI-DAQ trigger recording.
    %
    % An Epoch_Set_X only becomes an epoch if the resulting file group
    % satisfies EVERY configured FileParameter (an AND, matching the stock
    % ndi.file.navigator.epochdir semantics): all of the SpikeGLX files AND
    % the set's .tsv and .json must be present. A *_g0 directory that has
    % only the SpikeGLX files but no stimulus log (a partial match) does not
    % form an epoch -- previously such a directory formed a phantom epoch
    % whose epoch probe map could not be resolved.
    %

    methods
        function obj = vhlab_np_epochdir(varargin)
            obj = obj@ndi.file.navigator.epochdir(varargin{:});
        end % constructor

        function id = epochid(obj, epoch_number, epochfiles)
            % EPOCHID - return the epoch identifier for an epoch.
            %
            % Each epoch corresponds to one Epoch_Set_X subdirectory of a
            % first-level *_g0 directory of the session. The returned id is
            % '<g0dir>_<Epoch_Set_dir>' so that multiple stimulus sets within
            % one *_g0 run receive distinct epoch ids (and distinct hidden
            % bookkeeping file names, which the base navigator derives from
            % the first file of the group).
            %
            if nargin < 3
                epochfiles = getepochfiles(obj, epoch_number);
            end
            if ndi.file.navigator.isingested(epochfiles)
                id = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
                return;
            end
            sess_path = obj.path();

            % The stimulus-trigger .tsv is what defines the set; use it to
            % locate the Epoch_Set directory. Fall back to the first file.
            setfile = '';
            for i = 1:numel(epochfiles)
                [~,~,ext] = fileparts(epochfiles{i});
                if strcmpi(ext, '.tsv')
                    setfile = epochfiles{i};
                    break;
                end
            end
            if isempty(setfile)
                setfile = epochfiles{1};
            end

            rel = setfile;
            prefix = [sess_path filesep];
            if startsWith(rel, prefix)
                rel = rel(numel(prefix)+1:end);
            end
            parts = strsplit(rel, filesep);
            if numel(parts) >= 2
                % parts{1} is the *_g0 directory; parts{2} is the immediate
                % Epoch_Set subdirectory that holds this set's files.
                id = [parts{1} '_' parts{2}];
            else
                id = parts{1};
            end
        end % epochid

        function [epochfiles_disk] = selectfilegroups_disk(obj)
            % SELECTFILEGROUPS_DISK - find epoch file groups on disk.
            %
            % One epoch is returned per Epoch_Set_X subdirectory of a
            % first-level *_g0 directory of the session, provided the
            % combined file group (the shared SpikeGLX files at the top of
            % the *_g0 directory plus the files gathered under the set
            % subdirectory) contains at least one file matching EVERY
            % configured FileParameter. Sets that do not complete the match
            % (for example a *_g0 directory with only SpikeGLX files and no
            % stimulus log, or a non-set subdirectory such as *_imec0) are
            % skipped.

            exp_path = obj.path();
            epochfiles_disk = {};
            if ~isfolder(exp_path)
                return;
            end

            filematch = obj.fileparameters.filematch;
            if ischar(filematch)
                filematch = {filematch};
            end
            regexes = ndi.setup.file.navigator.vhlab_np_epochdir.filematch2regex(filematch);

            g0_dirs = ndi.setup.file.navigator.vhlab_np_epochdir.immediate_subdirs(exp_path);

            for k = 1:numel(g0_dirs)
                g0_path = fullfile(exp_path, g0_dirs{k});

                % Shared SpikeGLX files live directly in the *_g0 directory
                % (do not descend into the Epoch_Set subdirectories here).
                shared = ndi.setup.file.navigator.vhlab_np_epochdir.gather_matching_files(...
                    g0_path, filematch, false);

                % Each immediate subdirectory of the *_g0 directory is a
                % candidate Epoch_Set; the .tsv / .json may be nested one
                % level deeper, so gather them recursively.
                set_dirs = ndi.setup.file.navigator.vhlab_np_epochdir.immediate_subdirs(g0_path);
                for s = 1:numel(set_dirs)
                    set_path = fullfile(g0_path, set_dirs{s});
                    setfiles = ndi.setup.file.navigator.vhlab_np_epochdir.gather_matching_files(...
                        set_path, filematch, true);
                    if isempty(setfiles)
                        continue;
                    end

                    % Put the stimulus-trigger .tsv first so it becomes
                    % epochfiles{1}: the base navigator derives the per-epoch
                    % epoch-id and hidden id/probe-map file names from the
                    % first file, and this keeps them unique per Epoch_Set
                    % rather than colliding on the shared SpikeGLX files.
                    setfiles = ndi.setup.file.navigator.vhlab_np_epochdir.tsv_first(setfiles);

                    group = [setfiles(:); shared(:)];
                    if ndi.setup.file.navigator.vhlab_np_epochdir.covers_all(group, regexes)
                        epochfiles_disk{end+1,1} = group; %#ok<AGROW>
                    end
                end
            end
        end % selectfilegroups_disk
    end % methods

    methods (Static, Access = private)
        function names = immediate_subdirs(rootdir)
            % IMMEDIATE_SUBDIRS - names of the immediate, non-hidden
            % subdirectories of ROOTDIR, sorted for deterministic epoch
            % ordering.
            names = {};
            if ~isfolder(rootdir)
                return;
            end
            d = dir(rootdir);
            for i = 1:numel(d)
                if ~d(i).isdir
                    continue;
                end
                if d(i).name(1) == '.'   % skips '.', '..', and dot-directories
                    continue;
                end
                names{end+1,1} = d(i).name; %#ok<AGROW>
            end
            names = sort(names);
        end % immediate_subdirs

        function regexes = filematch2regex(filematch)
            % FILEMATCH2REGEX - convert FileParameters patterns to plain
            % regexes. The same-substring symbol ('#') supported by
            % vlt.file.findfilegroups is expanded to '.*'; every other
            % character is left as-is (the vhlab DAQ configuration already
            % uses regular-expression patterns).
            if ischar(filematch)
                filematch = {filematch};
            end
            regexes = cell(size(filematch));
            for i = 1:numel(filematch)
                regexes{i} = strrep(filematch{i}, '#', '.*');
            end
        end % filematch2regex

        function files = gather_matching_files(rootdir, filematch, recurse)
            % GATHER_MATCHING_FILES - return a column cell array of full
            % paths for every file under ROOTDIR whose basename matches any
            % pattern in FILEMATCH. When RECURSE is true (default) the whole
            % tree below ROOTDIR is walked; when false only the immediate
            % files of ROOTDIR are considered. Hidden entries (names
            % beginning with '.') are skipped, so OS/version-control
            % directories such as '.git' are never traversed.
            if nargin < 3
                recurse = true;
            end
            files = {};
            if ~isfolder(rootdir)
                return;
            end
            regexes = ndi.setup.file.navigator.vhlab_np_epochdir.filematch2regex(filematch);

            stack = {rootdir};
            while ~isempty(stack)
                cur = stack{end};
                stack(end) = [];
                entries = dir(cur);
                for i = 1:numel(entries)
                    if entries(i).name(1) == '.'
                        continue;
                    end
                    full = fullfile(cur, entries(i).name);
                    if entries(i).isdir
                        if recurse
                            stack{end+1} = full; %#ok<AGROW>
                        end
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

        function files = tsv_first(files)
            % TSV_FIRST - reorder FILES so that a '.tsv' file (the stimulus
            % trigger log) is first, if one is present.
            istsv = false(numel(files),1);
            for i = 1:numel(files)
                [~,~,ext] = fileparts(files{i});
                istsv(i) = strcmpi(ext, '.tsv');
            end
            idx = find(istsv, 1, 'first');
            if ~isempty(idx)
                rest = (1:numel(files))';
                rest(idx) = [];
                files = files([idx; rest]);
            end
        end % tsv_first

        function tf = covers_all(files, regexes)
            % COVERS_ALL - true if, for every regex in REGEXES, at least one
            % file in FILES has a basename matching it (an AND over the
            % configured FileParameters).
            tf = true;
            for r = 1:numel(regexes)
                matched = false;
                for i = 1:numel(files)
                    [~, nm, ext] = fileparts(files{i});
                    if ~isempty(regexp([nm ext], regexes{r}, 'once'))
                        matched = true;
                        break;
                    end
                end
                if ~matched
                    tf = false;
                    return;
                end
            end
        end % covers_all
    end % static methods
end
