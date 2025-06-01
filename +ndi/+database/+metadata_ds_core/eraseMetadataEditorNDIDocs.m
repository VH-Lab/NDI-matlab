function [hadPreviousDocs, previousDocsDeleted] = eraseMetadataEditorNDIDocs(D_in, askUser)
    % ERASENMETADATAEDITORNDIDOCS - Deletes existing metadata documents from an NDI dataset.
    %
    % [HADPREVIOUSDOCS, PREVIOUSDOCSDELETED] = ...
    %   ndi.database.metadata_ds_core.eraseMetadataEditorNDIDocs(D_IN, ASKUER)
    %
    % Inputs:
    %   D_IN - An ndi.dataset object.
    %   ASKUSER - (Optional) Boolean. If true (default), prompts the user before deleting
    %             documents. If false, deletes without prompting.
    %
    % Outputs:
    %   HADPREVIOUSDOCS - Boolean. True if any 'openminds.core.products.Dataset'
    %                     documents were found prior to deletion attempts.
    %   PREVIOUSDOCSDELETED - Boolean. True if previous documents were found and successfully
    %                         deleted (or if the user confirmed deletion). False if no
    %                         documents were found, or if the user declined deletion.
    %
    % See also: ndi.database.metadata_app.fun.save_dataset_docs

    arguments
        D_in (1,1) ndi.dataset
        askUser (1,1) logical = true % Default to asking the user
    end

    hadPreviousDocs = false;
    previousDocsDeleted = false;

    % Lines 13-14 from save_dataset_docs.m
    oldDocs = D_in.database_search(ndi.query('openminds.matlab_type','exact_string','openminds.core.products.Dataset'));

    if ~isempty(oldDocs)
        hadPreviousDocs = true;
        answer = 'No'; % Default to no if not asking or if askUser is false and we proceed
        
        if askUser
            % Lines 16-19 from save_dataset_docs.m
            answer = questdlg('This will replace any previously saved core metadata information in the dataset. Continue?','Continue?','Yes','No','Yes');
        else
            answer = 'Yes'; % If not asking user, proceed with deletion
        end

        % Lines 21-23 from save_dataset_docs.m (modified for clarity)
        if strcmp(answer,'Yes')
            % Lines 25-28 from save_dataset_docs.m
            antecedents = ndi.database.fun.findallantecedents(D_in,[],oldDocs{:});
            D_in.database_rm(oldDocs);
            if ~isempty(antecedents) % Only remove if antecedents were found
                D_in.database_rm(antecedents);
            end
            previousDocsDeleted = true;
        else
            % User said no, or default 'No' if askUser was true and no dialog shown (should not happen with questdlg)
            previousDocsDeleted = false; 
        end
    else
        % No oldDocs found
        hadPreviousDocs = false; 
        previousDocsDeleted = false; % Or true, depending on interpretation - let's say false as nothing was to be deleted.
                                     % If no docs, then technically nothing was "deleted" that was previous.
                                     % If we consider "previous docs were deleted" to mean "the state is now clean of previous docs", then true.
                                     % Sticking to "were they actually deleted in this run".
    end
end
