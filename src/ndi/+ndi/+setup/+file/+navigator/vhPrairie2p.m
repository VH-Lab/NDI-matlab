classdef vhPrairie2p < ndi.file.navigator
    % NDI.SETUP.FILE.NAVIGATOR.VHPRAIRIE2P - file navigator for vhlab Prairie 2-photon sessions
    %
    % In vhlab PrairieView 2-photon sessions an epoch is not contained in a
    % single directory: it is defined by a PAIR (rarely a small set) of
    % sibling directories whose names are related by a numeric suffix.
    %
    %   <BASE>/reference.txt      - index file written by the master acquisition
    %                               system; its presence marks an epoch.
    %   <BASE>/frametrigger.txt   - frame-trigger times used to synchronize this
    %                               recording to another clock (e.g. vhspike2).
    %   <BASE>-001/, <BASE>-002/  - PrairieView acquisition directories holding
    %                               the TIFF frames and the '.xml'/'.pcf' config.
    %                               Usually only '-001' exists; very rarely an
    %                               epoch spans '-001','-002',... (the cycles of
    %                               the run), and those all belong to ONE epoch.
    %
    % The default navigator cannot assemble these epochs: vlt.file.findfilegroups
    % only groups files that co-occur WITHIN a single directory, and its '#'
    % same-string symbol matches within one directory's file names. The
    % <BASE> <-> <BASE>-NNN relationship lives in the directory NAMES (with a
    % '-NNN' suffix on one side), which '#' cannot express. This navigator
    % therefore overrides SELECTFILEGROUPS_DISK with the directory-pairing rule.
    %
    % An epoch's file group is:
    %   <BASE>/reference.txt, <BASE>/frametrigger.txt (if present), and the
    %   non-TIFF config/metadata files of each <BASE>-NNN acquisition directory.
    % The image frames themselves are not enumerated here: the reader
    % (ndi.daq.reader.image.ndr('prairieview')) resolves the TIFFs from each
    % config file's directory. This keeps the epoch file list compact even when
    % an acquisition contains thousands of TIFFs.
    %
    % EPOCHID is the <BASE> directory name.
    %
    % See also: NDI.FILE.NAVIGATOR, NDI.FILE.NAVIGATOR.RHD_SERIES,
    %   NDI.SETUP.FILE.NAVIGATOR.VHLAB_NP_EPOCHDIR, NDR.READER.PRAIRIEVIEW

    properties (Constant)
        INDEX_FILE = 'reference.txt'        % index file in <BASE> that marks an epoch
        SYNC_FILE  = 'frametrigger.txt'     % frame-trigger sync file in <BASE>
    end

    methods
        function obj = vhPrairie2p(varargin)
            % VHPRAIRIE2P - construct a vhlab Prairie 2-photon file navigator
            %
            %   OBJ = NDI.SETUP.FILE.NAVIGATOR.VHPRAIRIE2P(SESSION, ...)
            %
            % Takes the same arguments as ndi.file.navigator. The
            % fileparameters/filematch are not used to discover epochs (the
            % directory-pairing rule is fixed), but are passed through so the
            % navigator can be saved/loaded like any other.
            obj = obj@ndi.file.navigator(varargin{:});
        end % constructor

        function id = epochid(obj, epoch_number, epochfiles)
            % EPOCHID - return the epoch identifier (the <BASE> directory name)
            %
            %   ID = EPOCHID(OBJ, EPOCH_NUMBER, [EPOCHFILES])
            %
            if nargin < 3
                epochfiles = getepochfiles(obj, epoch_number);
            end
            if ndi.file.navigator.isingested(epochfiles)
                id = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
                return;
            end
            % epochfiles{1} is always <BASE>/reference.txt; its parent folder
            % name is the epoch id.
            [basedir, ~] = fileparts(epochfiles{1});
            [~, id] = fileparts(basedir);
        end % epochid

        function [epochfiles_disk] = selectfilegroups_disk(obj)
            % SELECTFILEGROUPS_DISK - assemble epochs from <BASE> / <BASE>-NNN directory pairs
            %
            %   EPOCHFILES_DISK = SELECTFILEGROUPS_DISK(OBJ)
            %
            % Each first-level subdirectory of the session that contains a
            % 'reference.txt' is a <BASE>. For each <BASE> that also has at
            % least one sibling '<BASE>-NNN' acquisition directory, one epoch
            % is returned whose files are reference.txt, frametrigger.txt (if
            % present), and the non-TIFF metadata of each acquisition directory.
            %
            epochfiles_disk = {};
            exp_path = obj.path();
            if ~isfolder(exp_path)
                return;
            end

            d = dir(exp_path);
            d = d(~ismember({d.name}, {'.','..'}));
            subdirs = d([d.isdir]);
            % drop hidden directories
            isvis = arrayfun(@(e) e.name(1) ~= '.', subdirs);
            subdirs = subdirs(isvis);
            names = {subdirs.name};

            for k = 1:numel(names)
                B = names{k};
                refpath = fullfile(exp_path, B, obj.INDEX_FILE);
                if ~isfile(refpath)
                    continue; % not a <BASE>: no index file
                end

                acq = ndi.setup.file.navigator.vhPrairie2p.acquisitionDirs(names, B);
                if isempty(acq)
                    continue; % no paired acquisition directory -> not a usable epoch
                end

                grp = {refpath};
                syncpath = fullfile(exp_path, B, obj.SYNC_FILE);
                if isfile(syncpath)
                    grp{end+1,1} = syncpath; %#ok<AGROW>
                end
                for a = 1:numel(acq)
                    adir = fullfile(exp_path, acq{a});
                    anchors = ndi.setup.file.navigator.vhPrairie2p.nonTiffFiles(adir);
                    grp = [grp; anchors(:)]; %#ok<AGROW>
                end

                epochfiles_disk{end+1,1} = grp(:)'; %#ok<AGROW>
            end

            epochfiles_disk = ndi.util.removehiddenfilegroups(epochfiles_disk);
        end % selectfilegroups_disk
    end % methods

    methods (Static, Access = private)
        function acq = acquisitionDirs(names, B)
            % ACQUISITIONDIRS - sibling directory names of the form '<B>-NNN', sorted
            pat = ['^' regexptranslate('escape', B) '-\d+$'];
            tf = ~cellfun(@isempty, regexp(names, pat, 'once'));
            acq = sort(names(tf));
        end % acquisitionDirs

        function files = nonTiffFiles(adir)
            % NONTIFFFILES - full paths of the non-TIFF, non-hidden files directly in ADIR
            %
            % These are the PrairieView config/metadata files (.xml/.pcf/.env/.cfg,
            % frame-time sidecars, ...) that anchor the acquisition directory; the
            % image reader resolves the TIFF frames from each anchor's directory.
            files = {};
            if ~isfolder(adir)
                return;
            end
            e = dir(adir);
            for i = 1:numel(e)
                if e(i).isdir || e(i).name(1) == '.'
                    continue;
                end
                [~,~,ext] = fileparts(e(i).name);
                if any(strcmpi(ext, {'.tif','.tiff'}))
                    continue; % frames are resolved by the reader, not listed here
                end
                files{end+1,1} = fullfile(adir, e(i).name); %#ok<AGROW>
            end
        end % nonTiffFiles
    end % static methods
end % classdef
