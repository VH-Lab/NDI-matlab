classdef rhd_series < ndi.file.navigator
    % NDI.FILE.NAVIGATOR.RHD_SERIES - file navigator for rhd recordings
    % that are split across many .rhd files sharing a common prefix.
    %
    % Each epoch is a group of .rhd files that share a prefix but differ
    % in a trailing timestamp (e.g. 'foo_20240101120000.000.rhd',
    % 'foo_20240101120100.000.rhd', ...). The reader only needs the first
    % file of the series, so this navigator returns just one .rhd per epoch
    % (the lexicographically earliest match, which for zero-padded
    % YYYYMMDDHHMMSS.msec stamps is the chronologically earliest).
    %
    % FILEPARAMETERS:
    %   The first filematch pattern is the rhd-series pattern. It must
    %   contain a single '#' that stands for the per-epoch prefix, and the
    %   remainder of the pattern is a regex matching the variable portion
    %   of the filename (typically the timestamp + extension). Files that
    %   match this pattern are grouped by the substring captured by '#';
    %   each unique prefix becomes one epoch and only the earliest match
    %   in that group is returned.
    %
    %   Any additional filematch patterns are treated as ancillary files.
    %   In each pattern '#' is replaced by the literal prefix for the
    %   epoch, and the result is matched as a regex against filenames in
    %   the session directory. The first matching file is added to the
    %   epoch's file list. If an ancillary pattern matches no file the
    %   epoch is skipped.
    %
    % Example:
    %   fn = ndi.file.navigator.rhd_series(E, ...
    %       {'#_\d{14}\.\d+\.rhd\>', '#\.epochprobemap\.ndi\>'});

    methods
        function obj = rhd_series(varargin)
            obj = obj@ndi.file.navigator(varargin{:});
        end

        function id = epochid(obj, epoch_number, epochfiles)
            if nargin < 3
                epochfiles = getepochfiles(obj, epoch_number);
            end
            if ndi.file.navigator.isingested(epochfiles)
                id = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
                return;
            end
            patterns = obj.fileparameters.filematch;
            if ischar(patterns), patterns = {patterns}; end
            seriesRegex = ['^' strrep(patterns{1}, '#', '(.+?)') '$'];
            [~, name, ext] = fileparts(epochfiles{1});
            tok = regexp([name ext], seriesRegex, 'tokens', 'once');
            if ~isempty(tok)
                id = tok{1};
            else
                id = name;
            end
        end

        function epochfiles_disk = selectfilegroups_disk(obj)
            sess = obj.path();
            epochfiles_disk = {};
            if ~isfolder(sess)
                return;
            end

            patterns = obj.fileparameters.filematch;
            if ischar(patterns), patterns = {patterns}; end
            if isempty(patterns)
                return;
            end

            entries = dir(sess);
            entries = entries(~[entries.isdir]);
            names = {entries.name};
            if isempty(names)
                return;
            end

            seriesRegex = ['^' strrep(patterns{1}, '#', '(.+?)') '$'];
            tok = regexp(names, seriesRegex, 'tokens', 'once');
            mask = ~cellfun('isempty', tok);
            names_s = names(mask);
            tok = tok(mask);
            if isempty(names_s)
                return;
            end
            prefixes = cellfun(@(t) t{1}, tok, 'uni', false);

            [groups, ~, gidx] = unique(prefixes, 'stable');

            for g = 1:numel(groups)
                p = groups{g};
                idx = find(gidx == g);
                series_files = sort(names_s(idx));
                epoch = { fullfile(sess, series_files{1}) };

                ok = true;
                for i = 2:numel(patterns)
                    rx = ['^' strrep(patterns{i}, '#', ...
                        regexptranslate('escape', p)) '$'];
                    hit = ~cellfun('isempty', regexp(names, rx, 'once'));
                    j = find(hit, 1);
                    if isempty(j)
                        ok = false;
                        break;
                    end
                    epoch{end+1,1} = fullfile(sess, names{j}); %#ok<AGROW>
                end

                if ok
                    epochfiles_disk{end+1,1} = epoch; %#ok<AGROW>
                end
            end
        end % selectfilegroups_disk
    end % methods
end
