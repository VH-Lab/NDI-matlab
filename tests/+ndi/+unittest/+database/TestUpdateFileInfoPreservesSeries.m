classdef TestUpdateFileInfoPreservesSeries < matlab.unittest.TestCase
    % ndi.cloud.sync.internal.updateFileInfoForLocalFiles must not destroy
    % files.series_info.
    %
    % This is NDI-matlab#945, and it is ours, not the server's. The function
    % runs on every downloaded document when SyncFiles is true, to repoint
    % file locations at the freshly downloaded copies:
    %
    %     originalFileInfo = document.document_properties.files.file_info;
    %     document = document.reset_file_info();
    %     for i = 1:numel(originalFileInfo)
    %         ... document = document.add_file(filename, file_location);
    %     end
    %
    % did.document/reset_file_info clears file_info AND series_info -- it says
    % so in its own comment, "A series' per-instance record is reset with the
    % rest". The loop then repopulates file_info only. series_info is left as
    % the empty struct the reset installed, so a downloaded document reports
    % zero members for a populated series.
    %
    % It is silent: isFileSeries still returns true, because that reads
    % files.file_series, the class declaration from the schema, which the
    % reset deliberately leaves alone. Only seriesCount notices, and it
    % returns 0 rather than erroring.
    %
    % No credentials and no network: this calls the function directly with a
    % local directory standing in for the download folder.

    properties (Constant)
        MemberCount = 4;
    end

    properties
        MemberPaths (1,:) cell = {}
        FileDir
    end

    methods (TestMethodSetup)
        function setupDocumentAndFiles(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            memberDir = fullfile(pwd, 'level0');
            mkdir(memberDir);
            testCase.MemberPaths = cell(1, testCase.MemberCount);
            for i = 1:testCase.MemberCount
                p = fullfile(memberDir, sprintf('chunk_%04d.bin', i));
                fid = fopen(p, 'w');
                fwrite(fid, uint8(mod((1:16) * i, 251)), 'uint8');
                fclose(fid);
                testCase.MemberPaths{i} = p;
            end

            % Stands in for the folder downloadNdiDocuments passes as
            % filesTargetFolder.
            testCase.FileDir = fullfile(pwd, 'downloaded');
            mkdir(testCase.FileDir);
        end
    end

    methods (Access = private)
        function doc = makeSeriesDocumentWithAFile(testCase)
            % A document carrying both an ordinary file and a series, because
            % the function under test walks file_info and the bug is that it
            % ignores everything else under files.
            manifestPath = fullfile(pwd, 'chunkdata.bin');
            fid = fopen(manifestPath, 'w'); fwrite(fid, uint8(1:8)); fclose(fid);

            doc = ndi.document('demoNDISeries', ...
                'base.name', 'series_reset_doc', ...
                'demoNDISeries.value', 1, ...
                'base.session_id', did.ido.unique_id());
            doc = doc.addFileSeries('chunkdata.bin', testCase.MemberPaths);
        end

        function placeDownloadedCopies(testCase, doc)
            % updateFileInfoForLocalFiles only restores entries whose uid it
            % finds on disk, so put a file at fileDirectory/<uid> for each.
            fi = doc.document_properties.files.file_info;
            for i = 1:numel(fi)
                uid = fi(i).locations(1).uid;
                p = fullfile(testCase.FileDir, uid);
                fid = fopen(p, 'w'); fwrite(fid, uint8(1:8)); fclose(fid);
            end
        end
    end

    methods (Test)

        function testSeriesCountIsIntactBeforeTheUpdate(testCase)
            % Control. If this fails the rest says nothing.
            doc = testCase.makeSeriesDocumentWithAFile();
            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, testCase.MemberCount);
            testCase.verifyEqual(nPresent, testCase.MemberCount);
        end

        function testUpdateFileInfoForLocalFilesKeepsTheSeriesRecord(testCase)
            % THE BUG. Currently fails: series_info comes back empty.
            doc = testCase.makeSeriesDocumentWithAFile();
            testCase.placeDownloadedCopies(doc);

            updated = ndi.cloud.sync.internal.updateFileInfoForLocalFiles( ...
                doc, testCase.FileDir);

            testCase.onFailure(@() disp(updated.document_properties.files));

            hasSeriesInfo = isfield(updated.document_properties.files, 'series_info') && ...
                ~isempty(updated.document_properties.files.series_info);
            testCase.verifyTrue(hasSeriesInfo, ...
                ['files.series_info was emptied. reset_file_info clears it ' ...
                 'along with file_info, and the repopulation loop only ' ...
                 'restores file_info. See NDI-matlab#945.']);

            [n, nPresent] = updated.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, testCase.MemberCount, ...
                'series member count did not survive updateFileInfoForLocalFiles');
            testCase.verifyEqual(nPresent, testCase.MemberCount, ...
                'series present-count did not survive updateFileInfoForLocalFiles');
        end

        function testTheDeclarationSurvivesWhichIsWhyTheLossIsSilent(testCase)
            % isFileSeries reads files.file_series, the class declaration,
            % which reset_file_info deliberately leaves alone. So a caller
            % gets "yes this is a series" and "it has 0 members" together,
            % with no error anywhere. Pinning this explains the failure mode
            % to whoever reads it next.
            doc = testCase.makeSeriesDocumentWithAFile();
            testCase.placeDownloadedCopies(doc);

            updated = ndi.cloud.sync.internal.updateFileInfoForLocalFiles( ...
                doc, testCase.FileDir);

            testCase.verifyTrue(updated.isFileSeries('chunkdata.bin'), ...
                'the class declaration should survive; it comes from the schema');
        end

        function testFileInfoIsRepointedAtTheDownloadFolder(testCase)
            % What the function is FOR, and the thing I misread as evidence
            % that the server preserved file_info: after this call, locations
            % point into the download folder, not at the original paths.
            doc = testCase.makeSeriesDocumentWithAFile();
            testCase.placeDownloadedCopies(doc);

            updated = ndi.cloud.sync.internal.updateFileInfoForLocalFiles( ...
                doc, testCase.FileDir);

            fi = updated.document_properties.files.file_info;
            testCase.assertNotEmpty(fi, 'file_info should have been repopulated');
            testCase.verifyTrue(startsWith(fi(1).locations(1).location, testCase.FileDir), ...
                'file_info should now point into the download folder');
        end

    end
end
