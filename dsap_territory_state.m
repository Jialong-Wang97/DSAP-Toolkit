function varargout=dsap_territory_state(action,varargin)
% Pure mask editing transaction; never touches the perfusion engine or CAVE.
switch action
 case 'new'
  prediction=varargin{1};metadata=varargin{2};a=logical(prediction.ACA_mask);m=logical(prediction.MCA_mask);
  assert(ismatrix(a)&&isequal(size(a),size(m))&&~any(a&m,'all'),'DSAP:TerritoryShape','Invalid or overlapping prediction masks.');
  layers=repmat({false(size(a))},6,1);layers{1}=a;layers{2}=m;
  s=struct('SchemaVersion',1,'Names',{{'ACA_Unspecified';'MCA_Unspecified';'ACA_Left';'MCA_Left';'ACA_Right';'MCA_Right'}}, ...
   'Masks',{layers},'AutomaticMasks',struct('ACA',a,'MCA',m),'Metadata',metadata,'History',{{}},'Cursor',0,'Audit',{{}},'Confirmed',false,'LabelMappingConfirmed',false);
  varargout={s};
 case 'patch'
  s=varargin{1};layer=varargin{2};patch=varargin{3};mode=varargin{4};detail=struct();if numel(varargin)>4,detail=varargin{5};end
  assert(ismember(layer,1:6)&&islogical(patch)&&isequal(size(patch),size(s.Masks{1})),'DSAP:TerritoryPatch','Invalid edit mask.');
  old=s.Masks;next=old;
  switch mode
   case 'add',next{layer}=old{layer}|patch;
   case 'erase',next{layer}=old{layer}&~patch;
   case 'replace',next{layer}=patch;
   otherwise,error('DSAP:TerritoryMode','Unknown patch operation.');
  end
  s=commit(s,next,mode,detail);varargout={s};
 case 'assign_side'
  s=varargin{1};side=varargin{2};assert(ismember(side,{'Left','Right'}),'DSAP:TerritorySide','Side must be explicitly Left or Right.');
  index=3;if strcmp(side,'Right'),index=5;end
  assert(~any(s.Masks{index},'all')&&~any(s.Masks{index+1},'all'),'DSAP:TerritorySide','Destination side is not empty.');
  next=s.Masks;next(index:index+1)=next(1:2);next(1:2)={false(size(next{1}));false(size(next{1}))};
  varargout={commit(s,next,'assign_side',struct('Side',side))};
 case 'swap_labels'
  s=varargin{1};varargout={commit(s,s.Masks([2 1 4 3 6 5]),'swap_ACA_MCA',struct())};
 case {'undo','redo'}
  s=varargin{1};undo=strcmp(action,'undo');index=s.Cursor+~undo;
  if index<1||index>numel(s.History),varargout={s};return;end
  changes=s.History{index}.Changes;
  for j=1:numel(changes)
   c=changes{j};if undo,s.Masks{j}(c.Added)=false;s.Masks{j}(c.Removed)=true;
   else,s.Masks{j}(c.Added)=true;s.Masks{j}(c.Removed)=false;end
  end
  s.Cursor=s.Cursor+1-2*undo;s.Confirmed=false;s.Audit{end+1}=struct('Action',action,'HistoryID',s.History{index}.ID,'UTC',utc());varargout={s};
 case 'confirm'
  s=varargin{1};assert(isequal(varargin{2},true),'DSAP:TerritoryReview','Explicit label/anatomy review is required.');
  counts=cellfun(@nnz,s.Masks);assert(any(counts>=3)&&~any(counts>0&counts<3),'DSAP:TerritoryEmpty','Each included ROI needs at least 3 pixels.');
  occupied=zeros(size(s.Masks{1}));for j=1:6,occupied=occupied+double(s.Masks{j});end
  assert(~any(occupied>1,'all'),'DSAP:TerritoryOverlap','Territory layers overlap; correct them before confirming.');
  s.Confirmed=true;s.LabelMappingConfirmed=true;s.Audit{end+1}=struct('Action','confirm','UTC',utc());varargout={s};
 case 'save'
  s=varargin{1};folder=varargin{2};assert(s.Confirmed,'DSAP:TerritoryReview','Only reviewed masks can be saved as final.');
  if ~isfolder(folder),mkdir(folder);end
  assert(~isfile(fullfile(folder,'territory_session.mat')),'DSAP:TerritoryOverwrite','Choose a new output directory to preserve history.');
  ACA_mask=s.Masks{1}|s.Masks{3}|s.Masks{5};MCA_mask=s.Masks{2}|s.Masks{4}|s.Masks{6}; %#ok<NASGU>
  manual_edit_history=s.Audit;metadata=s.Metadata;automatic_mask=s.AutomaticMasks.ACA; %#ok<NASGU>
  reviewed_mask=ACA_mask;edit_history=manual_edit_history;
  save(fullfile(folder,'final_ACA_mask.mat'),'ACA_mask','automatic_mask','reviewed_mask','edit_history','manual_edit_history','metadata');
  automatic_mask=s.AutomaticMasks.MCA;reviewed_mask=MCA_mask;
  save(fullfile(folder,'final_MCA_mask.mat'),'MCA_mask','automatic_mask','reviewed_mask','edit_history','manual_edit_history','metadata');
  territory_session=s;save(fullfile(folder,'territory_session.mat'),'territory_session','-v7');varargout={folder};
 case 'definition'
  s=varargin{1};assert(s.Confirmed,'DSAP:TerritoryReview','Review before generating DSAP ROI.');
  used=cellfun(@nnz,s.Masks)>=3;n=nnz(used);
  d=struct('Mode','Freehand','Masks',{s.Masks(used)},'Names',{s.Names(used)},'SelectedFrames',ones(n,1), ...
   'Types',{repmat({'Individual'},n,1)},'MergeSources',{repmat({''},n,1)},'Confirmed',true,'TerritoryProvenance',s);
  varargout={d};
 case 'parenchyma'
  s=varargin{1};vessels=varargin{2};assert(islogical(vessels)&&isequal(size(vessels),size(s.Masks{1})),'DSAP:TerritoryShape','Vessel mask shape mismatch.');
  varargout={cellfun(@(m)m&~vessels,s.Masks,'UniformOutput',false)};
 otherwise,error('DSAP:TerritoryAction','Unknown action.');
end
end
function s=commit(s,next,action,detail)
changes=cell(6,1);for j=1:6,changes{j}=struct('Added',uint32(find(next{j}&~s.Masks{j})),'Removed',uint32(find(s.Masks{j}&~next{j})));end
entry=struct('ID',char(java.util.UUID.randomUUID()),'Action',action,'Detail',detail,'Changes',{changes},'UTC',utc());
s.History=s.History(1:s.Cursor);s.History{end+1}=entry;s.Cursor=numel(s.History);s.Masks=next;s.Confirmed=false;s.Audit{end+1}=entry;
end
function s=utc,s=char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));end
