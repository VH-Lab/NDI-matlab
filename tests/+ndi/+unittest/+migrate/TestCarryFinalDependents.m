classdef TestCarryFinalDependents < matlab.unittest.TestCase
%TESTCARRYFINALDEPENDENTS The final sweep: dependents of a final carry carry too.
%
%   Decided by Jess Haley, 2026-10-26 [dependents of a carried document
%   carry] and 2026-10-27 [handed-on documents do not carry dependents]
%   (did-schema schemas/V_eta_go_forward_class_audit.md):
%   ndi.migrate.internal.carryFinalDependents carries, by its v1 source, every
%   document that is not v1 at the end and whose edge names a document that
%   is; a handed-on document the second pass converted is not v1 at the end
%   and so carries nothing.
%
%   The documents here are built as structs (no schema, no validation): the
%   sweep reads only base.id, document_class and depends_on.

    methods (Test)
        function testDependentCarriesDownTheChain(testCase)
            % elem is carried as v1; ep (converted) names elem; obs
            % (converted) names ep. Both carry, by their v1 sources.
            elem = v1Body('elem', {});
            ep = v1Body('ep', {'element_id', idOf('elem')});
            obs = v1Body('obs', {'element_epoch_id', idOf('ep')});
            docs = {stamped(elem, 'did_v1'), v2Of(ep), v2Of(obs)};
            [out, rep] = ndi.migrate.internal.carryFinalDependents(docs, ...
                {elem, ep, obs}, sourceOutputs({elem, ep, obs}, {{}, {}, {}}));
            testCase.verifyEqual(rep.documents_inspected, 3);
            testCase.verifyEqual(rep.v2_documents_inspected, 2);
            testCase.verifyEqual(rep.carried_at_start, 1);
            testCase.verifyEqual(rep.carried_by_sweep, 2);
            testCase.verifyEqual(sort({rep.carry_rows.id}), sort({idOf('ep'), idOf('obs')}));
            testCase.verifyEqual(unique({rep.carry_rows.row}), {'carry-064'});
            testCase.verifyGreaterThanOrEqual(rep.rounds, 2);
            testCase.verifyEqual(numel(out), 3);
            for k = 1:numel(out)
                testCase.verifyEqual(out{k}.toStruct().document_class.schema_version, ...
                    'did_v1', 'every document ends as its v1 source');
            end
            expected = ep;
            expected.document_class.schema_version = 'did_v1';
            testCase.verifyTrue(isequaln(findById(out, idOf('ep')).toStruct(), expected), ...
                'a carried dependent is its v1 SOURCE body stamped did_v1');
        end

        function testConvertedHandedOnDocumentCarriesNothing(testCase)
            % [handed-on documents do not carry dependents]: a presentation
            % the second pass converted (same id, now V2) is not a final
            % carry, so the response that names it stays converted.
            pres = v1Body('pres', {});
            resp = v1Body('resp', {'stimulus_presentation_id', idOf('pres')});
            docs = {v2Of(pres), v2Of(resp)};
            [out, rep] = ndi.migrate.internal.carryFinalDependents(docs, ...
                {pres, resp}, sourceOutputs({pres, resp}, {{}, {}}));
            testCase.verifyEqual(rep.carried_at_start, 0);
            testCase.verifyEqual(rep.carried_by_sweep, 0);
            testCase.verifyEqual(out{2}.toStruct().document_class.schema_version, ...
                did2.schema.v2Stamp());
        end

        function testHandedOnDocumentLeftV1CarriesItsDependents(testCase)
            % the same presentation, left as v1 by the second pass: a final
            % carry, so the response carries
            pres = v1Body('pres', {});
            resp = v1Body('resp', {'stimulus_presentation_id', idOf('pres')});
            docs = {stamped(pres, 'did_v1'), v2Of(resp)};
            [out, rep] = ndi.migrate.internal.carryFinalDependents(docs, ...
                {pres, resp}, sourceOutputs({pres, resp}, {{}, {}}));
            testCase.verifyEqual(rep.carried_by_sweep, 1);
            testCase.verifyEqual(rep.carry_rows(1).dependency, idOf('pres'));
            testCase.verifyEqual(out{2}.toStruct().document_class.schema_version, 'did_v1');
        end

        function testOtherOutputsOfACarriedSourceAreDropped(testCase)
            % subj is carried; sub (converted) minted a statement (stmt)
            % that names sub, and a method (meth) that a third document
            % (other) still names. sub carries; stmt is dropped; meth is
            % kept, because dropping it would leave other's edge to nothing.
            subj = v1Body('subj', {});
            sub = v1Body('sub', {'subject_id', idOf('subj')});
            other = v1Body('other', {'method_id', idOf('meth')});
            stmt = mintedV2('stmt', {'entity_id', idOf('sub')});
            meth = mintedV2('meth', {});
            docs = {stamped(subj, 'did_v1'), v2Of(sub), stmt, meth, v2Of(other)};
            [out, rep] = ndi.migrate.internal.carryFinalDependents(docs, ...
                {subj, sub, other}, sourceOutputs({subj, sub, other}, ...
                {{}, {idOf('stmt'), idOf('meth')}, {}}));
            testCase.verifyEqual(rep.carried_by_sweep, 1);
            testCase.verifyEqual(rep.outputs_dropped, 1);
            testCase.verifyEqual(rep.outputs_kept_referenced, 1);
            outIds = cellfun(@(d) d.toStruct().base.id, out, 'UniformOutput', false);
            testCase.verifyFalse(any(strcmp(outIds, idOf('stmt'))));
            testCase.verifyTrue(any(strcmp(outIds, idOf('meth'))));
        end

        function testMintedDocumentWithNoSourceIsCountedNotCarried(testCase)
            % a second-pass document with no v1 source naming a final carry
            % has no v1 form: left as it is, counted, with a warning
            subj = v1Body('subj', {});
            tref = mintedV2('tref', {'entity_id', idOf('subj')});
            docs = {stamped(subj, 'did_v1'), tref};
            [out, rep] = testCase.verifyWarning(@() ...
                ndi.migrate.internal.carryFinalDependents(docs, {subj}, ...
                sourceOutputs({subj}, {{}})), 'NDI:migrate:finalCarryUnattributed');
            testCase.verifyEqual(rep.left_no_source, 1);
            testCase.verifyEqual(rep.left_no_source_sample(1).id, idOf('tref'));
            testCase.verifyEqual(rep.carried_by_sweep, 0);
            testCase.verifyEqual(numel(out), 2);
        end

        function testSessionEdgeIsCountedNotFollowed(testCase)
            sess = v1Body('sess', {});
            doc = v1Body('doc', {'session_id', idOf('sess')});
            docs = {stamped(sess, 'did_v1'), v2Of(doc)};
            [out, rep] = ndi.migrate.internal.carryFinalDependents(docs, ...
                {sess, doc}, sourceOutputs({sess, doc}, {{}, {}}));
            testCase.verifyEqual(rep.session_edges_to_v1, 1);
            testCase.verifyEqual(rep.carried_by_sweep, 0);
            testCase.verifyEqual(out{2}.toStruct().document_class.schema_version, ...
                did2.schema.v2Stamp());
        end

        function testNothingCarriedReportsItsDenominators(testCase)
            a = v1Body('a', {});
            [out, rep] = ndi.migrate.internal.carryFinalDependents({v2Of(a)}, {a});
            testCase.verifyEqual(rep.documents_inspected, 1);
            testCase.verifyEqual(rep.v2_documents_inspected, 1);
            testCase.verifyEqual(rep.carried_at_start, 0);
            testCase.verifyEqual(numel(out), 1);
        end
    end
