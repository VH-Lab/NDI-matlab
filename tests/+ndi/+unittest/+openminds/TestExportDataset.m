classdef TestExportDataset < matlab.unittest.TestCase
%TESTEXPORTDATASET ndi.openminds.exportDataset on a small made-up v2 dataset.
%
%   The dataset is built with the public v2 builders (did2.build.*,
%   ndi.setup.V2.entityDocuments / registeredTerm, ndi.v2.vocabTerm):
%
%     dataset   a Data Set entity with a name, notes and a DOI, a short
%               name, a version number and a release date, and a
%               copyrightYear date assertion (2024)
%     people    Ada Lovelace (ORCID, affiliated with the organization),
%               Grace Hopper, Alan Turing
%     relations author Ada (order 0) and Grace (order 1, with a CRediT role
%               on the author edge); contributor Alan with roles data
%               curation, visualization and corresponding author;
%               maintainer Grace; copyrightHolder the organization;
%               subjectOf a publication with a DOI; hosted_by the
%               organization (no crosswalk row reads it)
%
%   and checks the decided lines of did-schema
%   docs/plans/did_v2_go_forward_class_audit.md: [one dataset exports as
%   Dataset and version], [unmapped roles not exported], [custodian exports
%   as custodianship], [copyright year is a date assertion], [documentation
%   from subjectOf], and [openMINDS export answers] (the corresponding
%   author is not exported; a person's affiliations are those listed within
%   the dataset; DatasetVersion's fields from the dataset's assertions).
%
%   Needs DID-matlab's did2.build, a v2 schema with the openMINDS crosswalk
%   on DID_SCHEMA_PATH, and openMINDS_MATLAB (`latest`) on the path;
%   without them every test is filtered with the reason.

    properties
        Docs
        Id
    end

    methods (TestClassSetup)
        function build(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            schemaPath = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(schemaPath) && ...
                isfile(ndi.v2.schemaFile(schemaPath, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a v2 schema with `entity`');
            testCase.assumeTrue(isfile(ndi.v2.schemaFile(schemaPath, ...
                'did_v2_openminds_crosswalk.json')), ...
                'DID_SCHEMA_PATH holds no openMINDS crosswalk');
            testCase.assumeTrue(exist('openminds.core.products.DatasetVersion', 'class') == 8, ...
                'openMINDS_MATLAB (`latest` types) is not on the path');
            [testCase.Docs, testCase.Id] = buildDataset(true, true);
        end
    end

    methods (Test)
        function testOneDatasetIsDatasetAndVersion(testCase)
            [ds, dv, report] = ndi.openminds.exportDataset(testCase.Docs);
            testCase.verifyClass(ds, 'openminds.core.products.Dataset');
            testCase.verifyClass(dv, 'openminds.core.products.DatasetVersion');
            testCase.verifyClass(dv.isVersionOf, 'openminds.core.products.Dataset');
            testCase.verifyEqual(dv.isVersionOf.fullName, ds.fullName);
            testCase.verifyEqual(ds.fullName, "Example foraging dataset");
            testCase.verifyEqual(dv.fullName, "Example foraging dataset");
            testCase.verifyEqual(ds.description, "Worms foraging on food patches.");
            testCase.verifyEqual(dv.shortName, "Foraging");
            testCase.verifyEqual(ds.shortName, "Foraging");
            testCase.verifyEqual(dv.versionIdentifier, "1.0.0");
            testCase.verifyEqual(dv.releaseDate, datetime(2025, 3, 1));
            doi = dv.digitalIdentifier;
            testCase.verifyClass(doi, 'openminds.core.digitalidentifier.DOI');
            testCase.verifyEqual(doi.identifier, "https://doi.org/10.5555/dataset.1");
            % the denominator, first
            testCase.verifyEqual(report.documents, numel(testCase.Docs));
            testCase.verifyEqual(report.datasetId, testCase.Id.dataset);
            testCase.verifyGreaterThan(report.statements, 0);
            testCase.verifyGreaterThan(report.relations, 0);
        end

        function testContributionsThroughTheCrosswalk(testCase)
            [ds, dv, report] = ndi.openminds.exportDataset(testCase.Docs);
            types = {report.contributions.type};
            % author: one ordered authoring contribution; contributor: one
            % per mapped CRediT role; maintainer: custodianship
            testCase.verifyEqual(types, {'authoring', 'curation', 'custodianship'});
            author = report.contributions(strcmp(types, 'authoring'));
            testCase.verifyEqual(author.contributors, {testCase.Id.ada, testCase.Id.grace});
            custodian = report.contributions(strcmp(types, 'custodianship'));
            testCase.verifyEqual(custodian.contributors, {testCase.Id.grace});
            c = dv.contribution;
            testCase.verifyNumElements(c, 3);
            names = arrayfun(@(x) string(x.type.name), c);
            testCase.verifyEqual(names, ["authoring", "curation", "custodianship"]);
            testCase.verifyNumElements(ds.contribution, 3);
        end

        function testUnmappedRolesReportedNotExported(testCase)
            [~, ~, report] = ndi.openminds.exportDataset(testCase.Docs);
            n = report.notExported;
            onContribution = n(strcmp({n.property}, 'contribution'));
            items = {onContribution.item};
            % conceptualization/visualization ([unmapped roles not exported])
            % and the corresponding author (G108(3)) are left out, and said so
            testCase.verifyTrue(any(startsWith(items, 'visualization')), strjoin(items, ' | '));
            testCase.verifyTrue(any(startsWith(items, 'corresponding author')), strjoin(items, ' | '));
            testCase.verifyFalse(any(startsWith(items, 'data curation')), strjoin(items, ' | '));
            % a role on an author edge is reported, not dropped
            testCase.verifyTrue(any(startsWith(items, 'writing - original draft')), strjoin(items, ' | '));
        end

        function testCopyrightYearFromDateAssertion(testCase)
            [~, dv, report] = ndi.openminds.exportDataset(testCase.Docs);
            cr = dv.copyright;
            testCase.verifyClass(cr, 'openminds.core.data.Copyright');
            testCase.verifyEqual(cr.year, "2024");
            holder = cr.holder;
            testCase.verifyClass(holder, 'openminds.core.actors.Organization');
            testCase.verifyEqual(holder.name, "Example University");
            m = report.missing;
            testCase.verifyFalse(any(strcmp({m.type}, 'Copyright')), ...
                'Copyright has its holder and its year');
        end

        function testDocumentationFromSubjectOf(testCase)
            [~, dv, report] = ndi.openminds.exportDataset(testCase.Docs);
            d = dv.documentation;
            testCase.verifyClass(d, 'openminds.core.digitalidentifier.DOI');
            testCase.verifyEqual(d.identifier, "https://doi.org/10.5555/paper.2");
            m = report.missing;
            testCase.verifyFalse(any(strcmp({m.type}, 'DatasetVersion') & ...
                strcmp({m.property}, 'documentation')));
        end

        function testNoSubjectOfReportsDocumentationMissing(testCase)
            docs = buildDataset(false, false);
            [~, dv, report] = ndi.openminds.exportDataset(docs);
            testCase.verifyEmpty(dv.documentation);
            m = report.missing;
            testCase.verifyTrue(any(strcmp({m.type}, 'DatasetVersion') & ...
                strcmp({m.property}, 'documentation')));
        end

        function testAffiliationsWithinTheDataset(testCase)
            [~, dv, ~] = ndi.openminds.exportDataset(testCase.Docs);
            a = dv.contributorAffiliation;
            testCase.verifyNumElements(a, 1);
            person = a.person;
            testCase.verifyEqual(person.preferredName, "Ada Lovelace");
            testCase.verifyEqual(person.givenName, "Ada");
            testCase.verifyEqual(person.familyName, "Lovelace");
            org = a.organization;
            testCase.verifyEqual(org.name, "Example University");
            orcid = person.digitalIdentifier;
            testCase.verifyClass(orcid, 'openminds.core.digitalidentifier.ORCID');
            testCase.verifyEqual(orcid.identifier, "https://orcid.org/0000-0002-1825-0097");
            ror = org.digitalIdentifier;
            testCase.verifyClass(ror, 'openminds.core.digitalidentifier.RORID');
            testCase.verifyEqual(ror.identifier, "https://ror.org/03yrm5c26");
        end

        function testRequiredWithoutSourceIsMissingNotInvented(testCase)
            [~, dv, report] = ndi.openminds.exportDataset(testCase.Docs);
            m = report.missing;
            isDv = strcmp({m.type}, 'DatasetVersion');
            % deferred in the crosswalk: no v2 source, so reported missing
            testCase.verifyTrue(any(isDv & strcmp({m.property}, 'versionSpecification')));
            % an unset openMINDS string reads as "" (never filled in)
            testCase.verifyEqual(strlength(dv.versionSpecification), 0);
            % present in the dataset, so not missing
            for p = {'fullName', 'shortName', 'description', 'releaseDate', ...
                    'versionIdentifier', 'digitalIdentifier', 'contribution', 'isVersionOf'}
                testCase.verifyFalse(any(isDv & strcmp({m.property}, p{1})), p{1});
            end
        end

        function testUnreadRelationIsReported(testCase)
            [~, ~, report] = ndi.openminds.exportDataset(testCase.Docs);
            u = report.unread;
            testCase.verifyTrue(any(strcmp({u.id}, testCase.Id.hostedBy)), ...
                'a relation from the dataset that no crosswalk row reads is listed');
        end

        function testSeveralDatasetsNeedAnId(testCase)
            sid = did.ido.unique_id();
            other = ndi.setup.V2.entityDocuments('dataset', struct('name', 'Another dataset'), ...
                struct(), 'SessionId', sid, 'Id', sid);
            docs = [testCase.Docs, other];
            testCase.verifyError(@() ndi.openminds.exportDataset(docs), ...
                'ndi:openminds:exportDataset:datasetCount');
            [ds, ~, report] = ndi.openminds.exportDataset(docs, 'DatasetId', testCase.Id.dataset);
            testCase.verifyEqual(ds.fullName, "Example foraging dataset");
            testCase.verifyEqual(report.datasetId, testCase.Id.dataset);
            testCase.verifyError(@() ndi.openminds.exportDataset(docs, 'DatasetId', 'nope'), ...
                'ndi:openminds:exportDataset:noDataset');
        end
    end
end

function [docs, id] = buildDataset(withDocumentation, withExtras)
%BUILDDATASET The fixture's documents (cell of structs) and their ids.
arguments
    withDocumentation (1,1) logical
    withExtras (1,1) logical
end
sid = did.ido.unique_id();
common = {'SessionId', sid};
rel = @(child, parent, handle, varargin) did2.build.directedRelation(child, parent, ...
    ndi.v2.vocabTerm('relation', handle), common{:}, varargin{:});

ds = ndi.setup.V2.entityDocuments('dataset', struct('name', 'Example foraging dataset', ...
    'notes', 'Worms foraging on food patches.', 'short_name', 'Foraging', ...
    'version', '1.0.0', 'release_date', '2025-03-01', ...
    'global_identifier', struct('scheme', 'doi', 'value', '10.5555/dataset.1')), ...
    struct(), common{:}, 'Id', sid);
id.dataset = ds{1}.base.id;
ada = ndi.setup.V2.entityDocuments('person', struct('given_name', 'Ada', ...
    'family_name', 'Lovelace', 'global_identifier', ...
    struct('scheme', 'orcid', 'value', '0000-0002-1825-0097')), struct(), common{:});
grace = ndi.setup.V2.entityDocuments('person', struct('given_name', 'Grace', ...
    'family_name', 'Hopper'), struct(), common{:});
alan = ndi.setup.V2.entityDocuments('person', struct('given_name', 'Alan', ...
    'family_name', 'Turing'), struct(), common{:});
org = ndi.setup.V2.entityDocuments('organization', struct('name', 'Example University', ...
    'global_identifier', struct('scheme', 'ror', 'value', '03yrm5c26')), struct(), common{:});
id.ada = ada{1}.base.id;
id.grace = grace{1}.base.id;
id.alan = alan{1}.base.id;
id.org = org{1}.base.id;

docs = [ds, ada, grace, alan, org];
docs{end+1} = rel(id.dataset, id.ada, 'has_author', 'Order', 0);
docs{end+1} = rel(id.dataset, id.grace, 'has_author', 'Order', 1, ...
    'Fields', struct('roles', did2.build.label({'writing - original draft'})));
docs{end+1} = rel(id.dataset, id.alan, 'contributed_by', 'Fields', struct('roles', ...
    did2.build.label({'data curation', 'visualization', 'corresponding author'})));
docs{end+1} = rel(id.dataset, id.grace, 'has_custodian');
docs{end+1} = rel(id.dataset, id.org, 'copyright_holder');
docs{end+1} = rel(id.ada, id.org, 'affiliated_with');
% the copyright year: a date assertion about the dataset entity
docs{end+1} = did2.build.statement('assertion', id.dataset, ...
    ndi.setup.V2.registeredTerm('schema:copyrightYear', 'copyrightYear'), ...
    did2.build.valueCell('date', {'2024'}, 'Fields', struct('precision', 'year')), ...
    common{:}, 'ValueKind', 'date');
if withDocumentation
    pub = ndi.setup.V2.entityDocuments('publication', struct('name', 'A foraging paper', ...
        'global_identifier', struct('scheme', 'doi', 'value', '10.5555/paper.2')), ...
        struct(), common{:});
    id.publication = pub{1}.base.id;
    docs = [docs, pub];
    docs{end+1} = rel(id.dataset, id.publication, 'documented_by');
end
if withExtras
    docs{end+1} = rel(id.dataset, id.org, 'hosted_by');
    id.hostedBy = docs{end}.base.id;
end
end
