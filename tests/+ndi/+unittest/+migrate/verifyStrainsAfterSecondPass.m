function [C, R] = verifyStrainsAfterSecondPass(testCase, result, v1Bodies, dstBodies, label)
%VERIFYSTRAINSAFTERSECONDPASS The strain entities a migrated corpus ends with, and their fields against v1.
%
%   [C, R] = ndi.unittest.migrate.verifyStrainsAfterSecondPass(TESTCASE, ...
%       RESULT, V1BODIES, DSTBODIES, LABEL) checks two decisions of Jess
%   Haley, 2026-11-19 (did-schema did_v2_go_forward_class_audit.md), on the
%   final destination bodies DSTBODIES of a run of ndi.migrate.local whose
%   result is RESULT and whose v1 input is V1BODIES (structs or JSON text):
%
%   [openMINDS minted ids are an accepted loss] / [lab-made strain ids are an
%   accepted loss too] -- C, ndi.unittest.migrate.strainEntityCensus:
%     CHECKED  there is at least one strain entity (the denominator);
%              one strain entity per (home session, name) among the strains
%              an `instance_of` points at;
%              no subject has more than one `instance_of` to a strain, and no
%              subject is an instance of two strain entities;
%              no `openminds:` entry on any strain entity's global_identifier.
%     REPORTED the number of subject-strain names and the other strain
%              entities (a dataset-level bacterium, an ancestor), by name.
%
%   [strain fields checked after the second pass] -- R,
%   RESULT.secondPass.strainFields (ndi.migrate.internal.strainFieldsAfterSecondPass):
%     CHECKED  the step ran; its denominator is the number of v1 openMINDS
%              Strain documents counted here by decoding V1BODIES; the
%              mapping partitions it; every v1 Strain is carried by a strain
%              entity (none unmapped or ambiguous); per field
%              compared = equal + differ, nothing differs, and no strain
%              entity has a value its v1 Strain does not; every
%              `openminds_<n>` child edge is carried by a field.

arguments
    testCase
    result struct
    v1Bodies cell
    dstBodies cell
    label (1,:) char
end

% ---- the census ---------------------------------------------------------------
C = ndi.unittest.migrate.strainEntityCensus(dstBodies, label);
fprintf('  [%s] STRAIN CENSUS: %s\n', label, jsonencode(C));
testCase.verifyGreaterThan(C.strain_entities, 0, ...
    sprintf('%s: no strain entity in the destination (the denominator is 0)', label));
testCase.verifyEqual(C.subject_strain_pairs_over_one, 0, sprintf( ...
    ['%s: %d (home session, name) pair(s) hold more than one subject strain entity ' ...
     '(%d entities in %d pairs): not one strain entity per strain name per session'], ...
    label, C.subject_strain_pairs_over_one, C.subject_strain_entities, C.subject_strain_pairs));
testCase.verifyEqual(C.subjects_with_two_instance_of, 0, sprintf( ...
    '%s: %d subject(s) have more than one instance_of to a strain (of %d with one)', ...
    label, C.subjects_with_two_instance_of, C.subjects_with_instance_of));
testCase.verifyEqual(C.subjects_with_two_strains, 0, sprintf( ...
    '%s: %d subject(s) are an instance_of more than one strain entity', ...
    label, C.subjects_with_two_strains));
testCase.verifyEqual(C.openminds_ids_on_strains, 0, sprintf( ...
    '%s: %d openminds: id(s) on strain entities', label, C.openminds_ids_on_strains));

% ---- the fields -----------------------------------------------------------------
R = [];
testCase.assertTrue(isfield(result, 'secondPass') && ...
    isfield(result.secondPass, 'strainFields'), ...
    sprintf('%s: the migration result has no secondPass.strainFields', label));
R = result.secondPass.strainFields;
testCase.assertNotEmpty(R, sprintf(['%s: the strain field comparison did not run ' ...
    '(or threw; see result.secondPassErrors)'], label));
expected = countV1Strains(v1Bodies);
fprintf(['\n  OPENMINDS STRAIN FIELDS AFTER THE SECOND PASS (%s)\n' ...
    '    DENOMINATOR: %d v1 Strain(s) inspected (%d counted in the v1 bodies); %d ' ...
    'document(s) read; %d strain entit(ies)\n' ...
    '    %s: mapped %d by id, %d by instance_of, %d by name; not mapped: %d no ' ...
    'entity, %d ambiguous\n'], label, R.v1_strains_inspected, expected, ...
    R.documents_inspected, R.strain_entities_seen, upper(R.state), R.mapped_by_id, ...
    R.mapped_by_instance_of, R.mapped_by_name, R.not_mapped_no_entity, R.not_mapped_ambiguous);
