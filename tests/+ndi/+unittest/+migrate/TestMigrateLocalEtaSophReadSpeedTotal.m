classdef TestMigrateLocalEtaSophReadSpeedTotal < matlab.unittest.TestCase
%TESTMIGRATELOCALETASOPHREADSPEEDTOTAL Soph's read-speed check, over the whole corpus.
%
%   did-schema did_v2_go_forward_class_audit.md [read speed margin] (Jess
%   Haley, 2026-11-06) and [read speed check after getprobes] (2026-11-19;
%   VH-Lab/NDI-matlab#1266): every read step on every corpus inside
%   1.10 x v1 + 1 s, summed over the corpus's sessions.
%
%   Reads the report every shard job of test-eta-read-speed-soph.yml wrote
%   (TestMigrateLocalEtaSophReadSpeed), and runs
%   ndi.unittest.migrate.verifyReadPhases, the check B and Dab run, on the
%   phases summed over every session of every shard.
%
%   DENOMINATORS FIRST, and each one asserted: the number of reports equals
%   the shard count every report names, each shard index appears once, the
%   shards' documents add up to the corpus, and no session is read twice. A
%   missing shard fails; it never shrinks the corpus.
%
%   Environment: NDI_SOPH_READ_SPEED_REPORTS, the folder holding the shard
%   reports (*.json). SKIPS when it is unset.

    properties
        Reports
    end

    methods (TestClassSetup)
        function readReports(testCase)
            d = char(getenv('NDI_SOPH_READ_SPEED_REPORTS'));
            if isempty(d)
                assumeFail(testCase, 'NDI_SOPH_READ_SPEED_REPORTS unset; skipping.');
            end
            files = dir(fullfile(d, '**', '*.json'));
            testCase.Reports = cell(1, numel(files));
            for k = 1:numel(files)
                testCase.Reports{k} = jsondecode(fileread(fullfile(files(k).folder, files(k).name)));
            end
            fprintf('  [Soph read speed total] %d shard report(s) under %s\n', numel(files), d);
        end
    end

    methods (Test)

        function testReadPhasesAreNoSlowerThanV1(testCase)
            R = testCase.Reports;
            testCase.assertNotEmpty(R, 'no shard report to read');
            n = R{1}.shard_count;
            idx = cellfun(@(r) r.shard_index, R);
            fprintf('  shards reporting: %s of %d\n', mat2str(sort(idx)), n);
            testCase.assertEqual(sort(idx), 0:n-1, ...
                'the shard reports are not exactly one per shard');
            testCase.assertTrue(all(cellfun(@(r) r.shard_count == n, R)), ...
                'the shard reports name different shard counts');
            inCorpus = R{1}.docs_in_corpus;
            testCase.assertTrue(all(cellfun(@(r) r.docs_in_corpus == inCorpus, R)), ...
                'the shard reports name different corpora');
            kept = sum(cellfun(@(r) r.docs_kept, R));
            fprintf('  documents: %d in the shards, %d in the corpus\n', kept, inCorpus);
            testCase.assertEqual(kept, inCorpus, ...
                'the shards do not add up to the corpus');

            PH = reshape(cellstr(R{1}.phases), 1, []);
            T = struct('label', 'Soph', 'phases', {PH}, 'sessions', struct('id', {}, ...
                'reference', {}, 'v1', {}, 'v2', {}, 'counts', {}, 'errors', {}), ...
                'v1', zeroPhases(PH), 'v2', zeroPhases(PH));
            for k = 1:numel(R)
                S = R{k}.sessions;
                if isstruct(S); S = num2cell(S); end
                for i = 1:numel(S)
                    s = S{i};
                    rec = struct('id', s.id, 'reference', s.reference, ...
                        'v1', phaseSeconds(s.v1, PH), 'v2', phaseSeconds(s.v2, PH), ...
                        'counts', s.counts, 'errors', {textList(s.errors)});
                    T.sessions(end+1) = rec;
                    for p = 1:numel(PH)
                        T.v1.(PH{p}) = T.v1.(PH{p}) + rec.v1.(PH{p});
                        T.v2.(PH{p}) = T.v2.(PH{p}) + rec.v2.(PH{p});
                    end
                end
            end
            ids = {T.sessions.id};
            testCase.assertEqual(numel(unique(ids)), numel(ids), ...
                'a session was read in more than one shard');

            fprintf('\n  READ PHASES, v1 against v2 (Soph, %d shard(s)): %d session(s)\n', ...
                n, numel(T.sessions));
            fprintf('    %-16s %12s %12s %10s\n', 'phase', 'v1 (s)', 'v2 (s)', 'v2/v1');
            for p = 1:numel(PH)
                a = T.v1.(PH{p}); b = T.v2.(PH{p});
                fprintf('    %-16s %12.1f %12.1f %10.2f\n', PH{p}, a, b, b / max(a, eps));
            end
            ndi.unittest.migrate.verifyReadPhases(testCase, T);
        end

    end
end

function z = zeroPhases(PH)
z = struct();
for p = 1:numel(PH)
    z.(PH{p}) = 0;
end
end

function t = phaseSeconds(x, PH)
% a phase written as null (it raised) reads back empty: NaN, never 0
t = struct();
for p = 1:numel(PH)
    v = [];
    if isfield(x, PH{p}); v = x.(PH{p}); end
    if isempty(v); v = NaN; end
    t.(PH{p}) = double(v);
end
end

function c = textList(x)
% the errors list as written: [] (none), one text, or several
if isempty(x)
    c = {};
elseif ischar(x) || isstring(x)
    c = cellstr(x);
else
    c = reshape(cellstr(x), 1, []);
end
c = reshape(c, 1, []);
end
