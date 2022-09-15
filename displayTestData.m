function displayTestData()
    scr_siz = get(0,'ScreenSize') ;
    figure('color', [0.8 0.8 0.8], 'Position', floor([scr_siz(3)/4 scr_siz(4)/4 scr_siz(3)/1.5 scr_siz(4)/1.5]));
    title('select document simple gui');
    axis off;
    data = testData();
    docs = load('SomeDocuments.mat');
    data.addDoc(docs.documents);
end