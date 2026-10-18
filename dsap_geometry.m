function fig=dsap_geometry(source,centerline,pixelSpacing,opts)
% Optional geometry tool, also launched from Workspace. Perfusion state is untouched.
% source: 2D image, result struct, or saved Core folder. Centerline is Nx2 [x y].
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'src','geometry'));
if nargin<1,source=[];end
if nargin<2,centerline=[];end
if nargin<3,pixelSpacing=[];end
if nargin<4,opts=struct();end
reference=[];mask=[];
if ischar(source)||isstring(source)
 filename=char(source);if isfolder(filename),filename=fullfile(filename,'interactive_perfusion_results.mat');end
 fields=whos('-file',filename);names=intersect({fields.name},{'reference_image','large_vessel_mask','cave_full_field','vessel_features','info'});
 source=load(filename,names{:});
end
if isstruct(source)
 if isfield(source,'reference_image'),reference=source.reference_image;end
 % Use calibrated PixelSpacing only; do not silently substitute detector spacing.
 if isempty(pixelSpacing)&&isfield(source,'info')&&isfield(source.info,'PixelSpacing'),pixelSpacing=source.info.PixelSpacing;end
else
 reference=source;
end
opts=vesselGeometryOptions(opts,~isempty(pixelSpacing));opts.ShowQC=false;
if ~isempty(centerline)
 geometry=computeVesselGeometry(centerline,pixelSpacing,opts);assert(geometry.Valid,'DSAP:GeometryInvalid','%s',geometry.Warning);
 fig=vesselGeometryQC(geometry,reference,opts);return;
end
shape=[];if ~isempty(reference),shape=size(reference);end
sources=geometryVesselSources(source,shape);sourceIndex=1;
if ~isempty(sources)
 if ~strcmp(opts.VesselMaskSource,'auto')
  sourceIndex=find(strcmp({sources.ID},opts.VesselMaskSource),1);
  assert(~isempty(sourceIndex),'DSAP:GeometryMaskSource','Requested vessel extraction source is not available in this result.');
 end
 mask=sources(sourceIndex).Mask;
 if isempty(reference),reference=zeros(size(mask));end
end
fig=figure('Name','DSAP 血管几何 · 已有大血管结果','NumberTitle','off','Color','w','Position',[60 50 1120 830],'Visible',opts.FigureVisible);
ax=axes(fig,'Position',[.07 .30 .86 .62]);hold(ax,'on');
if ~isempty(reference),imagesc(ax,reference);colormap(ax,gray);end
axis(ax,'image');set(ax,'YDir','reverse');title(ax,'沿目标血管从近端到远端选点；青色叠加为当前已有提取结果');
maskOverlay=[];lastPath=[];lastGeometry=[];lastQC=[];pathLine=[];
fig.DeleteFcn=@dispose;
if ~isempty(reference)
 rgb=repmat(reshape([0 .85 .9],1,1,3),[size(reference) 1]);maskOverlay=image(ax,rgb,'AlphaData',zeros(size(reference)),'HitTest','off','PickableParts','none');
end
uicontrol(fig,'Style','text','Units','normalized','Position',[.04 .23 .14 .04],'String','血管提取来源','BackgroundColor','w','HorizontalAlignment','left');
labels={'未找到已保存掩膜'};if ~isempty(sources),labels={sources.Label};end
maskSelect=uicontrol(fig,'Style','popupmenu','Units','normalized','Position',[.18 .23 .56 .045], ...
 'String',labels,'Value',sourceIndex,'Enable',onoff(~isempty(sources)),'Callback',@change_source);
maskVisible=uicontrol(fig,'Style','checkbox','Units','normalized','Position',[.77 .23 .20 .045],'String','显示血管掩膜','Value',1,'BackgroundColor','w','Callback',@(~,~) render_mask());
endpoints=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.04 .15 .22 .055],'String','选两个端点 · 自动中心线','Enable',onoff(~isempty(mask)),'Callback',@pick);
guide=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.28 .15 .23 .055],'String','加引导点 · 指定目标分支','Enable',onoff(~isempty(mask)),'Callback',@pick_guides);
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.53 .15 .20 .055],'String','手绘中心线','Callback',@draw);
uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.75 .15 .21 .055],'String','载入中心线 CSV','Callback',@import_curve);
exportButton=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.04 .095 .22 .045], ...
 'String','导出中心线 / 几何','Enable','off','Callback',@export_geometry);
status=uicontrol(fig,'Style','text','Units','normalized','Position',[.04 .015 .92 .075], ...
 'String','先核对掩膜，再选择近端和远端。路径走错分支时，按顺序补充引导点。全幅 CAVE 是原始模型输出，可切换到已确认的大血管。', ...
 'BackgroundColor','w','HorizontalAlignment','left');
