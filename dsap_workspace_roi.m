function [mask,limits,partition,imported]=dsap_workspace_roi(fig,parent,sequence,reference,imported,autoAIFContext)
% Draft presentation only. Rasterization and partition validation use verified helpers.
if nargin<6,autoAIFContext=struct();end
startupComplete=false;autoAIFBusy=false;
children=gobjects(0);territoryRecords={};showingReference=false;nativeCLim=[];suspended=false;
t=dsap_theme;delete(parent.Children);done=false;frozen=false;mask=false(size(reference));partition=struct();
legacy=~isempty(fieldnames(imported));frame=1;playing=false;retired=false;roi=[];outer=[];inner=[];tissueROI=[];tissueBoundary=[];listeners=[];
tissueMode='none';tissueMask=false(size(reference));manualMasks={};manualNames={};
manualFrames=[];manualTypes={};manualSources={};
state=getappdata(fig,'WorkspaceState');runID=state.RunID;
g=uigridlayout(parent,[1 2],'ColumnWidth',{'1x',320},'Padding',t.Space.M,'ColumnSpacing',t.SectionGap);
left=uigridlayout(g,[4 1],'RowHeight',{'1x',40,36,30},'Padding',0);ax=uiaxes(left);
im=imshow(squeeze(sequence(1,:,:)),[],'Parent',ax);hold(ax,'on');
ol=plot(ax,nan,nan,'Color',t.OuterColor,'LineWidth',2);il=plot(ax,nan,nan,'Color',t.InnerColor,'LineWidth',2);
upperLine=yline(ax,1,'--','Color',t.UpperLimitColor);lowerLine=yline(ax,size(reference,1),'--','Color',t.LowerLimitColor);
% Keep image bounds fixed when ylines/contours are added; do not shrink the image.
ax.XLim=[.5 size(reference,2)+.5];ax.YLim=[.5 size(reference,1)+.5];
dsap_style_axes(ax);axtoolbar(ax,{'zoomin','zoomout','pan','restoreview'});ax.Toolbar.Visible='on';
ax.Color=t.ViewerBackground;aifBoundary=[];
slider=uislider(left,'Limits',[1 size(sequence,1)],'Value',1,'ValueChangingFcn',@(a,e) show_frame(e.Value),'ValueChangedFcn',@slider_changed);
bar=uigridlayout(left,[1 5],'ColumnWidth',{64,'1x',78,90,105},'Padding',0);
play=uibutton(bar,'Text','播放','ButtonPushedFcn',@play_frames);frameLabel=uilabel(bar,'Text','第 1 帧');
overlay=uicheckbox(bar,'Text','ROI 叠加','Value',true,'ValueChangedFcn',@toggle_overlay);
uibutton(bar,'Text','参考图像','ButtonPushedFcn',@(~,~) show_reference());uibutton(bar,'Text','自动窗宽/窗位','ButtonPushedFcn',@(~,~) auto_window());
inspectorColumn=uigridlayout(g,[4 1],'RowHeight',{'1x',70,28,40},'Padding',0);
inspect=uigridlayout(inspectorColumn,[11 2],'RowHeight',{26,22,32,26,32,30,54,22,60,30,0}, ...
 'ColumnWidth',{'1x','1x'},'Padding',t.Space.S,'RowSpacing',4,'Scrollable','on');
titleLabel=uilabel(inspect,'Text','ROI 草稿','FontSize',t.Section,'FontWeight','bold');titleLabel.Layout.Row=1;titleLabel.Layout.Column=[1 2];
aifStatus=uilabel(inspect,'Text','AIF · 待绘制','FontColor',t.TextSecondary);aifStatus.Layout.Row=2;aifStatus.Layout.Column=[1 2];
drawButton=uibutton(inspect,'Text','绘制 / 重画 AIF','ButtonPushedFcn',@draw_aif);drawButton.Layout.Row=3;drawButton.Layout.Column=2;
aifMode=uidropdown(inspect,'Items',{'Manual AIF','Auto AIF'},'Value','Manual AIF');aifMode.Layout.Row=3;aifMode.Layout.Column=1;
tissueStatus=uilabel(inspect,'Text','组织 ROI · 待定义','FontColor',t.TextSecondary);tissueStatus.Layout.Row=4;tissueStatus.Layout.Column=[1 2];
freehandButton=uibutton(inspect,'Text','手绘组织 ROI','ButtonPushedFcn',@roi_workflow);freehandButton.Layout.Row=5;
templateButton=uibutton(inspect,'Text','使用模板 / 分区','ButtonPushedFcn',@use_template);templateButton.Layout.Row=5;
roiAction=uidropdown(inspect,'Items',{'Manual ROI','Automatic ACA/MCA','修改已有 ROI'},'Value','Manual ROI');roiAction.Layout.Row=4;roiAction.Layout.Column=[1 2];tissueStatus.Visible='off';
clearButton=uibutton(inspect,'Text','清空 ROI','ButtonPushedFcn',@clear_tissue);clearButton.Layout.Row=6;
roiName=uieditfield(inspect,'text','Value','ROI_1','Tooltip','下一个手绘组织 ROI 的名称');roiName.Layout.Row=6;
roiList=uilistbox(inspect,'Items',{},'Multiselect','on','ValueChangedFcn',@(~,~) update_controls());roiList.Layout.Row=7;roiList.Layout.Column=[1 2];
limitsStatus=uilabel(inspect,'Text','颅内范围','FontColor',t.TextSecondary);limitsStatus.Layout.Row=8;limitsStatus.Layout.Column=[1 2];
limitGrid=uigridlayout(inspect,[2 2],'RowHeight',{28,28},'ColumnWidth',{85,'1x'},'Padding',0,'RowSpacing',4);limitGrid.Layout.Row=9;limitGrid.Layout.Column=[1 2];
uilabel(limitGrid,'Text','上限行');up=uieditfield(limitGrid,'numeric','Limits',[1 size(reference,1)],'Value',1,'ValueChangedFcn',@limits_changed);
uilabel(limitGrid,'Text','下限行');lo=uieditfield(limitGrid,'numeric','Limits',[1 size(reference,1)],'Value',size(reference,1),'ValueChangedFcn',@limits_changed);
advancedToggle=uibutton(inspect,'Text','高级工具 ▸','ButtonPushedFcn',@toggle_advanced);advancedToggle.Layout.Row=10;advancedToggle.Layout.Column=[1 2];
advanced=uigridlayout(inspect,[10 2],'RowHeight',repmat({30},1,10),'ColumnWidth',{'1x','1x'},'Padding',0,'Visible','off');advanced.Layout.Row=11;advanced.Layout.Column=[1 2];
tool=uidropdown(advanced,'Items',{'自由绘制','多边形','矩形','圆形','椭圆'}, ...
 'ItemsData',{'Freehand','Polygon','Rectangle','Circle','Ellipse'});
