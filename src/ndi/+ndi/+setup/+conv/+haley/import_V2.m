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
%        3  sessions       one per day, part_of its study          (building)
%        4  acquisition    camera/microscope, one epoch per video  (not yet)
%        5  subjects       plates, patches, worms                  (not yet)
%        6  relations      patch on plate, worm on plate, ...      (not yet)
%        7  assertions     strain, species, exclusion tags         (not yet)
%        8  manipulations  plate preparation, food deprivation     (not yet)
%        9  observations   tracks, environment, geometry, images   (not yet)
%        10 calculations   masks, closest-patch maps               (not yet)
%     C. dataset-wide, once
%        11 encounters, 12 cross-study calculations, 13 check & write (not yet)
%
%   Nothing is written to disk yet: RESULT holds the documents each stage
%   built, as structs, for inspection.
%
%   Options:
%     'Spec'              path to the spec (default: import_V2_spec.json here)
%     'Stages'            which stages to run (default: all implemented)
%     'DatasetSessionId'  session id for dataset-level documents (default: a
%                         new id; stage 10 will take it from the dataset)
%
%   doImport.m, the original V1 import, is unchanged.
%
%   See also ndi.setup.V2.discover, ndi.setup.V2.datasetMetadata.

arguments
    dataParentDir (1,:) char {mustBeFolder} = fullfile(userpath, 'data')
    options.Spec (1,:) char = fullfile(fileparts(mfilename('fullpath')), 'import_V2_spec.json')
    options.Stages (1,:) string = ["discover", "metadata"]
    options.DatasetSessionId (1,:) char = ''
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
end
