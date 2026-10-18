function f=dsap_workspace
% Production Workspace v1. Scientific engine remains in the existing workflow.
t=dsap_theme;
% A transient, minimal splash paints before uifigure's comparatively slow
% first construction. It is removed as soon as the real Workspace shell is visible.
splash=figure('Name','DSAP · 正在启动','NumberTitle','off','MenuBar','none','ToolBar','none', ...
 'Position',[80 80 380 110],'Color',t.Background,'Visible',get(groot,'DefaultFigureVisible'));
splashCleanup=onCleanup(@() close_startup_splash(splash));
uicontrol(splash,'Style','text','String','DSAP  ·  正在启动…', ...
 'Position',[22 30 335 48],'BackgroundColor',t.Background,'ForegroundColor',t.Primary, ...
 'FontSize',t.PageTitle,'FontWeight','bold','HorizontalAlignment','left');
drawnow;firstFeedbackAt=datetime('now','TimeZone','UTC');
screen=get(groot,'ScreenSize');windowSize=min([1440 900],screen(3:4)-[40 100]);
f=uifigure('Name','DSAP Workspace','Position',[screen(1:2)+[20 50] windowSize],'Color',t.Background,'AutoResizeChildren','off','Visible','off');
f.SizeChangedFcn=@minimum_size;
f.CloseRequestFcn=@(~,~) delete(f); % Startup shell is safe before state/controls exist.
f.DeleteFcn=@cleanup_activity_timer;
g=uigridlayout(f,[3 2],'RowHeight',{60,'1x',38},'ColumnWidth',{174,'1x'}, ...
 'Padding',[12 10 12 10],'RowSpacing',8,'ColumnSpacing',10,'BackgroundColor',t.Background);
top=uigridlayout(g,[1 6],'ColumnWidth',{72,'1x',190,80,105,125},'Padding',[16 4 10 4], ...
 'ColumnSpacing',12,'BackgroundColor',t.Surface);top.Layout.Row=1;top.Layout.Column=[1 2];
uilabel(top,'Text','DSAP','FontSize',t.Title,'FontWeight','bold','FontColor',t.Primary);
caseLabel=uilabel(top,'Text','正在启动…','FontSize',t.Body,'Interpreter','none','FontColor',t.TextPrimary);
activityShort=uilabel(top,'Text','准备中','FontColor',t.TextPrimary,'HorizontalAlignment','right');
saveLabel=uilabel(top,'Text','未保存','FontColor',t.TextSecondary,'HorizontalAlignment','right');
saveButton=uibutton(top,'Text','保存 / 导出','Enable','off','ButtonPushedFcn',@(~,~) navigate(6));
newCaseButton=uibutton(top,'Text','新建分析','Tooltip','关闭当前病例并准备新分析；未保存结果会先提示','ButtonPushedFcn',@(~,~) request_case_change('new'));
setappdata(f,'DSAPWorkspaceNewCaseButton',newCaseButton);f.WindowKeyPressFcn=@workspace_key;
setappdata(f,'DSAPTopStatusControls',struct('Case',caseLabel,'Analysis',activityShort,'Save',saveLabel,'Action',saveButton));
nav=uigridlayout(g,[7 2],'RowHeight',{40,40,40,40,40,40,'1x'},'ColumnWidth',{4,'1x'}, ...
 'Padding',[5 12 5 12],'RowSpacing',5,'ColumnSpacing',2,'BackgroundColor',t.Sidebar);nav.Layout.Row=2;
host=uigridlayout(g,[1 1],'Padding',0,'BackgroundColor',t.Background);host.Layout.Row=2;host.Layout.Column=2;
bottom=uilabel(g,'Text','正在启动 · 初始化工作区','FontColor',t.TextSecondary, ...
 'BackgroundColor',t.Surface,'FontSize',t.Caption);bottom.Layout.Row=3;bottom.Layout.Column=[1 2];
setappdata(f,'DSAPActivityLabel',bottom);
f.Visible='on';drawnow;
setappdata(f,'DSAPStartupFirstFeedbackAt',firstFeedbackAt);
setappdata(f,'DSAPStartupFeedbackAt',datetime('now','TimeZone','UTC'));
clear splashCleanup;
bottom.Text='正在载入导入页面…';drawnow;
names={'导入','ROI 设置','分析','结果','曲线 / QC','导出'};pages=gobjects(1,6);buttons=gobjects(1,6);navIndicators=gobjects(1,6);
for k=1:6
 navIndicators(k)=uilabel(nav,'Text','','BackgroundColor',t.Sidebar);navIndicators(k).Layout.Row=k;navIndicators(k).Layout.Column=1;
 buttons(k)=uibutton(nav,'Text',['○  ' names{k}],'Enable','off','BackgroundColor',t.Sidebar, ...
  'FontColor',t.TextSecondary,'ButtonPushedFcn',@(a,b) select_page(k));buttons(k).Layout.Row=k;buttons(k).Layout.Column=2;
 setappdata(buttons(k),'DSAPSidebarItem',true);
end
s=struct('CurrentPage',1,'RunID','','SourceStatus','empty','ROIStatus','empty', ...
 'AnalysisStatus','idle','SaveStatus','empty','ExportStatus','not_exported', ...
 'CAVEStatus','pending','ViewHandles',struct(),'Busy',false,'SourceFile','','Legacy',false,'OperationID','');
s.Activity=dsap_activity_state('new');
setappdata(f,'WorkspaceState',s);
stageNames={'Preparing','AIF / Timing','Signal Quality','CAVE','Deconvolution', ...
 'Post-processing','ROI Statistics','Rendering Results','Saving'};
stageItems=gobjects(1,numel(stageNames));stageLabel=[];cardState=[];cardStage=[];cardDescription=[];
cardElapsed=[];detailStage=[];detailElapsed=[];detailLast=[];detailWorker=[];
analysisHost=[];analysisDetails=[];roiHost=[];curveTab=[];irfTab=[];vesselTab=[];signalTab=[];partitionTab=[];provenance=[];
tab=[];status=[];folderText=[];openButton=[];exportButton=[];exportStatus=[];retry=[];
page1started=tic;
pages(1)=uipanel(host,'BorderType','none','Visible','off','BackgroundColor',t.Surface);
pages(1).Layout.Row=1;pages(1).Layout.Column=1;
importContainer=uigridlayout(pages(1),[1 1],'Padding',0);
ig=uigridlayout(importContainer,[10 3],'RowHeight',{42,28,14,44,36,36,65,42,44,'1x'}, ...
 'ColumnWidth',{240,240,'1x'},'Padding',t.PagePadding,'RowSpacing',t.Spacing(2),'BackgroundColor',t.Surface);
