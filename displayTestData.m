function displayTestData()
    scr_siz = get(0,'ScreenSize') ;
    figure('color', [0.8 0.8 0.8], 'Position', floor([scr_siz(3)/3 scr_siz(4)/3 scr_siz(3)/2 scr_siz(4)/2]));
    title('select document simple gui');
    axis off;
    data = testData();
    docs = load('SomeDocuments.mat');
%     data.addDoc(docs.documents);
    data.addDoc({docs.documents{1,1:100}}); % this line is for testing only, make doc shorter...
end