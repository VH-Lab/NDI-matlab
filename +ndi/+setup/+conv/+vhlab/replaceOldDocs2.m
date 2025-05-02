function b = replaceOldDocs(workingSessionDir, copiedSessionDir)


docFile = [copiedSessionDir filesep 'documents' filesep 'copied_documents.mat'];
docFile2 = [copiedSessionDir filesep 'documents' filesep 'copied_documents2.mat'];

load(docFile);


S = ndi.session.dir(workingSessionDir)

pD = S.database_search(ndi.query('','isa','stimulus_presentation'));

stimulator_probe = S.getprobes('type','stimulator');

stimulator_probe = stimulator_probe{1}

if ~isempty(pD)
    disp('Working on stimulus presentations...')
    decode = ndi.app.stimulus.decoder(S);
    pdNew = decode.parse_stimuli(stimulator_probe, 1);
else
    pdNew = {};
end

for i=1:numel(pdNew)
    match = 0;
    for j=1:numel(modified_docs)
        if strcmp(modified_docs{j}.document_properties.document_class.class_name,...
                pdNew{i}.document_properties.document_class.class_name)
            if isequal(pdNew{i}.document_properties.stimulus_presentation.presentation_order,...
                modified_docs{j}.document_properties.stimulus_presentation.presentation_order)
                if strcmp(pdNew{i}.document_properties.epochid.epochid,...
                    modified_docs{j}.document_properties.epochid.epochid)
                    match = j;
                    break;
                end
            end
        end
    end
    if match>0
        disp(['Copying into old document ' int2str(j) '.']);
        pdNew{i} = pdNew{i}.setproperties('base',modified_docs{j}.document_properties.base);

 % GEMINI: here you should write the files from pdNew{:} to the
 % copiedSessionDir/files directory
 % GEMINI: here you should reset the file information in pdNew{:} and 
 % add back the files you copied (now in the copiedSessionDir/files with add_file

        modified_docs{j} = pdNew{i}; % update the modified list
    end
end

b = 1;

 % now re-save

 save(docFile2,'modified_docs'); % while we are debugging

