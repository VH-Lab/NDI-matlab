function result = import_V2(dataParentDir, options)
%IMPORT_V2 Import the Haley C. elegans / E. coli foraging dataset as V2 (V_eta).
%
%   RESULT = ndi.setup.conv.haley.import_V2(DATAPARENTDIR) runs the import's
%   stages over the raw data in DATAPARENTDIR/haley and returns what each
%   stage produced. It is being built one stage at a time with the dataset's
%   owner, and is meant to be the canonical example of a V2 import (and the
%   basis of a GUI importer): every choice it makes is recorded, with its
%   reason, in import_V2_decisions.md next to this file.
%
%   The stages, in order (decision log, "Stage order"):
%     A. dataset, once
%        0  discover       list the source files; skip earlier import output
%        1  profile        describe tables (ndi.setup.V2.profileTable, on demand)
%        2  metadata       dataset, people, organizations, funding, publication,
%                          studies, software, products, strains, instruments --
%                          from import_V2_spec.json (sources: the eLife paper)
%     B. per study (E. coli first); per day:
%        3  sessions       one per experiment day, part_of its study
%        4  subjects       plates, patches, worms, growth plates   (listed; not yet written)
%        5  acquisition    camera/microscope, one epoch per video  (listed; not yet written)
%        6  relations      patch on plate, worm on plate, ...      (not yet)
%        7  assertions     strain, species, exclusion tags         (not yet)
%        8  manipulations  plate preparation, food deprivation     (not yet)
%        9  observations   tracks, environment, geometry, images   (not yet)
%        10 calculations   masks, closest-patch maps               (not yet)
%     C. dataset-wide, once
%        11 encounters, 12 cross-study calculations, 13 check & write (not yet)
%
%   Nothing is written unless 'Write' is true: by default RESULT holds what
%   each stage WOULD create, for inspection. With 'Write', stage 3 creates the
%   session directories and their V2 databases under 'OutputRoot'.
%
%   Options:
%     'Spec'              path to the spec (default: import_V2_spec.json here)
%     'Stages'            which stages to run (default: all implemented)
%     'OutputRoot'        where session directories go (default:
%                         <DATAPARENTDIR>/haley_V2; the raw data is never
%                         written to, decision 21)
%     'Write'             default false; true creates the sessions
%     'Overwrite'         default false; true replaces existing sessions
%     'ReadVideos'        default true: opens each lawn clip (VideoReader) to
%                         read its length (stage 5); false skips it for a
%                         quick look
%     'DatasetSessionId'  session id for dataset-level documents (default: a
%                         new id; stage 10 will take it from the dataset)
%
%   doImport.m, the original V1 import, is unchanged.
%
%   See also ndi.setup.V2.discover, ndi.setup.V2.datasetMetadata.

arguments
    dataParentDir (1,:) char {mustBeFolder} = fullfile(userpath, 'data')
    options.Spec (1,:) char = fullfile(fileparts(mfilename('fullpath')), 'import_V2_spec.json')
    options.Stages (1,:) string = ["discover", "metadata", "sessions", "subjects", "acquisition"]
    options.OutputRoot (1,:) char = ''
    options.Write (1,1) logical = false
    options.Overwrite (1,1) logical = false
    options.DatasetSessionId (1,:) char = ''
    options.ReadVideos (1,1) logical = true
end

% Check the requirements up front, so a missing one is reported with its fix
% rather than as "Unable to resolve the name 'did2.build.label'" mid-stage.
if any(ismember(options.Stages, ["metadata", "sessions"]))
    ndi.setup.V2.preflight();
end

result = struct();
sid = options.DatasetSessionId;
if isempty(sid)
    sid = did.ido.unique_id();
end
result.datasetSessionId = sid;

if any(options.Stages == "discover")
    fprintf('\n== stage 0: discover ==\n');
    result.files = ndi.setup.V2.discover(fullfile(dataParentDir, 'haley'));
end

if any(options.Stages == "metadata")
    fprintf('\n== stage 2: dataset metadata ==\n');
    spec = jsondecode(fileread(options.Spec));
    result.metadata = ndi.setup.V2.datasetMetadata(spec, sid);
    fprintf('DENOMINATOR: %d document(s) built from %s\n', ...
        numel(result.metadata.documents), options.Spec);
    disp(result.metadata.census);
    u = result.metadata.unrepresented;
    fprintf('spec content with NO place in V2 (recorded here, not in the documents): %d\n', numel(u));
    for k = 1:numel(u)
        fprintf('  %-12s %-20s %-16s %s\n', u(k).kind, u(k).key, u(k).field, u(k).why);
    end
end

if any(options.Stages == "sessions")
    fprintf('\n== stage 3: sessions ==\n');
    spec = jsondecode(fileread(options.Spec));
    studyIds = containers.Map();
    if isfield(result, 'metadata')
        studyIds = result.metadata.ids;
    end
    [result.sessions, result.sessionChecks] = ndi.setup.conv.haley.sessionList(dataParentDir, spec, ...
        'StudyIds', studyIds, 'OutputRoot', options.OutputRoot);
    disp(result.sessions(:, {'local_identifier', 'study_key', 'date', 'include'}));
    if options.Write
        [result.sessions, result.sessionObjects] = ndi.setup.V2.makeSessions( ...
            result.sessions, 'Overwrite', options.Overwrite);
    else
        fprintf('(not written: pass ''Write'', true to create these sessions)\n');
    end
end

if any(options.Stages == "subjects")
    fprintf('\n== stage 4: subjects ==\n');
    if ~isfield(result, 'sessions')
        error('ndi:setup:conv:haley:needSessions', ...
            'The subjects stage needs the sessions stage: include "sessions" in ''Stages''.');
    end
    [result.subjects, result.subjectChecks] = ndi.setup.conv.haley.subjectList( ...
        dataParentDir, result.sessions);
    if height(result.subjects) > 0
        disp(groupsummary(result.subjects, {'folder', 'kind'}));
    end
    fprintf('(listed only: subjects are written with the acquisition stage)\n');
end

if any(options.Stages == "acquisition")
    fprintf('\n== stage 5: acquisition ==\n');
    if ~isfield(result, 'sessions')
        error('ndi:setup:conv:haley:needSessions', ...
            'The acquisition stage needs the sessions stage: include "sessions" in ''Stages''.');
    end
    [result.recordings, result.recordingChecks] = ndi.setup.conv.haley.recordingList( ...
        dataParentDir, result.sessions, 'ReadVideos', options.ReadVideos);
    if height(result.recordings) > 0
        disp(groupsummary(result.recordings, {'kind', 'system'}));
    end
    fprintf('(listed only: nothing written yet)\n');
end
end
