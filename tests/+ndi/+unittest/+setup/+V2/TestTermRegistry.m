classdef TestTermRegistry < matlab.unittest.TestCase
%TESTTERMREGISTRY The Haley import writes only terms DID-schema's term registry holds.
%
%   Tenet T19 (DID-schema V_eta_term_registry_plan.md, Jess Haley 2026-10-20):
%   a term already used in an NDI dataset first, then an existing ontology,
%   then a new EMPTY term, and an unregistered term is an error in did2.build.
%   This runs the import over the fixture with that error OFF and collection
%   ON (did2.build.unregisteredTerms), so a failure lists every unregistered
%   term at once instead of stopping at the first. It needs a schema with a
%   registry (did-schema #88) and a DID-matlab that checks against it
%   (DID-matlab #218); without them each test is filtered, which
%   test-import-v2.yml counts as a failure.

    methods (Test)
        function testEveryHaleyTermIsTheRegisteredOne(testCase)
            testCase.assumeTrue(hasRegistry(), ['no term registry: needs did-schema #88 ' ...
                'and DID-matlab #218']);
            % haleyTerm's table (private to the import, read here as text)
            % names each handle's node and name; each must be a registered
            % term, exactly, so the import cannot drift from the registry
            ix = did2.schema.termIndex();
            rows = haleyTable();
            testCase.verifyGreaterThan(size(rows, 1), 100, 'the table was read');
            bad = {};
            for k = 1:size(rows, 1)
                [tf, why] = did2.schema.termRegistered(struct('node', rows{k, 2}, 'name', rows{k, 3}), ix);
                if ~tf, bad{end+1} = sprintf('%s: %s', rows{k, 1}, why); end %#ok<AGROW>
            end
            testCase.verifyEmpty(bad, strjoin(bad, newline));
        end

        function testTheImportWritesOnlyRegisteredTerms(testCase)
            testCase.assumeTrue(hasRegistry(), ['no term registry: needs did-schema #88 ' ...
                'and DID-matlab #218']);
            prev = did2.schema.cache.strictMode('TermRegistry', false);
            testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
            prevC = did2.build.unregisteredTerms('-collect', true);
            testCase.addTeardown(@() did2.build.unregisteredTerms('-collect', prevC));
            did2.build.unregisteredTerms('-reset');
            testCase.addTeardown(@() did2.build.unregisteredTerms('-reset'));
            root = tempname;
            testCase.addTeardown(@() rmdir(root, 's'));
            ndi.unittest.setup.V2.TestHaleyRecordings.writeFixture(root);
            ndi.setup.conv.haley.import_V2(root, 'Sessions', "concentration_0001", ...
                'OutputRoot', fullfile(root, 'haley_V2'), 'Write', true, ...
                'Overwrite', true, 'ReadVideos', false, 'SessionFolders', true);
            L = did2.build.unregisteredTerms();
            fprintf('UNREGISTERED TERMS: %d distinct (name, node, field)\n', numel(L));
            for k = 1:numel(L)
                fprintf('  %-45s %-20s %-45s x%d  %s\n', L(k).name, L(k).node, ...
                    L(k).field, L(k).count, L(k).reason);
            end
            testCase.verifyEmpty(L, sprintf(['%d term(s) the import writes are not in ' ...
                'DID-schema''s term registry; they are listed above'], numel(L)));
        end
    end
end

function tf = hasRegistry()
% did2.build, a schema with `entity` and a term registry, and a DID-matlab
% that checks against it
schemaPath = getenv('DID_SCHEMA_PATH');
tf = ~isempty(which('did2.build.document')) && ~isempty(schemaPath) ...
    && isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')) ...
    && ~isempty(which('did2.schema.termIndex'));
if tf
    ix = did2.schema.termIndex();
    tf = ix.present;
end
end

function rows = haleyTable()
% {handle, node, name} rows of haleyTerm's table, read from its source
file = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), 'private', 'haleyTerm.m');
tok = regexp(fileread(file), "^\s*'([^']+)',\s*'([^']+)',\s*'([^']*)'\s*$", ...
    'tokens', 'lineanchors');
rows = vertcat(tok{:});
end
