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
    % source_root) travels with it. The MEMBERS are copied too, which
    % current_file_list does not cover: it returns the manifest name only, so
    % the members are enumerated from the series record instead and fetched by
    % their NAME_<i> names, which resolve through the manifest
    % (VH-Lab/DID-matlab#173, #183).
    %
    % Each copied member is recorded in the extracted document's
    % ingest_locations UNDER ITS ORIGINAL UID. That is what lets the copy be
    % stored somewhere else: did.implementations.sqlitedb refuses a document
    % declaring present members while recording no location for any of them
    % (VH-Lab/DID-matlab#185), and ingestion writes each member to
    % FileDir/<uid> from this record, so reusing the uid keeps the copied
    % manifest -- which names members by uid -- correct in the new store.
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
            doc_id_here = d{i}.document_properties.base.id;

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
                % Copy the members. current_file_list does not name them --
                % it returns the manifest only, deliberately, so that a
                % 28,000-member series does not materialise 28,000 names --
                % so walk the slots the series record declares and fetch each
                % by its NAME_<i> name, which resolves through the manifest.
                % An absent slot is normal: a sparse series is the case the
                % mechanism exists for.
                % One cell per series, concatenated into files_I_made once
                % after the loop rather than per series.
                seriesMemberFiles = repmat({{}},1,numel(seriesInfo));

                for s = 1:numel(seriesInfo)
                    seriesName = seriesInfo(s).name;
                    slotCount = 0;
                    if isfield(seriesInfo(s),'count') && ~isempty(seriesInfo(s).count)
                        slotCount = seriesInfo(s).count;
                    end

                    % Preallocated to the slot count and trimmed at the end
                    % rather than grown per member. A level of a lightsheet
                    % pyramid is tens of thousands of members, which is the
                    % case this whole mechanism exists for, so growing either
                    % of these one element at a time is a reallocation per
                    % member.
                    memberEntries = repmat(struct('index',0,'uid','', ...
                        'location','','location_type','file', ...
                        'ingest',1,'delete_original',0,'parameters',''),1,slotCount);
                    memberFiles = cell(1,slotCount);
                    memberCount = 0;

                    for m = 1:slotCount
                        memberName = sprintf('%s_%d',seriesName,m);
                        [memberExists,memberPath] = ...
                            ndi_session_obj.database_existbinarydoc(doc_id_here,memberName);
                        if ~memberExists || isempty(memberPath)
                            continue;
                        end
                        % Keep the ORIGINAL uid: ingestion writes the member to
                        % FileDir/<uid> from this record, and the manifest we
                        % just copied names its members by uid, so a fresh uid
                        % would leave the copy's manifest pointing at nothing.
                        [~,memberUid,~] = fileparts(memberPath);
                        memberDestination = [target_path filesep memberUid];
                        try
                            copyfile(memberPath,memberDestination);
                        catch copyError
                            % Members copied for this series, and for earlier
                            % series of this document, are not in files_I_made
                            % yet -- clean them up alongside it.
                            madeSoFar = [files_I_made seriesMemberFiles{:} ...
                                memberFiles(1:memberCount)];
                            for j=1:numel(madeSoFar)
                                delete(madeSoFar{j});
                            end
                            error(['Extraction failed: ' copyError.message]);
                        end

                        memberCount = memberCount + 1;
                        memberFiles{memberCount} = memberDestination;
                        % delete_original 0: these are our copies in
                        % TARGET_PATH, and the caller was promised the files
                        % would be there.
                        memberEntries(memberCount) = struct('index',m, ...
                            'uid',memberUid,'location',memberDestination, ...
                            'location_type','file','ingest',1, ...
                            'delete_original',0,'parameters','');
                    end

                    % An absent slot leaves a hole, so trim to what was
                    % actually copied; a sparse series is normal.
                    seriesInfo(s).ingest_locations = memberEntries(1:memberCount);
                    seriesMemberFiles{s} = memberFiles(1:memberCount);
                end
                files_I_made = [files_I_made seriesMemberFiles{:}];

                docs{i} = docs{i}.setproperties('files.series_info',seriesInfo);
            end
        end
    end
