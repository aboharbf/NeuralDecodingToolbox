function ds = dsPseudoGenUpdate(ds);
% a function which modifies variables in ds for the sake of making the
% structure compatibile with pseudoGeneralization analysis

% Pull needed variables
the_labels = ds.the_labels;
label_names_to_use = ds.label_names_to_use;
the_labels_pseudoGen = ds.the_labels_pseudoGen;
num_cv_splits = ds.num_cv_splits;
num_times_to_repeat_each_label_per_cv_split = ds.num_times_to_repeat_each_label_per_cv_split;

trialPerLabel = num_cv_splits * num_times_to_repeat_each_label_per_cv_split;

% Check for pseudoGen info, which limits trialPerLabel
if ~isempty(the_labels_pseudoGen) && ~ds.pseudoGen_init
  
  % Identify the labels across everything.
  label_all = unique(vertcat(the_labels{:}))';
  pseudoLabelPerRun = cell(length(label_all), length(the_labels));
  for label_i = label_all
    labelIndexPerUnitArray = cellfun(@(x) x == label_i, the_labels, 'UniformOutput', false);
    pseudoLabelPerRun(label_i, :) = arrayfun(@(x) unique(the_labels_pseudoGen{x}(labelIndexPerUnitArray{x})), 1:length(the_labels_pseudoGen), 'UniformOutput', false );
  end
  
  % Take the minimum of all runs.
  pseudoLabelPerRun = min(min(cellfun('length', pseudoLabelPerRun)));
  
  % Identify the pseudoGen labels and make sure they can evenly be
  % represented in the testing set.
  pseudoLabel_names_to_use = unique(vertcat(the_labels_pseudoGen{:}));
  
  pseudoLabPerLabel = nan(length(pseudoLabel_names_to_use), length(the_labels_pseudoGen));
  for label_i = pseudoLabel_names_to_use'
    % Find the pseudoGen that matches label_i
    pseudoLabPerLabel(label_i,:) = cellfun(@(x) sum(x == label_i), the_labels_pseudoGen);
  end
  pseudoLabelMinTrials = min(pseudoLabPerLabel(pseudoLabPerLabel ~= 0));
  
  % Trials per run should be the number of pseudo labels times the
  % number of trials each of those pseudo labels has
  if trialPerLabel > pseudoLabelMinTrials * pseudoLabelPerRun
    % warn the user
    warning('Updating trialPerLabel due to need for fewer');
    
    goalTrialPerLabel = pseudoLabelMinTrials * pseudoLabelPerRun;
    
    [new_num_cv_splits, new_num_times_to_repeat_each_label_per_cv_split, trialPerLabel] = incrementSearch(num_cv_splits, num_times_to_repeat_each_label_per_cv_split, goalTrialPerLabel);
    
    % Update reps per cv, trialPerLabel
    [ds.num_times_to_repeat_each_label_per_cv_split, num_times_to_repeat_each_label_per_cv_split] = deal(new_num_times_to_repeat_each_label_per_cv_split);
    [ds.num_cv_splits, num_cv_splits] = deal(new_num_cv_splits);
    
    % Report
    fprintf('Finished updating, trialPerLabel = %d, num_cv_splits = %d, label_per_split = %d \n', trialPerLabel, num_cv_splits, num_times_to_repeat_each_label_per_cv_split);
    
    % Update this so it doesn't run twice
    ds.pseudoGen_init = true;
    
  end
  
end

end