tool.Layout.Row=1;tool.Layout.Column=2;
toolLabel=uilabel(advanced,'Text','AIF 绘制工具');toolLabel.Layout.Row=1;toolLabel.Layout.Column=1;
mergeButton=uibutton(advanced,'Text','合并所选手绘 ROI','ButtonPushedFcn',@merge_tissue);
loadTemplate=uibutton(advanced,'Text','载入模板','ButtonPushedFcn',@load_template);
applyTemplate=uibutton(advanced,'Text','应用上下限 / 模板','ButtonPushedFcn',@reset_partition);
resetTemplate=uibutton(advanced,'Text','重置模板','ButtonPushedFcn',@reset_partition);
target=uidropdown(advanced,'Items',{'内外边界','外边界','内边界'},'ItemsData',{'Both','Outer','Inner'});
labels={'放大 5%','缩小 5%','左转 3°','右转 3°','左移','右移','上移','下移'};
values={[1.05 0 0 0],[1/1.05 0 0 0],[1 -3 0 0],[1 3 0 0],[1 0 -1 0],[1 0 1 0],[1 0 0 -1],[1 0 0 1]};
transformButtons=gobjects(1,8);
for k=1:8,transformButtons(k)=uibutton(advanced,'Text',labels{k},'ButtonPushedFcn',@(a,b) transform(values{k}));end
windowBar=uigridlayout(left,[1 5],'ColumnWidth',{'1x',40,100,40,100},'Padding',0);windowBar.Layout.Row=4;
uilabel(windowBar,'Text','缩放 / 平移：图像右上角工具栏','FontSize',t.Caption,'FontColor',t.TextSecondary);
uilabel(windowBar,'Text','窗宽');width=uieditfield(windowBar,'numeric','Limits',[eps Inf],'Value',1,'ValueChangedFcn',@window_changed);
uilabel(windowBar,'Text','窗位');level=uieditfield(windowBar,'numeric','Value',.5,'ValueChangedFcn',@window_changed);
note=uilabel(inspectorColumn,'Text','请绘制 AIF 和组织 ROI，确认颅内上下限。','WordWrap','on');
summary=uibutton(inspectorColumn,'Text','查看只读总览（可选）','ButtonPushedFcn',@overview);
confirm=uibutton(inspectorColumn,'Text','确认 ROI 并开始分析','Enable','off','ButtonPushedFcn',@accept);
back=uibutton(advanced,'Text','返回编辑','Visible','off','ButtonPushedFcn',@back_draft);back.Layout.Column=[1 2];
timerObject=timer('ExecutionMode','fixedSpacing','Period',.12,'BusyMode','drop','TimerFcn',@advance);
cleanup=onCleanup(@() stop_timer(timerObject)); % Value-captured fallback; explicit disposal handles Draft objects.
if legacy
 mask=imported.AIFMask;aifBoundary=visboundaries(ax,mask,'Color',t.AIFColor);
 for k=1:numel(imported.Masks),tissueBoundary=[tissueBoundary;visboundaries(ax,imported.Masks{k},'Color',t.TissueColor)];end
 drawButton.Enable='off';tool.Enable='off';titleLabel.Text='历史 ROI · 只读';
 note.Text='ROI 错误请回 TIMESlice 修改后重新导入；在此核对颅内上下限。';
end
update_controls();
auto_window();update_ready();dsap_workspace_style(parent);
% A new editable case gets its AIF automatically before the draft is ready.
% Imported confirmed ROIs remain read-only and must never be overwritten.
if ~legacy&&current()
 aifMode.Value='Auto AIF';open_auto_aif();
