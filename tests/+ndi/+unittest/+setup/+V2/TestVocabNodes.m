classdef TestVocabNodes < matlab.unittest.TestCase
%TESTVOCABNODES NDI names relations, entity types and channel types by handle and matches them by node.
%
%   did-schema #88, Decided by Jess Haley, 2026-10-22 [vocabulary nodes]
%   L1/L2 (V_eta_relation_inheritance_plan.md): every relation name, entity
%   type and channel type has a node; the stored `name` becomes the ontology
%   label, and code matches by node. [registry holds nodes] (S1): the handle
%   -> node table is NDI's own (ndi.v2.vocabNodes, ndi.vintage.channelTypes).
%
%   Two kinds of test:
%     * AGAINST THE SCHEMA (needs DID_SCHEMA_PATH): NDI's table names every
%       node the schema binds, and agrees with it wherever the stored name is
%       still the handle -- so the table cannot drift from the registry.
%     * THE FLIP, in a scratch schema folder whose rows store the ontology
%       labels: writers (ndi.v2.vocabTerm) store the label with the node, and
%       readers (vocabHandle / vocabIs / vocabPatterns / channelPrefix) still
%       give the handle. This is the readiness check the schema's flip waits
%       on.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function scratch(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
        end
    end

    methods (Test)
        function testEveryRegistryRelationNodeIsInTheTable(testCase)
            p = schemaPathOrSkip(testCase, 'binding_registry_meta.json');
            reg = jsondecode(fileread(fullfile(p, 'binding_registry_meta.json')));
            rows = reg.relation_bindings;
            if isstruct(rows), rows = num2cell(rows); end
            V = ndi.v2.vocabNodes('relation', p);
            fprintf('  DENOMINATOR: %d relation_bindings row(s)\n', numel(rows));
            testCase.verifyGreaterThan(numel(rows), 0, 'the registry was read');
            for k = 1:numel(rows)
                r = rows{k}.relation;
                h = ndi.v2.vocabHandle('relation', r, p);
                testCase.verifyTrue(any(strcmp(h, V.handles)), sprintf( ...
                    'registry relation {%s, %s} has no NDI handle', r.node, r.name));
                if ~isempty(r.node)
                    testCase.verifyTrue(isKey(V.nodeHandle, r.node), sprintf( ...
                        'registry node %s (%s) is not in ndi.v2.vocabNodes', r.node, r.name));
                end
                if any(strcmp(r.name, V.handles)) && ~isempty(r.node)
                    i = strcmp(V.handles, r.name);
                    testCase.verifyTrue(any(strcmp(V.nodes{i}, r.node)), sprintf( ...
                        '%s: NDI knows %s, the registry has %s', r.name, strjoin(V.nodes{i}, ', '), r.node));
                    % and a writer stores the registry's own row
                    testCase.verifyEqual(ndi.v2.vocabTerm('relation', r.name, p), ...
                        struct('node', r.node, 'name', r.name), r.name);
                end
            end
        end

        function testEveryRegistryEntityTypeNodeIsInTheTable(testCase)
            p = schemaPathOrSkip(testCase, 'binding_registry_meta.json');
            reg = jsondecode(fileread(fullfile(p, 'binding_registry_meta.json')));
            rows = reg.entity_type_bindings;
            if isstruct(rows), rows = num2cell(rows); end
            V = ndi.v2.vocabNodes('entity_type', p);
            fprintf('  DENOMINATOR: %d entity_type_bindings row(s)\n', numel(rows));
            testCase.verifyGreaterThan(numel(rows), 0, 'the registry was read');
            for k = 1:numel(rows)
                node = '';
                if isfield(rows{k}, 'node'), node = rows{k}.node; end
                h = ndi.v2.vocabHandle('entity_type', struct('node', node, 'name', rows{k}.type), p);
                testCase.verifyTrue(any(strcmp(h, V.handles)), sprintf( ...
                    'registry entity type {%s, %s} has no NDI handle', node, rows{k}.type));
                if any(strcmp(rows{k}.type, V.handles)) && ~isempty(node)
                    i = strcmp(V.handles, rows{k}.type);
                    testCase.verifyEqual(V.nodes{i}{1}, node, rows{k}.type);
                end
            end
        end

        function testEveryBoundChannelTypeHasItsPrefix(testCase)
            p = schemaPathOrSkip(testCase, 'acquisition_channels.json');
            V = ndi.v2.vocabNodes('channel_type', p);
            testCase.verifyTrue(V.declared, 'acquisition_channels.channels.type binds its values');
            prefixes = ndi.vintage.channelTypes();
            for k = 1:size(prefixes, 1)
                testCase.verifyTrue(isKey(V.nodeHandle, prefixes{k, 2}));
                stored = V.storedName(prefixes{k, 1});
                testCase.verifyNotEmpty(stored, sprintf('the schema binds %s (%s)', ...
                    prefixes{k, 2}, prefixes{k, 1}));
                testCase.verifyEqual(ndi.vintage.channelPrefix( ...
                    struct('node', prefixes{k, 2}, 'name', stored)), prefixes{k, 1});
            end
        end

        function testWritersStoreTheLabelAfterTheFlip(testCase)
            p = flippedSchema(testCase);
            t = ndi.v2.vocabTerm('relation', 'member_of', p);
            testCase.verifyEqual(t, struct('node', 'RO:0002350', 'name', 'member of'));
            t = ndi.v2.vocabTerm('relation', 'sample_of', p);
            testCase.verifyEqual(t.node, 'ENVO:01003004');
            testCase.verifyEqual(t.name, 'derives from part of');
            t = ndi.v2.vocabTerm('entity_type', 'dataset', p);
            testCase.verifyEqual(t, struct('node', 'NCIT:C47824', 'name', 'Data Set'));
            t = ndi.v2.vocabTerm('channel_type', 'ai', p);
            testCase.verifyEqual(t, struct('node', 'EMPTY:0000370', 'name', 'analog input channel'));
            % node-less: the name the schema stores
            t = ndi.v2.vocabTerm('entity_type', 'culture', p);
            testCase.verifyEqual(t, struct('node', '', 'name', 'culture'));
            % [derived from general], [derived from label]: the schema's
            % new node and PROV-O's label "wasDerivedFrom" are written, and
            % both nodes read as derived_from
            t = ndi.v2.vocabTerm('relation', 'derived_from', p);
            testCase.verifyEqual(t, struct('node', 'prov:wasDerivedFrom', 'name', 'wasDerivedFrom'));
            testCase.verifyTrue(ndi.v2.vocabIs('relation', ...
                struct('node', 'RO:0001000', 'name', 'derived_from'), 'derived_from', p));
        end

        function testReadersGiveTheHandleInEveryVintage(testCase)
            p = flippedSchema(testCase);
            % by node, whatever name is beside it
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', ...
                struct('node', 'BFO:0000050', 'name', 'part of'), p), 'part_of');
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', ...
                struct('node', 'BFO:0000050', 'name', 'part_of'), p), 'part_of');
            % written before the nodes: the name alone
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', ...
                struct('node', '', 'name', 'member_of'), p), 'member_of');
            % the label alone, read through the schema's binding
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', 'derives from part of', p), 'sample_of');
            testCase.verifyEqual(ndi.v2.vocabHandle('entity_type', 'Data Set', p), 'dataset');
            % same_as stored as its label (did-schema dc116fd): read by node,
            % by the label alone, and a caller's name given as the node or the
            % label (ndi.entity relatedIds) -- never by comparing the name
            testCase.verifyTrue(ndi.v2.vocabIs('relation', ...
                struct('node', 'owl:sameAs', 'name', 'sameAs'), 'same_as', p));
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', 'sameAs', p), 'same_as');
            testCase.verifyTrue(ndi.v2.vocabIs('relation', ...
                struct('node', 'owl:sameAs', 'name', 'owl:sameAs'), 'same_as', p));
            testCase.verifyEqual(ndi.v2.vocabTerm('relation', 'same_as', p), ...
                struct('node', 'owl:sameAs', 'name', 'sameAs'));
            testCase.verifyFalse(ndi.v2.vocabIs('relation', ...
                struct('node', 'BFO:0000050', 'name', 'part of'), 'same_as', p));
            % K5: the retired relations read as the one that replaced them
            testCase.verifyTrue(ndi.v2.vocabIs('relation', 'aliquot_of', 'sample_of', p));
            testCase.verifyTrue(ndi.v2.vocabIs('relation', ...
                struct('node', 'ENVO:01003004', 'name', 'derives from part of'), 'passage_of', p));
            % [derived from label]: "wasDerivedFrom" reads as derived_from,
            % by node and, node-less, by the name the schema stores
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', ...
                struct('node', 'prov:wasDerivedFrom', 'name', 'wasDerivedFrom'), p), 'derived_from');
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', 'wasDerivedFrom', p), 'derived_from');
            testCase.verifyTrue(ndi.v2.vocabIs('relation', ...
                struct('node', 'prov:wasDerivedFrom', 'name', 'derived_from'), 'derived_from', p));
            % K1: the obsolete contained_in node still reads
            testCase.verifyTrue(ndi.v2.vocabIs('relation', ...
                struct('node', 'RO:0001018', 'name', 'contained_in'), 'contained_in', p));
            % unknown vocabulary passes through
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', 'observes', p), 'observes');
            testCase.verifyEqual(ndi.v2.vocabHandle('relation', 'no such relation', p), 'no such relation');
            % a read mode has no term: its name, unchanged
            testCase.verifyEqual(ndi.vintage.channelPrefix(struct('node', '', 'name', 'dep')), 'dep');
            testCase.verifyEqual(ndi.vintage.channelPrefix( ...
                struct('node', 'EMPTY:0000377', 'name', 'marker channel')), 'mk');
            % a cell of terms
            testCase.verifyEqual(ndi.v2.vocabIs('entity_type', ...
                {struct('node', 'COB:0000022', 'name', 'Organism'), 'culture', 'Data Set'}, ...
                {'organism', 'culture'}, p), [true true false]);
        end

        function testTextChannelReadsBothNodes(testCase)
            % Decided by Jess Haley, 2026-10-29 [text channel replaces NCIT
            % Text]: 'tx' is EMPTY:0000410 "text channel"; NCIT:C25704 Text,
            % which sessions already migrated carry, still reads as 'tx'.
            [C, E] = ndi.vintage.channelTypes();
            testCase.verifySize(C, [10 2]);
            testCase.verifyEqual(C{strcmp(C(:, 1), 'tx'), 2}, 'EMPTY:0000410');
            testCase.verifyEqual(E, {'tx', 'NCIT:C25704'});
            p = flippedSchema(testCase);
            V = ndi.v2.vocabNodes('channel_type', p);
            testCase.verifyEqual(V.nodes{strcmp(V.handles, 'tx')}, ...
                {'EMPTY:0000410', 'NCIT:C25704'});
            testCase.verifyEqual(V.nodeHandle('EMPTY:0000410'), 'tx');
            testCase.verifyEqual(V.nodeHandle('NCIT:C25704'), 'tx');
            testCase.verifyEqual(ndi.v2.vocabHandle('channel_type', ...
                struct('node', 'EMPTY:0000410', 'name', 'text channel'), p), 'tx');
            testCase.verifyEqual(ndi.v2.vocabHandle('channel_type', ...
                struct('node', 'NCIT:C25704', 'name', 'Text'), p), 'tx');
            testCase.verifyEqual(ndi.vintage.channelPrefix( ...
                struct('node', 'EMPTY:0000410', 'name', 'text channel')), 'tx');
            testCase.verifyEqual(ndi.vintage.channelPrefix( ...
                struct('node', 'NCIT:C25704', 'name', 'Text')), 'tx');
            % a writer stores the schema's row for the node written now
            testCase.verifyEqual(ndi.v2.vocabTerm('channel_type', 'tx', p), ...
                struct('node', 'EMPTY:0000410', 'name', 'text channel'));
        end

        function testClockWritersStoreTheDecidedNodeOnTodaysSchema(testCase)
            % Decided by Jess Haley, 2026-10-26 [clock terms get nodes]: the
            % schema's rows still hold EMPTY nodes and the snake_case
            % names; a writer stores the decided node with the schema's
            % name.
            p = clockSchema(testCase, 'today', {
                '', 'utc'; '', 'dev_local_time'; '', 'dev_global_time'; '', 'exp_global_time'});
            testCase.verifyEqual(ndi.v2.vocabTerm('clock', 'utc', p), ...
                struct('node', 'wikidata:Q1536', 'name', 'utc'));
            testCase.verifyEqual(ndi.v2.vocabTerm('clock', 'dev_local_time', p), ...
                struct('node', 'EMPTY:0000403', 'name', 'dev_local_time'));
            testCase.verifyEqual(ndi.v2.vocabTerm('clock', 'dev_global_time', p), ...
                struct('node', 'EMPTY:0000404', 'name', 'dev_global_time'));
            testCase.verifyEqual(ndi.v2.vocabTerm('clock', 'exp_global_time', p), ...
                struct('node', 'EMPTY:0000405', 'name', 'exp_global_time'));
            % no schema copy at all: the table's node and the handle
            testCase.verifyEqual(ndi.v2.vocabTerm('clock', 'dev_local_time', ''), ...
                struct('node', 'EMPTY:0000403', 'name', 'dev_local_time'));
            % a clock outside the four is written as before
            testCase.verifyEqual(ndi.v2.vocabTerm('clock', 'inherited', p), ...
                struct('node', '', 'name', 'inherited'));
        end

        function testClockWritersStoreTheLabelAfterTheFlip(testCase)
            p = clockSchema(testCase, 'flipped', {
                'wikidata:Q1536', 'UTC'; 'EMPTY:0000403', 'device local time'; ...
                'EMPTY:0000404', 'device global time'; 'EMPTY:0000405', 'experiment global time'});
            testCase.verifyEqual(ndi.v2.vocabTerm('clock', 'utc', p), ...
                struct('node', 'wikidata:Q1536', 'name', 'UTC'));
            testCase.verifyEqual(ndi.v2.vocabTerm('clock', 'dev_local_time', p), ...
                struct('node', 'EMPTY:0000403', 'name', 'device local time'));
        end

        function testClockReadersGiveTheHandleInEveryShape(testCase)
            p = clockSchema(testCase, 'flipped', {
                'wikidata:Q1536', 'UTC'; 'EMPTY:0000403', 'device local time'; ...
                'EMPTY:0000404', 'device global time'; 'EMPTY:0000405', 'experiment global time'});
            for q = {p, ''}
                h = @(t) ndi.v2.vocabHandle('clock', t, q{1});
                testCase.verifyEqual(h(struct('node', 'EMPTY:0000403', 'name', 'dev_local_time')), 'dev_local_time');
                testCase.verifyEqual(h(struct('node', 'EMPTY:0000403', 'name', 'device local time')), 'dev_local_time');
                testCase.verifyEqual(h(struct('node', '', 'name', 'dev_local_time')), 'dev_local_time');
                testCase.verifyEqual(h(struct('node', '', 'name', 'device local time')), 'dev_local_time');
                testCase.verifyEqual(h(struct('node', 'EMPTY:0000405', 'name', '')), 'exp_global_time');
                testCase.verifyEqual(h(struct('node', '', 'name', 'UTC')), 'utc');
                testCase.verifyEqual(h('inherited'), 'inherited');
                % by node: the node decides even when the name says otherwise
                testCase.verifyTrue(ndi.v2.vocabIs('clock', ...
                    struct('node', 'EMPTY:0000404', 'name', 'device global time'), 'dev_global_time', q{1}));
                testCase.verifyFalse(ndi.v2.vocabIs('clock', ...
                    struct('node', 'EMPTY:0000404', 'name', 'dev_local_time'), 'dev_local_time', q{1}));
            end
        end

        function testPatternsFindEitherSpelling(testCase)
            p = flippedSchema(testCase);
            pat = ndi.v2.vocabPatterns('relation', 'member_of', p);
            testCase.verifyTrue(ndi.v2.matchTerm(struct('node', 'RO:0002350', 'name', 'member of'), pat));
            testCase.verifyTrue(ndi.v2.matchTerm(struct('node', '', 'name', 'member_of'), pat));
            testCase.verifyFalse(ndi.v2.matchTerm(struct('node', 'BFO:0000050', 'name', 'part of'), pat));
            testCase.verifyEqual(ndi.v2.vocabPatterns('relation', 'something*', p), {'something*'});
        end
    end
