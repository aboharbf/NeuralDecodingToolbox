function  uiIs = whatui

LIC = license('inuse');

for elem = 1:numel(LIC)
  envStr = LIC(elem).feature;
  if strcmpi(envStr,'matlab')
    uiIs = 'Matlab';
    break
  elseif strcmpi(envStr,'octave')
    uiIs = 'Octave';
    break
  end
end

end