end
startupComplete=true;if current(),publish();end;drawnow;
try,dsap_workspace_wait(fig,runID,@is_done);
catch exception,dispose_draft();rethrow(exception);end
% No independent ROI truth is derived here.
dsap_task_control('check');assert(done,'DSAP:Cancelled','ROI 尚未确认。');
dispose_draft();delete(parent.Children);
dsap_workspace_frozen_roi(parent,reference,mask,limits,partition,imported);

 function value=is_done,value=done;end
 function publish
  if ~startupComplete,return;end
  setappdata(fig,'DSAPWorkspaceROIDraft',struct('Axes',ax,'Image',im,'Upper',up,'Lower',lo,'Outer',outer,'Inner',inner, ...
   'Summary',summary,'Confirm',confirm,'AIFMask',mask,'Freehand',freehandButton,'Template',templateButton, ...
   'Clear',clearButton,'Merge',mergeButton,'ROIs',roiList,'Name',roiName,'SetAIF',@set_aif, ...
   'SetTissue',@set_tissue,'AddTissue',@add_tissue_mask,'AIFMode',aifMode,'AIF',drawButton, ...
   'ROIAction',roiAction,'AdoptTerritory',@adopt_territory,'EditTissue',@edit_tissue, ...
   'Suspend',@suspend_editor,'Resume',@() resume_editor(),'CancelInteraction',@cancel_interaction, ...
   'ShowFrame',@show_frame,'ShowReference',@show_reference,'WindowWidth',width,'WindowLevel',level, ...
   'TissueMask',tissueMask,'ManualMasks',{manualMasks},'ManualNames',{manualNames}, ...
   'TissueMode',tissueMode,'RunID',runID,'Refresh',@refresh, ...
   'Advanced',advancedToggle,'Overlay',overlay,'Play',play,'Slider',slider,'Note',note, ...
   'Dispose',@dispose_draft,'Timer',timerObject));
 end
 function yes=current
  yes=false;
  if retired||done||~isgraphics(fig)||~isgraphics(ax)||~isgraphics(im)||~isgraphics(slider)||~isgraphics(frameLabel),return;end
  state=getappdata(fig,'WorkspaceState');yes=isstruct(state)&&isfield(state,'RunID')&&strcmp(state.RunID,runID);
 end
 function set_aif(value)
  assert(current()&&~frozen&&~legacy,'DSAP:FrozenROI','Cannot edit frozen/imported ROI.');
  assert(islogical(value)&&isequal(size(value),size(reference)));mask=value;
  if ~isempty(aifBoundary),delete(aifBoundary(isgraphics(aifBoundary)));end
  aifBoundary=visboundaries(ax,mask,'Color',t.AIFColor);update_ready();toggle_overlay();
 end
 function draw_aif(~,~)
  if ~current()||frozen||legacy,return;end
  pause_cine();close_children();
  if strcmp(aifMode.Value,'Auto AIF'),open_auto_aif();return;end
  children(end+1)=dsap_manual_roi_editor(im.CData,mask,@apply_manual_aif,'Manual AIF · ICA ROI',tool.Value);
 end
 function apply_manual_aif(value)
  set_aif(value);note.Text='AIF ROI 已应用';publish();
 end
 function open_auto_aif
  if autoAIFBusy||~current()||frozen||legacy,return;end
  autoAIFBusy=true;
  controls=findall(parent,'-property','Enable');enabled=get(controls,'Enable');set(controls,'Enable','off');
  restore=onCleanup(@() finish_auto_aif(controls,enabled)); %#ok<NASGU>
  try
   root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'AutoAIF'));
   note.Text='Auto-AIF：读取已有血管并检查腔内候选曲线…';drawnow;
   assert(current()&&~frozen&&~legacy,'DSAP:StaleDraft','当前 ROI 已锁定或病例已切换。');
   [vessel,network,provenance]=resolve_AIF_vascular(autoAIFContext,size(reference),fullfile(root,'interactive_results'));
   report=select_lumen_AIF(sequence,vessel,network,autoAIFContext.Time);
   report.Provenance=provenance;
   if ~report.Available
    save_AIF_report(fullfile(root,'reports','AutoAIF',char(java.util.UUID.randomUUID())),report);
    error('AutoAIF:Unavailable','%s',report.Reason);
   end
   adopt_auto_aif(report);
  catch e
   dsap_workspace_log_error(fig,e,'Auto-AIF');fprintf(2,'%s\n',getReport(e,'extended','hyperlinks','off'));
   if current(),aifMode.Value='Manual AIF';note.Text=['Auto-AIF 未应用，已切回 Manual AIF：' e.message];publish();end
  end
 end
 function finish_auto_aif(controls,enabled)
  autoAIFBusy=false;
  if ~current(),return;end
  for j=1:numel(controls)
   if isgraphics(controls(j)),controls(j).Enable=enabled{j};end
  end
  message=note.Text;update_controls();update_ready();note.Text=message;
 end
 function adopt_auto_aif(report)
  assert(current()&&~frozen&&~legacy,'DSAP:StaleDraft','当前 ROI 已锁定或病例已切换。');
  report.ManualMaskBefore=mask;
  folder=fullfile(fileparts(mfilename('fullpath')),'reports','AutoAIF',char(java.util.UUID.randomUUID()));
  save_AIF_report(folder,report);set_aif(report.Selected.Mask);
  [~,peakFrame]=max(report.Selected.TDC);show_frame(peakFrame);auto_window();
  note.Text=sprintf('Auto-AIF 已自动应用 · score %.3f · 半径 %.1f px；请继续绘制组织 ROI。',report.Selected.Score,report.Selected.Radius_px);publish();
 end
 function roi_workflow(~,~)
  if ~current()||frozen||legacy,return;end
  switch roiAction.Value
   case 'Manual ROI',draw_tissue([],[]);
   case 'Automatic ACA/MCA',open_territory();
   otherwise,edit_tissue();
  end
 end
 function edit_tissue
  if ~current()||frozen||legacy,return;end
  if isempty(roiList.Value),note.Text='请先选择一个手绘或已应用的自动 ROI。';return;end
  name=roiList.Value;if iscell(name),name=name{1};end
  index=find(strcmp(manualNames,name),1);if isempty(index),return;end
  pause_cine();close_children();
  children(end+1)=dsap_manual_roi_editor(im.CData,manualMasks{index},@(value) replace_tissue(index,value),'修改 ROI');
 end
 function replace_tissue(index,value)
  assert(current()&&~frozen&&~legacy,'DSAP:StaleDraft','当前 ROI 已锁定或病例已切换。');
  manualMasks{index}=value;rebuild_tissue();note.Text='ROI 已应用';
 end
 function rebuild_tissue
  % Derived merged ROIs must follow edits to their individual masks.
  for j=find(strcmp(manualTypes,'Merged'))'
   members=strsplit(manualSources{j},' + ');merged=false(size(reference));
   for k=find(ismember(manualNames,members)&strcmp(manualTypes,'Individual'))'
    merged=merged|manualMasks{k};
   end
   manualMasks{j}=merged;
  end
  delete(tissueBoundary(isgraphics(tissueBoundary)));tissueBoundary=[];tissueMask=false(size(reference));
  for j=1:numel(manualMasks)
   tissueMask=tissueMask|manualMasks{j};b=visboundaries(ax,manualMasks{j},'Color',t.TissueColor);tissueBoundary=[tissueBoundary;b(:)];
  end
  roiList.Items=manualNames(strcmp(manualTypes,'Individual'));if ~isempty(roiList.Items),roiList.Value=roiList.Items(end);end
  tissueMode='freehand';update_controls();update_ready();publish();
 end
 function open_territory
  pause_cine();close_children();
  try
   st=getappdata(fig,'WorkspaceState');[input,meta]=dsap_territory_case_input(st.SourceFile);
   assert(isequal([size(input,2) size(input,3)],size(reference)),'DSAP:TerritoryShape','供血区与当前图像尺寸不一致。');
   children(end+1)=dsap_territory_editor(input,reference,meta,@adopt_territory);
  catch e,report_error(e);end
 end
 function adopt_territory(session,folder)
  assert(current()&&~frozen&&~legacy,'DSAP:StaleDraft','当前 ROI 已锁定或病例已切换。');
  st=getappdata(fig,'WorkspaceState');identity=dsap_source_identity(st.SourceFile);
  assert(strcmp(session.Metadata.source_id,identity.SHA256),'DSAP:TerritorySource','供血区来自其他病例。');
  d=dsap_territory_state('definition',session);
  % Validate before mutation; replace this source's prior territory set atomically.
  for j=1:numel(d.Masks),assert(islogical(d.Masks{j})&&isequal(size(d.Masks{j}),size(reference)));end
  previous={};for j=1:numel(territoryRecords),previous=[previous;territoryRecords{j}.Names(:)];end
  keep=~ismember(manualNames,previous);
  for j=find(strcmp(manualTypes,'Merged'))'
   if any(ismember(strsplit(manualSources{j},' + '),previous)),keep(j)=false;end
  end
  assert(~any(ismember(d.Names,manualNames(keep))),'DSAP:TerritoryDuplicate','同名手动 ROI 已存在，请先重命名。');
  if strcmp(tissueMode,'template'),clear_tissue();keep=false(0,1);end
  manualMasks=[manualMasks(keep);d.Masks(:)];manualNames=[manualNames(keep);d.Names(:)];
  manualFrames=[manualFrames(keep);repmat(frame,numel(d.Masks),1)];
  manualTypes=[manualTypes(keep);d.Types(:)];manualSources=[manualSources(keep);repmat({folder},numel(d.Masks),1)];
  territoryRecords={struct('Folder',folder,'Names',{d.Names},'SourceID',identity.SHA256)};
  rebuild_tissue();note.Text='ROI 已应用 · 后续分析使用已确认的供血区';
 end
 function report_error(e)
  note.Text=['未应用：' e.message];dsap_workspace_log_error(fig,e,'ROI editor');
  fprintf(2,'%s\n',getReport(e,'extended','hyperlinks','off'));uialert(fig,e.message,'ROI 未应用');
 end
 function close_children
  delete(children(isgraphics(children)));children=gobjects(0);
 end
 function cancel_interaction
  close_children();
  if ~isempty(tissueROI)&&isvalid(tissueROI),delete(tissueROI);tissueROI=[];end
 end
 function suspend_editor
  suspended=true;pause_cine();cancel_interaction();
 end
 function resume_editor
  suspended=false;
 end
 function limits=get_limits
  upper=round(up.Value);lower=round(lo.Value);assert(lower-upper+1>=max(5,round(.05*size(reference,1))),'上下限距离过小。');
  limits=struct('Method','manual-horizontal-cranial-limits','UpperRow',upper,'LowerRow',lower, ...
   'ImageRowCount',size(reference,1),'IncludedRowCount',lower-upper+1);
 end
 function limits_changed(~,~)
  if frozen||~current(),return;end
  upperLine.Value=round(up.Value);lowerLine.Value=round(lo.Value);refresh();update_ready();
 end
 function clear_tissue(varargin)
  if legacy||frozen||~current(),return;end
  close_children();pause_cine();release_listeners();
  if ~isempty(tissueROI)&&isvalid(tissueROI),delete(tissueROI);end
  if ~isempty(tissueBoundary),delete(tissueBoundary(isgraphics(tissueBoundary)));end
  if ~isempty(outer)&&isvalid(outer),delete(outer);end
  if ~isempty(inner)&&isvalid(inner),delete(inner);end
  tissueROI=[];tissueBoundary=[];outer=[];inner=[];listeners=[];partition=struct();tissueMode='none';
  tissueMask=false(size(reference));manualMasks={};manualNames={};manualFrames=[];
  manualTypes={};manualSources={};territoryRecords={};roiName.Value='ROI_1';roiList.Items={};
  ol.XData=nan;ol.YData=nan;il.XData=nan;il.YData=nan;
  note.Text='组织 ROI 已清空。请选择手绘 ROI 或使用模板。';update_controls();update_ready();publish();
 end
 function set_tissue(value)
  assert(current()&&~frozen&&~legacy,'DSAP:FrozenROI','不能编辑已锁定或导入的 ROI。');
  assert(islogical(value)&&isequal(size(value),size(reference)),'DSAP:FreehandMask','手绘 mask 尺寸或类型无效。');
  clear_tissue();add_tissue_mask(value,'ROI_1',frame);
 end
 function add_tissue_mask(value,name,selectedFrame)
  assert(current()&&~frozen&&~legacy,'DSAP:FrozenROI','不能编辑已锁定或导入的 ROI。');
  assert(islogical(value)&&isequal(size(value),size(reference))&&nnz(value)>=3, ...
   'DSAP:FreehandMask','手绘 ROI 必须是与 DSA 同尺寸的 logical mask，且不少于 3 像素。');
  assert(~strcmp(tissueMode,'template'),'DSAP:ROIMode','请先清空模板，再添加手绘 ROI。');
  name=strtrim(name);assert(~isempty(name)&&~any(strcmp(manualNames,name)), ...
   'DSAP:ROIName','ROI 名称为空或重复。');
  manualMasks{end+1,1}=value;manualNames{end+1,1}=name;
  manualFrames(end+1,1)=selectedFrame;manualTypes{end+1,1}='Individual';manualSources{end+1,1}='';
  roiList.Items=manualNames(strcmp(manualTypes,'Individual'));
  roiList.Value=roiList.Items;
  tissueMask=tissueMask|value;tissueMode='freehand';
  nextBoundary=visboundaries(ax,value,'Color',t.TissueColor);
  tissueBoundary=[tissueBoundary;nextBoundary(:)];
  roiName.Value=sprintf('ROI_%d',numel(manualMasks)+1);
  note.Text=sprintf('已保存 %d 个手绘组织 ROI；当前 %s · %d 像素。',numel(manualMasks),name,nnz(value));
  update_controls();update_ready();publish();
 end
 function draw_tissue(~,~)
  if legacy||frozen||~current(),return;end
  pause_cine();close_children();
  name=strtrim(roiName.Value);if isempty(name),name=sprintf('ROI_%d',numel(manualMasks)+1);end
  selectedFrame=frame;
  children(end+1)=dsap_manual_roi_editor(im.CData,false(size(reference)),@(v) accept_tissue(v,name,selectedFrame),'Manual ROI');
 end
 function accept_tissue(value,name,selectedFrame)
  assert(current()&&~frozen&&~legacy,'DSAP:StaleDraft','当前 ROI 已锁定或病例已切换。');
  assert(~any(strcmp(manualNames,name)),'DSAP:ROIName','ROI 名称重复，请修改名称。');
  if strcmp(tissueMode,'template'),clear_tissue();end
  add_tissue_mask(value,name,selectedFrame);note.Text='ROI 已应用';
 end
 function merge_tissue(~,~)
  if legacy||frozen||~current()||numel(manualMasks)<2,return;end
  chosen=roiList.Value;if ischar(chosen),chosen={chosen};end
  individual=find(strcmp(manualTypes,'Individual')&ismember(manualNames,chosen));
  if numel(individual)<2,note.Text='至少需要两个独立手绘 ROI 才能合并。';return;end
  merged=false(size(reference));
  for j=individual(:)',merged=merged|manualMasks{j};end
  assert(nnz(merged)>=3,'合并 ROI 少于 3 个像素。');
  curve=mean(sequence(:,merged),2);[~,mergedFrame]=max(curve);
  mergedName=sprintf('总体ROI_%d',nnz(strcmp(manualTypes,'Merged'))+1);
  manualMasks{end+1,1}=merged;manualNames{end+1,1}=mergedName;
  manualFrames(end+1,1)=mergedFrame;manualTypes{end+1,1}='Merged';
  manualSources{end+1,1}=strjoin(manualNames(individual),' + ');
  note.Text=sprintf('已添加合并 ROI：%s（%d 像素）。',mergedName,nnz(merged));
  update_controls();update_ready();publish();
 end
 function use_template(~,~)
  if legacy||frozen||~current(),return;end
  clear_tissue();reset_partition();
 end
 function reset_partition(varargin)
  if legacy||frozen||~current(),return;end
  try
   if strcmp(tissueMode,'freehand'),clear_tissue();end
   lim=get_limits();box=dsap_partition_template('fitbox',reference,lim);template=dsap_partition_template('default');
   defaultFile=fullfile(fileparts(mfilename('fullpath')),'templates','default_partition_template.mat');
   if isfile(defaultFile),v=load(defaultFile,'template');template=v.template;end
   controls=dsap_partition_template('apply',template,box);install(controls);
  catch e,note.Text=e.message;end
 end
 function install(controls)
  if ~current(),return;end
  if strcmp(tissueMode,'freehand'),clear_tissue();end
  release_listeners();
  if ~isempty(outer)&&isvalid(outer),delete(outer);end
  if ~isempty(inner)&&isvalid(inner),delete(inner);end
  lim=get_limits();area=[.5 lim.UpperRow-.5 size(reference,2) lim.LowerRow-lim.UpperRow+1];
  outer=drawpolygon(ax,'Position',controls.Outer,'Color',t.OuterColor,'FaceAlpha',0,'DrawingArea',area);
  inner=drawpolygon(ax,'Position',controls.Inner,'Color',t.InnerColor,'FaceAlpha',0,'DrawingArea',area);
  outer.Deletable=false;inner.Deletable=false;
  listeners=[addlistener(outer,'MovingROI',@(~,~) preview_lines()),addlistener(inner,'MovingROI',@(~,~) preview_lines()), ...
   addlistener(outer,'ROIMoved',@(~,~) refresh()),addlistener(inner,'ROIMoved',@(~,~) refresh())];
  tissueMode='template';update_controls();refresh();update_ready();publish();
 end
 function preview_lines
  if ~current()||isempty(outer)||~isvalid(outer)||isempty(inner)||~isvalid(inner),return;end
  % Match the old editor: preview curves during drag; validate masks on release.
  o=dsap_partition_curve(outer.Position);i=dsap_partition_curve(inner.Position);
  ol.XData=o(:,1);ol.YData=o(:,2);il.XData=i(:,1);il.YData=i(:,2);
 end
 function refresh
  if ~current()||legacy||~strcmp(tissueMode,'template')||isempty(outer)||~isvalid(outer)||isempty(inner)||~isvalid(inner),return;end
  try
   p=dsap_partition_from_controls(outer.Position,inner.Position,size(reference),get_limits());
   ol.XData=p.OuterCurve(:,1);ol.YData=p.OuterCurve(:,2);il.XData=p.InnerCurve(:,1);il.YData=p.InnerCurve(:,2);
   note.Text=sprintf('AIF %d · Cortex %d · Subcortex %d pixels',nnz(mask),nnz(p.CortexMask),nnz(p.SubcortexMask));
  catch e,note.Text=e.message;end
  update_ready();
 end
 function update_ready
  if ~current()||~isgraphics(confirm),return;end
  ready=nnz(mask)>=3;reason='请先绘制至少 3 像素的 AIF。';
  try,get_limits();catch e,ready=false;reason=e.message;end
  if legacy
   if isempty(imported.Masks),ready=false;reason='没有可用的 TIMESlice 组织 ROI。';end
  elseif strcmp(tissueMode,'freehand')
   if isempty(manualMasks)||nnz(tissueMask)<3,ready=false;reason='请完成至少 3 像素的手绘组织 ROI。';end
  elseif strcmp(tissueMode,'template')
   try,dsap_partition_from_controls(outer.Position,inner.Position,size(reference),get_limits());
   catch e,ready=false;reason=['模板分区无效：' e.message];end
  else,ready=false;reason='请选择手绘 ROI 或使用模板。';end
  if nnz(mask)<3,ready=false;reason='请先绘制至少 3 像素的 AIF。';end
  confirm.Enable=onoff(ready);
  aifStatus.Text=sprintf('AIF · %s',completion(nnz(mask)>=3));
  tissueStatus.Text=sprintf('组织 ROI · %s',completion(legacy||~strcmp(tissueMode,'none')));
  limitsStatus.Text=sprintf('颅内范围 · %d–%d 行',round(up.Value),round(lo.Value));
  if ~ready&&~frozen,note.Text=['尚不能分析：' reason];end
 end
 function update_controls
  if ~current(),return;end
  editable=~legacy&&~frozen;
  freehandButton.Text='ROI 绘制 / 编辑';templateButton.Text='使用模板 / 分区';loadTemplate.Text='载入模板';
  
  if strcmp(tissueMode,'freehand')
   templateButton.Text='使用模板（替换手绘）';loadTemplate.Text='载入模板（替换手绘）';
  end
  drawButton.Enable=onoff(editable);tool.Enable=onoff(editable);aifMode.Enable=onoff(editable);roiAction.Enable=onoff(editable);
  freehandButton.Enable=onoff(editable);templateButton.Enable=onoff(editable);
  clearButton.Enable=onoff(editable&&~strcmp(tissueMode,'none'));
  mergeButton.Enable=onoff(editable&&numel(roiList.Value)>=2);
  roiList.Enable=onoff(editable&&nnz(strcmp(manualTypes,'Individual'))>=1);
  roiName.Enable=onoff(editable&&~strcmp(tissueMode,'template'));
  applyTemplate.Enable=onoff(editable&&strcmp(tissueMode,'template'));
  loadTemplate.Enable=onoff(editable);target.Enable=onoff(editable&&strcmp(tissueMode,'template'));
  resetTemplate.Enable=onoff(editable&&strcmp(tissueMode,'template'));
  for j=1:numel(transformButtons),transformButtons(j).Enable=onoff(editable&&strcmp(tissueMode,'template'));end
 end
 function transform(v)
  if ~current()||frozen||legacy||isempty(outer)||~isvalid(outer)||isempty(inner)||~isvalid(inner),return;end
  handles={outer,inner};if strcmp(target.Value,'Outer'),handles={outer};elseif strcmp(target.Value,'Inner'),handles={inner};end
  center=mean(handles{1}.Position,1);rotation=[cosd(v(2)) -sind(v(2));sind(v(2)) cosd(v(2))];
  previous=cellfun(@(h) h.Position,handles,'UniformOutput',false);
  try
   for j=1:numel(handles),handles{j}.Position=(handles{j}.Position-center)*rotation'*v(1)+center+v(3:4)*max(1,min(size(reference))/200);end
  catch e
   for j=1:numel(handles),handles{j}.Position=previous{j};end
   note.Text=['调整未应用：' e.message];return;
  end
  refresh();
 end
 function load_template(~,~)
  if ~current()||frozen||legacy,return;end
  [name,path]=uigetfile('*.mat');if isequal(name,0),return;end
  if ~current(),return;end
  try,v=load(fullfile(path,name),'template');box=dsap_partition_template('fitbox',reference,get_limits());install(dsap_partition_template('apply',v.template,box));catch e,note.Text=e.message;end
 end
 function overview(~,~)
  if ~current(),return;end
  pause_cine();
  try
   if ~isempty(roi)&&isvalid(roi),mask=createMask(roi,im);end
   assert(nnz(mask)>=3,'AIF 至少需要 3 个像素。');limits=get_limits();upperLine.Value=limits.UpperRow;lowerLine.Value=limits.LowerRow;
   if ~legacy&&strcmp(tissueMode,'template')
    partition=dsap_partition_from_controls(outer.Position,inner.Position,size(reference),limits);partition.Confirmed=true;
    partition.TemplateFitBox=dsap_partition_template('fitbox',reference,limits);
    partition.Template=dsap_partition_template('savegeometry',partition,partition.TemplateFitBox);
    outer.InteractionsAllowed='none';inner.InteractionsAllowed='none';outer.Visible=false;inner.Visible=false;
   elseif ~legacy&&strcmp(tissueMode,'freehand')
    assert(~isempty(manualMasks)&&nnz(tissueMask)>=3,'请先完成组织 ROI 手绘。');
    partition=struct('Mode','Freehand','Method','legacy-drawfreehand-createMask', ...
     'Masks',{manualMasks},'Names',{manualNames},'SelectedFrames',manualFrames, ...
     'Types',{manualTypes},'MergeSources',{manualSources},'Confirmed',true);
    if ~isempty(territoryRecords),partition.TerritoryProvenance=territoryRecords;end
   elseif ~legacy
    error('请先手绘组织 ROI 或使用模板。');
   end
   if ~isempty(roi)&&isvalid(roi),roi.InteractionsAllowed='none';end
   frozen=true;up.Enable='off';lo.Enable='off';drawButton.Enable='off';
   update_controls();confirm.Enable='on';back.Visible='on';
   summary.Text='返回编辑';summary.ButtonPushedFcn=@back_draft;
   show_reference();note.Text=sprintf('只读总览 · AIF %d 像素 · 颅内行 %d–%d。确认后锁定。',nnz(mask),limits.UpperRow,limits.LowerRow);
   settings=getappdata(fig,'DSAPWorkspaceScientificSettings');
   if isstruct(settings)&&isfield(settings,'ContrastPolarity')
    note.Text=sprintf('%s 基线帧 %g / 丢弃帧 %g / 备用帧率 %g fps / 增强方向 %s。', ...
     note.Text,settings.BaselineFrames,settings.ManualDiscardedFrames,settings.FallbackFrameRate,settings.ContrastPolarity);
   end
   side='未知';if legacy,side=strjoin(unique({imported.Semantics.Side}),', ');end
   note.Text=[note.Text ' 侧别：' side];note.Tooltip=note.Text;
  catch e
   note.Text=['不能确认：' e.message];dsap_workspace_log_error(fig,e,'ROI validation');
   dsap_workspace_bridge('activity','Error','ROI Setup',note.Text);drawnow;
  end
 end
 function back_draft(~,~)
  if ~current(),return;end
  frozen=false;up.Enable='on';lo.Enable='on';confirm.Enable='off';back.Visible='off';
  summary.Text='查看只读总览（可选）';summary.ButtonPushedFcn=@overview;
  if ~legacy
   drawButton.Enable='on';freehandButton.Enable='on';templateButton.Enable='on';clearButton.Enable='on';
   if strcmp(tissueMode,'template'),outer.InteractionsAllowed='all';inner.InteractionsAllowed='all';outer.Visible=true;inner.Visible=true;end
   if strcmp(tissueMode,'freehand')&&~isempty(tissueROI)&&isvalid(tissueROI),tissueROI.InteractionsAllowed='all';end
  end
  if ~isempty(roi)&&isvalid(roi),roi.InteractionsAllowed='all';end
  update_controls();
  update_ready();
 end
 function accept(~,~)
  if ~current(),return;end
  close_children();note.Text='正在锁定 ROI…';drawnow;
  if ~frozen,overview([],[]);end
  if ~frozen,return;end
  try
   if legacy
    dsap_validate_legacy_files(imported);
    if isfield(imported.Provenance,'SourceValidation')&&isfield(imported.Provenance.SourceValidation,'ParentSourceIdentity')
     expected=imported.Provenance.SourceValidation.ParentSourceIdentity;actual=dsap_source_identity(expected.Path);
     assert(strcmp(actual.SHA256,expected.SHA256),'DSAP:LegacySourceChanged','预览期间 Serial 原图发生变化，请重新导入。');
    end
    imported.Confirmed=true;
   end
   done=true;dispose_draft();uiresume(fig);
  catch e
   note.Text=['ROI 锁定失败：' e.message];dsap_workspace_log_error(fig,e,'ROI confirmation');
   dsap_workspace_bridge('activity','Error','ROI Setup',note.Text);drawnow;
  end
 end
 function show_frame(value)
  if ~current(),return;end
  if showingReference,ax.CLim=nativeCLim;width.Value=diff(nativeCLim);level.Value=mean(nativeCLim);showingReference=false;end
  frame=max(1,min(size(sequence,1),round(value)));im.CData=squeeze(sequence(frame,:,:));slider.Value=frame;frameLabel.Text=sprintf('第 %d / %d 帧',frame,size(sequence,1));
 end
 function slider_changed(source,~)
  if ~current()||~isgraphics(source),return;end
  show_frame(source.Value);
 end
 function show_reference
  if ~current(),return;end
  pause_cine();if ~showingReference,nativeCLim=ax.CLim;end;showingReference=true;im.CData=reference;auto_window();
 end
 function auto_window
  if ~current(),return;end
  range=double([min(im.CData(:)) max(im.CData(:))]);if range(1)==range(2),range(2)=range(1)+1;end
  width.Value=diff(range);level.Value=mean(range);ax.CLim=range;
 end
 function window_changed(~,~),if current(),ax.CLim=level.Value+[-.5 .5]*width.Value;end,end
 function play_frames(~,~)
  if ~current()||~isvalid(timerObject),return;end
  playing=~playing;if playing,play.Text='暂停';start(timerObject);else,play.Text='播放';stop(timerObject);end
 end
 function advance(~,~),if playing&&current()&&~suspended&&isvalid(timerObject),show_frame(mod(frame,size(sequence,1))+1);end,end
 function toggle_advanced(~,~)
  if ~current(),return;end
  expanded=strcmp(advanced.Visible,'off');advanced.Visible=onoff(expanded);
  rows=inspect.RowHeight;if expanded,rows{11}=340;advancedToggle.Text='高级工具 ▾';else,rows{11}=0;advancedToggle.Text='高级工具 ▸';end
  inspect.RowHeight=rows;
 end
 function toggle_overlay(varargin)
  if ~current(),return;end
  handles=[aifBoundary(:);tissueBoundary(:);ol;il;upperLine;lowerLine];
  handles=handles(isgraphics(handles));set(handles,'Visible',onoff(overlay.Value));
 end
 function pause_cine
  playing=false;if isgraphics(play),play.Text='播放';end
  if isvalid(timerObject)&&strcmp(timerObject.Running,'on'),stop(timerObject);end
 end
 function release_listeners
  if ~isempty(listeners),delete(listeners(isvalid(listeners)));end
  listeners=[];
 end
 function dispose_draft
  if retired,return;end
  retired=true;close_children();pause_cine();release_listeners();stop_timer(timerObject);
  objects={roi,outer,inner,tissueROI};
  for j=1:numel(objects),if ~isempty(objects{j})&&isvalid(objects{j}),delete(objects{j});end,end
  roi=[];outer=[];inner=[];tissueROI=[];
  if isgraphics(fig)&&isappdata(fig,'DSAPWorkspaceROIDraft')
   active=getappdata(fig,'DSAPWorkspaceROIDraft');
   if strcmp(active.RunID,runID),rmappdata(fig,'DSAPWorkspaceROIDraft');end
  end
 end
end
function value=completion(ready)
if ready,value='✓ 已就绪';else,value='待完成';end
end
function value=onoff(flag)
if flag,value='on';else,value='off';end
end
function stop_timer(t)
if isvalid(t),stop(t);delete(t);end
end
