function opt= defopt_spec(varargin)
% in construction

opt= propertylist2struct(varargin{:});
opt= set_defaults(opt, ...
                  'LineWidth',0.7, ...
                  'AxisTitleVerticalAlignment', 'top', ...
                  'AxisTitleFontWeight', 'demi', ...
                  'ShrinkAxes', [0.95 0.9], ...
                  'ScaleHPos','left', ...
                  'ScalePolicy','auto');
