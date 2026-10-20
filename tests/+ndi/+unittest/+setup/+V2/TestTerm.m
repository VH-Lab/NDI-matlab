classdef TestTerm < matlab.unittest.TestCase
%TESTTERM ndi.term: a stored term, and what the ontology says about it.
%
%   Offline: the ontology's answers are prepared in the on-disk cache
%   (NDI_SYNONYM_CACHE, read by ndi.v2.termLookup), so no lookup goes online.

    properties
        Folder
    end

    methods (TestMethodSetup)
        function cache(testCase)
            testCase.Folder = tempname;
            mkdir(testCase.Folder);
            testCase.addTeardown(@() rmdir(testCase.Folder, 's'));
            old = getenv('NDI_SYNONYM_CACHE');
            setenv('NDI_SYNONYM_CACHE', testCase.Folder);
            testCase.addTeardown(@() setenv('NDI_SYNONYM_CACHE', old));
            % an answer as ndi.v2.termLookup writes it
            write(testCase.Folder, 'wbls_0000038.json', struct('node', 'WBls:0000038', ...
                'names', {{'L4 larva Ce', 'L4 larva'}}, 'id', 'WBls:0000038', ...
                'label', 'L4 larva Ce', 'definition', 'The fourth stage larva.', ...
                'synonyms', {{'L4 larva'}}));
            % a names-only answer, as ndi.v2.synonyms wrote it before
            write(testCase.Folder, 'ncbitaxon_6239.json', struct('node', 'NCBITaxon:6239', ...
                'names', {{'Caenorhabditis elegans', 'C. elegans'}}));
        end
    end

    methods (Test)
        function testFromStored(testCase)
            t = ndi.term.fromStored(struct('node', 'WBls:0000038', 'name', 'L4 larva'));
            testCase.verifyClass(t, 'ndi.term');
            testCase.verifyEqual({t.node, t.name}, {'WBls:0000038', 'L4 larva'});
            t = ndi.term.fromStored([struct('node', 'A:1', 'name', 'a'), struct('node', 'B:2', 'name', 'b')]);
            testCase.verifyEqual(string(t), ["a", "b"], 'a struct array');
            t = ndi.term.fromStored({struct('node', 'A:1', 'name', 'a'), struct('node', '', 'name', 'b')});
            testCase.verifyEqual(t.hasNode(), [true false], 'a cell array; a label has no node');
            t = ndi.term.fromStored({'NCBITaxon:6239', 'acclimation plate'});
            testCase.verifyEqual({t.node}, {'NCBITaxon:6239', ''}, 'text: a CURIE is a node');
            testCase.verifyEqual({t.name}, {'', 'acclimation plate'}, 'other text is a name');
            testCase.verifyEmpty(ndi.term.fromStored([]));
            testCase.verifyClass(ndi.term.fromStored([]), 'ndi.term');
            u = ndi.term('X:1', 'x');
            testCase.verifyEqual(ndi.term.fromStored(u), u, 'an ndi.term is returned as is');
        end

        function testTextAndStruct(testCase)
            t = ndi.term('WBls:0000038', 'L4 larva');
            testCase.verifyEqual(string(t), "L4 larva");
            testCase.verifyEqual(char(t), 'L4 larva');
            testCase.verifyEqual(char(ndi.term('WBls:0000038', '')), 'WBls:0000038', 'no name: the node');
            testCase.verifyEqual(t.toStruct(), struct('node', 'WBls:0000038', 'name', 'L4 larva'));
            testCase.verifyEqual(t.prefix(), 'WBls');
            testCase.verifyEqual(ndi.term('', 'x').prefix(), '');
            testCase.verifyEqual(ndi.v2.termName(t), 'L4 larva', 'termName reads an ndi.term');
        end

        function testEquality(testCase)
            a = ndi.term('NCBITaxon:6239', 'C. elegans');
            testCase.verifyTrue(a == ndi.term('ncbitaxon:6239', 'Caenorhabditis elegans'), ...
                'two nodes: their keys (the prefix ignoring case), not their names');
            testCase.verifyFalse(a == ndi.term('NCBITaxon:6237', 'C. elegans'), 'different nodes');
            testCase.verifyTrue(ndi.term('', 'Assay plate') == ndi.term('', 'assay plate'), ...
                'no nodes: names, ignoring case');
            testCase.verifyTrue(a == "c. elegans", 'text: the name');
            testCase.verifyTrue(a == "ncbitaxon:6239", 'text: the node');
            testCase.verifyTrue("NCBITaxon:6239" == a, 'either side');
            testCase.verifyTrue(ndi.term('WBls:0000038', 'L4 larva') == "L4 larva Ce", ...
                'text: the ontology''s label (from the cache)');
            testCase.verifyTrue(ndi.term('WBls:0000038', 'L4 larva Ce') == "L4 larva", ...
                'text: one of the ontology''s synonyms (from the cache; tenet T19)');
            testCase.verifyFalse(a == "worm");
            testCase.verifyTrue(a ~= "worm");
            testCase.verifyEqual(a == ["C. elegans", "worm"], [true false], 'elementwise');
            testCase.verifyError(@() a == 3, 'ndi:term:eq');
        end

        function testSynonymNodesFindARegisteredTermByASynonym(testCase)
            % ndi.v2.synonymNodes reads DID-schema's term registry: 'mean' is
            % a synonym of NCIT:C53319 Arithmetic Mean, so a search for
            % 'mean' widens to that node (ndi.v2.searchStatements). Without a
            % registry (the `current` CI leg) it returns early: a filtered test
            % fails test-import-v2.yml.
            if isempty(which('did2.schema.termIndex')), return; end
            ix = did2.schema.termIndex();
            if ~(ix.present && isKey(ix.byNode, 'ncit:C53319')), return; end
            % every registered term answered offline: its name alone
            v = values(ix.byNode);
            for k = 1:numel(v)
                write(testCase.Folder, [regexprep(lower(v{k}.node), '[^a-z0-9_.-]', '_') '.json'], ...
                    struct('node', v{k}.node, 'names', {{v{k}.name}}));
            end
            write(testCase.Folder, 'ncit_c53319.json', struct('node', 'NCIT:C53319', ...
                'names', {{'Arithmetic Mean', 'mean', 'Statistical Mean'}}));
            testCase.verifyEqual(ndi.v2.synonymNodes('mean'), {'NCIT:C53319'});
            testCase.verifyEqual(ndi.v2.synonymNodes({'statistical*'}), {'NCIT:C53319'}, ...
                'a wildcard pattern');
            testCase.verifyEmpty(ndi.v2.synonymNodes('no term goes by this'));
        end

        function testOntologyAnswers(testCase)
            t = ndi.term('WBls:0000038', 'L4 larva');
            testCase.verifyEqual(t.label(), 'L4 larva Ce', 'the label differs from the stored name');
            testCase.verifyEqual(t.name, 'L4 larva');
            testCase.verifyEqual(t.definition(), 'The fourth stage larva.');
            testCase.verifyEqual(t.synonyms(), {'L4 larva'});
            testCase.verifyEqual(t.id(), 'WBls:0000038');
            L = t.lookup();
            testCase.verifyTrue(L.found);
            % a names-only cache file: its first name is the label, no definition
            c = ndi.term('NCBITaxon:6239', 'C. elegans');
            testCase.verifyEqual(c.label(), 'Caenorhabditis elegans');
            testCase.verifyEqual(c.synonyms(), {'C. elegans'});
            testCase.verifyEqual(c.definition(), '');
            % ndi.v2.synonyms reads the same files
            testCase.verifyEqual(ndi.v2.synonyms('WBls:0000038'), {'L4 larva Ce', 'L4 larva'});
            % a label with no node asks the ontology nothing
            n = ndi.term('', 'acclimation plate');
            testCase.verifyFalse(n.lookup().found);
            testCase.verifyEqual(n.label(), '');
            testCase.verifyEqual(n.iri(), '');
        end

        function testIri(testCase)
            % from the registry's uri_base, when the schema in use has one
            ix = ndi.v2.curiePrefixes();
            if isfield(ix, 'uriBase') && isKey(ix.uriBase, 'time')
                testCase.verifyEqual(ndi.term('time:intervalDuring', '').iri(), ...
                    [ix.uriBase('time') 'intervalDuring']);
            else
                testCase.verifyEqual(ndi.term('time:intervalDuring', '').iri(), '', ...
                    'no uri_base for time: no IRI');
            end
            testCase.verifyEqual(ndi.term('nosuchprefix:1', '').iri(), '', 'an unknown prefix');
        end
    end
end

function write(folder, name, s)
fid = fopen(fullfile(folder, name), 'w');
fwrite(fid, jsonencode(s), 'char');
fclose(fid);
end
