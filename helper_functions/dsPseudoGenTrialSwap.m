function [testing_logical, training_logical] = dsPseudoGenTrialSwap(curr_cv_inds, all_data_point_labels, curr_data_label_pseudoGen)
% This function ensures the testing set and training set do not represent
% the same pseudoGen stim.

% Important Note: Despite the fact the same pseudoStimuli may not be
% represented across all runs, the consistent count of those pseudoStimuli
% per label (4 per label, 2 represented in one set, 2 in the other), means
% that if the training and testing sets are segregated for one of these, it
% will be necessarily segregated for the other. This might be the case in
% the future of the non-overlapping stimuli sets aren't preserved, or the
% counts are not the same in the two stimuli sets.

% The code below implements that check
countsOfPL = nan(size(curr_data_label_pseudoGen,1),1);
for ii = 1:size(curr_data_label_pseudoGen,1)
 countsOfPL(ii) = length(unique(curr_data_label_pseudoGen(ii,:)));
end
assert(length(unique(countsOfPL)) == 1, 'Something is up with the pseudoLabel counts')

curr_data_label_pseudoGen = curr_data_label_pseudoGen(:,randi(size(curr_data_label_pseudoGen,2)));

% Create a logical index for ease
testing_logical = false(size(all_data_point_labels));
testing_logical(curr_cv_inds) = true;

% Pick a random integer for each label
label_unique = unique(all_data_point_labels)';

[testStimVec, trainStimVec] = deal([]);

for broad_i = label_unique
  
  % Find the pseudoGen labels within the label
  pseudoGen_in_Label = curr_data_label_pseudoGen(all_data_point_labels == broad_i);
  pseudoGen_unique = unique(pseudoGen_in_Label);
  
  % Identify which stimuli will be in the trainingStim
  testLog = false(length(pseudoGen_unique),1);
  testInd = randi(length(pseudoGen_unique));
  testLog(testInd) = true;
  
  testStim = pseudoGen_unique(testLog);
  trainStim = pseudoGen_unique(~testLog);
  
  testStimVec = [testStimVec; testStim];
  trainStimVec = [trainStimVec; trainStim];
  
  % Remove training stimuli from the test set. 
  if size(trainStim,1) > 1
    trainStim = trainStim';
  end
  
  if size(testStim,1) > 1
    testStim = testStim';
  end
  
  moveTest2Train = any(curr_data_label_pseudoGen == trainStim, 2) & testing_logical; % Trials in the testing set belonging to training stim.
  testing_logical(moveTest2Train) = false;
  trainSetLostTrials = sum(moveTest2Train);
  
  % Identify possible replacement trials, add them.
  moveTrain2Test = find(any(curr_data_label_pseudoGen == testStim, 2) & ~testing_logical); % Trials of the test stim not already in the testing set.
  moveTrain2Test = moveTrain2Test(randperm(length(moveTrain2Test)));
  moveTrain2Test = moveTrain2Test(1:(min(trainSetLostTrials, length(moveTrain2Test))));
  testing_logical(moveTrain2Test) = true;
  
end

% Make sure the training set doesn't have any of the testing stim.
training_logical = ~testing_logical;
training_logical(ismember(curr_data_label_pseudoGen, testStimVec)) = false;

end