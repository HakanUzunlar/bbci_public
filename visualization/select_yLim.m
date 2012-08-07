function YLim= select_yLim(h, varargin)

opt= propertylist2struct(varargin{:});
opt= set_defaults(opt, ...
                  'Policy', 'auto', ...
                  'TightenBorder', 0.03, ...
                  'Symmetrize', 0, ...
                  'SetLim', 1);

switch(lower(opt.policy)),
 case 'auto',
  YLim= get(h, 'YLim');
 case 'tightest',
  backaxes(h);
  axis('tight');
  YLim= get(h, 'YLim');
 case 'tight',
  backaxes(h);
  axis('tight');
  yl= get(h, 'YLim');
  %% add border not to make it too tight:
  yl= yl + [-1 1]*opt.tightenBorder*diff(yl);
  %% determine nicer limits
  dig= floor(log10(diff(yl)));
  if diff(yl)>1,
    dig= max(1, dig);
  end
  YLim= [trunc(yl(1),-dig+1,'floor') trunc(yl(2),-dig+1,'ceil')];
 otherwise,
  error('unknown policy');
end

if opt.symmetrize,
  ma= max(abs(YLim));
  YLim= [-ma ma];
end

if opt.setLim,
  set(h, 'YLim',YLim);
end

if nargout==0,
  clear YLim;
end
