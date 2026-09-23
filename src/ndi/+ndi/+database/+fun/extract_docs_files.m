function [docs,target_path] = extract_docs_files(ndi_session_obj, target_path, options)
    % EXTRACT_DOCS_FILES - extract a copy of all ndi.documents and files to path
    %
    % [DOCS,TARGET_PATH] = EXTRACT_DOCS_FILES(NDI_SESSION_OBJ, [TARGET_PATH], ...)
    %
    % Copies the ndi.document objects from an ndi.session object or an
    % ndi.dataset object. Returns the documents in DOCS with each file
    % location set so that a subsequent database_add lands the bytes in the
    % destination store.
    %
    % FILE HANDLING. There are two ways the returned documents can point at
    % their bytes, selected by 'ReferenceInPlace':
    %
    %   * REFERENCE IN PLACE (the default when TARGET_PATH is not given).
    %     Each file location is pointed AT THE SOURCE SESSION'S EXISTING file
    %     on disk, with delete_original set to 0. A later database_add then
    %     copies each file exactly once, directly from the source into the
    %     destination store, and leaves the source untouched. This is what a
    %     dataset ingest wants: it avoids staging a second full copy of every
    %     file in a temporary directory first, so the operation no longer
    %     transiently needs 2x the session's disk space (and no longer piles
    %     that copy onto whatever volume holds tempdir). See
    %     ndi.dataset.copySessionToDataset.
    %
    %   * COPY (the default when a TARGET_PATH is given, and the behavior for
    %     any file whose bytes are NOT on the local filesystem). The files
    %     associated with the documents DOCS are copied into the directory
    %     TARGET_PATH. If TARGET_PATH is not given, a subdirectory inside
    %     ndi.common.PathConstants.TempFolder is used and the path is
    %     returned as an output.
    %
    % Reference in place applies ONLY to files whose bytes are present on the
    % LOCAL filesystem, which database_existbinarydoc reports without going
    % to the network. A file that is not local -- a member of a cloud-backed
    % session that has not been fetched to this machine -- has nothing local
    % to reference, so it falls back to the copy path (a temp directory is
    % created on demand if one is needed). A cloud-backed session therefore
    % behaves as it did before this option existed.
    %
    % Options:
    %   ReferenceInPlace (logical) - if true, reference source files in place
    %       rather than copying them. The default is true when TARGET_PATH is
    %       not supplied and false when it is (supplying a TARGET_PATH means
    %       "put copies there").
    %
    % FILE SERIES. A series' manifest is an ordinary document file and is
    % handled like one, and the series record (name, count, n_present,
    % source_root) travels with it. The MEMBERS are handled too, which
    % current_file_list does not cover: it returns the manifest name only, so
    % the members are enumerated from the series record instead and fetched by
    % their NAME_<i> names, which resolve through the manifest
    % (VH-Lab/DID-matlab#173, #183).
    %
    % Each member is recorded in the extracted document's ingest_locations
    % UNDER ITS ORIGINAL UID. That is what lets the copy be stored somewhere
    % else: did.implementations.sqlitedb refuses a document declaring present
    % members while recording no location for any of them
    % (VH-Lab/DID-matlab#185), and ingestion writes each member to
    % FileDir/<uid> from this record, so reusing the uid keeps the copied
    % manifest -- which names members by uid -- correct in the new store.
    %

    arguments
        ndi_session_obj
        target_path = ''
        options.ReferenceInPlace = []
    end

    target_path = char(target_path);

    % Reference in place by default only when no target_path was asked for.
    % A caller who names a target_path is asking for copies there.
    reference_in_place = options.ReferenceInPlace;
    if isempty(reference_in_place)
        reference_in_place = isempty(target_path);
    end
    reference_in_place = logical(reference_in_place);

    % In copy mode with no target_path, stage into a temp directory. In
    % reference-in-place mode the temp directory is created lazily, only if a
    % non-local file forces a fall-back copy (see ensure_copy_target below).
    if ~reference_in_place && isempty(target_path)
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

                % Is the file's bytes on the local filesystem? database_existbinarydoc
                % answers from local state only -- it never goes to the network --
                % so a true answer means we can reference the source file directly.
                local_path = '';
                if reference_in_place
                    [tf_local,local_candidate] = ...
                        ndi_session_obj.database_existbinarydoc(doc_id,file_info_here.file_name);
                    if tf_local && ~isempty(local_candidate) && isfile(local_candidate)
                        local_path = local_candidate;
                    end
                end

                if ~isempty(local_path)
                    % Reference the source file in place. delete_original 0:
                    % this is the source session's own file, not a copy we
                    % made, so a later database_add must copy it into the
                    % destination store WITHOUT removing it here. It is
                    % deliberately NOT added to files_I_made -- the error
                    % cleanup deletes what it made, never the source.
                    file_info_here.fullpathfilename = local_path;
                    docs{i} = docs{i}.add_file(file_info_here.file_name, local_path, ...
                        'delete_original', 0);
                else
                    % Copy the file into TARGET_PATH, creating a temp directory
                    % on demand when we are otherwise referencing in place.
                    target_path = ensure_copy_target(target_path);
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
                    docs{i} = docs{i}.add_file(file_info_here.file_name,file_info_here.fullpathfilename);
                end

                file_info(end+1) = file_info_here;
            end

            if hasSeriesInfo
                % Handle the members. current_file_list does not name them --
                % it returns the manifest only, deliberately, so that a
                % 28,000-member series does not materialise 28,000 names --
                % so walk the slots the series record declares and fetch each
                % by its NAME_<i> name, which resolves through the manifest.
                % An absent slot is normal: a sparse series is the case the
                % mechanism exists for.
                % One cell per series, concatenated into files_I_made once
                % after the loop rather than per series. Only files this
                % function actually COPIED go in it; a referenced-in-place
                % member is the source's own file and must never be deleted.
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
                    copiedCount = 0;

                    for m = 1:slotCount
                        memberName = sprintf('%s_%d',seriesName,m);
                        % database_existbinarydoc reports the member's LOCAL
                        % path (via the manifest) without retrieving anything,
                        % so a miss here is a member whose bytes are not on
                        % this machine -- skip it, exactly as before.
                        [memberExists,memberPath] = ...
                            ndi_session_obj.database_existbinarydoc(doc_id_here,memberName);
                        if ~memberExists || isempty(memberPath)
                            continue;
                        end
                        % Keep the ORIGINAL uid: ingestion writes the member to
                        % FileDir/<uid> from this record, and the manifest we
                        % just carried over names its members by uid, so a
                        % fresh uid would leave the copy's manifest pointing at
                        % nothing.
                        [~,memberUid,~] = fileparts(memberPath);

                        if reference_in_place
                            % Reference the member in place: point at the
                            % source file, do not copy, do not delete.
                            memberLocation = memberPath;
                        else
                            % Copy the member into TARGET_PATH.
                            target_path = ensure_copy_target(target_path);
                            memberLocation = [target_path filesep memberUid];
                            try
                                copyfile(memberPath,memberLocation);
                            catch copyError
                                % Members copied for this series, and for
                                % earlier series of this document, are not in
                                % files_I_made yet -- clean them up alongside
                                % it. Empty cells (referenced-in-place members)
                                % are filtered so delete() is never handed ''.
                                madeSoFar = [files_I_made seriesMemberFiles{:} ...
                                    memberFiles(1:memberCount)];
                                madeSoFar = madeSoFar(~cellfun(@isempty,madeSoFar));
                                for j=1:numel(madeSoFar)
                                    delete(madeSoFar{j});
                                end
                                error(['Extraction failed: ' copyError.message]);
                            end
                            copiedCount = copiedCount + 1;
                            memberFiles{copiedCount} = memberLocation;
                        end

                        memberCount = memberCount + 1;
                        % delete_original 0: whether this is our copy in
                        % TARGET_PATH or a reference to the source, the caller
                        % was promised the files would still be there.
                        memberEntries(memberCount) = struct('index',m, ...
                            'uid',memberUid,'location',memberLocation, ...
                            'location_type','file','ingest',1, ...
                            'delete_original',0,'parameters','');
                    end

                    % An absent slot leaves a hole, so trim to what was
                    % actually recorded; a sparse series is normal. memberFiles
                    % holds only the copies (empty in reference-in-place mode).
                    seriesInfo(s).ingest_locations = memberEntries(1:memberCount);
                    seriesMemberFiles{s} = memberFiles(1:copiedCount);
                end
                files_I_made = [files_I_made seriesMemberFiles{:}];

                docs{i} = docs{i}.setproperties('files.series_info',seriesInfo);
            end
        end
    end
end

function target_path = ensure_copy_target(target_path)
    % ENSURE_COPY_TARGET - make sure there is a directory to copy files into
    %
    % Creates a temporary directory the first time a copy is needed while
    % otherwise referencing files in place, so that reference-in-place does
    % not create a temp directory it never uses.
    if isempty(target_path)
        target_path = ndi.file.temp_name();
        mkdir(target_path);
    end
end