heading=uilabel(ig,'Text','导入 DSA','FontSize',t.PageTitle,'FontWeight','bold','FontColor',t.TextPrimary);heading.Layout.Column=[1 3];
sub=uilabel(ig,'Text','选择影像序列，核对来源后开始 ROI 设置','FontColor',t.TextSecondary);sub.Layout.Row=2;sub.Layout.Column=[1 3];
fileButton=uibutton(ig,'Text','选择 DICOM 文件','ButtonPushedFcn',@choose_file);fileButton.Layout.Row=4;fileButton.Layout.Column=1;
folderButton=uibutton(ig,'Text','选择文件夹','ButtonPushedFcn',@choose_folder);folderButton.Layout.Row=4;folderButton.Layout.Column=2;
sourceText=uilabel(ig,'Text','尚未选择影像','Interpreter','none','FontColor',t.TextPrimary);sourceText.Layout.Row=5;sourceText.Layout.Column=[1 3];
metaText=uilabel(ig,'Text','尺寸、帧数和来源信息将在此显示','Interpreter','none','FontColor',t.TextSecondary);metaText.Layout.Row=6;metaText.Layout.Column=[1 3];
seriesList=uilistbox(ig,'Items',{},'Visible','off','ValueChangedFcn',@select_series);seriesList.Layout.Row=7;seriesList.Layout.Column=[1 2];
folderCandidates=struct([]);folderRoot='';
ig.Layout.Row=1;ig.Layout.Column=1;
sequenceHost=uipanel(importContainer,'BorderType','none','Visible','off');
sequenceHost.Layout.Row=1;sequenceHost.Layout.Column=1;
importNote=uilabel(ig,'Text','ROI 在正式分析前确认并锁定。','WordWrap','on','FontColor',t.TextSecondary);importNote.Layout.Row=7;importNote.Layout.Column=[1 3];
legacyButton=uibutton(ig,'Text','历史 ROI 导入 · TIMESlice','Tooltip','迁移已绘制的历史 ROI；严格校验来源和方向','ButtonPushedFcn',@choose_legacy);legacyButton.Layout.Row=8;legacyButton.Layout.Column=1;
startButton=uibutton(ig,'Text','继续：ROI 设置','Enable','off','ButtonPushedFcn',@start_native);startButton.Layout.Row=9;startButton.Layout.Column=[1 2];
view=struct('Perfusion',f,'Table',f,'Workspace',true);
setappdata(f,'DSAPWorkspaceView',view);setappdata(f,'DSAPWorkspaceDispatch',@dispatch);
initialState=getappdata(f,'WorkspaceState');initialState.ViewHandles=view;setappdata(f,'WorkspaceState',initialState);
pageCreateSeconds=zeros(1,6);pageCreateSeconds(1)=toc(page1started);
setappdata(f,'DSAPPageCreateSeconds',pageCreateSeconds);
setappdata(f,'DSAPWorkspaceRun',@start_native);setappdata(f,'DSAPWorkspaceImport',@load_source);
setappdata(f,'DSAPWorkspaceScanFolder',@scan_folder);
setappdata(f,'DSAPWorkspaceLegacyImport',@load_legacy);
setappdata(f,'DSAPWorkspaceImportControls',struct('File',fileButton,'Folder',folderButton,'Legacy',legacyButton,'Start',startButton));
dsap_workspace_style(f);navigate(1);caseLabel.Text='请选择 DICOM 影像';f.CloseRequestFcn=@close_workspace;
set_activity('Ready','','请选择 DICOM 影像',false);drawnow;
setappdata(f,'DSAPShellInteractiveAt',datetime('now','TimeZone','UTC'));
setappdata(f,'DSAPWorkspaceReadyAt',getappdata(f,'DSAPShellInteractiveAt'));
activityTimer=timer('ExecutionMode','fixedSpacing','Period',1,'BusyMode','drop', ...
 'TimerFcn',@(~,~) refresh_activity());setappdata(f,'DSAPActivityTimer',activityTimer);start(activityTimer);

 function minimum_size(~,~)
  position=f.Position;screenNow=get(groot,'ScreenSize');minimum=min([1100 760],screenNow(3:4)-[40 100]);
  shape=max(position(3:4),minimum);if ~isequal(shape,position(3:4)),f.Position=[position(1:2) shape];end
 end

 function ensure_page(n)
  if isgraphics(pages(n)),return;end
  created=tic;
  if n==6 && ~isgraphics(pages(4)),ensure_page(4);end
  if isgraphics(pages(n)),return;end
  pages(n)=uipanel(host,'BorderType','none','Visible','off','BackgroundColor',t.Surface);
  pages(n).Layout.Row=1;pages(n).Layout.Column=1;
  switch n
   case 2
    rg=uigridlayout(pages(n),[2 1],'RowHeight',{44,'1x'},'Padding',[12 8 12 8], ...
     'RowSpacing',t.SectionGap,'BackgroundColor',t.Surface);
    roiHeader=uigridlayout(rg,[1 2],'ColumnWidth',{'1x',120},'Padding',0);
    uilabel(roiHeader,'Text','ROI 设置','FontSize',t.PageTitle,'FontWeight','bold','FontColor',t.TextPrimary);
    change=uibutton(roiHeader,'Text','更换影像','ButtonPushedFcn',@(~,~) request_case_change('change'));
    setappdata(f,'DSAPWorkspaceChangeSourceButton',change);
    roiHost=uipanel(rg,'BorderType','none','BackgroundColor',t.Surface);
   case 3
    ag=uigridlayout(pages(n),[4 1],'RowHeight',{45,126,'1x',42}, ...
     'Padding',t.PagePadding,'RowSpacing',t.SectionGap,'BackgroundColor',t.Background);
    uilabel(ag,'Text','分析','FontSize',t.PageTitle,'FontWeight','bold','FontColor',t.TextPrimary);
    card=uipanel(ag,'BorderType','line','BackgroundColor',t.Surface);
    cg=uigridlayout(card,[3 2],'RowHeight',{26,40,'1x'},'ColumnWidth',{'1x',175}, ...
     'Padding',[18 12 18 12],'RowSpacing',3,'BackgroundColor',t.Surface);
    cardState=uilabel(cg,'Text','准备中','FontColor',t.Primary,'FontWeight','bold');cardState.Layout.Row=1;
    cardElapsed=uilabel(cg,'Text','已运行 00:00','HorizontalAlignment','right', ...
     'FontColor',t.TextSecondary);cardElapsed.Layout.Row=1;cardElapsed.Layout.Column=2;
    cardStage=uilabel(cg,'Text','准备','FontSize',t.Title,'FontWeight','bold','FontColor',t.TextPrimary);
    cardStage.Layout.Row=2;cardStage.Layout.Column=[1 2];
    cardDescription=uilabel(cg,'Text','正在准备分析','FontColor',t.TextSecondary,'WordWrap','on');
    cardDescription.Layout.Row=3;cardDescription.Layout.Column=[1 2];
    body=uigridlayout(ag,[1 2],'ColumnWidth',{270,'1x'},'Padding',0,'ColumnSpacing',t.SectionGap, ...
     'BackgroundColor',t.Background);
    stages=uipanel(body,'BorderType','line','BackgroundColor',t.Surface);stages.Layout.Column=1;
    sg=uigridlayout(stages,[10 1],'RowHeight',[{30} repmat({31},1,9)], ...
     'Padding',[15 12 12 10],'RowSpacing',3,'BackgroundColor',t.Surface);
    uilabel(sg,'Text','分析阶段','FontWeight','bold','FontColor',t.TextPrimary);
    for i=1:numel(stageNames)
     stageItems(i)=uilabel(sg,'Text',['○  ' stage_name(stageNames{i})], ...
      'FontColor',t.TextSecondary,'BackgroundColor',t.Surface);
    end
    right=uigridlayout(body,[1 1],'Padding',0,'BackgroundColor',t.Background);right.Layout.Column=2;
    analysisDetails=uipanel(right,'BorderType','line','BackgroundColor',t.Surface);
    analysisDetails.Layout.Row=1;analysisDetails.Layout.Column=1;
    dg=uigridlayout(analysisDetails,[7 1],'RowHeight',{33,38,29,38,29,38,'1x'}, ...
     'Padding',[20 14 20 14],'RowSpacing',5,'BackgroundColor',t.Surface);
    uilabel(dg,'Text','当前任务','FontWeight','bold','FontColor',t.TextPrimary);
    detailStage=uilabel(dg,'Text','等待开始','FontSize',t.Section,'FontColor',t.Primary);
    uilabel(dg,'Text','已运行','FontColor',t.TextSecondary);
    detailElapsed=uilabel(dg,'Text','00:00','FontSize',t.Section,'FontColor',t.TextPrimary);
    uilabel(dg,'Text','最后活动 / 任务状态','FontColor',t.TextSecondary);
    detailLast=uilabel(dg,'Text','尚无计算检查点','FontColor',t.TextPrimary);
    detailWorker=uilabel(dg,'Text','同步计算期间状态以最后检查点为准','FontColor',t.TextSecondary,'WordWrap','on');
    analysisHost=uipanel(right,'BorderType','none','Visible','off','BackgroundColor',t.Surface);
    analysisHost.Layout.Row=1;analysisHost.Layout.Column=1;
    cancelRow=uigridlayout(ag,[1 2],'ColumnWidth',{'1x',128},'Padding',0,'BackgroundColor',t.Background);
    cancelButton=uibutton(cancelRow,'Text','取消分析','ButtonPushedFcn',@cancel_run);
    cancelButton.Layout.Column=2;
    setappdata(f,'DSAPWorkspaceCancelButton',cancelButton);
    setappdata(f,'DSAPAnalyzeControls',struct('State',cardState,'Stage',cardStage, ...
     'Description',cardDescription,'Elapsed',cardElapsed,'Steps',stageItems, ...
     'LastActivity',detailLast,'Worker',detailWorker));
    update_stages(getappdata(f,'WorkspaceState').Activity);
   case 4
    resultGrid=uigridlayout(pages(n),[4 1],'RowHeight',{40,'3x',25,'1x'}, ...
     'Padding',t.Space.L,'RowSpacing',t.Space.S,'BackgroundColor',t.Surface);
    resultHeader=uigridlayout(resultGrid,[1 4],'ColumnWidth',{'1x',180,220,245},'Padding',0,'BackgroundColor',t.Surface);
    uilabel(resultHeader,'Text','灌注结果','FontSize',t.PageTitle,'FontWeight','bold','FontColor',t.TextPrimary);
    inclusiveButton=uibutton(resultHeader,'Text','组织 / 保留大血管对照','Enable','off','ButtonPushedFcn',@open_inclusive);
    setappdata(f,'DSAPWorkspaceInclusiveButton',inclusiveButton);
    geometryButton=uibutton(resultHeader,'Text','血管中心线 / 几何','Enable','off', ...
     'Tooltip','复用当前病例的血管提取结果，通过端点和引导点提取中心线', ...
     'ButtonPushedFcn',@open_geometry);
    setappdata(f,'DSAPWorkspaceGeometryButton',geometryButton);
    distributionButton=uibutton(resultHeader,'Text','Distribution / Heterogeneity','Enable','off', ...
     'Tooltip','查看当前 ROI 灌注分布、空间异质性及 QC','ButtonPushedFcn',@open_distribution);
    setappdata(f,'DSAPWorkspaceDistributionButton',distributionButton);
    mapPanel=uipanel(resultGrid,'BorderType','none','BackgroundColor',t.Surface);mapPanel.Layout.Row=2;
    mapGrid=tiledlayout(mapPanel,2,3,'TileSpacing','compact','Padding','compact');
    h=struct('Axes',gobjects(4,1),'Images',gobjects(4,1),'Backgrounds',gobjects(4,1), ...
     'Colorbars',gobjects(4,1),'Shape',[2 2]);
    labels={'CBF（相对值）','CBV（相对值）','Tmax (s)','MTT (s)'};
    perfusionTiles=[1 2 4 5];
    for i=1:4
     ax=nexttile(mapGrid,perfusionTiles(i));h.Axes(i)=ax;h.Backgrounds(i)=image(ax,repmat(single(.65),[2 2 3]));hold(ax,'on');
     h.Images(i)=imagesc(ax,nan(2));h.Images(i).AlphaData=0;axis(ax,'image','off');ax.YDir='reverse';colormap(ax,turbo);
     h.Colorbars(i)=colorbar(ax);title(ax,labels{i});dsap_style_axes(ax);
     h.Colorbars(i).FontName=t.Font;h.Colorbars(i).FontSize=t.Caption;h.Colorbars(i).Color=t.TextSecondary;h.Colorbars(i).Box='off';
    end
    h.CAVE=dsap_prepare_cave_result_view(mapGrid,[3 6]);
    section=uilabel(resultGrid,'Text','ROI 参数','FontWeight','bold','FontColor',t.TextPrimary);section.Layout.Row=3;
    tab=uitable(resultGrid,'RowName',[],'ColumnWidth','auto','CellSelectionCallback',@table_selected);tab.Layout.Row=4;
    setappdata(f,'DSAPCriticalView',h);
    ensure_page(6); % Save/export controls are prepared with the critical result owner, before science.
   case 5
    qg=uigridlayout(pages(n),[2 1],'RowHeight',{42,'1x'},'Padding',t.PagePadding, ...
     'RowSpacing',t.SectionGap,'BackgroundColor',t.Surface);
    uilabel(qg,'Text','曲线与质量检查','FontSize',t.PageTitle,'FontWeight','bold','FontColor',t.TextPrimary);
    tabs=uitabgroup(qg);
    curveTab=uitab(tabs,'Title','TIC');irfTab=uitab(tabs,'Title','IRF');vesselTab=uitab(tabs,'Title','血管');
    partitionTab=uitab(tabs,'Title','ROI');signalTab=uitab(tabs,'Title','信号质量');provTab=uitab(tabs,'Title','溯源');
    pg=uigridlayout(provTab,[1 1]);provenance=uitextarea(pg,'Editable','off');
    view.Curves=curveTab;view.Vessels=vesselTab;view.Partition=partitionTab;
    setappdata(f,'DSAPWorkspaceQCTabs',struct('Group',tabs,'TIC',curveTab,'IRF',irfTab, ...
     'Vessel',vesselTab,'ROI',partitionTab,'SignalQuality',signalTab,'Provenance',provTab));
    store_view();
   case 6
    eg=uigridlayout(pages(n),[10 2],'RowHeight',{42,28,42,56,36,24,42,42,36,'1x'}, ...
     'ColumnWidth',{240,'1x'},'Padding',t.PagePadding,'RowSpacing',t.Spacing(2),'BackgroundColor',t.Surface);
    exportHeading=uilabel(eg,'Text','保存与导出','FontSize',t.PageTitle,'FontWeight','bold','FontColor',t.TextPrimary);exportHeading.Layout.Row=1;exportHeading.Layout.Column=[1 2];
    coreHeading=uilabel(eg,'Text','核心科研结果','FontSize',t.Section,'FontWeight','bold','FontColor',t.TextPrimary);coreHeading.Layout.Row=2;coreHeading.Layout.Column=[1 2];
    status=uilabel(eg,'Text','尚未计算','WordWrap','on');status.Layout.Row=3;status.Layout.Column=[1 2];
    folderText=uilabel(eg,'Text','结果目录：—','Interpreter','none','WordWrap','on');folderText.Layout.Row=4;folderText.Layout.Column=[1 2];
    openButton=uibutton(eg,'Text','打开结果文件夹','Enable','off', ...
     'ButtonPushedFcn',@(~,~) winopen(getappdata(f,'OutputDirectory')));
    openButton.Layout.Row=5;openButton.Layout.Column=1;
    qcHeading=uilabel(eg,'Text','完整 QC 导出 · 图像与报告','FontSize',t.Section,'FontWeight','bold','FontColor',t.TextPrimary);qcHeading.Layout.Row=6;qcHeading.Layout.Column=[1 2];
    exportStatus=uilabel(eg,'Text','尚未导出','WordWrap','on');exportStatus.Layout.Row=7;exportStatus.Layout.Column=[1 2];
    exportButton=uibutton(eg,'Text','完整导出','Enable','off','ButtonPushedFcn',@export_full);exportButton.Layout.Row=8;exportButton.Layout.Column=1;
    retry=uibutton(eg,'Text','重试核心保存','Visible','off','ButtonPushedFcn',@retry_save);retry.Layout.Row=9;retry.Layout.Column=1;
    setappdata(f,'DSAPResultControls',struct('Table',tab,'Status',status, ...
     'Export',exportButton,'Retry',retry,'FullExportStatus',exportStatus));
  end
  if n==4,store_view();end
  dsap_workspace_style(pages(n));
  times=getappdata(f,'DSAPPageCreateSeconds');times(n)=toc(created);setappdata(f,'DSAPPageCreateSeconds',times);
  if all(isgraphics(pages)),setappdata(f,'DSAPWorkspaceFullyInitializedAt',datetime('now','TimeZone','UTC'));end
 end
 function store_view()
  setappdata(f,'DSAPWorkspaceView',view);
  state=getappdata(f,'WorkspaceState');state.ViewHandles=view;setappdata(f,'WorkspaceState',state);
 end

 function select_page(n)
  state=getappdata(f,'WorkspaceState');
  if n==2&&~state.Busy&&~strcmp(state.SourceStatus,'empty')&&ismember(state.AnalysisStatus,{'idle','cancelled','error'})
   start_native();return;
  end
  navigate(n);
 end
 function navigate(n)
  state=getappdata(f,'WorkspaceState');
  ready=ismember(state.AnalysisStatus,{'results_ready','complete'});
  allowed=[true ~strcmp(state.SourceStatus,'empty') state.Busy||~strcmp(state.AnalysisStatus,'idle') ...
   ready||(state.Busy&&strcmp(state.Activity.Stage,'Rendering Results')) ready ~strcmp(state.SaveStatus,'empty')];
  if ~allowed(n),set_activity('Waiting for input','','请先完成影像导入、ROI 确认或分析',false);return;end
  if n~=state.CurrentPage&&isappdata(f,'DSAPWorkspaceROIDraft')
   draft=getappdata(f,'DSAPWorkspaceROIDraft');
   if state.CurrentPage==2&&isfield(draft,'Suspend'),draft.Suspend();end
   if n==2&&isfield(draft,'Resume'),draft.Resume();end
  end
  ensure_page(n);
  complete=[strcmp(state.SourceStatus,'validated'),strcmp(state.ROIStatus,'frozen'),ready,ready,ready,strcmp(state.ExportStatus,'complete')];
  for j=1:6
   if isgraphics(pages(j)),pages(j).Visible=onoff(j==n);end
   buttons(j).Enable=onoff(allowed(j));
   marker='○';if complete(j),marker='✓';elseif j==n,marker='●';end
   buttons(j).Text=sprintf('%s  %s',marker,names{j});
   buttons(j).BackgroundColor=t.Sidebar;buttons(j).FontColor=t.TextPrimary;
   navIndicators(j).BackgroundColor=t.Sidebar;
   if j==n,buttons(j).BackgroundColor=t.Selected;navIndicators(j).BackgroundColor=t.Primary;end
   if ~allowed(j),buttons(j).FontColor=t.TextSecondary;buttons(j).Tooltip='请先完成影像导入、ROI 确认与分析。';else,buttons(j).Tooltip=names{j};end
  end
  state.CurrentPage=n;setappdata(f,'WorkspaceState',state);
 end
 function choose_file(~,~)
  if busy(),return;end
  [name,path]=uigetfile({'*.dcm;*.IMA;IM*','DSA DICOM';'*.*','All files'});if isequal(name,0),return;end
  seriesList.Visible='off';importNote.Visible='on';
  load_source(fullfile(path,name));
 end
 function choose_folder(~,~)
  if busy(),return;end
  path=uigetdir;if isequal(path,0),return;end
  scan_folder(path);
 end
 function scan_folder(path)
  if busy()||~reset_case('import'),return;end
  try
   set_activity('Preparing','Source scan','正在扫描 DICOM 文件夹并生成序列缩略图…',true);
   [folderCandidates,~]=scan_dicom_folder_sequences(path,@(~,message) set_activity('Preparing','Source scan',message,true));
   assert(~isempty(folderCandidates),'DSAP:NoSequences','所选文件夹没有至少 3 帧的灰度 DSA 序列。');
   folderRoot=path;show_sequences();
  catch e,report_error(e,'Folder scan');end
 end
 function show_sequences
  navigate(1);ig.Visible='off';sequenceHost.Visible='on';
  h=dsap_workspace_sequences(sequenceHost,folderCandidates,@use_sequence,@back_import,@() choose_folder([],[]));
  setappdata(f,'DSAPWorkspaceSequencePreview',h);
  set_activity('Waiting for input','Source selection','请选择序列并点击“使用此序列”',true);
 end
 function back_import
  sequenceHost.Visible='off';ig.Visible='on';navigate(1);
  set_activity('Waiting for input','Source selection','可重新选择文件夹或 DICOM 文件',true);
 end
 function use_sequence(file)
  if iscell(file)
   try
    root=fullfile(fileparts(mfilename('fullpath')),'interactive_results','patient_batches');
    folder=dsap_patient_batch(file,@run_batch_sequence,root);
    if isgraphics(f)
     batch=load(fullfile(folder,'patient_batch.mat'),'manifest');
     message=sprintf('已完成 %d / %d 个序列。\n患者汇总目录：%s',batch.manifest.Completed,numel(batch.manifest.Files),folder);
     uialert(f,message,'多序列分析','Icon','info');winopen(folder);
    end
   catch e
    if isgraphics(f),report_error(e,'Patient batch');end
   end
   return;
  end
  if load_source(file),sequenceHost.Visible='off';ig.Visible='on';start_native();end
 end
 function folder=run_batch_sequence(file,index,total)
  folder='';if ~isgraphics(f)||~load_source(file),return;end
  sequenceHost.Visible='off';ig.Visible='on';
  caseLabel.Text=sprintf('同一患者 · %d / %d · %s',index,total,caseLabel.Text);
  start_native();
  if ~isgraphics(f),return;end
  state=getappdata(f,'WorkspaceState');
  if strcmp(state.AnalysisStatus,'complete')&&strcmp(state.SaveStatus,'saved')&&isappdata(f,'OutputDirectory')
   folder=getappdata(f,'OutputDirectory');
  end
 end
 function select_series(src,~),load_source(src.Value);end
 function loaded=load_source(file)
  loaded=false;if busy(),return;end
  try
   if ~reset_case('import'),return;end
   set_activity('Preparing','Source validation','正在核对 DICOM 影像来源…',true);
   info=dicominfo(file);assert(isfield(info,'NumberOfFrames')&&info.NumberOfFrames>1,'请选择多帧 DSA DICOM。');
   if isappdata(f,'DSAPResultOwnerId')
    id=getappdata(f,'DSAPResultOwnerId');owner=dsap_result_owner('get',id);
    assert(owner.Saved,'DSAP:UnsavedResult','请先保存当前结果，再切换 source。');dsap_result_owner('release',id);rmappdata(f,'DSAPResultOwnerId');
   end
   state=getappdata(f,'WorkspaceState');state.SourceFile=file;state.SourceStatus='selected';state.ROIStatus='empty';
   state.AnalysisStatus='idle';state.SaveStatus='empty';state.ExportStatus='not_exported';state.Legacy=false;
   state.RunID=char(java.util.UUID.randomUUID());setappdata(f,'WorkspaceState',state);
   f.CloseRequestFcn=@close_workspace;setappdata(f,'DSAPCriticalReady',false);
   if isgraphics(exportButton)
    exportButton.Enable='off';retry.Visible='off';openButton.Enable='off';
    setappdata(exportButton,'OutputDirectory','');folderText.Text='结果目录：—';
    exportStatus.Text='尚未导出';status.Text='尚未计算';
   end
   if isappdata(f,'OutputDirectory'),rmappdata(f,'OutputDirectory');end
   sourceText.Text=file;[~,shortName,ext]=fileparts(file);caseLabel.Text=[shortName ext];caseLabel.Tooltip=file;metaText.Text=sprintf('%d × %d · %d 帧 · 正式分析前校验来源身份与 SHA256',info.Columns,info.Rows,info.NumberOfFrames);
   startButton.Enable='on';saveButton.Enable='off';saveLabel.Text='未保存';navigate(1);
   set_activity('Waiting for input','ROI Setup','已选择影像，请在分析前确认 ROI',true);
   loaded=true;
  catch e,report_error(e,'Source validation');end
 end
 function choose_legacy(~,~)
  if busy(),return;end
  try
   [file,entries,cancelled,origin]=dsap_timeslice_select(fileparts(mfilename('fullpath')));
   if cancelled,return;end
   load_legacy(file,entries,origin);
  catch e,report_error(e,'Legacy import');end
 end
 function load_legacy(file,entries,origin)
  if ~load_source(file),return;end
  state=getappdata(f,'WorkspaceState');state.Legacy=true;state.Entries=entries;state.Origin=origin;setappdata(f,'WorkspaceState',state);
  try
   set_activity('Preparing','Legacy validation','正在校验 TIMESlice 来源、方向及已有 ROI…',true);
   approved=load(fullfile(fileparts(mfilename('fullpath')),'contracts','TIMESlice_Legacy_Orientation_Contract_v1.mat'),'contract');
   [draft,identity]=dsap_timeslice_prepare_import(entries,file,dicominfo(file),origin,approved.contract);
   if isfield(identity,'LegacySourceLink'),draft.Provenance.SourceValidation=identity.LegacySourceLink;end
   state=getappdata(f,'WorkspaceState');state.LegacyDraft=draft;state.LegacyIdentity=identity;
   state.SourceStatus='validated';setappdata(f,'WorkspaceState',state);
  catch e
   state=getappdata(f,'WorkspaceState');state.SourceStatus='invalid';setappdata(f,'WorkspaceState',state);
   startButton.Enable='off';report_error(e,'Legacy validation',legacy_issue_message(e,entries));return;
  end
  startButton.Text='继续：预览已导入 ROI';
  importNote.Text='历史 ROI 只读迁移：严格校验来源、格式与方向；baseline 为 AIF，蓝青色为主要组织 ROI。';
  set_activity('Waiting for input','Legacy preview','来源和已有 ROI 校验通过，请继续只读预览',true);
 end
 function yes=busy
  state=getappdata(f,'WorkspaceState');yes=state.Busy;
  if yes,refresh_activity();end
 end
 function start_native(varargin)
  if busy(),return;end
  state=getappdata(f,'WorkspaceState');if isempty(state.SourceFile),return;end
  if strcmp(state.SourceStatus,'invalid'),set_activity('Error','Source validation','当前影像来源校验未通过，请更换影像。',true);return;end
  if isappdata(f,'DSAPResultOwnerId'),bottom.Text='当前结果已锁定；新分析请重新选择影像。';return;end
  state.Busy=true;state.RunID=char(java.util.UUID.randomUUID());state.OperationID=state.RunID;
  state.Activity=dsap_activity_state('new');state.ROIStatus='draft';state.AnalysisStatus='preparing';
  operation=state.OperationID;setappdata(f,'WorkspaceState',state);
  dsap_workspace_bridge('bind',struct('Figure',f,'Dispatch',@dispatch));cleanup=operation_cleanup(@finish_run,operation);
  navigate(3);set_activity('Computing','Preparing','正在准备 DSA 分析…',true);
  try,run_interactive_perfusion_remove_large_vessels;catch e
   if strcmp(e.identifier,'DSAP:Cancelled'),set_activity('Cancelled','','分析已取消',true);
   else,report_error(e,'Analysis');end
  end
  finish_run(operation);
 end
 function finish_run(operation)
  if ~isgraphics(f),return;end
  state=getappdata(f,'WorkspaceState');if ~state.Busy||~strcmp(state.OperationID,operation),return;end
  dsap_workspace_bridge('unbind');state.Busy=false;setappdata(f,'WorkspaceState',state);
  if isappdata(f,'DSAPPendingCaseAction')
   action=getappdata(f,'DSAPPendingCaseAction');rmappdata(f,'DSAPPendingCaseAction');reset_case(action);return;
  end
  if ~isappdata(f,'DSAPResultOwnerId')&&ismember(state.Activity.State,{'Cancelling','Cancelled','Error'})
   state.RunID=char(java.util.UUID.randomUUID());setappdata(f,'WorkspaceState',state);
   for key={'DSAPWorkspaceROIDraft','DSAPWorkspaceSettings','DSAPWorkspaceCAVE','DSAPFrozenSnapshot','DSAPConfirmedTask'}
    if isappdata(f,key{1}),rmappdata(f,key{1});end
   end
   if isgraphics(roiHost)
    delete(roiHost.Children);retryDraft=uigridlayout(roiHost,[2 1],'RowHeight',{55,42});
    uilabel(retryDraft,'Text','本轮草稿已结束。可重新准备 ROI，或更换影像。','WordWrap','on');
    uibutton(retryDraft,'Text','重新准备 ROI','ButtonPushedFcn',@start_native);
   end
   if isgraphics(analysisHost),delete(analysisHost.Children);analysisHost.Visible='off';analysisDetails.Visible='on';end
  end
  navigate(state.CurrentPage);
  if strcmp(state.Activity.State,'Cancelling'),set_activity('Cancelled','','已在安全检查点取消',true);
  elseif ~strcmp(state.AnalysisStatus,'complete')&&~ismember(state.Activity.State,{'Error','Cancelled','Warning'})
   report_error(MException('DSAP:IncompleteWorkflow','流程返回但没有生成结果；请查看错误日志后重试。'),'Workflow completion');
  end
 end
 function cancel_run(~,~)
  state=getappdata(f,'WorkspaceState');if ~state.Busy,return;end
  set_activity('Cancelling',state.Activity.Stage,'正在取消，将在当前操作结束后停止…',true);
  release_roi_draft();
  dsap_task_control('cancel');uiresume(f);
 end
 function varargout=dispatch(action,varargin)
  switch action
   case 'source',state=getappdata(f,'WorkspaceState');varargout={state};
   case 'confirmed'
    state=getappdata(f,'WorkspaceState');state.RunID=char(java.util.UUID.randomUUID());
    state.ROIStatus='frozen';setappdata(f,'WorkspaceState',state);
    setappdata(f,'DSAPFrozenSnapshot',varargin{1});
    setappdata(f,'DSAPConfirmedTask',dsap_task_control('status'));
    navigate(3);set_activity('Preparing','Preparing','ROI 已锁定，正在启动正式分析…',true);
   case 'navigate',navigate(varargin{1});
   case 'settings'
    state=getappdata(f,'WorkspaceState');navigate(2);set_activity('Waiting for input','Settings','请核对采集参数',true);
    varargout={dsap_workspace_settings(f,roiHost,varargin{:},state.RunID)};
    if ~isempty(varargout{1})
     settings=getappdata(f,'DSAPWorkspaceScientificSettings');
     settings.ContrastPolarity='dark';setappdata(f,'DSAPWorkspaceScientificSettings',settings);
    end
    set_activity('Preparing','Preprocessing','正在准备基线与增强序列…',true);
   case 'polarity'
    navigate(2);set_activity('Waiting for input','Polarity','请选择造影增强方向',true);
    varargout={dsap_workspace_polarity(f,roiHost,varargin{:})};
    set_activity('Preparing','Preprocessing','正在准备 DSA 序列…',true);
   case 'roi'
    state=getappdata(f,'WorkspaceState');state.SourceStatus='validated';setappdata(f,'WorkspaceState',state);navigate(2);
    set_activity('Waiting for input','ROI Setup','请确认并锁定 ROI',true);
    [varargout{1:nargout}]=dsap_workspace_roi(f,roiHost,varargin{:});
    state=getappdata(f,'WorkspaceState');state.ROIStatus='frozen';setappdata(f,'WorkspaceState',state);
    set_activity('Preparing','Preparing','ROI 已锁定，正在准备正式分析…',true);
   case 'prepare'
    started=tic;shape=varargin{1};ensure_page(4);dsap_prepare_critical_view(shape,view);
    drawnow;varargout={view,toc(started)}; % Include the graphics flush in preparation, before science.
   case 'stage'
    [stage,message]=normalize_stage(varargin{1});navigate(3);
    kind='Computing';if strcmp(stage,'Rendering Results'),kind='Rendering';end
    set_activity(kind,stage,message,true);
   case 'cave'
    navigate(3);set_activity('Waiting for input','CAVE','请核查血管排除结果：接受、标记异常或取消',true);
    analysisDetails.Visible='off';analysisHost.Visible='on';
    choice=dsap_workspace_cave(f,analysisHost,varargin{:});varargout={choice};
    analysisHost.Visible='off';analysisDetails.Visible='on';
    state=getappdata(f,'WorkspaceState');state.CAVEStatus=choice;setappdata(f,'WorkspaceState',state);
    if ~strcmp(choice,'cancel'),set_activity('Computing','CAVE','CAVE 检查已确认',true);end
   case 'critical'
    ensure_page(4);
    state=getappdata(f,'WorkspaceState');state.AnalysisStatus='complete';state.SaveStatus='pending';
    state.SourceStatus='validated';state.ROIStatus='frozen';
    if ~isempty(varargin)
        r=varargin{1};state.SourceFile=r.source_file;[~,stem,ext]=fileparts(r.source_file);caseLabel.Text=[stem ext];caseLabel.Tooltip=r.source_file;
        parameters=dsap_result_parameter_table(r);tab.ColumnName=result_column_labels(parameters.Properties.VariableNames);
    end
    state.AnalysisStatus='computing';setappdata(f,'WorkspaceState',state);saveButton.Enable='on';saveLabel.Text='未保存';
    navigate(4);set_activity('Rendering','Rendering Results','正在显示 CBF / CBV / Tmax / MTT 与 ROI 参数表…',false);
   case 'critical_visible'
    state=getappdata(f,'WorkspaceState');state.Activity.ResultsReady=true;setappdata(f,'WorkspaceState',state);
    set_activity('Rendering','Auxiliary','关键结果已就绪，正在准备辅助视图…',true);
   case 'auxiliary'
    ensure_page(5);
    r=varargin{1};started=tic;set_activity('Rendering','ROI curves','关键结果已就绪，正在绘制 ROI 曲线…',true);
    dsap_curve_view(r,curveTab,irfTab);drawnow;timing.CurvesVisibleSeconds=toc(started);
    set_activity('Rendering','Vessel QC','关键结果已就绪，正在绘制血管与信号质量检查…',true);
    dsap_vessel_view(r,vesselTab,signalTab);drawnow;timing.VesselQCVisibleSeconds=toc(started);
    set_activity('Rendering','Partition QC','关键结果已就绪，正在绘制分区检查…',true);
    if isfield(r,'partition')
        % A prior Legacy preview has no renderer handles and is replaced once.
        if ~isappdata(partitionTab,'DSAPPartitionView'),delete(partitionTab.Children);end
        dsap_partition_view(r,partitionTab);
    else
        delete(partitionTab.Children);
        if isappdata(partitionTab,'DSAPPartitionView'),rmappdata(partitionTab,'DSAPPartitionView');end
        if isfield(r,'timeslice_import'),dsap_workspace_frozen_roi(partitionTab,r.reference_image,r.aif_mask,r.cranial_limits,struct(),r.timeslice_import);end
        if isfield(r,'manual_tissue'),dsap_workspace_frozen_roi(partitionTab,r.reference_image,r.aif_mask,r.cranial_limits,r.manual_tissue,struct());end
    end
    provenance.Value={['影像来源：' r.source_file];['SHA256：' r.source_identity.SHA256];['锁定 ROI 签名：' r.roi_snapshot.FullSignature];'完整科研溯源：核心 MAT 文件'};
    for field={'StudyInstanceUID','SeriesInstanceUID','SOPInstanceUID'}
        if isfield(r.info,field{1}),provenance.Value=[provenance.Value;{[field{1} ': ' r.info.(field{1})]}];end
    end
    drawnow;timing.AuxiliaryCompleteSeconds=toc(started);varargout={view,timing};
   case 'status'
    ensure_page(6);
    state=getappdata(f,'WorkspaceState');state.SaveStatus=varargin{1};setappdata(f,'WorkspaceState',state);
    switch varargin{1}
     case 'pending',set_activity('Saving','Saving','关键结果已就绪，正在保存核心结果…',false);
     case 'saved',set_activity('Completed','','核心结果已保存',false);
     case 'failed',set_activity('Error','Saving','核心保存失败，可以重试',false);
    end
    folder=getappdata(exportButton,'OutputDirectory');if ~isempty(folder),folderText.Text=['保存路径：' folder];setappdata(f,'OutputDirectory',folder);openButton.Enable=onoff(isfolder(folder));end
    if strcmp(varargin{1},'saved')
     savedFile=dir(fullfile(folder,'interactive_perfusion_results.mat'));
     if ~isempty(savedFile),status.Text=['✓ 核心结果已保存 · ' datestr(savedFile.datenum,'yyyy-mm-dd HH:MM:SS')];status.FontColor=t.Success;end
    elseif strcmp(varargin{1},'failed'),status.FontColor=t.Error;
    else,status.FontColor=t.TextSecondary;end
   case 'activity'
    set_activity(varargin{1},varargin{2},varargin{3},true);
   case 'checkpoint'
    state=getappdata(f,'WorkspaceState');
    if seconds(datetime('now','TimeZone','UTC')-state.Activity.LastUpdateAt)>=.9
     state.Activity=dsap_activity_state('checkpoint',state.Activity);setappdata(f,'WorkspaceState',state);
     if strcmp(state.Activity.Stage,'CAVE')
      state.Activity.WorkerState='MATLAB 等待循环正在响应';setappdata(f,'WorkspaceState',state);
     end
     refresh_activity();
    end
   otherwise,error('DSAP:WorkspaceAction','Unknown Workspace action %s',action);
  end
 end
 function table_selected(~,event)
  setappdata(f,'DSAPCriticalLastInteraction',datetime('now','TimeZone','UTC'));
  if ~isempty(event.Indices),setappdata(f,'DSAPCriticalLastSelectedCell',event.Indices(1,:));end
 end
 function retry_save(~,~)
  if isappdata(f,'DSAPResultOwnerId'),dsap_result_owner('save',getappdata(f,'DSAPResultOwnerId'));end
 end
 function export_full(~,~)
  if busy()||~strcmp(exportButton.Enable,'on'),return;end
  state=getappdata(f,'WorkspaceState');state.Busy=true;state.OperationID=char(java.util.UUID.randomUUID());
  operation=state.OperationID;setappdata(f,'WorkspaceState',state);
  dsap_workspace_bridge('bind',struct('Figure',f,'Dispatch',@dispatch));cleanup=operation_cleanup(@finish_run,operation);
  exportStatus.Text='正在导出';exportButton.Enable='off';set_activity('Exporting','Full Export','正在导出 QC 图像与报告…',true);
  try
   dsap_full_export(getappdata(exportButton,'OutputDirectory'));exportStatus.Text='导出完成';
   state=getappdata(f,'WorkspaceState');state.ExportStatus='complete';setappdata(f,'WorkspaceState',state);
   set_activity('Completed','','完整导出已完成；核心结果未改变',true);
  catch e
   if strcmp(e.identifier,'DSAP:Cancelled'),exportStatus.Text='已取消';set_activity('Cancelled','','完整导出已取消',true);
   else,exportStatus.Text=['导出失败，可重试：' e.message];report_error(e,'Full Export');end
  end
  exportButton.Enable='on';navigate(6);finish_run(operation);
 end
 function close_workspace(~,~)
  if busy(),cancel_run([],[]);return;end
  if reset_case('import'),delete(f);end
 end
 function open_geometry(~,~)
  try
   dsap_workspace_geometry('open',f);
  catch e
   dsap_workspace_log_error(f,e,'Vessel Geometry');
   uialert(f,e.message,'中心线工具未打开');
  end
 end
 function open_distribution(~,~)
  try,dsap_workspace_distribution('open',f);
  catch e,dsap_workspace_log_error(f,e,'ROI Distribution');uialert(f,e.message,'分布分析未打开');end
 end
 function open_inclusive(~,~)
  try,dsap_workspace_inclusive('open',f);
  catch e,dsap_workspace_log_error(f,e,'Vessel comparison');uialert(f,e.message,'灌注对照未打开');end
 end
 function report_error(exception,context,message)
  if nargin<3,message=exception.message;end
  file=dsap_workspace_log_error(f,exception,context);
  setappdata(bottom,'DSAPErrorLog',file);bottom.Tooltip=['详细错误日志：' file];
  set_activity('Error',context,message,true);
 end
 function request_case_change(action)
  if busy()
   setappdata(f,'DSAPPendingCaseAction',action);cancel_run([],[]);return;
  end
  reset_case(action);
 end
 function ok=reset_case(action)
  ok=false;
  release_roi_draft();
  if isappdata(f,'DSAPResultOwnerId')
   id=getappdata(f,'DSAPResultOwnerId');owner=dsap_result_owner('get',id);
   if ~owner.Saved
    choice=uiconfirm(f,'当前结果尚未保存。保存后关闭，或明确放弃本次结果？','关闭当前病例', ...
     'Options',{'保存','放弃','取消'},'DefaultOption',1,'CancelOption',3);
    if strcmp(choice,'取消'),return;end
    if strcmp(choice,'保存')
     [saved,~]=dsap_result_owner('save',id);if ~saved,return;end
     dsap_result_owner('release',id);
    else,dsap_result_owner('discard',id,true);end
   else,dsap_result_owner('release',id);end
   rmappdata(f,'DSAPResultOwnerId');
  end
  dsap_workspace_geometry('close',f);
  dsap_workspace_distribution('close',f);
  dsap_workspace_inclusive('close',f);
  dsap_analysis_session('release');
  for j=2:6,if isgraphics(pages(j)),delete(pages(j));end,end
  pages(2:6)=gobjects(1,5);stageItems=gobjects(1,numel(stageNames));
  stageLabel=[];cardState=[];cardStage=[];cardDescription=[];cardElapsed=[];
  detailStage=[];detailElapsed=[];detailLast=[];detailWorker=[];analysisHost=[];analysisDetails=[];
  roiHost=[];curveTab=[];irfTab=[];vesselTab=[];signalTab=[];partitionTab=[];provenance=[];
  tab=[];status=[];folderText=[];openButton=[];exportButton=[];exportStatus=[];retry=[];
  for key={'DSAPWorkspaceROIDraft','DSAPWorkspaceSettings','DSAPWorkspaceScientificSettings','DSAPWorkspaceCAVE', ...
    'DSAPFrozenSnapshot','DSAPConfirmedTask','DSAPCriticalView','DSAPResultControls','DSAPWorkspaceChangeSourceButton', ...
    'DSAPWorkspaceCancelButton','DSAPAnalyzeControls','DSAPWorkspaceQCTabs','OutputDirectory','DSAPWorkspaceLastError','DSAPWorkspaceLastErrorLog'}
   if isappdata(f,key{1}),rmappdata(f,key{1});end
  end
  view=struct('Perfusion',f,'Table',f,'Workspace',true);setappdata(f,'DSAPWorkspaceView',view);
  state=struct('CurrentPage',1,'RunID','','SourceStatus','empty','ROIStatus','empty', ...
   'AnalysisStatus','idle','SaveStatus','empty','ExportStatus','not_exported','CAVEStatus','pending', ...
   'ViewHandles',view,'Busy',false,'SourceFile','','Legacy',false,'OperationID','', ...
   'Activity',dsap_activity_state('new'));
  setappdata(f,'WorkspaceState',state);setappdata(f,'DSAPCriticalReady',false);
  pageTimes=getappdata(f,'DSAPPageCreateSeconds');setappdata(f,'DSAPPageCreateSeconds',[pageTimes(1) zeros(1,5)]);
  sourceText.Text='尚未选择影像';metaText.Text='请选择要分析的 DSA 序列';caseLabel.Text='请选择 DICOM 影像';
  startButton.Text='继续：ROI 设置';startButton.Enable='off';saveButton.Enable='off';saveLabel.Text='未保存';
  f.CloseRequestFcn=@close_workspace;sequenceHost.Visible='off';ig.Visible='on';navigate(1);
  if strcmp(action,'change')&&~isempty(folderCandidates),show_sequences();
  else,set_activity('Ready','','请选择 DICOM 影像',true);end
  ok=true;
 end
 function set_activity(kind,stage,message,flush)
  if ~isgraphics(f),return;end
  state=getappdata(f,'WorkspaceState');state.Activity=dsap_activity_state('set',state.Activity,kind,stage,char(message));
  if state.Busy && ~state.Activity.ResultsReady && ismember(kind,{'Preparing','Computing','Rendering','Waiting for input'})
   state.AnalysisStatus='computing';
   if strcmp(stage,'Preparing')||strcmp(kind,'Waiting for input'),state.AnalysisStatus='preparing';end
  elseif state.Activity.ResultsReady && ismember(kind,{'Rendering','Saving'})
   state.AnalysisStatus='results_ready';
  elseif strcmp(kind,'Completed') && strcmp(state.SaveStatus,'saved')
   state.AnalysisStatus='complete';
  elseif strcmp(kind,'Cancelled') && ~state.Activity.ResultsReady
   state.AnalysisStatus='cancelled';
  elseif strcmp(kind,'Error') && ~state.Activity.ResultsReady && state.Busy
   state.AnalysisStatus='error';
  end
  setappdata(f,'WorkspaceState',state);refresh_activity();update_stages(state.Activity);
  if flush,drawnow;end
 end
 function refresh_activity()
  if ~isgraphics(f)||~isappdata(f,'WorkspaceState'),return;end
  dsap_workspace_geometry('refresh',f);
  dsap_workspace_distribution('refresh',f);
  dsap_workspace_inclusive('refresh',f);
  state=getappdata(f,'WorkspaceState');a=state.Activity;
  nowUTC=datetime('now','TimeZone','UTC');elapsed=max(0,floor(seconds(nowUTC-a.StartedAt)));
  clockText=sprintf('%02d:%02d',floor(elapsed/60),mod(elapsed,60));
  running=ismember(a.State,{'Preparing','Computing','Rendering','Saving','Exporting','Cancelling'});
  prefix=activity_name(a.State);if a.ResultsReady&&ismember(a.State,{'Rendering','Saving'}),prefix='结果已就绪';end
  stageText=stage_name(a.Stage);message=activity_description(a);
  if running,bottom.Text=sprintf('%s · %s · 已运行 %s',prefix,message,clockText);
  else,bottom.Text=sprintf('%s · %s',prefix,message);end
  if strcmp(a.Stage,'CAVE')&&~isempty(a.WorkerState)
   bottom.Text=[bottom.Text ' · ' a.WorkerState];
  end
  warningAfter=60;
  if strcmp(a.Stage,'CAVE'),warningAfter=180;end
  if running&&elapsed>warningAfter
   quiet=floor(seconds(nowUTC-a.LastUpdateAt));
   if quiet>5
    if strcmp(a.Stage,'CAVE'),bottom.Text=sprintf('%s · 提示：仍在等待 CAVE 进程；上次 MATLAB 检查点距今 %d 秒',bottom.Text,quiet);
    else,bottom.Text=sprintf('%s · 提示：此步骤比平时耗时更长；上次检查点距今 %d 秒',bottom.Text,quiet);end
   else,bottom.Text=[bottom.Text ' · 提示：此步骤比平时耗时更长'];end
  end
  activityShort.Text=analysis_name(state.AnalysisStatus);
  if strcmp(state.AnalysisStatus,'computing')||strcmp(state.AnalysisStatus,'preparing')
   activityShort.Text=[activityShort.Text ' · ' stageText];
  elseif strcmp(a.State,'Exporting'),activityShort.Text='正在导出';end
  saveLabel.Text=save_name(state.SaveStatus);
  bottom.FontColor=t.TextSecondary;
  if strcmp(a.State,'Error'),bottom.FontColor=t.Error;elseif strcmp(a.State,'Warning'),bottom.FontColor=t.Warning;end
  if isgraphics(cardState)
   cardState.Text=prefix;cardStage.Text=stageText;cardDescription.Text=message;
   cardElapsed.Text=['已运行 ' clockText];detailStage.Text=stageText;detailElapsed.Text=clockText;
   quiet=max(0,floor(seconds(nowUTC-a.LastUpdateAt)));
   if quiet<2,detailLast.Text='刚刚';else,detailLast.Text=sprintf('%d 秒前',quiet);end
   if ~isempty(a.WorkerState),detailWorker.Text=a.WorkerState;
   elseif strcmp(a.State,'Waiting for input'),detailWorker.Text='等待用户操作';
   elseif running,detailWorker.Text='同步操作期间，以最后检查点为准';
   else,detailWorker.Text='—';end
  end
 end
 function update_stages(a)
  if ~isgraphics(pages(3)),return;end
  idx=find(strcmp(stageNames,a.Stage),1);
  state=getappdata(f,'WorkspaceState');finished=strcmp(state.AnalysisStatus,'complete');
  if isempty(idx)&&~finished,return;end
  for j=1:numel(stageNames)
   if finished||j<idx,marker='✓';color=t.TextSecondary;background=t.Surface;weight='normal';
   elseif j==idx,marker='●';color=t.Primary;background=t.Selected;weight='bold';
   else,marker='○';color=t.TextSecondary;background=t.Surface;weight='normal';end
   stageItems(j).Text=[marker '  ' stage_name(stageNames{j})];stageItems(j).FontColor=color;
   stageItems(j).BackgroundColor=background;stageItems(j).FontWeight=weight;
  end
 end
 function [stage,message]=normalize_stage(raw)
  message=char(raw);stage=message;
  if contains(message,'TSVD')||contains(message,'反卷积'),stage='Deconvolution';
  elseif contains(message,'CAVE'),stage='CAVE';
  elseif ~any(strcmp(stageNames,message)),stage='Preparing';end
 end
 function cleanup_activity_timer(~,~)
  dsap_workspace_distribution('close',f);
  dsap_workspace_geometry('close',f);
  dsap_workspace_inclusive('close',f);
  release_roi_draft();
  if ~isappdata(f,'DSAPActivityTimer'),return;end
  task=getappdata(f,'DSAPActivityTimer');
  if isvalid(task),stop(task);delete(task);end
 end
 function release_roi_draft
  if ~isgraphics(f)||~isappdata(f,'DSAPWorkspaceROIDraft'),return;end
  draft=getappdata(f,'DSAPWorkspaceROIDraft');
  if isfield(draft,'Dispose'),draft.Dispose();end
 end
 function workspace_key(~,event)
  if strcmp(event.Key,'escape')&&isappdata(f,'DSAPWorkspaceROIDraft')
   draft=getappdata(f,'DSAPWorkspaceROIDraft');
   if isfield(draft,'CancelInteraction'),draft.CancelInteraction();return;end
  end
  focused=f.CurrentObject;
  if isa(focused,'matlab.ui.control.EditField')||isa(focused,'matlab.ui.control.NumericEditField')||isa(focused,'matlab.ui.control.TextArea'),return;end
  if strcmp(event.Key,'s')&&ismember('control',event.Modifier)&&~busy()&&isappdata(f,'DSAPResultOwnerId')
   dsap_result_owner('save',getappdata(f,'DSAPResultOwnerId'));
  end
 end
