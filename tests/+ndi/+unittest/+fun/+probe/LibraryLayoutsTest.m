classdef LibraryLayoutsTest < matlab.unittest.TestCase
% LIBRARYLAYOUTSTEST - integrity checks for the shipped electrode-layout library
%
% Validates every layout under [ndi_common]/probe/geometry/ without needing a
% session: all per-site vectors must share one length, and any shipped
% site->channel 'map' must be well formed (one entry per site; every recorded
% entry a positive integer). Also spot-checks the built-in layouts this suite
% cares about (site counts, shank counts, and that their maps are 1:N permutations).

    methods (Test)

        function testAllLayoutsSelfConsistent(testCase)
            % every shipped layout has internally consistent field lengths and,
            % if it ships a 'map', a well-formed one.
            names = ndi.fun.probe.geometry.listLibrary();
            testCase.assertNotEmpty(names, 'The electrode-layout library should not be empty.');

            for i = 1:numel(names)
                name = names{i};
                geom = ndi.fun.probe.geometry.readLibrary(name);

                testCase.verifyTrue(isfield(geom,'site_locations_leftright') && ...
                    ~isempty(geom.site_locations_leftright), ...
                    [name ': missing site_locations_leftright.']);
                testCase.verifyTrue(isfield(geom,'site_locations_depth') && ...
                    ~isempty(geom.site_locations_depth), ...
                    [name ': missing site_locations_depth.']);

                n = numel(geom.site_locations_leftright);
                testCase.verifyEqual(numel(geom.site_locations_depth), n, ...
                    [name ': depth length differs from leftright length.']);

                % every optional per-site vector, when present, must be length n
                perSiteFields = {'site_locations_frontback','shank_id', ...
                    'contact_shape_radius','contact_shape_width','contact_shape_height','map'};
                for k = 1:numel(perSiteFields)
                    f = perSiteFields{k};
                    if isfield(geom,f) && ~isempty(geom.(f))
                        testCase.verifyEqual(numel(geom.(f)), n, ...
                            [name ': field ''' f ''' has ' int2str(numel(geom.(f))) ...
                            ' element(s) but there are ' int2str(n) ' site(s).']);
                    end
                end

                % a shipped map must have recorded entries that are positive integers
                % (map(i)=recording channel of site i; NaN allowed for unrecorded sites).
                if isfield(geom,'map') && ~isempty(geom.map)
                    m = double(geom.map(:));
                    recorded = m(~isnan(m));
                    testCase.verifyTrue(all(recorded >= 1), ...
                        [name ': map has a channel index < 1 (channels are 1-based).']);
                    testCase.verifyEqual(recorded, round(recorded), ...
                        [name ': map has a non-integer channel index.']);
                end
            end
        end

        function testBuiltInLayoutsAsExpected(testCase)
            % spot-check the built-in layouts: site count, shank count, and that
            % each shipped map is a permutation of 1:N.
            expected = struct( ...
                'name', {'neuronexus/A1x32-Poly2-5mm-50s-177', 'ucla/UCLAf64', ...
                         'ucla/UCLAd64', 'ucla/UCLAe64', 'neuropixels/NP2_1shank'}, ...
                'nsites', {32, 64, 64, 64, 384}, ...
                'nshanks', {1, 2, 1, 1, 1});

            for i = 1:numel(expected)
                e = expected(i);
                geom = ndi.fun.probe.geometry.readLibrary(e.name);

                testCase.verifyEqual(numel(geom.site_locations_depth), e.nsites, ...
                    [e.name ': unexpected site count.']);
                testCase.verifyEqual(numel(unique(geom.shank_id)), e.nshanks, ...
                    [e.name ': unexpected shank count.']);

                testCase.verifyTrue(isfield(geom,'map') && ~isempty(geom.map), ...
                    [e.name ': expected a shipped site->channel map.']);
                m = double(geom.map(:));
                testCase.verifyEqual(sort(m)', 1:e.nsites, ...
                    [e.name ': map is not a permutation of 1:' int2str(e.nsites) '.']);
            end
        end

        function testNeuroNexusMapExact(testCase)
            % the NeuroNexus map is a real permutation (not identity); pin it exactly.
            geom = ndi.fun.probe.geometry.readLibrary('neuronexus/A1x32-Poly2-5mm-50s-177');
            expectedMap = [16;17;15;18;14;19;13;20;12;21;11;22;1;32;31;2;3;30; ...
                4;29;5;28;6;27;7;26;8;25;9;24;10;23];
            testCase.verifyEqual(double(geom.map(:)), expectedMap, ...
                'NeuroNexus A1x32-Poly2 shipped map changed unexpectedly.');
        end

        function testUCLAe64IsLinear(testCase)
            % UCLAe64 is a single linear column: all leftright positions equal.
            geom = ndi.fun.probe.geometry.readLibrary('ucla/UCLAe64');
            lr = double(geom.site_locations_leftright(:));
            testCase.verifyEqual(numel(unique(lr)), 1, ...
                'UCLAe64 should be a single linear column (constant leftright).');
        end

    end
end
