function testCloudApiPart(partIdx, numParts)
%testCloudApiPart Run a partition of the ndi.unittest.cloud test suite.
%
%   testCloudApiPart(PARTIDX, NUMPARTS) builds the full TestSuite from the
%   ndi.unittest.cloud package (including subpackages), groups tests by their
%   defining test class, splits the sorted list of unique test classes into
%   NUMPARTS contiguous chunks, and runs only the chunk identified by PARTIDX
%   (1-indexed). The final partition (PARTIDX == NUMPARTS) absorbs any
%   remainder so every test class is covered by exactly one partition.
%
%   A small manual override table (manualPartOverrides) then pins a few
%   file-upload-heavy classes to specific partitions so wall time on the
%   NUMPARTS-way split stays roughly balanced. Historically Part 2 ran
%   ~13 min while Part 1 was ~7 min and Part 3 was ~4.5 min because the
%   default alphabetical chunking dropped every full-upload-cycle class
%   (TestPublishWithDocsAndFiles, bulkUploadsJobInfoTest, SignedURLSetTest,
%   ...) into the middle chunk. Reassigning the heaviest of those to
%   Part 3 evens the split without changing the algorithm for the rest.
%   New classes still land in their alphabetical chunk automatically; add
%   an entry to manualPartOverrides only when a class shows up as a
%   sustained bottleneck.

    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner

    if ischar(partIdx) || isstring(partIdx)
        partIdx = double(string(partIdx));
    end
    if ischar(numParts) || isstring(numParts)
        numParts = double(string(numParts));
    end
    assert(numParts >= 1 && partIdx >= 1 && partIdx <= numParts, ...
        'Invalid partIdx=%d for numParts=%d', partIdx, numParts);

    projectRootDir = nditools.projectdir();
    nditools.installRequirements(fullfile(projectRootDir, 'tests'))

    suite = TestSuite.fromPackage('ndi.unittest.cloud', ...
        'IncludingSubpackages', true);

    classNames = strings(numel(suite), 1);
    for ii = 1:numel(suite)
        classNames(ii) = string(extractBefore(suite(ii).Name, '/'));
    end

    uniqueClasses = unique(classNames);  % sorted ascending
    nClasses = numel(uniqueClasses);

    % 1. Default assignment: contiguous chunks over the sorted class list.
    chunkSize = floor(nClasses / numParts);
    partAssignment = zeros(nClasses, 1);
    for p = 1:numParts
        s = (p - 1) * chunkSize + 1;
        if p == numParts
            e = nClasses;
        else
            e = p * chunkSize;
        end
        partAssignment(s:e) = p;
    end

    % 2. Apply manual overrides.
    [overrideNames, overridePart] = manualPartOverrides(numParts);
    overrideApplied = strings(0, 1);
    for i = 1:numel(overrideNames)
        idx = find(uniqueClasses == overrideNames(i), 1);
        if ~isempty(idx) && overridePart(i) >= 1 && overridePart(i) <= numParts
            if partAssignment(idx) ~= overridePart(i)
                overrideApplied(end+1, 1) = overrideNames(i); %#ok<AGROW>
            end
            partAssignment(idx) = overridePart(i);
        end
    end

    selectedClasses = uniqueClasses(partAssignment == partIdx);
    mask = ismember(classNames, selectedClasses);
    partitionSuite = suite(mask);

    fprintf('Cloud CI part %d of %d: %d of %d test classes, %d test items\n', ...
        partIdx, numParts, numel(selectedClasses), nClasses, numel(partitionSuite));
    for ii = 1:numel(selectedClasses)
        fprintf('  - %s\n', selectedClasses(ii));
    end
    if ~isempty(overrideApplied)
        fprintf('  (manual overrides applied to this run: %d class(es))\n', ...
            numel(overrideApplied));
        for ii = 1:numel(overrideApplied)
            fprintf('    * %s\n', overrideApplied(ii));
        end
    end

    runner = TestRunner.withTextOutput('OutputDetail', 'Detailed');
    results = runner.run(partitionSuite);
    display(results)
    results.assertSuccess()
end

function [names, parts] = manualPartOverrides(numParts)
%MANUALPARTOVERRIDES Pin specific test classes to specific partitions.
%
%   Only active for the 3-way split the Cloud CI workflow runs; other
%   partition counts fall back to the pure alphabetical chunking above.
%   Entries here override the default assignment ONLY for classes that
%   actually exist in the suite; a name that no longer matches is a
%   no-op, so cleanup on class deletion is not urgent.
%
%   Observed per-part "Run tests" wall time on main (avg of 4 recent
%   successful runs before this override):
%      Part 1: ~7m   Part 2: ~13m   Part 3: ~4.5m
%   The overrides below move three full-upload-cycle classes out of
%   Part 2 and into Part 3, so the tail (Part 2) shrinks and Part 3
%   grows to meet it. Re-measure and adjust when a new heavy class
%   is added.

    names = strings(0, 1);
    parts = zeros(0, 1);
    if numParts ~= 3
        return;
    end

    entries = { ...
        "ndi.unittest.cloud.SignedURLSetTest",              3; ...
        "ndi.unittest.cloud.TestPublishWithDocsAndFiles",   3; ...
        "ndi.unittest.cloud.bulkUploadsJobInfoTest",        3; ...
    };
    names = string(vertcat(entries{:, 1}));
    parts = cell2mat(entries(:, 2));
end
