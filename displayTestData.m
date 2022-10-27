function displayTestData()
    scr_siz = get(0,'ScreenSize') ;
    figure('color', [0.8 0.8 0.8], 'Position', floor([scr_siz(3)/4 scr_siz(4)/4 scr_siz(3)/1.5 scr_siz(4)/1.5]));
    title('select document simple gui');
    axis off;
    data = testData();
    docs = load('SomeDocuments.mat');
    data.addDoc(docs.documents);
    
%   These 2 can be used directly:
%     data.clearView();
%     data.restore();

%   searchFieldName needs some user input:
%     data.searchFieldName('', '', 'depends_on');
    
%   filter needs a helper:
%     data.filterHelper(6, 2, 'a'); 
%   parameterinputs: search(1), search(2), search(3).String
%   search(1): {'Select' 'Name' 'ID' 'Type' 'Date' 'Other'}
%   search(2): {'Filter options' 'contains' 'begins with' 'ends with'}

    search_ID = ["41268a0b47c03d8d_40d047ed663bbf5e", "41268a0b47c0c811_c0c46785271c26d2"];
    data.searchID(search_ID);

% TODO: take in an array, show documents with IDs in array

%   details, graph and subgraph are a bit tricky, but I am not sure if we
%   want these functions...
end