classdef TestEnsembleMembers < matlab.unittest.TestCase
%TESTENSEMBLEMEMBERS ndi.vintage.ensembleMembers: a migrated ensemble's roster
%   for one epoch, in column order, from the epoch-scoped member_of edges the
%   dissolved map became (Decided by Jess Haley, 2026-10-22 [ensemble
%   retired]); the edge shape is ndi.migrate.internal.ensembleMembership's.

    methods (Test)
        function testTheRosterComesBackInColumnOrderForItsEpoch(testCase)
            rels = {rel('nrn_b', 1, 'ep_a'), rel('nrn_a', 0, 'ep_a'), rel('nrn_c', 0, 'ep_b')};
            ids = ndi.vintage.ensembleMembers(rels, @(id) epochEntityById(id), 't00001');
            testCase.verifyEqual(ids, {'nrn_a', 'nrn_b'});
            ids = ndi.vintage.ensembleMembers(rels, @(id) epochEntityById(id), 't00002');
            testCase.verifyEqual(ids, {'nrn_c'});
        end

        function testTheOntologyLabelNameIsAlsoMemberOf(testCase)
            r = rel('nrn_a', 0, 'ep_a');
            r.directed_relation.relation = struct('node', '', 'name', 'member of');
            testCase.verifyEqual(ndi.vintage.ensembleMembers({r}, @(id) epochEntityById(id), 't00001'), {'nrn_a'});
        end

        function testAnotherRelationIsNotAMember(testCase)
            r = rel('nrn_a', 0, 'ep_a');
            r.directed_relation.relation = struct('node', 'RO:0001000', 'name', 'derived_from');
            testCase.verifyEmpty(ndi.vintage.ensembleMembers({r}, @(id) epochEntityById(id), 't00001'));
        end
    end
end

function r = rel(child, order, epochDoc)
r = struct();
r.document_class = struct('class_name', 'directed_relation');
r.base = struct('id', ['r_' child]);
r.depends_on = [struct('name', 'child_id', 'value', child), ...
    struct('name', 'parent_id', 'value', 'ens_1'), ...
    struct('name', 'epoch_id', 'value', epochDoc)];
r.directed_relation = struct('relation', struct('node', 'RO:0002350', 'name', 'member_of'), ...
    'order', order);
end

function p = epochEntityById(id)
p = [];
switch id
    case 'ep_a'
        p = struct('entity', struct('local_identifier', 't00001'));
    case 'ep_b'
        p = struct('entity', struct('local_identifier', 't00002'));
end
end