end

% ---- helpers --------------------------------------------------------------

function id = idOf(name)
id = ['aabb1122ccdd3344_' pad16(name)];
end

function s = pad16(name)
h = lower(dec2hex(double(name)))';
h = h(:)';
s = [h repmat('0', 1, 16)];
s = s(1:16);
end

function b = v1Body(name, edge)
% a did_v1 body (no stamp) with at most one depends_on edge {name, id}
b = struct();
b.document_class = struct('class_name', 'demo_a', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
if isempty(edge)
    b.depends_on = struct('name', {}, 'value', {});
else
    b.depends_on = struct('name', edge{1}, 'value', edge{2});
end
b.base = struct('id', idOf(name), 'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', name, 'datestamp', '2024-06-01T12:00:00.000Z');
b.demo_a = struct('marker', name);
end

function d = stamped(b, stamp)
b.document_class.schema_version = stamp;
d = did2.document(b);
end

function d = v2Of(b)
% the document a source became, same id, V2 stamp, edges as document_id
s = b;
s.document_class.schema_version = did2.schema.v2Stamp();
if isempty(b.depends_on)
    s.depends_on = struct('name', {}, 'document_id', {});
else
    s.depends_on = struct('name', b.depends_on(1).name, ...
        'document_id', b.depends_on(1).value);
end
d = did2.document(s);
end

function d = mintedV2(name, edge)
d = v2Of(v1Body(name, edge));
end

function so = sourceOutputs(bodies, extraOutputs)
% pass 1's source_outputs: each source became its own id plus EXTRAOUTPUTS{k}
so = struct('input_index', {}, 'id', {}, 'class_name', {}, 'done', {}, ...
    'carried', {}, 'output_ids', {});
for k = 1:numel(bodies)
    so(end+1) = struct('input_index', k, 'id', bodies{k}.base.id, ...
        'class_name', 'demo_a', 'done', true, 'carried', false, ...
        'output_ids', {[{bodies{k}.base.id}, extraOutputs{k}]}); %#ok<AGROW>
end
end

function d = findById(docs, id)
d = [];
for k = 1:numel(docs)
    if strcmp(docs{k}.toStruct().base.id, id)
        d = docs{k};
        return;
    end
end
end
