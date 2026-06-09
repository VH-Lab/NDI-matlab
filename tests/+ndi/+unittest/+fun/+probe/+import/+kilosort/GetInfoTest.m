classdef GetInfoTest < matlab.unittest.TestCase
    % GETINFOTEST - Unit tests for ndi.fun.probe.import.kilosort.getInfo
    %
    % Builds a small kilosort output directory on disk (spike_clusters.npy,
    % spike_times.npy, templates.npy, cluster_group.tsv) and verifies the
    % structure and the multiline summary returned by getInfo.

    properties
        sessionDir
        S
        probe
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            % session path and a probe directory matching its elementstring
            testCase.sessionDir = tempname;
            testCase.probe = ndi.unittest.fun.probe.MockProbe(); % elementstring -> 'mock_probe'
            testCase.S = struct('path', testCase.sessionDir); % getInfo only needs S.path

            kdir = fullfile(testCase.sessionDir, 'kilosort', 'mock_probe', 'kilosort_output');
            mkdir(kdir);

            % 3 clusters: ids 0,1,2 ; spikes: cluster 0 ->4, 1 ->2, 2 ->3
            spike_clusters = int32([0 0 0 0 1 1 2 2 2]');
            spike_times    = int64((1:9)');
            writeNPY = @ndi.unittest.fun.probe.import.kilosort.GetInfoTest.writeNPY;
            writeNPY(fullfile(kdir,'spike_clusters.npy'), spike_clusters, 'int32');
            writeNPY(fullfile(kdir,'spike_times.npy'), spike_times, 'int64');

            % templates.npy: 3 templates x 5 samples x 4 channels
            templates = zeros(3,5,4);
            templates(:) = 1:numel(templates);
            writeNPY(fullfile(kdir,'templates.npy'), templates, 'double');

            % cluster_group.tsv with labels: good, mua, noise
            fid = fopen(fullfile(kdir,'cluster_group.tsv'),'w');
            fprintf(fid,'cluster_id\tgroup\n');
            fprintf(fid,'0\tgood\n');
            fprintf(fid,'1\tmua\n');
            fprintf(fid,'2\tnoise\n');
            fclose(fid);
        end
    end

    methods (TestMethodTeardown)
        function removeFixture(testCase)
            if exist(testCase.sessionDir,'dir')
                rmdir(testCase.sessionDir,'s');
            end
        end
    end

    methods (Test)

        function testInfoStructure(testCase)
            [info, summary] = ndi.fun.probe.import.kilosort.getInfo(testCase.S, testCase.probe);

            testCase.verifyEqual(info.num_clusters, 3, 'Should find 3 clusters.');
            testCase.verifyEqual(sort(info.cluster_ids(:)'), [0 1 2], 'Cluster ids should be 0,1,2.');
            testCase.verifyEqual(info.num_spikes_total, 9, 'Total spikes should be 9.');

            % spike counts per cluster (in the order labels returns the ids: 0,1,2)
            testCase.verifyEqual(info.num_spikes(:)', [4 2 3], 'Per-cluster spike counts incorrect.');

            % tags
            testCase.verifyEqual(sort(cellstr(info.unique_tags)), {'good';'mua';'noise'}, ...
                'Unique tags should be good, mua, noise.');
            testCase.verifyEqual(sum(info.tag_counts), 3, 'Tag counts should sum to the cluster count.');

            % default quality_labels are good+mua -> 2 clusters would import; noise excluded
            testCase.verifyEqual(info.num_would_import, 2, ...
                'good+mua should import 2 of 3 clusters by default.');

            % template dimensions
            testCase.verifyEqual(info.num_templates, 3, 'Should report 3 templates.');
            testCase.verifyEqual(info.samples_per_template, 5, 'Should report 5 samples per template.');
            testCase.verifyEqual(info.num_channels, 4, 'Should report 4 channels.');

            % summary is a non-empty multiline char array
            testCase.verifyTrue(ischar(summary), 'Summary should be a char array.');
            testCase.verifyTrue(contains(summary, newline), 'Summary should be multiline.');
            testCase.verifyTrue(contains(summary, 'mock_probe'), 'Summary should name the probe.');
            testCase.verifyTrue(contains(summary, 'noise'), 'Summary should list the noise tag.');
        end

        function testCustomQualityLabels(testCase)
            % If we only want 'noise', exactly one cluster would import.
            info = ndi.fun.probe.import.kilosort.getInfo(testCase.S, testCase.probe, ...
                'quality_labels', "noise");
            testCase.verifyEqual(info.num_would_import, 1, ...
                'Only the noise cluster should be flagged for import.');
        end

        function testMissingDirectoryErrors(testCase)
            badS = struct('path', tempname); % nonexistent
            testCase.verifyError(@() ndi.fun.probe.import.kilosort.getInfo(badS, testCase.probe), ...
                ?MException, 'A missing kilosort directory should raise an error.');
        end

    end

    methods (Static)
        function writeNPY(fname, arr, dtypeName)
            % Minimal .npy writer for fixtures (little-endian, C-order).
            switch dtypeName
                case 'int32',  tc='<i4'; prec='int32';
                case 'int64',  tc='<i8'; prec='int64';
                case 'double', tc='<f8'; prec='double';
                otherwise, error('unsupported dtype %s', dtypeName);
            end
            if isvector(arr)
                shp = ['(' num2str(numel(arr)) ',)'];
                flat = arr(:);
            else
                sz = size(arr);
                shp = ['(' strjoin(arrayfun(@num2str,sz,'UniformOutput',false), ', ') ')'];
                nd = ndims(arr);
                flat = reshape(permute(arr, nd:-1:1), [], 1); % C order
            end
            header = ['{''descr'': ''' tc ''', ''fortran_order'': False, ''shape'': ' shp ', }'];
            total = 10 + numel(header) + 1; % 6 magic +2 ver +2 len +header +\n
            pad = ceil(total/64)*64 - total;
            header = [header repmat(' ',1,pad) char(10)];
            fid = fopen(fname,'w','l');
            fwrite(fid,[uint8(hex2dec('93')) uint8('NUMPY') uint8(1) uint8(0)],'uint8');
            fwrite(fid, numel(header), 'uint16');
            fwrite(fid, header, 'char');
            fwrite(fid, flat, prec);
            fclose(fid);
        end
    end
end
