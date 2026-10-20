classdef TestCuriePrefixSpelling < matlab.unittest.TestCase
%TESTCURIEPREFIXSPELLING A CURIE's prefix is written the way its issuer cites
%   it, and read by key, spelling or synonym, ignoring case.
%
%   did-schema V_eta_prefix_spelling_plan.md, TEAM-SIGN-OFF [prefix spelling],
%   2026-10-19: "a CURIE's prefix is written as its issuer cites it (the
%   registry entry's spelling: ORCID:, ROR:, PMID:, PMCID:, RRID:, doi:,
%   WormBase:, EDAM:format_), for identifiers and term nodes alike; readers
%   match a prefix by key, spelling or synonym, ignoring case; registry keys
%   stay the lowercase Bioregistry prefixes."
%
%   Covers ndi.v2.curiePrefixes / curieKey / curieSpelling / curieForms,
%   ndi.v2.matchTerm and ndi.setup.V2.curie over a registry written here in
%   the V_eta shape, and the Haley spec's strain nodes. One test reads the
%   schema on DID_SCHEMA_PATH and is filtered when that schema predates the
%   spellings.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Dir
        Index
        OldPath
    end

    methods (TestMethodSetup)
        function writeRegistry(testCase)
            testCase.Dir = tempname;
            mkdir(testCase.Dir);
            testCase.addTeardown(@() rmdir(testCase.Dir, 's'));
            fid = fopen(fullfile(testCase.Dir, 'CURIE_lookups_meta.json'), 'w');
            fwrite(fid, registryJSON(), 'char');
            fclose(fid);
            testCase.Index = ndi.v2.curiePrefixes(testCase.Dir);
            testCase.OldPath = getenv('DID_SCHEMA_PATH');
            testCase.addTeardown(@() setenv('DID_SCHEMA_PATH', testCase.OldPath));
        end
    end

    methods (Test)
        function testAPrefixIsReadByKeySpellingOrSynonym(testCase)
            ix = testCase.Index;
            for c = {'PMID:123', 'pmid:123', 'pubmed:123', 'PubMed:123'}
                testCase.verifyEqual(ndi.v2.curieKey(c{1}, ix), 'pubmed:123', c{1});
            end
            for c = {'NCBITaxon:6239', 'ncbitaxon:6239', 'NCBIT:6239', 'taxonomy:6239'}
                testCase.verifyEqual(ndi.v2.curieKey(c{1}, ix), 'ncbitaxon:6239', c{1});
            end
            testCase.verifyEqual(ndi.v2.curieKey('ZZZ:1', ix), 'zzz:1', ...
                'an unknown prefix still ignores case');
            testCase.verifyNotEqual(ndi.v2.curieKey('NCIT:C1', ix), ...
                ndi.v2.curieKey('NCIT:c1', ix), 'the local id keeps its case');
        end

        function testTheOldFormsAreReadByRewrite(testCase)
            ix = testCase.Index;
            testCase.verifyEqual(ndi.v2.curieKey('WBStrain:00004246', ix), ...
                ndi.v2.curieKey('WormBase:WBStrain00004246', ix));
            testCase.verifyEqual(ndi.v2.curieKey('format:1929', ix), ...
                ndi.v2.curieKey('EDAM:format_1929', ix));
            testCase.verifyEqual(ndi.v2.curieKey('cellosaurus:0030', ix), ...
                ndi.v2.curieKey('RRID:CVCL_0030', ix));
        end

        function testAWriterEmitsTheSpelling(testCase)
            ix = testCase.Index;
            testCase.verifyEqual(ndi.v2.curieSpelling('pubmed:1', ix), 'PMID:1');
            testCase.verifyEqual(ndi.v2.curieSpelling('WBStrain:00004246', ix), ...
                'WormBase:WBStrain00004246');
            testCase.verifyEqual(ndi.v2.curieSpelling('format:1929', ix), 'EDAM:format_1929');
            testCase.verifyEqual(ndi.v2.curieSpelling('cellosaurus:0030', ix), 'RRID:CVCL_0030');
            testCase.verifyEqual(ndi.v2.curieSpelling('ZZZ:1', ix), 'ZZZ:1', ...
                'a writer does not invent a spelling');
        end

        function testEveryFormOfANodeIsAskedFor(testCase)
            forms = lower(ndi.v2.curieForms('WormBase:WBStrain00004246', testCase.Index));
            testCase.verifyTrue(all(ismember({'wormbase:wbstrain00004246', ...
                'wbstrain:00004246', 'wb:wbstrain00004246'}, forms)), strjoin(forms, ', '));
            testCase.verifyEqual(ndi.v2.curieForms('ZZZ:1', testCase.Index), {'ZZZ:1'});
        end

        function testMatchTermReadsSynonyms(testCase)
            setenv('DID_SCHEMA_PATH', testCase.Dir);
            t = struct('node', 'NCBITaxon:6239', 'name', 'Caenorhabditis elegans');
            testCase.verifyTrue(ndi.v2.matchTerm(t, 'ncbitaxon:6239'));
            testCase.verifyTrue(ndi.v2.matchTerm(t, 'NCBIT:6239'));
            testCase.verifyTrue(ndi.v2.matchTerm(t, 'NCBIT:*'), 'a wildcard on a synonym');
            testCase.verifyFalse(ndi.v2.matchTerm(t, 'NCBITaxon:562'));
            s = struct('node', 'WBStrain:00000001', 'name', 'N2');
            testCase.verifyTrue(ndi.v2.matchTerm(s, 'WormBase:WBStrain00000001'), ...
                'a strain written in the old form is still found');
        end

        function testIdentifiersAreWrittenInTheirSpelling(testCase)
            setenv('DID_SCHEMA_PATH', testCase.Dir);
            ids = {struct('scheme', 'ORCID', 'value', 'https://orcid.org/0000-0001-6282-7124'), ...
                struct('scheme', 'ROR', 'value', '03xez1567'), ...
                struct('scheme', 'DOI', 'value', 'https://doi.org/10.7554/eLife.1'), ...
                struct('scheme', 'PMID', 'value', '123'), ...
                struct('scheme', 'PMCID', 'value', 'PMC1'), ...
                struct('scheme', 'RRID', 'value', 'RRID:WB-STRAIN:WBStrain00041969'), ...
                struct('scheme', 'NCBITaxon', 'value', 'NCBITaxon:637912'), ...
                struct('scheme', 'WormBase', 'value', 'WBStrain00000001'), ...
                struct('scheme', 'cellosaurus', 'value', '0030'), ...
                struct('scheme', 'URL', 'value', 'https://example.org/x'), ...
                struct('scheme', 'AwardNumber', 'value', 'R01 1')};
            [out, local] = ndi.setup.V2.curie(ids);
            testCase.verifyEqual(out, {'ORCID:0000-0001-6282-7124', 'ROR:03xez1567', ...
                'doi:10.7554/eLife.1', 'PMID:123', 'PMCID:PMC1', ...
                'RRID:WB-STRAIN:WBStrain00041969', 'NCBITaxon:637912', ...
                'WormBase:WBStrain00000001', 'RRID:CVCL_0030', 'https://example.org/x'});
            testCase.verifyEqual(local, 'R01 1');
            testCase.verifyError(@() ndi.setup.V2.curie({struct('scheme', 'nope', 'value', '1')}), ...
                'ndi:setup:V2:unknownScheme');
        end

        function testTheSchemaOnDidSchemaPathSpellsTheSignedPrefixes(testCase)
            ix = ndi.v2.curiePrefixes(testCase.OldPath);
            if ~isKey(ix.names, 'pmid')
                % a schema built before the prefix spellings: nothing is
                % respelled, and a prefix still matches ignoring case
                testCase.verifyEqual(ndi.v2.curieKey('ORCID:0000-0001-6282-7124', ix), ...
                    ndi.v2.curieKey('orcid:0000-0001-6282-7124', ix));
                return;
            end
            testCase.verifyEqual(ndi.v2.curieSpelling('orcid:0000-0001-6282-7124', ix), ...
                'ORCID:0000-0001-6282-7124');
            testCase.verifyEqual(ndi.v2.curieSpelling('pubmed:1', ix), 'PMID:1');
            testCase.verifyEqual(ndi.v2.curieSpelling('rrid:SCR_1', ix), 'RRID:SCR_1');
            testCase.verifyEqual(ndi.v2.curieSpelling('WBStrain:00000001', ix), ...
                'WormBase:WBStrain00000001');
        end

        function testTheHaleySpecWritesStrainsInTheWormBaseForm(testCase)
            f = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), ...
                'import_V2_spec.json');
            testCase.assumeTrue(isfile(f), 'the Haley spec is not where it was expected');
            spec = jsondecode(fileread(f));
            strains = spec.strains;
            if isstruct(strains), strains = num2cell(strains); end
            nodes = {};
            for k = 1:numel(strains)
                if isfield(strains{k}, 'node') && ~isempty(strains{k}.node)
                    nodes{end+1} = char(strains{k}.node); %#ok<AGROW>
                end
            end
            testCase.verifyNumElements(nodes, 13, 'the spec''s 13 strain nodes');
            testCase.verifyTrue(all(startsWith(nodes, 'WormBase:WBStrain')), strjoin(nodes, ', '));
        end
    end
