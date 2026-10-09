function R = v2_import_profile(dataParentDir, options)
%V2_IMPORT_PROFILE Where the time goes when the Haley V2 import runs one session.
%
%   R = v2_import_profile(DATAPARENTDIR) runs ndi.setup.conv.haley.import_V2
%   on one session ('Sessions', default concentration_0001), every stage,
%   'Write' true, into a FRESH output folder under tempdir (your real
%   haley_V2 is not touched), under the MATLAB profiler. It prints:
%
%     - the wall-clock time;
%     - self time grouped by where it is spent: the schema cache, did2.build
%       (making documents), the database and mksqlite (writing), the rest of
%       did2, the Haley import's own code, the rest of NDI, reading files,
%       MATLAB itself;
%     - the 30 functions with the most self time.
%
%   R has the numbers and is saved to <OutputRoot>/import_profile.mat.
%   Run it once per DID-matlab version and pass the earlier .mat as
%   'Compare' to print the two side by side, e.g.
%
%     a = v2_import_profile(d, 'Label', 'V2');                  % DID-matlab V2
%     % ... check out the #218 branch, clear classes, set the path again ...
%     b = v2_import_profile(d, 'Label', '218', 'Compare', a.matFile);
%
%   Options:
%     'Sessions'   default "concentration_0001"
%     'Label'      a name for this run (default 'run'), part of the folder
%     'Checksums'  default false, as in the full run
%     'ReadVideos' default true (import_V2's default)
%     'Compare'    a .mat saved by an earlier call
%
%   The profiler slows MATLAB down (it roughly doubled the read profiled
%   earlier), so read the groups as shares, and the wall clock as an upper
%   bound.
%
%   See also ndi.setup.conv.haley.import_V2, v2_subject_listing_profile.

arguments
    dataParentDir (1,:) char {mustBeFolder}
    options.Sessions (1,:) string = "concentration_0001"
    options.Label (1,:) char = 'run'
    options.Checksums (1,1) logical = false
    options.ReadVideos (1,1) logical = true
    options.Compare (1,:) char = ''
end

out = fullfile(tempdir, ['haley_V2_profile_' options.Label]);
if isfolder(out), rmdir(out, 's'); end
mkdir(out);
fprintf('import of %s into %s (fresh)\nDID-matlab: %s\n', strjoin(options.Sessions, ', '), out, ...
    fileparts(fileparts(fileparts(which('did2.schema.cache')))));

profile clear; profile on;
t0 = tic;
r = ndi.setup.conv.haley.import_V2(dataParentDir, 'Sessions', options.Sessions, ...
    'OutputRoot', out, 'Write', true, 'Overwrite', true, ...
    'Checksums', options.Checksums, 'ReadVideos', options.ReadVideos);
wall = toc(t0);
profile off;
info = profile('info');
ft = info.FunctionTable;

self = arrayfun(@(f) f.TotalTime - sum([f.Children.TotalTime]), ft);
names = string({ft.FunctionName})';
files = string({ft.FileName})';
group = strings(numel(names), 1);
for k = 1:numel(names), group(k) = groupOf(names(k), files(k)); end

[g, ~, j] = unique(group);
selfByGroup = accumarray(j, self(:));
G = table(g, selfByGroup, selfByGroup / sum(self), 'VariableNames', {'group', 'self_s', 'share'});
G = sortrows(G, 'self_s', 'descend');

F = table(names, group, self(:), [ft.TotalTime]', [ft.NumCalls]', ...
    'VariableNames', {'fn', 'group', 'self_s', 'total_s', 'calls'});
F = sortrows(F, 'self_s', 'descend');

nDocs = NaN;
try nDocs = sum(r.dataset.report.documents.byClass.GroupCount); catch, end
fprintf('\n== wall clock (under the profiler) ==\n  %.1f s for %s; %g document(s) in the dataset\n', ...
    wall, strjoin(options.Sessions, ', '), nDocs);
fprintf('\n== self time by group ==\n');
disp(G);
fprintf('\n== top 30 functions by self time ==\n');
disp(F(1:min(30, height(F)), :));

R = struct('label', options.Label, 'sessions', options.Sessions, 'wall', wall, ...
    'documents', nDocs, 'groups', G, 'functions', F, 'outputRoot', out, ...
    'matFile', fullfile(out, 'import_profile.mat'));
save(R.matFile, 'R');
fprintf('saved %s\n', R.matFile);

if ~isempty(options.Compare)
    A = load(options.Compare);
    A = A.R;
    fprintf('\n== %s vs %s ==\n  wall: %.1f s vs %.1f s\n', A.label, R.label, A.wall, R.wall);
    C = outerjoin(A.groups(:, {'group', 'self_s'}), R.groups(:, {'group', 'self_s'}), ...
        'Keys', 'group', 'MergeKeys', true);
    C.Properties.VariableNames = {'group', A.label, R.label};
    disp(C);
end
end

function g = groupOf(name, file)
f = replace(file, '\', '/');
if contains(f, '/+did2/+schema/')
    g = "schema cache";
elseif contains(f, '/+did2/+build/')
    g = "did2.build (making documents)";
elseif contains(f, '/+did2/+database/') || startsWith(name, "mksqlite")
    g = "database + mksqlite (writing)";
elseif contains(f, '/+did2/')
    g = "did2, other";
elseif contains(f, '/+haley/') || contains(f, '/+setup/+V2/')
    g = "Haley import";
elseif contains(f, '/+ndi/')
    g = "NDI, other";
elseif any(startsWith(name, ["readtable", "readmatrix", "readcell", "load", "fread", "fopen", ...
        "imread", "imfinfo", "VideoReader", "read", "h5read", "xlsread", "fileread", "jsondecode", ...
        "dir", "exist", "isfile", "isfolder"]))
    g = "reading files";
else
    g = "MATLAB, other";
end
end
