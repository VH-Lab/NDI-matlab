classdef TestSoftwareDedup < matlab.unittest.TestCase
%TESTSOFTWAREDEDUP Unit tests for the V_eta `software` dedup second pass (pure
%   struct logic; no database, schema, or MATLAB toolbox needed).
%
%   ndi.migrate.internal.softwareDedup merges the duplicate `software` ENTITIES
%   that pass 1 cannot avoid minting -- a single-document migrator sees one
%   source document and cannot know another already minted the same program --
%   and retargets every edge that pointed at the ones removed. Merge key is
%   (base.session_id, software.name, software.version), which is the key the
%   sign-off names plus the session scope base.session_id forces.
%
%   ---------------------------------------------------------------------
%   STATUS: NOT VERIFIED BY EXECUTION
%   ---------------------------------------------------------------------
%   There is no MATLAB in the authoring environment, so no test in this file
%   has ever been run. Every assertion below is derived from reading the code
%   and the schemas, not from a green result.
%
%   ---------------------------------------------------------------------
%   WHAT THESE FIXTURES ARE BUILT FROM
%   ---------------------------------------------------------------------
%   The shapes come from the DID-side minters, not from a DID schema:
%     - `software` body:  did-matlab +did2/+convert/+migrators_j/private/
%                         jSoftware.m (document_class + base + entity.
%                         global_identifier + software{name,version,
%                         local_identifier})
%     - `software_id` edge on a calculator leaf: private/jCalculation.m
%     - `reader_id` edge:  migrators_j/daqsystem.m, whose target is the
%                          `software` that migrators_j/daqreader.m produced
%                          WITH THE v1 ID PRESERVED. That id preservation is
%                          the whole reason the pinning rule exists, so it is
%                          reproduced here rather than paraphrased.
%
%   Run with:  runtests('ndi.unittest.migrate.TestSoftwareDedup')
%
%   Fixtures/accessors are LOCAL FUNCTIONS below the classdef -- the same
%   arrangement TestPathSPromotion had to adopt after class-qualified static
%   helpers failed to resolve inside the package.

    methods (Test)

        % ============================================================ merging

        function testTwoMintsOfOneProgramCollapseToOne(testCase)
            % The headline case: two calculator outputs in one session naming
            % ndi.calc.vis.oridir @ 1.2 mint two identical entities in pass 1.
            structs = [ ...
                {softwareBody('sw_a', 'sess_1', 'ndi.calc.vis.oridir', '1.2', '')}, ...
                {softwareBody('sw_b', 'sess_1', 'ndi.calc.vis.oridir', '1.2', '')}, ...
                {leafBody('leaf_a', 'sess_1', 'sw_a')}, ...
                {leafBody('leaf_b', 'sess_1', 'sw_b')}];

            [kept, report] = ndi.migrate.internal.softwareDedup(structs);

            testCase.verifyTrue(report.changed);
            testCase.verifyEqual(report.documents_inspected, 4);
            testCase.verifyEqual(report.software_seen, 2);
            testCase.verifyEqual(report.merge_groups, 1);
            testCase.verifyEqual(report.software_merged_away, 1);
            testCase.verifyEqual(report.software_surviving, 1);
            testCase.verifyEqual(numel(kept), 3);

            % ONE survivor, and BOTH leaves point at it.
            sw = allOfClass(kept, 'software');
            testCase.verifyEqual(numel(sw), 1);
            survivorId = sw{1}.base.id;
            testCase.verifyEqual(depValue(firstWithId(kept, 'leaf_a'), 'software_id'), ...
                survivorId);
            testCase.verifyEqual(depValue(firstWithId(kept, 'leaf_b'), 'software_id'), ...
                survivorId);
            % exactly one edge had to move
            testCase.verifyEqual(report.edges_retargeted, 1);
        end

        function testSurvivorIsDeterministicNotOrderDependent(testCase)
            % Migration output must not depend on the order documents came out
            % of a database. Same three bodies, reversed, must give the same
            % survivor.
            a = softwareBody('sw_zzz', 'sess_1', 'prog', '1', '');
            b = softwareBody('sw_aaa', 'sess_1', 'prog', '1', '');
            fwd = ndi.migrate.internal.softwareDedup({a, b});
            rev = ndi.migrate.internal.softwareDedup({b, a});
            testCase.verifyEqual(idOfClass(fwd, 'software'), 'sw_aaa');
            testCase.verifyEqual(idOfClass(rev, 'software'), 'sw_aaa');
        end

        function testDifferentVersionsDoNotMerge(testCase)
            % version is HALF the key. Two releases of one program are two
            % pieces of software.
            structs = { ...
                softwareBody('sw_a', 'sess_1', 'ndi.calc.vis.oridir', '1.2', ''), ...
                softwareBody('sw_b', 'sess_1', 'ndi.calc.vis.oridir', '1.3', '')};
            [kept, report] = ndi.migrate.internal.softwareDedup(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(report.software_merged_away, 0);
            testCase.verifyEqual(numel(allOfClass(kept, 'software')), 2);
        end

        function testDifferentSessionsDoNotMergeButAreCounted(testCase)
            % base.session_id is "mustBeNonEmpty" on `base`, so a survivor
            % carries exactly ONE session; merging across sessions would stamp
            % documents in session B with an entity belonging to session A.
            % That is a modelling call, so the pass MEASURES it instead.
            structs = { ...
                softwareBody('sw_a', 'sess_1', 'ndi.calc.vis.oridir', '1.2', ''), ...
                softwareBody('sw_b', 'sess_2', 'ndi.calc.vis.oridir', '1.2', '')};
            [kept, report] = ndi.migrate.internal.softwareDedup(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(numel(allOfClass(kept, 'software')), 2);
            % the measurement, which is the point of the test
            testCase.verifyEqual(report.cross_session_groups, 1);
            testCase.verifyEqual(report.cross_session_collapsible, 1);
        end

        function testNamelessSoftwareNeverMerges(testCase)
            % "Both nameless" is not evidence of being the same program.
            structs = { ...
                softwareBody('sw_a', 'sess_1', '', '', ''), ...
                softwareBody('sw_b', 'sess_1', '', '', '')};
            [kept, report] = ndi.migrate.internal.softwareDedup(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(report.unnamed_seen, 2);
            testCase.verifyEqual(numel(allOfClass(kept, 'software')), 2);
        end

        % ======================================================== retargeting

        function testRetargetsAnEdgeThatIsNotCalledSoftwareId(testCase)
            % THE REASON RETARGETING IS BY TARGET ID. Seven V_eta edges declare
            % must_refer_to_document_class == "software" and one of them is
            % `acquisition_system.reader_id` (did_v1 daqreader dissolves into a
            % software entity). A name-based sweep would have skipped it and
            % left a dangling reference.
            structs = { ...
                softwareBody('sw_a', 'sess_1', 'ndi.daq.reader.mfdaq.intan', '', ''), ...
                softwareBody('sw_b', 'sess_1', 'ndi.daq.reader.mfdaq.intan', '', ''), ...
                acquisitionSystemBody('sys_1', 'sess_1', 'sw_b')};

            [kept, report] = ndi.migrate.internal.softwareDedup(structs);

            testCase.verifyTrue(report.changed);
            % sw_b is PINNED (an inbound edge that is not software_id), so it
            % survives and sw_a is the one merged away.
            testCase.verifyEqual(report.software_pinned, 1);
            testCase.verifyEqual(idOfClass(kept, 'software'), 'sw_b');
            testCase.verifyEqual( ...
                depValue(firstWithId(kept, 'sys_1'), 'reader_id'), 'sw_b');
            % nothing had to move -- the pinned entity was already the target
            testCase.verifyEqual(report.edges_retargeted, 0);
        end

        function testPinnedEntityIsNeverMergedAway(testCase)
            % An id-preserved entity (daqreader.m keeps the v1 document id
            % deliberately) may be referred to by means this pass cannot see --
            % CLAUDE.md: "a `depends_on` sweep is not a reference check ... grep
            % for the NAME too". So a pinned entity is always the survivor,
            % whatever its id sorts as. Here the pinned id sorts LAST, which is
            % what would break a naive smallest-id rule.
            structs = { ...
                softwareBody('sw_aaa', 'sess_1', 'prog', '', ''), ...
                softwareBody('sw_zzz', 'sess_1', 'prog', '', ''), ...
                acquisitionSystemBody('sys_1', 'sess_1', 'sw_zzz')};
            [kept, report] = ndi.migrate.internal.softwareDedup(structs);
            testCase.verifyTrue(report.changed);
            testCase.verifyEqual(idOfClass(kept, 'software'), 'sw_zzz');
            testCase.verifyEqual(report.software_merged_away, 1);
        end

        function testTwoPinnedEntitiesOnOneKeyAreLeftAlone(testCase)
            % Both ids are load-bearing and this pass cannot decide which one to
            % destroy. Report the collision; change nothing.
            structs = { ...
                softwareBody('sw_a', 'sess_1', 'prog', '', ''), ...
                softwareBody('sw_b', 'sess_1', 'prog', '', ''), ...
                acquisitionSystemBody('sys_1', 'sess_1', 'sw_a'), ...
                acquisitionSystemBody('sys_2', 'sess_1', 'sw_b')};
            [kept, report] = ndi.migrate.internal.softwareDedup(structs);
            testCase.verifyFalse(report.changed);
            testCase.verifyEqual(report.software_pinned, 2);
            testCase.verifyEqual(report.pinned_key_collisions, 1);
            testCase.verifyEqual(report.merge_groups, 0);
            testCase.verifyEqual(numel(allOfClass(kept, 'software')), 2);
        end

        function testRetargetsAnEdgeSpelledDocumentId(testCase)
            % Both spellings are live on this path: a body a migrator built
            % carries `value`, a body that came through
            % did2.convert.universalRenames carries `document_id`. Rewriting the
            % wrong one leaves the edge silently unchanged.
            leaf = leafBody('leaf_a', 'sess_1', 'sw_b');
            leaf.depends_on = struct('name', 'software_id', 'document_id', 'sw_b');
            structs = { ...
                softwareBody('sw_a', 'sess_1', 'prog', '1', ''), ...
                softwareBody('sw_b', 'sess_1', 'prog', '1', ''), ...
                leaf};
            [kept, report] = ndi.migrate.internal.softwareDedup(structs);
            testCase.verifyTrue(report.changed);
            testCase.verifyEqual(report.edges_retargeted, 1);
            k = firstWithId(kept, 'leaf_a');
            testCase.verifyEqual(k.depends_on(1).document_id, 'sw_a');
        end

        % ================================================= survivor repair

        function testSurvivorGetsTheDedupHandleRepaired(testCase)
            % local_identifier is a CONVENIENCE, not the key -- and it was
            % missing from two of the three pass-1 minters until the 2026-08-10
            % consolidation. The survivor's handle is recomposed from the merge
            % key so a corpus migrated before that consolidation still ends up
            % consistent.
            a = softwareBody('sw_a', 'sess_1', 'prog', '1.2', '');
            a.software = rmfield(a.software, 'local_identifier');
            b = softwareBody('sw_b', 'sess_1', 'prog', '1.2', '');
            b.software = rmfield(b.software, 'local_identifier');
            [kept, report] = ndi.migrate.internal.softwareDedup({a, b});
            sw = firstOfClass(kept, 'software');
            testCase.verifyEqual(sw.software.local_identifier, 'prog@1.2');
            testCase.verifyEqual(report.local_identifier_repaired, 1);
        end

        function testGlobalIdentifiersAreUnionedNotDropped(testCase)
            % Two mints of one program can carry different URLs (a homepage from
            % one app block, a repository from another). Both are facts about
            % the same software; keeping only the survivor's would be silent
            % loss, and re-deriving one would be invention.
            a = softwareBody('sw_a', 'sess_1', 'prog', '1', 'https://a.example');
            b = softwareBody('sw_b', 'sess_1', 'prog', '1', 'https://b.example');
            kept = ndi.migrate.internal.softwareDedup({a, b});
            sw = firstOfClass(kept, 'software');
            vals = sort({sw.entity.global_identifier.value});
            testCase.verifyEqual(vals, {'https://a.example', 'https://b.example'});
        end

        function testIdenticalGlobalIdentifiersCollapse(testCase)
            a = softwareBody('sw_a', 'sess_1', 'prog', '1', 'https://a.example');
            b = softwareBody('sw_b', 'sess_1', 'prog', '1', 'https://a.example');
            kept = ndi.migrate.internal.softwareDedup({a, b});
            sw = firstOfClass(kept, 'software');
            testCase.verifyEqual(numel(sw.entity.global_identifier), 1);
        end

        % ================================================== the instrument

        function testReportCarriesItsDenominatorEvenWhenNothingMatched(testCase)
            % Operating rule 5. A body set with no `software` at all must still
            % report how much it read, so "found nothing" and "read nothing" are
            % distinguishable from the report alone.
            structs = {leafBody('leaf_a', 'sess_1', 'sw_missing')};
            [~, report] = ndi.migrate.internal.softwareDedup(structs);
            testCase.verifyEqual(report.documents_inspected, 1);
            testCase.verifyEqual(report.software_seen, 0);
            % AND the edge denominator, which is the half that is easy to get
            % wrong: the edge walk has to run BEFORE the no-software early
            % return, or "looked at everything, matched nothing" reports the
            % same 0 as "looked at nothing".
            testCase.verifyEqual(report.edges_examined, 1);
            testCase.verifyFalse(report.changed);
        end

        function testEmptyInputStillReportsAZeroDenominator(testCase)
            [kept, report] = ndi.migrate.internal.softwareDedup({});
            testCase.verifyEmpty(kept);
            testCase.verifyEqual(report.documents_inspected, 0);
            testCase.verifyFalse(report.changed);
        end

        function testEdgesExaminedCountsEveryEdgeNotJustSoftwareOnes(testCase)
            % edges_examined is the denominator for edges_retargeted, so it has
            % to be the count of edges LOOKED AT, not of edges that matched.
            leaf = leafBody('leaf_a', 'sess_1', 'sw_a');
            leaf.depends_on(end+1) = struct('name', 'subject_id', 'value', 'subj_1');
            structs = { ...
                softwareBody('sw_a', 'sess_1', 'prog', '1', ''), ...
                leaf};
            [~, report] = ndi.migrate.internal.softwareDedup(structs);
            testCase.verifyEqual(report.edges_examined, 2);
        end

    end
end

% ===================== fixtures ==========================================

function s = softwareBody(id, sessionId, name, version, url)
%SOFTWAREBODY The shape private/jSoftware.m emits.
gids = struct('scheme', {}, 'value', {});
if ~isempty(url)
    gids(end+1) = struct('scheme', 'URL', 'value', url);
end
localId = name;
if ~isempty(version)
    localId = [name '@' version];
end
s = struct();
s.document_class = struct('class_name', 'software', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
s.depends_on = struct('name', {}, 'value', {});
s.base = struct('id', id, 'session_id', sessionId, 'name', name, ...
    'datestamp', '2024-01-01T00:00:00.000Z');
s.entity = struct('global_identifier', {gids});
s.software = struct('name', name, 'version', version, ...
    'local_identifier', localId);
end

function s = leafBody(id, sessionId, softwareId)
%LEAFBODY A calculator leaf carrying the `software_id` edge jCalculation writes.
s = struct();
s.document_class = struct('class_name', 'tuning_curve_calculation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_calculation', ...
        'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
s.depends_on = struct('name', 'software_id', 'value', softwareId);
s.base = struct('id', id, 'session_id', sessionId, 'name', 'leaf', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
end

function s = acquisitionSystemBody(id, sessionId, readerId)
%ACQUISITIONSYSTEMBODY The `reader_id` edge migrators_j/daqsystem.m writes.
%   Its target is the `software` migrators_j/daqreader.m produced WITH THE v1
%   ID PRESERVED -- the case the pinning rule exists for.
s = struct();
s.document_class = struct('class_name', 'acquisition_system', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
s.depends_on = struct('name', 'reader_id', 'value', readerId);
s.base = struct('id', id, 'session_id', sessionId, 'name', 'rig', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
s.entity = struct('global_identifier', {struct('scheme', {}, 'value', {})});
s.acquisition_system = struct();
end

% ===================== accessors =========================================

function out = allOfClass(bodies, className)
out = {};
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        out{end+1} = bodies{k}; %#ok<AGROW>
    end
end
end

function b = firstOfClass(bodies, className)
b = [];
for k = 1:numel(bodies)
    if strcmp(bodies{k}.document_class.class_name, className)
        b = bodies{k}; return;
    end
end
end

function id = idOfClass(bodies, className)
b = firstOfClass(bodies, className);
assert(~isempty(b), 'no %s body survived', className);
id = b.base.id;
end

function b = firstWithId(bodies, id)
b = [];
for k = 1:numel(bodies)
    if strcmp(bodies{k}.base.id, id)
        b = bodies{k}; return;
    end
end
end

function v = depValue(s, name)
%DEPVALUE Read an edge accepting BOTH live spellings (`value` from a body a
%   migrator built, `document_id` after did2.convert.universalRenames).
v = '';
if ~isstruct(s) || ~isfield(s, 'depends_on') || ~isstruct(s.depends_on)
    return;
end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(d.name, name)
        continue;
    end
    for key = {'document_id', 'value', 'id'}
        f = key{1};
        if isfield(d, f) && ~isempty(d.(f))
            v = char(d.(f)); return;
        end
    end
end
end