end

function s = registryJSON()
% A cut of did-schema's V_eta CURIE_lookups_meta.json, in its shape.
s = ['{"prefixes": {' ...
     '"pubmed": {"spelling": "PMID", "synonyms": ["MEDLINE", "PMID", "PubMed", "PubMed ID", "pmid"]},' ...
     '"pmc": {"spelling": "PMCID", "synonyms": ["PMC", "PMCID"]},' ...
     '"orcid": {"spelling": "ORCID", "synonyms": ["ORCID", "ORCiD"]},' ...
     '"ror": {"spelling": "ROR", "synonyms": []},' ...
     '"doi": {"spelling": "doi", "synonyms": []},' ...
     '"rrid": {"spelling": "RRID", "synonyms": []},' ...
     '"ncit": {"spelling": "NCIT", "synonyms": ["NCIT", "NCIt"]},' ...
     '"ncbitaxon": {"spelling": "NCBITaxon", "synonyms": ["NCBITaxon", "taxonomy", "NCBIT"]},' ...
     '"wormbase": {"spelling": "WormBase", "synonyms": ["WB", "wb", "wormbase"],' ...
     '  "legacy_rewrite": {"legacy_prefix": "WBStrain", "id_prefix": "WBStrain"}},' ...
     '"edam": {"spelling": "EDAM", "synonyms": [],' ...
     '  "legacy_rewrite": {"legacy_prefix": "format", "id_prefix": "format_"}},' ...
     '"cellosaurus": {"spelling": "RRID", "synonyms": ["CVCL"],' ...
     '  "written_as": {"prefix": "rrid", "id_prefix": "CVCL_"}}' ...
     '}}'];
end