end

function p = schemaPathOrSkip(testCase, file)
p = getenv('DID_SCHEMA_PATH');
testCase.assumeTrue(~isempty(p) && isfile(fullfile(p, file)), ...
    sprintf('DID_SCHEMA_PATH has no %s', file));
end

function p = clockSchema(testCase, sub, rows)
% a scratch schema folder holding only relative_time_reference.json, whose
% value.clock binding lists ROWS ({node, name}) -- the read
% ndi.v2.vocabNodes('clock') makes ([clock terms get nodes])
p = fullfile(testCase.Dir, sub);
mkdir(p);
vals = cellfun(@(n, l) struct('node', n, 'name', l), rows(:, 1), rows(:, 2), ...
    'UniformOutput', false);
clk = struct('name', 'clock', 'type', 'ontology_term', ...
    'constraints', struct('binding', struct('root', 'did_clocktype', ...
    'expansion', 'value_set', 'values', {vals}, 'strength', 'required')));
s = struct('fields', {{struct('name', 'value', 'type', 'structure', 'fields', {{clk}})}});
fid = fopen(fullfile(p, 'relative_time_reference.json'), 'w');
fwrite(fid, jsonencode(s));
fclose(fid);
end

function p = flippedSchema(testCase)
% a scratch schema folder whose rows store the ontology labels, as the
% schema will once DID-matlab and NDI match by node
p = testCase.Dir;
rel = {
    'BFO:0000050', 'part of'
    'RO:0002350', 'member of'
    'ENVO:01003004', 'derives from part of'
    'RO:0001025', 'located in'
    'schema:isPartOf', 'is part of'
    'prov:wasDerivedFrom', 'wasDerivedFrom'
    'owl:sameAs', 'sameAs'
    };
