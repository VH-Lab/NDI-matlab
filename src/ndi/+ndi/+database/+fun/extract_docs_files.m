function [docs,target_path] = extract_doc_files(ndi_session_obj, target_path)
    % EXTRACT_DOC_FILES - extract a copy of all ndi.documents and files to path
    %
    % [DOCS,TARGET_PATH] = EXTRACT_DOC_FILES(NDI_SESSION_OBJ, TARGET_PATH)
    %
    % Copies the ndi.document objects from an ndi.session object or an
    % ndi.dataset object. The files associated with the documents DOCS
    % will be placed in the directory TARGET_PATH.
    %
    % If TARGE_TPATH is not given, then a subdirectory inside
    % ndi.common.PathConstants.TempFolder is used and the path is returned as
    % an output.
    %
    % FILE SERIES. A series' manifest is an ordinary document file and is
    % copied like one, and the series record (name, count, n_present,
    % source_root) travels with it. The series MEMBERS are not copied:
    % current_file_list returns the manifest name only, and member ingestion is
    % not implemented yet (VH-Lab/DID-matlab#173), so there are no member files
    % in the source session's store to copy. An extracted document therefore
    % describes a series whose members are not in TARGET_PATH. Copying them
    % belongs here once ingestion records them.
    %

    if nargin<2
        target_path = ndi.file.temp_name();
        mkdir(target_path);
    end

    q_all = ndi.query('','isa','base');

    d = ndi_session_obj.database_search(q_all);

    files_I_made = {};

    docs = d;

    for i = 1:numel(d)
        % has_files() rather than isfield(...,'files'): the latter is true for
        % a document that declares files but has added none, and the loop
        % below has nothing to do for one. It would still call
        % reset_file_info, which for such a document is pure destruction.
        if docs{i}.has_files()
            file_info = did.datastructures.emptystruct('file_name','fullpathfilename');
            fl = docs{i}.current_file_list();

            % reset_file_info clears files.series_info along with file_info --
            % see did.document/reset_file_info, "A series' per-instance record
            % is reset with the rest". The loop below restores file_info only,
            % so without this the extracted copy loses the per-series record
            % and reports zero members for a populated series. Silently:
            % isFileSeries reads files.file_series, the class declaration,
            % which the reset leaves alone, so only seriesCount notices and it
            % returns 0 rather than erroring. See VH-Lab/NDI-matlab#946.
            %
            % Carried across: name, count, n_present and source_root. The
            % counts describe the SERIES, not where its bytes are, and the
            % manifest that lists the members is copied verbatim below, so
            % dropping them would leave seriesCount contradicting the manifest
            % sitting next to it. source_root is the root those manifest
            % entries are relative to, so it travels with them.
            %
            % NOT carried across: ingest_locations, which name where the
            % members sit in the SOURCE session and mean nothing in the target
            % path. Emptied with did.document.stripSeriesIngestLocations, the
            % same call the database makes on the way into storage -- which is
            % why this is a no-op for every document database_search returns
            % today. It is here because an extract's output gets stored
            % somewhere else (see ndi.dataset.copySessionToDataset), and a copy
            % destined for another store should carry no path into the source.
            seriesInfo = [];
            hasSeriesInfo = isfield(docs{i}.document_properties.files,'series_info') && ...
                ~isempty(docs{i}.document_properties.files.series_info);
            if hasSeriesInfo
                strippedProperties = did.document.stripSeriesIngestLocations( ...
                    docs{i}.document_properties);
                seriesInfo = strippedProperties.files.series_info;
            end

            docs{i} = docs{i}.reset_file_info;
            for f = 1:numel(fl)
                file_info_here = [];
                file_info_here.file_name = fl{f};
                doc_id = d{i}.document_properties.base.id;
                file_obj = ndi_session_obj.database_openbinarydoc(doc_id,file_info_here.file_name);
                [~,uid,~] = fileparts(file_obj.fullpathfilename);
                file_info_here.fullpathfilename = [target_path filesep uid];
                try
                    copyfile(file_obj.fullpathfilename,file_info_here.fullpathfilename);
                    files_I_made{end+1} = file_info_here.fullpathfilename;
                catch
                    % probably disk space error or something, bail out
                    % try to recover some of the user's precious disk space
                    for j=1:numel(files_I_made)
                        delete(files_I_made{j});
                    end
                    error(['Extraction failed: ' lasterr]);
                end

                file_info(end+1) = file_info_here;
                docs{i} = docs{i}.add_file(file_info_here.file_name,file_info_here.fullpathfilename);
            end

            if hasSeriesInfo
                docs{i} = docs{i}.setproperties('files.series_info',seriesInfo);
            end
        end
    end
