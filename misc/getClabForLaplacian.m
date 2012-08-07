function [requ_clab, W, neighbor_clab]= getClabForLaplacian(dat, varargin)
%GETCLABFORLAPLACIAN - Get channels which are required for Laplacian filtering
%
%Synopsis:
%   CLAB= getClabForLaplacian(DAT, <OPT>)
%   CLAB= getClabForLaplacian(DAT, CLAB, <OPT>)
%
%Arguments:
%   DAT:    STRUCT   - Continuous or epoched data, or directly the full
%                      channel set from which the clabs for laplacian should 
%                      be extracted
%   CLAB:   CELL     - Names of channels that should be filtered by 
%                      proc_laplacian. Accepts wildcards.
%   OPT: 	PROPLIST - struct or property/value list of optional properties:
%     filter_type: CHAR (default 'small') - Name of the type of Laplace
%                      filter that should be used. Simply add your filter
%                      to the subfunction 'getLaplaceFilter'.
%     clab: CELL     - Equal to CLAB as a second parameter.
%     ignore_clab: CELL (default {'E*'}) - Names of the channels that are
%                      to be left out of the calculation.
%     grid: STRING (default 'grid_128') - Name of montage file (in 
%                      EEG_CFG_DIR folder). 
%     require_complete_neighborhood: BOOL (default 1) - Enforce that a
%                      Laplace channel can only be returned if all the
%                      necessary neighbors are available.
%
%Returns:
%   REQU_CLAB:         cell array of channel labels, necessary for the
%                      given Laplace channels
%   W:                 filter matrix that can be used, e.g. in 
%                      proc_linearDerivation, to calculate the Laplace
%                      channels
%   NEIGHBOR_CLAB:     Channels around the Laplace channels that are used
%                      for referencing
%
%Examples:
%   getClabForLaplacian(dat, {'C3', 'C4'}, 'filter_type', 'small');
%   getClabForLaplacian(dat, 'filter_type', 'large', 'clab', {'C3', 'C4'});

%See:
% proc_laplacian
%
% Benjamin Blankertz
% Martijn Schreuder 06/12 - Updated the help documentation

if mod(nargin,2)==0,
  opt.clab= varargin{1};
  opt= merge_structs(opt, propertylist2struct(varargin{2:end}));
  %  opt.clab= clab;
else
  opt= propertylist2struct(varargin{:});
end
opt= set_defaults(opt, ...
  'clab', '*', ...
  'ignore_clab', {'E*'}, ...
  'grid', 'grid_128', ...
  'filter_type', 'small', ...
  'require_complete_neighborhood', 1);

if ~iscell(opt.ignore_clab),
  opt.ignore_clab= {opt.ignore_clab};
end

if isstruct(dat)
  clab = dat.clab;
else
  clab = dat;
end
  
laplace= [];
laplace.grid= getGrid(opt.grid);
if isequal(opt.filter_type, 'flexi')
  laplace.filter= [];
  % for standard positions C3, CP5, etc
  laplace.filter1= getLaplaceFilter('small');
  % for extended positions CFC3, PCP1, etc
  laplace.filter2= getLaplaceFilter('diagonal_small');
else
  laplace.filter= getLaplaceFilter(opt.filter_type);
end

rc= chanind(clab, {'not', opt.ignore_clab{:}});
nOrigChans= length(clab);
pos= zeros(2, nOrigChans);
for ic= 1:nOrigChans,
  pos(:,ic)= getCoordinates(clab{ic}, laplace.grid);
end
pos(:,setdiff(1:nOrigChans,rc))= inf;

idx_tbf= chanind(clab, opt.clab);
W= zeros(length(clab), length(idx_tbf));
lc= 0;
requ_clab= {};
neighbor_clab= cell(length(idx_tbf), 1);
filter_tmp = laplace.filter;
for ci= 1:length(idx_tbf),
  cc= idx_tbf(ci);
  refChans= [];  
  if isequal(opt.filter_type, 'flexi'),
    clab_tmp= strrep(clab{cc}, 'z','0');
    if sum(isletter(clab_tmp))<3,
      laplace.filter= laplace.filter1;
    else
      laplace.filter= laplace.filter2;
    end
  end
  if isequal(opt.filter_type, 'eleven')    
    if isnan(mod(str2double(clab{cc}(end)),2))
      warning('asymmetric filter type ''eleven'' ignores central channels');
      continue;
    end
  end
  if size(filter_tmp,3) > 1
    if isequal(clab{cc}(end),'z')
      laplace.filter = filter_tmp(:,:,2);
    elseif mod(str2double(clab{cc}(end)),2)
      laplace.filter = filter_tmp(:,:,1);
    else
      laplace.filter = filter_tmp(:,:,end);
    end
  end
  nRefs= size(laplace.filter,2);
  for ir= 1:nRefs,
    ri= find( pos(1,:)==pos(1,cc)+laplace.filter(1,ir) & ...
      pos(2,:)==pos(2,cc)+laplace.filter(2,ir) );
    refChans= [refChans ri];
  end
  if length(refChans)==nRefs | ~opt.require_complete_neighborhood,
    lc= lc+1;
    W(cc,lc)= 1;
    if ~isempty(refChans),
      W(refChans,lc)= -1/length(refChans);
    end
    requ_clab= unique(cat(2, requ_clab, clab([cc refChans])));
    neighbor_clab{ci}= clab(refChans);
  end