reg = struct();
reg.relation_bindings = cellfun(@(n, l) struct('relation', struct('node', n, 'name', l), ...
    'passes', 'nothing'), rel(:, 1), rel(:, 2), 'UniformOutput', false);
ent = {
    'COB:0000022', 'Organism'
    '', 'culture'
    'NCIT:C47824', 'Data Set'
    'NCIT:C16644', 'Grant'
    };
reg.entity_type_bindings = cellfun(@(n, l) struct('type', l, 'node', n), ...
    ent(:, 1), ent(:, 2), 'UniformOutput', false);
fid = fopen(fullfile(p, 'binding_registry_meta.json'), 'w');
fprintf(fid, '%s', jsonencode(reg));
fclose(fid);
labels = {'analog input channel', 'analog output channel', 'digital input channel', ...
    'digital output channel', 'time channel', 'auxiliary input channel', 'event channel', ...
    'marker channel', 'Metadata', 'text channel'};
C = ndi.vintage.channelTypes();
values = cellfun(@(n, l) struct('node', n, 'name', l), C(:, 2)', labels, 'UniformOutput', false);
ac = struct('fields', {{struct('name', 'channels', 'fields', {{struct('name', 'type', ...
    'constraints', struct('binding', struct('values', {values})))}})}});
fid = fopen(fullfile(p, 'acquisition_channels.json'), 'w');
fprintf(fid, '%s', jsonencode(ac));
fclose(fid);
end
