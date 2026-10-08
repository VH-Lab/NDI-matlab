classdef bodies < ndi.file.navigator
    % ndi.file.navigator.bodies - find an acquisition system's epochs through its documents
    %
    % A navigator for a V2 session whose recordings are described by
    % documents rather than by files laid out in the session folder. It
    % scans no folder and writes no file: everything it reports is read
    % from the session's database.
    %
    % For the acquisition system that names this navigator (its
    % `epoch_file_pattern_id`), each epoch is one recording statement:
    %
    %   acquisition_system  <- acquisition_channels (acquisition_system_id)
    %                       <- subject_statement     (acquisition_channels_id)
    %                       <- data_body             (owner_id)
    %
    %   epoch files   each body's files, at the location the body records
    %                 (files.file_info.locations, not ingested), resolved by
    %                 the database (ndi.session/database_existbinarydoc) --
    %                 the raw data stays where it is
    %   epoch id      the `local_identifier` of the `epoch` document the
    %                 statement's relative time reference points at
    %   probe map     one entry: name = the acquisition system's name,
    %                 reference 1, type = the statement's `method` name,
    %                 device = <system>:image1, subject = the statement's
    %                 subject (a document id)
    %
    % A statement none of whose files is found on this computer is left
    % out (and reported once, with a warning), so a missing raw file reads
    % as a missing epoch rather than an error deep inside a reader.
    %
    % The file pattern in the epoch_file_pattern document (fileparameters)
    % filters the bodies by file name: a body none of whose file names
    % matches the first pattern is not this system's.
    %
    % See also: ndi.file.navigator, ndi.database.fun.externalFileLocation,
    %   ndi.setup.conv.haley.sessionDocuments

    properties (Access = protected)
        found   % containers.Map: 'recordings' -> struct array (a cache)
    end

    methods
        function obj = bodies(varargin)
            obj = obj@ndi.file.navigator(varargin{:});
            obj.found = containers.Map();
        end

        function id = epochid(obj, epoch_number, epochfiles)
            % The epoch document's local_identifier; no hidden file is
            % written next to the (raw) epoch files.
            if nargin < 3
                epochfiles = obj.getepochfiles_number(epoch_number);
            end
            if ndi.file.navigator.isingested(epochfiles)
                id = ndi.file.navigator.ingestedfiles_epochid(epochfiles);
                return;
            end
            R = obj.recordings();
            for k = 1:numel(R)
                if isequal(R(k).files, epochfiles)
                    id = R(k).epoch_id;
                    return;
                end
            end
            error('NDI:navigator:bodies:unknownEpoch', ...
                'No recording statement of this acquisition system has the files %s.', ...
                strjoin(cellstr(epochfiles), ', '));
        end

        function [epochfiles_disk] = selectfilegroups_disk(obj)
            R = obj.recordings();
            epochfiles_disk = {R.files};
        end

        function [epochfiles, epochprobemaps] = selectfilegroups(obj)
            R = obj.recordings();
            epochfiles = {R.files};
            epochprobemaps = {R.probemap};
        end

        function epochprobemap = getepochprobemap(obj, N, epochfiles)
            if nargin < 3
                epochfiles = obj.getepochfiles_number(N);
            end
            R = obj.recordings();
            for k = 1:numel(R)
                if isequal(R(k).files, epochfiles)
                    epochprobemap = R(k).probemap;
                    return;
                end
            end
            error('NDI:navigator:bodies:unknownEpoch', 'No recording for epoch %d.', N);
        end

        function R = recordings(obj)
            % The system's recordings, read from the database once per object.
            if isKey(obj.found, 'recordings')
                R = obj.found('recordings');
                return;
            end
            R = obj.readRecordings();
            obj.found('recordings') = R;
        end
    end

    methods (Access = protected)
        function R = readRecordings(obj)
            R = struct('files', {}, 'epoch_id', {}, 'probemap', {});
            S = obj.session;
            if isempty(S)
                return;
            end
            inSession = ndi.query('base.session_id', 'exact_string', S.id(), '');
            pattern = '';
            if ~isempty(obj.fileparameters) && ~isempty(obj.fileparameters.filematch)
                pattern = obj.fileparameters.filematch{1};
            end
            missing = {};
            systems = S.database_search(ndi.query('', 'isa', 'acquisition_system', '') & ...
                ndi.query('', 'depends_on', 'epoch_file_pattern_id', obj.id()) & inSession);
            for a = 1:numel(systems)
                sysName = systems{a}.document_properties.acquisition_system.name;
                channels = S.database_search(ndi.query('', 'isa', 'acquisition_channels', '') & ...
                    ndi.query('', 'depends_on', 'acquisition_system_id', systems{a}.id()) & inSession);
                for c = 1:numel(channels)
                    statements = S.database_search(ndi.v2.isaQuery('statement') & ...
                        ndi.query('', 'depends_on', 'acquisition_channels_id', channels{c}.id()) & inSession);
                    for t = 1:numel(statements)
                        st = statements{t};
                        [files, names] = obj.statementFiles(st, pattern);
                        if isempty(names)
                            continue;   % not this system's (by file name)
                        end
                        if isempty(files)
                            missing{end+1} = strjoin(names, ', '); %#ok<AGROW>
                            continue;
                        end
                        R(end+1) = struct('files', {files}, ...
                            'epoch_id', obj.statementEpoch(st), ...
                            'probemap', obj.statementProbemap(st, sysName)); %#ok<AGROW>
                    end
                end
            end
            if ~isempty(missing)
                warning('NDI:navigator:bodies:missingFiles', ...
                    ['%d recording(s) of this acquisition system have no file on ' ...
                     'this computer at the location their document records, and are ' ...
                     'left out: %s'], numel(missing), strjoin(missing, '; '));
            end
            [~, order] = sort({R.epoch_id});
            R = R(order);
        end

        function [files, names] = statementFiles(obj, st, pattern)
            % FILES: local paths of the statement's bodies' files; NAMES:
            % the bodies' recorded file names that match PATTERN.
            files = {};
            names = {};
            S = obj.session;
            bodies = S.database_search(ndi.query('', 'isa', 'data_body', '') & ...
                ndi.query('', 'depends_on', 'owner_id', st.id()) & ...
                ndi.query('base.session_id', 'exact_string', S.id(), ''));
            for b = 1:numel(bodies)
                p = bodies{b}.document_properties;
                if isfield(p, 'data_body') && isfield(p.data_body, 'filename')
                    name = char(p.data_body.filename);
                else
                    name = '';
                end
                if ~isempty(pattern) && isempty(regexp(name, pattern, 'once'))
                    continue;
                end
                names{end+1} = name; %#ok<AGROW>
                list = {};
                if isfield(p, 'files') && isfield(p.files, 'file_list')
                    list = cellstr(p.files.file_list);
                end
                for f = 1:numel(list)
                    [tf, where] = S.database_existbinarydoc(bodies{b}, list{f});
                    if tf
                        files{end+1} = where; %#ok<AGROW>
                    end
                end
            end
        end

        function id = statementEpoch(obj, st)
            % The epoch a statement's relative time reference points at.
            S = obj.session;
            refs = ndi.vintage.edge_n(st, 'time_reference_id');
            for r = 1:numel(refs)
                d = S.database_search(ndi.query('base.id', 'exact_string', refs{r}, ''));
                if numel(d) ~= 1 || ~isfield(d{1}.document_properties, 'relative_time_reference')
                    continue;
                end
                referent = d{1}.dependency_value('referent_id', 'ErrorIfNotFound', 0);
                e = S.database_search(ndi.query('base.id', 'exact_string', referent, '') & ...
                    ndi.v2.isaQuery('epoch'));
                if numel(e) == 1
                    id = ndi.v2.blockOf(e{1}.document_properties, 'epoch', 'local_identifier');
                    return;
                end
            end
            error('NDI:navigator:bodies:noEpoch', ...
                'Recording statement %s has no relative time reference to an epoch document.', st.id());
        end

        function pm = statementProbemap(~, st, sysName)
            p = st.document_properties;
            type = '';
            m = ndi.v2.blockOf(p, 'interaction', 'method', []);
            if isstruct(m) && isfield(m, 'name')
                type = char(m.name);
            end
            if isempty(type)
                error('NDI:navigator:bodies:noMethod', ...
                    ['Recording statement %s has no `method`, which names the probe ' ...
                     'type (e.g. brightfield-imaging).'], st.id());
            end
            subject = ndi.v2.edgeIds(p, 'entity_id');
            if isempty(subject), subject = ''; else, subject = subject{1}; end
            pm = ndi.epoch.epochprobemap_daqsystem(sysName, 1, type, [sysName ':image1'], subject);
        end
    end
end
