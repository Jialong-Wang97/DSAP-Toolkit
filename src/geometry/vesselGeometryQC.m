function fig=vesselGeometryQC(geometry,reference,opts)
% QC in original image pixel coordinates; derivatives retain calibrated units.
if nargin<2,reference=[];end
if nargin<3,opts=struct();end
opts=vesselGeometryOptions(opts,isfield(geometry,'Units')&&strcmp(geometry.Units,'mm'));
assert(geometry.Valid,'DSAP:GeometryQC','Cannot display invalid geometry.');
fig=figure('Name',['DSAP Vascular Geometry | ' geometry.SegmentName],'NumberTitle','off', ...
 'Color','w','Position',[50 80 1280 730],'Visible',opts.FigureVisible);
ax=axes(fig,'Position',[.06 .27 .48 .66]);hold(ax,'on');
if ~isempty(reference)
 assert(isnumeric(reference)&&ismatrix(reference),'DSAP:GeometryQC','Reference must be a 2D image.');
 imagesc(ax,reference);colormap(ax,gray(256));set(ax,'YDir','reverse');
else
 set(ax,'YDir','reverse');
end
axis(ax,'image');xlabel(ax,'Column x (px)');ylabel(ax,'Row y (px)');title(ax,'Selected vessel: projected 2D geometry');
p=geometry.centerlineSmoothed;raw=plot(ax,geometry.centerlineRaw(:,1),geometry.centerlineRaw(:,2),'c--','LineWidth',1,'Visible','off');
resampled=plot(ax,geometry.centerlineResampled(:,1),geometry.centerlineResampled(:,2),'--','Color',[.7 .7 .7],'Visible','off');
smooth=plot(ax,p(:,1),p(:,2),'-','Color',[.2 .7 .9],'LineWidth',1.5);
colored=[];
if ~isempty(geometry.CurvatureProfile)
 % True color leaves the DSA grayscale colormap untouched.
 values=geometry.CurvatureProfile;normalized=values/max(max(values),eps);colors=turbo(256);rgb=colors(1+round(normalized*255),:);
 colored=scatter(ax,p(:,1),p(:,2),16,rgb,'filled');
end
start=scatter(ax,p(1,1),p(1,2),100,[.1 .9 .2],'filled','MarkerEdgeColor','k');
finish=scatter(ax,p(end,1),p(end,2),100,[1 .2 .2],'filled','MarkerEdgeColor','k');
text(ax,p(1,1),p(1,2),'  Proximal','Color',[.1 .7 .1],'FontWeight','bold');text(ax,p(end,1),p(end,2),'  Distal','Color',[1 .2 .2],'FontWeight','bold');
maximum=[];inflections=[];
if ~isempty(geometry.MaxCurvaturePoint)
 maximum=plot(ax,geometry.MaxCurvaturePoint(1),geometry.MaxCurvaturePoint(2),'p','MarkerSize',17,'MarkerFaceColor',[1 .8 .1],'MarkerEdgeColor','k');
end
if ~isempty(geometry.InflectionPoints),inflections=plot(ax,geometry.InflectionPoints(:,1),geometry.InflectionPoints(:,2),'md','MarkerSize',9,'LineWidth',1.5);end
curveAx=axes(fig,'Position',[.63 .43 .32 .5]);plot(curveAx,geometry.ArcLengthPosition,geometry.CurvatureProfile,'Color',[.1 .35 .7],'LineWidth',1.6);grid(curveAx,'on');
xlabel(curveAx,['Arc length (' geometry.Units ')']);ylabel(curveAx,['Curvature (' geometry.CurvatureUnits ')']);title(curveAx,'Curvature along selected segment');
if isfield(geometry,'MaxCurvaturePosition'),xline(curveAx,geometry.MaxCurvaturePosition,':','Maximum','Color',[.8 .5 0]);end
if ~isempty(geometry.InflectionIndices)
 for k=geometry.InflectionIndices(:)',xline(curveAx,geometry.ArcLengthPosition(k),':','Color',[.8 .1 .8]);end
end
lengthValue=geometry.Length_px;chord=geometry.ChordLength_px;if strcmp(geometry.Units,'mm'),lengthValue=geometry.Length_mm;chord=geometry.ChordLength_mm;end
summary=sprintf('%s | Length %.4g %s | Chord %.4g %s | L/D %.4f | 1-D/L %.4f\nMean curvature %.4g | Max %.4g | RMS %.4g %s | Inflections %g | VTI %.4g', ...
 geometry.SegmentName,lengthValue,geometry.Units,chord,geometry.Units,geometry.DistanceMetric,geometry.ESCAPE_Tortuosity, ...
 geometry.MeanCurvature,geometry.MaxCurvature,geometry.RMSCurvature,geometry.CurvatureUnits,geometry.InflectionCount,geometry.VTI);
annotation(fig,'textbox',[.05 .14 .9 .09],'String',summary,'EdgeColor','none','HorizontalAlignment','left','FontSize',11,'Interpreter','none');
annotation(fig,'textbox',[.05 .01 .9 .065],'String',geometry.Warning,'EdgeColor','none','Color',[.6 .25 .1],'HorizontalAlignment','left','Interpreter','none');
rawToggle=uicontrol(fig,'Style','checkbox','Units','normalized','Position',[.06 .24 .25 .035],'String','Show raw and resampled centerline','Value',0,'BackgroundColor','w','Callback',@toggle_raw);
exportButton=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.69 .27 .25 .06],'String','Export separate geometry CSV / MAT / QC','Callback',@export);
setappdata(fig,'DSAPGeometryQC',struct('Geometry',geometry,'ImageAxes',ax,'CurveAxes',curveAx,'Raw',raw,'Resampled',resampled, ...
 'Smooth',smooth,'ColorPoints',colored,'Start',start,'End',finish,'Maximum',maximum,'Inflections',inflections,'RawToggle',rawToggle,'Export',exportButton));
 function toggle_raw(source,~)
  visibility='off';if source.Value,visibility='on';end
  set([raw resampled],'Visible',visibility);
 end
 function export(~,~)
  folder=uigetdir(pwd,'Export independent vessel geometry');if isequal(folder,0),return;end
  exportVesselGeometry(folder,geometry,fig);
 end
end