end
function message=legacy_issue_message(exception,entries)
message=exception.message;
if ~strcmp(exception.identifier,'DSAP:LegacyMaskInvalid')||~contains(message,'fewer than 3 pixels'),return;end
try
 [roles,~]=dsap_timeslice_semantics(entries);problems={};
 for k=find([roles.Adopted])
  count=nnz(niftiread(entries(k).maskFile));
  if count>=3,continue;end
  role='蓝青色主要组织 ROI';if strcmp(roles(k).Role,'AIF'),role='baseline 标记的 AIF';end
  problems{end+1}=sprintf('%s（Step %s）只有 %d 个有效像素',role,entries(k).stepId,count); %#ok<AGROW>
 end
 if ~isempty(problems),message=[strjoin(problems,'；') '。请在 TIMESlice 完成并保存该 ROI 后重新导入。'];end
catch
 % Diagnostic failure must not replace or hide the original exception.
end
end
function guard=operation_cleanup(callback,id)
% Capture an immutable invocation ID outside the retained nested Workspace.
guard=onCleanup(@() callback(id));
end
function text=onoff(flag)
text='off';if flag,text='on';end
end
function close_startup_splash(fig)
if isgraphics(fig),delete(fig);end
end
function value=analysis_name(state)
switch state
 case 'idle',value='未开始';
 case 'preparing',value='准备中';
 case 'computing',value='分析中';
 case 'results_ready',value='结果已就绪';
 case 'complete',value='完成';
 case 'cancelled',value='已取消';
 case 'error',value='错误';
 otherwise,value='—';
