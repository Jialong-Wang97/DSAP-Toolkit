function [view,seconds]=dsap_prepare_critical_view(shape,view)
% Prepare graphics before science; preparation time is reported separately.
    started=tic;if nargin<2,view=struct();end
    if isfield(view,'Workspace')&&isfield(view,'Perfusion')&&isgraphics(view.Perfusion) ...
            &&~isappdata(view.Perfusion,'DSAPCriticalView')
        dispatch=getappdata(view.Perfusion,'DSAPWorkspaceDispatch');
        if ~isempty(dispatch),[view,seconds]=dispatch('prepare',shape);return;end
    end
    if isfield(view,'Perfusion')&&isgraphics(view.Perfusion)&&isappdata(view.Perfusion,'DSAPCriticalView')
        h=getappdata(view.Perfusion,'DSAPCriticalView');
        if ~isequal(h.Shape,shape)
            for k=1:4
                h.Backgrounds(k).CData=repmat(single(.65),[shape 3]);
                set([h.Backgrounds(k),h.Images(k)],'XData',[1 shape(2)],'YData',[1 shape(1)]);
                h.Axes(k).XLim=[.5 shape(2)+.5];h.Axes(k).YLim=[.5 shape(1)+.5];
            end
            h.Shape=shape;setappdata(view.Perfusion,'DSAPCriticalView',h);
        end
        seconds=toc(started);return;
    end
    fig=figure('Name','DSAP · 灌注参数与 ROI 参数表','NumberTitle','off','Color','w', ...
        'Position',[40 40 1320 900],'Visible','off','WindowStyle','normal');
    panel=uipanel(fig,'Position',[0 .29 1 .71],'BorderType','none');
    layout=tiledlayout(panel,2,3,'Padding','compact','TileSpacing','compact');
    names={'CBF（相对值）','CBV（相对值）','Tmax (s)','MTT (s)'};
    h.Axes=gobjects(4,1);h.Images=gobjects(4,1);h.Colorbars=gobjects(4,1);h.Backgrounds=gobjects(4,1);h.Shape=shape;
    perfusionTiles=[1 2 4 5];
    for k=1:4
        ax=nexttile(layout,perfusionTiles(k));h.Axes(k)=ax;
        h.Backgrounds(k)=image(ax,repmat(single(.65),[shape 3]));hold(ax,'on');
        h.Images(k)=imagesc(ax,nan(shape));h.Images(k).AlphaData=0;
        axis(ax,'image','off');ax.YDir='reverse';colormap(ax,turbo);
        h.Colorbars(k)=colorbar(ax);title(ax,[names{k} '；灰色不参与统计']);
        ax.Toolbar.Visible='off';
    end
    h.CAVE=dsap_prepare_cave_result_view(layout,[3 6]);
    controls.Table=uitable(fig,'ColumnWidth','auto','RowName',[],'Units','normalized', ...
        'Position',[.01 .075 .98 .21],'CellSelectionCallback',@selected);
    controls.Status=uicontrol(fig,'Style','text','Units','normalized','Position',[.01 .01 .54 .05], ...
        'HorizontalAlignment','left','BackgroundColor','w','String','等待科学计算完成');
    controls.Export=uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.77 .018 .21 .04], ...
        'String','完整导出图像 / 报告','Enable','off','Callback',@dsap_full_export_callback);
    setappdata(fig,'DSAPCriticalView',h);setappdata(fig,'DSAPResultControls',controls);
    view.Perfusion=fig;view.Table=fig;drawnow;seconds=toc(started);
end
function selected(table,event)
    fig=ancestor(table,'figure');h=getappdata(fig,'DSAPResultControls');
    setappdata(fig,'DSAPCriticalLastInteraction',datetime('now','TimeZone','UTC'));
    if ~isempty(event.Indices)
        h.Status.String=sprintf('已选择 ROI 参数表第 %d 行、第 %d 列。',event.Indices(1,1),event.Indices(1,2));
    end
end
