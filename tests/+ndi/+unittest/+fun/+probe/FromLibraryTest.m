classdef FromLibraryTest < ndi.unittest.session.buildSession
% FROMLIBRARYTEST - end-to-end tests for ndi.fun.probe.geometry.fromLibrary
%
% Uses the real Intan session built by ndi.unittest.session.buildSession (a single
% 'n-trode' probe) to verify that attaching a library layout creates the expected
% documents:
%   - a layout that ships a default 'map' also creates a site2channelmap,
%   - a caller-supplied 'map' overrides the shipped default, and
%   - a map-less layout creates only a probe_geometry (no site2channelmap).
%
% The probe has one channel but the layouts have many sites, so fromStruct emits a
% channel-count mismatch warning; that is expected here (we are exercising the map
% plumbing, not physical correctness) and is silenced in each test.

    methods (Static)
        function c = suppressMismatchWarning()
            % silence the expected site/channel count-mismatch warning; the returned
            % onCleanup restores the previous warning state when it goes out of scope.
            w = warning('off','ndi:fun:probe:geometry:fromStruct:channelCountMismatch');
            c = onCleanup(@() warning(w));
        end
    end

    methods (Test)

        function testShippedMapCreatesSite2ChannelMap(testCase)
            S = testCase.Session;
            p = S.getprobes();
            testCase.assertNotEmpty(p, 'buildSession should provide at least one probe.');
            probe = p{1};

            cleanup = ndi.unittest.fun.probe.FromLibraryTest.suppressMismatchWarning(); %#ok<NASGU>

            ndi.fun.probe.geometry.fromLibrary(S, probe, ...
                'neuronexus/A1x32-Poly2-5mm-50s-177', 'replace', true, 'verbose', 0);

            G = ndi.fun.probe.geometry.get(S, probe);
            testCase.verifyTrue(G.found, 'probe_geometry should have been created.');
            testCase.verifyEqual(numel(G.pg.site_locations_depth), 32, ...
                'NeuroNexus A1x32-Poly2 should have 32 sites.');
            testCase.verifyNotEmpty(G.s2c_doc, ...
                'A shipped map should have produced a site2channelmap document.');

            expectedMap = [16;17;15;18;14;19;13;20;12;21;11;22;1;32;31;2;3;30; ...
                4;29;5;28;6;27;7;26;8;25;9;24;10;23];
            testCase.verifyEqual(G.map, expectedMap, ...
                'site2channelmap should carry the layout''s shipped map.');
        end

        function testCallerMapOverridesShipped(testCase)
            S = testCase.Session;
            p = S.getprobes();
            probe = p{1};

            cleanup = ndi.unittest.fun.probe.FromLibraryTest.suppressMismatchWarning(); %#ok<NASGU>

            customMap = (32:-1:1)';
            ndi.fun.probe.geometry.fromLibrary(S, probe, ...
                'neuronexus/A1x32-Poly2-5mm-50s-177', 'map', customMap, ...
                'replace', true, 'verbose', 0);

            G = ndi.fun.probe.geometry.get(S, probe);
            testCase.verifyNotEmpty(G.s2c_doc, 'A caller map should create a site2channelmap.');
            testCase.verifyEqual(G.map, customMap, ...
                'A caller-supplied map should override the shipped default.');
        end

        function testMaplessLayoutHasNoSite2ChannelMap(testCase)
            S = testCase.Session;
            p = S.getprobes();
            probe = p{1};

            cleanup = ndi.unittest.fun.probe.FromLibraryTest.suppressMismatchWarning(); %#ok<NASGU>

            ndi.fun.probe.geometry.fromLibrary(S, probe, ...
                'generic/tetrode', 'replace', true, 'verbose', 0);

            G = ndi.fun.probe.geometry.get(S, probe);
            testCase.verifyTrue(G.found, 'probe_geometry should have been created.');
            testCase.verifyEqual(numel(G.pg.site_locations_depth), 4, ...
                'tetrode should have 4 sites.');
            testCase.verifyEmpty(G.s2c_doc, ...
                'A map-less layout should not create a site2channelmap.');
            testCase.verifyEmpty(G.map, ...
                'A map-less layout should yield no site->channel map.');
        end

    end
end