end
end
function labels=result_column_labels(names)
% Display labels only. Core table names and all table.Data values are preserved.
keys={'ROIType','MergedFrom','SelectedFrame','AreaPixels','Tmax_s','MTT_s', ...
 'Peak','TTP_s','Intensity','ROIIRF_CBF','ROIIRF_CBV','ROIIRF_Tmax_s','ROIIRF_MTT_s', ...
 'GeometryPixels','ExcludedVesselPixels','ExcludedAIFPixels','NonfiniteInputPixels', ...
 'TICPixels','PerfusionValidPixels','InvalidPerfusionPixels','PerfusionCoveragePercent'};
values={'类型','合并来源','选定帧','像素数','Tmax (s)','MTT (s)', ...
 '峰值','TTP (s)','信号强度','ROI IRF CBF','ROI IRF CBV','ROI IRF Tmax (s)','ROI IRF MTT (s)', ...
 '几何像素','排除血管像素','排除 AIF 像素','非有限输入像素', ...
 'TIC 像素','灌注有效像素','灌注无效像素','灌注覆盖率 (%)'};
labels=names;
for k=1:numel(names),index=find(strcmp(keys,names{k}),1);if ~isempty(index),labels{k}=values{index};end,end
end
function value=save_name(state)
switch state
 case 'pending',value='保存中';
 case 'saved',value='已保存';
 case 'failed',value='保存失败';
 otherwise,value='未保存';
