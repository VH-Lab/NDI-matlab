function testCloudApiPart(partIdx, numParts)
%testCloudApiPart Run a partition of the ndi.unittest.cloud test suite.
%
%   testCloudApiPart(PARTIDX, NUMPARTS) builds the full TestSuite from the
%   ndi.unittest.cloud package (including subpackages), groups tests by their
%   defining test class, splits the sorted list of unique test classes into
%   NUMPARTS contiguous chunks, and runs only the chunk identified by PARTIDX
%   (1-indexed). The final partition (PARTIDX == NUMPARTS) absorbs any
%   remainder so every test class is covered by exactly one partition.

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
    matbox.installRequirements(fullfile(projectRootDir, 'tests'))

    suite = TestSuite.fromPackage('ndi.unittest.cloud', ...
        'IncludingSubpackages', true);

    classNames = strings(numel(suite), 1);
    for ii = 1:numel(suite)
        classNames(ii) = string(extractBefore(suite(ii).Name, '/'));
    end

    uniqueClasses = unique(classNames);  % sorted ascending
    nClasses = numel(uniqueClasses);
    chunkSize = floor(nClasses / numParts);
    startIdx = (partIdx - 1) * chunkSize + 1;
    if partIdx == numParts
        endIdx = nClasses;
    else
        endIdx = partIdx * chunkSize;
    end

    selectedClasses = uniqueClasses(startIdx:endIdx);
    mask = ismember(classNames, selectedClasses);
    partitionSuite = suite(mask);

    fprintf('Cloud CI part %d of %d: %d of %d test classes, %d test items\n', ...
        partIdx, numParts, numel(selectedClasses), nClasses, numel(partitionSuite));
    for ii = 1:numel(selectedClasses)
        fprintf('  - %s\n', selectedClasses(ii));
    end

    runner = TestRunner.withTextOutput('OutputDetail', 'Detailed');
    results = runner.run(partitionSuite);
    display(results)
    results.assertSuccess()
end
