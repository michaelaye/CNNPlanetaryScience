function svm = svm_hirise_Data(config, pixel_size)
hi_path = config.data{1};
opts.dataDir = fullfile(hi_path,'hirise_data') ;
opts.pixel_size = pixel_size;
imdb = getHiRISEImdb(opts);
trainLabels = imdb.images.labels(find(imdb.images.set == 1));
testLabels = imdb.images.labels(find(imdb.images.set == 3));
testData = imdb.images.data(:,:,find(imdb.images.set == 3));
trainData = imdb.images.data(:,:,find(imdb.images.set == 1));
flatTrainData = permute(trainData,[3 1 2]);
flatTrainData = reshape(flatTrainData, size(trainData,3), size(trainData,1)*size(trainData,1));
flatTestData = permute(testData,[3 1 2]);
c = cvpartition(size(trainData,3),'KFold',3);
flatTestData = reshape(flatTestData, size(testData,3), size(testData,1)*size(testData,1));

minfn = @(z)kfoldLoss(fitcsvm(flatTrainData,trainLabels,'KernelFunction','RBF', 'CVPartition',c,'BoxConstraint', exp(z(1)), 'KernelScale', exp(z(2))));
opts = optimset('TolX',5e-4,'TolFun',5e-4);
tic
[searchmin fval] = fminsearch(minfn,randn(2,1),opts);
z = searchmin;
toc
svm=fitcsvm(flatTrainData,trainLabels, 'KernelFunction','RBF', 'BoxConstraint', exp(z(1)), 'KernelScale', exp(z(2)));
svm = fitcsvm(flatTrainData,trainLabels, 'KernelFunction','RBF', 'KernelScale', 'auto');
% mdlSVM = fitPosterior(svm);
% [~,score_svm] = resubPredict(mdlSVM);
% class_flag = logical(mdlSVM.ClassNames-1);
% [Xsvm,Ysvm,Tsvm,AUCsvm] = perfcurve(logical(trainLabels-1),score_svm(:,class_flag),'true');
% plot(Xsvm, Ysvm)

disp 'tortilla'




function imdb = getHiRISEImdb(opts)
% --------------------------------------------------------------------
% Preapre the imdb structure, returns image data with mean image subtracted
if ~exist(opts.dataDir, 'dir')
  mkdir(opts.dataDir) ;
  disp 'You need to put some data in the dataDir'
end

mat_to_load = ['all_images_', num2str(opts.pixel_size), '.mat'];
labels_to_load = ['labels_', num2str(opts.pixel_size), '.mat'];
load(fullfile(opts.dataDir, mat_to_load))
load(fullfile(opts.dataDir, labels_to_load))
[n,m,samples] = size(image_array);
[labels, label_text] = grp2idx(label_file_out); %this transforms the text into numbers for the classes
%we need to create a binary classifier, so we need to do a catch all to
%everything not a cone
labels(labels==3)=2; %forget the second class
subset_pct = 90;%percentage of training data
subset = floor(size(image_array, 3)*subset_pct/100);
disp(['Subset size is ', num2str(subset)])
[trainLabels, idx] = datasample(labels, subset, 'Replace', false);
trainData = image_array(:,:,idx);
testData = image_array;
testData(:,:,idx) = [];
testLabels = labels;
testLabels(idx) = [];
%%
%Save the test and training data to run metrics afterwards
mat_to_save_test = ['test_all_images_', num2str(opts.pixel_size), '.mat'];
labels_to_save_test = ['test_labels_', num2str(opts.pixel_size), '.mat'];
save(fullfile(opts.dataDir, mat_to_save_test), 'testData')
save(fullfile(opts.dataDir, labels_to_save_test), 'testLabels')
mat_to_save_train = ['train_all_images_', num2str(opts.pixel_size), '.mat'];
labels_to_save_train = ['train_labels_', num2str(opts.pixel_size), '.mat'];
save(fullfile(opts.dataDir, mat_to_save_train), 'trainData')
save(fullfile(opts.dataDir, labels_to_save_train), 'trainLabels')

%%
data = cat(3, trainData, testData);
data = single(reshape(data,n,m,samples))/255;
set = [ones(1,numel(trainLabels)) 3*ones(1,numel(testLabels))];
dataMean = mean(data(:,:,set == 1), 3);
data = zscore(data, [], 3);
%data = zscore(data);
%data = bsxfun(@minus, data, dataMean) ;

imdb.images.data = data ;
imdb.images.data_mean = dataMean;
imdb.images.labels = cat(2, trainLabels', testLabels');%Labels need to start form 1
imdb.images.set = set ;
imdb.meta.sets = {'train', 'val', 'test'} ;
%imdb.meta.classes = arrayfun(@(x)sprintf('%d',x),0:1,'uniformoutput',false) ;
imdb.meta.classes = label_text';