fieldNames = {'name', 'description', 'species', 'genetic_strain_type', 'background_strain'};
for k = 1:numel(fieldNames)
    f = R.(fieldNames{k});
    fprintf('    %s: %d compared: %d equal, %d differ; %d empty in v1, of which %d have a v2 value\n', ...
        fieldNames{k}, f.compared, f.equal, f.differ, f.v1_absent, f.v2_only);
end
fprintf('    background_strain parents mapped to no entity: %d\n', ...
    R.background_strain.parent_not_mapped);
fprintf(['    openminds child edges: %d: %d to a compared field, %d to another field, ' ...
    '%d to no field\n'], R.child_edges.total, R.child_edges.to_compared_field, ...
    R.child_edges.to_other_field, R.child_edges.to_no_field);
for k = 1:numel(R.differences)
    d = R.differences(k);
    fprintf('    DIFFERS: %s %s: %s (v1 "%s", v2 "%s")\n', d.v1_id, d.field, d.why, d.v1, d.v2);
end

testCase.verifyEqual(R.v1_strains_inspected, expected, sprintf( ...
    '%s: the step inspected %d v1 Strain(s); the v1 bodies hold %d', ...
    label, R.v1_strains_inspected, expected));
testCase.verifyGreaterThan(R.v1_strains_inspected, 0, ...
    sprintf('%s: no v1 Strain to compare (the denominator is 0)', label));
testCase.verifyEqual(R.mapped_by_id + R.mapped_by_instance_of + R.mapped_by_name + ...
    R.not_mapped_no_entity + R.not_mapped_ambiguous, R.v1_strains_inspected, ...
    sprintf('%s: the mapping does not partition the v1 Strains', label));
testCase.verifyEqual(R.not_mapped_no_entity + R.not_mapped_ambiguous, 0, sprintf( ...
    '%s: %d v1 Strain(s) carried by no strain entity, %d by several', ...
    label, R.not_mapped_no_entity, R.not_mapped_ambiguous));
for k = 1:numel(fieldNames)
    f = R.(fieldNames{k});
    testCase.verifyEqual(f.equal + f.differ, f.compared, sprintf( ...
        '%s: %s: compared %d is not equal %d + differ %d', label, fieldNames{k}, ...
        f.compared, f.equal, f.differ));
    testCase.verifyEqual(f.differ, 0, sprintf('%s: %s differs on %d v1 Strain(s)', ...
        label, fieldNames{k}, f.differ));
    testCase.verifyEqual(f.v2_only, 0, sprintf(['%s: %s: %d v1 Strain(s) with no value ' ...
        'whose strain entity has one'], label, fieldNames{k}, f.v2_only));
end
testCase.verifyEqual(R.child_edges.to_compared_field + R.child_edges.to_other_field + ...
    R.child_edges.to_no_field, R.child_edges.total, ...
    sprintf('%s: the child edges are not partitioned', label));
testCase.verifyEqual(R.child_edges.to_no_field, 0, sprintf( ...
    '%s: %d openminds child edge(s) named by no field of their Strain', ...
    label, R.child_edges.to_no_field));
end

function n = countV1Strains(raw)
% the v1 openMINDS Strain documents, counted by decoding each (not by the
% step's own filter)
n = 0;
for k = 1:numel(raw)
    b = raw{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        if ~contains(b, 'Strain'); continue; end
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if ~isstruct(b) || ~isfield(b, 'document_class') ...
            || ~any(strcmp(char(b.document_class.class_name), {'openminds', 'openminds_subject'}))
        continue;
    end
    blk = struct();
    if isfield(b, 'openminds') && isstruct(b.openminds)
        blk = b.openminds;
    elseif isfield(b, 'openminds_subject') && isstruct(b.openminds_subject)
        blk = b.openminds_subject;
    end
    t = '';
    if isfield(blk, 'openminds_type'); t = char(blk.openminds_type); end
    m = '';
    if isfield(blk, 'matlab_type'); m = char(blk.matlab_type); end
    if endsWith(t, '/Strain') || endsWith(m, '.Strain') || strcmp(t, 'Strain')
        n = n + 1;
    end
end
end
