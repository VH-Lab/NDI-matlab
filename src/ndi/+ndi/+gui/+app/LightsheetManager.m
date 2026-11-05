classdef LightsheetManager < ndi.gui.app.sessionApp
% NDI.GUI.APP.LIGHTSHEETMANAGER - list, add, view and delete lightsheet images
%
%   ndi.gui.app.LightsheetManager(SESSION)
%
%   Lists the lightsheet image pyramids (lightsheetZarrPyramid documents)
%   in a session, paired with their subject and level counts, and lets the
%   user add, open or remove one. Reached from the navigator's per-session
%   Apps menu.
%
%   WHAT IS LISTED IS PYRAMIDS, NOT FILES. The input is a SmartSPIM
%   acquisition (its stitched All_Channels folder) or an OME-Zarr store;
%   what lands in the database is a lightsheetZarrPyramid plus one
%   lightsheetZarrLevel per level, with the image chunks stored in NDI.
%
%   VIEWING IS SOMEONE ELSE'S JOB. The viewer is napari, which is
%   Python, so View does not draw anything here: it builds a command
%   line via NDI.FUN.DOC.LIGHTSHEET.VIEWCOMMAND and hands it to a
%   launcher: NDI-python's napariViewLightsheet console script, found by
%   ndi.python.findCommand (install it with ndi.python.install()). It is
%   started with NDI_FROM_MATLAB=1, which tells the Python side to drop
%   the library paths MATLAB exports before loading anything, so no
%   shell wrapper is needed. viewCommand builds the command and is pure,
%   so what will run can be shown in the dialog before it runs and can
%   be copied into a terminal when it does not.
%
%   ADDING IS ONE DIALOG. Add... asks, in order, where the image goes
%   (this session, or a session of an NDI Cloud dataset), which subject it
%   is of (one of that session's subjects, or a new one added there), and
%   which folder holds it; the folder is recognised as a SmartSPIM
%   acquisition or an OME-Zarr store. What is still missing is listed in
%   the dialog, and Add stays disabled until nothing is. The decisions
%   are the static functions addChoices, sourceKind, addPlan and
%   addMessage, and the work is addSubject and runAdd, so all of it can be
%   tested and scripted without a display. A pyramid added to the cloud
%   goes through ndi.cloud.upload.SessionWriter and is not listed here:
%   the table shows this session.
%
%   DELETING IS A CASCADE. Levels depend on the pyramid, so removing a
%   pyramid orphans everything beneath it. deletionPlan enumerates that
%   first and the confirmation names the counts, because "delete 1
%   document" and "delete 32 documents" should not look the same.
%
%   Example:
%       S = ndi.session.dir('mysession','/path/to/session');
%       ndi.gui.app.LightsheetManager(S);
%
%   See also: ndi.fun.doc.lightsheet.fromSPIM,
%             ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.cloud.upload.SessionWriter,
%             ndi.fun.doc.lightsheet.viewCommand,
%             ndi.gui.app.GEFManager (the pattern this app mirrors)

    properties (Constant)
        Name = "Lightsheet Manager"
        Category = "Lightsheet microscopy"

        % Where the napari launcher lives when nobody has said otherwise.
        % Empty means "find it": ndi.python.findCommand('napariViewLightsheet')
        % looks in ~/.ndi/bin (where ndi.python.install puts it) and the
        % other usual places. Overridden by the preference
        % GUI.LightsheetManager.ViewerLauncher.
        DefaultViewerLauncher = ""
    end

    properties (Access = private)
        session
        fig
        table
        statusLabel
        rows = struct([])
        % The View and Add dialogs, kept so a second click RAISES the
        % open one rather than stacking another. Both are non-modal, so
        % without this a button would build one dialog per press.
        viewDialog = matlab.ui.Figure.empty
        addDialog = matlab.ui.Figure.empty
    end

    methods
        function obj = LightsheetManager(sessionObj, options)
            arguments
                sessionObj (1,1)
                % build=false constructs the model without a figure, so
                % every decision this app makes is checkable with no
                % display. Same arrangement GEFManager uses.
                options.build (1,1) logical = true
            end
            obj.session = sessionObj;
            if options.build
                obj.buildUI();
                obj.reload();
            end
        end

        function reload(obj)
            obj.rows = ndi.gui.app.LightsheetManager.pyramidRows(obj.session);
            if ~isempty(obj.fig) && isvalid(obj.fig)
                obj.table.Data = ndi.gui.app.LightsheetManager.rowsToCell(obj.rows);
                obj.setStatus(sprintf('%d pyramid(s).', numel(obj.rows)));
            end
        end

        function refresh(obj)
        % REFRESH - backward-compatible alias for reload
            obj.reload();
        end
    end

    % =====================================================================
    % The model. Static and pure: no figure, no state, so it is testable
    % headlessly and a test failure names a decision rather than a widget.
    % =====================================================================
    methods (Static)

        function rows = pyramidRows(session)
        % PYRAMIDROWS - one row per lightsheetZarrPyramid, with subject names
        %
        %   The subject column shows local_identifier, not the raw id: an
        %   id names the subject uniquely and tells the reader nothing.
        %   The lookup is done ONCE for the whole session rather than
        %   per row -- a session with 20 pyramids would otherwise make
        %   20 subject queries to answer one question.
            docs = session.database_search( ...
                ndi.query('','isa','lightsheetZarrPyramid'));
            subjectNames = ndi.gui.app.LightsheetManager.subjectNameMap(session);
            rows = struct('id',{},'label',{},'reduction',{},'subject',{}, ...
                'subjectID',{},'nLevels',{},'shapeLevel0',{},'dtype',{},'doc',{});
            for i = 1:numel(docs)
                d = docs{i};
                p = d.document_properties.lightsheetZarrPyramid;
                k = numel(rows) + 1;
                rows(k).id = d.id();
                rows(k).doc = d;
                rows(k).label = ndi.gui.app.LightsheetManager.field(p,'label','');
                rows(k).subjectID = ndi.gui.app.LightsheetManager.dependency(d,'subject_id');
                rows(k).subject = ndi.gui.app.LightsheetManager.lookup( ...
                    subjectNames, rows(k).subjectID, rows(k).subjectID);

                % Level count and reduction come from the child level
                % docs, not the parent -- the parent schema has neither
                % an n_levels nor a reduction field. Reductions are per
                % level (reduction_function on lightsheetZarrLevel);
                % the parent's pyramid_type names the source volume, not
                % the reduction. See NDI-matlab#979 review 2026-09-25.
                q1 = ndi.query('', 'isa', 'lightsheetZarrLevel');
                q2 = ndi.query('depends_on', 'depends_on', ...
                    'lightsheetZarrPyramid_id', rows(k).id);
                levelDocs = session.database_search(q1 & q2);
                rows(k).nLevels = numel(levelDocs);
                rows(k).reduction = ndi.gui.app.LightsheetManager.joinReductions(levelDocs);

                shp = ndi.gui.app.LightsheetManager.field(p,'shape_level0',[]);
                rows(k).shapeLevel0 = shp;
                rows(k).dtype = ndi.gui.app.LightsheetManager.field(p,'dtype','');
            end
        end

        function s = joinReductions(levelDocs)
        % joinReductions - unique non-'none' reduction_function values
        %   Reads reduction_function from each lightsheetZarrLevel doc
        %   and returns them joined by "/", with 'none' (the raw level 0
        %   marker) filtered out. When only 'none' levels exist, returns
        %   the string 'none' so the column doesn't lie about a missing
        %   ladder.
            seen = strings(1, numel(levelDocs));
            for j = 1:numel(levelDocs)
                lp = levelDocs{j}.document_properties.lightsheetZarrLevel;
                seen(j) = string(ndi.gui.app.LightsheetManager.field( ...
                    lp, 'reduction_function', 'none'));
            end
            reductions = unique(seen);
            reductions = reductions(reductions ~= "none");
            if isempty(reductions)
                s = 'none';
            else
                s = char(strjoin(reductions, '/'));
            end
        end

        function m = subjectNameMap(session)
        % SUBJECTNAMEMAP - subject document id -> local_identifier
        %
        %   containers.Map so the lookup is one query for the session
        %   rather than one per pyramid. A subject with no
        %   local_identifier is left out rather than mapped to '': the
        %   caller's default is the id, and an empty cell in the Subject
        %   column would say the pyramid has no subject, which is a
        %   different and worse claim than showing the id.
            m = containers.Map('KeyType','char','ValueType','char');
            docs = session.database_search(ndi.query('','isa','subject'));
            for i = 1:numel(docs)
                p = docs{i}.document_properties;
                if ~isfield(p,'subject'), continue; end
                nm = ndi.gui.app.LightsheetManager.field(p.subject,'local_identifier','');
                if ~isempty(nm)
                    m(docs{i}.id()) = char(nm);
                end
            end
        end

        function plan = deletionPlan(session, pyramidID)
        % DELETIONPLAN - the pyramid and every level that depends on it
        %
        %   Public and static so a caller without a display can preview
        %   what a delete would remove.
            plan = struct();
            plan.pyramidID = char(pyramidID);
            q1 = ndi.query('', 'isa', 'lightsheetZarrLevel');
            q2 = ndi.query('depends_on', 'depends_on', ...
                'lightsheetZarrPyramid_id', plan.pyramidID);
            levelDocs = session.database_search(q1 & q2);
            parentDoc = session.database_search(ndi.query('base.id', ...
                'exact_string', plan.pyramidID));
            plan.nLevels = numel(levelDocs);
            plan.docsToRemove = [levelDocs(:); parentDoc(:)];
        end

        function msg = deletionMessage(plan, label)
        % DELETIONMESSAGE - the confirmation text for a deletion
        %
        %   Names the pyramid and the level count so "delete 1 document"
        %   and "delete 32 documents" do not read the same.
            if nargin < 2, label = ''; end
            if isempty(label), label = plan.pyramidID; end
            msg = sprintf(['This removes %d document(s):\n\n' ...
                '  1 pyramid (%s)\n  %d level(s)\n\n' ...
                'The levels go because the pyramid they belong to goes. ' ...
                'This cannot be undone.'], ...
                1 + plan.nLevels, label, plan.nLevels);
        end

        function p = launcherPath()
        % LAUNCHERPATH - the viewer launcher, from preferences or found
        %
        %   ndi.python.findCommand('napariViewLightsheet'), which honours
        %   the preference GUI.LightsheetManager.ViewerLauncher when
        %   it names a file that exists. When nothing is found this
        %   returns the preference as written, or '' -- never raises: the
        %   dialog can still open, and the field it opens with is
        %   editable.
            p = ndi.gui.app.LightsheetManager.resolveLauncher('');
            if isempty(p)
                try
                    p = strtrim(char(ndi.preferences.get( ...
                        'GUI.LightsheetManager.ViewerLauncher')));
                catch
                end
            end
        end

        function p = resolveLauncher(p)
        % RESOLVELAUNCHER - the launcher typed, or the one found if none was
        %
        %   An explicit launcher always wins. An empty one means "find
        %   it", and stays empty when NDI-python's napariViewLightsheet
        %   is not installed; viewCommand then says how to install it.
            p = strtrim(char(p));
            if isempty(p)
                try
                    p = ndi.python.findCommand('napariViewLightsheet');
                catch
                    p = '';
                end
            end
        end

        function setLauncherPath(p)
        % SETLAUNCHERPATH - remember the launcher for next time
        %
        %   Failing to persist must not cost the launch about to happen.
            try
                ndi.preferences.set('GUI.LightsheetManager.ViewerLauncher', string(p));
            catch
            end
        end

        function paper(h, c)
        % PAPER - put a control on the cloud palette's white body
        %
        %   The figure and its layouts are on c.offWhite, but the
        %   CONTROLS default to MATLAB's grey chrome, which reads as a
        %   grey app with a tinted border. Defensive: a missing handle
        %   or a control without a BackgroundColor is a no-op.
            if isempty(h) || ~isvalid(h)
                return;
            end
            try %#ok<TRYNC>
                h.BackgroundColor = c.white;
            end
            try %#ok<TRYNC>
                h.FontColor = c.darkBlue;
            end
        end

        function accent(btn, c)
        % ACCENT - style a button in the NDI Cloud accent
        %
        %   Light blue on navy, matching ndi.util.ListDialog and the
        %   cloud .mlapp apps. A missing or deleted handle is a no-op
        %   rather than an error: this is styling, and losing the
        %   window over a colour would be a poor trade.
            if isempty(btn) || ~isvalid(btn)
                return;
            end
            btn.BackgroundColor = c.lightBlue;
            btn.FontColor       = c.darkBlue;
            btn.FontWeight      = 'bold';
        end

        function labels = sessionLabels(sessions)
        % SESSIONLABELS - list entries for cloud sessions: reference, then id
            labels = arrayfun(@(x) sprintf('%s  (%s)', ...
                x.session_reference, x.session_id), sessions, ...
                'UniformOutput', false);
            labels = reshape(labels, 1, []);
        end

        % -----------------------------------------------------------------
        % ADDING. What the Add dialog decides, as functions of a CHOICES
        % struct, so a test or a script can make the same decisions with
        % no display.
        % -----------------------------------------------------------------

        function choices = addChoices()
        % ADDCHOICES - what the Add dialog starts from
        %
        %   destination      - 'local' (this session) or 'cloud'
        %   datasetId        - cloud dataset id ('' until chosen)
        %   datasetName      - its name, for messages
        %   sessionId        - id of a session in that dataset
        %   sessionReference - its reference, for messages
        %   subjectID        - id of the subject the image is of. NO
        %                      DEFAULT: an acquisition folder does not say
        %                      which animal it is, and a guess would attach
        %                      the image to the wrong one undetectably.
        %   subjectName      - its local identifier, for messages
        %   sourcePath       - the SmartSPIM acquisition folder or the
        %                      OME-Zarr store
        %   sourceKind       - 'smartspim', 'omezarr' or '' (see sourceKind)
        %   label            - the pyramid's label; '' uses the folder name
        %   voxelSizeUm      - [z y x] micrometers for a SmartSPIM folder
        %                      whose metadata does not give it; [] = read
        %                      it from the acquisition
        %   clevel           - Blosc-Zstd compression level of the stored
        %                      chunks, 1-9 (see defaultClevel)
        %   reductions       - the ladders a SmartSPIM image is built with:
        %                      any of 'mean', 'max'. An OME-Zarr store
        %                      brings its own.
        %   numWorkers       - parallel workers compressing chunks: N > 1
        %                      opens (or resizes) a pool of N, 1 is one at
        %                      a time, -1 uses whatever pool is open
            choices = struct('destination', 'local', ...
                'datasetId', '', 'datasetName', '', ...
                'sessionId', '', 'sessionReference', '', ...
                'subjectID', '', 'subjectName', '', ...
                'sourcePath', '', 'sourceKind', '', ...
                'label', '', 'voxelSizeUm', [], ...
                'clevel', ndi.gui.app.LightsheetManager.defaultClevel('local'), ...
                'reductions', {{'mean', 'max'}}, ...
                'numWorkers', -1);
        end

        function c = defaultClevel(destination)
        % DEFAULTCLEVEL - the compression level offered for a destination
        %
        %   8 for the cloud, where the chunks are kept for a long time and
        %   a smaller file is worth a slower build; 5 (the ingest
        %   functions' own default) for this session. Not 9: c-blosc maps
        %   Blosc level L to Zstd level 2L-1, except that 9 means Zstd's
        %   maximum, 22, which is many times slower and needs far more
        %   memory per worker for a percent or two more.
            if strcmp(destination, 'cloud')
                c = 8;
            else
                c = 5;
            end
        end

        function n = defaultWorkers()
        % DEFAULTWORKERS - the number of workers the Add dialog starts with
        %
        %   The size of a parallel pool that is already open, else
        %   min(8, cores). 1 without the Parallel Computing Toolbox.
        %   Never opens a pool itself.
            n = 1;
            if isempty(ver('parallel'))
                return
            end
            try
                p = gcp('nocreate');
                if ~isempty(p)
                    n = p.NumWorkers;
                    return
                end
                n = min(8, feature('numcores'));
            catch
                n = 1;
            end
        end

        function [kind, description] = sourceKind(folder)
        % SOURCEKIND - what a chosen folder holds: 'smartspim', 'omezarr' or ''
        %
        %   A SmartSPIM acquisition is recognised by a usable All_Channels
        %   folder (SmartSPIM AutoStitch output), which is what
        %   ndi.fun.doc.lightsheet.fromSPIM reads; an OME-Zarr store by
        %   its multiscales .zattrs. DESCRIPTION says what was found, or
        %   why nothing was, in words for the dialog.
            kind = '';
            folder = char(folder);
            if isempty(strtrim(folder))
                description = 'No folder chosen yet.';
                return
            end
            if ~isfolder(folder)
                description = sprintf('There is no folder at %s.', folder);
                return
            end
            % Name a missing reader rather than failing on it: an NDR-matlab
            % older than these functions is the usual cause, and the fix
            % is to update NDR, not to choose another folder.
            needed = {'ndr.format.smartspim.hasAllChannels', 'ndr.format.omezarr.isOMEZarr'};
            missing = needed(cellfun(@(f) isempty(which(f)), needed));
            if ~isempty(missing)
                description = sprintf(['NDR-matlab on the MATLAB path is too ' ...
                    'old to read lightsheet images: it has no %s. Update ' ...
                    'NDR-matlab (git pull in its folder, or ndi_install), then ' ...
                    'run rehash or restart MATLAB.'], strjoin(missing, ' or '));
                return
            end
            try
                if ndr.format.smartspim.hasAllChannels(folder)
                    kind = 'smartspim';
                    description = 'SmartSPIM acquisition (stitched All_Channels).';
                    return
                end
                if ndr.format.omezarr.isOMEZarr(folder)
                    kind = 'omezarr';
                    description = 'OME-Zarr store.';
                    return
                end
            catch ME
                description = sprintf(['Could not read the folder (%s). ' ...
                    'Reading lightsheet images needs NDR-matlab.'], ME.message);
                return
            end
            description = ['Not a SmartSPIM acquisition or an OME-Zarr ' ...
                'store. Choose the acquisition folder that holds ' ...
                'All_Channels (run SmartSPIM AutoStitch first if it has ' ...
                'none), or the .ome.zarr folder itself.'];
        end

        function plan = addPlan(choices)
        % ADDPLAN - what Add would do, or everything still missing
        %
        %   Pure: nothing is read or written. PLAN.errors lists EVERY
        %   problem at once (a dialog that reports one per attempt turns
        %   three missing fields into three rounds); PLAN.warnings says
        %   what will happen anyway but should be seen first.
        %   PLAN.ingest is 'fromSPIM' or 'fromOMEZarr', PLAN.where says
        %   where the image goes.
            arguments
                choices (1,1) struct
            end
            F = @(name, dflt) ndi.gui.app.LightsheetManager.field(choices, name, dflt);
            plan = struct('errors', {{}}, 'warnings', {{}}, 'ingest', '', ...
                'where', '', 'choices', choices);
            E = {}; W = {};

            toCloud = strcmp(F('destination', 'local'), 'cloud');
            if toCloud
                if isempty(F('datasetId', ''))
                    E{end+1} = 'Choose the NDI Cloud dataset.';
                end
                if isempty(F('sessionId', ''))
                    E{end+1} = ['Choose the session in that dataset. An ' ...
                        'image goes into a session, not into the dataset itself.'];
                end
                plan.where = sprintf('session %s of the NDI Cloud dataset %s', ...
                    char(F('sessionReference', '')), char(F('datasetName', '')));
            else
                plan.where = 'this session';
            end

            if isempty(F('subjectID', ''))
                E{end+1} = ['Choose the subject the image is of, or add a ' ...
                    'new subject to the session.'];
            end

            switch char(F('sourceKind', ''))
                case 'smartspim'
                    plan.ingest = 'fromSPIM';
                case 'omezarr'
                    plan.ingest = 'fromOMEZarr';
                otherwise
                    if isempty(strtrim(char(F('sourcePath', ''))))
                        E{end+1} = ['Choose the image folder: a SmartSPIM ' ...
                            'acquisition or an OME-Zarr store.'];
                    else
                        E{end+1} = ['The image folder is not a SmartSPIM ' ...
                            'acquisition or an OME-Zarr store.'];
                    end
            end

            vox = F('voxelSizeUm', []);
            if ~isempty(vox) && (numel(vox) ~= 3 || any(~isfinite(vox)) || any(vox <= 0))
                E{end+1} = ['Voxel size must be three positive numbers ' ...
                    '(z y x, in micrometers), or empty to read it from the ' ...
                    'acquisition.'];
            end
            if ~isempty(vox) && strcmp(plan.ingest, 'fromOMEZarr')
                W{end+1} = ['Voxel size is ignored for an OME-Zarr store: ' ...
                    'the store records its own.'];
            end

            cl = F('clevel', 5);
            if ~isscalar(cl) || ~isnumeric(cl) || cl ~= round(cl) || cl < 1 || cl > 9
                E{end+1} = 'Compression must be a whole number from 1 to 9.';
            elseif cl == 9
                W{end+1} = ['Compression 9 is Zstd''s slowest setting: many ' ...
                    'times slower than 8, with much more memory per worker, ' ...
                    'for files only a percent or two smaller.'];
            end

            red = cellstr(F('reductions', {'mean', 'max'}));
            if strcmp(plan.ingest, 'fromSPIM')
                if isempty(red) || ~all(ismember(red, {'mean', 'max'}))
                    E{end+1} = 'Reductions must be mean, max, or both.';
                end
            elseif strcmp(plan.ingest, 'fromOMEZarr') && ~isempty(setxor(red, {'mean', 'max'}))
                W{end+1} = ['Reductions are ignored for an OME-Zarr store: it ' ...
                    'brings the ladders it was made with.'];
            end

            nw = F('numWorkers', -1);
            if ~isscalar(nw) || ~isnumeric(nw) || nw ~= round(nw) || (nw < 1 && nw ~= -1)
                E{end+1} = 'Workers must be a whole number, 1 or more.';
            end

            if toCloud
                W{end+1} = ['Every image chunk is built on this computer and ' ...
                    'uploaded as it is made. A large volume takes hours; the ' ...
                    'disk holds only the chunks in flight plus one coarser ' ...
                    'level at a time.'];
            else
                W{end+1} = ['Every image chunk is built and stored in this ' ...
                    'session. A large volume takes hours, and needs as much ' ...
                    'free disk as the chunks.'];
            end
            plan.errors = E(:);
            plan.warnings = W(:);
        end

        function msg = addMessage(plan)
        % ADDMESSAGE - the confirmation before the wait, or what is missing
            if ~isempty(plan.errors)
                msg = sprintf('Not ready yet:\n\n%s', ...
                    ndi.gui.app.LightsheetManager.bullets(plan.errors));
                return
            end
            c = plan.choices;
            label = c.label;
            if isempty(label)
                [~, label] = fileparts(strip(char(c.sourcePath), 'right', filesep));
            end
            msg = sprintf(['Add the image\n  %s\nas "%s", of subject %s, ' ...
                'to %s?'], c.sourcePath, label, c.subjectName, plan.where);
            how = sprintf('Compression %d', ndi.gui.app.LightsheetManager.field(c, 'clevel', 5));
            if strcmp(plan.ingest, 'fromSPIM')
                how = sprintf('%s, %s ladder(s)', how, strjoin(cellstr( ...
                    ndi.gui.app.LightsheetManager.field(c, 'reductions', {'mean', 'max'})), ' and '));
            end
            nw = ndi.gui.app.LightsheetManager.field(c, 'numWorkers', -1);
            if nw > 1
                how = sprintf('%s, %d parallel workers', how, nw);
            elseif nw == 1
                how = sprintf('%s, one worker', how);
            end
            msg = sprintf('%s\n%s.', msg, how);
            if ~isempty(plan.warnings)
                msg = sprintf('%s\n\n%s', msg, ...
                    ndi.gui.app.LightsheetManager.bullets(plan.warnings));
            end
        end

        function problems = subjectProblems(localIdentifier, existing)
        % SUBJECTPROBLEMS - why a new subject cannot be added, or {} when it can
        %
        %   EXISTING is the local identifiers the target session already
        %   has: a second subject with the same identifier would make the
        %   subject list ambiguous, and the user almost certainly meant
        %   the one that is there.
            problems = {};
            localIdentifier = strtrim(char(localIdentifier));
            if isempty(localIdentifier)
                problems{end+1} = ['A subject needs a local identifier, ' ...
                    'such as mouse42@vhlab.org.'];
            elseif any(strcmp(localIdentifier, cellstr(existing)))
                problems{end+1} = sprintf(['This session already has a ' ...
                    'subject %s. Choose it from the list instead.'], localIdentifier);
            end
        end

        function subjects = targetSubjects(session, choices, options)
        % TARGETSUBJECTS - the subjects of the session an image would go to
        %
        %   A struct array with fields id and local_identifier: this
        %   session's subjects, or those of the chosen cloud session.
            arguments
                session
                choices (1,1) struct
                options.Api = []
            end
            subjects = struct('id', {}, 'local_identifier', {});
            if strcmp(choices.destination, 'cloud')
                if isempty(choices.datasetId) || isempty(choices.sessionId)
                    return
                end
                subjects = ndi.cloud.upload.SessionWriter.listSubjects( ...
                    choices.datasetId, choices.sessionId, 'Api', options.Api);
                return
            end
            docs = session.database_search(ndi.query('', 'isa', 'subject'));
            for i = 1:numel(docs)
                p = docs{i}.document_properties;
                subjects(end+1) = struct('id', docs{i}.id(), 'local_identifier', ...
                    char(ndi.gui.app.LightsheetManager.field(p.subject, ...
                        'local_identifier', ''))); %#ok<AGROW>
            end
        end

        function id = addSubject(session, choices, localIdentifier, description, options)
        % ADDSUBJECT - add a subject to the session an image would go to
        %
        %   ID = ndi.gui.app.LightsheetManager.addSubject(SESSION, CHOICES, ...
        %       LOCALIDENTIFIER, DESCRIPTION)
        %
        %   To this session, or straight to the chosen cloud session
        %   (through an ndi.cloud.upload.SessionWriter). Refused, with
        %   subjectProblems' reasons, when the identifier is empty or the
        %   session already has it.
            arguments
                session
                choices (1,1) struct
                localIdentifier (1,:) char
                description (1,:) char = ''
                options.Api = []
            end
            existing = ndi.gui.app.LightsheetManager.targetSubjects(session, ...
                choices, 'Api', options.Api);
            problems = ndi.gui.app.LightsheetManager.subjectProblems( ...
                localIdentifier, {existing.local_identifier});
            if ~isempty(problems)
                error('NDI:gui:LightsheetManager:badSubject', '%s', strjoin(problems, ' '));
            end
            props = {'subject.local_identifier', strtrim(localIdentifier), ...
                'subject.description', description};
            if strcmp(choices.destination, 'cloud')
                writer = ndi.cloud.upload.SessionWriter(choices.datasetId, ...
                    choices.sessionId, 'Api', options.Api, 'Verbose', false);
                doc = writer.newdocument('subject', props{:});
                writer.database_add(doc);
                writer.commit();
            else
                doc = session.newdocument('subject', props{:});
                session.database_add(doc);
            end
            id = doc.id();
        end

        function [pyramidDoc, levelDocs, info] = runAdd(session, choices, options)
        % RUNADD - add the image the choices describe
        %
        %   [P, L, INFO] = ndi.gui.app.LightsheetManager.runAdd(SESSION, CHOICES)
        %
        %   Refuses, listing everything addPlan found missing, before any
        %   work. Otherwise runs fromSPIM or fromOMEZarr into this session
        %   or, through an ndi.cloud.upload.SessionWriter, straight into
        %   the chosen cloud session. Chunks are always stored in NDI (the
        %   viewer reads only stored chunks, so a pyramid without them
        %   draws nothing).
        %
        %   Optional Name-Value Arguments:
        %     Api        - cloud calls for the writer (tests pass a fake)
        %     ingestArgs - extra name/value pairs for fromSPIM/fromOMEZarr,
        %                  after (so overriding) the ones from CHOICES,
        %                  e.g. {'asyncPrefetch', false}
            arguments
                session
                choices (1,1) struct
                options.Api = []
                options.ingestArgs cell = {}
            end
            plan = ndi.gui.app.LightsheetManager.addPlan(choices);
            if ~isempty(plan.errors)
                error('NDI:gui:LightsheetManager:cannotAdd', '%s', ...
                    ndi.gui.app.LightsheetManager.addMessage(plan));
            end
            target = session;
            if strcmp(choices.destination, 'cloud')
                target = ndi.cloud.upload.SessionWriter(choices.datasetId, ...
                    choices.sessionId, 'Api', options.Api);
            end
            args = {'subjectID', choices.subjectID, ...
                'clevel', choices.clevel, 'numWorkers', choices.numWorkers};
            if ~isempty(choices.label)
                args = [args {'label', choices.label}];
            end
            switch plan.ingest
                case 'fromSPIM'
                    args = [args {'reductions', cellstr(choices.reductions)}];
                    if ~isempty(choices.voxelSizeUm)
                        args = [args {'voxelSizeUm', double(choices.voxelSizeUm(:).')}];
                    end
                    [pyramidDoc, levelDocs, info] = ndi.fun.doc.lightsheet.fromSPIM( ...
                        target, choices.sourcePath, args{:}, options.ingestArgs{:});
                case 'fromOMEZarr'
                    [pyramidDoc, levelDocs, info] = ndi.fun.doc.lightsheet.fromOMEZarr( ...
                        target, choices.sourcePath, args{:}, ...
                        'materializeChunks', true, 'codec', 'blosc-zstd', ...
                        options.ingestArgs{:});
            end
        end
    end

    % =====================================================================
    methods (Static, Access = private)

        function v = field(s, name, dflt)
            if isstruct(s) && isfield(s, name), v = s.(name); else, v = dflt; end
        end

        function t = bullets(items)
            t = strjoin(cellfun(@(x) ['  - ' x], items(:).', ...
                'UniformOutput', false), newline);
        end

        function v = dependency(d, name)
            try
                v = d.dependency_value(name);
            catch
                v = '';
            end
            if isempty(v), v = ''; end
        end

        function v = lookup(m, key, dflt)
            v = dflt;
            if isempty(key) || ~isKey(m, char(key)), return; end
            v = m(char(key));
        end

        function c = rowsToCell(rows)
            c = cell(numel(rows), 6);
            for i = 1:numel(rows)
                c{i,1} = rows(i).label;
                c{i,2} = rows(i).subject;
                c{i,3} = rows(i).reduction;
                c{i,4} = rows(i).nLevels;
                if isempty(rows(i).shapeLevel0)
                    c{i,5} = '';
                else
                    c{i,5} = mat2str(double(rows(i).shapeLevel0));
                end
                c{i,6} = rows(i).dtype;
            end
        end
    end

    % =====================================================================
    methods (Access = private)

        function buildUI(obj)
            c = ndi.gui.cloudColors();
            obj.fig = uifigure('Name','Lightsheet Manager', ...
                'Position',[100 100 900 460], 'Color', c.offWhite);
            % The View dialog is a separate top-level window; closing
            % the manager has to take it along, or an orphaned dialog
            % would report its result to a status bar that no longer
            % exists.
            obj.fig.CloseRequestFcn = @(~,~) obj.onClose();
            g = uigridlayout(obj.fig,[4 5]);
            g.RowHeight = {28, '1x', 30, 22};
            g.ColumnWidth = {'1x', 90, 90, 90, 90};
            g.BackgroundColor = c.offWhite;

            % Navy header bar with white text, matching the cloud apps
            % and ndi.util.ListDialog.
            hb = uigridlayout(g,[1 1]);
            hb.Layout.Row = 1; hb.Layout.Column = [1 5];
            hb.Padding = [8 0 8 0];
            hb.BackgroundColor = c.darkBlue;
            uilabel(hb,'Text','Lightsheet images', ...
                'FontColor', c.white, 'FontWeight','bold', 'FontSize',14, ...
                'VerticalAlignment','center');

            obj.table = uitable(g, 'ColumnName', ...
                {'Label','Subject','Reduction','Levels','Shape (level 0)','dtype'});
            obj.table.Layout.Row = 2; obj.table.Layout.Column = [1 5];
            ndi.gui.app.LightsheetManager.paper(obj.table, c);

            b = uibutton(g,'Text','Reload','ButtonPushedFcn',@(~,~) obj.reload());
            b.Layout.Row = 3; b.Layout.Column = 2;
            ndi.gui.app.LightsheetManager.accent(b, c);
            b = uibutton(g,'Text','View...','ButtonPushedFcn',@(~,~) obj.onView());
            b.Layout.Row = 3; b.Layout.Column = 3;
            ndi.gui.app.LightsheetManager.accent(b, c);
            b = uibutton(g,'Text','Add...','ButtonPushedFcn',@(~,~) obj.onAdd());
            b.Layout.Row = 3; b.Layout.Column = 4;
            ndi.gui.app.LightsheetManager.accent(b, c);
            b = uibutton(g,'Text','Delete','ButtonPushedFcn',@(~,~) obj.onDelete());
            b.Layout.Row = 3; b.Layout.Column = 5;
            ndi.gui.app.LightsheetManager.accent(b, c);

            obj.statusLabel = uilabel(g,'Text','','FontColor', c.darkBlue);
            obj.statusLabel.Layout.Row = 4; obj.statusLabel.Layout.Column = [1 5];
        end

        function setStatus(obj, msg)
            if ~isempty(obj.statusLabel) && isvalid(obj.statusLabel)
                obj.statusLabel.Text = msg;
            end
        end

        function r = selectedRow(obj)
            r = [];
            sel = obj.table.Selection;
            if isempty(sel) || isempty(obj.rows), return; end
            r = obj.rows(sel(1));
        end

        function onView(obj)
        % ONVIEW - the launcher dialog, and then the launch
        %
        %   A dialog rather than a button that just runs, because the
        %   things it asks about cannot be recovered afterwards from
        %   the window that opens: which channel, which reduction,
        %   which level, and what the layer is called. And because the
        %   launcher is a path on the user's machine that NDI cannot
        %   know, only default.
        %
        %   THE COMMAND IS ON SCREEN before it runs, and stays readable
        %   afterwards. Launching another program is the step most
        %   likely to fail for reasons NDI cannot see -- a wrapper not
        %   installed, an environment that is not what it looks like --
        %   and a command the user can copy into a terminal turns that
        %   from a shrug into something they can act on.
            r = obj.selectedRow();
            if isempty(r)
                uialert(obj.fig,'Select a pyramid first.','Nothing selected');
                return;
            end
            sessionPath = '';
            try
                sessionPath = obj.session.getpath();
            catch
                try
                    sessionPath = obj.session.path;
                catch
                end
            end
            if isempty(sessionPath)
                uialert(obj.fig, ...
                    ['This session has no directory on disk. The napari ' ...
                     'viewer opens an ndi.session.dir, and there is ' ...
                     'nothing here for it to open.'], 'Nothing to view');
                return;
            end

            % One dialog at a time. Non-modal, so nothing stops the
            % button being pressed again; without this each press would
            % build another and the user would be editing whichever
            % landed on top while an older one held a different pyramid.
            if ~isempty(obj.viewDialog) && isvalid(obj.viewDialog)
                figure(obj.viewDialog);
                return;
            end

            c = ndi.gui.cloudColors();
            d = uifigure('Name','View in napari','Position',[120 120 660 430], ...
                'Color', c.offWhite);
            gl = uigridlayout(d,[9 3]);
            gl.RowHeight = {28, 40, 24, 24, 24, 24, 24, 24, 60};
            gl.ColumnWidth = {140, '1x', 100};
            gl.BackgroundColor = c.offWhite;

            hb = uigridlayout(gl,[1 1]);
            hb.Layout.Row = 1; hb.Layout.Column = [1 3];
            hb.Padding = [8 0 8 0];
            hb.BackgroundColor = c.darkBlue;
            uilabel(hb,'Text','View in napari', ...
                'FontColor', c.white, 'FontWeight','bold', 'FontSize',14, ...
                'VerticalAlignment','center');

            intro = uilabel(gl,'WordWrap','on','Text', ...
                ['Opens this pyramid in napari. The viewer is a separate ' ...
                 'Python program: MATLAB starts it and does not wait for ' ...
                 'it. The command that will run is shown at the bottom.']);
            intro.Layout.Row = 2; intro.Layout.Column = [1 3];

            lab = uilabel(gl,'Text','Launcher');
            lab.Layout.Row = 3; lab.Layout.Column = 1;
            % Remembered so Go only writes the preference when the user
            % changed the launcher: a path that was merely found must not
            % be pinned over a later ndi.python.install().
            initialLauncher = ndi.gui.app.LightsheetManager.launcherPath();
            ed = uieditfield(gl,'text','Value', initialLauncher);
            ed.Layout.Row = 3; ed.Layout.Column = 2;
            ndi.gui.app.LightsheetManager.paper(ed, c);
            br = uibutton(gl,'Text','Browse...');
            br.Layout.Row = 3; br.Layout.Column = 3;
            ndi.gui.app.LightsheetManager.accent(br, c);

            lab = uilabel(gl,'Text','Layer name');
            lab.Layout.Row = 4; lab.Layout.Column = 1;
            nameEd = uieditfield(gl,'text','Value', ...
                ndi.gui.app.LightsheetManager.orEmpty(r.label));
            nameEd.Layout.Row = 4; nameEd.Layout.Column = [2 3];
            ndi.gui.app.LightsheetManager.paper(nameEd, c);

            lab = uilabel(gl,'Text','Reduction');
            lab.Layout.Row = 5; lab.Layout.Column = 1;
            redDd = uidropdown(gl, 'Items', {'(as selected)','mean','max'}, ...
                'Value','(as selected)');
            redDd.Layout.Row = 5; redDd.Layout.Column = [2 3];
            ndi.gui.app.LightsheetManager.paper(redDd, c);

            lab = uilabel(gl,'Text','Channel');
            lab.Layout.Row = 6; lab.Layout.Column = 1;
            chSpin = uispinner(gl,'Limits',[-1 32],'Value',-1,'Step',1);
            chSpin.Layout.Row = 6; chSpin.Layout.Column = [2 3];
            chSpin.Tooltip = '-1 opens all channels as separate napari layers';
            ndi.gui.app.LightsheetManager.paper(chSpin, c);

            lab = uilabel(gl,'Text','Initial level');
            lab.Layout.Row = 7; lab.Layout.Column = 1;
            lvSpin = uispinner(gl,'Limits',[-1 32],'Value',-1,'Step',1);
            lvSpin.Layout.Row = 7; lvSpin.Layout.Column = [2 3];
            lvSpin.Tooltip = '-1 lets the viewer choose based on window size';
            ndi.gui.app.LightsheetManager.paper(lvSpin, c);

            cbPanels = uicheckbox(gl,'Text','Control panels','Value',true);
            cbPanels.Layout.Row = 8; cbPanels.Layout.Column = [1 3];

            cmdArea = uitextarea(gl,'Editable','off','Value','');
            cmdArea.Layout.Row = 9; cmdArea.Layout.Column = [1 2];
            ndi.gui.app.LightsheetManager.paper(cmdArea, c);
            go = uibutton(gl,'Text','Launch');
            ndi.gui.app.LightsheetManager.accent(go, c);
            go.Layout.Row = 9; go.Layout.Column = 3;

            br.ButtonPushedFcn = @(~,~) localBrowse();
            go.ButtonPushedFcn = @(~,~) localGo();
            everything = {ed, nameEd, redDd, chSpin, lvSpin, cbPanels};
            for i = 1:numel(everything)
                everything{i}.ValueChangedFcn = @localRefresh;
            end

            % One log per launch, named now so the command shown is the
            % exact line that will run (and can be pasted in a terminal).
            logFile = ndi.fun.doc.lightsheet.viewerLogFile();

            localRefresh();
            obj.viewDialog = d;

            function [cmd, ok] = localCommand()
                ok = true;
                try
                    red = '';
                    if ~strcmp(redDd.Value, '(as selected)')
                        red = redDd.Value;
                    end
                    cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                        ndi.gui.app.LightsheetManager.resolveLauncher(ed.Value), ...
                        sessionPath, r.id, ...
                        'reduction', red, ...
                        'channel', chSpin.Value, ...
                        'level', lvSpin.Value, ...
                        'controls', cbPanels.Value, ...
                        'name', nameEd.Value);
                catch ME
                    cmd = ME.message;
                    ok = false;
                end
            end

            function localRefresh(~,~)
                % Show the full shell line: debugging on and output
                % appended to the log, as launchViewer will run it.
                [cmd, ok] = localCommand();
                if ok
                    cmd = ndi.fun.doc.lightsheet.viewerShellCommand( ...
                        cmd, logFile, false, true, ispc);
                end
                cmdArea.Value = cmd;
            end

            function localBrowse()
                [f,pth] = uigetfile('*','Select the napari viewer launcher');
                figure(d);
                if isequal(f,0), return; end
                ed.Value = fullfile(pth,f);
                localRefresh();
            end

            function localGo()
                cmd = localCommand();
                target = ndi.gui.app.LightsheetManager.resolveLauncher(ed.Value);
                if isempty(target)
                    uialert(d, ['NDI-python''s napariViewLightsheet was ' ...
                        'not found. Run ndi.python.install() in MATLAB ' ...
                        'to install it, or point Launcher at it yourself.'], ...
                        'Launcher not found');
                    return;
                end
                if ~isempty(regexp(target,'[/\\]','once')) && ~isfile(target)
                    uialert(d, sprintf(['No launcher at\n  %s\n\nRun ' ...
                        'ndi.python.install() in MATLAB to install ' ...
                        'NDI-python''s napariViewLightsheet, or point ' ...
                        'this at the console script yourself.'], target), ...
                        'Launcher not found');
                    return;
                end
                % Only a launcher the user chose is remembered; clearing
                % the field goes back to finding it automatically.
                if ~strcmp(strtrim(ed.Value), initialLauncher)
                    ndi.gui.app.LightsheetManager.setLauncherPath(strtrim(ed.Value));
                end
                % Debugging lines on, and the viewer's output kept in a
                % log in NDI's temporary folder: launched from here it
                % has no terminal, so the log is the only record of what
                % it fetched and what failed.
                status = ndi.fun.doc.lightsheet.launchViewer(cmd, 'logFile', logFile);
                delete(d);
                if status == 0
                    obj.setStatus(sprintf(['Launched the viewer for %s. ' ...
                        'Its log: %s'], obj.rowLabel(r), logFile));
                else
                    obj.setStatus(sprintf(['The launcher exited %d. ' ...
                        'The command was:  %s  (log: %s)'], status, cmd, logFile));
                end
            end
        end

        function onClose(obj)
        % ONCLOSE - shut the manager, and anything it opened
        %
        %   Only the View and Add dialogs are closed. The napari process is
        %   deliberately NOT touched: it was detached on purpose, it is
        %   somebody's picture, and closing the window that launched it
        %   is not a request to close it.
            if ~isempty(obj.viewDialog) && isvalid(obj.viewDialog)
                delete(obj.viewDialog);
            end
            if ~isempty(obj.addDialog) && isvalid(obj.addDialog)
                delete(obj.addDialog);
            end
            delete(obj.fig);
        end

        function onDelete(obj)
            r = obj.selectedRow();
            if isempty(r)
                uialert(obj.fig,'Select a pyramid first.','Nothing selected');
                return;
            end
            plan = ndi.gui.app.LightsheetManager.deletionPlan( ...
                obj.session, r.id);
            msg = ndi.gui.app.LightsheetManager.deletionMessage( ...
                plan, obj.rowLabel(r));
            choice = uiconfirm(obj.fig, msg, 'Confirm delete', ...
                'Options',{'Delete','Cancel'}, ...
                'DefaultOption',2,'CancelOption',2);
            if ~strcmp(choice,'Delete'), return; end
            for k = 1:numel(plan.docsToRemove)
                obj.session.database_rm(plan.docsToRemove{k});
            end
            obj.setStatus(sprintf('Deleted %d document(s).', ...
                1 + plan.nLevels));
            obj.reload();
        end

        function onAdd(obj)
        % ONADD - the Add dialog: where, which subject, which folder
        %
        %   One window, filled in top to bottom: where the image goes
        %   (this session, or a session of an NDI Cloud dataset), the
        %   subject it is of (pick one of that session's, or add one), and
        %   the folder that holds it (recognised as a SmartSPIM acquisition
        %   or an OME-Zarr store). The box at the bottom lists what is
        %   still missing, from addPlan, and Add stays off until nothing
        %   is. Non-modal, like View, and raised rather than duplicated.
            if ~isempty(obj.addDialog) && isvalid(obj.addDialog)
                figure(obj.addDialog);
                return;
            end
            choices = ndi.gui.app.LightsheetManager.addChoices();
            datasets = {};       % cloud datasets, loaded on first use
            sessions = struct('session_id', {}, 'session_reference', {});
            subjects = struct('id', {}, 'local_identifier', {});
            autoLabel = '';      % the label we filled in, replaced on a new folder
            clevelTouched = false;  % the user chose a compression; keep it

            c = ndi.gui.cloudColors();
            d = uifigure('Name', 'Add a lightsheet image', ...
                'Position', [140 100 700 610], 'Color', c.offWhite);
            gl = uigridlayout(d, [15 3]);
            gl.RowHeight = {28, 36, 24, 24, 24, 24, 24, 22, 24, 24, 24, 24, 24, '1x', 30};
            gl.ColumnWidth = {130, '1x', 130};
            gl.BackgroundColor = c.offWhite;

            hb = uigridlayout(gl, [1 1]);
            hb.Layout.Row = 1; hb.Layout.Column = [1 3];
            hb.Padding = [8 0 8 0];
            hb.BackgroundColor = c.darkBlue;
            uilabel(hb, 'Text', 'Add a lightsheet image', ...
                'FontColor', c.white, 'FontWeight', 'bold', 'FontSize', 14, ...
                'VerticalAlignment', 'center');

            intro = uilabel(gl, 'WordWrap', 'on', 'Text', ...
                ['Choose where the image goes, the subject it is of, and ' ...
                 'the folder that holds it. The box below lists anything ' ...
                 'still missing.']);
            intro.Layout.Row = 2; intro.Layout.Column = [1 3];

            % -- where ---------------------------------------------------
            row(3, 'Add to');
            destDd = uidropdown(gl, 'Items', ...
                {'This session', 'A session in an NDI Cloud dataset'}, ...
                'ItemsData', {'local', 'cloud'}, 'Value', 'local');
            place(destDd, 3, [2 3]);

            row(4, 'Dataset');
            datasetDd = uidropdown(gl, 'Items', {'(choose NDI Cloud above)'}, ...
                'ItemsData', {''}, 'Enable', 'off');
            place(datasetDd, 4, [2 3]);

            row(5, 'Session');
            sessionDd = uidropdown(gl, 'Items', {'(choose a dataset first)'}, ...
                'ItemsData', {''}, 'Enable', 'off');
            place(sessionDd, 5, [2 3]);

            % -- which subject ------------------------------------------
            row(6, 'Subject');
            subjectDd = uidropdown(gl, 'Items', {''}, 'ItemsData', {''});
            place(subjectDd, 6, 2);
            newSubjBtn = uibutton(gl, 'Text', 'New subject...');
            newSubjBtn.Layout.Row = 6; newSubjBtn.Layout.Column = 3;
            ndi.gui.app.LightsheetManager.accent(newSubjBtn, c);

            % -- which folder -------------------------------------------
            row(7, 'Image folder');
            pathEd = uieditfield(gl, 'text', 'Value', '', ...
                'Placeholder', 'SmartSPIM acquisition folder or .ome.zarr store');
            place(pathEd, 7, 2);
            browseBtn = uibutton(gl, 'Text', 'Browse...');
            browseBtn.Layout.Row = 7; browseBtn.Layout.Column = 3;
            ndi.gui.app.LightsheetManager.accent(browseBtn, c);
            kindLabel = uilabel(gl, 'Text', 'No folder chosen yet.', ...
                'FontAngle', 'italic', 'FontColor', c.darkBlue);
            kindLabel.Layout.Row = 8; kindLabel.Layout.Column = [2 3];

            row(9, 'Label');
            labelEd = uieditfield(gl, 'text', 'Value', '', ...
                'Placeholder', 'defaults to the folder name');
            place(labelEd, 9, [2 3]);

            row(10, 'Voxel size (um)');
            voxEd = uieditfield(gl, 'text', 'Value', '', 'Enable', 'off', ...
                'Placeholder', 'z y x; empty reads it from the acquisition');
            place(voxEd, 10, [2 3]);

            % -- how ---------------------------------------------------
            row(11, 'Compression');
            clevelDd = uidropdown(gl, 'Items', { ...
                '1  (fastest, largest files)', '2', '3', '4', ...
                '5  (default for this session)', '6', '7', ...
                '8  (recommended for the cloud)', ...
                '9  (smallest, very slow, much more memory)'}, ...
                'ItemsData', num2cell(1:9), ...
                'Value', choices.clevel);
            clevelDd.Tooltip = ['Blosc-Zstd level of the stored chunks. They ' ...
                'are kept as built, so a higher level saves storage for ' ...
                'good at the cost of a slower build. Opening them is about ' ...
                'equally fast at every level.'];
            place(clevelDd, 11, [2 3]);

            row(12, 'Reductions');
            reductionDd = uidropdown(gl, 'Items', ...
                {'mean and max', 'mean only', 'max only'}, ...
                'ItemsData', {'mean,max', 'mean', 'max'}, 'Value', 'mean,max', ...
                'Enable', 'off');
            reductionDd.Tooltip = ['The downsampled ladders built from a ' ...
                'SmartSPIM image. Each one adds about a third to the chunks ' ...
                'of the full-resolution level. An OME-Zarr store brings its own.'];
            place(reductionDd, 12, [2 3]);

            row(13, 'Workers');
            workersSp = uispinner(gl, 'Limits', [1 256], 'Step', 1, ...
                'RoundFractionalValues', 'on', ...
                'Value', ndi.gui.app.LightsheetManager.defaultWorkers());
            workersSp.Tooltip = ['Parallel workers compressing chunks. More ' ...
                'than 1 opens a parallel pool of that size. Each worker can ' ...
                'need about 3 GB of memory while the coarser levels are built.'];
            place(workersSp, 13, [2 3]);

            msgArea = uitextarea(gl, 'Editable', 'off', 'Value', '');
            place(msgArea, 14, [1 3]);

            bg = uigridlayout(gl, [1 3]);
            bg.Layout.Row = 15; bg.Layout.Column = [1 3];
            bg.ColumnWidth = {'1x', 110, 110};
            bg.Padding = [0 0 0 0];
            bg.BackgroundColor = c.offWhite;
            cancelBtn = uibutton(bg, 'Text', 'Cancel');
            cancelBtn.Layout.Column = 2;
            ndi.gui.app.LightsheetManager.accent(cancelBtn, c);
            addBtn = uibutton(bg, 'Text', 'Add', 'Enable', 'off');
            addBtn.Layout.Column = 3;
            ndi.gui.app.LightsheetManager.accent(addBtn, c);

            destDd.ValueChangedFcn    = @(~,~) onDestination();
            datasetDd.ValueChangedFcn = @(~,~) onDataset();
            sessionDd.ValueChangedFcn = @(~,~) onSession();
            subjectDd.ValueChangedFcn = @(~,~) refresh();
            newSubjBtn.ButtonPushedFcn = @(~,~) onNewSubject();
            pathEd.ValueChangedFcn    = @(~,~) onFolder(pathEd.Value);
            browseBtn.ButtonPushedFcn = @(~,~) onBrowse();
            labelEd.ValueChangedFcn   = @(~,~) refresh();
            voxEd.ValueChangedFcn     = @(~,~) refresh();
            clevelDd.ValueChangedFcn  = @(~,~) onClevel();
            reductionDd.ValueChangedFcn = @(~,~) refresh();
            workersSp.ValueChangedFcn = @(~,~) refresh();
            cancelBtn.ButtonPushedFcn = @(~,~) delete(d);
            addBtn.ButtonPushedFcn    = @(~,~) onGo();

            obj.addDialog = d;
            loadSubjects();

            % -- layout helpers -------------------------------------------
            function row(r, text)
                lab = uilabel(gl, 'Text', text);
                lab.Layout.Row = r; lab.Layout.Column = 1;
            end
            function place(h, r, cols)
                h.Layout.Row = r; h.Layout.Column = cols;
                ndi.gui.app.LightsheetManager.paper(h, c);
            end
            function busy(tf, text)
                % Lists come from the cloud and can take a few seconds.
                if tf
                    msgArea.Value = text;
                    d.Pointer = 'watch';
                else
                    d.Pointer = 'arrow';
                end
                drawnow;
            end

            % -- the choices, from the widgets -----------------------------
            function refresh()
                choices.destination = destDd.Value;
                choices.datasetId = datasetDd.Value;
                choices.datasetName = itemText(datasetDd);
                choices.sessionId = sessionDd.Value;
                choices.sessionReference = '';
                k = find(strcmp({sessions.session_id}, sessionDd.Value), 1);
                if ~isempty(k), choices.sessionReference = sessions(k).session_reference; end
                choices.subjectID = subjectDd.Value;
                choices.subjectName = itemText(subjectDd);
                choices.label = strtrim(labelEd.Value);
                choices.voxelSizeUm = sscanf(strrep(voxEd.Value, ',', ' '), '%f').';
                if ~isempty(strtrim(voxEd.Value)) && isempty(choices.voxelSizeUm)
                    choices.voxelSizeUm = NaN;   % typed but unreadable: addPlan says so
                end
                choices.clevel = clevelDd.Value;
                choices.reductions = strsplit(reductionDd.Value, ',');
                choices.numWorkers = workersSp.Value;
                isSpim = strcmp(choices.sourceKind, 'smartspim');
                voxEd.Enable = onOff(isSpim);
                reductionDd.Enable = onOff(isSpim);
                plan = ndi.gui.app.LightsheetManager.addPlan(choices);
                if isempty(plan.errors)
                    msgArea.Value = [{'Ready to add.'}; plan.warnings];
                else
                    msgArea.Value = [{'Still needed:'}; ...
                        cellfun(@(x) ['  - ' x], plan.errors, 'UniformOutput', false)];
                end
                addBtn.Enable = onOff(isempty(plan.errors));
            end

            % -- where ------------------------------------------------------
            function onClevel()
                clevelTouched = true;
                refresh();
            end

            function onDestination()
                toCloud = strcmp(destDd.Value, 'cloud');
                if ~clevelTouched
                    clevelDd.Value = ndi.gui.app.LightsheetManager.defaultClevel(destDd.Value);
                end
                datasetDd.Enable = onOff(toCloud);
                sessionDd.Enable = onOff(toCloud);
                if toCloud && isempty(datasets)
                    loadDatasets();
                elseif ~toCloud
                    choices.destination = 'local';
                end
                loadSubjects();
            end

            function loadDatasets()
                busy(true, 'Reading your NDI Cloud datasets...');
                try
                    [ok, answer] = ndi.cloud.api.datasets.listDatasets();
                    if ~ok, error('NDI Cloud did not list the datasets.'); end
                    datasets = answer.datasets;
                    if isstruct(datasets), datasets = num2cell(datasets); end
                catch ME
                    busy(false);
                    datasets = {};
                    uialert(d, ME.message, 'Could not list datasets');
                    destDd.Value = 'local';
                    onDestination();
                    return
                end
                busy(false);
                names = cellfun(@(x) char(x.name), datasets, 'UniformOutput', false);
                orgs = cellfun(@(x) char(ndi.gui.app.LightsheetManager.field(x, 'organizationName', '')), ...
                    datasets, 'UniformOutput', false);
                if numel(unique(orgs)) > 1
                    names = cellfun(@(o, n) sprintf('[%s] %s', o, n), orgs, names, ...
                        'UniformOutput', false);
                end
                ids = cellfun(@(x) char(x.id), datasets, 'UniformOutput', false);
                setItems(datasetDd, [{'(choose a dataset)'}, reshape(names, 1, [])], ...
                    [{''}, reshape(ids, 1, [])]);
            end

            function onDataset()
                sessions = sessions([]);
                setItems(sessionDd, {'(choose a dataset first)'}, {''});
                if ~isempty(datasetDd.Value)
                    busy(true, 'Reading the dataset''s sessions...');
                    try
                        sessions = ndi.cloud.upload.SessionWriter.listSessions(datasetDd.Value);
                    catch ME
                        busy(false);
                        uialert(d, ME.message, 'Could not read the dataset');
                        refresh();
                        return
                    end
                    busy(false);
                    if isempty(sessions)
                        setItems(sessionDd, {'(this dataset has no sessions)'}, {''});
                    else
                        setItems(sessionDd, [{'(choose a session)'}, ...
                            ndi.gui.app.LightsheetManager.sessionLabels(sessions)], ...
                            [{''}, {sessions.session_id}]);
                    end
                end
                loadSubjects();
            end

            function onSession()
                loadSubjects();
            end

            % -- which subject ---------------------------------------------
            function loadSubjects(selectId, selectName)
                % SELECTID/SELECTNAME: a subject just added, selected
                % afterwards, and listed even if a cloud search does not
                % return it yet.
                if nargin < 1, selectId = ''; end
                if nargin < 2, selectName = ''; end
                refresh();
                subjects = subjects([]);
                if strcmp(choices.destination, 'cloud') && isempty(choices.sessionId)
                    setItems(subjectDd, {'(choose a session first)'}, {''});
                    newSubjBtn.Enable = 'off';
                    refresh();
                    return
                end
                newSubjBtn.Enable = 'on';
                if strcmp(choices.destination, 'cloud')
                    busy(true, 'Reading the session''s subjects...');
                end
                try
                    subjects = ndi.gui.app.LightsheetManager.targetSubjects(obj.session, choices);
                catch ME
                    busy(false);
                    uialert(d, ME.message, 'Could not read the subjects');
                end
                busy(false);
                if ~isempty(selectId) && ~any(strcmp({subjects.id}, selectId))
                    subjects(end+1) = struct('id', selectId, 'local_identifier', selectName);
                end
                if isempty(subjects)
                    setItems(subjectDd, {'(no subjects yet: add one)'}, {''});
                else
                    setItems(subjectDd, [{'(choose a subject)'}, {subjects.local_identifier}], ...
                        [{''}, {subjects.id}]);
                    if any(strcmp({subjects.id}, selectId))
                        subjectDd.Value = selectId;
                    end
                end
                refresh();
            end

            function onNewSubject()
                answer = inputdlg({'Local identifier (for example mouse42@vhlab.org):', ...
                    'Description (optional):'}, 'New subject', [1 60; 3 60]);
                figure(d);
                if isempty(answer), return; end
                localId = strtrim(answer{1});
                desc = strtrim(strjoin(cellstr(answer{2}), ' '));
                problems = ndi.gui.app.LightsheetManager.subjectProblems(localId, {subjects.local_identifier});
                if ~isempty(problems)
                    uialert(d, strjoin(problems, ' '), 'Cannot add that subject');
                    return
                end
                where = 'this session';
                if strcmp(choices.destination, 'cloud')
                    where = sprintf('cloud session %s', choices.sessionReference);
                end
                ok = uiconfirm(d, sprintf('Add subject %s to %s now?', localId, where), ...
                    'New subject', 'Options', {'Add subject', 'Cancel'}, ...
                    'DefaultOption', 1, 'CancelOption', 2);
                if ~strcmp(ok, 'Add subject'), return; end
                busy(true, sprintf('Adding subject %s...', localId));
                try
                    newId = ndi.gui.app.LightsheetManager.addSubject(obj.session, choices, localId, desc);
                catch ME
                    busy(false);
                    uialert(d, ME.message, 'Could not add the subject');
                    return
                end
                busy(false);
                loadSubjects(newId, localId);
            end

            % -- which folder ----------------------------------------------
            function onBrowse()
                start = strtrim(pathEd.Value);
                if isempty(start) || ~isfolder(start), start = pwd; end
                f = uigetdir(start, ['Choose the SmartSPIM acquisition folder ' ...
                    '(the one holding All_Channels) or the .ome.zarr store']);
                figure(d);
                if isequal(f, 0), return; end
                pathEd.Value = f;
                onFolder(f);
            end

            function onFolder(f)
                f = strip(strtrim(char(f)), 'right', filesep);
                choices.sourcePath = f;
                [choices.sourceKind, kindLabel.Text] = ndi.gui.app.LightsheetManager.sourceKind(f);
                [~, name] = fileparts(f);
                if isempty(labelEd.Value) || strcmp(labelEd.Value, autoLabel)
                    labelEd.Value = name;
                    autoLabel = name;
                end
                refresh();
            end

            % -- add ---------------------------------------------------------
            function onGo()
                refresh();
                plan = ndi.gui.app.LightsheetManager.addPlan(choices);
                if ~isempty(plan.errors), return; end
                ok = uiconfirm(d, ndi.gui.app.LightsheetManager.addMessage(plan), ...
                    'Add lightsheet image', 'Options', {'Add', 'Cancel'}, ...
                    'DefaultOption', 1, 'CancelOption', 2);
                if ~strcmp(ok, 'Add'), return; end
                final = choices;
                delete(d);
                if strcmp(final.destination, 'cloud')
                    obj.runCloudJob(final, plan);
                    return
                end
                obj.setStatus(sprintf(['Adding %s to %s; progress is in the ' ...
                    'Command Window...'], final.sourcePath, plan.where));
                drawnow;
                try
                    ndi.gui.app.LightsheetManager.runAdd(obj.session, final);
                catch ME
                    obj.setStatus('Add failed; see the message.');
                    uialert(obj.fig, ME.message, 'Add failed');
                    return
                end
                obj.setStatus('Image added.');
                obj.reload();
            end
        end

        function runCloudJob(obj, choices, plan)
        % RUNCLOUDJOB - add to the cloud as a job (ndi.job.LightsheetToCloud)
        %
        %   A job, so the hours it takes can be paused, and a run stopped
        %   by a lost connection, a crash or quitting MATLAB can be resumed
        %   from the navigator's Jobs pane rather than started over.
            try
                job = ndi.job.LightsheetToCloud.create(choices);
            catch ME
                uialert(obj.fig, ME.message, 'Could not start');
                return
            end
            obj.setStatus(sprintf(['Adding to %s as a job; pause or resume it ' ...
                'from the navigator''s Jobs pane...'], plan.where));
            drawnow;
            job.run();
            switch job.state
                case 'done'
                    r = job.checkpoint.report;
                    obj.setStatus(sprintf(['Added %d document(s) and %d file(s) ' ...
                        '(%.1f MB) to %s.'], r.documents, r.files, r.bytes / 1e6, plan.where));
                case 'paused'
                    obj.setStatus(sprintf(['Paused at %s. Resume it from the ' ...
                        'navigator''s Jobs pane.'], ndi.job.Job.percentText(job.progress)));
                otherwise
                    obj.setStatus(sprintf(['Stopped at %s: %s Resume it from ' ...
                        'the navigator''s Jobs pane once the cause is fixed.'], ...
                        ndi.job.Job.percentText(job.progress), job.message));
                    if isvalid(obj.fig)
                        uialert(obj.fig, job.message, 'Add to NDI Cloud stopped');
                    end
            end
        end

        function s = rowLabel(~, r)
            s = r.label;
            if isempty(s), s = r.id; end
        end
    end

    methods (Static, Access = private)
        function s = orEmpty(v)
            if isempty(v), s = ''; else, s = char(v); end
        end
    end
end

function setItems(dd, items, data)
% Replace a dropdown's entries and their data together, on the placeholder.
    set(dd, 'Items', items, 'ItemsData', data, 'Value', data{1});
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end

function t = itemText(dd)
% The visible text of a dropdown's selected entry; '' for a placeholder.
    t = '';
    k = find(cellfun(@(x) isequal(x, dd.Value), dd.ItemsData), 1);
    if ~isempty(k) && ~isempty(dd.Value)
        t = char(dd.Items{k});
    end
end
