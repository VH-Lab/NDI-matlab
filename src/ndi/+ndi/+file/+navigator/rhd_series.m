classdef rhd_series < ndi.file.navigator
    %NDI.FILE.NAVIGATOR.RHD_SERIES File navigator for prefix-grouped .rhd recordings.
    %
    %   An NDI.FILE.NAVIGATOR.RHD_SERIES groups .rhd files that share a common
    %   prefix but differ in a trailing variable portion (typically a
    %   YYYYMMDDHHMMSS.msec timestamp) into a single epoch. Because the Intan
    %   reader can discover the remaining files in a series from the first
    %   file alone, only the lexicographically earliest match in each prefix
    %   group is returned. Ancillary files (e.g. an epochprobemap) that share
    %   the same prefix are matched through the standard '#' substitution
    %   syntax used by NDI.FILE.NAVIGATOR.
    %
    %   This navigator is for "flat" sessions in which all .rhd files of all
    %   epochs live directly in the session directory. Use
    %   NDI.FILE.NAVIGATOR.RHD_SERIES_EPOCHDIR for sessions in which each
    %   epoch lives in its own subdirectory.
    %
    %   FILEPARAMETERS
    %       The filematch list is interpreted as follows:
    %
    %       patterns{1} - Series pattern. Must contain exactly one '#'.
    %                     The '#' captures the per-epoch prefix; the rest of
    %                     the pattern is a regular expression matching the
    %                     variable portion of the filename. Files matching
    %                     this pattern are grouped by the captured prefix and
    %                     each unique prefix becomes one epoch. Within a
    %                     group only the lexicographically earliest filename
    %                     is kept (which is the chronologically earliest
    %                     when timestamps are zero-padded).
    %
    %       patterns{2:end} - Ancillary patterns. In each pattern '#' is
    %                     replaced by the literal (regex-escaped) prefix of
    %                     the current epoch and the result is matched as a
    %                     regular expression against the filenames in the
    %                     session directory. The lexicographically earliest
    %                     match is appended to the epoch's file list (so
    %                     when timestamps are zero-padded the chronologically
    %                     earliest match is selected, matching the behavior
    %                     of the series pattern). If any ancillary pattern
    %                     produces no match the epoch is skipped.
    %
    %   The epoch identifier returned by EPOCHID is the prefix captured by
    %   the series pattern.
    %
    %   Example
    %       fn = ndi.file.navigator.rhd_series(E, ...
    %           {'#_\d{14}\.\d+\.rhd\>', '#\.epochprobemap\.ndi\>'});
    %
    %   See also NDI.FILE.NAVIGATOR, NDI.FILE.NAVIGATOR.EPOCHDIR,
    %            NDI.FILE.NAVIGATOR.RHD_SERIES_EPOCHDIR

    methods
        function obj = rhd_series(varargin)
            %RHD_SERIES Construct an ndi.file.navigator.rhd_series.
            %
            %   OBJ = NDI.FILE.NAVIGATOR.RHD_SERIES(SESSION, FILEPARAMETERS)
            %   creates a navigator for SESSION with the given FILEPARAMETERS.
            %   See the class documentation for the FILEPARAMETERS contract.
            %   Any additional constructor arguments accepted by
            %   NDI.FILE.NAVIGATOR (epochprobemap class and epochprobemap
            %   fileparameters) are passed through.
            obj = obj@ndi.file.navigator(varargin{:});
        end

        function id = epochid(obj, epoch_number, epochfiles)
            %EPOCHID Return the epoch identifier for an epoch.
            %
            %   ID = EPOCHID(OBJ, EPOCH_NUMBER) returns the prefix captured
            %   by the series pattern from the first file of the epoch. If
            %   the epoch's files are ingested, the inherited ingested-file
            %   identifier is returned instead.
            %
            %   ID = EPOCHID(OBJ, EPOCH_NUMBER, EPOCHFILES) uses the supplied
            %   EPOCHFILES instead of looking them up.
            if nargin < 3
                epochfiles = getepochfiles(obj, epoch_number);
            end
            if ndi.file.navigator.isingested(epochfiles)
                id = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
                return;
            end
            patterns = ndi.file.navigator.rhd_series.normalizePatterns(...
                obj.fileparameters.filematch);
            [~, name, ext] = fileparts(epochfiles{1});
            id = ndi.file.navigator.rhd_series.extractPrefix(...
                [name ext], patterns{1});
            if isempty(id)
                id = name;
            end
        end

        function epochfiles_disk = selectfilegroups_disk(obj)
            %SELECTFILEGROUPS_DISK Return groups of files that comprise epochs.
            %
            %   EPOCHFILES_DISK = SELECTFILEGROUPS_DISK(OBJ) inspects the
            %   session directory and returns one cell per epoch, each cell
            %   containing the absolute path of the first .rhd file in the
            %   prefix group followed by any ancillary files matched by the
            %   remaining filematch patterns.
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
            epochfiles_disk = ndi.file.navigator.rhd_series.groupDirectory(...
                sess, patterns);
        end
    end % methods

    methods (Static)
        function patterns = normalizePatterns(filematch)
            %NORMALIZEPATTERNS Coerce filematch into a cell array of strings.
            if ischar(filematch)
                patterns = {filematch};
            else
                patterns = filematch;
            end
        end

        function prefix = extractPrefix(filename, seriesPattern)
            %EXTRACTPREFIX Return the substring captured by '#' in PATTERN.
            %
            %   PREFIX = EXTRACTPREFIX(FILENAME, SERIESPATTERN) replaces the
            %   '#' in SERIESPATTERN with a non-greedy capture group, anchors
            %   the result, and returns the captured substring or '' if the
            %   filename does not match.
            rx = ['^' strrep(seriesPattern, '#', '(.+?)') '$'];
            tok = regexp(filename, rx, 'tokens', 'once');
            if isempty(tok)
                prefix = '';
            else
                prefix = tok{1};
            end
        end

        function groups = groupDirectory(directory, patterns)
            %GROUPDIRECTORY Build epoch file groups from one directory.
            %
            %   GROUPS = GROUPDIRECTORY(DIRECTORY, PATTERNS) applies the
            %   rhd_series matching rules to the files in DIRECTORY and
            %   returns a column cell array of epoch file lists. PATTERNS is
            %   a normalized cell array; PATTERNS{1} is the series pattern
            %   and PATTERNS{2:end} are ancillary patterns (see class help).
            %
            %   Files whose basename begins with '.' (e.g. macOS resource
            %   forks like '._foo.rhd' or '.DS_Store') are ignored, matching
            %   the convention used by the base ndi.file.navigator.
            groups = {};
            entries = dir(directory);
            entries = entries(~[entries.isdir]);
            if isempty(entries)
                return;
            end
            names = {entries.name};
            names = names(~startsWith(names, '.'));
            if isempty(names)
                return;
            end

            seriesRegex = ['^' strrep(patterns{1}, '#', '(.+?)') '$'];
            tok = regexp(names, seriesRegex, 'tokens', 'once');
            mask = ~cellfun('isempty', tok);
            seriesNames = names(mask);
            tok = tok(mask);
            if isempty(seriesNames)
                return;
            end
            prefixes = cellfun(@(t) t{1}, tok, 'uni', false);
            [uniquePrefixes, ~, gidx] = unique(prefixes, 'stable');

            for g = 1:numel(uniquePrefixes)
                p = uniquePrefixes{g};
                seriesIdx = find(gidx == g);
                sortedSeries = sort(seriesNames(seriesIdx));
                epoch = { fullfile(directory, sortedSeries{1}) };

                ok = true;
                for i = 2:numel(patterns)
                    rx = ['^' strrep(patterns{i}, '#', ...
                        regexptranslate('escape', p)) '$'];
                    hit = ~cellfun('isempty', regexp(names, rx, 'once'));
                    matched = sort(names(hit));
                    if isempty(matched)
                        ok = false;
                        break;
                    end
                    epoch{end+1,1} = fullfile(directory, matched{1}); %#ok<AGROW>
                end

                if ok
                    groups{end+1,1} = epoch; %#ok<AGROW>
                end
            end
        end
    end % static methods
end
