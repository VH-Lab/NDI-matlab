classdef TestMigrateSessionId < matlab.unittest.TestCase
%TESTMIGRATESESSIONID The second pass writes a session id the way the schema in use keeps it.
%
%   did-schema V_eta_relation_inheritance_plan.md (signed 2026-10-21):
%   base.session_id is no longer a field; every document carries a required
%   `session_id` edge to the session or dataset entity, whose base.id IS the
%   session id. ndi.migrate.internal.withSessionId is the one place the v1 ->
%   V_eta second pass decides which to write, from ndi.v2.sessionIdIsEdge.
%
%   Each test points DID_SCHEMA_PATH at a scratch folder holding only a
%   `base.json` -- one declaring session_id, one not -- so both branches run
%   on any CI leg and without a corpus. Pure struct logic otherwise.
%
%   Run with:  runtests('ndi.unittest.migrate.TestMigrateSessionId')
%
%   UNVERIFIED: written without MATLAB; CI is the first run.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function scratchSchema(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            prev = getenv('DID_SCHEMA_PATH');
            testCase.addTeardown(@() setenv('DID_SCHEMA_PATH', prev));
        end
    end

    methods (Test)
        function testTheFieldShapeKeepsTheField(testCase)
            useSchema(testCase, true);
            testCase.verifyFalse(ndi.v2.sessionIdIsEdge());
            b = body();
            out = ndi.migrate.internal.withSessionId(b, 'sess_2');
            testCase.verifyEqual(out.base.session_id, 'sess_2');
            testCase.verifyEqual(fieldnames(out.base), fieldnames(b.base), ...
                'the field is overwritten in place, base keeps its order');
            testCase.verifyEqual(out.depends_on, b.depends_on, 'no edge is added');
            same = ndi.migrate.internal.withSessionId(b, 'sess_1');
            testCase.verifyEqual(same, b, 'today''s body is written unchanged');
        end

        function testNoSchemaKeepsTheField(testCase)
            setenv('DID_SCHEMA_PATH', '');
            b = body();
            testCase.verifyEqual(ndi.migrate.internal.withSessionId(b, 'sess_1'), b);
        end

        function testTheEdgeShapeWritesTheEdge(testCase)
            useSchema(testCase, false);
            testCase.verifyTrue(ndi.v2.sessionIdIsEdge());
            out = ndi.migrate.internal.withSessionId(body(), 'sess_1');
            testCase.verifyFalse(isfield(out.base, 'session_id'));
            testCase.verifyEqual(ndi.v2.edgeIds(out, 'session_id'), {'sess_1'});
            testCase.verifyEqual(ndi.v2.edgeIds(out, 'subject_id'), {'animal_1'}, ...
                'the other edges stay');
            testCase.verifyEqual(ndi.v2.sessionIdOf(out), 'sess_1');
        end

        function testTheEdgeIsAddedToAnEmptyOrAbsentDependsOn(testCase)
            useSchema(testCase, false);
            b = body();
            b.depends_on = struct('name', {}, 'value', {});
            out = ndi.migrate.internal.withSessionId(b, 'sess_1');
            testCase.verifyEqual(out.depends_on, struct('name', 'session_id', 'value', 'sess_1'));
            b = rmfield(b, 'depends_on');
            out = ndi.migrate.internal.withSessionId(b, 'sess_1');
            testCase.verifyEqual(out.depends_on, struct('name', 'session_id', 'value', 'sess_1'));
        end

        function testTheEdgeIsReplacedNotRepeated(testCase)
            useSchema(testCase, false);
            out = ndi.migrate.internal.withSessionId(body(), 'sess_1');
            out = ndi.migrate.internal.withSessionId(out, 'sess_2');
            names = {out.depends_on.name};
            testCase.verifyEqual(sum(strcmp(names, 'session_id')), 1);
            testCase.verifyEqual(ndi.v2.sessionIdOf(out), 'sess_2');
        end

        function testTheEdgeTakesTheShapeOfTheBodysEdges(testCase)
            useSchema(testCase, false);
            b = body();
            b.depends_on = struct('name', {'subject_id'}, 'document_id', {'animal_1'});
            out = ndi.migrate.internal.withSessionId(b, 'sess_1');
            testCase.verifyFalse(isfield(out.depends_on, 'value'));
            testCase.verifyEqual(out.depends_on(end).document_id, 'sess_1');
        end

        function testAnEmptySessionIdWritesNoEdge(testCase)
            useSchema(testCase, false);
            b = body();
            out = ndi.migrate.internal.withSessionId(b, '');
            testCase.verifyEmpty(ndi.v2.edgeIds(out, 'session_id'));
            testCase.verifyEqual(out.depends_on, b.depends_on);
        end

        function testPathSPromotionMintsTheShapeOfTheSchema(testCase)
            for hasField = [true, false]
                useSchema(testCase, hasField);
                [~, minted, changed] = ndi.migrate.internal.pathSPromotion( ...
                    treatmentWithSite());
                testCase.verifyTrue(changed);
                testCase.verifyNumElements(minted, 3);
                for k = 1:numel(minted)
                    m = minted{k};
                    testCase.verifyEqual(ndi.v2.sessionIdOf(m), 'sess_1');
                    testCase.verifyEqual(isfield(m.base, 'session_id'), hasField);
                    testCase.verifyEqual(isempty(ndi.v2.edgeIds(m, 'session_id')), hasField);
                end
            end
        end

        function testTheEpochAnchorFoldKeepsTheSessionEdge(testCase)
            % the fold replaces depends_on; on the edge shape the session edge
            % must survive it, and the session is read from the edge
            useSchema(testCase, false);
            a = anchorDoc();
            a.base = rmfield(a.base, 'session_id');
            a.depends_on(end+1) = struct('name', 'session_id', 'value', 'sess_09');
            idx = struct('session_id', 'sess_09', 'local_identifier', 't00001', ...
                'epoch_document_id', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold({a}, idx);
            testCase.verifyEqual(report.anchors_planned, 1);
            b = plan(1).body;
            % did-schema #88: relative_time_reference names its referent by
            % `referent_id` (`relative_to` before)
            testCase.verifyEqual(ndi.v2.edgeIds(b, 'referent_id'), {'epoch_doc_A'});
            testCase.verifyEqual(ndi.v2.edgeIds(b, 'session_id'), {'sess_09'});
            testCase.verifyEmpty(ndi.v2.edgeIds(b, 'element_id'));
            testCase.verifyFalse(isfield(b.base, 'session_id'));

            % the field shape: exactly as before, the one relative_to edge
            useSchema(testCase, true);
            [plan, ~] = ndi.migrate.internal.epochAnchorFold({anchorDoc()}, idx);
            b = plan(1).body;
            testCase.verifyEqual(b.depends_on, ...
                struct('name', 'referent_id', 'value', 'epoch_doc_A'));
            testCase.verifyEqual(b.base.session_id, 'sess_09');
        end
    end
end

% ===================== fixtures ==========================================

function useSchema(testCase, hasSessionIdField)
%USESCHEMA Point DID_SCHEMA_PATH at a fresh folder whose base.json does or
%   does not declare session_id.
[~, u] = fileparts(tempname);
d = fullfile(testCase.Dir, sprintf('schema_%d_%s', hasSessionIdField, u));
mkdir(d);
fields = {struct('name', 'id'), struct('name', 'name'), ...
    struct('name', 'creation_timestamp')};
if hasSessionIdField
    fields = [fields(1), {struct('name', 'session_id')}, fields(2:end)];
end
schema = struct('classname', 'base', 'fields', {fields});
fid = fopen(fullfile(d, 'base.json'), 'w');
fwrite(fid, jsonencode(schema));
fclose(fid);
setenv('DID_SCHEMA_PATH', d);
end

function b = body()
b = struct();
b.document_class = struct('class_name', 'term_observation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_observation', 'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
b.depends_on = struct('name', {'subject_id'}, 'value', {'animal_1'});
b.base = struct('id', 'doc_1', 'session_id', 'sess_1', 'name', 'n', ...
    'creation_timestamp', '2024-01-01T00:00:00.000Z');
end

function s = treatmentWithSite()
% the attributed-site fixture of TestPathSPromotion, reduced to one site
manip = struct();
manip.document_class = dc('dose_manipulation', {'subject_manipulation', 'dose'});
manip.depends_on = [dep('subject_id', 'animal_1'), dep('time_reference_1', 'anch_1')];
manip.base = base('manip_1');
manip.subject_statement = struct('variable', term('chebi:1', 'muscimol'), ...
    'storage_mode', 'inline');
manip.subject_interaction = struct('method', term('', ''), ...
    'sample_time', struct('kind', 'point'));
manip.subject_manipulation = struct('notes', '');
manip.dose = struct('value', struct());

site = struct();
site.document_class = dc('term_observation', {'subject_observation'});
site.depends_on = [dep('subject_id', 'animal_1'), dep('time_reference_1', 'anch_1')];
site.base = base('site_1');
site.subject_statement = struct('variable', term('', 'anatomical location'), ...
    'storage_mode', 'inline');
site.subject_interaction = struct('method', term('', ''), ...
    'sample_time', struct('kind', 'point'));
site.subject_observation = struct();
site.term = struct('value', term('uberon:0002436', 'primary visual cortex'));

anchor = struct();
anchor.document_class = dc('session_relative_reference', {'time_reference'});
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = base('anch_1');
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');
s = {manip, site, anchor};
end

function b = anchorDoc()
% the body stimulusBathToBath mints under V_eta (TestEpochAnchorFold's fixture)
b = struct();
b.document_class = struct( ...
    'class_name', 'epoch_bounded_reference', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
        struct('class_name', 'epochid',        'class_version', '1.0.0')], ...
    'schema_version', 'did_v2');
b.depends_on = struct('name', 'element_id', 'value', 'stim_1');
b.base = struct('id', 'anchor_1', 'session_id', 'sess_09', ...
    'name', 'migrated_stimulator_epoch_anchor', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
b.time_reference = struct('is_approximate', false);
b.epochid = struct('epochid', 't00001');
b.epoch_bounded_reference = struct('epoch_clock', 'dev_local_time');
end

function x = dc(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
x = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'did_v2');
end

function x = dep(name, value)
x = struct('name', name, 'value', value);
end

function x = base(id)
x = struct('id', id, 'session_id', 'sess_1', 'name', 'n', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
end

function x = term(node, name)
x = struct('node', node, 'name', name);
end
