function dsap_finish_cine_preview(preview_figure, action, browser_figure)
%DSAP_FINISH_CINE_PREVIEW Close a cine preview without nested UI waits.

    if ~isempty(preview_figure) && isgraphics(preview_figure)
        setappdata(preview_figure, 'PreviewPlaying', false);
        setappdata(preview_figure, 'PreviewAction', action);
        preview_figure.CloseRequestFcn = '';
        delete(preview_figure);
    end
    if isempty(browser_figure) || ~isgraphics(browser_figure)
        return;
    end
    setappdata(browser_figure, 'PreviewFigure', gobjects(0));
    if strcmp(action, 'use')
        setappdata(browser_figure, 'BrowserAction', 'use');
        uiresume(browser_figure);
    else
        browser_figure.Visible = 'on';
        figure(browser_figure);
        drawnow;
    end
end
