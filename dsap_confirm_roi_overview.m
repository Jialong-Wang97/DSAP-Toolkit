function [confirmed,action]=dsap_confirm_roi_overview(reference,aif,limits,definition,imported)
% Final read-only overview. Editing remains in Draft, never on a frozen result.
    confirmed=false;action='cancel';finished=false;
    fig=figure('Name','ROI Draft 总览 · 确认后锁定','NumberTitle','off','Color','w', ...
        'Position',[120 70 1000 820],'CloseRequestFcn',@cancel);
    cleanup=onCleanup(@() dsap_safe_delete(fig)); %#ok<NASGU>
    ax=axes(fig,'Position',[.05 .17 .90 .78]);imshow(reference,[],'Parent',ax);hold(ax,'on');
    visboundaries(ax,aif,'Color',[1 .3 0],'LineWidth',1.5);
    if imported
        masks=definition.Masks;
        note='TIMESlice ROI 只读；如有错误，请取消并回 TIMESlice 修改后重新导入。';
    else
        masks={definition.OuterMask,definition.SubcortexMask};
        note='橙色 AIF；组织边界及颅骨上下限如下。确认后正式锁定。';
    end
    colors=lines(numel(masks));
    for k=1:numel(masks),visboundaries(ax,masks{k},'Color',colors(k,:),'LineWidth',1.2);end
    yline(ax,limits.UpperRow,'c-','LineWidth',1.5);yline(ax,limits.LowerRow,'y-','LineWidth',1.5);
    title(ax,note,'Interpreter','none');
    uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.20 .055 .40 .065], ...
        'String','确认并开始分析（锁定 ROI）','Callback',@accept);
    uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.65 .055 .18 .065], ...
        'String','取消','Callback',@cancel);
    if ~imported
        uicontrol(fig,'Style','pushbutton','Units','normalized','Position',[.02 .055 .16 .065], ...
            'String','返回 Draft','Callback',@back);
    end
    drawnow;if isgraphics(fig)&&~finished,uiwait(fig);end
    % Nested callback closures can retain the cleanup object and figure.
    % Close deterministically before returning the frozen decision.
    dsap_safe_delete(fig);
    function accept(~,~),confirmed=true;action='confirm';finished=true;uiresume(fig);end
    function back(~,~),confirmed=false;action='draft';finished=true;uiresume(fig);end
    function cancel(~,~),confirmed=false;finished=true;uiresume(fig);end
end