end
clear filter_tmp
W= W(chanind(clab, requ_clab),:);



function pos= getCoordinates(lab, grid)

nRows= size(grid,1);
%w_cm= warning('query', 'bci:missing_channels');
%warning('off', 'bci:missing_channels');
ii= chanind(grid, lab);
%warning(w_cm);
if isempty(ii),
  pos= [NaN; NaN];
else
  xc= 1+floor((ii-1)/nRows);
  yc= ii-(xc-1)*nRows;
  xc= 2*xc - isequal(grid{yc,1},'<');
  pos= [xc; yc];
end



function filt= getLaplaceFilter(filter_type)

switch lower(filter_type),
  case 'sixnew'
    filt = [-4 0; -2 0; 0 -2; 0 2; 2 0; 4 0]';
  case 'eightnew'    
    filt = [-4 0; -2 -2; -2 0; -2 2; 2 -2; 2 0; 2 2; 4 0]';
  case 'small',
    filt= [0 -2; 2 0; 0 2; -2 0]';
  case 'large',
    filt(:,:,1) = [-2 0; 0 -2; 0 2; 2 0; 4 0; 8 0]';
    filt(:,:,2) = [-4 0; -2 0; 0 -2; 0 2; 2 0; 4 0]';
    filt(:,:,3) = [-8 0; -4 0; -2 0; 0 -2; 0 2; 2 0]';  
  case 'horizontal',
    filt= [-2 0; 2 0]';
  case 'vertical',
    filt= [0 -2; 0 2]';
  case 'bip_to_anterior';
    filt= [0 -2]';
  case 'bip_to_posterior';
    filt= [0 2]';
  case 'bip_to_left';
    filt= [-2 0]';
  case 'bip_to_right';
    filt= [2 0]';
  case 'diagonal',
    filt= [-2 -2; 2 -2; 2 2; -2 2]';
  case 'diagonal_small',
    filt= [-1 -1; 1 -1; 1 1; -1 1]';
  case 'six',
    filt= [-2 0; -1 -1; 1 -1; 2 0; 1 1; -1 1]';
  case 'eightsparse',
    filt= [-2 0; -2 -2; 0 -2; 2 -2; 2 0; 2 2; 0 2; -2 2]';
  case 'eight',
    filt= [-2 0; -1 -1; 0 -2; 1 -1; 2 0; 1 1; 0 2; -1 1]';
  case 'ten'
    filt= [-4 0; -2 -2; -2 0; -2 2; 0 -2; 0 2; 2 -2; 2 0; 2 2; 4 0]';
  case 'eleven_to_anterior'
    % eleven unsymmetric neighbors for channel in the left emisphere
    % (neigbors more going to the left)
    filt(:,:,1) = [-4 0; -4 2; -2 -2; -2 0; -2 2; -2 4; 0 -2; 0 2; 0 4; 2 0; 2 2]';
    % eleven unsymmetric neighbors for channel in the right emisphere
    % (neigbors more going to the right)
    filt(:,:,2) = [-2 0; -2 2; 0 -2; 0 2; 0 4; 2 -2; 2 0; 2 2; 2 4; 4 0; 4 2]';
  case 'eleven'
    filt(:,:,1) = [-4 -2; -4 0; -4 2; -2 -2; -2 0; -2 2; 0 -2; 0 2; 2 -2; 2 0; 2 2]';
    filt(:,:,2) = [-2 -2; -2 0; -2 2; 0 -2; 0 2; 2 -2; 2 0; 2 2; 4 -2; 4 0; 4 2]';
  case 'twelve'
    filt = [-2 0; -2 -2; 0 -2; 2 -2; 2 0; 2 2; 0 2; -2 2; -1 -1; 1 -1; 1 1; -1 1]';  
  case 'eighteen',
    filt= [-2 2; 0 2; 2 2; -3 1; -1 1; 1 1; 3 1; -4 0; -2 0; 2 0; 4 0; -3 -1; -1 -1; 1 -1; 3 -1; -2 -2; 0 -2; 2 -2]';
  case 'twentytwo'
    filt = [-1 3; 1 3; -2 2; 0 2; 2 2; -3 1; -1 1; 1 1; 3 1; -4 0; -2 0; 2 0; 4 0; -3 -1; -1 -1; 1 -1; 3 -1; -2 -2; 0 -2; 2 -2; -1 -3; 1 -3]';
  otherwise
    error('unknown filter matrix');
end
