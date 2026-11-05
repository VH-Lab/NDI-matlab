classdef LightsheetToCloud < ndi.job.Job
% NDI.JOB.LIGHTSHEETTOCLOUD - build a lightsheet pyramid straight into a cloud session, resumably
%
%   JOB = ndi.job.LightsheetToCloud.create(CHOICES)
%
%   CHOICES is what ndi.gui.app.LightsheetManager.addChoices describes,
%   with destination 'cloud' (the Lightsheet Manager's Add dialog makes
%   one). JOB.run() builds the pyramid with ndi.fun.doc.lightsheet.fromSPIM
%   or fromOMEZarr through an ndi.cloud.upload.SessionWriter, which
%   streams the chunks as they are made.
%
%   RESUMING. Every document the writer uploads is also saved in the job's
%   folder (documents/), with its series member uids. If the run stops --
%   paused, a lost connection that outlasted the writer's retries, a slice
%   server that stayed down, Ctrl+C, MATLAB quit or crashed -- the next
%   run() adopts the pyramid and the levels already in the cloud, asks the
%   cloud which of their chunks it has, and builds only the missing ones;
%   levels not declared yet are built as usual. The writer's cache (the
%   level a coarser level is reduced from) is in the job's folder too, so
%   it survives a restart; if it is gone, those chunks are downloaded.
%
%   PROFILE. Every super-block's timings go to profile.csv in the job's
%   folder (appended across runs), and a summary of where the time goes
%   is printed every 10 minutes and after each level (see
%   ndi.fun.doc.lightsheet.BuildProfile).
%
%   RESTART starts over with a new pyramid. The one the earlier run left in
%   the cloud stays there, labelled "(uploading)"; delete it from the
%   dataset if it is not wanted.
%
%   See also: ndi.job.Job, ndi.gui.app.LightsheetManager,
%             ndi.cloud.upload.SessionWriter

    properties (Constant)
        Kind = 'lightsheetToCloud'
    end

    properties (Transient)
        % Test hook: extra name/value pairs for fromSPIM/fromOMEZarr
        % (small chunks and reads, so a test can pause partway through a
        % level). Not saved with the job.
        ExtraIngestArgs cell = {}
    end

    methods (Static)
        function job = create(choices)
            arguments
                choices (1,1) struct
            end
            if ~strcmp(choices.destination, 'cloud')
                error('NDI:job:LightsheetToCloud:notCloud', ...
                    'This job adds to an NDI Cloud session; choose destination ''cloud''.');
            end
            plan = ndi.gui.app.LightsheetManager.addPlan(choices);
            if ~isempty(plan.errors)
                error('NDI:job:LightsheetToCloud:incomplete', '%s', ...
                    ndi.gui.app.LightsheetManager.addMessage(plan));
            end
            label = choices.label;
            if isempty(label)
                [~, label] = fileparts(strip(char(choices.sourcePath), 'right', filesep));
            end
            title = sprintf('%s to %s', label, plan.where);
            job = ndi.job.LightsheetToCloud();
            job.initialize(title, choices);
        end
    end

    methods (Access = protected)
        function work(obj)
            c = obj.spec;
            writer = ndi.cloud.upload.SessionWriter(c.datasetId, c.sessionId, ...
                'CacheDir', fullfile(obj.folder(), 'cache'), ...
                'KeepLocalCopies', true, ...
                'OnUpload', @(doc) obj.recordUpload(doc), ...
                'Api', obj.Api);

            args = {'subjectID', c.subjectID, 'clevel', c.clevel, ...
                'numWorkers', c.numWorkers, 'progressFcn', @(f, t) obj.beat(f, t), ...
                'profileLog', fullfile(obj.folder(), 'profile.csv')};
            if ~isempty(c.label)
                args = [args {'label', c.label}];
            end
            args = [args obj.ExtraIngestArgs];
            [resume, sourceFileID] = obj.resumeFromSaved();
            if ~isempty(sourceFileID)
                args = [args {'sourceFileID', sourceFileID}];
            end
            if ~isempty(resume)
                obj.beat(obj.progress, 'Resuming: asking the cloud what it already has...');
                args = [args {'resume', resume}];
            end

            switch char(c.sourceKind)
                case 'smartspim'
                    args = [args {'reductions', cellstr(c.reductions)}];
                    if ~isempty(c.voxelSizeUm)
                        args = [args {'voxelSizeUm', double(c.voxelSizeUm(:).')}];
                    end
                    [~, ~, info] = ndi.fun.doc.lightsheet.fromSPIM(writer, c.sourcePath, args{:});
                case 'omezarr'
                    [~, ~, info] = ndi.fun.doc.lightsheet.fromOMEZarr(writer, c.sourcePath, ...
                        args{:}, 'materializeChunks', true, 'codec', 'blosc-zstd');
                otherwise
                    error('NDI:job:LightsheetToCloud:unknownSource', ...
                        'Unknown source kind ''%s''.', char(c.sourceKind));
            end
            obj.setCheckpoint('report', info.cloud);
            cache = fullfile(obj.folder(), 'cache');
            if isfolder(cache), rmdir(cache, 's'); end
        end

        function onRestart(obj)
            for sub = {'documents', 'cache'}
                f = fullfile(obj.folder(), sub{1});
                if isfolder(f), rmdir(f, 's'); end
            end
        end
    end

    methods (Access = private)
        function recordUpload(obj, doc)
        % Keep each uploaded document, as uploaded but with its series
        % member uids, so a later run can adopt it.
            d = fullfile(obj.folder(), 'documents');
            if ~isfolder(d), mkdir(d); end
            fid = fopen(fullfile(d, [doc.id() '.json']), 'w');
            fwrite(fid, did.datastructures.jsonencodenan(doc.document_properties), 'char');
            fclose(fid);
        end

        function [resume, sourceFileID] = resumeFromSaved(obj)
        % What an earlier run of this job already put in the cloud.
            resume = [];
            sourceFileID = '';
            d = fullfile(obj.folder(), 'documents');
            files = dir(fullfile(d, '*.json'));
            pyramid = [];
            levels = {};
            for k = 1:numel(files)
                props = jsondecode(fileread(fullfile(d, files(k).name)));
                doc = ndi.document(props);
                switch char(props.document_class.class_name)
                    case 'lightsheetZarrPyramid'
                        pyramid = doc;
                    case 'lightsheetZarrLevel'
                        levels{end+1} = doc; %#ok<AGROW>
                    case 'fileReference'
                        sourceFileID = doc.id();
                end
            end
            if ~isempty(pyramid)
                resume = struct('pyramidDoc', pyramid, 'levelDocs', {levels});
            end
        end
    end
end
