function [newA, newB, newProd] = incrementSearch(A, B, Target);
% A function which gets the product of A and B as close to the target,
% while not being greater than it. for interchangable cases, A is made
% larger.

% Iteratively - Create a multiplication table for all numbers 1:A and 1:B
aVec = 1:A;
bVec = 1:B;

% Create the grid
comparisonGrid = aVec .* bVec';
newProd = Target;
targFound = false;

% Iteratively drop the new product until the closest thing is found
while ~targFound
  
  validGrid = newProd == comparisonGrid;
  
  if any(validGrid(:))
    targFound = 1;
  else
    newProd = newProd - 1;
  end
    
end

% find the new A
newA = find(any(validGrid), 1, 'last');
newB = find(validGrid(:,newA), 1, 'last');

end