classdef addSyncRulesTest < matlab.unittest.TestCase
    % addSyncRulesTest - Tests for ndi.setup.sync.addSyncRules and the
    % declarative lab-specific synchronization-rule mechanism.

    properties
        SessionPaths = {}   % temp directories created during the tests
    end

    methods (TestMethodTeardown)
        function cleanupSessions(testCase)
            for i = 1:numel(testCase.SessionPaths)
                p = testCase.SessionPaths{i};
                if isfolder(p)
                    rmdir(p, 's');
                end
            end
            testCase.SessionPaths = {};
        end
    end

    methods (Access = private)
        function p = makeSessionDir(testCase, tag)
            % makeSessionDir - create a fresh, empty temp session directory
            p = fullfile(tempdir(), 'NDI', ['test_addSyncRules_' tag]);
            if isfolder(p)
                rmdir(p, 's');
            end
            mkdir(p);
            testCase.SessionPaths{end+1} = p;
        end

        function names = ruleClassNames(~, S)
            % ruleClassNames - sorted class names of the rules in a syncgraph
            rules = S.syncgraph.rules;
            names = cell(1, numel(rules));
            for i = 1:numel(rules)
                names{i} = class(rules{i});
            end
            names = sort(names);
        end
    end

    methods (Test)

        function testFilefindRuleFromConfig(testCase)
            % The vhintan<->vhvis_spike2 rule loads with the correct type/params
            configFile = fullfile(ndi.common.PathConstants.CommonFolder, ...
                'sync_rules', 'vhlab', 'vhintan_intan2spike2.json');
            rule = ndi.setup.sync.syncRuleFromConfigFile(configFile);

            testCase.verifyClass(rule, 'ndi.time.syncrule.filefind');
            testCase.verifyEqual(rule.parameters.syncfilename, 'vhintan_intan2spike2time.txt');
            testCase.verifyEqual(rule.parameters.daqsystem1, 'vhintan');
            testCase.verifyEqual(rule.parameters.daqsystem2, 'vhvis_spike2');
            testCase.verifyEqual(rule.parameters.number_fullpath_matches, 1);
        end

        function testCommonTriggersRuleFromConfig(testCase)
            % The vhtaste_sync<->vhtaste_bpod rule loads with correct type/params
            configFile = fullfile(ndi.common.PathConstants.CommonFolder, ...
                'sync_rules', 'vhlab', 'vhtaste_sync2bpod.json');
            rule = ndi.setup.sync.syncRuleFromConfigFile(configFile);

            testCase.verifyClass(rule, 'ndi.time.syncrule.commonTriggersOverlappingEpochs');
            testCase.verifyEqual(rule.parameters.daqsystem1_name, 'vhtaste_sync');
            testCase.verifyEqual(rule.parameters.daqsystem2_name, 'vhtaste_bpod');
            testCase.verifyEqual(rule.parameters.daqsystem_ch1, 'dep1');
            testCase.verifyEqual(rule.parameters.daqsystem_ch2, 'mk1');
            testCase.verifyTrue(logical(rule.parameters.errorOnFailure));
        end

        function testLabMatchesLegacyVhlab(testCase)
            % ndi.setup.lab('vhlab',...) must produce the SAME set of sync
            % rules as the legacy ndi.setup.vhlab(...). This is the regression
            % this change fixes: previously ndi.setup.lab added only filematch.
            Slegacy = ndi.setup.vhlab('exp_legacy', testCase.makeSessionDir('legacy'));

            Slab = ndi.setup.lab('vhlab', 'exp_lab', testCase.makeSessionDir('lab'));

            testCase.verifyEqual(testCase.ruleClassNames(Slab), ...
                testCase.ruleClassNames(Slegacy), ...
                ['ndi.setup.lab(''vhlab'') should add the same synchronization ' ...
                'rules as ndi.setup.vhlab().']);

            % And specifically, the vhlab-specific rules must be present.
            names = testCase.ruleClassNames(Slab);
            testCase.verifyTrue(any(strcmp(names, 'ndi.time.syncrule.filefind')));
            testCase.verifyTrue(any(strcmp(names, ...
                'ndi.time.syncrule.commonTriggersOverlappingEpochs')));
        end

        function testAddSyncRulesIsIdempotent(testCase)
            % Calling addSyncRules twice must not duplicate rules.
            S = ndi.session.dir('exp_idem', testCase.makeSessionDir('idem'));
            S = ndi.setup.sync.addSyncRules(S, 'vhlab');
            n1 = numel(S.syncgraph.rules);
            S = ndi.setup.sync.addSyncRules(S, 'vhlab');
            n2 = numel(S.syncgraph.rules);
            testCase.verifyEqual(n2, n1, 'Re-adding lab sync rules should be a no-op.');
        end

        function testUnknownLabIsNoOp(testCase)
            % A lab with no sync_rules folder leaves the syncgraph unchanged.
            S = ndi.session.dir('exp_nolab', testCase.makeSessionDir('nolab'));
            n0 = numel(S.syncgraph.rules);
            S = ndi.setup.sync.addSyncRules(S, 'a_lab_that_does_not_exist');
            testCase.verifyEqual(numel(S.syncgraph.rules), n0, ...
                'addSyncRules for an unknown lab should not change the syncgraph.');
        end

    end
end