render_mask();publish();
 function publish
  id='';if ~isempty(sources),id=sources(sourceIndex).ID;end
  setappdata(fig,'DSAPGeometryPrototype',struct('Axes',ax,'Compute',@calculate,'Extract',@extract,'PickEndpoints',endpoints,'PickGuides',guide, ...
   'Status',status,'MaskSelect',maskSelect,'MaskVisible',maskVisible,'MaskOverlay',maskOverlay,'MaskSources',{sources}, ...
   'SelectedMaskID',id,'LastPath',lastPath,'LastGeometry',lastGeometry,'LastQC',lastQC,'Export',exportButton));
 end
 function render_mask
  if ~isempty(maskOverlay)&&isgraphics(maskOverlay)
   if isempty(mask),maskOverlay.AlphaData=zeros(size(reference));else,maskOverlay.AlphaData=.20*double(mask)*maskVisible.Value;end
  end
 end
 function change_source(~,~)
  sourceIndex=maskSelect.Value;mask=sources(sourceIndex).Mask;
  if ~isempty(pathLine)&&isgraphics(pathLine),delete(pathLine);end
  if ~isempty(lastQC)&&isgraphics(lastQC),close(lastQC);end
  lastPath=[];lastGeometry=[];lastQC=[];exportButton.Enable='off';render_mask();publish();
  status.String='血管来源已切换，请重新选择端点或引导点。';
 end
 function calculate(points,varargin)
  geometry=computeVesselGeometry(points,pixelSpacing,opts);
  if ~geometry.Valid,status.String=geometry.Warning;return;end
  if ~isempty(varargin)
   geometry.PathQC=varargin{1};
   smoothed=geometry.centerlineSmoothed;
   inside=interp2(double(mask),smoothed(:,1),smoothed(:,2),'nearest',0)>.5;
   geometry.PathQC.SmoothedInsideFraction=mean(inside);
   if ~all(inside),geometry.PathQC.Warning=strtrim([geometry.PathQC.Warning newline '部分平滑中心线超出当前血管掩膜，请检查路径或减小平滑范围。']);end
   if ~isempty(geometry.PathQC.Warning)
    geometry.Warning=strtrim([geometry.Warning newline geometry.PathQC.Warning]);
   end
  end
  if ~isempty(pathLine)&&isgraphics(pathLine),delete(pathLine);end
  pathLine=plot(ax,geometry.centerlineSmoothed(:,1),geometry.centerlineSmoothed(:,2),'y-','LineWidth',2);
  if ~isempty(lastQC)&&isgraphics(lastQC),close(lastQC);end
  lastPath=points;lastGeometry=geometry;lastQC=vesselGeometryQC(geometry,reference,opts);exportButton.Enable='on';publish();
  status.String='已生成中心线和几何 QC。请检查黄色路径，走错分支时使用引导点重选。';
  if ~isempty(geometry.Warning),status.String=geometry.Warning;end
 end
 function draw(~,~)
  try
   line=drawpolyline(ax,'Color',[0 .8 1]);points=line.Position;delete(line);calculate(points);
  catch e
   if isgraphics(status),status.String=e.message;end
  end
 end
 function extract(first,last,varargin)
  waypoints=zeros(0,2);if ~isempty(varargin),waypoints=varargin{1};end
  [points,quality]=extractOrderedVesselPath(mask,first,last,pixelSpacing,opts,waypoints);
  quality.VesselSource=rmfield(sources(sourceIndex),'Mask');calculate(points,quality);
 end
 function pick(~,~)
  first=[];last=[];
  try
   status.String='点击目标血管的近端。';first=drawpoint(ax,'Color','g');status.String='点击目标血管的远端。';last=drawpoint(ax,'Color','r');
   extract(first.Position,last.Position);
  catch e
   if isgraphics(status),status.String=e.message;end
  end
  if ~isempty(first)&&isvalid(first),delete(first);end
  if ~isempty(last)&&isvalid(last),delete(last);end
 end
 function pick_guides(~,~)
  line=[];
  try
   status.String='从近端到远端沿目标血管单击引导点；在末端双击完成。点间路径会自动贴合当前血管掩膜。';
   line=drawpolyline(ax,'Color',[1 .7 0]);points=line.Position;
   assert(size(points,1)>=2,'DSAP:GeometryEndpoints','至少选择两个点。');
   extract(points(1,:),points(end,:),points(2:end-1,:));
  catch e
   if isgraphics(status),status.String=e.message;end
  end
  if ~isempty(line)&&isvalid(line),delete(line);end
 end
 function import_curve(~,~)
  [name,folder]=uigetfile('*.csv','Ordered Nx2 [x y] centerline');if isequal(name,0),return;end
  try
   calculate(readmatrix(fullfile(folder,name)));
  catch e
   status.String=e.message;
  end
 end
 function export_geometry(~,~)
  if isempty(lastGeometry),return;end
  folder=uigetdir(pwd,'选择几何结果导出位置');if isequal(folder,0),return;end
  try
   % A unique sidecar directory avoids replacing prior exports or Core files.
   destination=tempname(folder);mkdir(destination);
   exportVesselGeometry(destination,lastGeometry,lastQC);
   writematrix(lastPath,fullfile(destination,'centerline_xy.csv'));
   status.String=['已导出中心线、几何指标和 QC：' destination];
  catch e
   status.String=['几何导出失败：' e.message];
  end
 end
 function dispose(~,~)
  if ~isempty(lastQC)&&isgraphics(lastQC),delete(lastQC);end
 end
end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
