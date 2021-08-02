function [curr_trials_to_use, pseudoLabels_in_Label_updated] = dsPseudoGenRandomTrialPick(pseudoLabels_in_Label, curr_trials_to_use, trialPerLabel)
% during the extracting of test and training sets, random trials are
% selected. In the case of the pseudoGen decoding, we want those trials to
% be random, but evenly represent the pseudoGen label which is nested in
% the true label.

% Identify which pseudoLabels are represented in this label
unique_pseudoLabels = unique(pseudoLabels_in_Label)';

% Find out how many of each label to pick.
trialPerPseudoLabel = trialPerLabel/length(unique_pseudoLabels);

[trials2Use, trialsPseudoLabel] = deal([]);
for ii = unique_pseudoLabels
  pseudoLabel_ind = pseudoLabels_in_Label == ii;
  pseudoLabel_trialInd = curr_trials_to_use(pseudoLabel_ind);
  trials2Use = [trials2Use, pseudoLabel_trialInd(1:trialPerPseudoLabel)];
  trialsPseudoLabel = [trialsPseudoLabel, ones(trialPerPseudoLabel, 1) * ii];
end

% interdigitate the rows
[tmp, tmp2] = deal([]);
for ii = 1:size(trials2Use, 1)
  tmp = [tmp, trials2Use(ii,:)];
  tmp2 = [tmp2, trialsPseudoLabel(ii,:)];
end

curr_trials_to_use = tmp;
pseudoLabels_in_Label_updated = tmp2;

end