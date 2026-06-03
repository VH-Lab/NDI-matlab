classdef rhd_series_epochdir < ndi.file.navigator.epochdir
    %NDI.FILE.NAVIGATOR.RHD_SERIES_EPOCHDIR Epochdir navigator for prefix-grouped .rhd recordings.
    %
    %   An NDI.FILE.NAVIGATOR.RHD_SERIES_EPOCHDIR is the epochdir-organized
    %   counterpart of NDI.FILE.NAVIGATOR.RHD_SERIES. Each first-level
    %   subdirectory of the session is treated as a candidate epoch
    %   container; within each subdirectory, .rhd files that share a common
    %   prefix but differ in a trailing variable portion (typically a
    %   YYYYMMDDHHMMSS.msec timestamp) are grouped, and only the
    %   lexicographically earliest member of each group is returned (the
    %   Intan reader recovers the rest of the series from that file).
    %   Ancillary files matched through the standard '#' substitution
    %   syntax are searched for in the same subdirectory.
    %
    %   FILEPARAMETERS
    %       The filematch list is interpreted exactly as in
    %       NDI.FILE.NAVIGATOR.RHD_SERIES; the only difference is that
    %       matching is performed independently in each first-level
    %       subdirectory of the session rather than in the session root.
    %
    %       patterns{1} - Series pattern. Contains exactly one '#'
    %                     capturing the per-epoch prefix; the remainder is
    %                     a regular expression matching the variable part
    %                     of the filename.
    %
    %       patterns{2:end} - Ancillary patterns. '#' is replaced by the
    %                     literal (regex-escaped) prefix of the current
    %                     epoch and the result is matched as a regular
    %                     expression against filenames in the same
    %                     subdirectory. The lexicographically earliest
    %                     match per pattern is appended to the epoch's
    %                     file list. If any ancillary pattern produces no
    %                     match the epoch is skipped.
    %
    %   The epoch identifier returned by EPOCHID is the name of the
    %   subdirectory that contains the epoch's files, matching the
    %   convention of NDI.FILE.NAVIGATOR.EPOCHDIR.
    %
    %   Example
    %       fn = ndi.file.navigator.rhd_series_epochdir(E, ...
    %           {'#_\d{14}\.\d+\.rhd\>', '#\.epochprobemap\.ndi\>'});
    %
    %   See also NDI.FILE.NAVIGATOR.EPOCHDIR, NDI.FILE.NAVIGATOR.RHD_SERIES,
    %            NDI.FILE.NAVIGATOR

    methods
        function obj = rhd_series_epochdir(varargin)
            %RHD_SERIES_EPOCHDIR Construct an ndi.file.navigator.rhd_series_epochdir.
            %
            %   OBJ = NDI.FILE.NAVIGATOR.RHD_SERIES_EPOCHDIR(SESSION, FILEPARAMETERS)
            %   creates a navigator for SESSION with the given FILEPARAMETERS.
            %   See the class documentation for the FILEPARAMETERS contract.
            %   Any additional constructor arguments accepted by
            %   NDI.FILE.NAVIGATOR.EPOCHDIR are passed through.
            obj = obj@ndi.file.navigator.epochdir(varargin{:});
        end

        function id = epochid(obj, epoch_number, epochfiles)
            %EPOCHID Return the epoch identifier (subdirectory name).
            %
            %   ID = EPOCHID(OBJ, EPOCH_NUMBER) returns the name of the
            %   subdirectory that contains the epoch's files. If the
            %   epoch's files are ingested, the inherited ingested-file
            %   identifier is returned instead.
            %
            %   ID = EPOCHID(OBJ, EPOCH_NUMBER, EPOCHFILES) uses the
            %   supplied EPOCHFILES instead of looking them up.
            if nargin < 3
                epochfiles = getepochfiles(obj, epoch_number);
            end
            if ndi.file.navigator.isingested(epochfiles)
                id = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
                return;
            end
            [pathdir, ~] = fileparts(epochfiles{1});
            [~, id] = fileparts(pathdir);
        end

        function epochfiles_disk = selectfilegroups_disk(obj)
            %SELECTFILEGROUPS_DISK Return groups of files that comprise epochs.
            %
            %   EPOCHFILES_DISK = SELECTFILEGROUPS_DISK(OBJ) walks the
            %   first-level subdirectories of the session and applies the
            %   rhd_series matching rules to each. Every prefix group
            %   found in a subdirectory contributes one epoch whose file
            %   list is the first .rhd of the group followed by any
            %   ancillary matches found in the same subdirectory.
            epochfiles_disk = {};
            sess = obj.path();
            if ~isfolder(sess)
                return;
            end
            patterns = ndi.file.navigator.rhd_series.normalizePatterns(...
                obj.fileparameters.filematch);
            if isempty(patterns)
                return;
            end

            entries = dir(sess);
            entries = entries(~ismember({entries.name}, {'.','..'}));
            subdirs = entries([entries.isdir]);

            for k = 1:numel(subdirs)
                if subdirs(k).name(1) == '.'
                    continue;
                end
                epochPath = fullfile(sess, subdirs(k).name);
                groups = ndi.file.navigator.rhd_series.groupDirectory(...
                    epochPath, patterns);
                for g = 1:numel(groups)
                    epochfiles_disk{end+1,1} = groups{g}; %#ok<AGROW>
                end
            end
            % drop hidden files and macOS AppleDouble ('._') shadow files
            epochfiles_disk = ndi.util.removehiddenfilegroups(epochfiles_disk);
        end
    end % methods
end
