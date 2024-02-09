function filePath = getOpenmindsInstanceFile(filename)
    
    % Todo: Return a folder where to save openminds jsons. Right now,
    % instances are saved as structs to a matfile.
    
    folderPath = fullfile(userpath, 'NDIDatasetUpload', 'openMINDS', 'UserInstances');
    if ~isfolder(folderPath); mkdir(folderPath); end
    
    filePath = fullfile(folderPath, filename);
end