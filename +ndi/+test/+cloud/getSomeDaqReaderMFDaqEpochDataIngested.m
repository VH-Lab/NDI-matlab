function fileStruct = getSomeDaqReaderMFDaqEpochDataIngested(doc, dataset)
% GETSOMEDAQREADERMFDAQEPOCHDATAINGESTED
%
% FILESTRUCT = GETSOMEDAQREADERMFDAQEPOCHDATAINGESTED(DOC, DATASET)
%
% Loads data from an ndi.document of class
% 'daqreader_mfdaq_epochdata_ingested' and copies the files to temporary
% locations:
%  
% FILESTRUCT is a structure with fields corresponding to file names:
%    'channel_list_bin' - channel_list.bin
%    'ai_group1_seg_nbf_1' - ai_group1_seg.nbf_1
%    'ai_group1_seg_nbf_2' - ai_group1_seg.nbf_2
%    'ao_group1_seg_nbf_1' - ao_group1_seg.nbf_1
%    'ao_group1_seg_nbf_2' - ao_group1_seg.nbf_2
%

arguments
    doc (1,1) ndi.document
    dataset (1,1) ndi.dataset
end

assert(strcmp(doc_class(doc),'daqreader_mfdaq_epochdata_ingested'));

fileStructFields = {'channel_list_bin',...
    'ai_group1_seg_nbf_1', ...
    'ai_group1_seg_nbf_2', ... 
    'ao_group1_seg_nbf_1', ...
    'ao_group1_seg_nbf_2' ...
    };
filelist = { 'channel_list.bin', ...
    'ai_group1_seg.nbf_1', ...
    'ai_group1_seg.nbf_2', ...
    'ao_group1_seg.nbf_1', ...
    'ao_group1_seg.nbf_2' ...
    };

fileStruct = struct();

for i=1:numel(filelist)
    bd = dataset.database_openbinarydoc(doc,filelist{i});
    [fid,fname] = ndi.file.temp_fid();
    while ~feof(bd)
        a=fread(bd,1000,'uint8');
        fwrite(fid,a,'uint8');
    end
    fclose(fid);
    fileStruct = setfield(fileStruct,fileStructFields{i},fname);
end