end
end
function value=activity_name(state)
switch state
 case 'Ready',value='就绪';
 case 'Waiting for input',value='等待操作';
 case 'Preparing',value='准备中';
 case 'Computing',value='计算中';
 case 'Rendering',value='生成结果';
 case 'Saving',value='保存中';
 case 'Exporting',value='导出中';
 case 'Completed',value='已完成';
 case 'Cancelling',value='正在取消';
 case 'Cancelled',value='已取消';
 case 'Warning',value='提示';
 case 'Error',value='错误';
 otherwise,value='—';
end
end
function value=stage_name(stage)
switch stage
 case 'Preparing',value='准备';
 case 'AIF / Timing',value='AIF / 时间轴';
 case 'Signal Quality',value='信号质量';
 case 'CAVE',value='CAVE';
 case 'Deconvolution',value='TSVD 去卷积';
 case 'Post-processing',value='后处理';
 case 'ROI Statistics',value='ROI 统计';
 case 'Rendering Results',value='生成结果';
 case 'Saving',value='保存';
 case 'ROI Setup',value='ROI 设置';
 case 'Source scan',value='扫描影像';
 case 'Source validation',value='核对影像来源';
 case 'Full Export',value='完整导出';
 case 'Auxiliary',value='辅助视图';
 case 'ROI curves',value='ROI 曲线';
 case 'Vessel QC',value='血管 / 信号检查';
 case 'Partition QC',value='分区检查';
 case 'Settings',value='采集参数';
 case 'Polarity',value='增强方向';
 case 'Preprocessing',value='预处理';
 case 'Legacy import',value='历史数据导入';
 otherwise,value='等待开始';
end
end
function value=activity_description(a)
if ismember(a.State,{'Ready','Waiting for input','Cancelled','Cancelling','Warning','Error','Completed','Exporting'})
 value=a.Message;return;
end
switch a.Stage
 case 'Preparing',value='正在读取并准备影像序列';
 case 'AIF / Timing',value='正在处理 AIF 与采集时间轴';
 case 'Signal Quality',value='正在判定信号质量';
 case 'CAVE',value='正在进行 CAVE 血管识别与检查';
 case 'Deconvolution',value='正在根据 AIF 对时间序列进行 TSVD 去卷积计算';
 case 'Post-processing',value='正在后处理灌注参数图';
 case 'ROI Statistics',value='正在计算 ROI 曲线与参数统计';
 case 'Rendering Results',value='正在显示四张灌注图与 ROI 参数表';
 case 'Saving',value='正在保存核心科研结果';
 otherwise,value=a.Message;
end
end
