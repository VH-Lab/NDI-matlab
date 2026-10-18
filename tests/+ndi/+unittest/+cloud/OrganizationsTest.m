classdef OrganizationsTest < matlab.unittest.TestCase
% OrganizationsTest - Offline tests for the NDI Cloud organization helpers.
%
%   Exercises ndi.cloud.internal.normalizeOrganizations,
%   ndi.cloud.internal.setOrganizations, ndi.cloud.internal.getOrganizations
%   (cache path only) and ndi.cloud.internal.chooseOrganization (with
%   Interactive false). The token is cleared for every test so nothing
%   reaches the network. Requires no credentials.

    properties (Access = private)
        SavedEnv struct = struct()
    end

    methods (TestMethodSetup)
        function isolateCloudEnv(testCase)
            names = {'NDI_CLOUD_TOKEN', 'NDI_CLOUD_ORGANIZATIONS'};
            saved = struct();
            for k = 1:numel(names)
                saved.(names{k}) = getenv(names{k});
                setenv(names{k}, '');
            end
            testCase.SavedEnv = saved;
        end
    end

    methods (TestMethodTeardown)
        function restoreCloudEnv(testCase)
            names = fieldnames(testCase.SavedEnv);
            for k = 1:numel(names)
                setenv(names{k}, testCase.SavedEnv.(names{k}));
            end
        end
    end

    methods (Static, Access = private)
        function orgs = threeOrgs()
            % Two uploadable organizations and one read-only one.
            orgs = struct( ...
                'id', {'org-1', 'org-2', 'org-3'}, ...
                'name', {'Alpha Lab', 'Beta Institute', 'Gamma Archive'}, ...
                'canUploadDataset', {true, true, false});
        end
    end

    methods (Test)
        function testNormalizeStructArray(testCase)
            orgs = ndi.cloud.internal.normalizeOrganizations(testCase.threeOrgs());
            testCase.verifySize(orgs, [1 3]);
            testCase.verifyEqual({orgs.id}, {'org-1', 'org-2', 'org-3'});
            testCase.verifyEqual({orgs.name}, {'Alpha Lab', 'Beta Institute', 'Gamma Archive'});
            testCase.verifyEqual([orgs.canUploadDataset], [true true false]);
        end

        function testNormalizeCellArrayAndMissingFields(testCase)
            % jsondecode returns a cell array when objects differ in fields.
            raw = {struct('id', "org-1", 'name', "Alpha"), ...
                   struct('id', 'org-2'), ...
                   struct('name', 'no id, dropped')};
            orgs = ndi.cloud.internal.normalizeOrganizations(raw);
            testCase.verifySize(orgs, [1 2]);
            testCase.verifyClass(orgs(1).id, 'char');
            testCase.verifyEqual(orgs(1).name, 'Alpha');
            testCase.verifyEqual(orgs(2).name, '');
            testCase.verifyEqual([orgs.canUploadDataset], [true true]);
        end

        function testNormalizeEmpty(testCase)
            orgs = ndi.cloud.internal.normalizeOrganizations([]);
            testCase.verifyEmpty(orgs);
            testCase.verifyTrue(all(isfield(orgs, {'id', 'name', 'canUploadDataset'})));
        end

        function testCacheRoundTrip(testCase)
            ndi.cloud.internal.setOrganizations(testCase.threeOrgs());
            orgs = ndi.cloud.internal.getOrganizations();
            testCase.verifyEqual(orgs, ndi.cloud.internal.normalizeOrganizations(testCase.threeOrgs()));
        end

        function testCacheRoundTripSingle(testCase)
            % jsonencode writes a lone struct as an object, not an array.
            ndi.cloud.internal.setOrganizations(struct('id', 'org-1', ...
                'name', 'Alpha Lab', 'canUploadDataset', true));
            orgs = ndi.cloud.internal.getOrganizations();
            testCase.verifySize(orgs, [1 1]);
            testCase.verifyEqual(orgs.id, 'org-1');
            testCase.verifyEqual(orgs.name, 'Alpha Lab');
        end

        function testSetEmptyClearsCache(testCase)
            ndi.cloud.internal.setOrganizations(testCase.threeOrgs());
            ndi.cloud.internal.setOrganizations([]);
            testCase.verifyEmpty(getenv('NDI_CLOUD_ORGANIZATIONS'));
        end

        function testChooseSingleOrganization(testCase)
            ndi.cloud.internal.setOrganizations(struct('id', 'org-1', ...
                'name', 'Alpha Lab', 'canUploadDataset', true));
            [id, name] = ndi.cloud.internal.chooseOrganization('Interactive', false);
            testCase.verifyEqual(id, 'org-1');
            testCase.verifyEqual(name, 'Alpha Lab');
        end

        function testChooseByNameAndId(testCase)
            ndi.cloud.internal.setOrganizations(testCase.threeOrgs());
            [id, name] = ndi.cloud.internal.chooseOrganization( ...
                'organizationName', 'Beta Institute', 'Interactive', false);
            testCase.verifyEqual(id, 'org-2');
            testCase.verifyEqual(name, 'Beta Institute');
            [id, name] = ndi.cloud.internal.chooseOrganization( ...
                'organizationID', 'org-3', 'Interactive', false);
            testCase.verifyEqual(id, 'org-3');
            testCase.verifyEqual(name, 'Gamma Archive');
        end

        function testChooseRequiresChoiceWhenNotInteractive(testCase)
            ndi.cloud.internal.setOrganizations(testCase.threeOrgs());
            testCase.verifyError(@() ndi.cloud.internal.chooseOrganization( ...
                'Interactive', false), 'NDI:Cloud:OrganizationRequired');
        end

        function testRequireUploadFiltersCandidates(testCase)
            orgs = testCase.threeOrgs();
            orgs(2).canUploadDataset = false;
            ndi.cloud.internal.setOrganizations(orgs);
            id = ndi.cloud.internal.chooseOrganization( ...
                'RequireUpload', true, 'Interactive', false);
            testCase.verifyEqual(id, 'org-1');
        end

        function testRequireUploadRejectsReadOnlyOrganization(testCase)
            ndi.cloud.internal.setOrganizations(testCase.threeOrgs());
            testCase.verifyError(@() ndi.cloud.internal.chooseOrganization( ...
                'organizationName', 'Gamma Archive', 'RequireUpload', true, ...
                'Interactive', false), 'NDI:Cloud:OrganizationCannotUpload');
        end

        function testNoUploadableOrganization(testCase)
            ndi.cloud.internal.setOrganizations(struct('id', 'org-3', ...
                'name', 'Gamma Archive', 'canUploadDataset', false));
            testCase.verifyError(@() ndi.cloud.internal.chooseOrganization( ...
                'RequireUpload', true, 'Interactive', false), ...
                'NDI:Cloud:NoUploadableOrganization');
        end

        function testUnknownOrganization(testCase)
            ndi.cloud.internal.setOrganizations(testCase.threeOrgs());
            testCase.verifyError(@() ndi.cloud.internal.chooseOrganization( ...
                'organizationName', 'Nonexistent', 'Interactive', false), ...
                'NDI:Cloud:UnknownOrganization');
        end

        function testAmbiguousOrganizationName(testCase)
            orgs = testCase.threeOrgs();
            orgs(2).name = 'Alpha Lab';
            ndi.cloud.internal.setOrganizations(orgs);
            testCase.verifyError(@() ndi.cloud.internal.chooseOrganization( ...
                'organizationName', 'Alpha Lab', 'Interactive', false), ...
                'NDI:Cloud:AmbiguousOrganization');
        end

        function testNameAndIdAreMutuallyExclusive(testCase)
            ndi.cloud.internal.setOrganizations(testCase.threeOrgs());
            testCase.verifyError(@() ndi.cloud.internal.chooseOrganization( ...
                'organizationName', 'Alpha Lab', 'organizationID', 'org-1', ...
                'Interactive', false), 'NDI:Cloud:OrganizationArguments');
        end
    end
end
