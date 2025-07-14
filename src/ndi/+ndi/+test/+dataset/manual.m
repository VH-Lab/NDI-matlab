
prefix = '/Users/vanhoosr/Desktop/dataset_tests/';

D = ndi.dataset.dir('test_dataset',[prefix 'dataset']);

s{1} = ndi.session.dir([prefix '2023-08-01']);
s{2} = ndi.session.dir([prefix '2023-08-03']);

D = D.add_ingested_session(s{1});
D = D.add_ingested_session(s{2});
