classdef SyncModeDispatchTest < matlab.unittest.TestCase
    %SyncModeDispatchTest Offline regression test for the SyncMode dispatch path.
    %
    %   ndi.cloud.syncDataset dispatches a sync operation through
    %   ndi.cloud.sync.enum.SyncMode/execute, which forwards the SyncOptions to
    %   the selected ndi.cloud.sync.* function as name-value arguments. The
    %   forwarding previously called a non-existent SyncOptions.nvpairs() method
    %   (it is toCell()) and passed the result without {:} expansion, so every
    %   sync invoked through syncDataset errored before doing any work.
    %
    %   The existing DownloadNewTest/UploadNewTest/... call the sync functions
    %   DIRECTLY and require a live cloud dataset, so they never exercised the
    %   SyncMode.execute forwarding contract. These tests do, with no network:
    %   they assert that SyncOptions.toCell() yields name-value pairs that, when
    %   expanded with {:}, are accepted by a sync-style arguments block exactly
    %   as SyncMode.execute forwards them.

    methods (Test)

        function testToCellShape(testCase)
            % toCell returns a 1-by-2N cell of interleaved name,value pairs.
            opts = ndi.cloud.sync.SyncOptions();
            c = opts.toCell();
            propNames = properties(opts);
            testCase.verifyEqual(numel(c), 2*numel(propNames), ...
                'toCell() must return one name and one value per property.');
            testCase.verifyTrue(isrow(c), 'toCell() must return a row cell.');
            % Names occupy the odd positions and cover every public property.
            testCase.verifyEqual(sort(c(1:2:end)), sort(propNames(:)'), ...
                'toCell() names must match the SyncOptions properties.');
        end

        function testToCellExpandsAsNameValueArguments(testCase)
            % The exact forwarding contract of SyncMode.execute:
            %   nvPairs = syncOptions.toCell(); fcn(ndiDataset, nvPairs{:})
            % Expanding with {:} must hand the values to a name-value
            % arguments block (here a local stand-in for a sync function).
            opts = ndi.cloud.sync.SyncOptions();
            opts.SyncFiles = true;
            opts.Verbose = false;
            opts.DryRun = true;
            opts.FileUploadStrategy = "serial";

            nvPairs = opts.toCell();
            received = ndi.unittest.cloud.sync.SyncModeDispatchTest.acceptSyncOptions( ...
                'a_dataset_placeholder', nvPairs{:});

            testCase.verifyEqual(received.SyncFiles, true);
            testCase.verifyEqual(received.Verbose, false);
            testCase.verifyEqual(received.DryRun, true);
            testCase.verifyEqual(received.FileUploadStrategy, "serial");
        end

        function testToCellRoundTripsToSyncOptions(testCase)
            % toCell() -> struct -> SyncOptions reconstructs the same options,
            % which is what each sync function's `opts.?SyncOptions` block does
            % with the forwarded name-value pairs.
            opts = ndi.cloud.sync.SyncOptions();
            opts.SyncFiles = true;
            opts.FileUploadStrategy = "serial";

            c = opts.toCell();
            opts2 = ndi.cloud.sync.SyncOptions(struct(c{:}));

            testCase.verifyEqual(opts2.SyncFiles, opts.SyncFiles);
            testCase.verifyEqual(opts2.Verbose, opts.Verbose);
            testCase.verifyEqual(opts2.DryRun, opts.DryRun);
            testCase.verifyEqual(opts2.FileUploadStrategy, opts.FileUploadStrategy);
        end

        function testSyncModeFunctionsResolve(testCase)
            % Every SyncMode maps to a real ndi.cloud.sync.* function handle so
            % the dispatch in SyncMode.execute reaches an existing function.
            for m = enumeration('ndi.cloud.sync.enum.SyncMode')'
                testCase.verifyClass(m.Function, 'function_handle');
                testCase.verifyEqual(exist(func2str(m.Function), 'file') > 0 ...
                    || ~isempty(which(func2str(m.Function))), true, ...
                    sprintf('SyncMode %s points at a missing function %s', ...
                    char(m), func2str(m.Function)));
            end
        end
    end

    methods (Static)
        function received = acceptSyncOptions(ndiDataset, options)
            % Local stand-in for a sync function: a name-value arguments block
            % matching SyncOptions, mirroring `opts.?ndi.cloud.sync.SyncOptions`.
            arguments
                ndiDataset %#ok<INUSA>
                options.SyncFiles (1,1) logical
                options.Verbose (1,1) logical
                options.DryRun (1,1) logical
                options.FileUploadStrategy (1,1) string
            end
            received = options;
        end
    end
end
